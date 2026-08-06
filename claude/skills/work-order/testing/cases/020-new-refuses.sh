#!/usr/bin/env bash
# A validator that never rejects anything is not a validator.
source "${SKILL:-/skill}/testing/assert.sh"

d=$(new_project)
base=(--project "$d" --title T --type feature --problem P)

run 3 "refuses with no --out (an empty non-goals list lets an agent wander)" \
  wo new "${base[@]}"
run 3 "refuses an unknown --type" \
  wo new --project "$d" --title T --type nonsense --problem P --out X
run 3 "refuses an unknown --priority" \
  wo new --project "$d" --title T --type feature --problem P --out X --priority p9
run 2 "refuses a missing --title" \
  wo new --project "$d" --type feature --problem P --out X
run 2 "refuses an unknown flag" \
  wo new --project "$d" --bogus
run 4 "refuses a --from-figma dir with no build-plan.json" \
  wo new --project "$d" --title T --type feature --problem P --out X --from-figma /work/nope

# Nothing may be left behind by a refused run.
assert_no_file "$d/work-orders" "a rejected new creates no work-orders/ directory"
finish
