#!/usr/bin/env bash
# sweep-preflight.sh - node R2 of the inbox sweep: is the machine able to run the seats at all?
#
#   sweep-preflight.sh --run <run-id>
#
# Input:  <run>/run.json
# Output: <run>/preflight.json {schema_version, run_id, checked_at, checks:[{id, code, attempts, evidence}]}
#         <run>/logs/preflight.log  raw output of every attempt of every probe
#         <run>/checklist.jsonl     one row per passed box (design section 5, R2 checklist)
#
# Checks, in order, each with one PF-* code (design section 6):
#   herdr         PF-NO-HERDR       not inside herdr or no `dotfiles` workspace. Rule 18: nothing may run outside a
#                                   labeled pane, so this refuses with exit 3 before any other probe (preflight.json
#                                   is still written, so the refusal has a record).
#   claude-exe    PF-NO-CLAUDE-EXE  `<win-home>/.local/bin/claude.exe --version` fails.
#   chrome        PF-NO-CHROME      tasklist.exe shows no chrome.exe.
#   extension     PF-NO-BROWSER     `claude.exe -p --chrome` lists no connected browser, tried through sweep_retry 3.
# The extension probe is not run when claude-exe or chrome failed: it cannot succeed without them, and three 90 second
# timeouts would only delay the report. Its row then carries the upstream code, attempts 0 and "not probed".
# Browser seats are skipped by the controller when any of PF-NO-CLAUDE-EXE, PF-NO-CHROME, PF-NO-BROWSER is present;
# the Gmail seat still runs. Only PF-NO-HERDR stops the run.
#
# Exit: 0 written; 2 usage error or no run.json, nothing written; 3 PF-NO-HERDR, nothing started.
#
# Environment: SWEEP_RUN_DIR overrides the run dir; SWEEP_WIN_HOME overrides the Windows home lookup (sweep-lib.sh);
# SWEEP_PROBE_TIMEOUT seconds for the extension probe (default 90, the spec's value). Spec: docs/design/inbox-sweep.spec.xml, script `sweep-preflight.sh` and the launchers probes.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=sweep-lib.sh
. "$HERE/sweep-lib.sh"

usage() { echo "usage: sweep-preflight.sh --run <run-id>" >&2; exit 2; }
if [ $# -ne 2 ] || [ "$1" != "--run" ]; then usage; fi
run_id="$2"
[[ $run_id =~ ^[0-9]{8}T[0-9]{6}Z$ ]] || { echo "sweep-preflight: bad run id '$run_id'" >&2; exit 2; }

if [ -z "${SWEEP_RUN_DIR:-}" ]; then
  win_home="$(sweep_win_home)" || { echo "sweep-preflight: cannot resolve the Windows home" >&2; exit 2; }
  SWEEP_RUN_DIR="$win_home/.local/state/zenith/inbox-sweep/runs/$run_id"
fi
export SWEEP_RUN_DIR
[ -f "$SWEEP_RUN_DIR/run.json" ] || { echo "sweep-preflight: no run.json in $SWEEP_RUN_DIR" >&2; exit 2; }
win_home="$(sweep_win_home)" || win_home=""
mkdir -p "$SWEEP_RUN_DIR/logs"
LOG="$SWEEP_RUN_DIR/logs/preflight.log"
CLAUDE_EXE="$win_home/.local/bin/claude.exe"

# checks accumulates one compact JSON object per check; add_check <id> <code> <attempts> <evidence>
checks=()
add_check() {
  checks+=("$(jq -cn --arg id "$1" --arg code "$2" --argjson a "$3" --arg e "$4" '{id:$id, code:$code, attempts:$a, evidence:$e}')")
}
# Pass boxes are written to checklist.jsonl only after preflight.json exists, so a proof never points at nothing.
passed=()

write_preflight() {
  local tmp
  tmp="$(mktemp "$SWEEP_RUN_DIR/.preflight.XXXXXX")"
  printf '%s\n' "${checks[@]}" | jq -s --arg run "$run_id" --arg at "$(sweep_now)" \
    '{schema_version:1, run_id:$run, checked_at:$at, checks:.}' >"$tmp"
  mv "$tmp" "$SWEEP_RUN_DIR/preflight.json"
  local p
  for p in "${passed[@]+"${passed[@]}"}"; do
    sweep_check R2 "${p%%|*}" "${p#*|}"
  done
}

# --- herdr ---------------------------------------------------------------------------------------------------------
# Captured into a variable, not piped into `grep -q`: grep exiting early would SIGPIPE herdr and, under pipefail, turn a
# present workspace into a failure.
herdr_out=""
if [ "${HERDR_ENV:-}" = 1 ] && herdr_out="$(herdr workspace list 2>>"$LOG")" && grep -q dotfiles <<<"$herdr_out"; then
  add_check herdr PF-OK 1 "HERDR_ENV=1 and workspace dotfiles listed"
  passed+=("inside herdr|preflight.json checks[herdr].evidence")
else
  add_check herdr PF-NO-HERDR 1 "HERDR_ENV=${HERDR_ENV:-unset}; workspace list: ${herdr_out:-none}"
  write_preflight
  echo "sweep-preflight: PF-NO-HERDR - not inside herdr; nothing started" >&2
  exit 3
fi

# --- claude.exe ----------------------------------------------------------------------------------------------------
exe_code=PF-NO-CLAUDE-EXE
exe_ev="cannot run $CLAUDE_EXE"
if [ -n "$win_home" ] && ver="$("$CLAUDE_EXE" --version 2>>"$LOG")" && [ -n "$ver" ]; then
  exe_code=PF-OK
  exe_ev="$ver"
  passed+=("claude.exe runs|version string in preflight.json checks[claude-exe].evidence")
fi
add_check claude-exe "$exe_code" 1 "$exe_ev"

# --- chrome --------------------------------------------------------------------------------------------------------
chrome_code=PF-NO-CHROME
chrome_ev="tasklist.exe shows no chrome.exe"
if row="$(tasklist.exe /FI "IMAGENAME eq chrome.exe" /NH 2>>"$LOG" | grep -i chrome.exe | head -n 1)" && [ -n "$row" ]; then
  chrome_code=PF-OK
  chrome_ev="$row"
  passed+=("chrome running|tasklist row in preflight.json checks[chrome].evidence")
fi
add_check chrome "$chrome_code" 1 "$chrome_ev"

# --- extension -----------------------------------------------------------------------------------------------------
# One attempt = one claude.exe call whose raw answer goes to the log. The pass filter is the spec's, verbatim: an empty
# list, a non-list, or output that is not JSON all fail it, so a sleeping extension (`[]`) is retried, not trusted.
# Counted in a variable because sweep_retry runs the command in this shell, not a subshell.
ext_attempts=0
ext_last=""
# shellcheck disable=SC2317 # called indirectly, through sweep_retry
probe_extension() {
  ext_attempts=$((ext_attempts + 1))
  local rc=0
  ext_last="$(timeout "${SWEEP_PROBE_TIMEOUT:-90}" "$CLAUDE_EXE" -p --chrome --model haiku --output-format json \
    "Call list_connected_browsers once. Output only its raw result as JSON. Do nothing else." 2>>"$LOG")" || rc=$?
  printf '[attempt %s rc=%s] %s\n' "$ext_attempts" "$rc" "$ext_last" >>"$LOG"
  [ "$rc" -eq 0 ] || return 1
  jq -e '.result | fromjson? // . | (if type=="array" then length else 0 end) > 0' <<<"$ext_last" >/dev/null 2>&1
}

if [ "$exe_code" != PF-OK ]; then
  add_check extension "$exe_code" 0 "not probed: claude.exe is not runnable"
elif [ "$chrome_code" != PF-OK ]; then
  add_check extension "$chrome_code" 0 "not probed: chrome is not running"
elif sweep_retry 3 probe-extension probe_extension; then
  add_check extension PF-OK "$ext_attempts" "$ext_last"
  passed+=("extension connected|probe output and attempts in preflight.json checks[extension].evidence")
else
  add_check extension PF-NO-BROWSER "$ext_attempts" "no connected browser after $ext_attempts tries; last answer: $ext_last"
fi

write_preflight
exit 0
