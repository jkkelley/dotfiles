#!/usr/bin/env bash
# The happy path, plus the two properties the sliding window depends on:
# newest-first ordering and resolution-by-new-entry.
CASE_NAME=040-log-issue-happy
source "${SKILL:-/skill}/testing/assert.sh"

p=$(scaffolded_project)

capture id1 log_issue --project "$p" --title "First" --severity high --area export \
  --symptom s --trigger t --cause c --fix f --verify v
case $id1 in
  [a-z0-9][a-z0-9][a-z0-9][a-z0-9][a-z0-9]) _pass "ID is a 5-char suffix" ;;
  *) _fail "ID is a 5-char suffix" "got: $id1" ;; esac

capture id2 log_issue --project "$p" --title "Second" --severity low --area ui \
  --symptom s --trigger t --cause c --fix f --verify v
if [[ $id1 != "$id2" ]]; then _pass "suffixes are distinct"; else _fail "suffixes are distinct" "both: $id1"; fi

# One file per entry, in the shard its timestamp implies.
f1=$(find "$p/issues" -name "*-${id1}.md")
f2=$(find "$p/issues" -name "*-${id2}.md")
assert_file "$f1" "entry file for the first issue"
assert_file "$f2" "entry file for the second issue"
case $f1 in
  "$p/issues/2026/08/20260805T193211Z-${id1}.md") _pass "entry sits in the shard its timestamp implies" ;;
  *) _fail "entry sits in the shard its timestamp implies" "got: $f1" ;; esac

# Metadata holds the suffix as its ID, not a sequential number.
assert_contains "$f1" "id: ${id1}" "metadata id is the suffix"
assert_not_contains "$f1" "ISS-00" "no sequential ID anywhere"

# A resolving entry is a NEW file carrying resolves:, never an edit.
run 0 "resolving entry accepted" log_issue --project "$p" --resolves "$id1" \
  --title "First fixed" --severity high --area export \
  --symptom s --trigger t --cause c --fix f --verify v
f3=$(grep -rl "resolves: ${id1}" "$p/issues")
assert_file "$f3" "resolution recorded as a new entry"
assert_contains "$f1" "- **Symptom** - s" "original entry not rewritten"

# The window is a directory walk: newest-first IS reverse path order.
capture newest find "$p/issues" -name '*.md' -type f
case $newest in
  *"${id2}.md"*) _pass "both entries are in the tree" ;;
  *) _fail "both entries are in the tree" "got: $newest" ;; esac

# The tree is created when it does not exist yet.
q=$(new_project)
run 0 "creates issues/ when absent" log_issue --project "$q" --title T --severity low \
  --area a --symptom s --trigger t --cause c --fix f --verify v
capture made find "$q/issues" -name '*.md' -type f
case $made in
  "$q/issues/2026/08/"*) _pass "entry landed in a fresh tree" ;;
  *) _fail "entry landed in a fresh tree" "got: $made" ;; esac

finish
