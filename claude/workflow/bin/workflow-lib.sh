#!/usr/bin/env bash
# workflow-lib.sh - shared helpers for the workflow machinery.
# Sourced by bin/workflow-spec.sh, bin/workflow-spawn.sh and bin/workflow-watch.sh.
#
# Nothing in this file names a project, a seat, a branch, a worktree, a state directory or a
# herdr identifier. Every one of those comes from the configuration file, which is the only
# project-aware artefact in the system. Drop bin/ and schemas/workflows/*.schema.json into another
# repository, write that repository its own config, and the machinery runs unchanged.
#
# BREADCRUMB - why this library sets no shell options at all.
# What broke: a shared library that runs `set -euo pipefail` at source time hands those options to
#   every caller. A watcher loop is built out of greps that are expected to find nothing on most
#   ticks, so it opens with `set -uo pipefail` and deliberately no -e.
# Why it mattered: sourcing silently upgraded such a caller into a shell that exits on the first
#   expected non-match. The watcher died with no error, no log line and no exit status anyone reads,
#   and a dead watcher is indistinguishable from a quiet one. This is the failure the house
#   container-sandbox skill calls out, and it is invisible to anyone reading the two files.
# Why this fix: a library that sets nothing cannot change its caller's error handling. Each script
#   declares its own options on its own first line, where a reader can see them.
#   Rejected: `set -euo pipefail` guarded by a flag, which leaves the caller's options depending on
#   how it was called; and stating the requirement in a comment, which is what already fails,
#   because a comment is not an enforcement.
# Cost: every caller repeats one `set` line.
# Proof, not reasoning: tests/unit/test_workflow_schemas.sh captures $- before the source and
#   asserts it is unchanged after. Check it by hand the same way, never by reading the two files.

WF_REPO="${WF_REPO:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
WF_SCHEMA_DIR="${WF_SCHEMA_DIR:-$WF_REPO/schemas/workflows}"
WF_CONFIG="${WORKFLOW_CONFIG:-$WF_REPO/config/project.json}"

wf_die() { printf 'workflow: %s\n' "$*" >&2; exit 1; }
wf_now() { date -u +%Y-%m-%dT%H:%M:%SZ; }

wf_need() { command -v "$1" >/dev/null 2>&1 || wf_die "$1 is required and not on PATH"; }

# wf_cfg <jq-filter>: one fact out of the configuration file.
wf_cfg() {
  [ -f "$WF_CONFIG" ] || wf_die "no configuration at $WF_CONFIG (set WORKFLOW_CONFIG)"
  jq -r "$1" "$WF_CONFIG"
}

# A leading ~ in a configured path is expanded here and nowhere else, so no caller has to remember
# that config values are not shell-expanded. Only a leading ~ is touched: a tilde anywhere else in a
# path is a legitimate character and rewriting it would corrupt the path.
# The pattern is a bracketed literal tilde, not a quoted one: a quoted "~/" reads to shellcheck as an
# unexpanded tilde and trips SC2088 at warning level, which the gate treats as a failure. [~]/* matches
# the same single character with no ambiguity, so the check stays on instead of being suppressed.
wf_expand() { case "$1" in [~]/*) printf '%s/%s' "$HOME" "${1#[~]/}" ;; *) printf '%s' "$1" ;; esac; }

wf_state_dir() { wf_expand "$(wf_cfg .project.state_dir)"; }

wf_workflow_file() {
  local id="$1" f="$WF_SCHEMA_DIR/$1.workflow.json"
  [ -f "$f" ] || wf_die "no workflow '$id' (expected $f)"
  printf '%s' "$f"
}

wf_list() {
  local f
  for f in "$WF_SCHEMA_DIR"/*.workflow.json; do
    [ -f "$f" ] || continue
    jq -r '"\(.id)\t\(.version)\t\(.title)"' "$f"
  done
}

# wf_interpolate: expand ${gate_command} and ${state_dir} in a workflow declaration read from stdin.
# A workflow declares the project's gate by name, never by its command line, so the same declaration
# works in a repository that gates with something other than the one this config happens to name.
wf_interpolate() {
  local gate state skills
  gate="$(wf_cfg .project.gate_command)"; state="$(wf_state_dir)"
  skills="$(wf_expand "$(wf_cfg '.workflow.skills_dir // "~/.claude/skills"')")"
  jq --arg gate "$gate" --arg state "$state" --arg skills "$skills" \
    'walk(if type == "string"
          then gsub("\\$\\{gate_command\\}"; $gate)
             | gsub("\\$\\{state_dir\\}"; $state)
             | gsub("\\$\\{skills_dir\\}"; $skills)
          else . end)'
}

# wf_validate <schema> <instance>: the project already owns a validator; call it rather than
# growing a second one that can disagree with the gate about what valid means.
wf_validate() { "$WF_REPO/tools/validate-schema.sh" "$1" "$2"; }

# ---------------------------------------------------------------------------
# Watcher helpers, per house MONITORING-AND-ALERTING v1.0.0.
#
# One line only on CHANGE, never a heartbeat per tick: a watcher that reports the same state every
# minute writes sixty identical lines an hour and buries the one line that mattered.
# ALERT prefixes a line only when the decision is the owner's. Everything else takes a lowercase
# `key:` prefix, so both a reader and `grep ALERT` can tell them apart without judgement.
# Nothing is printed to the owner and nothing is sent to any pane.

wf_watch_log() { printf '%s %s\n' "$(wf_now)" "$*" >> "$WF_WATCH_LOG"; }

# wf_watch_change <key> <line...>: log only when <key>'s value differs from the previous call.
# The previous value is held in the loop's own process, so a restarted watcher announces current
# state once and then goes quiet again. Returns 0 when it logged, 1 when it stayed silent.
wf_watch_change() {
  local key="$1"; shift
  local var="WF_PREV_${key//[^A-Za-z0-9]/_}"
  local cur="$*"
  [ "${!var-}" = "$cur" ] && return 1
  printf -v "$var" '%s' "$cur"
  wf_watch_log "$cur"
  return 0
}

# wf_watch_state <name> <state> <pid> [extra-json]: the schema-backed state file beside the log.
wf_watch_state() {
  local name="$1" state="$2" pid="$3" extra="${4:-null}"
  local x
  mkdir -p "$(dirname "$WF_WATCH_LOG")"
  x="$extra"; [ "$x" = null ] && x='{}'
  jq -n --arg w "$name" --arg s "$state" --argjson p "$pid" \
        --arg at "${WF_WATCH_STARTED:-$(wf_now)}" --arg log "$WF_WATCH_LOG" \
        --argjson iv "${WF_WATCH_INTERVAL:-60}" --argjson x "$x" \
    '{schema_version:"1.0.0",watcher:$w,state:$s,pid:$p,started_at:$at,log:$log,interval_seconds:$iv} + $x' \
    > "${WF_WATCH_LOG%.log}.state.json"
}

# wf_watch_status <name> <pidfile>: the house contract - the pid and the last three lines, nothing more.
wf_watch_status() {
  local name="$1"
  local pidf="$2" p
  p="$(cat "$pidf" 2>/dev/null || true)"
  if [ -n "$p" ] && kill -0 "$p" 2>/dev/null; then printf '%s on, pid %s\n' "$name" "$p"
  else printf '%s off\n' "$name"; fi
  tail -n 3 "$WF_WATCH_LOG" 2>/dev/null || true
}
