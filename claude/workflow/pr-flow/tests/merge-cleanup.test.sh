#!/usr/bin/env bash
# name: merge-cleanup.test.sh
# purpose: dev gate for pr-flow merge.sh post_merge_clean (coq line/tests/cases/merge-cleanup.test.sh, rule R8), slots off
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
pr_set 7; git -C "$W/clone" switch -q feat/t7
run_merge --pr 7; eq "merged: exit 0" "$RC" 0
git -C "$W/origin.git" show-ref --verify --quiet refs/heads/feat/t7 && no "remote branch kept" || ok "remote branch deleted"
git -C "$W/clone" show-ref --verify --quiet refs/heads/feat/t7 && no "local branch kept" || ok "local branch deleted from a detached HEAD"
[ "$(git -C "$W/clone" rev-parse --abbrev-ref HEAD)" = HEAD ] && ok "main was never checked out" || no "HEAD: $(git -C "$W/clone" rev-parse --abbrev-ref HEAD)"
git -C "$W/origin.git" show-ref --verify --quiet refs/heads/main && ok "main kept" || no "main deleted"
[[ $OUT == *"slots off"* ]] && ok "slots off is named" || no "slot note: $OUT"
pr_set 8 '{"headRefName": "main"}'; run_merge --pr 8; eq "a PR from main merges" "$RC" 0
[[ $OUT == *"refuses to delete branch main"* ]] && ok "never deletes main" || no "main: $OUT"
pr_set 9 '{"headRefName": "feat/gone"}'; run_merge --pr 9
[[ $OUT == *"remote branch deleted"* ]] && ok "a branch already gone counts as deleted" || no "gone: $OUT"
eq "no 423 for a clean cleanup" "$(pubs blocked)" 0
done_tests
