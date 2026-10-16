#!/usr/bin/env bash
# B9: sweep.sh, the controller behind `make sweep`. The integration test: every script is the real one; only herdr,
# claude.exe, claude, powershell.exe, tasklist.exe and workflow-spawn.sh are stubs on PATH or behind SWEEP_SPAWN.
# AC-H1 a full run reaches RUN-OK. AC-H2 an extension probe answering [] gives RUN-PARTIAL, Gmail OK, one card.
# AC-H3 `start` returns in under 5 seconds.
# Rules out: a run that can never say RUN-OK because collect ran before the tab bar verdict existed, a run left
# RUN-RUNNING so clean refuses it, a browser seat spawned when the preflight said there is no browser, a seat whose
# spawn failed and was dropped instead of counted, a `start` that does the run's work itself instead of handing it to
# the sweep-ctl pane, and a run that talks to a mailbox or a real herdr.
# shellcheck disable=SC2016,SC2317 # literal single-quoted stub text on purpose
set -uo pipefail
R="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=_t.sh
. "$R/tests/unit/_t.sh"
# shellcheck source=../lib/stubs.sh
. "$R/tests/lib/stubs.sh"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
export TEST_OUT="$T/out"
stubs_install "$T/bin"
for s in powershell.exe:stub-powershell-exe.sh claude:stub-claude.sh wslpath:stub-wslpath.sh; do cp "$R/tests/lib/${s#*:}" "$T/bin/${s%%:*}"; done
cat >"$T/bin/tasklist.exe" <<'STUB'
#!/usr/bin/env bash
echo "chrome.exe                    4242 Console                    1    210,000 K"
STUB
# herdr: the shared stub plus the one tab and pane `start` creates and then looks up by label.
mv "$T/bin/herdr" "$T/bin/herdr.real"
cat >"$T/bin/herdr" <<'STUB'
#!/usr/bin/env bash
case "${1:-} ${2:-}" in
  "tab list") printf 'herdr %s\n' "$*" >>"$TEST_OUT/calls.log"; printf '{"result":{"tabs":[{"tab_id":"wS:t1","label":"orchestrator"},{"tab_id":"wS:t9","label":"inbox-sweep"}]}}\n'; exit 0 ;;
  "pane list") printf 'herdr %s\n' "$*" >>"$TEST_OUT/calls.log"; printf '{"result":{"panes":[{"pane_id":"wS:p1","tab_id":"wS:t1"},{"pane_id":"wS:p9","tab_id":"wS:t9"}]}}\n'; exit 0 ;;
esac
exec "$(dirname "$0")/herdr.real" "$@"
STUB
# The spawner: logs the call, writes the seat-link the controller reads the pane from, and the seat's result.
cat >"$T/spawn.sh" <<'STUB'
#!/usr/bin/env bash
printf 'spawn %s\n' "$*" >>"$TEST_OUT/calls.log"
wf="$1"; seat="$2"; ticket=""
shift 2
while [ $# -gt 0 ]; do case "$1" in --ticket) ticket="$2"; shift 2 ;; *) shift ;; esac; done
[ "${STUB_SPAWN_FAIL:-}" = "$seat" ] && exit 1
mkdir -p "$SWEEP_SEATS_DIR/pane-$seat"
jq -n --arg s "$seat" --arg t "$ticket" --arg p "wS:$seat" '{seat:$s, ticket:$t, pane:$p}' >"$SWEEP_SEATS_DIR/pane-$seat/seat-link"
run="${ticket#IS-}"
jq --arg s "$seat" --arg r "$run" --arg src "${wf#inbox-sweep-}" '.seat=$s | .run_id=$r | .source=$src | .account=$s
   | if $src != "gmail" then .tab_group = {anchor_reused:true, tabs_opened:1, closed_anchor_last:true} else . end' \
  "$FIX/OK.json" >"$SWEEP_RUN_DIR/results/$seat.json"
STUB
chmod +x "$T/bin/"* "$T/spawn.sh"
export FIX="$R/tests/fixtures/results"

export HERDR_ENV=1 SWEEP_WIN_HOME="$T/win" SWEEP_RETRY_WAITS="0 0 0" SWEEP_SLEEP=true SWEEP_WATCH_POLL=1
export SWEEP_CONFIG="$R/tests/fixtures/config/valid.json" SWEEP_OWNER_WORDS="$R/tests/fixtures/owner-words.md"
export SWEEP_SPAWN="$T/spawn.sh" SWEEP_SEAT_RECORD="$R/tests/lib/stub-seat-record.sh"
mkdir -p "$SWEEP_WIN_HOME/.local/bin"
cp "$T/bin/claude.exe" "$SWEEP_WIN_HOME/.local/bin/claude.exe"
GOOD='{"result":"[{\"deviceId\":\"d1\",\"name\":\"Your Chrome\"}]"}'
S="$R/bin/sweep.sh"

fresh() { # fresh <name>: a clean sandbox for one scenario
  export SWEEP_RUNS_ROOT="$T/$1/runs" SWEEP_LATEST="$T/$1/latest" SWEEP_EXEC_DIR="$T/$1/exec" SWEEP_SEATS_DIR="$T/$1/exec/seats"
  export SWEEP_CARDS_FILE="$T/$1/bearings/questions.json" SWEEP_BEARINGS_SERVER="$T/none.mjs" SWEEP_TEST_OUT="$T/$1/testout"
  rm -rf "${T:?}/$1" "$TEST_OUT"; mkdir -p "$T/$1" "$TEST_OUT"; : >"$TEST_OUT/calls.log"
  unset STUB_CLAUDE_SEQ STUB_SPAWN_FAIL SWEEP_RUN_DIR
  echo "$GOOD" >"$T/good.seq"
  export STUB_CLAUDE_SEQ="$T/good.seq"
}
calls() { grep -c -e "$1" "$TEST_OUT/calls.log" || true; }
field() { jq -r "$1" "$SWEEP_RUNS_ROOT"/*/run.json; }
ctl() { jq -r "$1" "$SWEEP_RUNS_ROOT"/*/controller.json; }

# AC-H3 and the start path
fresh start
t0="$(date +%s%N)"
rid="$(bash "$S" start --seats all)"; rc=$?
ms=$((($(date +%s%N) - t0) / 1000000))
check 0 "$rc" "start exits 0"
check yes "$([[ $rid =~ ^[0-9]{8}T[0-9]{6}Z$ ]] && echo yes)" "start prints the run id"
check yes "$([ "$ms" -lt 5000 ] && echo yes)" "AC-H3: start returned in ${ms} ms, under 5000"
check 1 "$(calls "^herdr tab create .*--label inbox-sweep")" "start creates one tab labeled inbox-sweep"
check 1 "$(calls "^herdr pane rename wS:p9 sweep-ctl$")" "start renames the new tab's pane sweep-ctl"
check 1 "$(calls "^herdr pane run wS:p9 bash .*sweep.sh run --run $rid$")" "start hands the run to the sweep-ctl pane"
check 0 "$(calls '^spawn ')" "start spawns no seat itself"
check RUN-RUNNING "$(field .status)" "run.json declares RUN-RUNNING at init"
check no "$([ -e "$SWEEP_RUNS_ROOT/$rid/controller.json" ] && echo yes || echo no)" "start writes no controller.json; the run does"

# AC-H1: a full stubbed run reaches RUN-OK
fresh full
rid="$(bash "$S" start --seats all)"
sha_init="$(sha256sum "$SWEEP_RUNS_ROOT/$rid/run.json" | cut -d' ' -f1)"
out="$(HERDR_PANE_ID=wS:p9 timeout 30 bash "$S" run --run "$rid")"; rc=$?
check 0 "$rc" "run exits 0"
check RUN-OK "$(jq -r .status "$SWEEP_RUNS_ROOT/$rid/summary.json")" "AC-H1: a full stubbed run reaches RUN-OK in summary.json"
check RUN-OK "$(ctl .status)" "AC-H2: controller.json carries RUN-OK"
check "$sha_init" "$(sha256sum "$SWEEP_RUNS_ROOT/$rid/run.json" | cut -d' ' -f1)" "AC-H1: run.json is byte-identical at the end of a stubbed full run"
check "OK OK OK OK" "$(jq -r '.status' "$SWEEP_RUNS_ROOT/$rid"/seats/*.status.json | paste -sd' ')" "AC-H2: each seat's status is in seats/<seat>.status.json"
check "RUN-OK
$SWEEP_RUNS_ROOT/$rid/summary.md" "$out" "run prints the status and the summary.md path"
check 4 "$(calls '^spawn inbox-sweep-')" "one spawn per enabled seat (gmail, two proton, linkedin)"
check 1 "$(calls '^spawn inbox-sweep-gmail gmail .*--ticket IS-'"$rid"'$')" "the spawn call is workflow, seat, brief file, ticket IS-<run>"
check 2 "$(calls '^powershell.exe ')" "tab bar captured twice, baseline and verify"
check yes "$([ "$(grep -n 'powershell.exe' "$TEST_OUT/calls.log" | head -1 | cut -d: -f1)" -lt "$(grep -n '^spawn ' "$TEST_OUT/calls.log" | head -1 | cut -d: -f1)" ] && echo yes)" "the baseline is captured before the first seat starts"
check CLEAN-OK "$(jq -r .code "$SWEEP_RUNS_ROOT/$rid/proof/R7-verdict.json")" "R7 verdict is CLEAN-OK"
check yes "$(jq -r '.cleaned_at | test("Z$") | if . then "yes" else "no" end' "$SWEEP_RUNS_ROOT/$rid/clean.json")" "AC-H2: clean ran: cleaned_at is set in clean.json"
check no "$([ -d "$SWEEP_RUNS_ROOT/$rid/briefs" ] && echo yes || echo no)" "clean removed the briefs"
check "wS:gmail" "$(ctl '.panes.gmail')" "AC-H2: the pane, from the seat-link the spawner wrote, is in controller.json"
check 1 "$(calls "^herdr pane rename wS:p9 sweep-ctl $rid RUN-OK$")" "the pane ends labeled sweep-ctl <run-id> RUN-OK"
check 4 "$(wc -l <"$TEST_OUT/records.jsonl")" "the watcher wrote one record row per seat"
check 0 "$(jq '[.mutations[]?.action] - ["marked-read"] | length' "$SWEEP_RUNS_ROOT/$rid"/results/*.json | grep -vc '^0$')" "no result carries a mutation other than marked-read"

# AC-H2: probe [] three times gives RUN-PARTIAL, Gmail OK, one card
fresh partial
echo '[]' >"$T/empty.seq"; export STUB_CLAUDE_SEQ="$T/empty.seq"
rid="$(bash "$S" start --seats all)"
HERDR_PANE_ID=wS:p9 bash "$S" run --run "$rid" >/dev/null; rc=$?
check 0 "$rc" "a partial run exits 0"
sum="$SWEEP_RUNS_ROOT/$rid/summary.json"
check RUN-PARTIAL "$(jq -r .status "$sum")" "AC-H2: probe [] gives RUN-PARTIAL"
check OK "$(jq -r '.seats[] | select(.seat=="gmail") | .status' "$sum")" "AC-H2: the Gmail seat is OK"
check "SKIPPED SKIPPED SKIPPED" "$(jq -r '[.seats[] | select(.seat != "gmail") | .status] | join(" ")' "$sum")" "every browser seat is SKIPPED"
check 1 "$(calls '^spawn ')" "only the Gmail seat is spawned"
check 1 "$(jq '.items | length' "$SWEEP_CARDS_FILE")" "AC-H2: exactly one card"
check "IS-$rid-preflight-B-PF-NO-BROWSER" "$(jq -r '.items[0].id' "$SWEEP_CARDS_FILE")" "the card is the preflight PF-NO-BROWSER card (B-<code> suffix)"
check 3 "$(calls '^claude.exe -p --chrome')" "the extension was probed exactly 3 times"
check 3 "$(jq -r '[.results[]?] | length' <<<"{\"results\":$(jq -s '[.[] | select(.status=="SKIPPED")]' "$SWEEP_RUNS_ROOT/$rid"/results/*.json)}")" "a SKIPPED result file exists for each skipped seat"

"$R/../tools/validate-schema.sh" "$R/schemas/result.schema.json" "$SWEEP_RUNS_ROOT/$rid/results/proton-first.json" >/dev/null 2>&1
check 0 "$?" "a SKIPPED result written by the controller validates against result.schema.json"

# PF-NO-HERDR: nothing starts, but the run still has a summary and a clean
fresh nohdr
rid="$(bash "$S" start --seats all)"
export STUB_HERDR_FAIL=1
HERDR_PANE_ID=wS:p9 bash "$S" run --run "$rid" >/dev/null 2>&1; rc=$?
unset STUB_HERDR_FAIL
check 3 "$rc" "PF-NO-HERDR exits 3"
check RUN-FAILED "$(jq -r .status "$SWEEP_RUNS_ROOT/$rid/summary.json")" "PF-NO-HERDR gives RUN-FAILED"
check 0 "$(calls '^spawn ')" "PF-NO-HERDR spawns nothing"

# a spawn that fails 3 times is a counted seat, not a dropped one
fresh spawnfail
export STUB_SPAWN_FAIL=gmail
rid="$(bash "$S" start --seats gmail)"
HERDR_PANE_ID=wS:p9 bash "$S" run --run "$rid" >/dev/null
check 3 "$(calls '^spawn inbox-sweep-gmail gmail')" "a failing spawn is tried exactly 3 times"
check FAILED-SEAT "$(jq -r '.seats[0].status' "$SWEEP_RUNS_ROOT/$rid/summary.json")" "a seat that never started is FAILED-SEAT in the summary"
check RUN-FAILED "$(jq -r .status "$SWEEP_RUNS_ROOT/$rid/summary.json")" "no OK seat and nothing blocked is RUN-FAILED"
unset STUB_SPAWN_FAIL

# status, clean, prune and usage
fresh status
rid="$(bash "$S" start --seats gmail)"
bash "$S" status --run "$rid" | grep -q "run $rid RUN-RUNNING"; check 0 "$?" "status shows the run and its code"
bash "$S" status | grep -q "gmail RUN-RUNNING"; check 0 "$?" "status with no --run reads the latest run"
bash "$S" clean --run "$rid" >/dev/null 2>&1; check 3 "$?" "clean refuses a RUN-RUNNING run"
bash "$S" prune --days 0 >/dev/null 2>&1; check 2 "$?" "prune --days 0 is refused"
bash "$S" start --seats nonsense >/dev/null 2>&1; check 2 "$?" "an unknown --seats value exits 2"
bash "$S" >/dev/null 2>&1; check 2 "$?" "no verb exits 2"
bash "$S" bogus >/dev/null 2>&1; check 2 "$?" "an unknown verb exits 2"
SWEEP_OWNER_WORDS="$T/nope.md" bash "$S" start --seats all >/dev/null 2>&1; check 3 "$?" "start without owner words exits 3 (PF-NO-OWNER-WORDS)"
finish
