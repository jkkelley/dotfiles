#!/usr/bin/env bash
# The happy path, against a real bare origin.
#
# Two properties, and the second is the one this redesign turns on: both branches
# are gone, and main gained no commit. cleanup is not bookkeeping - the archive
# reached main inside the ticket's own pull request, before this command ran.
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

# done and the commit that carries it both happen on the branch, which is the
# whole procedure. Nothing after the merge writes anything.
wo done --project "$d" --id "$id" >/dev/null
git -C "$d" add -A && git -C "$d" commit -qm "done"
git -C "$d" push -q origin "$branch"

git -C "$d" checkout -q main && git -C "$d" merge -q --no-ff -m "merge #7" "$branch"
git -C "$d" push -q origin main && git -C "$d" checkout -q "$branch"

main_before=$(git -C "$d" rev-parse origin/main)
arch=$(find "$d/work-orders/archive" -name 'WO-*.md' | head -1)

# The archive reached main through the merge, not through this command.
run 0 "the archive is on origin/main before cleanup runs" bash -c \
  "git -C '$d' cat-file -e origin/main:'${arch#"$d"/}'"

run 0 "cleanup succeeds when gh reports MERGED" wo cleanup --project "$d" --id "$id"

assert_eq "$main_before" "$(git -C "$d" rev-parse origin/main)" "cleanup added no commit to main"
assert_eq "main" "$(git -C "$d" rev-parse --abbrev-ref HEAD)" "the caller is left on main"

git -C "$d" rev-parse --verify "$branch" >/dev/null 2>&1 \
  && _fail "the feature branch was deleted locally" "branch still exists" \
  || _pass "the feature branch was deleted locally"
git -C "$d" ls-remote --exit-code --heads origin "$branch" >/dev/null 2>&1 \
  && _fail "the feature branch was deleted on the remote" "remote branch still exists" \
  || _pass "the feature branch was deleted on the remote"

# Idempotent by construction: a branch already gone is the expected state on a
# re-run, days later or on a second machine.
run 0 "a second cleanup is a clean no-op" wo cleanup --project "$d" --id "$id"
assert_eq "$main_before" "$(git -C "$d" rev-parse origin/main)" "the re-run added no commit either"
finish
