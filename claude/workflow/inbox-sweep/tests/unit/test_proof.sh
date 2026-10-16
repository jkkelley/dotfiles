#!/usr/bin/env bash
# B13: the tab bar proof. Rules out: a failed screen capture reported as clean (F7), a verdict taken on faith when
# there is no baseline, an orphan tab with no card or with a card per rerun, and a seat prompted to close its tabs
# more than 3 times. Every Windows and Claude dependency is a stub on PATH; nothing here touches a screen or a browser.
# shellcheck disable=SC2016 # fixture JSON in single quotes is literal on purpose
set -uo pipefail
R="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=_t.sh
. "$R/tests/unit/_t.sh"
# shellcheck source=../lib/stubs.sh
. "$R/tests/lib/stubs.sh"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
export TEST_OUT="$T/out"
stubs_install "$T/bin"
cp "$R/tests/lib/stub-powershell-exe.sh" "$T/bin/powershell.exe"
cp "$R/tests/lib/stub-claude.sh" "$T/bin/claude"
cp "$R/tests/lib/stub-wslpath.sh" "$T/bin/wslpath"
chmod +x "$T/bin/"*
export SWEEP_RETRY_WAITS="0 0" SWEEP_SLEEP=true
RUN=20261016T000000Z
OK='{"code":"CLEAN-OK","claude_groups_open":0,"tabs_beyond_baseline":0,"orphan_tabs":[]}'
LEFT='{"code":"CLEAN-TABS-LEFT","claude_groups_open":1,"tabs_beyond_baseline":2,"orphan_tabs":[]}'
ORPHAN='{"code":"CLEAN-ORPHAN-TAB","claude_groups_open":0,"tabs_beyond_baseline":1,"orphan_tabs":["Inbox (3) - example"]}'

fresh() { # a run dir with one live browser seat and one gmail seat
  rm -rf "$T/run" "$T/out"; mkdir -p "$T/run" "$TEST_OUT"; : >"$TEST_OUT/calls.log"
  export SWEEP_RUN_DIR="$T/run" SWEEP_CARDS_FILE="$T/cards/questions.json"
  rm -rf "$T/cards"
  echo '{"run_id":"'"$RUN"'","seats":[{"seat":"sweep-proton-1","source":"proton"},{"seat":"sweep-gmail","source":"gmail"}]}' >"$T/run/run.json"
  # panes live in controller.json, written by sweep.sh (WO-20261016-002d)
  echo '{"schema_version":1,"panes":{"sweep-proton-1":"wS:p7","sweep-gmail":"wS:p8"}}' >"$T/run/controller.json"
  unset STUB_PS_FAIL STUB_PS_BAD STUB_VERDICT STUB_VERDICT_SEQ
}
proof() { bash "$R/bin/sweep-proof.sh" "$@"; }
count() { grep -c -e "$1" "$TEST_OUT/calls.log" || true; }
verdict_code() { jq -r .code "$T/run/proof/R7-verdict.json"; }

# baseline happy path
fresh
proof baseline --run "$RUN"; rc=$?
check 0 "$rc" "baseline exits 0"
check 1 "$(find "$T/run/proof" -name 'R2-tabbar-*.png' | wc -l)" "baseline writes one proof/R2-tabbar-<UTC>.png"
check 1 "$(count '^powershell.exe .*screen.ps1')" "baseline runs screen.ps1 through powershell.exe once"
check 1 "$(count '-NoProfile -ExecutionPolicy Bypass')" "powershell.exe is called with -NoProfile -ExecutionPolicy Bypass"

# AC-H1: capture failing 3 times gives CLEAN-NO-PROOF
fresh
proof baseline --run "$RUN" >/dev/null
export STUB_PS_FAIL=1
out="$(proof verify --run "$RUN")"; rc=$?
check 0 "$rc" "verify exits 0 even without proof"
check CLEAN-NO-PROOF "$out" "verify prints CLEAN-NO-PROOF when the capture fails"
check CLEAN-NO-PROOF "$(verdict_code)" "R7-verdict.json says CLEAN-NO-PROOF when the capture fails"
check 4 "$(count '^powershell.exe')" "capture is tried exactly 3 times (plus the 1 baseline call): no loop"
check 0 "$(count '^claude ')" "no verdict is read when there is no screenshot to read"

# a capture that exits 0 but writes a non-PNG is a failure, not proof
fresh
proof baseline --run "$RUN" >/dev/null
export STUB_PS_BAD=1
check CLEAN-NO-PROOF "$(proof verify --run "$RUN")" "a non-PNG capture gives CLEAN-NO-PROOF"

# failed baseline: the run goes on, verify cannot reach better than CLEAN-NO-PROOF
fresh
export STUB_PS_FAIL=1; proof baseline --run "$RUN"; rc=$?
check 0 "$rc" "a failed baseline does not stop the run (exit 0)"
unset STUB_PS_FAIL
check CLEAN-NO-PROOF "$(proof verify --run "$RUN")" "no baseline: verify can only reach CLEAN-NO-PROOF"
check 0 "$(count '^claude ')" "no baseline: the verifier is never asked"

# clean
fresh
proof baseline --run "$RUN" >/dev/null
export STUB_VERDICT="$OK"
check CLEAN-OK "$(proof verify --run "$RUN")" "matching tab bars give CLEAN-OK"
check "CLEAN-OK 0" "$(jq -r '"\(.code) \(.tabs_left_prompts)"' "$T/run/proof/R7-verdict.json")" "CLEAN-OK verdict records no prompts"
check 1 "$(count '^claude .*-p --model haiku --output-format json')" "the verdict is one claude -p --model haiku call"
check 1 "$(find "$T/run/proof" -name 'R7-tabbar-*.png' | wc -l)" "verify writes proof/R7-tabbar-<UTC>.png"

# the verdict may come wrapped in prose and a code fence
fresh
proof baseline --run "$RUN" >/dev/null
export STUB_VERDICT='Here is the result: ```json
{"code":"CLEAN-OK","claude_groups_open":0,"tabs_beyond_baseline":0,"orphan_tabs":[]}
```'
check CLEAN-OK "$(proof verify --run "$RUN")" "a fenced verdict is still read"

# a verdict that never parses is CLEAN-NO-PROOF after 3 reads
fresh
proof baseline --run "$RUN" >/dev/null
export STUB_VERDICT='the tabs look fine to me'
check CLEAN-NO-PROOF "$(proof verify --run "$RUN")" "an unreadable verdict gives CLEAN-NO-PROOF"
check 3 "$(count '^claude ')" "an unreadable verdict is re-read exactly 3 times"

# AC-H3: TABS-LEFT prompts the seat at most 3 times
fresh
proof baseline --run "$RUN" >/dev/null
export STUB_VERDICT="$LEFT"
check CLEAN-TABS-LEFT "$(proof verify --run "$RUN")" "tabs that never close stay CLEAN-TABS-LEFT"
check 3 "$(count '^herdr agent prompt wS:p7 Close your tab group now, anchor last, then exit')" "TABS-LEFT prompts the live browser seat exactly 3 times"
check 0 "$(count '^herdr agent prompt wS:p8')" "the gmail seat has no browser tabs and is never prompted"
check 4 "$(count '^claude ')" "the verdict is read once, then once after each of the 3 prompts"
check 4 "$(find "$T/run/proof" -name 'R7-tabbar-*.png' | wc -l)" "each prompt is followed by a recapture, none overwritten"
check 3 "$(jq -r .tabs_left_prompts "$T/run/proof/R7-verdict.json")" "R7-verdict.json records 3 prompt rounds"

# TABS-LEFT that clears after one prompt
fresh
proof baseline --run "$RUN" >/dev/null
printf '%s\n%s\n' "$LEFT" "$OK" >"$T/seq"; export STUB_VERDICT_SEQ="$T/seq"
check CLEAN-OK "$(proof verify --run "$RUN")" "tabs closed after one prompt end in CLEAN-OK"
check 1 "$(count '^herdr agent prompt')" "the seat is prompted once, not 3 times, when one prompt is enough"

# a seat whose herdr agent is gone is not prompted
fresh
proof baseline --run "$RUN" >/dev/null
printf '%s\n%s\n' "$LEFT" "$OK" >"$T/seq"; export STUB_VERDICT_SEQ="$T/seq"
STUB_HERDR_FAIL=1 proof verify --run "$RUN" >/dev/null
check 0 "$(count '^herdr agent prompt')" "no live pane, no prompt"

# AC-H2: orphan tab gives one card, and a rerun adds none
fresh
proof baseline --run "$RUN" >/dev/null
export STUB_VERDICT="$ORPHAN"
check CLEAN-ORPHAN-TAB "$(proof verify --run "$RUN")" "an orphan verdict gives CLEAN-ORPHAN-TAB"
check 1 "$(jq '.items | length' "$SWEEP_CARDS_FILE")" "an orphan verdict writes exactly one card"
check "IS-$RUN-sweep-B-CLEAN-ORPHAN-TAB" "$(jq -r '.items[0].id' "$SWEEP_CARDS_FILE")" "the card id follows IS-<run-id>-<seat>-B"
check yes "$(jq -r '.items[0].decide | contains("Inbox (3) - example") | if . then "yes" else "no" end' "$SWEEP_CARDS_FILE")" "the card names the orphan tab"
check 0 "$(count '^herdr agent prompt')" "an orphan tab is not prompted away: no tool can close it"
proof verify --run "$RUN" >/dev/null
check 1 "$(jq '.items | length' "$SWEEP_CARDS_FILE")" "rerunning verify adds no second card"

# a card already in the file survives
fresh
proof baseline --run "$RUN" >/dev/null
mkdir -p "$T/cards"; echo '{"title":"Inbox sweep","items":[{"id":"IS-x","about":"a","decide":"d","options":[],"rec":0}]}' >"$SWEEP_CARDS_FILE"
export STUB_VERDICT="$ORPHAN"; proof verify --run "$RUN" >/dev/null
check 2 "$(jq '.items | length' "$SWEEP_CARDS_FILE")" "the orphan card is appended beside existing cards"

# usage
proof verify >/dev/null 2>&1; check 2 "$?" "missing --run is a usage error (exit 2)"
proof wipe --run "$RUN" >/dev/null 2>&1; check 2 "$?" "unknown verb is a usage error (exit 2)"
proof verify --run not-a-run >/dev/null 2>&1; check 2 "$?" "a malformed run id is refused (exit 2)"

# screen.ps1 carries the breadcrumb the ticket asks for
for f in F6 F7 "System.Windows.Forms" "-Out"; do
  if grep -q -- "$f" "$R/bin/screen.ps1"; then ok "screen.ps1 mentions $f"; else bad "screen.ps1 mentions $f"; fi
done
finish
