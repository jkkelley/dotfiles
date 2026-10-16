#!/usr/bin/env bash
# shellcheck disable=SC2016 # jq filters use $var; they are jq variables, single quotes are the point
# sweep-watch.sh --run <run-id> - R4: turn each seat's result file into one seat record row, or a code written on its behalf.
#
# Runs in the foreground of the sweep-ctl pane, called by sweep.sh run (Rule 18: no backgrounding, here or by the caller).
# Every POLL seconds (default 15) it visits each seat of the run that has no final status yet, in this order:
#   1. results/<seat>.json parses and validates   -> seat-record.sh <outcome> ..., run.json seat status = the result's status
#   2. <seats dir>/<pane>/failover-stopped exists  -> FAILED-SEAT result on the seat's behalf, then the same bridge
#   3. the seat's deadline_at has passed           -> TIMEOUT result on the seat's behalf, then the same bridge
#   4. a result exists but is invalid              -> herdr agent prompt <pane> with the validator's errors; the 3rd failure
#                                                     writes FAILED-SCHEMA. A file that does not parse is "still being
#                                                     written" until two consecutive polls see the same size; only then is
#                                                     it a failure. A given content counts as a failure once.
# The loop ends when every seat has a final status. Every seat reaches one: a result, a stop, a deadline or a failure,
# so there is no separate run deadline to check (spec R4: "every seat has a final status or run deadline passes").
#
# BREADCRUMB - completion is a file that validates, never a screen. Design F4.
# What broke: a watcher matched DONE inside the echoed prompt (docs/design/inbox-sweep.md section 3, F4) and closed a seat
#   that had not finished. Nothing the seat prints can be told from what we typed into it.
# Why this fix: the only inputs here are files (results/*.json validated against schemas/result.schema.json, run.json,
#   the seat dir) and the clock. This script never runs `herdr pane read` or `herdr wait output`; the herdr calls it makes
#   are `agent prompt` only, to ask for a rewrite. tests/unit/test_watch.sh asserts calls.log carries no read.
#   Rejected: reading the pane as a second opinion, which reintroduces the F4 failure for one seat in a thousand.
# Cost: a seat that finishes but cannot write a valid file waits for its deadline, or for 3 rewrite requests, to be closed.
#
# BREADCRUMB - the bridge is record-then-run.json, not the reverse.
# A crash between the two leaves a row and a seat still non-final, so a restarted watcher writes a second row for it.
# The other order would leave a final seat with no row, which seat-watch.sh never retires. A duplicate row is harmless
# (seat-watch.sh acts on the first); a missing row strands the seat, so duplicates are the side to err on.
#
# Environment: SWEEP_RUN_DIR (the run dir; else derived from sweep_win_home), SWEEP_WATCH_POLL (seconds, default 15),
# SWEEP_SLEEP (wait command, tests only), SWEEP_SEAT_RECORD (path of seat-record.sh, tests point it at a recorder),
# SWEEP_SEATS_DIR (seat dirs root), SWEEP_NOW (fixed UTC time, tests only).
# Exit: 0 every seat final and recorded; 1 a seat's record could not be written after 3 tries (it is marked final anyway
# so the loop ends, and the failure is in logs/watch.log); 2 usage.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SWEEP="$(cd "$HERE/.." && pwd)"
# shellcheck source=sweep-lib.sh
. "$HERE/sweep-lib.sh"

run_id=""
while [ $# -gt 0 ]; do
  case "$1" in
    --run) run_id="${2:?--run needs a run id}"; shift 2 ;;
    -h|--help) sed -n '2,2p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "sweep-watch.sh: unknown argument $1" >&2; exit 2 ;;
  esac
done
[[ $run_id =~ ^[0-9]{8}T[0-9]{6}Z$ ]] || { echo "usage: sweep-watch.sh --run <run-id>" >&2; exit 2; }
command -v jq >/dev/null || { echo "sweep-watch.sh: jq is required" >&2; exit 2; }

if [ -z "${SWEEP_RUN_DIR:-}" ]; then
  win="$(sweep_win_home)" || { echo "sweep-watch.sh: cannot resolve the Windows home and SWEEP_RUN_DIR is unset" >&2; exit 2; }
  SWEEP_RUN_DIR="$win/.local/state/zenith/inbox-sweep/runs/$run_id"
fi
export SWEEP_RUN_DIR
RUN="$SWEEP_RUN_DIR"
[ -f "$RUN/run.json" ] || { echo "sweep-watch.sh: no run.json in $RUN" >&2; exit 2; }
[ "$(jq -r .run_id "$RUN/run.json")" = "$run_id" ] || { echo "sweep-watch.sh: $RUN/run.json is not run $run_id" >&2; exit 2; }
mkdir -p "$RUN/results" "$RUN/logs"

POLL="${SWEEP_WATCH_POLL:-15}"
SLEEP="${SWEEP_SLEEP:-sleep}"
RECORD="${SWEEP_SEAT_RECORD:-$SWEEP/../bin/seat-record.sh}"
SEATS_DIR="${SWEEP_SEATS_DIR:-$HOME/.local/state/dotfiles/execution/seats}"
VALIDATE="$SWEEP/../tools/validate-schema.sh"
SCHEMA="$SWEEP/schemas/result.schema.json"
LOG="$RUN/logs/watch.log"
FINAL=" OK PARTIAL BLOCKED-NO-BROWSER BLOCKED-SIGNED-OUT BLOCKED-CHALLENGE BLOCKED-CONNECTOR REFUSED TIMEOUT FAILED-SEAT FAILED-SCHEMA SKIPPED "

now() { if [ -n "${SWEEP_NOW:-}" ]; then printf '%s\n' "$SWEEP_NOW"; else sweep_now; fi; }
# Lines are `<UTC> <seat> <event> <detail>`; one line per event, never per poll, so the log stays readable.
log() { printf '%s %s\n' "$(now)" "$*" >>"$LOG"; }
is_final() { [[ $FINAL == *" $1 "* ]]; }

# ISO UTC to epoch seconds, for comparing a deadline with now.
epoch() { date -u -d "$1" +%s 2>/dev/null; }

seat_field() { jq -r --arg s "$1" --arg f "$2" '.seats[] | select(.seat==$s) | .[$f] // empty' "$RUN/run.json"; }
set_seat() { # <seat> <status>
  sweep_json_set "$RUN/run.json" '(.seats[] | select(.seat==$s)) |= (.status=$st)' --arg s "$1" --arg st "$2"
}

# outcome in the declaration's record schema (passed|failed|blocked) from the seat code
outcome_of() {
  case "$1" in
    OK|PARTIAL) echo passed ;;
    BLOCKED-*|SKIPPED) echo blocked ;;
    *) echo failed ;;
  esac
}

# bridge <seat> <status> - the one place a record row is written.
bridge() {
  local seat="$1" status="$2" source pane args
  source="$(seat_field "$seat" source)"
  pane="$(seat_field "$seat" pane)"
  args=("$(outcome_of "$status")" --workflow "inbox-sweep-$source" --ticket "IS-$run_id"
        --set "run_id=$run_id" --set "status=$status" --set "result_path=$RUN/results/$seat.json")
  [ -n "$pane" ] && args+=(--pane "$pane")
  if sweep_retry 3 "record-$seat" bash "$RECORD" "${args[@]}" >>"$LOG" 2>&1; then
    log "$seat recorded $status"
  else
    log "$seat ALERT record-failed $status after 3 tries; seat marked final so the loop ends"
    rec_failed=1
  fi
  set_seat "$seat" "$status"
}

# synth <seat> <status> <message> - a result written on the seat's behalf, valid against the schema.
# A file already there (a rejected or half-written result) is kept beside it as <seat>.rejected.json, not overwritten blind.
synth() {
  local seat="$1" status="$2" msg="$3" f="$RUN/results/$1.json" attempts t
  [ -f "$f" ] && cp "$f" "$RUN/results/$seat.rejected.json"
  attempts="$(seat_field "$seat" attempts)"
  [[ $attempts =~ ^[1-3]$ ]] || attempts=1
  t="$(now)"
  jq -n --arg rid "$run_id" --arg seat "$seat" --arg src "$(seat_field "$seat" source)" --arg acct "$(seat_field "$seat" account)" \
        --arg st "$status" --arg t "$t" --arg start "$(jq -r '.started_at // empty' "$RUN/run.json")" --arg msg "$msg" --argjson n "$attempts" '
    {schema_version:"1.0.0", run_id:$rid, seat:$seat, source:$src, account:($acct | if .=="" then $seat else . end), status:$st,
     started_at:($start | if .=="" then $t else . end), finished_at:$t, attempts:$n,
     counts:{before:{unread:null}, after:{unread:null}, processed:0, important:0, bulk:0},
     items:[], drafts:[], owner_decisions:[], mutations:[],
     errors:[{at:$t, attempt:$n, step:"watch", message:$msg}], tab_closed:false}' >"$f.tmp" && mv "$f.tmp" "$f"
}

# check_result <seat> - 0 valid; 1 invalid (errors in $verr); 3 not parseable yet
verr=""
check_result() {
  local f="$RUN/results/$1.json" out
  jq -e . "$f" >/dev/null 2>&1 || return 3
  if ! out="$("$VALIDATE" "$SCHEMA" "$f" 2>&1)"; then verr="$out"; return 1; fi
  if [ "$(jq -r .seat "$f")" != "$1" ] || [ "$(jq -r .run_id "$f")" != "$run_id" ]; then
    verr="  seat and run_id must be '$1' and '$run_id'"
    return 1
  fi
  return 0
}

declare -A fails size_seen same_polls counted_hash
rec_failed=0

visit() { # <seat>
  local seat="$1" f pane stopdir cur size hash deadline
  f="$RUN/results/$seat.json"
  pane="$(seat_field "$seat" pane)"
  deadline="$(seat_field "$seat" deadline_at)"
  stopdir="$SEATS_DIR/${pane//[^A-Za-z0-9_-]/_}"

  if [ -f "$f" ]; then
    check_result "$seat"
    case $? in
      0)
        local st; st="$(jq -r .status "$f")"
        bridge "$seat" "$st"
        return
        ;;
    esac
  fi
  if [ -n "$pane" ] && [ -f "$stopdir/failover-stopped" ]; then
    log "$seat seat-watch reported failover-stopped"
    synth "$seat" FAILED-SEAT "seat-watch stopped failover for pane $pane: the seat died without a valid result"
    bridge "$seat" FAILED-SEAT
    return
  fi
  if [ "$(epoch "$(now)")" -ge "$(epoch "$deadline")" ]; then
    log "$seat deadline $deadline passed with no valid result"
    synth "$seat" TIMEOUT "no valid result by the seat deadline $deadline"
    bridge "$seat" TIMEOUT
    return
  fi
  [ -f "$f" ] || return 0

  # A result exists and is not valid (yet).
  size="$(wc -c <"$f")"
  hash="$(cksum <"$f")"
  if check_result "$seat"; then cur=0; else cur=$?; fi
  if [ "$cur" = 3 ]; then
    if [ "${size_seen[$seat]:-}" = "$size" ]; then same_polls[$seat]=$((${same_polls[$seat]:-0} + 1)); else same_polls[$seat]=0; fi
    size_seen[$seat]="$size"
    [ "${same_polls[$seat]}" -ge 1 ] || return 0
    verr="  the file is not valid JSON (unchanged at $size bytes for two polls; truncated?)"
  fi
  [ "${counted_hash[$seat]:-}" = "$hash" ] && return 0
  counted_hash[$seat]="$hash"
  fails[$seat]=$((${fails[$seat]:-0} + 1))
  log "$seat schema failure ${fails[$seat]} of 3"
  if [ "${fails[$seat]}" -ge 3 ]; then
    synth "$seat" FAILED-SCHEMA "result failed validation 3 times; last errors: $(printf '%s' "$verr" | head -c 200 | tr '\n' ' ')"
    bridge "$seat" FAILED-SCHEMA
    return
  fi
  if [ -n "$pane" ]; then
    herdr agent prompt "$pane" "Your result file $f did not validate against the result schema. Errors: $(printf '%s' "$verr" | head -c 600 | tr '\n' ' ') Rewrite the whole file as valid JSON, then stop. Do not report in any other way." >/dev/null 2>&1 \
      || log "$seat herdr agent prompt failed; the seat gets no rewrite request this time"
  fi
}

log "watch started run=$run_id poll=${POLL}s"
while :; do
  open=0
  while IFS= read -r seat; do
    [ -n "$seat" ] || continue
    is_final "$(seat_field "$seat" status)" && continue
    visit "$seat"
    is_final "$(seat_field "$seat" status)" || open=$((open + 1))
  done < <(jq -r '.seats[].seat' "$RUN/run.json")
  [ "$open" -eq 0 ] && break
  "$SLEEP" "$POLL"
done

sweep_check R4 "every seat final" "run.json .seats[].status has no non-final seat" || true
sweep_check R4 "no seat past deadline" "TIMEOUT rows in logs/watch.log for late seats" || true
log "watch ended: every seat final"
exit "$rec_failed"
