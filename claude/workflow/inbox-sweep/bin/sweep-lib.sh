# shellcheck shell=bash
# shellcheck disable=SC2016 # jq filters use $var; they are jq variables, single quotes are the point
# Shared helpers for the inbox sweep's scripts. Sourced, never executed, so it sets no shell options of its own:
# the caller's `set -euo pipefail` governs, and every function here is written to be safe under it.
#
# Environment the helpers read:
#   SWEEP_RUN_DIR     the run directory; run.json and checklist.jsonl live in it. Unset means "no run", and the
#                     helpers that record into a run skip recording rather than fail.
#   SWEEP_RETRY_WAITS seconds to wait after the 1st, 2nd, 3rd... failed attempt (default "10 30 90"); the last value
#                     repeats if there are more attempts than values. Tests override it.
#   SWEEP_SLEEP       the command that waits (default `sleep`); tests point it at a recorder so no test really waits.
#   SWEEP_WIN_HOME    overrides the Windows home lookup; tests and non-WSL hosts set it.
#
# Design: docs/design/inbox-sweep.md section 8 (retries) and spec node `scripts` / `sweep-lib.sh`.

sweep_now() { date -u +%Y-%m-%dT%H:%M:%SZ; }

# sweep_json_set <file> <jq-filter> [jq args...]
# Writes through a temp file in the same directory, then mv, so a reader polling the file (sweep-watch.sh reads
# run.json every 15 seconds) never sees a half-written file. A temp file elsewhere would make mv a copy, which is not atomic.
sweep_json_set() {
  local file="$1" filter="$2" tmp
  shift 2
  tmp="$(mktemp "$(dirname "$file")/.sweep-json.XXXXXX")" || return 1
  if jq "$@" "$filter" "$file" >"$tmp"; then
    mv "$tmp" "$file"
  else
    rm -f "$tmp"
    return 1
  fi
}

# sweep_retry <attempts> <step> <cmd...>
# Runs cmd up to <attempts> times. After failed attempt N it waits the Nth value of SWEEP_RETRY_WAITS, except after the
# last attempt: nothing is gained by waiting 90 seconds and then giving up, so the third failure returns at once.
# With the default 3 attempts the waits actually taken are therefore 10 and 30; 90 is used only by a caller that asks
# for 4 attempts. Rejected alternative: sleeping after the final failure too, which only delays the report.
# Appends {step,status,attempts,at} to $SWEEP_RUN_DIR/run.json .steps (status ok|failed) and returns the last exit code,
# so the controller can record the step's status code and move on rather than loop.
sweep_retry() {
  local attempts="${1:-}" step="${2:-}"
  if ! [[ $attempts =~ ^[1-9][0-9]*$ ]] || [ -z "$step" ] || [ $# -lt 3 ]; then
    echo "sweep_retry: usage: sweep_retry <attempts> <step> <cmd...>" >&2
    return 2
  fi
  shift 2
  local -a waits
  read -r -a waits <<<"${SWEEP_RETRY_WAITS:-10 30 90}"
  local sleeper="${SWEEP_SLEEP:-sleep}" n=0 rc=0 status=failed
  while [ "$n" -lt "$attempts" ]; do
    n=$((n + 1))
    if "$@"; then
      rc=0
      status=ok
      break
    else
      rc=$?
    fi
    [ "$n" -lt "$attempts" ] || break
    "$sleeper" "${waits[$((n - 1))]:-${waits[-1]}}"
  done
  if [ -n "${SWEEP_RUN_DIR:-}" ] && [ -f "$SWEEP_RUN_DIR/run.json" ]; then
    sweep_json_set "$SWEEP_RUN_DIR/run.json" '.steps = ((.steps // []) + [{step:$s, status:$st, attempts:$n, at:$at}])' \
      --arg s "$step" --arg st "$status" --argjson n "$n" --arg at "$(sweep_now)" || true
  fi
  return "$rc"
}

# sweep_check <node> <box> <proof>
# One checklist row per call: a node is done only when each of its boxes has a row with its proof (design section 10).
sweep_check() {
  if [ $# -ne 3 ] || [ -z "${SWEEP_RUN_DIR:-}" ]; then
    echo "sweep_check: usage: sweep_check <node> <box> <proof> (with SWEEP_RUN_DIR set)" >&2
    return 2
  fi
  jq -cn --arg at "$(sweep_now)" --arg node "$1" --arg box "$2" --arg proof "$3" \
    '{at:$at, node:$node, box:$box, proof:$proof}' >>"$SWEEP_RUN_DIR/checklist.jsonl"
}

# sweep_win_home
# Prints the Windows home as a WSL path, resolved once and cached in run.json .win_home. Run dirs sit on the Windows
# drive because both runtimes reach it natively (design section 9).
sweep_win_home() {
  local cached="" home=""
  if [ -n "${SWEEP_RUN_DIR:-}" ] && [ -f "$SWEEP_RUN_DIR/run.json" ]; then
    cached="$(jq -r '.win_home // empty' "$SWEEP_RUN_DIR/run.json")"
    if [ -n "$cached" ]; then
      printf '%s\n' "$cached"
      return 0
    fi
  fi
  if [ -n "${SWEEP_WIN_HOME:-}" ]; then
    home="$SWEEP_WIN_HOME"
  else
    home="$(wslpath -u "$(cmd.exe /c 'echo %USERPROFILE%' 2>/dev/null | tr -d '\r')")" || return 1
  fi
  [ -n "$home" ] || return 1
  if [ -n "${SWEEP_RUN_DIR:-}" ] && [ -f "$SWEEP_RUN_DIR/run.json" ]; then
    sweep_json_set "$SWEEP_RUN_DIR/run.json" '.win_home = $h' --arg h "$home" || true
  fi
  printf '%s\n' "$home"
}

# sweep_bearings_server <cards-file> <server-js>
# Starts the Bearings server for the page that owns <cards-file> unless <dir>/server.json says one is up. The server
# goes in a new herdr pane labeled bearings-inbox-sweep (split, rename, run), never a background job (CLAUDE.md Rule 18):
# the owner watches herdr. Moved here from sweep-cards.sh in B14 because reply-cards.sh needs the same server and a copy
# of 20 lines would drift; the behaviour is unchanged and tests/unit/test_cards.sh still covers it. A server that cannot
# be started is logged through the caller's `log` function, not fatal: the cards are on disk and the next run tries again.
# Environment: SWEEP_HERDR_WORKSPACE herdr workspace label to put the pane in (default dotfiles).
sweep_bearings_server() {
  local cards="$1" server_js="$2" ws anchor known pane
  if [ -f "$(dirname "$cards")/server.json" ]; then
    log "bearings server already up"
    return 0
  fi
  ws="$(herdr workspace list 2>/dev/null | jq -r --arg l "${SWEEP_HERDR_WORKSPACE:-dotfiles}" 'first(.result.workspaces[] | select(.label == $l) | .workspace_id) // empty' || true)"
  anchor="" known=""
  if [ -n "$ws" ]; then
    known="$(herdr pane list --workspace "$ws" 2>/dev/null | jq -c '[.result.panes[].pane_id]' || true)"
    anchor="$(jq -r '.[0] // empty' <<<"${known:-[]}")"
  fi
  if [ -z "$anchor" ]; then
    log "no herdr pane to split; server not started"
  elif ! herdr pane split "$anchor" --direction down >/dev/null 2>&1; then
    log "herdr pane split failed; server not started"
  else
    # The new pane is the id that was not in the list before the split: panes can be unlabeled already, so "last
    # unlabeled pane" could rename someone else's.
    pane="$(herdr pane list --workspace "$ws" 2>/dev/null | jq -r --argjson k "${known:-[]}" '[.result.panes[].pane_id | select(. as $i | $k | index($i) | not)] | last // empty' || true)"
    if [ -n "$pane" ] && herdr pane rename "$pane" bearings-inbox-sweep >/dev/null 2>&1 &&
      herdr pane run "$pane" "node $server_js inbox-sweep" >/dev/null 2>&1; then
      log "bearings server started in pane $pane (bearings-inbox-sweep)"
    else
      log "could not label or run the server pane; server not started"
    fi
  fi
}
