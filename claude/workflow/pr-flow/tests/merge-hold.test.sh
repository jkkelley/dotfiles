#!/usr/bin/env bash
# name: merge-hold.test.sh
# purpose: dev gate for the merge hold in pr-flow bin/merge.sh (coq line/tests/cases/merge-hold.sh, rule R4)
# inputs: bin/merge.sh; tests/lib-merge.sh
# outputs: ok/FAIL lines and pass= fail=; exit 1 on any failure
# writes-to: a mktemp directory
# cleanup: the mktemp directory is removed on exit
# shellcheck disable=SC2015
set -uo pipefail
PR_FLOW_DIR=$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd); export PR_FLOW_DIR
# shellcheck source=lib-merge.sh
. "$PR_FLOW_DIR/tests/lib-merge.sh"
fixture_up
pr_set 7
echo '{"sha":"cccccccccccccccccccccccccccccccccccccccc","reason":"main red at ccc"}' > "$W/state/merge-hold.json"
run_merge --pr 7; eq "hold on: exit 3" "$RC" 3
[ -s "$W/gh/calls.log" ] && no "a gh call under the hold" || ok "no gh call under the hold"
eq "one blocked 423" "$(pubs blocked)" 1
grep "^line.test.event.blocked " "$W/pub.log" | cut -d' ' -f2- | jq -e '.sha == "cccccccccccccccccccccccccccccccccccccccc" and (.note|test("main red"))' >/dev/null && ok "the 423 names the hold sha and reason" || no "423 fields"
run_merge --all; eq "--all under the hold: exit 3" "$RC" 3
eq "still one 423 for the same hold" "$(pubs blocked)" 1
echo 'not json' > "$W/state/merge-hold.json"; run_merge --pr 7
eq "an unreadable hold still holds" "$RC" 3; [[ $OUT == *unreadable* ]] && ok "reason unreadable" || no "reason: $OUT"
rm -f "$W/state/merge-hold.json"; run_merge --pr 7; eq "hold lifted: merges" "$RC" 0
# WO-20261016-0233: ci green but the head carries an in-review work-order: held 3, gh pr merge never called
hd 8 >/dev/null; git -C "$W/clone" switch -q feat/t8; mkdir -p "$W/clone/work-orders/E"   # PR 7 merged above and its branch is gone; t8 is a fresh head
printf -- '---\n{"id": "WO-20261016-aaaa", "status": "in-review"}\n---\n' > "$W/clone/work-orders/E/WO-20261016-aaaa-x.md"
git -C "$W/clone" add -A; git -C "$W/clone" commit -qm open; git -C "$W/clone" push -q origin feat/t8; git -C "$W/clone" switch -q main
H=$(git -C "$W/clone" rev-parse feat/t8); pr_set 8 "{\"headRefOid\": \"$H\"}"; : > "$W/gh/calls.log"
run_merge --pr 8; eq "ticket in-review: exit 3" "$RC" 3; [[ $OUT == *TICKET-OPEN* ]] && ok "reason names TICKET-OPEN" || no "reason: $OUT"
grep -q 'pr merge' "$W/gh/calls.log" && no "gh pr merge called under TICKET-OPEN" || ok "gh pr merge never called"
done_tests
