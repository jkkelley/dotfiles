#!/usr/bin/env bash
# AC-H1..H5 for reply-send.sh (B17b), against a stub seat that advances one step per `herdr pane read`.
# Rules out: a near-match reaching Send (the stub seat clicks only if the token exists, and the token needs reply-verify to
# pass); a classifier denial being retried (one seat start, no prompt, no second start); a thread or ledger that already holds
# the text getting a second seat; typing before the owner's own line (no line, a line for another id, and a seat that types
# early all end with no token and no click); a result that claims RP-SENT without the gate (no token) being recorded as sent;
# a result that does not validate being accepted; a file the owner's approval does not name, a changed file, a superseded file
# or a terminal code being sent or rerun; ledger rows without an integer schema_version; prune deleting an approval that is
# still waiting to be sent; prune deleting a ledger whose approval files are still there.
set -uo pipefail
R="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=_t.sh
. "$R/tests/unit/_t.sh"
# shellcheck source=../lib/stubs.sh
. "$R/tests/lib/stubs.sh"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
S="$R/bin/reply-send.sh"
stubs_install "$T/bin"
export SWEEP_CLEAR_SEAT_START="$R/tests/lib/stub-clear-start.sh"
export SWEEP_SLEEP=true SWEEP_SEND_MAX_POLLS=30 SWEEP_SEAT_START="$R/tests/lib/stub-reply-start.sh" STUB_SEAT_STEP="$R/tests/lib/stub-reply-seat.sh"
printf 'owner words, 2026-10-16\n' >"$T/owner-words.md"; export SWEEP_OWNER_WORDS="$T/owner-words.md"
URL=https://www.linkedin.com/messaging/thread/2-EXAMPLE/
TEXT=$'Hi Sam,\n\nhappy to talk Thursday.\nBest, J'

# fresh: a new sandbox with one approved file m1 (and its RP-READY row), the stub seat reset
fresh() {
  rm -rf "$T/w" "$T/seat" "$TEST_OUT"; mkdir -p "$T/w/inbox-triage-20261017" "$T/seat" "$TEST_OUT"; : >"$TEST_OUT/calls.log"
  F="$T/w/inbox-triage-20261017"; export SWEEP_TRIAGE_ROOT="$T/w" STUB_SEAT_DIR="$T/seat" STUB_LEDGER="$F/ledger.jsonl"
  export SWEEP_CARDS_FILE="$T/bearings/questions.json"; rm -rf "$T/bearings"
  unset STUB_OWNER_LINE STUB_OWNER_AT STUB_SEAT_MODE STUB_HERDR_AGENT_GONE STUB_CLEAR_MODE STUB_CLEAR_OK_AT
  printf '%s' "$TEXT" >"$F/send-m1.txt"; A="$(readlink -f "$F/send-m1.txt")"; SHA="$(sha256sum "$A" | cut -d' ' -f1)"
  jq -cn --arg p "$A" --arg s "$SHA" --arg u "$URL" '{schema_version:1, id:"m1", card:"c1", code:"RP-APPROVED", thread_key:$u, thread_url:$u, to:"Sam Example", revision:1, path:$p, sha256:$s}' >"$F/approvals.jsonl"
  jq -cn --arg s "$SHA" '{schema_version:1, code:"RP-READY", id:"m1", sha256:$s}' >"$F/ledger.jsonl"
}
export SWEEP_BATCH_ID=b1
send() { out="$(bash "$S" send --approval "$A" 2>"$T/err")"; rc=$?; }
codes() { jq -r '.code' "$F/ledger.jsonl" | paste -sd' ' -; }
count() { jq -s --arg c "$1" '[.[] | select(.code == $c)] | length' "$F/ledger.jsonl"; }
slog() { grep -c "$1" "$T/seat/seat.log" 2>/dev/null || true; }

# AC-H5: the whole path, one ledger row for the send
fresh; export STUB_OWNER_LINE="Send them"
send
check 0 "$rc" "B17b AC-H5: a stub run exits 0"
check "m1 RP-SENT" "$out" "B17b AC-H5: a stub run reaches RP-SENT"
check 1 "$(count RP-SENT)" "B17b AC-H5: exactly one RP-SENT ledger row"
check "RP-READY RP-SENDING RP-AWAITING-CONFIRM RP-CONFIRMED RP-SENT" "$(codes)" "B17b AC-H5: the ledger tells the path in order"
check 1 "$(slog '^clicked')" "B17b AC-H5: the seat clicked Send once"
row="$(jq -c 'select(.code == "RP-SENT")' "$F/ledger.jsonl")"
check "$SHA" "$(jq -r .sha256 <<<"$row")" "L11: the row carries the sha256"
check "$URL" "$(jq -r .thread_url <<<"$row")" "L11: the row carries the thread URL"
check yes "$(jq -r '.at | test("^[0-9-]+T[0-9:]+Z$") | if . then "yes" else "no" end' <<<"$row")" "L11: the row carries a UTC time"
check yes "$(jq -r '[.proof.readback_path, .proof.token_path, .proof.screenshot_path] | all(. != null and . != "") | if . then "yes" else "no" end' <<<"$row")" "L11: the row carries the proof paths"
check 0 "$(jq -s '[.[] | select((.schema_version | type) != "number")] | length' "$F/ledger.jsonl")" "every ledger row has an integer schema_version"
check 1 "$(jq -r 'select(.code == "RP-CONFIRMED") | .schema_version' "$F/ledger.jsonl")" "RP-CONFIRMED row has schema_version 1"
check "Send them" "$(jq -r 'select(.code == "RP-CONFIRMED") | .line' "$F/ledger.jsonl")" "L6b: the CONFIRMED row quotes the owner's line"
check 1 "$(grep -c '^start ' "$T/seat/starts.log")" "one seat start for one send"
check 1 "$(grep -c '^Approval file: ' "$T/seat/brief.md")" "L6: the brief handed to the seat names one approval file"
check 1 "$(grep -c "^Thread URL: $URL\$" "$T/seat/brief.md")" "L6: and one thread URL"
check 1 "$(grep -c "^Approved sha256: $SHA\$" "$T/seat/brief.md")" "L6: and the approved sha256"
# shellcheck disable=SC2016 # a literal ${ is what is searched for
check 0 "$(grep -c '\${' "$T/seat/brief.md")" "L6: no placeholder is left unfilled in the brief"

# AC-H4: nothing typed before RP-CONFIRMED
fresh; send
check 5 "$rc" "B17b AC-H4: with no owner line the controller is still waiting (exit 5)"
check "m1 RP-AWAITING-CONFIRM" "$out" "B17b AC-H4: and says RP-AWAITING-CONFIRM"
check 0 "$(slog '^typed')" "B17b AC-H4: the seat typed nothing with no owner line"
check no "$([ -e "$F/readback-m1.txt" ] && echo yes || echo no)" "B17b AC-H4: no readback exists"
check 0 "$(count RP-CONFIRMED)" "B17b AC-H4: no RP-CONFIRMED row"
fresh; export STUB_OWNER_LINE="send other-id"; send
check 5 "$rc" "B17b AC-H4: a line naming another id is ignored (still waiting)"
check 0 "$(( $(count RP-CONFIRMED) + $(slog '^typed') ))" "B17b AC-H4: no RP-CONFIRMED row and nothing typed for a line naming another id"
fresh; export STUB_OWNER_LINE="send m1"; send
check 5 "$rc" "B17d: the old per-reply line send <id> is ignored (still waiting)"
check 0 "$(( $(count RP-CONFIRMED) + $(slog '^typed') ))" "B17d: and writes no RP-CONFIRMED row and types nothing"
fresh; export STUB_OWNER_LINE="please send m1 now"; send
check 5 "$rc" "B17b AC-H4: a line that merely contains the id is not the owner's line"
fresh; export STUB_OWNER_LINE="Send them" STUB_SEAT_MODE=ok; send
check yes "$(grep -q '^typed 1 confirmed=yes' "$T/seat/seat.log" && echo yes)" "B17b AC-H4: when the owner's line comes, RP-CONFIRMED is in the ledger before the seat types"
fresh; export STUB_OWNER_LINE="Send them" STUB_SEAT_MODE=early; send
check 1 "$rc" "B17b AC-H4: a seat that types before the owner's line ends (exit 1)"
check "m1 RP-FAILED-SEAT" "$out" "B17b AC-H4: as RP-FAILED-SEAT"
check no "$([ -e "$F/verified-m1.token" ] && echo yes || echo no)" "B17b AC-H4: and no token is ever issued for it"
check 0 "$(slog '^clicked')" "B17b AC-H4: and no click"

# AC-H1: a one-character mismatch never reaches Send
fresh; export STUB_OWNER_LINE="Send them" STUB_SEAT_MODE=mismatch; send
check 1 "$rc" "B17b AC-H1: a mismatching seat ends with a failure code"
check "m1 RP-TEXT-MISMATCH" "$out" "B17b AC-H1: RP-TEXT-MISMATCH"
check 0 "$(slog '^clicked')" "B17b AC-H1: the seat never clicked Send"
check no "$([ -e "$F/verified-m1.token" ] && echo yes || echo no)" "B17b AC-H1: no token was written"
check 0 "$(count RP-SENT)" "B17b AC-H1: no RP-SENT row"
check 3 "$(slog '^typed')" "B17b AC-H1: the seat typed three times, the written limit"
# the controller rejects a seat's RP-SENT that skipped the gate
fresh; export STUB_OWNER_LINE="Send them" STUB_SEAT_MODE=rogue; send
check "m1 RP-UNPROVEN" "$out" "B17b AC-H1: a result claiming RP-SENT with no token is RP-UNPROVEN, never RP-SENT"
check 0 "$(count RP-SENT)" "B17b AC-H1: and no RP-SENT row"

# AC-H2: a classifier denial is recorded, with zero retries
fresh; export STUB_OWNER_LINE="Send them" STUB_SEAT_MODE=denied; send
check 1 "$rc" "B17b AC-H2: a denial exits 1"
check "m1 RP-DENIED-CLASSIFIER" "$out" "B17b AC-H2: RP-DENIED-CLASSIFIER"
check 1 "$(grep -c '^start ' "$T/seat/starts.log")" "B17b AC-H2: zero retries: one seat start"
check 0 "$(grep -c 'agent prompt' "$TEST_OUT/calls.log")" "B17b AC-H2: and no prompt to the seat"
check 0 "$(( $(slog '^typed') + $(slog '^clicked') ))" "B17b AC-H2: nothing typed or clicked"
check 1 "$(count RP-DENIED-CLASSIFIER)" "B17b AC-H2: one denial row"
send   # the approval stays valid: a second call is allowed (the owner acted), and starts exactly one more seat
check 2 "$(grep -c '^start ' "$T/seat/starts.log")" "B17b AC-H2: after a denial the approved file can be sent again, by a deliberate rerun only"

# AC-H3: already sent
fresh; export STUB_OWNER_LINE="Send them" STUB_SEAT_MODE=already; send
check 0 "$rc" "B17b AC-H3: a thread already holding the text exits 0"
check "m1 RP-ALREADY-SENT" "$out" "B17b AC-H3: RP-ALREADY-SENT"
check 0 "$(( $(slog '^clicked') + $(slog '^typed') ))" "B17b AC-H3: no click, nothing typed"
check 0 "$(count RP-SENT)" "B17b AC-H3: not recorded as sent"
fresh
jq -cn --arg s "$SHA" --arg u "$URL" '{schema_version:1, code:"RP-SENT", id:"m1", sha256:$s, thread_url:$u}' >>"$F/ledger.jsonl"
send
check "m1 RP-ALREADY-SENT" "$out" "B17b AC-H3: a ledger RP-SENT for this sha256 and thread gives RP-ALREADY-SENT"
check no "$([ -e "$T/seat/starts.log" ] && echo yes || echo no)" "B17b AC-H3: and no seat is started"
n1="$(wc -l <"$F/ledger.jsonl")"; send
check "$n1" "$(wc -l <"$F/ledger.jsonl")" "B17b AC-H3: a rerun adds no row"

# terminal codes are not rerun
for c in RP-UNPROVEN RP-TEXT-MISMATCH RP-FAILED-SEAT; do
  fresh; jq -cn --arg s "$SHA" --arg c "$c" '{schema_version:1, code:$c, id:"m1", sha256:$s}' >>"$F/ledger.jsonl"; send
  check 3 "$rc" "$c is refused on a rerun (exit 3)"
  check no "$([ -e "$T/seat/starts.log" ] && echo yes || echo no)" "$c: no seat started"
done
fresh; jq -cn --arg s "$SHA" '{schema_version:1, code:"RP-SENDING", id:"m1", sha256:$s, seat:"agent-reply-batch-old"}' >>"$F/ledger.jsonl"; send
check 3 "$rc" "a seat that still holds the file blocks a second one (exit 3)"

# integrity
fresh; printf 'changed' >"$A"; send
check 4 "$rc" "a file whose bytes do not hash to its approval is refused (exit 4)"
check no "$([ -e "$T/seat/starts.log" ] && echo yes || echo no)" "and no seat is started for it"
fresh; : >"$F/approvals.jsonl"; send
check 4 "$rc" "a file in no approvals.jsonl row is refused (exit 4)"
fresh; jq -cn --arg s "$SHA" '{schema_version:1, code:"RP-SUPERSEDED", id:"m1", sha256:$s}' >>"$F/ledger.jsonl"; send
check 4 "$rc" "a superseded file is refused (exit 4)"
fresh; jq -c '. + {thread_url:null}' "$F/approvals.jsonl" >"$T/x" && mv "$T/x" "$F/approvals.jsonl"; send
check 4 "$rc" "an approval with no thread URL is refused (exit 4)"
fresh; printf '\n' >"$T/owner-empty.md"; SWEEP_OWNER_WORDS="$T/owner-empty.md" send
check 3 "$rc" "no owner words: no seat (PF-NO-OWNER-WORDS)"
bash "$S" 2>/dev/null; check 2 "$?" "no arguments exits 2"
rm -rf "$T/empty"; mkdir "$T/empty"; SWEEP_TRIAGE_ROOT="$T/empty" bash "$S" send >/dev/null 2>&1; check 0 "$?" "send with no --approval and nothing RP-READY"
bash "$S" send --bogus 2>/dev/null; check 2 "$?" "B17d: an unknown option exits 2"
bash "$S" send --approval /nope 2>/dev/null; check 3 "$?" "a missing file exits 3"

# seat death: three starts, then RP-FAILED-SEAT
fresh; export STUB_HERDR_AGENT_GONE=1; (unset STUB_SEAT_STEP; send; echo "$out" >"$T/o"; echo "$rc" >"$T/rc")
check "m1 RP-FAILED-SEAT" "$(cat "$T/o")" "a seat that dies before any token is started up to 3 times, then RP-FAILED-SEAT"
check 3 "$(grep -c '^start ' "$T/seat/starts.log")" "and exactly 3 starts"
# a result that does not validate is asked for again, 3 times, then RP-FAILED-SEAT
fresh; export STUB_OWNER_LINE="Send them" STUB_SEAT_MODE=badresult; send
check "m1 RP-FAILED-SEAT" "$out" "a result that never validates ends RP-FAILED-SEAT"
check 2 "$(grep -c 'agent prompt' "$TEST_OUT/calls.log")" "and the seat is asked to rewrite it twice (3 tries in all)"

# B17c: a seat that dies after typing leaves the box to a fresh clear seat. AC-H1..H3.
clears() { [ -f "$T/seat/clear-starts.log" ] && grep -c '^start ' "$T/seat/clear-starts.log" || echo 0; }
cards() { jq -r '[.items[].id] | join(",")' "$SWEEP_CARDS_FILE" 2>/dev/null || true; }
# AC-H1: a token was issued, then the seat died with no result: one clear seat, RP-BOX-CLEARED, then the original RP-UNPROVEN
fresh; export STUB_OWNER_LINE="Send them" STUB_SEAT_MODE=die-token STUB_HERDR_AGENT_GONE=1; send
check "m1 RP-UNPROVEN" "$out" "B17b AC-H1: a seat that died after the token still ends with its original code"
check 1 "$(clears)" "B17b AC-H1: one clear seat is started for the dead seat"
check "RP-READY RP-SENDING RP-AWAITING-CONFIRM RP-CONFIRMED RP-BOX-CLEARED RP-UNPROVEN" "$(codes)" "B17b AC-H1: the ledger gets RP-BOX-CLEARED, then the original code"
check 0 "$(slog '^clicked')" "B17b AC-H1: and nothing is clicked by anyone"
check "" "$(cards)" "B17b AC-H1: no owner card when the box was proven empty"
check 1 "$(jq -r 'select(.code == "RP-BOX-CLEARED") | .schema_version' "$F/ledger.jsonl")" "B17b AC-H1: the RP-BOX-CLEARED row has an integer schema_version"
# a seat that died with wrong text in the box and no token: cleared each time, respawned, finally RP-FAILED-SEAT
fresh; export STUB_OWNER_LINE="Send them" STUB_SEAT_MODE=die STUB_HERDR_AGENT_GONE=1; send
check "m1 RP-FAILED-SEAT" "$out" "B17b AC-H1: three deaths after typing still end RP-FAILED-SEAT"
check 3 "$(clears)" "B17b AC-H1: one clear seat per death"
check "RP-READY RP-SENDING RP-AWAITING-CONFIRM RP-CONFIRMED RP-BOX-CLEARED RP-SENDING RP-AWAITING-CONFIRM RP-CONFIRMED RP-BOX-CLEARED RP-SENDING RP-AWAITING-CONFIRM RP-CONFIRMED RP-BOX-CLEARED RP-FAILED-SEAT" "$(codes)" "B17b AC-H1: each death is cleared before the next seat starts"
# a seat that dies before typing has no box to clear
fresh; export STUB_HERDR_AGENT_GONE=1; (unset STUB_SEAT_STEP; send)
check 0 "$(clears)" "B17b AC-H1: a seat that died before it typed starts no clear seat"
# AC-H2: the clear brief
cb="$T/seat/clear-brief-1.md"
fresh; export STUB_OWNER_LINE="Send them" STUB_SEAT_MODE=die-token STUB_HERDR_AGENT_GONE=1; send
check 1 "$(grep -c "^Thread URL: $URL\$" "$cb")" "B17b AC-H2: the clear brief names one thread URL"
check 1 "$(grep -c '^Thread URL: ' "$cb")" "B17b AC-H2: and only one"
check 0 "$(grep -ci '^Approval file:\|^Approved sha256:\|^Token' "$cb")" "B17b AC-H2: and no approval file, hash or token to send from"
check yes "$(grep -q '^This seat types nothing into LinkedIn\.$' "$cb" && echo yes)" "B17b AC-H2: the clear brief forbids typing"
check yes "$(grep -q '^This seat never clicks Send' "$cb" && echo yes)" "B17b AC-H2: and clicking Send"
check yes "$(grep -q 'The box must read back empty' "$cb" && echo yes)" "B17b AC-H2: and requires an empty read-back"
# shellcheck disable=SC2016 # a literal ${ is what is searched for
check 0 "$(grep -c '\${' "$cb")" "B17b AC-H2: no placeholder is left unfilled in the clear brief"
check 0 "$(grep -c $'\xe2\x80\x94' "$cb")" "B17b AC-H2: no em dash in the clear brief"
# AC-H3: three clear seats cannot prove the box empty: one owner card, original code, no new send seat
fresh; export STUB_OWNER_LINE="Send them" STUB_SEAT_MODE=die STUB_HERDR_AGENT_GONE=1 STUB_CLEAR_MODE=dirty; send
check "m1 RP-FAILED-SEAT" "$out" "B17b AC-H3: an uncleared box ends with the original code"
check 3 "$(clears)" "B17b AC-H3: three clear seats were tried, no more"
check "RP-BOX-m1" "$(cards)" "B17b AC-H3: exactly one owner card is raised"
check 1 "$(grep -c '^start ' "$T/seat/starts.log")" "B17b AC-H3: no new send seat is started into a box nobody could empty"
check 0 "$(count RP-BOX-CLEARED)" "B17b AC-H3: and RP-BOX-CLEARED is never recorded"
check unconfirmed "$(jq -r 'select(.code == "RP-FAILED-SEAT") | .box_state' "$F/ledger.jsonl")" "B17b AC-H3: the final row says the box state is unconfirmed"
export STUB_CLEAR_MODE=none; fresh; export STUB_OWNER_LINE="Send them" STUB_SEAT_MODE=die STUB_HERDR_AGENT_GONE=1 STUB_CLEAR_MODE=none; send
check "RP-BOX-m1" "$(cards)" "B17b AC-H3: a clear seat that writes no result counts as a failed try"
rm -f "$T/bearings/x"; send
check 1 "$(jq '.items | length' "$SWEEP_CARDS_FILE")" "B17b AC-H3: a rerun never duplicates the card"
# the second clear seat can succeed after a first that could not
fresh; export STUB_OWNER_LINE="Send them" STUB_SEAT_MODE=die-token STUB_HERDR_AGENT_GONE=1 STUB_CLEAR_MODE=dirty STUB_CLEAR_OK_AT=2; send
check 2 "$(clears)" "B17b AC-H3: a first clear seat that fails is followed by a second"
check 1 "$(count RP-BOX-CLEARED)" "B17b AC-H3: the second one proving the box empty gives RP-BOX-CLEARED"
check "" "$(cards)" "B17b AC-H3: and no card"
unset STUB_CLEAR_MODE STUB_CLEAR_OK_AT

# ---- B17d: one seat and one owner line per batch (design 18.4). Three RP-READY files m1..m3, each in its own thread.
URLN() { echo "https://www.linkedin.com/messaging/thread/2-EXAMPLE$1/"; }
batchfresh() { # <count>
  fresh
  local k a s   # assigned through eval below; declared so SC2154 sees them (WO-20261016-4409)
  : >"$F/approvals.jsonl"; : >"$F/ledger.jsonl"; rm -f "$F/send-m1.txt"
  for k in $(seq 1 "$1"); do
    printf 'Hi Sam %s,\n\nhappy to talk Thursday.' "$k" >"$F/send-m$k.txt"
    eval "A$k=\"\$(readlink -f \"\$F/send-m$k.txt\")\""; eval "a=\$A$k"; eval "SHA$k=\"\$(sha256sum \"\$a\" | cut -d' ' -f1)\""; eval "s=\$SHA$k"
    jq -cn --arg p "$a" --arg s "$s" --arg u "$(URLN "$k")" --arg id "m$k" '{schema_version:1, id:$id, card:"c1", code:"RP-APPROVED", thread_key:$u, thread_url:$u, to:"Sam Example", revision:1, path:$p, sha256:$s}' >>"$F/approvals.jsonl"
    jq -cn --arg s "$s" --arg id "m$k" '{schema_version:1, code:"RP-READY", id:$id, sha256:$s}' >>"$F/ledger.jsonl"
  done
}
batch() { out="$(bash "$S" send "$@" 2>"$T/err")"; rc=$?; }

# AC-H1: three RP-READY files start exactly one seat, whose brief names all three
batchfresh 3; export STUB_OWNER_LINE="Send them"; batch
check 0 "$rc" "B17d AC-H1: a batch of three exits 0"
check "m1 RP-SENT
m2 RP-SENT
m3 RP-SENT" "$out" "B17d AC-H1: each file reaches RP-SENT"
check 1 "$(grep -c '^start ' "$T/seat/starts.log")" "B17d AC-H1: exactly one seat start"
check "start agent-reply-batch-b1 b1" "$(cat "$T/seat/starts.log")" "B17d AC-H1: the seat is agent-reply-batch-<batch-id>"
check 3 "$(grep -c '^Approval file: ' "$T/seat/brief.md")" "B17d AC-H1: the brief names the 3 files"
for k in 1 2 3; do eval "a=\$A$k"; check 1 "$(grep -c -F "Approval file: $a" "$T/seat/brief.md")" "B17d AC-H1: the brief names send-m$k.txt once"; done
check 3 "$(slog '^clicked')" "B17d AC-H1: one click per reply"
check 3 "$(slog '^typed')" "B17d AC-H1: and one typing per reply"
# shellcheck disable=SC2016 # a literal ${ is what is searched for
check 0 "$(grep -c '\${' "$T/seat/brief.md")" "B17d AC-H1: no placeholder is left unfilled in the batch brief"
check 0 "$(grep -c $'\xe2\x80\x94' "$T/seat/brief.md")" "B17d AC-H1: no em dash in the batch brief"
# AC-H2: nothing typed until `Send them` follows RP-AWAITING-CONFIRM batch <id>; send <id> and other lines are ignored
for line in "send m1" "send m2" "sEnd them" "Send them please" "yes"; do
  batchfresh 3; export STUB_OWNER_LINE="$line"; batch
  check 5 "$rc" "B17d AC-H2: '$line' is ignored (still waiting)"
  check 0 "$(( $(count RP-CONFIRMED) + $(slog '^typed') ))" "B17d AC-H2: '$line' confirms nothing and types nothing"
done
check "m1 RP-AWAITING-CONFIRM
m2 RP-AWAITING-CONFIRM
m3 RP-AWAITING-CONFIRM" "$out" "B17d AC-H2: every file reports RP-AWAITING-CONFIRM"
check 3 "$(count RP-AWAITING-CONFIRM)" "B17d AC-H2: one RP-AWAITING-CONFIRM row per file"
check 3 "$(jq -s '[.[] | select(.code == "RP-AWAITING-CONFIRM" and .batch == "b1")] | length' "$F/ledger.jsonl")" "B17d AC-H2: each row carries the batch id"
batchfresh 3; export STUB_OWNER_LINE="Send them" STUB_SEAT_MODES="early ok ok"; batch
check "m1 RP-FAILED-SEAT
m2 RP-FAILED-SEAT
m3 RP-FAILED-SEAT" "$out" "B17d AC-H2: a seat that types before the owner's line fails the whole batch"
check 0 "$(slog '^clicked')" "B17d AC-H2: and no click"
# AC-H3: RP-CONFIRMED once per file, quoting the line and the batch id
batchfresh 3; export STUB_OWNER_LINE="Send them"; unset STUB_SEAT_MODES; batch
check 3 "$(count RP-CONFIRMED)" "B17d AC-H3: RP-CONFIRMED is written once per file"
check "m1 m2 m3" "$(jq -r 'select(.code == "RP-CONFIRMED") | .id' "$F/ledger.jsonl" | paste -sd' ')" "B17d AC-H3: one for each of the 3 files"
check 3 "$(jq -s '[.[] | select(.code == "RP-CONFIRMED" and .line == "Send them" and .batch == "b1")] | length' "$F/ledger.jsonl")" "B17d AC-H3: each row quotes the line and the batch id"
check "RP-READY RP-SENDING RP-AWAITING-CONFIRM RP-CONFIRMED RP-SENT" "$(jq -r 'select(.id == "m3") | .code' "$F/ledger.jsonl" | paste -sd' ')" "B17d AC-H3: each file's own ledger path is in order"
check 0 "$(jq -s '[.[] | select((.schema_version | type) != "number")] | length' "$F/ledger.jsonl")" "B17d AC-H3: every row has an integer schema_version"
# AC-H4: a mismatch on file 2 ends file 2 only
batchfresh 3; export STUB_OWNER_LINE="Send them" STUB_SEAT_MODES="ok mismatch ok"; batch
check 1 "$rc" "B17d AC-H4: a batch with a failed reply exits 1"
check "m1 RP-SENT
m2 RP-TEXT-MISMATCH
m3 RP-SENT" "$out" "B17d AC-H4: file 2 is RP-TEXT-MISMATCH and files 1 and 3 reach RP-SENT"
check no "$([ -e "$F/verified-m2.token" ] && echo yes || echo no)" "B17d AC-H4: file 2 never got a token"
check 2 "$(slog '^clicked')" "B17d AC-H4: only files 1 and 3 were clicked"
check 1 "$(grep -c '^start ' "$T/seat/starts.log")" "B17d AC-H4: one seat start, no respawn for a mismatch"
# AC-H5: a classifier denial on file 1 stops the batch with zero retries
batchfresh 3; export STUB_OWNER_LINE="Send them" STUB_SEAT_MODES="denied ok ok"; batch
check "m1 RP-DENIED-CLASSIFIER
m2 RP-DENIED-CLASSIFIER
m3 RP-DENIED-CLASSIFIER" "$out" "B17d AC-H5: all 3 files end RP-DENIED-CLASSIFIER"
check 3 "$(count RP-DENIED-CLASSIFIER)" "B17d AC-H5: one denial row per file"
check 1 "$(grep -c '^start ' "$T/seat/starts.log")" "B17d AC-H5: zero retries: one seat start"
check 0 "$(grep -c 'agent prompt' "$TEST_OUT/calls.log")" "B17d AC-H5: and no prompt to the seat"
check 0 "$(( $(slog '^typed') + $(slog '^clicked') ))" "B17d AC-H5: nothing typed or clicked by anyone"
# a denial on file 2 leaves file 1's RP-SENT alone
batchfresh 3; export STUB_OWNER_LINE="Send them" STUB_SEAT_MODES="ok denied ok"; batch
check "m1 RP-SENT
m2 RP-DENIED-CLASSIFIER
m3 RP-DENIED-CLASSIFIER" "$out" "B17d AC-H5: a denial on file 2 keeps file 1 sent and stops 2 and 3"
# AC-H6: more RP-READY files than reply_batch_max leave the rest for the next batch
batchfresh 3; export STUB_OWNER_LINE="Send them"; unset STUB_SEAT_MODES
printf '{"reply_batch_max": 2}\n' >"$T/cfg.json"; SWEEP_CONFIG="$T/cfg.json" batch
check "m1 RP-SENT
m2 RP-SENT" "$out" "B17d AC-H6: reply_batch_max 2 sends the first two"
check RP-READY "$(bash "$S" status | awk -F'\t' '$1 == "m3" {print $2}')" "B17d AC-H6: the third stays RP-READY"
check 2 "$(grep -c '^Approval file: ' "$T/seat/brief.md")" "B17d AC-H6: the brief names only the batch"
SWEEP_BATCH_ID=b2 batch
check "m3 RP-SENT" "$out" "B17d AC-H6: the next batch takes the rest"
batchfresh 3; export STUB_OWNER_LINE="Send them"; batch --max 1
check "m1 RP-SENT" "$out" "B17d AC-H6: --max overrides the config and the default"
batchfresh 12; export STUB_OWNER_LINE="Send them"; SWEEP_SEND_MAX_POLLS=90 batch
check 10 "$(printf '%s\n' "$out" | grep -c ' RP-SENT$')" "B17d AC-H6: the default cap is 10"
check RP-READY "$(bash "$S" status | awk -F'\t' '$1 == "m11" {print $2}')" "B17d AC-H6: the 11th stays RP-READY"
batchfresh 1; batch --max 0
check 2 "$rc" "B17d AC-H6: a bad cap exits 2"
# a seat that dies mid-batch is replaced by one for the unsent files only, which waits for the line again
batchfresh 3; export STUB_OWNER_LINE="Send them" STUB_SEAT_MODES="ok die-token ok" STUB_HERDR_AGENT_GONE=1; batch
check "m1 RP-SENT
m2 RP-UNPROVEN
m3 RP-SENT" "$out" "B17d: death after file 2's token: file 1 stays sent, file 2 is RP-UNPROVEN, and a fresh seat sends file 3"
check 2 "$(grep -c '^start ' "$T/seat/starts.log")" "B17d: the replacement seat is one more start"
check 1 "$(grep -c '^Approval file: ' "$T/seat/brief.md")" "B17d: the replacement brief names only the unsent file"
check 2 "$(slog '^clicked')" "B17d: files 1 and 3 were clicked, never file 2"
unset STUB_SEAT_MODES STUB_HERDR_AGENT_GONE STUB_CLEAR_MODE
# a file already sent is skipped inside a batch
batchfresh 3; jq -cn --arg s "$SHA2" --arg u "$(URLN 2)" '{schema_version:1, code:"RP-SENT", id:"m2", sha256:$s, thread_url:$u}' >>"$F/ledger.jsonl"
export STUB_OWNER_LINE="Send them"; batch --approval "$A1" --approval "$A2" --approval "$A3"
check "m1 RP-SENT
m2 RP-ALREADY-SENT
m3 RP-SENT" "$out" "B17d: a reply already sent is skipped inside a batch"
check 2 "$(grep -c '^Approval file: ' "$T/seat/brief.md")" "B17d: and is not in the seat's brief"
unset STUB_OWNER_LINE

# status
fresh; out="$(bash "$S" status)"
check "m1	RP-READY	${SHA:0:8}	$A" "$out" "status lists an approved file as RP-READY"
export STUB_OWNER_LINE="Send them"; STUB_SEAT_MODE=ok; send
out="$(bash "$S" status --day 20261017)"
check "m1	RP-SENT	${SHA:0:8}	$A" "$out" "status shows RP-SENT after the send"
check "" "$(bash "$S" status --day 20250101)" "status for a day with no folder is empty"

# prune: 14 day tier by age, never an approval still waiting; 90 day ledger tier, never while approval files remain
fresh
old="$(date -u -d '30 days ago' +%Y%m%d)"
mkdir -p "$F/proof"
for f in readback-m1.txt verified-m1.token send-result-m1.json brief-m1.md proof/m1.png; do : >"$F/$f"; touch -d '30 days ago' "$F/$f"; done
touch -d '30 days ago' "$A"
: >"$F/readback-fresh.txt"
bash "$S" prune --days 14 --dry-run >"$T/dry"
check yes "$(grep -q 'readback-m1.txt' "$T/dry" && echo yes)" "prune --dry-run lists an old readback"
check yes "$([ -e "$F/readback-m1.txt" ] && echo yes)" "prune --dry-run deletes nothing"
check no "$(grep -q 'send-m1.txt' "$T/dry" && echo yes || echo no)" "prune keeps an old approval whose ledger code is RP-READY (waiting to be sent)"
bash "$S" prune --days 14 >/dev/null
check no "$([ -e "$F/readback-m1.txt" ] || [ -e "$F/verified-m1.token" ] || [ -e "$F/send-result-m1.json" ] || [ -e "$F/brief-m1.md" ] || [ -e "$F/proof/m1.png" ] && echo yes || echo no)" "prune removes the 14 day tier past its age"
check yes "$([ -e "$F/readback-fresh.txt" ] && [ -e "$A" ] && echo yes)" "prune keeps a fresh file and the waiting approval"
jq -cn --arg s "$SHA" --arg u "$URL" '{schema_version:1, code:"RP-SENT", id:"m1", sha256:$s, thread_url:$u}' >>"$F/ledger.jsonl"
bash "$S" prune --days 14 >/dev/null
check no "$([ -e "$A" ] && echo yes || echo no)" "prune removes an old approval once it is sent"
mv "$F" "$T/w/inbox-triage-$old"; F="$T/w/inbox-triage-$old"
export SWEEP_TODAY=20261017
bash "$S" prune >/dev/null
check yes "$([ -e "$F/ledger.jsonl" ] && echo yes)" "prune --ledger-days keeps a 30 day old ledger (90 day tier)"
old90="$(date -u -d '100 days ago' +%Y%m%d)"; mkdir -p "$T/w/inbox-triage-$old90"; : >"$T/w/inbox-triage-$old90/ledger.jsonl"; : >"$T/w/inbox-triage-$old90/send-z.txt"
SWEEP_TODAY=$(date -u +%Y%m%d) bash "$S" prune >/dev/null
check yes "$([ -e "$T/w/inbox-triage-$old90/ledger.jsonl" ] && echo yes)" "prune keeps a 100 day old ledger while an approval file is still in its folder"
rm -f "$T/w/inbox-triage-$old90/send-z.txt"
SWEEP_TODAY=$(date -u +%Y%m%d) bash "$S" prune >/dev/null
check no "$([ -e "$T/w/inbox-triage-$old90/ledger.jsonl" ] && echo yes || echo no)" "prune removes a 100 day old ledger once its folder holds no approval file"
finish
