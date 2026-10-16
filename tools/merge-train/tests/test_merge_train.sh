#!/usr/bin/env bash
# rolodex: header drafted by scripts/rolodex.py headers - correct any line that is wrong
# name: test_merge_train.sh
# purpose: Why: the train must merge children before their parent (or the parent lands on main without them), must never merge
# inputs: --arg --argjson --base --dry --head --jq
# outputs: stdout, exit code
# writes-to: a mktemp scratch path
# cleanup: removes its own temp files on exit
# Why: the train must merge children before their parent (or the parent lands on main without them), must never merge
# a child under a parent it will skip (the code would be stranded on a dead branch), and every skip must carry
# evidence (Design principles 101 item 7). A stub gh records the merge calls so the order itself is asserted.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }

# Stack: 1 <- main; 2 <- 1; 3 <- 2; 4 <- 1 ; 5 <- main ci-failed; 6 <- 5 (blocked); 7 draft; 8 <- gone (orphan); 9 pending;
# 10 cancelled run superseded by a green rerun (merges); 11 green run superseded by a red rerun (ci-failed).
cat >"$tmp/prs.json" <<'JSON'
[
 {"number":1,"title":"root","url":"u1","headRefName":"a","baseRefName":"main","isDraft":false,"mergeable":"MERGEABLE","statusCheckRollup":[]},
 {"number":2,"title":"mid","url":"u2","headRefName":"b","baseRefName":"a","isDraft":false,"mergeable":"MERGEABLE","statusCheckRollup":[{"name":"t","status":"COMPLETED","conclusion":"SUCCESS"}]},
 {"number":3,"title":"leaf","url":"u3","headRefName":"c","baseRefName":"b","isDraft":false,"mergeable":"MERGEABLE","statusCheckRollup":[]},
 {"number":4,"title":"leaf2","url":"u4","headRefName":"d","baseRefName":"a","isDraft":false,"mergeable":"MERGEABLE","statusCheckRollup":[]},
 {"number":5,"title":"red","url":"u5","headRefName":"e","baseRefName":"main","isDraft":false,"mergeable":"MERGEABLE","statusCheckRollup":[{"name":"lint","status":"COMPLETED","conclusion":"FAILURE","detailsUrl":"https://github.com/o/r/actions/runs/1/job/42"}]},
 {"number":6,"title":"under-red","url":"u6","headRefName":"f","baseRefName":"e","isDraft":false,"mergeable":"MERGEABLE","statusCheckRollup":[]},
 {"number":7,"title":"draft","url":"u7","headRefName":"g","baseRefName":"main","isDraft":true,"mergeable":"MERGEABLE","statusCheckRollup":[]},
 {"number":8,"title":"orphan","url":"u8","headRefName":"h","baseRefName":"gone","isDraft":false,"mergeable":"MERGEABLE","statusCheckRollup":[]},
 {"number":9,"title":"pending","url":"u9","headRefName":"i","baseRefName":"main","isDraft":false,"mergeable":"MERGEABLE","statusCheckRollup":[{"name":"t","status":"IN_PROGRESS","conclusion":null}]},
 {"number":10,"title":"rerun","url":"u10","headRefName":"j","baseRefName":"main","isDraft":false,"mergeable":"MERGEABLE","statusCheckRollup":[{"name":"t","status":"COMPLETED","conclusion":"CANCELLED","startedAt":"2026-10-16T04:45:00Z"},{"name":"t","status":"COMPLETED","conclusion":"SUCCESS","startedAt":"2026-10-16T04:45:05Z"}]},
 {"number":11,"title":"rerun-red","url":"u11","headRefName":"k","baseRefName":"main","isDraft":false,"mergeable":"MERGEABLE","statusCheckRollup":[{"name":"t","status":"COMPLETED","conclusion":"SUCCESS","startedAt":"2026-10-16T04:45:00Z"},{"name":"t","status":"COMPLETED","conclusion":"FAILURE","startedAt":"2026-10-16T04:45:05Z"}]}
]
JSON
cat >"$tmp/gh" <<'STUB'
#!/usr/bin/env bash
log=$STUB_DIR/calls
case "$1 $2" in
  "api repos/o/r") echo '{"default_branch":"main","allow_merge_commit":false,"allow_squash_merge":true,"allow_rebase_merge":true}' ;;
  "pr list")
    if [[ " $* " == *" --base "* ]]; then # open children of a branch: not yet merged, not yet retargeted
      b=$(sed -n 's/.* --base \([^ ]*\) .*/\1/p' <<<"$* ")
      merged=$(grep -o 'pulls/[0-9]*/merge' "$log.ok" 2>/dev/null | tr -dc '0-9\n' | jq -sc . 2>/dev/null || echo '[]')
      moved=$(grep -o 'PATCH repos/o/r/pulls/[0-9]*' "$log" 2>/dev/null | tr -dc '0-9\n' | jq -sc . 2>/dev/null || echo '[]')
      jq -r --arg b "$b" --argjson m "${merged:-[]}" --argjson v "${moved:-[]}" \
        '.[] | select(.baseRefName == $b and (.number as $n | ($m + $v) | index($n) | not)) | .number' "$STUB_DIR/prs.json"
    elif [[ " $* " == *" --state closed "* ]]; then cat "$STUB_DIR/closed.tsv"
    elif [[ " $* " == *" headRefName "* ]]; then echo b
    elif [[ " $* " == *" --jq "* ]]; then echo 4
    else cat "$STUB_DIR/prs.json"; fi ;;
  "api repos/o/r/git/matching-refs/heads/") printf '%s\n' main c d s ;;
  "pr create") echo "$*" >>"$log"; echo https://github.com/o/r/pull/99 ;;
  "run view") printf 'line one\nError: lint failed\n' ;;
  "api -X")
    echo "$*" >>"$log"
    [[ "$*" == *"pulls/4/merge"* ]] && { echo "Pull Request is not mergeable" >&2; exit 1; }
    [[ "$*" == *"/merge"* ]] && echo "$*" >>"$log.ok"
    echo '{"sha":"abc"}' ;;
  "repo clone") exit 1 ;;
  *) echo "unexpected: $*" >&2; exit 1 ;;
esac
STUB
chmod +x "$tmp/gh"

out=$(STUB_DIR=$tmp GH=$tmp/gh MERGE_TRAIN_SLEEP=0 bash "$here/../merge-train.sh" --repo o/r --result "$tmp/r.json")
[ "$out" = "$(cat "$tmp/r.json")" ] || fail "result file differs from stdout"

order=$(grep -o 'pulls/[0-9]*/merge' "$tmp/calls" | tr -d 'a-z/' | paste -sd' ')
# 4 is tried (conflict -> clone fails -> skipped); 3 before 2, both before 1; 10 is its own root.
[ "$order" = "3 2 4 1 10" ] || fail "merge order: got '$order', want '3 2 4 1 10'"
[ "$(jq -r .method <<<"$out")" = squash ] || fail "method should follow repo settings (squash only)"
[ "$(jq -c '[.merged[].number]' <<<"$out")" = "[3,2,1,10]" ] || fail "merged: $(jq -c '[.merged[].number]' <<<"$out")"
grep -q 'DELETE repos/o/r/git/refs/heads/c' "$tmp/calls" || fail "merged head branch not cleaned up"

reason() { jq -r --argjson n "$1" '.skipped[] | select(.number == $n) | .reason' <<<"$out"; }
[ "$(reason 4)" = conflict ] || fail "#4 should be a conflict skip, got '$(reason 4)'"
[ "$(reason 5)" = ci-failed ] || fail "#5 ci-failed"
[ "$(reason 6)" = blocked-by-ancestor ] || fail "#6 blocked"
[ "$(reason 7)" = draft ] || fail "#7 draft"
[ "$(reason 8)" = orphan-base ] || fail "#8 orphan"
[ "$(reason 9)" = ci-pending ] || fail "#9 pending"
[ "$(reason 11)" = ci-failed ] || fail "#11 latest run red, got '$(reason 11)'"
jq -e '[.merged[].number] | index(10)' <<<"$out" >/dev/null || fail "#10 cancelled run superseded by green rerun not merged"
jq -e '.skipped[] | select(.number == 5) | .evidence[0] | .name == "lint" and (.log_tail | index("Error: lint failed"))' <<<"$out" >/dev/null \
  || fail "#5 evidence lacks check name and log lines"
! grep -q 'pulls/6/merge' "$tmp/calls" || fail "#6 merged under a skipped parent"

# #4 conflicted under #1: before #1's head "a" is deleted, #4 is retargeted onto main, and "a" is kept only if a child
# still targets it. Without the retarget GitHub closes #4 (seen live, ypconsult-01-src 2026-10-16 UTC).
grep -q 'PATCH repos/o/r/pulls/4 -f base=main' "$tmp/calls" || fail "conflicted child #4 not retargeted before its base was deleted"
grep -q 'DELETE repos/o/r/git/refs/heads/a' "$tmp/calls" || fail "root head not cleaned up after its child was retargeted"

# --recover: a closed PR whose head survives and whose base is gone gets a new PR into main; others are left alone.
printf '%s\t%s\t%s\t%s\n' 40 s gone "stranded" 41 x gone "head gone" 42 b main "base alive" >"$tmp/closed.tsv"
rm -f "$tmp/calls" "$tmp/calls.ok"
out=$(STUB_DIR=$tmp GH=$tmp/gh MERGE_TRAIN_SLEEP=0 bash "$here/../merge-train.sh" --repo o/r --recover 2>/dev/null)
[ "$(jq -c '[.recovered[].closed]' <<<"$out")" = "[40]" ] || fail "recover: got $(jq -c .recovered <<<"$out")"
grep -q 'pr create -R o/r --head s --base main' "$tmp/calls" || fail "recover did not open s into main"

# Dry run writes nothing.
rm -f "$tmp/calls" "$tmp/calls.ok"
STUB_DIR=$tmp GH=$tmp/gh MERGE_TRAIN_SLEEP=0 bash "$here/../merge-train.sh" --repo o/r --dry >/dev/null
[ ! -e "$tmp/calls" ] || fail "dry run made write calls"
echo "ok  merge-train: order, method, cleanup, skips with evidence, dry"
