#!/usr/bin/env bash
# cache.sh is gone, and nothing still points at it.
#
# The directory of small files is the cheap window (S-03, decision D4): the
# newest 10 paths are the newest 10 entries, so a derived JSON copy of them only
# added a staleness check to forget. A reference left behind is worse than the
# script was - a doc telling an agent to run `cache.sh verify` before trusting a
# slice sends it to a command that exits 127, and a vendoring list naming the
# file makes every scaffold run die on a missing source.
CASE_NAME=220-cache-gone
source "${SKILL:-/skill}/testing/assert.sh"

assert_no_file "$SKILL/scripts/cache.sh" "scripts/cache.sh is deleted"

# Every file in the skill except this one, which has to name what it hunts.
hits=$(grep -rlF "cache.sh" "$SKILL" --exclude="$(basename "${BASH_SOURCE[0]}")" || true)
if [[ -z $hits ]]; then _pass "no file in the skill references cache.sh"; else
  _fail "no file in the skill references cache.sh" "found in: $(printf '%s ' $hits)"; fi

p=$(scaffolded_project)
assert_no_file "$p/.claude/scripts/cache.sh" "scaffold vendors no cache.sh"
capture plan scaffold --project "$p" --json
assert_not_contains <(printf '%s' "$plan") "cache.sh" "the plan names no cache.sh"

finish
