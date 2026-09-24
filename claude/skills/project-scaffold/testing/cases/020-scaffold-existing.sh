#!/usr/bin/env bash
# Existing files are never clobbered. Three shapes matter: empty, partial, and
# hand-written with no recognisable structure - plus the old monoliths, which
# scaffold must notice but never touch.
CASE_NAME=020-scaffold-existing
source "${SKILL:-/skill}/testing/assert.sh"

# --- zero bytes: the state this skill's own project was in when it was written
p=$(new_project)
: >"$p/COMPASS.md"
run 0 "apply over zero-byte files" scaffold --project "$p" --apply --yes
assert_contains "$p/COMPASS.md" "scaffold:section=map" "empty COMPASS gained its sections"

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

# --- old monoliths: named in the plan, never modified, never deleted
m=$(new_project)
printf '# ISSUES\n\n<!-- ISSUES:BEGIN\n' >"$m/ISSUES.md"
printf '# BACKLOG\n' >"$m/BACKLOG.md"
cp "$m/ISSUES.md" "$WORK/issues-before.md"
cp "$m/BACKLOG.md" "$WORK/backlog-before.md"
capture plan scaffold --project "$m" --json
case $plan in *'old monolith'*) _pass "monolith named in the plan" ;;
  *) _fail "monolith named in the plan" "got: ${plan:0:400}" ;; esac
run 0 "apply over monoliths" scaffold --project "$m" --apply --yes
assert_same "$m/ISSUES.md" "$WORK/issues-before.md" "ISSUES.md monolith left byte-identical"
assert_same "$m/BACKLOG.md" "$WORK/backlog-before.md" "BACKLOG.md monolith left byte-identical"
assert_file "$m/issues/.gitkeep" "entry tree created beside the monolith"

finish
