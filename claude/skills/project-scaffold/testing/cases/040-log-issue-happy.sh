#!/usr/bin/env bash
# The happy path, plus the two properties the sliding window depends on:
# newest-first ordering and resolution-by-new-entry.
CASE_NAME=040-log-issue-happy
source "${SKILL:-/skill}/testing/assert.sh"

p=$(scaffolded_project)

capture id1 log_issue --project "$p" --title "First" --severity high --area export \
  --symptom s --trigger t --cause c --fix f --verify v
assert_eq "ISS-0001" "$id1" "first ID allocated"

capture id2 log_issue --project "$p" --title "Second" --severity low --area ui \
  --symptom s --trigger t --cause c --fix f --verify v
assert_eq "ISS-0002" "$id2" "IDs increment"

# Newest on top: the first heading in the file must be the newest entry.
first_heading=$(grep -m1 -E '^## ISS-' "$p/ISSUES.md")
assert_eq "## ISS-0002 - Second" "$first_heading" "newest entry is on top"

run 0 "resolving entry accepted" log_issue --project "$p" --resolves "$id1" \
  --title "First fixed" --severity high --area export \
  --symptom s --trigger t --cause c --fix f --verify v
assert_contains "$p/ISSUES.md" "resolves: ISS-0001" "resolution recorded"
assert_count 1 "$(grep -c '^## ISS-0001' "$p/ISSUES.md")" "original entry not rewritten"

# The file is created from the template when it does not exist yet.
q=$(new_project)
run 0 "creates ISSUES.md when absent" log_issue --project "$q" --title T --severity low \
  --area a --symptom s --trigger t --cause c --fix f --verify v
assert_contains "$q/ISSUES.md" "ISSUES:BEGIN" "created file carries the sentinel"

finish
