#!/usr/bin/env bash
# shellcheck disable=SC2016 # jq filters use $var; they are jq variables, single quotes are the point
# node: S6
# lead-followup.sh - S6 (follow-up) of the lead stage, build node B23.
#
#   lead-followup.sh --run <run-id>
#
# For every lead in <run dir>/leads.jsonl whose reply has gone out and gone unanswered for followup_after_days, writes ONE
# follow-up draft to <run dir>/reply/drafts/fu-<lead-id>-<n>.txt and an RP-DRAFTED ledger row, then runs reply-cards.sh so
# the draft appears as a NEW Bearings card (design 14.3, L3). It sends nothing and writes no approval file: a follow-up
# goes through the same owner approval and the same send seat as any reply, so there is no second send path to guard.
#
# What it reads, all of it data and none of it instructions:
#   leads.jsonl                  the lead rows (lead-ledger.sh / lead-qualify.sh)
#   ledger.jsonl, every day      RP-SENT rows, matched to a lead by thread_url; the newest is when we last wrote
#   reply/decisions.jsonl        an RP-DROPPED follow-up closes the lead
#   reply/linkedin.md            the L1 read; a Last message date after our last send means they wrote back
#
# Per lead, in order (only LD-QUALIFIED and LD-REPLIED leads are looked at; every other code is left exactly as it is, so a
# declined, closed, booked, cold or not-a-fit lead can never get a draft):
#   1. LD-QUALIFIED with an RP-SENT on its thread becomes LD-REPLIED: nobody else records that our reply is out.
#   2. A pending follow-up (draft id in pending_followup) blocks a second one. It is cleared when its RP-SENT appears (and
#      followups_sent goes up by one) or when the owner Dropped it (the lead becomes LD-CLOSED).
#   3. They wrote back after our last send: LD-ANSWERED. The agent drafts the next reply, not a follow-up.
#   4. Not yet followup_after_days since our last send: nothing.
#   5. followups_sent has reached followup_max: LD-COLD, terminal, no draft.
#   6. Otherwise one draft, one RP-DRAFTED row, pending_followup set. A draft file that already exists is never rewritten, so
#      a crash between the draft and the lead row heals on the next pass instead of making a second draft.
# Counting sent follow-ups, not drafted ones, is deliberate: a draft the owner has not approved is not a follow-up that was
# spent, and counting it would turn a lead COLD while its card is still open. Rejected alternative: count at draft time.
#
# followup_after_days (default 3) and followup_max (default 2) are the design's guesses, not owner rulings (design 17).
# They are environment, not config.json, because the config schema is closed (additionalProperties false) and the owner has
# not yet set them; SWEEP_FOLLOWUP_AFTER_DAYS and SWEEP_FOLLOWUP_MAX override them.
# The draft text is templates/followup.txt with {name} replaced by the sender's first word. It names no company, so the
# personal profile never carries YieldPoint (design 17 conflict), and it offers a call, the outcome of the whole stage.
#
# Output, one line per lead that changed:  <lead-id> <LD-code> <draft-id or ->
# Exit: 0 done; 2 usage; 3 precondition (no run, no leads.jsonl, no template).
#
# Every record written carries an integer schema_version (design 15.2); leads.jsonl and ledger rows are version 1.
# Environment: SWEEP_RUNS_ROOT, SWEEP_TRIAGE_ROOT (default <win-home>), SWEEP_LEDGER_FILE as reply-cards.sh;
#   SWEEP_FOLLOWUP_NOW an ISO UTC "now" for tests (default the clock).
# Design: docs/design/inbox-sweep.md section 17, spec lead-stage S6 and build node B23.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=sweep-lib.sh
. "$HERE/sweep-lib.sh"

if [ $# -ne 2 ] || [ "$1" != --run ]; then echo "usage: lead-followup.sh --run <run-id>" >&2; exit 2; fi
run="$2"
[[ $run =~ ^[0-9]{8}T[0-9]{6}Z$ ]] || { echo "lead-followup: bad run id '$run'" >&2; exit 2; }
after_days="${SWEEP_FOLLOWUP_AFTER_DAYS:-3}"
max="${SWEEP_FOLLOWUP_MAX:-2}"
if ! [[ $after_days =~ ^[0-9]+$ ]] || ! [[ $max =~ ^[0-9]+$ ]]; then
  echo "lead-followup: SWEEP_FOLLOWUP_AFTER_DAYS and SWEEP_FOLLOWUP_MAX must be whole numbers" >&2; exit 2
fi

root="${SWEEP_RUNS_ROOT:-$(sweep_win_home)/.local/state/zenith/inbox-sweep/runs}"
RUN_DIR="$root/$run"
LEADS="$RUN_DIR/leads.jsonl"
REPLY="$RUN_DIR/reply"
TRIAGE="${SWEEP_TRIAGE_ROOT:-$(sweep_win_home)}"
LEDGER="${SWEEP_LEDGER_FILE:-$TRIAGE/inbox-triage-${run:0:8}/ledger.jsonl}"
TEMPLATE="$HERE/../templates/followup.txt"
[ -f "$LEADS" ] || { echo "lead-followup: no leads.jsonl in $RUN_DIR" >&2; exit 3; }
[ -f "$TEMPLATE" ] || { echo "lead-followup: no template $TEMPLATE" >&2; exit 3; }
export SWEEP_RUN_DIR="$RUN_DIR"
mkdir -p "$RUN_DIR/logs" "$REPLY/drafts" "$(dirname "$LEDGER")"
log() { printf '%s %s\n' "$(sweep_now)" "$*" >>"$RUN_DIR/logs/lead-followup.log"; }
touch "$LEDGER" "$REPLY/decisions.jsonl"
SCRATCH="$(mktemp -d)"
trap 'rm -rf "$SCRATCH"' EXIT

now="${SWEEP_FOLLOWUP_NOW:-$(sweep_now)}"
now_s="$(date -u -d "$now" +%s)"
cat "$TRIAGE"/inbox-triage-*/ledger.jsonl "$LEDGER" 2>/dev/null | sort -u >"$SCRATCH/ledgers.jsonl" || true

# url<TAB>last message date, from the L1 read, for the "they wrote back" test.
: >"$SCRATCH/last.tsv"
if [ -f "$REPLY/linkedin.md" ]; then
  awk 'function flush() { if (url != "") print url "\t" last; url = ""; last = "" }
       /^## / { flush(); next }
       match($0, /^[-*]?[[:space:]]*Thread( URL)?[[:space:]]*:[[:space:]]*/) { url = substr($0, RLENGTH + 1); sub(/[[:space:]]+$/, "", url) }
       match($0, /^[-*]?[[:space:]]*Last message[[:space:]]*:[[:space:]]*/) { last = substr($0, RLENGTH + 1); sub(/[[:space:]]+$/, "", last) }
       END { flush() }' "$REPLY/linkedin.md" >"$SCRATCH/last.tsv"
fi

: >"$SCRATCH/out.jsonl"
: >"$SCRATCH/moved.txt"
drafted=0
while IFS= read -r row; do
  [ -n "$row" ] || continue
  code="$(jq -r .code <<<"$row")"
  if [ "$code" != LD-QUALIFIED ] && [ "$code" != LD-REPLIED ]; then printf '%s\n' "$row" >>"$SCRATCH/out.jsonl"; continue; fi
  id="$(jq -r .lead_id <<<"$row")"
  url="$(jq -r '.thread_url // empty' <<<"$row")"
  # A lead with no thread URL cannot be matched to a send, so it cannot be followed up.
  sent_at=""
  [ -z "$url" ] || sent_at="$(jq -rs --arg u "$url" '[.[] | select(.code == "RP-SENT" and .thread_url == $u) | .at] | max // empty' "$SCRATCH/ledgers.jsonl")"
  if [ -z "$sent_at" ]; then printf '%s\n' "$row" >>"$SCRATCH/out.jsonl"; continue; fi
  new="$(jq -c --arg at "$(sweep_now)" --arg s "$sent_at" '.code = "LD-REPLIED" | .reason = "our reply is out" | .last_sent_at = $s | .updated_at = $at
      | .followups_sent = (.followups_sent // 0)' <<<"$row")"
  [ "$code" = LD-REPLIED ] || { printf '%s LD-REPLIED -\n' "$id" >>"$SCRATCH/moved.txt"; log "$id: LD-REPLIED (RP-SENT at $sent_at)"; }
  finish_row() { # <code> <reason> : record a terminal or answered outcome
    new="$(jq -c --arg c "$1" --arg r "$2" --arg at "$(sweep_now)" '.code = $c | .reason = $r | .updated_at = $at' <<<"$new")"
    printf '%s %s -\n' "$id" "$1" >>"$SCRATCH/moved.txt"; log "$id: $1 ($2)"
  }

  pending="$(jq -r '.pending_followup // empty' <<<"$new")"
  if [ -n "$pending" ]; then
    if [ "$(jq -rs --arg p "$pending" '[.[] | select(.id == $p and .code == "RP-DROPPED")] | length' "$REPLY/decisions.jsonl")" != 0 ]; then
      new="$(jq -c '.pending_followup = null' <<<"$new")"
      finish_row LD-CLOSED "owner dropped follow-up $pending"
      printf '%s\n' "$new" >>"$SCRATCH/out.jsonl"; continue
    fi
    if [ "$(jq -rs --arg p "$pending" --arg u "$url" '[.[] | select(.code == "RP-SENT" and .id == $p and .thread_url == $u)] | length' "$SCRATCH/ledgers.jsonl")" != 0 ]; then
      new="$(jq -c '.pending_followup = null | .followups_sent += 1' <<<"$new")"
      log "$id: follow-up $pending was sent; followups_sent $(jq -r .followups_sent <<<"$new")"
    else
      printf '%s\n' "$new" >>"$SCRATCH/out.jsonl"; continue   # one follow-up at a time; its card is still open
    fi
  fi

  last="$(awk -F'\t' -v u="$url" '$1 == u { l = $2 } END { print l }' "$SCRATCH/last.tsv")"
  if [ -n "$last" ] && [[ ${last:0:10} > ${sent_at:0:10} ]]; then
    finish_row LD-ANSWERED "they wrote on $last, after our send on ${sent_at:0:10}"
    printf '%s\n' "$new" >>"$SCRATCH/out.jsonl"; continue
  fi

  if [ $((now_s - $(date -u -d "$sent_at" +%s))) -lt $((after_days * 86400)) ]; then printf '%s\n' "$new" >>"$SCRATCH/out.jsonl"; continue; fi

  sent_n="$(jq -r .followups_sent <<<"$new")"
  if [ "$sent_n" -ge "$max" ]; then
    finish_row LD-COLD "$sent_n follow-ups sent, no answer (followup_max $max)"
    printf '%s\n' "$new" >>"$SCRATCH/out.jsonl"; continue
  fi

  did="fu-$id-$((sent_n + 1))"
  if [ ! -e "$REPLY/drafts/$did.txt" ]; then
    sender="$(jq -r '.sender // ""' <<<"$new")"
    name="${sender%% *}"
    body="$(cat "$TEMPLATE"; printf x)"; body="${body%x}"
    printf '%s' "${body//\{name\}/${name:-there}}" >"$SCRATCH/draft.txt"
    mv "$SCRATCH/draft.txt" "$REPLY/drafts/$did.txt"
    jq -cn --arg at "$(sweep_now)" --arg id "$did" --arg to "$sender" --arg url "$url" --arg lead "$id" --argjson n "$((sent_n + 1))" --arg run "$run" \
      '{schema_version:1, at:$at, code:"RP-DRAFTED", id:$id, to:$to, thread_url:$url, lead_id:$lead, followup:$n, run_id:$run}' >>"$LEDGER"
  fi
  drafted=1
  new="$(jq -c --arg d "$did" '.pending_followup = $d' <<<"$new")"
  printf '%s LD-REPLIED %s\n' "$id" "$did" >>"$SCRATCH/moved.txt"
  log "$id: follow-up draft $did"
  printf '%s\n' "$new" >>"$SCRATCH/out.jsonl"
done <"$LEADS"

# leads.jsonl has one writer (design 18, R3, node B21d): lead-ledger.sh. Unchanged rows are no-ops there.
bash "$HERE/lead-ledger.sh" append --run "$run" <"$SCRATCH/out.jsonl"
# The card is the whole point of the draft: raise it now so the draft never sits unseen. reply-cards.sh is idempotent.
if [ "$drafted" = 1 ]; then bash "$HERE/reply-cards.sh" --run "$run" >/dev/null; fi
cat "$SCRATCH/moved.txt"
sweep_check S6 "A follow-up is never sent without its own approval" "$(find "$RUN_DIR" -name 'send-*.txt' | wc -l) send-*.txt files; drafts only under reply/drafts"
sweep_check S6 "None for a decline, an answer or a booked call" "$(jq -s '[.[] | select(.pending_followup != null and .code != "LD-REPLIED")] | length' "$LEADS") non-REPLIED leads holding a pending follow-up"
