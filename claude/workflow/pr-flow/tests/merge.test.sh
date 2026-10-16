#!/usr/bin/env bash
# name: merge.test.sh
# purpose: dev gate for pr-flow bin/merge.sh, the cases of coq line/tests/cases/merge.test.sh with ci-green as the gate
# inputs: bin/merge.sh, bin/gate.sh, bin/records.sh; tests/lib-merge.sh
# outputs: ok/FAIL lines and pass= fail=; exit 1 on any failure
# writes-to: a mktemp directory
# cleanup: the mktemp directory is removed on exit
# shellcheck disable=SC2015
set -uo pipefail
PR_FLOW_DIR=$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd); export PR_FLOW_DIR
# shellcheck source=lib-merge.sh
. "$PR_FLOW_DIR/tests/lib-merge.sh"
fixture_up

pr_set 7; run_merge --pr 7
eq "merged: exit 0" "$RC" 0
grep -q "^pr merge 7 --squash --match-head-commit $H1$" "$W/gh/calls.log" && ok "gh pr merge --squash --match-head-commit HEAD" || no "merge call: $(grep 'pr merge' "$W/gh/calls.log")"
eq "one merged 200 posted" "$(pubs merged)" 1
grep "^line.test.event.merged " "$W/pub.log" | cut -d' ' -f2- | jq -e '.code == "200" and .pr == 7 and .ticket == "WO-20261016-aaaa" and (.sha|length) == 40 and .repo == "o/r"' >/dev/null \
  && ok "merged 200 carries pr, ticket from the body, merge sha, repo" || no "merged record: $(cat "$W/pub.log")"
run_merge --pr 7; eq "rerun on a merged PR: exit 0" "$RC" 0
[[ $OUT == *already-merged* ]] && ok "rerun says already-merged" || no "rerun: $OUT"
eq "rerun posts nothing (R3)" "$(pubs merged)" 1

pr_set 8 '{"title": "chore: no ticket", "body": ""}'; run_merge --pr 8
eq "port: no ticket still merges" "$RC" 0; grep -q '"ticket":"PR-8"' "$W/pub.log" && ok "ticket falls back to PR-8" || no "ticket fallback"

pr_set 9 '{"checks": [{"n":"ci-ok","s":"in_progress","c":""}]}'; run_merge --pr 9
eq "pending check: held, exit 3" "$RC" 3; grep -q '^pr merge 9' "$W/gh/calls.log" && no "merged a pending head" || ok "pending: no merge call"
pr_set 10 '{"checks": []}'; run_merge --pr 10; eq "zero checks: held (F3)" "$RC" 3
pr_set 11 '{"checks": [{"n":"ci-ok","s":"completed","c":"success"},{"n":"t","s":"completed","c":"failure"}]}'; run_merge --pr 11
eq "a failed check: held" "$RC" 3
pr_set 12 '{"state": "CLOSED"}'; run_merge --pr 12; eq "closed PR: held" "$RC" 3

pr_set 13 '{"mergeable": "CONFLICTING"}'; run_merge --pr 13
eq "conflict: exit 5" "$RC" 5; eq "one merge.conflict 409" "$(pubs merge.conflict)" 1
run_merge --pr 13; eq "conflict again on the same head posts nothing" "$(pubs merge.conflict)" 1
pr_set 13 '{"mergeable": "CONFLICTING", "headRefOid": "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb2"}'; run_merge --pr 13
eq "a new head re-arms the 409" "$(pubs merge.conflict)" 2
pr_set 14 '{"merge": "conflict"}'; run_merge --pr 14; eq "refused, then CONFLICTING: exit 5" "$RC" 5
pr_set 15 '{"merge": "moved"}'; run_merge --pr 15; eq "head moved while merging: held" "$RC" 3
pr_set 16 '{"merge": "merged-elsewhere"}'; run_merge --pr 16; eq "lost race to another merge: success" "$RC" 0

: > "$W/pub.log"; touch "$W/gh/fail-all"; pr_set 17; run_merge --pr 17
eq "gh down: exit 4" "$RC" 4; eq "three attempts" "$(grep -c '^pr view 17' "$W/gh/calls.log")" 3
eq "one blocked 423" "$(pubs blocked)" 1; rm -f "$W/gh/fail-all"

rm -f "$W"/gh/pr-*.json; : > "$W/gh/calls.log"; pr_set 20; pr_set 21 '{"mergeable": "CONFLICTING"}'; pr_set 22 '{"checks": []}'
run_merge --all; eq "--all: exit 0 with a conflict and a hold in the pass" "$RC" 0
eq "--all: three lines" "$(wc -l <<<"$OUT" | tr -d ' ')" 3
grep -q '^pr merge 20 ' "$W/gh/calls.log" && ! grep -q '^pr merge 22 ' "$W/gh/calls.log" && ok "--all merges the green one only" || no "--all merges"
done_tests
