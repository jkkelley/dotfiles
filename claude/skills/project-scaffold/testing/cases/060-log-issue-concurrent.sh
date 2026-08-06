#!/usr/bin/env bash
# Parallel agents are normal. Two writers racing for the next ID would silently
# lose an entry, so this asserts every writer got a distinct ID and every entry
# survived.
CASE_NAME=060-log-issue-concurrent
source "${SKILL:-/skill}/testing/assert.sh"

p=$(scaffolded_project)
N=8

for i in $(seq 1 $N); do
  log_issue --project "$p" --title "concurrent $i" --severity low --area race \
    --symptom s --trigger t --cause c --fix f --verify v >/dev/null 2>&1 &
done
wait

total=$(grep -cE '^id: ISS-' "$p/ISSUES.md")
unique=$(grep -oE '^id: ISS-[0-9]{4}' "$p/ISSUES.md" | sort -u | wc -l)
assert_count "$N" "$total" "every concurrent write landed"
assert_count "$N" "$unique" "every ID is distinct"

# IDs must be dense: a gap means an allocation was computed but lost.
highest=$(grep -oE '^id: ISS-[0-9]{4}' "$p/ISSUES.md" | grep -oE '[0-9]{4}$' | sort -n | tail -1)
assert_eq "$(printf '%04d' $N)" "$highest" "no gaps in the ID sequence"

finish
