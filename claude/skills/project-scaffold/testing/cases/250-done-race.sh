#!/usr/bin/env bash
# S-05 M2: `done` racing `done`, or `move` racing `done`, must leave the item in
# exactly one place. The old code found SRC and read it, then landed a done copy
# under its own second's timestamp. A racer that finished in between had already
# removed SRC, but the late racer's ln still succeeded because its file name
# differed, so the tree held two files with one suffix and check went red.
#
# The race is forced, not hoped for: a chmod shim on the slow racer's PATH pauses
# it inside ps_atomic_create, after SRC is read and before the ln, and the fast
# racer runs to completion in that pause. The racers use different seconds on
# purpose - same-second racers collide on the file name and were always caught.
CASE_NAME=250-done-race
source "${SKILL:-/skill}/testing/assert.sh"

p=$(scaffolded_project)
shim="$WORK/slow-chmod"; mkdir -p "$shim"
printf '#!/bin/sh\nsleep 3\nexec %s "$@"\n' "$(command -v chmod)" >"$shim/chmod"
chmod +x "$shim/chmod"

slow_done() { PATH="$shim:$PATH" SCAFFOLD_NOW=2026-08-05T15:00:01-05:00 backlog done --project "$p" --id "$1" >/dev/null 2>&1; }

# done racing done
a=$(backlog add --project "$p" --title "done vs done" --why w --done-when d --bucket now 2>/dev/null)
slow_done "$a" &
slow=$!
sleep 1
SCAFFOLD_NOW=2026-08-05T15:00:02-05:00 backlog done --project "$p" --id "$a" >/dev/null 2>&1
fast_rc=$?
wait "$slow"; slow_rc=$?
# S-05 round 2 N3: the exit codes are the contract, not only the final count.
# The slow racer claims first, so it must land (0). The fast one is the loser:
# 6 if it arrives while the winner is mid-flight, 0 ("already done") if after.
# Anything else - 3, or a 0 that also wrote - fails here or in the counts.
assert_eq 0 "$slow_rc" "done racing done: the claiming racer exits 0"
case $fast_rc in
  0 | 6) _pass "done racing done: the loser exits a documented code (got $fast_rc)" ;;
  *) _fail "done racing done: the loser exits a documented code" "got $fast_rc, want 0 or 6" ;; esac
assert_count 1 "$(find "$p/backlog" -name "*-${a}.md" | wc -l)" "done racing done leaves exactly one file"
assert_count 1 "$(find "$p/backlog/done" -name "*-${a}.md" | wc -l)" "and that file is in done"

# move racing done
b=$(backlog add --project "$p" --title "move vs done" --why w --done-when d --bucket now 2>/dev/null)
slow_done "$b" &
slow=$!
sleep 1
SCAFFOLD_NOW=2026-08-05T15:00:03-05:00 backlog move --project "$p" --id "$b" --to next >/dev/null 2>&1
fast_rc=$?
wait "$slow"; slow_rc=$?
assert_eq 0 "$slow_rc" "move racing done: the claiming done exits 0"
assert_eq 6 "$fast_rc" "move racing done: the fast move exits 6 (id_not_found)"
assert_count 1 "$(find "$p/backlog" -name "*-${b}.md" | wc -l)" "move racing done leaves exactly one file"

assert_count 0 "$(find "$p/backlog" -type f ! -name '*.md' ! -name .gitkeep | wc -l)" "no claim file is left behind"
run 0 "check is green after the races" backlog check --project "$p"

finish
