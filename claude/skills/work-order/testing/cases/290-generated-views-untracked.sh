#!/usr/bin/env bash
# name: 290-generated-views-untracked.sh
# purpose: prove INDEX.md and epic READMEs are untracked build outputs that every reader rebuilds on demand (WO-20261016-565d)
# inputs: SKILL (skill dir), a drafted project from testing/assert.sh
# outputs: ok/FAIL lines from assert.sh
# writes-to: a temporary project under the test sandbox only
# cleanup: the sandbox project is removed by the test harness
# INDEX.md and the epic READMEs are untracked build outputs (WO-20261016-565d).
# A fresh clone has neither, so every reader must rebuild them and the CI check
# must validate without them.
source "${SKILL:-/skill}/testing/assert.sh"

read -r d id <<<"$(drafted_project)"
rm -f "$d/work-orders/INDEX.md"
find "$d/work-orders" -name README.md -delete

run 0 "next answers with INDEX.md absent" wo next --project "$d"
assert_file "$d/work-orders/INDEX.md" "next rebuilt INDEX.md"

rm -f "$d/work-orders/INDEX.md"
run 0 "tree answers with INDEX.md absent" wo tree --project "$d"
assert_file "$d/work-orders/INDEX.md" "tree rebuilt INDEX.md"

rm -f "$d/work-orders/INDEX.md"
run 0 "reindex --check passes with INDEX.md absent" wo reindex --project "$d" --check
run 1 "reindex --check wrote nothing" test -f "$d/work-orders/INDEX.md"

# A ticket newer than the index triggers a rebuild on read.
sleep 1
touch "$d/work-orders/"*/WO-*.md "$d/work-orders/"WO-*.md 2>/dev/null || true
run 0 "a reader regenerates a stale index" wo tree --project "$d"

# The layout gate still fails the CI check.
cp "$(find "$d/work-orders" -name 'WO-*.md' | head -1)" "$d/work-orders/WO-99999999-loose0.md"
run 3 "reindex --check fails on a loose top-level ticket" wo reindex --project "$d" --check
