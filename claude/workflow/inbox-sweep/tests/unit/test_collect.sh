#!/usr/bin/env bash
# AC-H1: each row of the spec's codes/run derive table has a fixture (5 cases), built from the shared result fixtures.
# AC-H2: summary.md has a contents list and no em dash, even when a seat's own text carries one.
# Rules out: RUN-OK reported without a CLEAN-OK verdict (the tab bar never checked), a BLOCKED seat beside an OK seat
# hiding as RUN-BLOCKED, a seat with no result file dropped from the count, a pipe in a subject breaking a table row,
# and a rerun that is not idempotent.
set -uo pipefail
R="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=_t.sh
. "$R/tests/unit/_t.sh"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
COL="$R/bin/sweep-collect.sh"
FX="$R/tests/fixtures/results"
RUN_ID=20261016T010000Z
export SWEEP_WIN_HOME="$T/win"

# fresh <name> <seat:fixture>...: a run dir whose run.json lists the seats and whose results hold the fixtures.
# A fixture of "none" lists the seat with no result file; "none:SKIPPED" also gives run.json that status.
fresh() {
  local name="$1"; shift
  export SWEEP_RUN_DIR="$T/$name/runs/$RUN_ID"
  rm -rf "${T:?}/$name"; mkdir -p "$SWEEP_RUN_DIR/results"
  local seats="[]" pair seat fx st src
  for pair in "$@"; do
    seat="${pair%%:*}"; fx="${pair#*:}"; st=""
    src="${seat%%-*}"
    if [[ $fx == none* ]]; then st="${fx#none}"; st="${st#:}"; else cp "$FX/$fx.json" "$SWEEP_RUN_DIR/results/$seat.json"; fi
    seats="$(jq -c --arg s "$seat" --arg src "$src" --arg st "$st" '. + [{seat:$s, source:$src, account:$s, status:(if $st=="" then "RUN-RUNNING" else $st end)}]' <<<"$seats")"
  done
  jq -n --argjson seats "$seats" --arg run "$RUN_ID" '{run_id:$run, seats:$seats}' >"$SWEEP_RUN_DIR/run.json"
}
verdict() { mkdir -p "$SWEEP_RUN_DIR/proof"; echo "{\"code\":\"$1\"}" >"$SWEEP_RUN_DIR/proof/R7-verdict.json"; }
run_status() { jq -r .status "$SWEEP_RUN_DIR/summary.json"; }
collect() { bash "$COL" --run "$RUN_ID" "$@" >/dev/null 2>"$T/err"; }

# derive row 1: controller error, PF-NO-HERDR or PF-NO-OWNER-WORDS -> RUN-FAILED, even with every seat OK and clean
fresh d1a gmail:OK; verdict CLEAN-OK; collect --controller-error
check RUN-FAILED "$(run_status)" "derive 1: --controller-error beats an all-OK clean run"
fresh d1b gmail:OK; verdict CLEAN-OK
echo '{"checks":[{"id":"herdr","code":"PF-NO-HERDR"}]}' >"$SWEEP_RUN_DIR/preflight.json"; collect
check RUN-FAILED "$(run_status)" "derive 1: PF-NO-HERDR beats an all-OK clean run"
fresh d1c gmail:OK; verdict CLEAN-OK
echo '{"checks":[{"id":"owner-words","code":"PF-NO-OWNER-WORDS"}]}' >"$SWEEP_RUN_DIR/preflight.json"; collect
check RUN-FAILED "$(run_status)" "derive 1: PF-NO-OWNER-WORDS beats an all-OK clean run"

# derive row 2: all seats OK and CLEAN-OK -> RUN-OK
fresh d2 gmail:OK linkedin:OK-linkedin-with-draft; verdict CLEAN-OK; collect
check RUN-OK "$(run_status)" "derive 2: every seat OK and CLEAN-OK is RUN-OK"
fresh d2b gmail:OK; collect
check RUN-PARTIAL "$(run_status)" "derive 2: all OK with no verdict is not RUN-OK (tab bar unproven)"
fresh d2c gmail:OK; verdict CLEAN-TABS-LEFT; collect
check RUN-PARTIAL "$(run_status)" "derive 2: all OK with CLEAN-TABS-LEFT is not RUN-OK"

# derive row 3: any seat OK -> RUN-PARTIAL
fresh d3 gmail:OK proton-first:BLOCKED-CHALLENGE linkedin:TIMEOUT; verdict CLEAN-OK; collect
check RUN-PARTIAL "$(run_status)" "derive 3: one OK beside a BLOCKED and a TIMEOUT is RUN-PARTIAL"

# derive row 4: no OK, any BLOCKED-* or SKIPPED -> RUN-BLOCKED
fresh d4a gmail:BLOCKED-CONNECTOR proton-first:TIMEOUT; collect
check RUN-BLOCKED "$(run_status)" "derive 4: BLOCKED-* with no OK is RUN-BLOCKED"
fresh d4b gmail:FAILED-SEAT proton-first:none:SKIPPED; collect
check RUN-BLOCKED "$(run_status)" "derive 4: SKIPPED with no OK is RUN-BLOCKED"

# derive row 5: otherwise -> RUN-FAILED
fresh d5 gmail:FAILED-SEAT linkedin:REFUSED proton-first:TIMEOUT; collect
check RUN-FAILED "$(run_status)" "derive 5: no OK and nothing blocked is RUN-FAILED"

# every seat accounted for: a seat with no result file still has a row
fresh seats gmail:OK proton-first:none linkedin:none:SKIPPED; collect
check 3 "$(jq '.seats | length' "$SWEEP_RUN_DIR/summary.json")" "summary.json has a row for every run.json seat"
check FAILED-SEAT "$(jq -r '.seats[] | select(.seat=="proton-first") | .status' "$SWEEP_RUN_DIR/summary.json")" "a seat with no result and no code is FAILED-SEAT"
check SKIPPED "$(jq -r '.seats[] | select(.seat=="linkedin") | .status' "$SWEEP_RUN_DIR/summary.json")" "a seat with no result keeps the SKIPPED code run.json holds"
check "1 1 0 0" "$(jq -r '.seats[] | select(.seat=="gmail") | "\(.before) \(.processed) \(.after) \(.flagged)"' "$SWEEP_RUN_DIR/summary.json")" "OK seat carries before, processed, after, flagged"
check "6" "$(jq -r '.seats[0] | keys | length' "$SWEEP_RUN_DIR/summary.json")" "a seat row has exactly seat, status, before, after, processed, flagged"
check 1.0.0 "$(jq -r .schema_version "$SWEEP_RUN_DIR/summary.json")" "summary.json carries schema_version"
check yes "$(jq -r '.finished_at | test("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:]{8}Z$") | if . then "yes" else "no" end' "$SWEEP_RUN_DIR/summary.json")" "finished_at is UTC"
check 2 "$(jq -s 'map(select(.node=="R5")) | length' "$SWEEP_RUN_DIR/checklist.jsonl")" "two R5 checklist rows"

# AC-H2: contents list, no em dash, table-safe cells, newest item first
fresh md gmail:OK proton-first:PARTIAL
EM=$'\xe2\x80\x94'
jq --arg em "$EM" '.items[0].subject = ("Pipe | and dash " + $em + " here") | .items[0].gist = ("gist " + $em)' "$FX/OK.json" >"$SWEEP_RUN_DIR/results/gmail.json"
jq -c --arg em "$EM" '.items += [.items[0] | .id="m2" | .received_at="2026-10-16T02:00:00Z" | .subject="Newer"]' "$SWEEP_RUN_DIR/results/gmail.json" >"$T/g.json" && mv "$T/g.json" "$SWEEP_RUN_DIR/results/gmail.json"
collect
MD="$SWEEP_RUN_DIR/summary.md"
check 0 "$(grep -c "$EM" "$MD" || true)" "AC-H2: summary.md has no em dash, though the result's text did"
check 1 "$(grep -c '^## Contents$' "$MD")" "AC-H2: summary.md has a contents heading"
check yes "$(grep -q '^- gmail$' "$MD" && grep -q '^- proton$' "$MD" && echo yes || echo no)" "AC-H2: contents lists each source"
check "Newer" "$(grep '^| 2026' "$MD" | head -1 | awk -F' [|] ' '{print $4}' | sed 's/ *$//')" "items are sorted newest first"
check yes "$(grep -q 'Pipe \\| and dash - here' "$MD" && echo yes || echo no)" "a pipe in a subject is escaped and the dash replaced"
check 1 "$(grep -c '^## gmail$' "$MD")" "one section per source"

# idempotent, and usage errors write nothing
cp "$SWEEP_RUN_DIR/summary.json" "$T/first.json"; collect
check "$(jq -c '.seats' "$T/first.json")" "$(jq -c '.seats' "$SWEEP_RUN_DIR/summary.json")" "a rerun gives the same seats"
bash "$COL" >/dev/null 2>&1; check 2 "$?" "no arguments exits 2"
bash "$COL" --run bad >/dev/null 2>&1; check 2 "$?" "a bad run id exits 2"
rm -f "$SWEEP_RUN_DIR/run.json" "$SWEEP_RUN_DIR/summary.json"; bash "$COL" --run "$RUN_ID" >/dev/null 2>&1
check "2 no" "$? $([ -f "$SWEEP_RUN_DIR/summary.json" ] && echo yes || echo no)" "no run.json exits 2 and writes nothing"
finish
