#!/usr/bin/env bash
# add -> move -> done, plus the refusals. A move is a rename between bucket
# directories and must preserve the item byte for byte, which is the whole
# reason move is a script and not an edit.
CASE_NAME=070-backlog-lifecycle
source "${SKILL:-/skill}/testing/assert.sh"

p=$(scaffolded_project)

capture b1 backlog add --project "$p" --title "First" --why W1 --done-when D1 --bucket next
case $b1 in
  [a-z0-9][a-z0-9][a-z0-9][a-z0-9][a-z0-9]) _pass "ID is a 5-char suffix" ;;
  *) _fail "ID is a 5-char suffix" "got: $b1" ;; esac
capture b2 backlog add --project "$p" --title "Second" --why W2 --done-when D2 --bucket later
if [[ $b1 != "$b2" ]]; then _pass "suffixes are distinct across buckets"; else _fail "suffixes are distinct across buckets" "both: $b1"; fi

f1=$(find "$p/backlog" -name "*-${b1}.md")
case $f1 in
  "$p/backlog/next/"*) _pass "item landed in its bucket directory" ;;
  *) _fail "item landed in its bucket directory" "got: $f1" ;; esac

run 0 "move to now" backlog move --project "$p" --id "$b1" --to now
moved=$(find "$p/backlog" -name "*-${b1}.md")
case $moved in
  "$p/backlog/now/"*) _pass "move is a rename between bucket directories" ;;
  *) _fail "move is a rename between bucket directories" "got: $moved" ;; esac
capture listing backlog list --project "$p" --bucket now --json
assert_eq 0 "$(printf '%s' "$listing" | grep -c "$b2")" "only the moved item is in now"
case $listing in *"\"id\":\"$b1\""*'"bucket":"now"'*) _pass "item reports its new bucket" ;;
  *) _fail "item reports its new bucket" "got: $listing" ;; esac

# why/done-when must survive the move untouched.
assert_contains "$moved" "- why: W1" "why preserved across the move"
assert_contains "$moved" "- done-when: D1" "done-when preserved across the move"

run 0 "move to the same bucket is a no-op" backlog move --project "$p" --id "$b1" --to now

run 0 "done" backlog done --project "$p" --id "$b1"
done_file=$(find "$p/backlog/done" -name "*-${b1}.md")
assert_file "$done_file" "item landed in the done shard"
case $done_file in
  "$p/backlog/done/2026/08/"*) _pass "done shard matches the completion time" ;;
  *) _fail "done shard matches the completion time" "got: $done_file" ;; esac
assert_contains "$done_file" "completed: " "completion recorded in metadata"
assert_no_file "$moved" "the live copy is gone after done"
capture done_list backlog list --project "$p" --bucket done --json
case $done_list in *'"title":"First"'*) _pass "title unpolluted by the completion date" ;;
  *) _fail "title unpolluted by the completion date" "got: $done_list" ;; esac

run 0 "done again is a reported no-op" backlog done --project "$p" --id "$b1"

run 6 "unknown ID" backlog move --project "$p" --id zzzzz --to now
run 3 "unknown bucket" backlog move --project "$p" --id "$b2" --to somewhere
run 2 "malformed ID" backlog move --project "$p" --id BK-0014 --to now
run 2 "unknown subcommand" backlog frobnicate --project "$p"
run 2 "add without done-when" bash -c \
  "bash '$SKILL/scripts/backlog.sh' add --project '$p' --title T --why W"

# A suffix appearing twice is ambiguous: refuse rather than pick one.
q=$(scaffolded_project)
backlog add --project "$q" --title Dup --why W --done-when D --bucket now >/dev/null
dup=$(find "$q/backlog" -name '*.md' -type f)
mkdir -p "$q/backlog/later"
cp "$dup" "$q/backlog/later/20260805T193211Z-$(basename "$dup" | sed 's/.*-//')"
run 3 "duplicate suffix is refused" backlog move --project "$q" --id "$(basename "$dup" .md | sed 's/.*-//')" --to later

finish
