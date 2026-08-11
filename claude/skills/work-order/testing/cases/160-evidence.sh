#!/usr/bin/env bash
# evidence, and the gate it exists to serve.
#
# `new --ac` writes an unchecked box and done refuses while one is still
# unchecked. That gate is correct, so the assertion that earns its keep here is
# not that evidence works - it is that done is *still* refused while any
# criterion is unobserved. What was broken was the absence of a verb that could
# record an observation: every ticket in a repository could only reach done by
# hand editing the file, which is the one thing this skill exists to prevent.
source "${SKILL:-/skill}/testing/assert.sh"

d=$(git_project)
bin=$(gh_stub "$d/.bin" MERGED)
export PATH="$bin:$PATH"

wo new --project "$d" --title "Two criteria" --type feature --problem P \
   --out X --ac "the cart renders empty" --ac "the DNS record resolves" >/dev/null
id=$(wo list --project "$d" --json | jq -r '.[0].id')
f=$(find "$d/work-orders" -name 'WO-*.md')

# --- the refusals, all of which must happen before anything is written --------
run 6 "an unknown ticket id is not found" \
  wo evidence --project "$d" --id WO-20260805-ffff --index 1 --observed "seen"
run 2 "an observation is mandatory - a box ticked without one is just a claim" \
  wo evidence --project "$d" --id "$id" --index 1
run 2 "a selector is mandatory" wo evidence --project "$d" --id "$id" --observed "seen"
run 2 "--index and --match together is a usage error" \
  wo evidence --project "$d" --id "$id" --index 1 --match cart --observed "seen"
run 2 "a non-numeric index is a usage error" \
  wo evidence --project "$d" --id "$id" --index two --observed "seen"
run 3 "an out-of-range index is refused" \
  wo evidence --project "$d" --id "$id" --index 3 --observed "seen"
run 3 "a match that hits nothing is refused" \
  wo evidence --project "$d" --id "$id" --match "billing" --observed "seen"
run 3 "an ambiguous match is refused rather than guessed" \
  wo evidence --project "$d" --id "$id" --match "the" --observed "seen"
assert_contains "$f" '- [ ] `AC-H1` *(human)* the cart renders empty' \
  "no refusal touched the ticket"

# --- the happy path ----------------------------------------------------------
run 0 "evidence records an observation" \
  wo evidence --project "$d" --id "$id" --index 1 --observed "empty cart rendered at both breakpoints"
assert_contains "$f" '- [x] `AC-H1` *(human)* the cart renders empty' "the box is checked"
assert_contains "$f" 'empty cart rendered at both breakpoints' "the observation is recorded"
assert_contains "$f" '- observed `2026-08-05`' "the observation carries the date it was made"
assert_contains "$f" '- [ ] `AC-H2` *(human)* the DNS record resolves' \
  "the other criterion is untouched"

# evidence changes the record, never the state. It carries no status check at
# all, so nothing about where a ticket sits can block writing down what was seen.
run 0 "evidence leaves the status alone" bash -c \
  "bash '$SKILL/scripts/work-order.sh' show --project '$d' --id '$id' --json | jq -e '.status == \"draft\"' >/dev/null"
run 0 "frontmatter still parses after an evidence" bash -c \
  "awk 'NR==1{next} /^---\$/{exit} {print}' '$f' | jq -e . >/dev/null"

run 3 "an already-evidenced criterion is refused, by name" \
  wo evidence --project "$d" --id "$id" --index 1 --observed "again"

# THE assertion. One observed, one outstanding: the gate must still hold.
wo approve --project "$d" --id "$id" --no-lavish --reason "no lavish in CI" >/dev/null
wo start --project "$d" --id "$id" >/dev/null
wo submit --project "$d" --id "$id" --pr 7 >/dev/null
run 3 "done still refuses while any criterion is unobserved" \
  wo done --project "$d" --id "$id"

# An error that says what is wrong and not what to run leaves the caller to
# rediscover the verb, which is how the hand edit gets invented in the first place.
wo done --project "$d" --id "$id" 2>"$d/done-refusal.txt" || true
assert_contains "$d/done-refusal.txt" "work-order.sh evidence" \
  "the refusal names the verb that records an observation"

run 0 "the second criterion evidences by substring" \
  wo evidence --project "$d" --id "$id" --match "DNS" --observed "dig returned the A record"
run 0 "only now does the ticket reach done" wo done --project "$d" --id "$id"
assert_contains "$f" '"status": "done"' "done was reached through script verbs alone"
assert_contains "$f" 'dig returned the A record' "both observations survive into the done ticket"

run 0 "evidence --json emits parseable JSON" bash -c \
  "bash '$SKILL/scripts/work-order.sh' evidence --project '$d' --id '$id' --index 1 \
     --observed x --json | jq -e '.error == \"already_evidenced\"' >/dev/null"

# A ticket with no criteria has nowhere to put an observation, and says so.
d2=$(new_project)
wo new --project "$d2" --title "No criteria" --type chore --problem P --out X >/dev/null
id2=$(wo list --project "$d2" --json | jq -r '.[0].id')
run 3 "a ticket with no acceptance criteria refuses" \
  wo evidence --project "$d2" --id "$id2" --index 1 --observed "n/a"
finish
