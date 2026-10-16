#!/usr/bin/env bash
# B6: sweep-watch.sh, the bridge from a seat's result file to its seat record row.
# Rules out: a truncated or half-written result accepted as done (F4's cousin), a seat that outlives its deadline, a valid
# result that yields two rows or none, a completion decided by reading a pane, a result for another seat or run accepted,
# a seat that ignores its rewrite requests holding the run open forever, and a failing record write that loops.
# Every herdr and record call is a stub on PATH; time is pinned with SWEEP_NOW; nothing waits for real.
# shellcheck disable=SC2317 # fake_sleep is called indirectly, through SWEEP_SLEEP
set -uo pipefail
R="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=_t.sh
. "$R/tests/unit/_t.sh"
# shellcheck source=../lib/stubs.sh
. "$R/tests/lib/stubs.sh"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
export TEST_OUT="$T/out"
stubs_install "$T/bin"
export SWEEP_SEAT_RECORD="$R/tests/lib/stub-seat-record.sh"
export SWEEP_SEATS_DIR="$T/seats"
export SWEEP_NOW=2026-10-16T02:00:00Z
export SWEEP_RETRY_WAITS="0 0" SWEEP_WATCH_POLL=1
PAST=2026-10-16T01:40:00Z
FUTURE=2026-10-16T03:00:00Z
RID=20261016T010000Z
FIX="$R/tests/fixtures/results"
WATCH="$R/bin/sweep-watch.sh"
SCHEMA="$R/schemas/result.schema.json"
VALIDATE="$R/../tools/validate-schema.sh"
: >"$T/hook"

# fresh <seat:source:deadline>... - a run dir with those seats and a clean TEST_OUT
fresh() {
  export SWEEP_RUN_DIR="$T/run"
  rm -rf "$SWEEP_RUN_DIR" "$TEST_OUT" "$SWEEP_SEATS_DIR"; mkdir -p "$SWEEP_RUN_DIR/results" "$TEST_OUT"; : >"$TEST_OUT/calls.log"
  local seats='[]' spec seat src dl
  for spec in "$@"; do
    IFS=: read -r seat src dl <<<"$spec"
    seats="$(jq -c --arg s "$seat" --arg src "$src" --arg dl "$dl" \
      '. + [{seat:$s, source:$src, account:$s, status:"RUN-RUNNING", pane:("wS:" + $s), deadline_at:$dl, attempts:1}]' <<<"$seats")"
  done
  jq -n --arg rid "$RID" --argjson seats "$seats" '{schema_version:"1.0.0", run_id:$rid, status:"RUN-RUNNING", started_at:"2026-10-16T01:00:00Z", seats:$seats}' >"$SWEEP_RUN_DIR/run.json"
}
rows() { [ -f "$TEST_OUT/records.jsonl" ] && wc -l <"$TEST_OUT/records.jsonl" || echo 0; }
status_of() { jq -r --arg s "$1" '.seats[] | select(.seat==$s) | .status' "$SWEEP_RUN_DIR/run.json"; }
# fake_sleep runs $T/hook (a function name set by the case) with the number of this sleep, instead of waiting.
fake_sleep() { nsleep=$((${nsleep:-0} + 1)); "$(cat "$T/hook")" "$nsleep"; }
export SWEEP_SLEEP=fake_sleep T FIX
export -f fake_sleep rows
# The watcher is a child process, so a hook must be an exported function; `hook` exports it. timeout bounds a looping bug.
run_watch() { timeout 20 bash "$WATCH" --run "$RID"; }
# shellcheck disable=SC2163 # export -f takes the function's name, which is what $1 holds
hook() { export -f "$1"; printf '%s' "$1" >"$T/hook"; }
noop() { :; }

# 1. a valid result gives exactly one row (AC-H3)
fresh "gmail:gmail:$FUTURE"
cp "$FIX/OK.json" "$SWEEP_RUN_DIR/results/gmail.json"
hook noop
run_watch; rc=$?
check 0 "$rc" "valid result: the watcher exits 0"
check 1 "$(rows)" "valid result: exactly one record row"
check "passed inbox-sweep-gmail IS-$RID OK" "$(jq -r '[.outcome,.workflow,.ticket,.status] | join(" ")' "$TEST_OUT/records.jsonl")" "the row carries the outcome, the declaration, the ticket and the seat code"
check "$SWEEP_RUN_DIR/results/gmail.json" "$(jq -r .result_path "$TEST_OUT/records.jsonl")" "the row points at the result file"
check wS:gmail "$(jq -r .pane "$TEST_OUT/records.jsonl")" "the row names the seat's pane so seat-watch.sh retires it"
check OK "$(status_of gmail)" "run.json carries the seat's final status"
run_watch; check 1 "$(rows)" "a second watcher run adds no second row for a final seat"

# 2. each seat code maps to an outcome the declarations' record schema accepts, and bridges once
for c in PARTIAL BLOCKED-CHALLENGE BLOCKED-NO-BROWSER REFUSED FAILED-SEAT FAILED-SCHEMA TIMEOUT SKIPPED; do
  src="$(jq -r .source "$FIX/$c.json")"; seat="$(jq -r .seat "$FIX/$c.json")"
  fresh "$seat:$src:$FUTURE"; cp "$FIX/$c.json" "$SWEEP_RUN_DIR/results/$seat.json"; run_watch
  case $c in PARTIAL) want=passed ;; BLOCKED-*|SKIPPED) want=blocked ;; *) want=failed ;; esac
  check "$want $c 1" "$(jq -r '"\(.outcome) \(.status)"' "$TEST_OUT/records.jsonl") $(rows)" "$c bridges as $want, one row"
done

# 3. truncated JSON is not accepted (AC-H1)
fresh "gmail:gmail:$FUTURE"
head -c 300 "$FIX/OK.json" >"$SWEEP_RUN_DIR/results/gmail.json"
rm -f "$T/during"
fix_on_3() { printf '%s ' "$(rows)" >>"$T/during"; if [ "$1" -ge 3 ]; then cp "$FIX/OK.json" "$SWEEP_RUN_DIR/results/gmail.json"; fi; }
hook fix_on_3
run_watch; rc=$?
check 0 "$rc" "truncated then fixed: exits 0"
check "0 0 0 " "$(cat "$T/during")" "a truncated result produced no row on any poll before it was fixed"
check 1 "$(rows)" "once rewritten whole, exactly one row"
check 1 "$(grep -c '^herdr agent prompt wS:gmail .*did not validate' "$TEST_OUT/calls.log")" "the seat was asked once to rewrite, after two polls saw the same size"
check 1 "$(grep -c 'schema failure 1 of 3' "$SWEEP_RUN_DIR/logs/watch.log")" "the truncated file is logged as one schema failure"
# a file still growing is not a failure
fresh "gmail:gmail:$FUTURE"
head -c 200 "$FIX/OK.json" >"$SWEEP_RUN_DIR/results/gmail.json"
grow() { case "$1" in 1) head -c 400 "$FIX/OK.json" >"$SWEEP_RUN_DIR/results/gmail.json" ;; 2) head -c 600 "$FIX/OK.json" >"$SWEEP_RUN_DIR/results/gmail.json" ;; 3) cp "$FIX/OK.json" "$SWEEP_RUN_DIR/results/gmail.json" ;; esac; }
hook grow; run_watch
check 0 "$(grep -c '^herdr agent prompt' "$TEST_OUT/calls.log")" "a result that is still growing gets no rewrite request"
check 1 "$(rows)" "a result that grows to completion gives one row"

# 4. a deadline in the past gives a TIMEOUT row (AC-H2)
fresh "proton-first:proton:$PAST"
hook noop; run_watch; rc=$?
check 0 "$rc" "timeout: exits 0"
check "failed TIMEOUT 1" "$(jq -r '"\(.outcome) \(.status)"' "$TEST_OUT/records.jsonl") $(rows)" "no result at the deadline gives one TIMEOUT row"
check TIMEOUT "$(status_of proton-first)" "run.json says TIMEOUT"
"$VALIDATE" "$SCHEMA" "$SWEEP_RUN_DIR/results/proton-first.json" 2>"$T/err"; check 0 "$?" "the TIMEOUT result written on the seat's behalf validates against the schema" 
for s in "gmail:gmail" "linkedin:linkedin"; do
  fresh "${s%%:*}:${s##*:}:$PAST"; run_watch
  "$VALIDATE" "$SCHEMA" "$SWEEP_RUN_DIR/results/${s%%:*}.json" 2>"$T/err"; check 0 "$?" "TIMEOUT result for ${s##*:} validates"
done
# a seat that finished in time is not timed out even if the clock has moved on
fresh "gmail:gmail:$PAST"; cp "$FIX/OK.json" "$SWEEP_RUN_DIR/results/gmail.json"; run_watch
check "OK 1" "$(status_of gmail) $(rows)" "a valid result beats an expired deadline"
# a partial file at the deadline is kept beside the TIMEOUT result
fresh "gmail:gmail:$PAST"; head -c 100 "$FIX/OK.json" >"$SWEEP_RUN_DIR/results/gmail.json"; run_watch
check yes "$([ -f "$SWEEP_RUN_DIR/results/gmail.rejected.json" ] && echo yes || echo no)" "a half-written file at the deadline is kept as gmail.rejected.json"
# a future deadline is waited for: the seat finishes on the 2nd sleep
fresh "gmail:gmail:$FUTURE"
late() { [ "$1" -ge 2 ] && cp "$FIX/OK.json" "$SWEEP_RUN_DIR/results/gmail.json"; }
hook late; run_watch
check "OK 1" "$(status_of gmail) $(rows)" "before its deadline a seat is waited for"

# 5. three failures give FAILED-SCHEMA; a result for another run or seat is a failure
fresh "gmail:gmail:$FUTURE"
mk_invalid() { jq --argjson n "$1" '.items = [] | .extra_field = $n' "$FIX/OK.json" >"$SWEEP_RUN_DIR/results/gmail.json"; }
mk_invalid 0; hook mk_invalid; run_watch
check "FAILED-SCHEMA 1" "$(status_of gmail) $(rows)" "three different invalid results give FAILED-SCHEMA, one row"
check 2 "$(grep -c '^herdr agent prompt' "$TEST_OUT/calls.log")" "two rewrite requests were sent before the third failure ended it"
check yes "$([ -f "$SWEEP_RUN_DIR/results/gmail.rejected.json" ] && echo yes || echo no)" "the last rejected file is kept"
fresh "gmail:gmail:$FUTURE"
jq '.run_id = "20250101T000000Z"' "$FIX/OK.json" >"$SWEEP_RUN_DIR/results/gmail.json"
hook noop; fresh "gmail:gmail:$PAST"; jq '.run_id = "20250101T000000Z"' "$FIX/OK.json" >"$SWEEP_RUN_DIR/results/gmail.json"; run_watch
check "TIMEOUT" "$(status_of gmail)" "a result for another run is not accepted as done"
fresh "gmail:gmail:$PAST"; jq '.seat = "linkedin" | .source = "linkedin"' "$FIX/OK.json" >"$SWEEP_RUN_DIR/results/gmail.json"; run_watch
check "TIMEOUT" "$(status_of gmail)" "a result naming another seat is not accepted as done"
# the same invalid content is one failure, not one per poll
fresh "gmail:gmail:$FUTURE"; mk_invalid 7
settle() { [ "$1" -ge 5 ] && cp "$FIX/OK.json" "$SWEEP_RUN_DIR/results/gmail.json"; }
hook settle; run_watch
check "OK 1 1" "$(status_of gmail) $(rows) $(grep -c '^herdr agent prompt' "$TEST_OUT/calls.log")" "an unchanged invalid file is counted once and prompted once"

# 6. failover-stopped gives FAILED-SEAT
fresh "linkedin:linkedin:$FUTURE"
mkdir -p "$SWEEP_SEATS_DIR/wS_linkedin"; touch "$SWEEP_SEATS_DIR/wS_linkedin/failover-stopped"
hook noop; run_watch
check "failed FAILED-SEAT 1" "$(jq -r '"\(.outcome) \(.status)"' "$TEST_OUT/records.jsonl") $(rows)" "failover-stopped gives one FAILED-SEAT row"
"$VALIDATE" "$SCHEMA" "$SWEEP_RUN_DIR/results/linkedin.json" 2>"$T/err"; check 0 "$?" "the FAILED-SEAT result validates"

# 7. several seats: each gets exactly one row, a skipped seat none
fresh "gmail:gmail:$FUTURE" "proton-first:proton:$PAST" "linkedin:linkedin:$FUTURE"
cp "$FIX/OK.json" "$SWEEP_RUN_DIR/results/gmail.json"
jq '(.seats[] | select(.seat=="linkedin")) |= (.status="SKIPPED")' "$SWEEP_RUN_DIR/run.json" >"$T/rj" && mv "$T/rj" "$SWEEP_RUN_DIR/run.json"
run_watch
check "gmail OK|proton-first TIMEOUT" "$(jq -r '"\(.pane|sub("wS:";"")) \(.status)"' "$TEST_OUT/records.jsonl" | sort | paste -sd'|')" "mixed run: one row each for the two live seats"
check 0 "$(jq '[.seats[] | select(.status=="RUN-RUNNING")] | length' "$SWEEP_RUN_DIR/run.json")" "no seat is left running"
check 2 "$(grep -c 'R4' "$SWEEP_RUN_DIR/checklist.jsonl")" "the two R4 checklist boxes were ticked"

# 8. a record write that fails 3 times does not loop
fresh "gmail:gmail:$FUTURE"; cp "$FIX/OK.json" "$SWEEP_RUN_DIR/results/gmail.json"
STUB_RECORD_FAIL=1 run_watch; rc=$?
check 1 "$rc" "record failing: exits 1, does not loop"
check 3 "$(grep -c '^seat-record' "$TEST_OUT/calls.log")" "the record is tried exactly 3 times"
check 1 "$(grep -c 'ALERT record-failed' "$SWEEP_RUN_DIR/logs/watch.log")" "the failure is alerted in logs/watch.log"

# 9. completion is never decided from a pane (AC-H4)
fresh "gmail:gmail:$PAST" "linkedin:linkedin:$FUTURE"
cp "$FIX/OK.json" "$SWEEP_RUN_DIR/results/gmail.json"; head -c 50 "$FIX/OK.json" >"$SWEEP_RUN_DIR/results/linkedin.json"
fix_li() { [ "$1" -ge 4 ] && cp "$FIX/OK-linkedin-with-draft.json" "$SWEEP_RUN_DIR/results/linkedin.json"; }
hook fix_li; run_watch
check 0 "$(grep -cE '^herdr (pane read|wait output|pane get)|wait-output|pane read' "$TEST_OUT/calls.log")" "calls.log has no pane read or wait-output"
check 1 "$(grep -c '^herdr agent prompt' "$TEST_OUT/calls.log")" "the only herdr call is the rewrite request (agent prompt)" 
check 0 "$(grep '^herdr' "$TEST_OUT/calls.log" | grep -vc '^herdr agent prompt')" "no other herdr call of any kind"

# usage
bash "$WATCH" 2>/dev/null; check 2 "$?" "no arguments is a usage error"
bash "$WATCH" --run nonsense 2>/dev/null; check 2 "$?" "a malformed run id is a usage error"
finish
