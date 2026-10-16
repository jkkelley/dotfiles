#!/usr/bin/env bash
# name: 410-start-branch-id.sh
# purpose: prove work-order.sh start puts the id hex in the branch, so tickets sharing a slug both start (WO-20261016-9fc7)
# inputs: SKILL (skill dir), a project built with testing/assert.sh
# outputs: ok/FAIL lines from assert.sh
# writes-to: a temporary project under the test sandbox only
# cleanup: the sandbox project is removed by the test harness
# The slug is cut to 48 chars, so two long titles with one prefix gave one branch
# name and the second start refused branch_exists.
source "${SKILL:-/skill}/testing/assert.sh"

d=$(git_project); fig=$(figma_dir "$WORK/fig410")
prefix="Shared prefix title that is long enough to be cut by the slug limit"
ids=()
for n in 1 2; do
  wo new --project "$d" --title "$prefix $n" --type feature --problem P --out X --top-level \
     --ac "it works" --from-figma "$fig" >/dev/null
  git -C "$d" add -A && git -C "$d" commit -qm "add $n"
done
mapfile -t ids < <(wo list --project "$d" --json | jq -r '.[].id')
for id in "${ids[@]}"; do
  wo approve --project "$d" --id "$id" --no-lavish --reason "test" >/dev/null
done
git -C "$d" add -A && git -C "$d" commit -qm "approve"
base=$(git -C "$d" rev-parse --abbrev-ref HEAD)

rc1=0; wo start --project "$d" --id "${ids[0]}" >/dev/null || rc1=$?
b1=$(git -C "$d" rev-parse --abbrev-ref HEAD)
git -C "$d" add -A && git -C "$d" commit -qm "started first"
git -C "$d" checkout -q "$base"
rc2=0; wo start --project "$d" --id "${ids[1]}" >/dev/null || rc2=$?
b2=$(git -C "$d" rev-parse --abbrev-ref HEAD)

assert_eq "0" "$rc1" "first start exits 0"
assert_eq "0" "$rc2" "second start exits 0 although the slug matches"
[[ $b1 != "$b2" ]] && assert_eq "differ" "differ" "branches differ" || assert_eq "differ" "same" "branches differ"
[[ $b1 == feat/${ids[0]##*-}-* ]] && assert_eq ok ok "first branch carries its id hex" || assert_eq ok "$b1" "first branch carries its id hex"
[[ $b2 == feat/${ids[1]##*-}-* ]] && assert_eq ok ok "second branch carries its id hex" || assert_eq ok "$b2" "second branch carries its id hex"
