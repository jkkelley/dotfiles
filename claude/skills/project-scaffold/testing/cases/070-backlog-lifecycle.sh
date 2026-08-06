#!/usr/bin/env bash
# add -> move -> done, plus the refusals. The move must preserve the item body
# byte for byte, which is the whole reason move is a script and not an edit.
CASE_NAME=070-backlog-lifecycle
source "${SKILL:-/skill}/testing/assert.sh"

p=$(scaffolded_project)

capture b1 backlog add --project "$p" --title "First" --why W1 --done-when D1 --bucket next
assert_eq "BK-0001" "$b1" "first backlog ID"
capture b2 backlog add --project "$p" --title "Second" --why W2 --done-when D2 --bucket later
assert_eq "BK-0002" "$b2" "IDs increment across buckets"

run 0 "move to now" backlog move --project "$p" --id "$b1" --to now
capture listing backlog list --project "$p" --bucket now --json
assert_eq 0 "$(printf '%s' "$listing" | grep -c 'BK-0002')" "only the moved item is in now"
case $listing in *'"id":"BK-0001"'*'"bucket":"now"'*) _pass "item reports its new bucket" ;;
  *) _fail "item reports its new bucket" "got: $listing" ;; esac

# why/done-when must survive the move untouched.
assert_contains "$p/BACKLOG.md" "- why: W1" "why preserved across the move"
assert_contains "$p/BACKLOG.md" "- done-when: D1" "done-when preserved across the move"

run 0 "move to the same bucket is a no-op" backlog move --project "$p" --id "$b1" --to now

run 0 "done" backlog done --project "$p" --id "$b1"
assert_contains "$p/BACKLOG.md" "- [x] **BK-0001**" "checkbox flipped"
assert_contains "$p/BACKLOG.md" "completed: " "completion date recorded in metadata"
capture done_list backlog list --project "$p" --bucket done --json
case $done_list in *'"title":"First"'*) _pass "title unpolluted by the completion date" ;;
  *) _fail "title unpolluted by the completion date" "got: $done_list" ;; esac

run 6 "unknown ID" backlog move --project "$p" --id BK-9999 --to now
run 3 "unknown bucket" backlog move --project "$p" --id "$b2" --to somewhere
run 2 "malformed ID" backlog move --project "$p" --id nonsense --to now
run 2 "unknown subcommand" backlog frobnicate --project "$p"
run 2 "add without done-when" bash -c \
  "bash '$SKILL/scripts/backlog.sh' add --project '$p' --title T --why W"

# An ID appearing twice is ambiguous: refuse rather than pick one.
q=$(scaffolded_project)
backlog add --project "$q" --title Dup --why W --done-when D --bucket now >/dev/null
awk '/^- \[ \] \*\*BK-0001\*\*/ { print; print; next } { print }' "$q/BACKLOG.md" >"$WORK/dup.md"
cp "$WORK/dup.md" "$q/BACKLOG.md"
run 3 "duplicate ID is refused" backlog move --project "$q" --id BK-0001 --to later

finish
