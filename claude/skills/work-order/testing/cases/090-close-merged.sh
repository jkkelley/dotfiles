#!/usr/bin/env bash
# The happy path, against a real bare origin: branch really is deleted, ticket
# really is archived, merge SHA really is recorded.
source "${SKILL:-/skill}/testing/assert.sh"

d=$(git_project)
export PATH="$(gh_stub "$WORK/stub-merged" MERGED feedfacef00d):$PATH"

wo new --project "$d" --title "Close me" --type feature --problem P --out X --ac "works" >/dev/null
id=$(wo list --project "$d" --json | jq -r '.[0].id')
git -C "$d" add -A && git -C "$d" commit -qm "add"
wo approve --project "$d" --id "$id" --no-lavish --reason t >/dev/null
# approve rewrites the ticket; commit it or start will refuse a dirty tree.
git -C "$d" add -A && git -C "$d" commit -qm "approve"
wo start --project "$d" --id "$id" >/dev/null
branch=$(git -C "$d" rev-parse --abbrev-ref HEAD)
wo submit --project "$d" --id "$id" --pr 7 >/dev/null
f=$(find "$d/work-orders" -name 'WO-*.md'); sed -i 's/^- \[ \] /- [x] /' "$f"
git -C "$d" add -A && git -C "$d" commit -qm "work"
wo done --project "$d" --id "$id" >/dev/null
git -C "$d" add -A && git -C "$d" commit -qm "done"
git -C "$d" push -q origin "$branch"
# gh says MERGED, so origin/main must actually contain the work. A fixture that
# claims a merge without performing one tests a world that cannot exist.
git -C "$d" checkout -q main && git -C "$d" merge -q --no-ff -m "merge #7" "$branch"
git -C "$d" push -q origin main && git -C "$d" checkout -q "$branch"

run 0 "close succeeds when gh reports MERGED" wo close --project "$d" --id "$id"

arch=$(find "$d/work-orders/archive" -name 'WO-*.md' 2>/dev/null | head -1)
assert_file "$arch" "the ticket is archived under archive/YYYY/"
assert_contains "$arch" 'feedfacef00d' "the real merge SHA is recorded"
assert_contains "$arch" '"status": "done"' "status is done"
assert_no_file "$d/work-orders/$(basename "$arch")" "the ticket left the active directory"

git -C "$d" rev-parse --verify "$branch" >/dev/null 2>&1 \
  && _fail "the feature branch was deleted locally" "branch still exists" \
  || _pass "the feature branch was deleted locally"

assert_contains "$d/work-orders/INDEX.md" "archive/" "INDEX still finds the archived ticket"
run 3 "closing an already-archived ticket is refused" wo close --project "$d" --id "$id"
finish
