#!/usr/bin/env bash
# Existing files are never clobbered. Three shapes matter: empty, partial, and
# hand-written with no recognisable structure.
CASE_NAME=020-scaffold-existing
source "${SKILL:-/skill}/testing/assert.sh"

# --- zero bytes: the state this skill's own project was in when it was written
p=$(new_project)
: >"$p/COMPASS.md"; : >"$p/ISSUES.md"
run 0 "apply over zero-byte files" scaffold --project "$p" --apply --yes
assert_contains "$p/COMPASS.md" "scaffold:section=map" "empty COMPASS gained its sections"
assert_contains "$p/ISSUES.md" "ISSUES:BEGIN" "empty ISSUES gained its sentinel"

# --- hand-written prose with none of our structure: must be refused untouched
q=$(new_project)
printf '# My own notes\n\nProse I care about.\n' >"$q/COMPASS.md"
cp "$q/COMPASS.md" "$WORK/before-hand.md"
run 0 "apply over unstructured file" scaffold --project "$q" --apply --yes
assert_same "$q/COMPASS.md" "$WORK/before-hand.md" "unstructured file left byte-identical"

# --- partial: only the missing sections are added, exactly once
r=$(new_project)
head -20 "$SKILL/references/templates/COMPASS.md.tmpl" >"$r/COMPASS.md"
run 0 "apply over partial file" scaffold --project "$r" --apply --yes
assert_count 1 "$(grep -c 'scaffold:section=map' "$r/COMPASS.md")" "map section appears exactly once"
assert_count 1 "$(grep -c 'scaffold:section=siblings' "$r/COMPASS.md")" "siblings section added once"
assert_contains "$r/COMPASS.md" "One-line purpose" "original content still present"

finish
