#!/usr/bin/env bash
# workflow-spawn.sh - start the seat a workflow declares, through herdr, from the schema.
#
#   workflow-spawn.sh <workflow-id> [seat-name] [--link N] [--pane ID] [--ticket ID] [--brief-file FILE] [--dry-run]
#
# --link N picks link N of a declaration's model chain (agent.models), default 0. --pane pins the pane, which
# bin/seat-watch.sh uses to start the next link where the last one stopped. --ticket is recorded for the watcher.
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

DRY=0; BRIEF=""; WORKFLOW=""; SEAT=""; LINK=0; PANE=""; TICKET=""
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY=1; shift ;;
    --link) LINK="${2:?--link needs a number}"; shift 2 ;;
    --pane) PANE="${2:?--pane needs a pane id}"; shift 2 ;;
    --ticket) TICKET="${2:?--ticket needs an id}"; shift 2 ;;
    --brief-file) BRIEF="${2:?--brief-file needs a path}"; shift 2 ;;
    -h|--help) sed -n '3,9p' "$(readlink -f "$0")" | sed 's/^# \{0,1\}//'; exit 0 ;;
    -*) wf_die "unknown flag $1" ;;
    *) if [ -z "$WORKFLOW" ]; then WORKFLOW="$1"; else SEAT="$1"; fi; shift ;;
  esac
done
[ -n "$WORKFLOW" ] || wf_die "usage: workflow-spawn.sh <workflow-id> [seat-name] [--link N] [--pane ID] [--ticket ID] [--brief-file FILE] [--dry-run]"
case "$LINK" in ''|*[!0-9]*) wf_die "--link takes a link index, got '$LINK'" ;; esac

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

ws_label="$(wf_cfg .workflow.herdr.workspace_label)"
start_timeout="$(wf_cfg '.workflow.herdr.start_timeout_ms // 60000')"

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

if [ -n "$PANE" ]; then
  pane="$PANE"
else
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
fi

# A live agent already holding this name is not replaced silently: herdr answers agent_name_taken,
# and driving the incumbent would send this workflow's brief into whatever it is already doing.
if herdr agent get "$name" >/dev/null 2>&1; then
  wf_die "an agent named '$name' is already live; let it finish and exit, or rename it, before starting another"
fi

# ---- start and brief -------------------------------------------------------
allow="$(jq -r '.allowed_tools | join(",")' <<<"$spec")"
deny="$(jq -r '.denied_tools | join(",")' <<<"$spec")"

# ---- the link: what runs, and which surface it reports on ----------------
# A declaration carries either one runtime and model, or a chain (agent.models); the schema refuses both at once.
# The single form is treated as a chain of one, so everything below and bin/seat-watch.sh reads one shape.
nlinks="$(jq -r '(.models // []) | length' <<<"$spec")"
if [ "$nlinks" -gt 0 ]; then
  [ "$LINK" -lt "$nlinks" ] || wf_die "workflow '$WORKFLOW' declares $nlinks links; there is no link $LINK"
  link_json="$(jq -c --argjson n "$LINK" '.models[$n]' <<<"$spec")"
else
  [ "$LINK" = 0 ] || wf_die "workflow '$WORKFLOW' declares no model chain; only link 0 exists"
  nlinks=1
  # BREADCRUMB - why the single form still derives its surface from the runtime.
  # What broke: a Kimi seat asked for an owner-facing page cannot mint a claude.ai artifact URL, so it either
  #   invented one or produced nothing, and an invented URL reads as success in the transcript (dotfiles Rule 19).
  # Why this fix: a single-form declaration names only a runtime, so the runtime is the only fact there is; a chain
  #   link names its surface outright, because there the runtime is not enough (kimi-claude is herdr kind claude).
  #   Rejected: telling the seat in its brief which surface to use, which is prose a model can reinterpret.
  # Cost: none beyond the case below.
  runtime="$(jq -r '.runtime // "claude"' <<<"$spec")"
  case "$runtime" in claude) surface=artifact ;; *) surface=lavish ;; esac
  link_json="$(jq -nc --arg r "$runtime" --arg k "$(wf_cfg .workflow.herdr.agent_kind)" --arg m "$(claude_model "$(jq -r .model <<<"$spec")")" --arg s "$surface" \
    '{id:$r, launcher:$k, herdr_kind:$k, model:$m, surface:$s}')"
fi
link_id="$(jq -r .id <<<"$link_json")"
launcher="$(jq -r .launcher <<<"$link_json")"
kind="$(jq -r .herdr_kind <<<"$link_json")"
model="$(jq -r '.model // empty' <<<"$link_json")"
surface="$(jq -r .surface <<<"$link_json")"

# Each kind speaks its own argument dialect. Codex has no tool allow or deny flags, so for a codex link the denials
# live only in the brief; the brief below restates them for every seat for that reason.
args=()
case "$kind" in
  claude) [ -n "$model" ] && args+=(--model "$model"); args+=(--allowed-tools "$allow" --disallowed-tools "$deny") ;;
  codex)  [ -n "$model" ] && args+=(-m "$model") ;;
  *)      [ -n "$model" ] && args+=(--model "$model") ;;
esac

# The pane gets RAIL_SURFACE before the agent starts, and the agent inherits it. report/rail.sh routes on it.
# Rejected: --env on agent start, which herdr lacks. Cost: one extra command sent to the pane before the start.
run herdr pane run "$pane" "export RAIL_SURFACE=$surface RAIL_SEAT=$name"
printf 'seat %s: link %s/%s %s via %s (herdr kind %s), RAIL_SURFACE=%s\n' "$name" "$LINK" "$nlinks" "$link_id" "$launcher" "$kind" "$surface"

# BREADCRUMB - a launcher that is not the kind's own binary is run in the pane, then named.
# What broke: `herdr agent start --kind claude` always runs `claude`. kimi-k3 is Claude Code launched through
#   kimi-claude (a per-invocation --settings routing to the kimi proxy), so agent start would have started opus under
#   the kimi link's name and billed the provider the chain exists to spare.
# Why this fix: herdr detects any supported agent in any pane, so the launcher is run as a plain command, the pane is
#   waited on until herdr sees the agent idle, and the detected agent is given the seat's name.
#   Rejected: a kimi-claude shim named claude earlier on PATH, which reroutes every claude in that shell.
# Cost: this path has no agent_not_ready gate of its own; the wait's timeout is that gate.
if [ "$launcher" = "$kind" ]; then
  run herdr agent start "$name" --kind "$kind" --pane "$pane" --timeout "$start_timeout" -- "${args[@]}"
else
  run herdr pane run "$pane" "$(printf '%q ' "$launcher" "${args[@]}")"
  run herdr agent wait "$pane" --until idle --timeout "$start_timeout"
  run herdr agent rename "$pane" "$name"
fi

# The seat-link file tells bin/seat-watch.sh what runs in this pane: which workflow, seat and ticket, which link of
# how many, and where. Written only after a real start, so a watcher never reads a link that is not running.
if [ "$DRY" = 1 ]; then
  printf 'DRY: seat-link %s link=%s links=%s\n' "$pane" "$LINK" "$nlinks"
else
  jq -n --arg w "$WORKFLOW" --arg s "$name" --arg t "$TICKET" --argjson l "$LINK" --argjson n "$nlinks" \
        --argjson link "$link_json" --arg wt "$worktree" --arg p "$pane" --arg at "$(wf_now)" \
    '{workflow:$w, seat:$s, ticket:$t, link:$l, links:$n, link_id:$link.id, launcher:$link.launcher,
      herdr_kind:$link.herdr_kind, model:($link.model // null), surface:$link.surface, worktree:$wt, pane:$p, started_at:$at}' \
    > "$(wf_seat_dir "$pane")/seat-link"
fi

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
line="${brief} Write only within: ${paths:-nothing}. Never run: ${denied_cmds}. Never start an agent with an in-process Agent or Task tool; seats are started through herdr only. At ${threshold} percent context or above, follow ${WF_REPO}/runbooks/RB-compaction.md: finish your step, write your checkpoint, touch your compact-request, end your turn. Never send /compact yourself. When your work is done, report it and exit; do not idle."

# BREADCRUMB - every seat this spawner starts gets a compaction watcher, or the start is reported as failed.
# What broke: the brief told each seat to compact at its threshold, and nothing checked. A seat mid-task does not watch
#   its own context, and the runbook the brief pointed at did not exist in this repository until 2026-09-22.
# Why it mattered: a seat that runs out of context mid-step fails in a way that reads like a tooling fault, and the
#   owner cannot see it coming because nothing was watching.
# Why this fix: arming is automatic and its failure is loud. workflow.compaction.auto_arm in config/project.json is the
#   one switch. Rejected: a reminder in the brief, which is what already failed.
# Cost: a seat cannot be started while herdr cannot host its watcher.
if [ "$(wf_cfg '.workflow.compaction.auto_arm // false')" = true ]; then
  run "$(dirname "$(readlink -f "$0")")/watch-ctl.sh" on compact "$pane" \
    || wf_die "seat $name started in $pane but its compaction watcher did not come up; fix that before trusting the seat"
fi
# BREADCRUMB - the brief is sent without --wait, and only after the watcher is armed.
# What broke: `herdr agent prompt --wait` reported agent_prompt_stalled 5 s into a live Opus seat (S-02, 2026-09-22T21:3xZ,
#   wC1:p6) while the pane showed it working; under set -e that aborted the spawn before the watcher block below it.
# Why it mattered: the seat ran unwatched, which is exactly what auto_arm exists to prevent.
# Why this fix: arm first, so a seat is never live without its watcher, and send the brief fire-and-forget; the seat's
#   own report and its watcher pane are the proof it started. Rejected: tolerating the stall error, which would also
#   swallow a real one. Cost: the spawner no longer waits to see the seat pick the brief up.
run herdr agent prompt "$name" "$line"
printf 'seat %s started for workflow %s in %s (%s)\n' "$name" "$WORKFLOW" "$pane" "$worktree"
