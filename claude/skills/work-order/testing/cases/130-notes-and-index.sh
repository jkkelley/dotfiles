#!/usr/bin/env bash
# Notes and the index gate. Both exist so that the record of a ticket's progress
# is written by a tool: a hand-edited note is the failure this skill removes, and
# an index that silently disagrees with the tickets misroutes the next agent.
source "${SKILL:-/skill}/testing/assert.sh"

read -r d id <<<"$(drafted_project)"
f=$(find "$d/work-orders" -name 'WO-*.md')

assert_contains "$f" "## Notes" "a new ticket carries an empty Notes section"

run 0 "note appends" wo note --project "$d" --id "$id" --text "stood up the namespace"
run 0 "note appends again" wo note --project "$d" --id "$id" --text "second, newer"
run 2 "note refuses an empty text" wo note --project "$d" --id "$id" --text ""

# Newest first, matching ISSUES.md: reading top-down meets the latest state
# before the history that produced it.
first=$(grep -n 'second, newer' "$f" | cut -d: -f1)
second=$(grep -n 'stood up the namespace' "$f" | cut -d: -f1)
run 0 "the newer note is above the older one" bash -c "[ $first -lt $second ]"

# The explanatory line stays put, and Outcome stays last.
notes_line=$(grep -n '^## Notes' "$f" | cut -d: -f1)
outcome_line=$(grep -n '^## Outcome' "$f" | cut -d: -f1)
run 0 "Outcome is still the last section" bash -c "[ $notes_line -lt $outcome_line ]"

run 0 "frontmatter still parses after a note" bash -c \
  "awk 'NR==1{next} /^---\$/{exit} {print}' '$f' | jq -e . >/dev/null"

# A note must never be mistaken for an acceptance criterion.
run 0 "a note is not a checkbox" bash -c \
  "! awk '/^## Notes/{n=1;next} /^## /{n=0} n' '$f' | grep -q '^- \[ \]'"

# The index check. INDEX.md is an untracked build output (WO-20261016-565d), so
# the check generates and validates; it does not compare against a file on disk.
run 0 "reindex --check passes on a generated index" wo reindex --project "$d" --check
printf 'hand edited\n' >>"$d/work-orders/INDEX.md"
run 0 "reindex --check ignores a drifted local index" wo reindex --project "$d" --check
run 0 "reindex rebuilds it" wo reindex --project "$d"
run 0 "and the check passes again" wo reindex --project "$d" --check
