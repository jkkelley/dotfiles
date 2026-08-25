#!/usr/bin/env bash
# --dry-run prints the whole plan and touches nothing.
#
# It also states, in words, that the command writes nothing. That line is part of
# the deliverable: the previous version of this command wrote a commit to main,
# and a reader who remembers that needs to be told it no longer does.
source "${SKILL:-/skill}/testing/assert.sh"

d=$(git_project)
export PATH="$(gh_stub "$WORK/stub-dry" MERGED deadbeefcafe):$PATH"

wo new --project "$d" --title "Dry run me" --type chore --problem P --out X --ac "works" --top-level >/dev/null
id=$(wo list --project "$d" --json | jq -r '.[0].id')
git -C "$d" add -A && git -C "$d" commit -qm "add"
wo approve --project "$d" --id "$id" --no-lavish --reason t >/dev/null
git -C "$d" add -A && git -C "$d" commit -qm "approve"
wo start --project "$d" --id "$id" >/dev/null
wo submit --project "$d" --id "$id" --pr 7 >/dev/null
f=$(find "$d/work-orders" -name 'WO-*.md'); sed -i 's/^- \[ \] /- [x] /' "$f"
git -C "$d" add -A && git -C "$d" commit -qm "work"
wo done --project "$d" --id "$id" >/dev/null
git -C "$d" add -A && git -C "$d" commit -qm "done"

before=$(git -C "$d" rev-parse HEAD)
branch=$(git -C "$d" rev-parse --abbrev-ref HEAD)
arch=$(find "$d/work-orders/archive" -name 'WO-*.md' | head -1)

run 0 "--dry-run exits 0" wo cleanup --project "$d" --id "$id" --dry-run
capture out wo cleanup --project "$d" --id "$id" --dry-run
case $out in *"DRY RUN"*) _pass "says it is a dry run" ;; *) _fail "says it is a dry run" "got: ${out:0:200}" ;; esac
case $out in *"git branch -D"*) _pass "shows the destructive step it would run" ;; *) _fail "shows the destructive step" "got: ${out:0:200}" ;; esac
case $out in *"writes nothing"*) _pass "states that it writes nothing" ;; *) _fail "states that it writes nothing" "got: ${out:0:200}" ;; esac
case $out in *merge_sha*|*"merge sha"*) _fail "no longer mentions a merge SHA" "got: ${out:0:200}" ;; *) _pass "no longer mentions a merge SHA" ;; esac

assert_eq "$before" "$(git -C "$d" rev-parse HEAD)" "--dry-run created no commit"
assert_eq "$branch" "$(git -C "$d" rev-parse --abbrev-ref HEAD)" "--dry-run did not switch branch"
assert_file "$arch" "--dry-run left the archive alone"
finish
