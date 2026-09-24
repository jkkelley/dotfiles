#!/usr/bin/env bash
# S-05 M2: `done` racing `done`, or `move` racing `done`, must leave the item in
# exactly one place. The old code found SRC and read it, then landed a done copy
# under its own second's timestamp. A racer that finished in between had already
# removed SRC, but the late racer's ln still succeeded because its file name
# differed, so the tree held two files with one suffix and check went red.
#
# Two orderings, both forced rather than hoped for, and both through PATH shims
# that exist only in this case - no seam in the scripts themselves:
#
#   mid-flight  a chmod shim pauses the first racer inside ps_atomic_create,
#               after it has claimed SRC and before it lands. The second racer
#               finds no SRC at all, so its exit is find_item's (6), not the
#               claim's.
#   claim-loss  an mv shim pauses the second racer at claim_item's rename,
#               after find_item has passed. The first racer runs to completion
#               in that pause, so the rename fails and the loser takes the
#               claim-loss branches: land_in_done's "already done" (0) or
#               cmd_move's id_not_found (6). S-05 round 3 R1: without this
#               ordering no case executed those branches, and reverting them
#               left the suite green.
#
# The racers use different seconds on purpose - same-second racers collide on
# the file name and were always caught.
CASE_NAME=250-done-race
source "${SKILL:-/skill}/testing/assert.sh"

p=$(scaffolded_project)

# --- mid-flight: the loser dies in find_item ---------------------------------
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
assert_eq 0 "$slow_rc" "mid-flight done racing done: the claiming racer exits 0"
assert_eq 6 "$fast_rc" "mid-flight done racing done: the loser finds no SRC (find_item, 6)"
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
assert_eq 0 "$slow_rc" "mid-flight move racing done: the claiming done exits 0"
assert_eq 6 "$fast_rc" "mid-flight move racing done: the move finds no SRC (find_item, 6)"
assert_count 1 "$(find "$p/backlog" -name "*-${b}.md" | wc -l)" "move racing done leaves exactly one file"

# --- claim-loss: the loser passes find_item, then loses the rename -----------
# The mv shim pauses only a rename onto a .claim. name, which is claim_item's
# and nothing else on the done/move path. It signals that it has paused and
# waits for the go file, so the ordering is a handshake rather than a sleep.
# The 20-second cap turns a broken handshake into a red case, not a hang.
gate="$WORK/claim-gate"; mkdir -p "$gate/bin"
cat >"$gate/bin/mv" <<EOF
#!/bin/sh
for arg in "\$@"; do
  case \$arg in
    *.claim.*)
      : >"$gate/paused"
      n=0; while [ ! -e "$gate/go" ] && [ \$n -lt 200 ]; do sleep 0.1; n=\$((n + 1)); done
      break ;;
  esac
done
exec $(command -v mv) "\$@"
EOF
chmod +x "$gate/bin/mv"

# claim_loss <id> <loser-verb...> - start the loser behind the gate, wait until
# it is paused at the claim, run a plain done to completion, then open the gate.
# Sets LOSER_RC and WINNER_RC; the loser's output stays in $gate/out.
claim_loss() {
  local id="$1"; shift
  rm -f "$gate/paused" "$gate/go"
  PATH="$gate/bin:$PATH" SCAFFOLD_NOW=2026-08-05T15:00:04-05:00 \
    backlog "$@" --project "$p" --id "$id" >"$gate/out" 2>&1 &
  local loser=$! n=0
  while [ ! -e "$gate/paused" ] && [ $n -lt 200 ]; do sleep 0.1; n=$((n + 1)); done
  SCAFFOLD_NOW=2026-08-05T15:00:05-05:00 backlog done --project "$p" --id "$id" >/dev/null 2>&1
  WINNER_RC=$?
  : >"$gate/go"
  wait "$loser"; LOSER_RC=$?
}

# done racing done: the loser sees the item already landed in done.
c=$(backlog add --project "$p" --title "claim-loss done vs done" --why w --done-when d --bucket now 2>/dev/null)
claim_loss "$c" done
assert_file "$gate/paused" "claim-loss done racing done: the loser was paused past find_item"
assert_eq 0 "$WINNER_RC" "claim-loss done racing done: the winner exits 0"
assert_eq 0 "$LOSER_RC" "claim-loss done racing done: the loser exits 0"
assert_contains "$gate/out" "already done" "claim-loss done racing done: the loser reports already done"
assert_count 1 "$(find "$p/backlog" -name "*-${c}.md" | wc -l)" "claim-loss done racing done leaves exactly one file"
assert_count 1 "$(find "$p/backlog/done" -name "*-${c}.md" | wc -l)" "and that file is in done"

# move racing done: the loser's item is gone from its bucket, so it says so.
d=$(backlog add --project "$p" --title "claim-loss move vs done" --why w --done-when d --bucket now 2>/dev/null)
claim_loss "$d" move --to next
assert_file "$gate/paused" "claim-loss move racing done: the loser was paused past find_item"
assert_eq 0 "$WINNER_RC" "claim-loss move racing done: the done exits 0"
assert_eq 6 "$LOSER_RC" "claim-loss move racing done: the move exits 6 (id_not_found)"
assert_count 1 "$(find "$p/backlog" -name "*-${d}.md" | wc -l)" "claim-loss move racing done leaves exactly one file"
assert_count 0 "$(find "$p/backlog/next" -name "*-${d}.md" | wc -l)" "and nothing landed in next"

assert_count 0 "$(find "$p/backlog" -type f ! -name '*.md' ! -name .gitkeep | wc -l)" "no claim file is left behind"
run 0 "check is green after the races" backlog check --project "$p"

finish
