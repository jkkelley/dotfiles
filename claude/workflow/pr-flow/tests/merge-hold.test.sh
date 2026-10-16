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
done_tests
