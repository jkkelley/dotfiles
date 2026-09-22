#!/usr/bin/env bash
# workflow-watch.sh <workflow-id> on|off|status|run - watch one workflow's gates, non-disruptively.
#
# House MONITORING-AND-ALERTING v1.0.0, implemented once and generically:
#   - log only. Nothing is printed to the owner and nothing is sent to any pane.
#   - one line only on CHANGE. Never a heartbeat per tick.
#   - a line whose decision is the owner's is prefixed ALERT. Everything else takes a lowercase
#     `key:` prefix, so `grep ALERT` is a complete filter and no judgement is needed to read the log.
#   - the pid file sits beside the log, both in the configured state directory.
#   - `status` prints the pid and the last three lines, and nothing else.
#   - the watcher stops on its own when the run ends, and `off` never disturbs the run.
#
# Which lines are the owner's is read from the workflow declaration's gates[].owner_decision, never
# decided here. A watcher that classifies severity by pattern-matching a gate name is a watcher whose
# alerting drifts the first time a gate is renamed.
#
# BREADCRUMB - why `set -uo pipefail` and deliberately no -e.
# What breaks with -e: a watcher tick is built out of commands that are expected to fail. Evaluating
#   a gate that is currently red is the normal case, not an error, and jq finding nothing in a fresh
#   log is normal too. Under -e the first of those kills the loop.
# Why it mattered: the watcher exits with no log line and no message. A dead watcher is
#   indistinguishable from a quiet one, so the failure is silent exactly when monitoring is what you
#   were relying on. bin/workflow-lib.sh sets no shell options for the same reason and says so.
# Why this fix: -u and pipefail keep real mistakes loud; -e is the one that cannot tell an expected
#   non-zero from a bug. Rejected: -e with `|| true` on every line, which is -e in name only and
#   hides the cases where a non-zero really does matter.
# Cost: a genuine bug mid-loop keeps ticking instead of stopping. `status` showing a stale log is the
#   symptom, and runbooks/RB-watcher.md names it.
set -uo pipefail
# shellcheck source=bin/workflow-lib.sh disable=SC1091
. "$(dirname "$(readlink -f "$0")")/workflow-lib.sh"
wf_need jq

WORKFLOW="${1:-}"; ACTION="${2:-status}"
[ -n "$WORKFLOW" ] || wf_die "usage: workflow-watch.sh <workflow-id> on|off|status|run"
file="$(wf_workflow_file "$WORKFLOW")"

X="$(wf_state_dir)"; mkdir -p "$X"
NAME="$WORKFLOW-watch"
WF_WATCH_LOG="$X/$NAME.log"
PIDF="$X/$NAME.pid"
WF_WATCH_INTERVAL="$(wf_cfg '.workflow.watchers.interval_seconds // 60')"
export WF_WATCH_LOG WF_WATCH_INTERVAL

# One gate evaluation. Prints "pass" or "fail"; never lets a gate's own output reach the log, because
# a watcher that echoes what it watches stops being one line on change.
gate_result() {
  local cmd="$1" expect="$2" match="${3:-}" out rc
  out="$(cd "$WF_REPO" && eval "$cmd" 2>&1)"; rc=$?
  case "$expect" in
    exit-zero)    [ "$rc" -eq 0 ] && printf pass || printf fail ;;
    exit-nonzero) [ "$rc" -ne 0 ] && printf pass || printf fail ;;
    line-match)   printf '%s' "$out" | grep -qF -- "$match" && printf pass || printf fail ;;
    *)            printf fail ;;
  esac
}

tick() {
  local n id cmd expect match owner res state alert
  state=""; alert=""
  n="$(jq '.gates | length' "$file")"
  for (( i = 0; i < n; i++ )); do
    id="$(jq -r ".gates[$i].id" "$file")"
    cmd="$(wf_interpolate < "$file" | jq -r ".gates[$i].command")"
    expect="$(jq -r ".gates[$i].expect" "$file")"
    match="$(jq -r ".gates[$i].match // \"\"" "$file")"
    owner="$(jq -r ".gates[$i].owner_decision // false" "$file")"
    res="$(gate_result "$cmd" "$expect" "$match")"
    state="$state $id=$res"
    [ "$res" = fail ] && [ "$owner" = true ] && alert="$alert $id"
  done
  printf '%s|%s' "${state# }" "${alert# }"
}

# BREADCRUMB - `on` no longer backgrounds anything; `run` is the loop, in the foreground of a herdr pane.
# What broke: the kimi-proxy original started this loop with `( ... ) >/dev/null 2>&1 & disown`.
# Why it mattered: dotfiles CLAUDE.md Rule 18 - a backgrounded watcher is invisible to the owner, and a dead one
#   looks exactly like a quiet one.
# Why this fix: bin/watch-ctl.sh owns placement for every watcher, so `on` and `off` delegate to it and this script
#   keeps only the loop. Rejected: keeping a background path behind a flag, which is the fallback Rule 18 forbids.
# Cost: watchers need herdr. `run` refuses outside it.
case "$ACTION" in
  on)  exec "$(dirname "$(readlink -f "$0")")/watch-ctl.sh" on workflow "$WORKFLOW" ;;
  run)
    [ "${HERDR_ENV:-}" = 1 ] || wf_die "refusing to run outside a herdr pane (dotfiles Rule 18); use bin/watch-ctl.sh on workflow $WORKFLOW"
    if [ -f "$PIDF" ] && kill -0 "$(cat "$PIDF" 2>/dev/null || echo 0)" 2>/dev/null; then
      printf '%s already on, pid %s\n' "$NAME" "$(cat "$PIDF")"; exit 0
    fi
    WF_WATCH_STARTED="$(wf_now)"; export WF_WATCH_STARTED
    echo "$$" > "$PIDF"
    trap 'rm -f "$PIDF"' EXIT
    threshold="$(jq -r '.agent.context_threshold_percent' "$file")"
    wf_watch_state "$NAME" on "$$" "$(jq -n --arg w "$WORKFLOW" --argjson t "$threshold" \
      '{watches_workflow:$w, context_threshold_percent:$t}')"
    wf_watch_log "watch: started on workflow $WORKFLOW"
    while :; do
      out="$(tick)"; gates="${out%%|*}"; alert="${out#*|}"
      if [ -n "$alert" ]; then
        wf_watch_change gates "ALERT decision is the owner's: $alert failing ($gates)"
      else
        wf_watch_change gates "gate: $gates"
      fi
      # The run has ended when nothing is red. A watcher that keeps ticking over a finished run is
      # a watcher nobody turns off, and an unattended loop is how a stale log starts looking live.
      case "$gates" in
        *=fail*) ;;
        *) wf_watch_log "watch: all gates passing, stopping"
           wf_watch_state "$NAME" ended 0 "$(jq -n --arg s "$(wf_now)" '{stopped_at:$s}')"
           exit 0 ;;
      esac
      sleep "$WF_WATCH_INTERVAL"
    done
    ;;
  off) exec "$(dirname "$(readlink -f "$0")")/watch-ctl.sh" off workflow "$WORKFLOW" ;;
  status) wf_watch_status "$NAME" "$PIDF" ;;
  *) wf_die "usage: workflow-watch.sh <workflow-id> on|off|status|run" ;;
esac
