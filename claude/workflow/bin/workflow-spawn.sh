#!/usr/bin/env bash
# workflow-spawn.sh - start the seat a workflow declares, through herdr, from the schema.
#
#   workflow-spawn.sh <workflow-id> [seat-name] [--brief-file FILE] [--dry-run]
#
# With no seat name the seat is chosen by matching the workflow's declared role against the seats in
# the configuration, so the caller names the work and never the worker.
#
# Why this script exists, and why it is not an in-process subagent.
# What breaks with an in-process agent: it appears as a generic unnamed entry under the session. The
#   owner cannot see which seat it is, cannot focus it, cannot read its terminal, and cannot tell
#   idle from blocked from done. The repository's CLAUDE.md makes this a standing rule, and the
#   declarations carry Agent and Task in agent.denied_tools so the rule is data, not prose.
# Why this fix: a herdr agent is named, owns a tab, owns a git worktree, and reports real lifecycle
#   state. Rejected: a wrapper that falls back to an in-process agent when herdr is unavailable,
#   which would make the rule hold only on the days it was convenient.
# Cost: the machinery now depends on herdr being up. `--dry-run` prints every command it would run,
#   so the spawn path stays inspectable when it is not.
#
# Herdr ids are rediscovered on every run, never stored. They are not stable across a herdr restart,
# so a hardcoded wBZ:t2 is a defect that surfaces as an agent started into a stranger's pane.
set -euo pipefail
# shellcheck source=bin/workflow-lib.sh disable=SC1091
. "$(dirname "$(readlink -f "$0")")/workflow-lib.sh"
wf_need jq

DRY=0; BRIEF=""; WORKFLOW=""; SEAT=""
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY=1; shift ;;
    --brief-file) BRIEF="${2:?--brief-file needs a path}"; shift 2 ;;
    -h|--help) sed -n '3,6p' "$(readlink -f "$0")" | sed 's/^# \{0,1\}//'; exit 0 ;;
    -*) wf_die "unknown flag $1" ;;
    *) if [ -z "$WORKFLOW" ]; then WORKFLOW="$1"; else SEAT="$1"; fi; shift ;;
  esac
done
[ -n "$WORKFLOW" ] || wf_die "usage: workflow-spawn.sh <workflow-id> [seat-name] [--brief-file FILE] [--dry-run]"

run() { if [ "$DRY" = 1 ]; then printf 'DRY:'; printf ' %q' "$@"; printf '\n'; else "$@"; fi; }

spec="$(wf_workflow_file "$WORKFLOW" >/dev/null && "$(dirname "$(readlink -f "$0")")/workflow-spec.sh" "$WORKFLOW")"
role="$(jq -r .role <<<"$spec")"
threshold="$(jq -r .context_threshold_percent <<<"$spec")"
[ "$threshold" != null ] || wf_die "workflow '$WORKFLOW' carries no context threshold; refusing to start a seat that will never compact"

# ---- the seat, from configuration -----------------------------------------
if [ -n "$SEAT" ]; then
  seat="$(jq -c --arg n "$SEAT" 'first(.workflow.seats[] | select(.name == $n)) // empty' "$WF_CONFIG")"
  [ -n "$seat" ] || wf_die "no seat named $SEAT in $WF_CONFIG"
else
  seat="$(jq -c --arg r "$role" 'first(.workflow.seats[] | select(.role == $r)) // empty' "$WF_CONFIG")"
  [ -n "$seat" ] || wf_die "no seat with role '$role' in $WF_CONFIG; add one or name a seat explicitly"
fi
name="$(jq -r .name <<<"$seat")"
tab_label="$(jq -r .tab_label <<<"$seat")"
branch="$(jq -r .branch <<<"$seat")"
worktree="$(wf_expand "$(jq -r .worktree <<<"$seat")")"

kind="$(wf_cfg .workflow.herdr.agent_kind)"
ws_label="$(wf_cfg .workflow.herdr.workspace_label)"
start_timeout="$(wf_cfg '.workflow.herdr.start_timeout_ms // 60000')"
prompt_timeout="$(wf_cfg '.workflow.herdr.prompt_timeout_ms // 120000')"

# The declaration names a model in seat vocabulary so it stays runtime-neutral for Codex and Kimi.
# Claude Code takes its own ids, and an unknown alias is answered with "issue with the selected
# model" while the agent sits idle looking started. The mapping is runtime knowledge, so it lives
# next to the runtime flag and nowhere else.
claude_model() {
  case "$1" in
    haiku)    printf 'claude-haiku-4-5-20251001' ;;
    sonnet-5) printf 'claude-sonnet-5' ;;
    opus)     printf 'claude-opus-5-5' ;;  # 2026-09-22: owner moved to Opus 5.5
    fable)    printf 'claude-fable-5-1' ;;
    *)        printf '%s' "$1" ;;
  esac
}

# ---- the worktree ----------------------------------------------------------
# One seat is one worktree on its own branch. Creating it here rather than by hand is what makes the
# spawn reproducible; `git worktree add` is idempotent enough that an existing directory is left alone.
repo_root="$(git -C "$WF_REPO" rev-parse --show-toplevel 2>/dev/null || printf '%s' "$WF_REPO")"
if [ -d "$worktree" ]; then
  printf 'seat %s: worktree present at %s\n' "$name" "$worktree"
else
  run git -C "$repo_root" worktree add "$worktree" "$branch"
fi

# ---- herdr: rediscover every id -------------------------------------------
need_herdr() { command -v herdr >/dev/null 2>&1 || wf_die "herdr is not on PATH; seats are started through herdr only"; }
need_herdr
[ "${HERDR_ENV:-}" = 1 ] || printf 'warning: HERDR_ENV is not 1; this shell may not be inside a herdr pane\n' >&2

ws="$(herdr workspace list | jq -r --arg l "$ws_label" 'first(.result.workspaces[] | select(.label == $l) | .workspace_id) // empty')"
[ -n "$ws" ] || wf_die "no herdr workspace labelled '$ws_label'"

tab="$(herdr tab list --workspace "$ws" | jq -r --arg l "$tab_label" 'first(.result.tabs[] | select(.label == $l) | .tab_id) // empty')"
if [ -z "$tab" ]; then
  printf 'seat %s: no tab labelled %s, creating one at %s\n' "$name" "$tab_label" "$worktree"
  run herdr tab create --workspace "$ws" --cwd "$worktree" --label "$tab_label" --no-focus
  tab="$(herdr tab list --workspace "$ws" | jq -r --arg l "$tab_label" 'first(.result.tabs[] | select(.label == $l) | .tab_id) // empty')"
  [ -n "$tab" ] || { [ "$DRY" = 1 ] && tab="<new-tab>"; }
fi

# A free pane is one in this tab with no agent occupying it. `agent start` never creates or splits
# layout, so a tab whose only pane already hosts an agent has nowhere to put a second one.
pane="$(herdr pane list --workspace "$ws" | jq -r --arg t "$tab" \
  'first(.result.panes[] | select(.tab_id == $t and (.agent | not)) | .pane_id) // empty')"
if [ -z "$pane" ] && [ "$DRY" = 1 ]; then pane="<free-pane>"; fi
[ -n "$pane" ] || wf_die "tab $tab has no pane at an interactive shell prompt; free one and retry"

# A live agent already holding this name is not replaced silently: herdr answers agent_name_taken,
# and driving the incumbent would send this workflow's brief into whatever it is already doing.
if herdr agent get "$name" >/dev/null 2>&1; then
  wf_die "an agent named '$name' is already live; let it finish and exit, or rename it, before starting another"
fi

# ---- start and brief -------------------------------------------------------
model="$(claude_model "$(jq -r .model <<<"$spec")")"
allow="$(jq -r '.allowed_tools | join(",")' <<<"$spec")"
deny="$(jq -r '.denied_tools | join(",")' <<<"$spec")"

# BREADCRUMB - why the pane gets RAIL_SURFACE before the agent starts (dotfiles CLAUDE.md Rule 19).
# What broke: a Kimi seat asked for an owner-facing page cannot mint a claude.ai artifact URL, so it either
#   invented one or produced nothing, and an invented URL reads as success in the transcript.
# Why this fix: the declaration names the runtime, so the surface is derived here as data and exported into the
#   pane's shell, which the agent inherits. report/rail.sh routes on it. Rejected: telling the seat in its brief
#   which surface to use, which is prose a model can reinterpret; and --env on agent start, which herdr lacks.
# Cost: one extra command sent to the pane before the start.
runtime="$(jq -r '.runtime // "claude"' <<<"$spec")"
case "$runtime" in claude) surface=artifact ;; *) surface=lavish ;; esac
run herdr pane run "$pane" "export RAIL_SURFACE=$surface RAIL_SEAT=$name"

run herdr agent start "$name" --kind "$kind" --pane "$pane" --timeout "$start_timeout" \
  -- --model "$model" --allowed-tools "$allow" --disallowed-tools "$deny"

if [ -n "$BRIEF" ]; then
  [ -f "$BRIEF" ] || wf_die "brief file not found: $BRIEF"
  brief="$(cat "$BRIEF")"
else
  brief="You are the ${role} seat for workflow ${WORKFLOW}. Your spec is printed by bin/workflow-spec.sh ${WORKFLOW}; read it and obey it."
fi

# The brief is one physical line: herdr sends text then Enter as one ordered submission, and an
# embedded newline submits half a message. Everything long belongs in a file the seat reads.
# The exit instruction is part of every brief because a seat that has finished its work exits; a
# finished agent left alive holds a pane, a name and a worktree that the next workflow needs.
paths="$(jq -r '.allowed_paths | join(", ")' <<<"$spec")"
denied_cmds="$(jq -r '.denied_commands | join(", ")' <<<"$spec")"
line="${brief} Write only within: ${paths:-nothing}. Never run: ${denied_cmds}. Never start an agent with an in-process Agent or Task tool; seats are started through herdr only. At ${threshold} percent context or above, run the compaction ceremony in runbooks/RB-compaction.md before your next step, never mid-step. When your work is done, report it and exit; do not idle."

run herdr agent prompt "$name" "$line" --wait --timeout "$prompt_timeout"
printf 'seat %s started for workflow %s in %s (%s)\n' "$name" "$WORKFLOW" "$pane" "$worktree"
