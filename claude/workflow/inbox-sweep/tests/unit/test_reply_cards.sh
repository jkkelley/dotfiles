#!/usr/bin/env bash
# AC-H1..H4 for reply-cards.sh. Rules out: a card that summarises or truncates the draft, a card with other than the
# three options, a rerun adding a second card or a second RP-AWAITING-OWNER row, an unanswered card producing a decision,
# an edited answer being trimmed or changed before it is hashed (the hash must be of the owner's bytes), a decision being
# rewritten when the owner later answers differently, Send with my edits with no words counting as an approval, and any
# record written without an integer schema_version.
set -uo pipefail
R="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=_t.sh
. "$R/tests/unit/_t.sh"
# shellcheck source=../lib/stubs.sh
. "$R/tests/lib/stubs.sh"
# shellcheck source=../lib/bg-scan.sh
. "$R/tests/lib/bg-scan.sh"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
export TEST_OUT="$T/out"
stubs_install "$T/bin"
# The stub's pane list is fixed; a real split adds a pane. Wrap it so `pane split` adds one and `pane list` shows it.
cp "$T/bin/herdr" "$T/bin/herdr.real"
cat >"$T/bin/herdr" <<'W'
#!/usr/bin/env bash
state="$TEST_OUT/split.state"
if [ "${1:-} ${2:-}" = "pane list" ]; then
  printf 'herdr %s\n' "$*" >>"$TEST_OUT/calls.log"
  if [ -f "$state" ]; then
    printf '{"result":{"panes":[{"pane_id":"wS:p1","label":"claude-main","tab_id":"wS:t1"},{"pane_id":"wS:p9","label":%s,"tab_id":"wS:t1"}]}}\n' "$(cat "$state")"
  else
    printf '{"result":{"panes":[{"pane_id":"wS:p1","label":"claude-main","tab_id":"wS:t1"}]}}\n'
  fi
  exit 0
fi
if [ "${1:-} ${2:-}" = "pane split" ]; then echo null >"$state"; fi
if [ "${1:-} ${2:-}" = "pane rename" ]; then printf '"%s"' "$4" >"$state"; fi
exec "$(dirname "$0")/herdr.real" "$@"
W
chmod +x "$T/bin/herdr"

export SWEEP_RUNS_ROOT="$T/runs" SWEEP_CARDS_FILE="$T/bearings/inbox-sweep/questions.json" SWEEP_BEARINGS_SERVER="/skills/bearings/server.mjs"
export SWEEP_LEDGER_FILE="$T/win/inbox-triage-20261016/ledger.jsonl"
S="$R/bin/reply-cards.sh"
run=20261016T010000Z
D="$SWEEP_RUNS_ROOT/$run"
mkdir -p "$D/reply/drafts" "$T/win/inbox-triage-20261016"
# Drafts with awkward bytes: a trailing newline, an apostrophe, a quote and a multi-line body must all survive untouched.
printf 'Hi Sam,\nThanks for the note - happy to talk.\nBest, J\n' >"$D/reply/drafts/t1.txt"
long="$(printf 'y%.0s' $(seq 1 3000))"
printf '%s' "$long" >"$D/reply/drafts/t2.txt"
printf 'It'"'"'s a "quote" test' >"$D/reply/drafts/t3.txt"
printf 'Hello again' >"$D/reply/drafts/t4.txt"
echo '{"code":"RP-DRAFTED","id":"t1","to":"Sam Example","thread_url":"https://www.linkedin.com/messaging/thread/example/"}' >"$SWEEP_LEDGER_FILE"
item() { jq -c --arg id "RP-$run-$1" '.items[] | select(.id == $id)' "$SWEEP_CARDS_FILE"; }
items() { jq '.items | length' "$SWEEP_CARDS_FILE"; }
awaiting() { jq -s '[.[] | select(.code == "RP-AWAITING-OWNER")] | length' "$SWEEP_LEDGER_FILE"; }

out="$(bash "$S" --run $run)"; rc=$?
check 0 "$rc" "first pass exits 0"

# AC-H1: the full draft text and exactly three options
check 4 "$(items)" "AC-H1: four drafts give four cards"
want="$(printf 'Hi Sam,\nThanks for the note - happy to talk.\nBest, J\n')"
check yes "$(item t1 | jq -r --arg w "$want" '.decide | contains($w) | if . then "yes" else "no" end')" "AC-H1: the card holds the full multi-line draft text"
check yes "$(item t2 | jq -r --arg l "$long" '.decide | endswith($l) | if . then "yes" else "no" end')" "AC-H1: a 3000 character draft is not truncated"
check yes "$(item t3 | jq -r '.decide | endswith("It'"'"'s a \"quote\" test") | if . then "yes" else "no" end')" "AC-H1: quotes and apostrophes survive"
check "Send as written,Send with my edits,Drop" "$(item t1 | jq -r '[.options[].label] | join(",")')" "AC-H1: the three options, in order"
check 3 "$(item t4 | jq '.options | length')" "AC-H1: exactly three options"
check yes "$(item t1 | jq -r '.decide | startswith("Nothing sends until you answer this card.") | if . then "yes" else "no" end')" "the card says nothing sends until it is answered"
check yes "$(item t1 | jq -r '.about | contains("Sam Example") and contains("linkedin.com/messaging/thread/example")' | sed 's/true/yes/')" "recipient and thread come from the RP-DRAFTED row"
check "LinkedIn reply draft t4" "$(item t4 | jq -r .about)" "no metadata still gives a card"

# AC-H3: unanswered stays RP-AWAITING-OWNER, writes no decision
check 4 "$(grep -c 'RP-AWAITING-OWNER' <<<"$out")" "AC-H3: all four cards are reported RP-AWAITING-OWNER"
check 4 "$(awaiting)" "AC-H3: one RP-AWAITING-OWNER ledger row per card"
check 0 "$(wc -l <"$D/reply/decisions.jsonl")" "AC-H3: no decision without an answer"

# AC-H2: a rerun adds no duplicate card and no duplicate ledger row; an existing card is not rewritten
jq '(.items[] | select(.id | test("-t4$")) | .decide) = "KEPT"' "$SWEEP_CARDS_FILE" >"$T/q" && mv "$T/q" "$SWEEP_CARDS_FILE"
bash "$S" --run $run >/dev/null
check 4 "$(items)" "AC-H2: a rerun leaves four cards"
check 4 "$(jq '[.items[].id] | unique | length' "$SWEEP_CARDS_FILE")" "AC-H2: ids stay unique"
check 4 "$(awaiting)" "AC-H2: a rerun adds no second RP-AWAITING-OWNER row"
check KEPT "$(item t4 | jq -r .decide)" "AC-H2: an existing card is not rewritten"
jq '(.items[] | select(.id | test("-t4$")) | .decide) = "Nothing sends until you answer this card. Full draft text:\n\nHello again"' "$SWEEP_CARDS_FILE" >"$T/q" && mv "$T/q" "$SWEEP_CARDS_FILE"

# Answers: the server appends to answers.jsonl beside questions.json
A="$(dirname "$SWEEP_CARDS_FILE")/answers.jsonl"
ans() { jq -cn --arg id "RP-$run-$1" --arg c "$2" --arg w "${3-}" '{id:$id, decide:"x", pick:0, choice:$c, words:$w, at:"2026-10-16T01:00:00.000Z"}' >>"$A"; }
ans t1 "Send as written"
edit="$(printf '  Sam,\n\ntrailing space and newline kept \nEnd\n')"
ans t2 "Send with my edits" "$edit"
ans t3 "Drop"
ans t4 "Send with my edits" ""
out="$(bash "$S" --run $run)"
dec() { jq -s --arg id "$1" '[.[] | select(.id == $id)] | last' "$D/reply/decisions.jsonl"; }

check RP-APPROVED "$(dec t1 | jq -r .code)" "Send as written is RP-APPROVED"
check "$(sha256sum "$D/reply/drafts/t1.txt" | cut -d' ' -f1)" "$(dec t1 | jq -r .sha256)" "as written: sha256 is of the draft file's bytes"
dec t1 | jq -j .text >"$T/t1.out"; cmp -s "$T/t1.out" "$D/reply/drafts/t1.txt"; check 0 "$?" "as written: the recorded text is the draft, byte for byte (trailing newline kept)"

check RP-APPROVED-EDITED "$(dec t2 | jq -r .code)" "Send with my edits is RP-APPROVED-EDITED"
printf '%s' "$edit" >"$T/edit.bin"
dec t2 | jq -j .text >"$T/t2.out"; cmp -s "$T/t2.out" "$T/edit.bin"; check 0 "$?" "edited: the recorded text is the owner's words, untrimmed"
check "$(sha256sum "$T/edit.bin" | cut -d' ' -f1)" "$(dec t2 | jq -r .sha256)" "edited: sha256 is of the owner's bytes, not of the draft"

check RP-DROPPED "$(dec t3 | jq -r .code)" "Drop is RP-DROPPED"
check null "$(dec t3 | jq -r '.text // "null"')" "Drop records no text"
check null "$(dec t3 | jq -r '.sha256 // "null"')" "Drop records no hash"

check 0 "$(jq -s --arg id t4 '[.[] | select(.id == $id)] | length' "$D/reply/decisions.jsonl")" "edits with empty words is not an approval"
check "t4 RP-AWAITING-OWNER" "$(grep '^t4 ' <<<"$out")" "AC-H3: and that card stays RP-AWAITING-OWNER"
check 3 "$(wc -l <"$D/reply/decisions.jsonl")" "three decisions written"

# A rerun adds no duplicate decision; a later different answer does not rewrite one
bash "$S" --run $run >/dev/null
check 3 "$(wc -l <"$D/reply/decisions.jsonl")" "AC-H2: a rerun adds no decision"
ans t1 "Drop"
out="$(bash "$S" --run $run)"
check RP-APPROVED "$(dec t1 | jq -r .code)" "a later different answer does not rewrite a decision"
check "t1 RP-APPROVED" "$(grep '^t1 ' <<<"$out")" "the reported code is the recorded one"
check yes "$(grep -q 't1: answer changed after decision' "$D/logs/reply-cards.log" && echo yes || echo no)" "and the change is logged"
# a card answered after the first pass is picked up on the next
ans t4 "Send with my edits" "ok then"
bash "$S" --run $run >/dev/null
check "ok then" "$(dec t4 | jq -r .text)" "a late answer is read on the next pass"
# an answer to a card of another run is ignored
jq -cn '{id:"RP-20200101T000000Z-t1", choice:"Drop", words:""}' >>"$A"
bash "$S" --run $run >/dev/null
check 4 "$(wc -l <"$D/reply/decisions.jsonl")" "an answer to another run's card is ignored"

# AC-H4: every record carries an integer schema_version
check 0 "$(jq -s '[.[] | select((.schema_version | type) != "number" or (.schema_version | floor) != .schema_version)] | length' "$D/reply/decisions.jsonl")" "AC-H4: decisions.jsonl rows have an integer schema_version"
check 0 "$(jq -s '[.[] | select(.code != "RP-DRAFTED") | select((.schema_version | type) != "number")] | length' "$SWEEP_LEDGER_FILE")" "AC-H4: the ledger rows written here have an integer schema_version"
check 0 "$(jq '[.items[] | select((.schema_version | type) != "number")] | length' "$SWEEP_CARDS_FILE")" "AC-H4: the cards have an integer schema_version"
check integer "$(jq -r '.schema_version | if type == "number" and floor == . then "integer" else "no" end' "$D/reply/answers.json")" "AC-H4: answers.json has an integer schema_version"
check 4 "$(jq '.answers | length' "$D/reply/answers.json")" "answers.json holds the latest answer per card"

# server: labeled pane via the shared helper, never a background job
grep -q 'herdr pane run .* node /skills/bearings/server.mjs inbox-sweep' "$TEST_OUT/calls.log"; check 0 "$?" "the Bearings server is started in a herdr pane when none is up"
bg_scan "$S" >/dev/null; check 0 "$?" "the script backgrounds nothing (Rule 18 scan)"

# failure paths
bash "$S" --run 20200101T000000Z >/dev/null 2>&1; check 3 "$?" "an unknown run exits 3"
bash "$S" --run nope >/dev/null 2>&1; check 2 "$?" "a bad run id exits 2"
bash "$S" >/dev/null 2>&1; check 2 "$?" "no arguments exits 2"
printf 'x' >"$D/reply/drafts/.bad name.txt"; before="$(items)"
bash "$S" --run $run >/dev/null 2>&1; check "$before" "$(items)" "a draft with an unsafe name makes no card"
finish
