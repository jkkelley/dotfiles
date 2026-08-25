#!/usr/bin/env bash
# The reason this command exists.
#
# `cleanup` runs git branch -D and git push --delete. If it believed the caller's
# claim that a PR merged, it would delete unmerged work. So it asks gh instead
# and refuses anything that is not MERGED. That is the one assertion that
# survived the command shrinking, and it is now guarding an actual delete rather
# than a bookkeeping commit.
source "${SKILL:-/skill}/testing/assert.sh"

d=$(git_project); fig=$(figma_dir "$WORK/fig070")
export PATH="$(gh_stub "$WORK/stub-open" OPEN ""):$PATH"

wo new --project "$d" --title "Cart empty" --type feature --problem P --out X --top-level \
   --ac "it works" --from-figma "$fig" >/dev/null
id=$(wo list --project "$d" --json | jq -r '.[0].id')
git -C "$d" add -A && git -C "$d" commit -qm "add $id"

wo approve --project "$d" --id "$id" --no-lavish --reason "test" >/dev/null
git -C "$d" add -A && git -C "$d" commit -qm "approve"
wo start --project "$d" --id "$id" >/dev/null
branch=$(git -C "$d" rev-parse --abbrev-ref HEAD)
assert_eq "feat/cart-empty" "$branch" "start created the branch from the slug"

wo submit --project "$d" --id "$id" --pr 7 >/dev/null
git -C "$d" add -A && git -C "$d" commit -qm "work"
f=$(find "$d/work-orders" -name 'WO-*.md')
sed -i 's/^- \[ \] /- [x] /' "$f"
git -C "$d" add -A && git -C "$d" commit -qm "tick"
wo done --project "$d" --id "$id" >/dev/null
git -C "$d" add -A && git -C "$d" commit -qm "done"

arch=$(find "$d/work-orders/archive" -name 'WO-*.md' | head -1)

# gh says OPEN. Nothing may be destroyed.
run 3 "cleanup refuses when gh reports the PR is not MERGED" \
  wo cleanup --project "$d" --id "$id"

git -C "$d" rev-parse --verify "$branch" >/dev/null 2>&1 \
  && _pass "the feature branch still exists after the refusal" \
  || _fail "the feature branch still exists after the refusal" "branch was deleted"

# The archive is untouched by the refusal, because cleanup never owned it. done
# archived it on the branch and it is already committed.
assert_file "$arch" "the ticket stays archived - cleanup does not own the archive"

# A ticket that never reached submit has no PR to ask gh about.
wo new --project "$d" --title "No pr here" --type chore --problem P --out X --ac "w" --top-level >/dev/null
id2=$(wo list --project "$d" --status draft --json | jq -r '.[0].id')
run 3 "cleanup refuses a ticket with no PR recorded" wo cleanup --project "$d" --id "$id2"
finish
