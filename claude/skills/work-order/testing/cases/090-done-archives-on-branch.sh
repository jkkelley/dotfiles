#!/usr/bin/env bash
# done is the whole close-out, and it happens on the feature branch.
#
# The property that matters is not "the file moved" but "the file moved and
# nothing was committed". The archive has to ride the ticket's own pull request,
# so a done that quietly committed would put the record on main by a second route
# and bring back the split this replaced.
source "${SKILL:-/skill}/testing/assert.sh"

d=$(git_project)
export PATH="$(gh_stub "$WORK/stub-merged" MERGED feedfacef00d "$d"):$PATH"

wo new --project "$d" --title "Close me" --type feature --problem P --out X --ac "works" --top-level >/dev/null
id=$(wo list --project "$d" --json | jq -r '.[0].id')
git -C "$d" add -A && git -C "$d" commit -qm "add"
wo approve --project "$d" --id "$id" --no-lavish --reason t >/dev/null
git -C "$d" add -A && git -C "$d" commit -qm "approve"
wo start --project "$d" --id "$id" >/dev/null
branch=$(git -C "$d" rev-parse --abbrev-ref HEAD)
wo submit --project "$d" --id "$id" --pr 7 >/dev/null
f=$(find "$d/work-orders" -name 'WO-*.md'); sed -i 's/^- \[ \] /- [x] /' "$f"
git -C "$d" add -A && git -C "$d" commit -qm "work"

head_before=$(git -C "$d" rev-parse HEAD)

run 0 "done succeeds on the feature branch" wo done --project "$d" --id "$id"

# The whole point. done writes files; the caller commits them.
assert_eq "$head_before" "$(git -C "$d" rev-parse HEAD)" "done committed nothing"
[[ -n $(git -C "$d" status --porcelain) ]] \
  && _pass "done left the move in the working tree" \
  || _fail "done left the move in the working tree" "the tree is clean"

assert_eq "$branch" "$(git -C "$d" rev-parse --abbrev-ref HEAD)" "the caller is still on the branch"

arch=$(find "$d/work-orders/archive" -name 'WO-*.md' 2>/dev/null | head -1)
assert_file "$arch" "the ticket is archived under archive/YYYY/"
assert_contains "$arch" '"status": "done"' "status is done"
assert_contains "$arch" '"closed"' "closed is stamped"
assert_no_file "$d/work-orders/$id" "the ticket left the active tree, directory and all"

# merge_sha cannot be known on a branch, so it is not written at all. pr is the
# pointer, and it resolves to a merge commit through gh for as long as the
# repository exists.
assert_not_contains "$arch" 'merge_sha' "no merge_sha is written"
assert_contains "$arch" '"pr": 7' "the PR number is the durable pointer"

assert_file "$d/work-orders/archive/README.md" "archive/ carries a generated README"
assert_file "$d/work-orders/archive/2026/README.md" "archive/<year>/ carries one too"
assert_contains "$d/work-orders/INDEX.md" "archive/" "INDEX still finds the archived ticket"

run 3 "a second done on an archived ticket is refused" wo done --project "$d" --id "$id"
finish
