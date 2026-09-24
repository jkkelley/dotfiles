#!/usr/bin/env bash
# The money property (dotfiles #95): parallel agents are normal. Under the old
# monolith, eight writers raced for the next sequential ID inside one locked
# file - and git saw one file touched by every writer, so merges conflicted
# even when the lock held. One file per entry, uniquely named at mint time,
# means no lock, no lost write, and no merge collision. This case is the proof.
CASE_NAME=060-log-issue-concurrent
source "${SKILL:-/skill}/testing/assert.sh"

p=$(scaffolded_project)
N=8

# SCAFFOLD_NOW is fixed for the whole suite, so all N writers mint the SAME
# timestamp into the SAME shard - the worst case, not a convenient one.
for i in $(seq 1 $N); do
  log_issue --project "$p" --title "concurrent $i" --severity low --area race \
    --symptom s --trigger t --cause c --fix f --verify v >/dev/null 2>&1 &
done
wait

total=$(find "$p/issues" -name '*.md' -type f | wc -l)
unique=$(find "$p/issues" -name '*.md' -type f -printf '%f\n' | sort -u | wc -l)
assert_count "$N" "$total" "every concurrent write landed"
assert_count "$N" "$unique" "every entry file has a distinct name"

# No writer saw a lock timeout (exit 5) or any failure: the count above is the
# assertion - a failed write would have reduced it. And the tree the race left
# behind must validate clean.
run 0 "check is green after concurrent writes" log_issue check --project "$p"

finish
