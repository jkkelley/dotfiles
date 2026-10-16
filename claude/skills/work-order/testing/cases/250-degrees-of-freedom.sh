#!/usr/bin/env bash
# Degrees of freedom, and the Contents list that makes a ticket navigable.
#
# A ticket says what to build and what not to build, and nothing in between: a
# junior agent handed one cannot tell which decisions are its own to make and
# which are fixed. It either asks about everything, which stalls the work, or
# decides everything, which is how "any HTTP client" turns into a new dependency
# nobody approved. `## Degrees of freedom` names the decisions the implementer
# may make without asking, and when nobody declared any the section says so in
# one fixed line rather than going quiet - silence reads as "use your judgement",
# which is the exact ambiguity the section removes.
#
# `## Contents` is generated from the template's own H2 headings, so it can never
# disagree with the body beneath it. A hand-maintained list would drift the first
# time a section was added, and a wrong map is worse than none.
source "${SKILL:-/skill}/testing/assert.sh"

# --- two declared freedoms render in order under the section ----------------
d=$(new_project)
wo new --project "$d" --title "Retry failed webhooks" --type bug --top-level \
   --problem "Deliveries that 500 are dropped silently" \
   --out "changing the payload schema" --ac "a 500 is retried three times" \
   --freedom "any HTTP client library already in go.mod" \
   --freedom "backoff schedule, as long as the ceiling stays under one minute" >/dev/null
f=$(find "$d/work-orders" -name 'WO-*.md')
id=$(wo list --project "$d" --json | jq -r '.[0].id')

assert_contains "$f" '## Degrees of freedom' "the section is rendered"
assert_not_contains "$f" '%%' "no placeholder survives the render"
dof=$(awk '/^## Degrees of freedom[[:space:]]*$/{f=1;next} /^## /{f=0} f && NF' "$f")
assert_eq "- [free] any HTTP client library already in go.mod
- [free] backoff schedule, as long as the ceiling stays under one minute" "$dof" \
  "both freedoms render as [free] lines, in the order given, and nothing else"
assert_not_contains "$f" '[fixed] None declared' "a ticket with freedoms carries no fixed line"

# The section sits between Scope and Acceptance criteria: an agent reads what is
# in and out, then what it may decide, then what it must prove.
order=$(grep -n '^## ' "$f" | grep -E 'Scope|Degrees of freedom|Acceptance criteria' | cut -d: -f2 | tr '\n' '|')
assert_eq '## Scope|## Degrees of freedom|## Acceptance criteria|' "$order" \
  "Degrees of freedom sits after Scope and before Acceptance criteria"

# --- no --freedom renders exactly one fixed line ------------------------------
d2=$(new_project)
wo new --project "$d2" --title "Empty cart state" --type feature --top-level \
   --problem "The cart shows nothing when empty" \
   --out "payment errors" --ac "npm test passes" >/dev/null
f2=$(find "$d2/work-orders" -name 'WO-*.md')
dof2=$(awk '/^## Degrees of freedom[[:space:]]*$/{f=1;next} /^## /{f=0} f && NF' "$f2")
assert_eq '- [fixed] None declared: implement exactly as specified; raise a question before deviating.' \
  "$dof2" "with no --freedom the section is exactly the one fixed line"

# --- the Contents list matches the body's own H2 headings, in order ----------
# The reference is computed from the rendered body, never typed in here: the
# assertion is "the map agrees with the territory", whatever the territory is.
want=$(grep '^## ' "$f2" | grep -v '^## Contents$' | sed 's/^## /- /')
got=$(awk '/^## Contents[[:space:]]*$/{f=1;next} /^## /{f=0} f && NF' "$f2")
assert_eq "$want" "$got" "Contents lists every H2 in the body, in order, and nothing else"
assert_contains "$f2" '- Degrees of freedom' "Contents names the new section"
head1=$(awk 'f && NF {print; exit} NR>1 && /^---$/ {f=1}' "$f2")
assert_eq "# $(wo list --project "$d2" --json | jq -r '.[0].id') - Empty cart state" "$head1" \
  "the H1 is still the first line of the body"
second=$(awk 'f && NF {n++; if (n==2) {print; exit}} NR>1 && /^---$/ {f=1}' "$f2")
assert_eq '## Contents' "$second" "Contents is the first section under the H1"

# repair rewrites the H1 and nothing else, so the Contents block survives it.
sed -i "s/^# ${id} - Retry failed webhooks\$/# %%ID%% - %%TITLE%%/" "$f"
run 0 "repair heals a placeholder H1 on a ticket with freedoms" wo repair --project "$d"
got_after=$(awk '/^## Contents[[:space:]]*$/{f=1;next} /^## /{f=0} f && NF' "$f")
assert_eq "$want" "$got_after" "repair left the Contents list untouched"
run 0 "reindex --check is clean on a ticket carrying both new blocks" \
  wo reindex --project "$d" --check

# --- amend --freedom replaces wholesale on a draft -----------------------------
run 0 "amend --freedom succeeds on a draft" \
  wo amend --project "$d" --id "$id" --freedom "a single replacement freedom"
dof3=$(awk '/^## Degrees of freedom[[:space:]]*$/{f=1;next} /^## /{f=0} f && NF' "$f")
assert_eq '- [free] a single replacement freedom' "$dof3" \
  "amend replaced the whole section rather than appending to it"
assert_contains "$f" 'a 500 is retried three times' "amending freedoms left the criteria alone"
assert_contains "$f" 'changing the payload schema' "and the non-goals"
run 0 "frontmatter still parses after the amend" bash -c \
  "awk 'NR==1{next} /^---\$/{exit} {print}' '$f' | jq -e . >/dev/null"

# A freedom amended away leaves the fixed line, never an empty section.
run 0 "amend --freedom '' withdraws every freedom" wo amend --project "$d" --id "$id" --freedom ""
dof4=$(awk '/^## Degrees of freedom[[:space:]]*$/{f=1;next} /^## /{f=0} f && NF' "$f")
assert_eq '- [fixed] None declared: implement exactly as specified; raise a question before deviating.' \
  "$dof4" "withdrawing every freedom renders the fixed line, not an empty section"

# --- past draft, the freedoms are part of what was approved --------------------
wo amend --project "$d" --id "$id" --freedom "the approved freedom" >/dev/null
wo approve --project "$d" --id "$id" --no-lavish --reason "no lavish in CI" >/dev/null
run 3 "amend --freedom refuses a ready ticket" \
  wo amend --project "$d" --id "$id" --freedom "widening the freedoms after approval"
assert_contains "$f" '- [free] the approved freedom' "the approved freedoms are exactly what was approved"
assert_not_contains "$f" 'widening the freedoms' "and the refused amend wrote nothing"

# --- the guard still covers the new token --------------------------------------
# Unwire the token the way a future refactor might: leave it in the template with
# no case in render_body. The copy is the same technique case 150 uses, because
# the skill is mounted read-only.
sk="$WORK/skill-copy-250"
mkdir -p "$sk"
cp -r "$SKILL/scripts" "$SKILL/references" "$sk/"
sed -i 's/^%%DEGREES_OF_FREEDOM%%$/%%DEGREES_OF_FREEDOM_UNWIRED%%/' "$sk/references/ticket.tmpl"
assert_contains "$sk/references/ticket.tmpl" '%%DEGREES_OF_FREEDOM_UNWIRED%%' \
  "the doctored template carries the unwired token, so the sed matched the real one"
d5=$(new_project)
run 3 "an unwired degrees-of-freedom token refuses the write" \
  bash "$sk/scripts/work-order.sh" new --project "$d5" --title "Guarded" --type chore \
    --top-level --problem P --out X --ac "it works" --ac-check true --ac-exit 0 --owner-words W --context C
run 0 "and no ticket file was written" bash -c \
  "[ -z \"\$(find '$d5/work-orders' -name 'WO-*.md' 2>/dev/null)\" ]"
finish
