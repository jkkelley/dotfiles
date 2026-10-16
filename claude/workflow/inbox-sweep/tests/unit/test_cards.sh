#!/usr/bin/env bash
# AC-H1..H4 for sweep-cards.sh. Rules out: a rerun appending the same card again, two seats with one BLOCKED code giving
# two cards (or one code giving none), a draft card that carries a summary instead of the draft text, an existing
# (possibly answered) card being rewritten, a server started with a background job instead of a labeled pane, and a
# second server started when one is already up.
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
S="$R/bin/sweep-cards.sh"
run=20261016T010000Z
D="$SWEEP_RUNS_ROOT/$run"
mkdir -p "$D/results"
echo '{"run_id":"'$run'","status":"RUN-PARTIAL"}' >"$D/summary.json"
F="$R/tests/fixtures/results"
seat() { jq --arg s "$2" '.seat=$s' "$F/$1.json" >"$D/results/$2.json"; }
seat BLOCKED-NO-BROWSER proton-first
seat BLOCKED-NO-BROWSER proton-second
seat BLOCKED-CHALLENGE proton-third
seat BLOCKED-CONNECTOR gmail
seat BLOCKED-SIGNED-OUT linkedin2
cp "$F/OK-linkedin-with-draft.json" "$D/results/linkedin.json"
echo '{"checks":[{"id":"chrome","code":"PF-NO-CHROME"},{"id":"herdr","code":"PF-OK"}]}' >"$D/preflight.json"
items() { jq '.items | length' "$SWEEP_CARDS_FILE"; }
has() { jq -r --arg id "$1" '[.items[] | select(.id == $id)] | length' "$SWEEP_CARDS_FILE"; }

bash "$S" --run $run >/dev/null; rc=$?
check 0 "$rc" "first run exits 0"
# 4 distinct BLOCKED codes (NO-BROWSER x2 seats, CHALLENGE, CONNECTOR, SIGNED-OUT) + 1 preflight + 1 decision + 1 draft
check 7 "$(items)" "seven cards: four blocked codes, one preflight code, one owner decision, one draft"

# AC-H2: one card per BLOCKED code, whatever the seat count
check 1 "$(has "IS-$run-proton-first-B-BLOCKED-NO-BROWSER")" "AC-H2: BLOCKED-NO-BROWSER gives one card"
check 0 "$(has "IS-$run-proton-second-B-BLOCKED-NO-BROWSER")" "AC-H2: the second seat with the same code gets no second card"
check yes "$(jq -r '.items[] | select(.id == "IS-'$run'-proton-first-B-BLOCKED-NO-BROWSER") | .about | contains("also proton-second") | if . then "yes" else "no" end' "$SWEEP_CARDS_FILE")" "the card names the other seat"
check 1 "$(has "IS-$run-proton-third-B-BLOCKED-CHALLENGE")" "AC-H2: BLOCKED-CHALLENGE gives one card"
check 1 "$(has "IS-$run-gmail-B-BLOCKED-CONNECTOR")" "AC-H2: BLOCKED-CONNECTOR gives one card"
check 1 "$(has "IS-$run-linkedin2-B-BLOCKED-SIGNED-OUT")" "AC-H2: BLOCKED-SIGNED-OUT gives one card"
check 1 "$(has "IS-$run-preflight-B-PF-NO-CHROME")" "AC-H2: PF-NO-CHROME gives one card; PF-OK gives none"
check "Orchestrator runs make sweep-proton" "$(jq -r '.items[] | select(.id|test("proton-first-B")) | .options[0].then' "$SWEEP_CARDS_FILE")" "the blocked card's rerun option names the source"
check 2 "$(jq -r '.items[] | select(.id|test("-B-")) | .options|length' "$SWEEP_CARDS_FILE" | sort -u)" "every blocked card has the two spec options"

# owner decision keeps the seat's own words
check "linkedin linkedin: c1" "$(jq -r '.items[] | select(.id == "IS-'$run'-linkedin-Q1") | .about' "$SWEEP_CARDS_FILE")" "decision about is '<source> <account>: <about>'"
check "Send the draft?" "$(jq -r '.items[] | select(.id == "IS-'$run'-linkedin-Q1") | .decide' "$SWEEP_CARDS_FILE")" "decision text is copied"

# AC-H3: the draft card carries the full draft text
draft="$(jq -r '.drafts[0].draft_text' "$F/OK-linkedin-with-draft.json")"
check "Approve this draft? Full text: $draft" "$(jq -r '.items[] | select(.id == "IS-'$run'-linkedin-D1") | .decide' "$SWEEP_CARDS_FILE")" "AC-H3: the draft card carries the full draft text"
check "Approve,Edit,Drop" "$(jq -r '.items[] | select(.id == "IS-'$run'-linkedin-D1") | [.options[].label] | join(",")' "$SWEEP_CARDS_FILE")" "AC-H3: Approve, Edit, Drop"
check "LinkedIn reply to Sender in c1" "$(jq -r '.items[] | select(.id == "IS-'$run'-linkedin-D1") | .about' "$SWEEP_CARDS_FILE")" "draft about names the recipient and conversation"
long="$(printf 'x%.0s' $(seq 1 3000))"
jq --arg t "$long" '.drafts[0].draft_text=$t' "$F/OK-linkedin-with-draft.json" >"$D/results/linkedin.json"
rm "$SWEEP_CARDS_FILE"; bash "$S" --run $run >/dev/null
check 3031 "$(jq -r '.items[] | select(.id == "IS-'$run'-linkedin-D1") | .decide | length' "$SWEEP_CARDS_FILE")" "AC-H3: a 3000 character draft is not truncated"
cp "$F/OK-linkedin-with-draft.json" "$D/results/linkedin.json"; rm "$SWEEP_CARDS_FILE"; bash "$S" --run $run >/dev/null

# AC-H1: a rerun adds no duplicate, and does not rewrite an existing card
n="$(items)"
jq '(.items[] | select(.id | test("-Q1$")) | .decide) = "ANSWERED ELSEWHERE"' "$SWEEP_CARDS_FILE" >"$T/q" && mv "$T/q" "$SWEEP_CARDS_FILE"
bash "$S" --run $run >/dev/null
check "$n" "$(items)" "AC-H1: a rerun leaves the item count unchanged"
check "$n" "$(jq '[.items[].id] | unique | length' "$SWEEP_CARDS_FILE")" "AC-H1: every id is unique after the rerun"
check "ANSWERED ELSEWHERE" "$(jq -r '.items[] | select(.id|test("-Q1$")) | .decide' "$SWEEP_CARDS_FILE")" "AC-H1: an existing card is not rewritten"
# cards from another run survive and a different run adds its own
printf '{"title":"Inbox sweep","items":[{"id":"IS-old-x-Q1","about":"a","decide":"d","options":[],"rec":0}]}\n' >"$T/q" && jq -s '.[0].items += .[1].items | .[0]' "$SWEEP_CARDS_FILE" "$T/q" >"$T/q2" && mv "$T/q2" "$SWEEP_CARDS_FILE"
bash "$S" --run $run >/dev/null
check 1 "$(has IS-old-x-Q1)" "a card of another run is left alone"

# checklist and log
check yes "$(grep -q 'ids unique: yes' "$D/logs/cards.log" && grep -q 'BLOCKED codes 4, BLOCKED cards 4' "$D/logs/cards.log" && echo yes || echo no)" "logs/cards.log records unique ids and 4 BLOCKED codes = 4 BLOCKED cards"

# AC-H4: server in a labeled pane, never a background job
grep -q 'herdr pane split wS:p1' "$TEST_OUT/calls.log"; check 0 "$?" "AC-H4: the server pane is split from an existing pane"
grep -q 'herdr pane rename wS:p9 bearings-inbox-sweep' "$TEST_OUT/calls.log"; check 0 "$?" "AC-H4: the new pane (not another) is renamed bearings-inbox-sweep"
check "herdr pane run wS:p9 node /skills/bearings/server.mjs inbox-sweep" "$(grep 'pane run' "$TEST_OUT/calls.log" | head -1)" "AC-H4: the server runs in that pane"
check 1 "$(grep -c 'pane run' "$TEST_OUT/calls.log")" "AC-H4: the server was started once across the reruns"
check 0 "$(grep -c 'herdr pane read\|wait-output' "$TEST_OUT/calls.log")" "no pane is read"
bg_scan "$S" >/dev/null; check 0 "$?" "AC-H4: the script backgrounds nothing (Rule 18 scan)"
# a server that is already up is left alone
rm -f "$T/out/split.state"; : >"$TEST_OUT/calls.log"; echo '{}' >"$(dirname "$SWEEP_CARDS_FILE")/server.json"
bash "$S" --run $run >/dev/null
check 0 "$(grep -c 'pane split\|pane run' "$TEST_OUT/calls.log")" "AC-H4: server.json present means no pane is created"

# failure paths
bash "$S" --run 20200101T000000Z >/dev/null 2>&1; check 3 "$?" "an unknown run exits 3"
bash "$S" --run nope >/dev/null 2>&1; check 2 "$?" "a bad run id exits 2"
bash "$S" >/dev/null 2>&1; check 2 "$?" "no arguments exits 2"
rm "$(dirname "$SWEEP_CARDS_FILE")/server.json"; : >"$TEST_OUT/calls.log"
STUB_HERDR_FAIL=1 bash "$S" --run $run >/dev/null 2>&1; check 0 "$?" "a herdr that fails does not fail the cards"
check yes "$(grep -q 'server not started' "$D/logs/cards.log" && echo yes || echo no)" "and the log says the server was not started"
finish
