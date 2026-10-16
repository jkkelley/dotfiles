#!/usr/bin/env bash
# The reason this case exists.
#
# Owner, item 30: a job carries the owner's words verbatim and the full context
# behind it, so nothing is lost between design and build. A ticket that can be
# minted without them loses the idea at the first handoff, so `new` refuses it.
# Every refusal here calls work-order.sh directly: wo() would supply the very
# defaults whose absence is under test.
source "${SKILL:-/skill}/testing/assert.sh"

wos() { bash "$SKILL/scripts/work-order.sh" "$@"; }
d=$(new_project)
base=(--project "$d" --title "Words matter" --type feature --problem P --top-level --out X
      --ac "it works" --ac-check true --ac-exit 0)

run 3 "new without --owner-words is refused" wos new "${base[@]}" --context C
run 0 "the refusal is named missing_owner_words" bash -c \
  "bash '$SKILL/scripts/work-order.sh' new ${base[*]@Q} --context C --json 2>&1 | jq -e '.error == \"missing_owner_words\"' >/dev/null"
run 3 "new without --context is refused" wos new "${base[@]}" --owner-words W
run 0 "the refusal is named missing_context" bash -c \
  "bash '$SKILL/scripts/work-order.sh' new ${base[*]@Q} --owner-words W --json 2>&1 | jq -e '.error == \"missing_context\"' >/dev/null"
run 3 "a blank --owner-words does not count" wos new "${base[@]}" --owner-words "  " --context C
assert_no_file "$d/work-orders" "the refused runs left no work-orders directory"

run 0 "new with both flags succeeds" wos new "${base[@]}" \
  --owner-words "first the owner said this" --owner-words "then this" \
  --context "the background" --context "a second idea"
f=$(find "$d/work-orders" -name 'WO-*.md')
assert_contains "$f" '## Owner words' "the Owner words section is rendered"
assert_contains "$f" '> first the owner said this' "the first owner quote is verbatim"
assert_contains "$f" '> then this' "the second owner quote is verbatim"
assert_contains "$f" '## Context' "the Context section is rendered"
assert_contains "$f" 'a second idea' "every --context is kept"
assert_contains "$f" '- Owner words' "the contents list names the new section"
finish
