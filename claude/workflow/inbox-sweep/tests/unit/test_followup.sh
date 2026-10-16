#!/usr/bin/env bash
# AC-H1..H3 for lead-followup.sh. Rules out: a send or an approval file being produced by the scheduler, a due lead getting
# no draft or no card, a rerun making a second draft or a second card, a draft before followup_after_days, a second draft
# while the first card is still open, a declined, answered, booked, closed or not-a-fit lead getting a draft, a lead going
# COLD before its follow-ups were actually sent, a Dropped follow-up leaving the lead open, a draft that names YieldPoint,
# a lead with no thread URL being matched to someone else's send, and any record without an integer schema_version.
set -uo pipefail
R="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=_t.sh
. "$R/tests/unit/_t.sh"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
export SWEEP_RUNS_ROOT="$T/runs" SWEEP_TRIAGE_ROOT="$T/win" SWEEP_CARDS_FILE="$T/bearings/questions.json"
export SWEEP_LEDGER_FILE="$T/win/inbox-triage-20261016/ledger.jsonl"
F="$R/bin/lead-followup.sh"
run=20261016T010000Z
D="$SWEEP_RUNS_ROOT/$run"
mkdir -p "$D/reply" "$T/win/inbox-triage-20261016" "$T/bearings"
echo '{}' >"$T/bearings/server.json"   # a Bearings server is "already up", so reply-cards.sh starts no herdr pane
U=https://www.linkedin.com/messaging/thread
lead() { jq -cn --arg id "$1" --arg u "$2" --arg c "$3" --arg s "$4" '{schema_version:1, lead_id:$id, thread_key:$u, thread_url:(if $u == "" then null else $u end), sender:$s, last_message:null, text:"x", code:$c, reason:"r", run_id:"x", created_at:"2026-10-10T00:00:00Z", updated_at:"2026-10-10T00:00:00Z"}'; }
sent() { jq -cn --arg id "$1" --arg u "$2" --arg at "$3" '{schema_version:1, at:$at, code:"RP-SENT", id:$id, sha256:"abc", thread_url:$u}' >>"$SWEEP_LEDGER_FILE"; }
{
  lead lead-due "$U/due/" LD-QUALIFIED "Sam Example"
  lead lead-fresh "$U/fresh/" LD-QUALIFIED "Fran Fresh"
  lead lead-answered "$U/ans/" LD-QUALIFIED "Ann Answered"
  lead lead-declined "$U/dec/" LD-CLOSED "Dee Declined"
  lead lead-booked "$U/book/" LD-CALL-BOOKED "Bo Booked"
  lead lead-nofit "$U/nofit/" LD-NOT-A-FIT "Nina Nofit"
  lead lead-unsent "$U/unsent/" LD-QUALIFIED "Una Unsent"
  lead lead-nourl "" LD-QUALIFIED "Nolan Nourl"
} >"$D/leads.jsonl"
: >"$SWEEP_LEDGER_FILE"
sent r-due "$U/due/" 2026-10-10T00:00:00Z
sent r-fresh "$U/fresh/" 2026-10-15T12:00:00Z
sent r-ans "$U/ans/" 2026-10-10T00:00:00Z
sent r-dec "$U/dec/" 2026-10-10T00:00:00Z
sent r-book "$U/book/" 2026-10-10T00:00:00Z
sent r-nofit "$U/nofit/" 2026-10-10T00:00:00Z
cat >"$D/reply/linkedin.md" <<'M'
## Ann Answered
- Thread: https://www.linkedin.com/messaging/thread/ans/
- Last message: 2026-10-12
She wrote back.
## Sam Example
- Thread: https://www.linkedin.com/messaging/thread/due/
- Last message: 2026-10-10
Nothing since our send.
M
export SWEEP_FOLLOWUP_NOW=2026-10-16T00:00:00Z
row() { jq -c --arg i "$1" 'select(.lead_id == $i)' "$D/leads.jsonl"; }
code_of() { row "$1" | jq -r .code; }
drafts() { find "$D/reply/drafts" -name '*.txt' | wc -l; }
due_drafts() { find "$D/reply/drafts" -name 'fu-lead-due-*.txt' | wc -l; }
due_rows() { jq -s '[.[] | select(.code == "RP-DRAFTED" and .lead_id == "lead-due")] | length' "$SWEEP_LEDGER_FILE"; }
cards() { jq '.items | length' "$SWEEP_CARDS_FILE"; }

bash "$F" --run $run >"$T/o1"; check 0 "$?" "first pass exits 0"

# AC-H1: a due lead gets one draft and one card, never a send
check 1 "$(drafts)" "AC-H1: exactly one draft: only the due lead"
check yes "$([ -f "$D/reply/drafts/fu-lead-due-1.txt" ] && echo yes || echo no)" "AC-H1: the draft is fu-<lead>-1"
check 1 "$(cards)" "AC-H1: and exactly one card"
check "RP-$run-fu-lead-due-1" "$(jq -r '.items[0].id' "$SWEEP_CARDS_FILE")" "AC-H1: the card is for that draft"
check yes "$(jq -r '.items[0].decide | contains("Hi Sam,")' "$SWEEP_CARDS_FILE" | sed 's/true/yes/')" "AC-H1: the card carries the full draft, addressed by first name"
check 0 "$(grep -ci yieldpoint "$D/reply/drafts/fu-lead-due-1.txt")" "AC-H1: the draft does not name YieldPoint"
check 1 "$(grep -ciE 'call' "$D/reply/drafts/fu-lead-due-1.txt")" "AC-H1: the draft offers a call"
check 0 "$(find "$T" -name 'send-*.txt' | wc -l)" "AC-H1: no approval file exists, so nothing can be sent"
check 6 "$(jq -s '[.[] | select(.code == "RP-SENT")] | length' "$SWEEP_LEDGER_FILE")" "AC-H1: no new RP-SENT row, only the six the test wrote"
check 1 "$(jq -s '[.[] | select(.code == "RP-DRAFTED" and .id == "fu-lead-due-1" and .lead_id == "lead-due")] | length' "$SWEEP_LEDGER_FILE")" "AC-H1: one RP-DRAFTED row names the lead"
check 1 "$(jq -s '[.[] | select(.code == "RP-AWAITING-OWNER")] | length' "$SWEEP_LEDGER_FILE")" "AC-H1: the card starts RP-AWAITING-OWNER"
check "fu-lead-due-1" "$(row lead-due | jq -r .pending_followup)" "AC-H1: the lead remembers the pending draft"
check LD-REPLIED "$(code_of lead-due)" "a qualified lead whose reply is out becomes LD-REPLIED"
check LD-REPLIED "$(code_of lead-fresh)" "LD-REPLIED for the fresh one too"
check null "$(row lead-fresh | jq -r '.pending_followup // "null"')" "not due before followup_after_days: no pending draft"

# rerun: still one draft, one card, one ledger row
bash "$F" --run $run >/dev/null
check 1 "$(drafts)" "AC-H1: a rerun makes no second draft while the first card is open"
check 1 "$(cards)" "AC-H1: and no second card"
check 1 "$(jq -s '[.[] | select(.code == "RP-DRAFTED")] | length' "$SWEEP_LEDGER_FILE")" "AC-H1: and no second RP-DRAFTED row"

# AC-H2: declined, answered, booked, not-a-fit, never-sent and no-URL leads get none
check LD-ANSWERED "$(code_of lead-answered)" "AC-H2: a lead that wrote back after our send is LD-ANSWERED"
check LD-CLOSED "$(code_of lead-declined)" "AC-H2: a declined lead is untouched"
check LD-CALL-BOOKED "$(code_of lead-booked)" "AC-H2: a booked lead is untouched"
check LD-NOT-A-FIT "$(code_of lead-nofit)" "AC-H2: a not-a-fit lead is untouched"
check LD-QUALIFIED "$(code_of lead-unsent)" "AC-H2: a lead we never wrote to is left for the reply step"
check LD-QUALIFIED "$(code_of lead-nourl)" "AC-H2: a lead with no thread URL is not matched to anyone's send"
for l in answered declined booked nofit unsent nourl; do
  check no "$([ -e "$D/reply/drafts/fu-lead-$l-1.txt" ] && echo yes || echo no)" "AC-H2: no draft for lead-$l"
done

# the follow-up is sent (RP-SENT for its own id); the first one is spent but the lead is not yet cold
sent fu-lead-due-1 "$U/due/" 2026-10-16T01:00:00Z
export SWEEP_FOLLOWUP_NOW=2026-10-17T00:00:00Z
bash "$F" --run $run >/dev/null
check 1 "$(row lead-due | jq -r .followups_sent)" "a sent follow-up is counted"
check 1 "$(drafts)" "AC-H3: one day after the follow-up there is no new draft (followup_after_days not passed)"
check LD-REPLIED "$(code_of lead-due)" "AC-H3: and the lead is still open"

# second follow-up, then COLD
export SWEEP_FOLLOWUP_NOW=2026-10-20T00:00:00Z
bash "$F" --run $run >/dev/null
check yes "$([ -f "$D/reply/drafts/fu-lead-due-2.txt" ] && echo yes || echo no)" "AC-H3: three days after the first follow-up, the second draft"
check LD-REPLIED "$(code_of lead-due)" "AC-H3: a drafted but unsent second follow-up does not make the lead cold"
bash "$F" --run $run >/dev/null; check 2 "$(due_rows)" "no third draft while the second card is open"
sent fu-lead-due-2 "$U/due/" 2026-10-20T01:00:00Z
export SWEEP_FOLLOWUP_NOW=2026-10-24T00:00:00Z
out="$(bash "$F" --run $run)"
check LD-COLD "$(code_of lead-due)" "AC-H3: after followup_max (2) sent follow-ups and followup_after_days of silence the lead is LD-COLD"
check 2 "$(due_drafts)" "AC-H3: and no third draft"
check yes "$(grep -q 'lead-due LD-COLD' <<<"$out" && echo yes || echo no)" "AC-H3: the output reports the lead going cold"
bash "$F" --run $run >/dev/null; check LD-COLD "$(code_of lead-due)" "LD-COLD is terminal on a rerun"
SWEEP_FOLLOWUP_MAX=3 bash "$F" --run $run >/dev/null; check LD-COLD "$(code_of lead-due)" "a terminal lead is not reopened by a larger followup_max"

# a Dropped follow-up closes the lead; a bad number is refused
lead lead-drop "$U/drop/" LD-QUALIFIED "Dru Drop" >>"$D/leads.jsonl"
sent r-drop "$U/drop/" 2026-10-20T00:00:00Z
export SWEEP_FOLLOWUP_NOW=2026-10-24T00:00:00Z
bash "$F" --run $run >/dev/null
check yes "$([ -f "$D/reply/drafts/fu-lead-drop-1.txt" ] && echo yes || echo no)" "a late lead gets its draft"
echo '{"schema_version":1,"id":"fu-lead-drop-1","code":"RP-DROPPED"}' >>"$D/reply/decisions.jsonl"
bash "$F" --run $run >/dev/null
check LD-CLOSED "$(code_of lead-drop)" "a Dropped follow-up closes the lead"
SWEEP_FOLLOWUP_MAX=x bash "$F" --run $run >/dev/null 2>&1; check 2 "$?" "a non-numeric followup_max is a usage error"
bash "$F" --run bad >/dev/null 2>&1; check 2 "$?" "a bad run id is a usage error"
bash "$F" --run 20200101T000000Z >/dev/null 2>&1; check 3 "$?" "a missing run is a precondition error"

# the schedule and the cap are config, not baked in: shorter window, one follow-up
lead lead-cfg "$U/cfg/" LD-QUALIFIED "Cy Cfg" >>"$D/leads.jsonl"
sent r-cfg "$U/cfg/" 2026-10-23T00:00:00Z
SWEEP_FOLLOWUP_AFTER_DAYS=1 bash "$F" --run $run >/dev/null
check yes "$([ -f "$D/reply/drafts/fu-lead-cfg-1.txt" ] && echo yes || echo no)" "SWEEP_FOLLOWUP_AFTER_DAYS=1 makes a one-day-old send due"
check 0 "$(find "$T" -name 'send-*.txt' | wc -l)" "still no approval file anywhere"

# every record carries an integer schema_version
check 0 "$(jq -s '[.[] | select((.schema_version | type) != "number" or (.schema_version | floor) != .schema_version)] | length' "$D/leads.jsonl" "$SWEEP_LEDGER_FILE")" "every lead and ledger row has an integer schema_version"
finish
