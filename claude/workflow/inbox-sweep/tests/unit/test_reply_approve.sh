#!/usr/bin/env bash
# AC-H1..H4 for reply-approve.sh. Rules out: edited text changed on its way to the file (trim, newline added, reflow),
# a hash recorded that is not the hash of the file, a second text for a thread overwriting or sharing the first file,
# an older file not marked superseded, Drop leaving any file or approvals row, a draft edited after the card was answered
# riding the old approval, a rerun duplicating files or rows, a file landing outside the allow-rule glob, an existing
# approval being overwritten, and any record written without an integer schema_version.
set -uo pipefail
R="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=_t.sh
. "$R/tests/unit/_t.sh"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
export SWEEP_RUNS_ROOT="$T/runs" SWEEP_TRIAGE_ROOT="$T/win" SWEEP_TODAY=20261017
export SWEEP_LEDGER_FILE="$T/win/inbox-triage-20261016/ledger.jsonl"
S="$R/bin/reply-approve.sh"
run=20261016T010000Z
D="$SWEEP_RUNS_ROOT/$run/reply"
F="$T/win/inbox-triage-20261017"
mkdir -p "$D/drafts" "$T/win/inbox-triage-20261016"
printf 'Hi Sam,\nhappy to talk.\nBest, J\n' >"$D/drafts/t1.txt"
printf 'second draft same thread' >"$D/drafts/t2.txt"
printf 'unrelated thread' >"$D/drafts/t3.txt"
printf 'to be dropped' >"$D/drafts/t4.txt"
printf 'edited later' >"$D/drafts/t5.txt"
u1=https://www.linkedin.com/messaging/thread/one/
{ for i in t1 t2; do echo "{\"code\":\"RP-DRAFTED\",\"id\":\"$i\",\"to\":\"Sam Example\",\"thread_url\":\"$u1\"}"; done
  echo '{"code":"RP-DRAFTED","id":"t3","thread_url":"https://www.linkedin.com/messaging/thread/two/"}'; } >"$SWEEP_LEDGER_FILE"
sha() { sha256sum "$1" | cut -d' ' -f1; }
# decision row: <id> <code> <file holding the text bytes>  (text from the file, so any bytes survive)
decide() { jq -cn --rawfile t "$3" --arg id "$1" --arg code "$2" --arg sha "$(sha "$3")" \
  '{schema_version:1, at:"x", run_id:"r", id:$id, card:("RP-r-" + $id), choice:"c", code:$code, text:$t, sha256:$sha}' >>"$D/decisions.jsonl"; }
touch "$D/decisions.jsonl"
ledger_n() { jq -s --arg c "$1" '[.[] | select(.code == $c)] | length' "$SWEEP_LEDGER_FILE"; }

# AC-H1: edited text in, same bytes out. Awkward bytes: leading spaces, blank line, trailing space AND newline, a quote.
printf '  Sam,\n\nit'"'"'s "fine" \nEnd \n' >"$T/edit.bin"
cp "$T/edit.bin" "$D/drafts/t3.txt"   # the draft differs from the edit; the edit must win
decide t3 RP-APPROVED-EDITED "$T/edit.bin"
decide t1 RP-APPROVED "$D/drafts/t1.txt"
out="$(bash "$S" --run $run)"; rc=$?
check 0 "$rc" "first pass exits 0"
cmp -s "$T/edit.bin" "$F/send-t3.txt"; check 0 "$?" "AC-H1: edited text in gives the same bytes out (untrimmed, trailing newline kept)"
check "$(sha "$T/edit.bin")" "$(sha "$F/send-t3.txt")" "AC-H1: sha256 of the file equals sha256 of the owner's bytes"
check "$(sha "$F/send-t3.txt")" "$(jq -r 'select(.id == "t3") | .sha256' "$F/approvals.jsonl")" "AC-H1: the approvals row carries the file's sha256"
cmp -s "$D/drafts/t1.txt" "$F/send-t1.txt"; check 0 "$?" "AC-H1: as written is the draft's bytes"
check "t1 RP-READY" "$(grep '^t1 ' <<<"$out")" "reports RP-READY"
check "$u1" "$(jq -r 'select(.id == "t1") | .thread_url' "$F/approvals.jsonl")" "approvals row records the thread URL"
check RP-r-t1 "$(jq -r 'select(.id == "t1") | .card' "$F/approvals.jsonl")" "approvals row records the card id"
check 1 "$(jq -r 'select(.id == "t1") | .revision' "$F/approvals.jsonl")" "first text is revision 1"
check yes "$([[ $F/send-t1.txt == */inbox-triage-*/send-*.txt ]] && echo yes || echo no)" "path matches the allow rule glob inbox-triage-*/send-*.txt"
check 2 "$(ledger_n RP-READY)" "one RP-READY row per approval"
check 20261017 "$(basename "$F" | sed 's/inbox-triage-//')" "folder is the approval day, not the run day"

# AC-H2: a second text for one thread gets a new revision file and supersedes the first
decide t2 RP-APPROVED-EDITED "$T/edit.bin"
bash "$S" --run $run >/dev/null
check yes "$([ -f "$F/send-t2-r2.txt" ] && echo yes || echo no)" "AC-H2: second text for the thread is send-<id>-r2.txt"
check "$(sha "$D/drafts/t1.txt")" "$(sha "$F/send-t1.txt")" "AC-H2: the first file is untouched"
check 2 "$(jq -r 'select(.id == "t2") | .revision' "$F/approvals.jsonl")" "AC-H2: revision 2 recorded"
check 1 "$(ledger_n RP-SUPERSEDED)" "AC-H2: the older file got one RP-SUPERSEDED row"
check "$F/send-t1.txt" "$(jq -r 'select(.code == "RP-SUPERSEDED") | .path' "$SWEEP_LEDGER_FILE")" "AC-H2: and it names the first file"
check 2 "$(jq -s '[.[] | select(.thread_key == "'"$u1"'")] | length' "$F/approvals.jsonl")" "AC-H2: both revisions stay on record"
# a third text supersedes only the second; the first is not marked twice
printf 'third' >"$T/third.bin"; printf 'third' >"$D/drafts/t6.txt"
echo "{\"code\":\"RP-DRAFTED\",\"id\":\"t6\",\"thread_url\":\"$u1\"}" >>"$SWEEP_LEDGER_FILE"
decide t6 RP-APPROVED "$T/third.bin"
bash "$S" --run $run >/dev/null
check yes "$([ -f "$F/send-t6-r3.txt" ] && echo yes || echo no)" "AC-H2: third text is -r3"
check 2 "$(ledger_n RP-SUPERSEDED)" "AC-H2: only the previous file is newly superseded"
# a revision approved on a later day still sees the earlier days' approvals
SWEEP_TODAY=20261018 bash "$S" --run $run >/dev/null
check 4 "$(ledger_n RP-READY)" "a rerun on a later day adds nothing for decisions already applied"

# idempotent: rerun adds no file, row or ledger line
files="$(find "$T/win" -name 'send-*.txt' | wc -l)"; rows="$(wc -l <"$F/approvals.jsonl")"; led="$(wc -l <"$SWEEP_LEDGER_FILE")"
bash "$S" --run $run >/dev/null
check "$files" "$(find "$T/win" -name 'send-*.txt' | wc -l)" "a rerun writes no file"
check "$rows" "$(wc -l <"$F/approvals.jsonl")" "a rerun adds no approvals row"
check "$led" "$(wc -l <"$SWEEP_LEDGER_FILE")" "a rerun adds no ledger row"

# AC-H3: Drop writes no file
before="$(find "$T/win" -type f | sort | tr '\n' ' ')"
jq -cn '{schema_version:1, at:"x", run_id:"r", id:"t4", card:"RP-r-t4", choice:"Drop", code:"RP-DROPPED", text:null, sha256:null}' >>"$D/decisions.jsonl"
out="$(bash "$S" --run $run)"
check "t4 RP-DROPPED" "$(grep '^t4 ' <<<"$out")" "AC-H3: Drop is reported RP-DROPPED"
check 1 "$(ledger_n RP-DROPPED)" "AC-H3: one RP-DROPPED ledger row"
after="$(find "$T/win" -type f | sort | tr '\n' ' ')"
check "$before" "$after" "AC-H3: Drop creates no file (the ledger already existed)"
check 0 "$(jq -s '[.[] | select(.id == "t4")] | length' "$F/approvals.jsonl")" "AC-H3: Drop writes no approvals row"
bash "$S" --run $run >/dev/null
check 1 "$(ledger_n RP-DROPPED)" "AC-H3: a rerun adds no second RP-DROPPED row"

# integrity: a draft changed after the card was answered cannot ride the old approval
decide t5 RP-APPROVED "$D/drafts/t5.txt"
printf 'changed after approval' >"$D/drafts/t5.txt"
bash "$S" --run $run >/dev/null 2>&1; check 4 "$?" "a draft changed after approval exits 4"
check no "$([ -f "$F/send-t5.txt" ] && echo yes || echo no)" "and no file is written for it"
# a row whose sha256 is not its text's hash is refused
jq -cn '{schema_version:1, id:"t7", card:"RP-r-t7", code:"RP-APPROVED-EDITED", text:"abc", sha256:"0000"}' >>"$D/decisions.jsonl"
bash "$S" --run $run >/dev/null 2>&1; check 4 "$?" "a text that does not hash to its row exits 4"
check no "$([ -f "$F/send-t7.txt" ] && echo yes || echo no)" "and no file is written for it"
# an existing approval file is never overwritten
printf 'other' >"$T/o.bin"; printf 'other' >"$D/drafts/t8.txt"; decide t8 RP-APPROVED "$T/o.bin"
printf 'squatter' >"$F/send-t8.txt"
bash "$S" --run $run >/dev/null 2>&1; check 4 "$?" "an existing file at the target exits 4"
check squatter "$(cat "$F/send-t8.txt")" "and it is left as it was"
# the failures above did not stop the good decisions: t1 and t3 are still ready
check yes "$([ -f "$F/send-t1.txt" ] && [ -f "$F/send-t3.txt" ] && echo yes || echo no)" "earlier approvals are intact"

# AC-H4: every record carries an integer schema_version
isint='select((.schema_version | type) != "number" or (.schema_version | floor) != .schema_version)'
check 0 "$(jq -s "[.[] | $isint] | length" "$F/approvals.jsonl")" "AC-H4: approvals.jsonl rows have an integer schema_version"
check 0 "$(jq -s "[.[] | select(.code != \"RP-DRAFTED\") | $isint] | length" "$SWEEP_LEDGER_FILE")" "AC-H4: ledger rows written here have an integer schema_version"

# usage and preconditions
bash "$S" --run 20200101T000000Z >/dev/null 2>&1; check 3 "$?" "an unknown run exits 3"
bash "$S" --run nope >/dev/null 2>&1; check 2 "$?" "a bad run id exits 2"
bash "$S" >/dev/null 2>&1; check 2 "$?" "no arguments exits 2"
finish
