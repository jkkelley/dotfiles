#!/usr/bin/env bash
# shellcheck disable=SC2016 # jq filters use $var; they are jq variables, single quotes are the point
# reply-cards.sh - L3 of the LinkedIn reply DAG, and the read-back half of L4: one Bearings card per draft, then the
# owner's answers read into decisions.jsonl.
#
#   reply-cards.sh --run <run-id>
#
# Two jobs in one pass, both idempotent so a rerun (or a poll loop) is safe:
#   1. Card:  every <run dir>/reply/drafts/<id>.txt gets exactly one card, id RP-<run>-<id>, with the FULL draft text and
#             exactly three options: Send as written, Send with my edits, Drop. Its first appearance writes one
#             RP-AWAITING-OWNER row to the ledger. A card already in questions.json is never rewritten or removed.
#   2. Read:  the Bearings server appends answers to answers.jsonl beside questions.json (latest per id wins). Each answer
#             to one of this run's cards becomes one decisions.jsonl row {id, choice, code, text, sha256}. A card with no
#             answer, or with a Send-with-my-edits answer that holds no text, writes nothing and stays RP-AWAITING-OWNER.
#
# This script writes no approval file and sends nothing: that is reply-approve.sh (B15) and the send seat. It only turns
# "the owner clicked" into a row that B15 can apply verbatim.
#
# Byte rules (design 14.5): Send as written records the draft file's bytes; Send with my edits records the answer's words
# byte for byte. Nothing is trimmed, reflowed or fixed. The sha256 is taken over exactly those bytes, from a file written
# with `jq -j`, because bash command substitution strips trailing newlines and a hash of the stripped text is not the
# hash of what the owner approved. Whether edited words are finished text or an instruction is a judgement code cannot
# make; only the empty answer is refused here. The card tells the owner what to write, and the owner reads what is sent
# (the L6b pane prints the exact text) before it goes.
#
# A decision is final once recorded. A later, different answer to the same card is logged and ignored: changed text is a
# new approval and a new card (design 14.5), never a silent rewrite of one the approval file may already rest on.
#
# Output, one line per draft:  <draft-id> <RP-code>   (RP-AWAITING-OWNER, RP-APPROVED, RP-APPROVED-EDITED, RP-DROPPED)
# Exit: 0 pass done; 2 usage; 3 precondition (no such run, no reply/drafts directory).
#
# Environment (tests point these at a sandbox):
#   SWEEP_RUNS_ROOT       default <win-home>/.local/state/zenith/inbox-sweep/runs
#   SWEEP_CARDS_FILE      default ~/.bearings/inbox-sweep/questions.json; answers.jsonl and server.json sit beside it
#   SWEEP_BEARINGS_SERVER default ~/.claude/skills/bearings/scripts/server.mjs
#   SWEEP_LEDGER_FILE     default <win-home>/inbox-triage-<yyyymmdd of the run>/ledger.jsonl
#   SWEEP_HERDR_WORKSPACE herdr workspace label for the server pane (default dotfiles)
#
# Every record written carries an integer schema_version (design 15.2); all are version 1.
# Design: docs/design/inbox-sweep.md section 14.3 (L3, L4), spec node reply-dag L3, build node B14.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=sweep-lib.sh
. "$HERE/sweep-lib.sh"

usage() { echo "usage: reply-cards.sh --run <run-id>" >&2; exit 2; }
if [ $# -ne 2 ] || [ "$1" != --run ]; then usage; fi
run="$2"
[[ $run =~ ^[0-9]{8}T[0-9]{6}Z$ ]] || { echo "reply-cards: bad run id '$run'" >&2; exit 2; }

root="${SWEEP_RUNS_ROOT:-$(sweep_win_home)/.local/state/zenith/inbox-sweep/runs}"
RUN_DIR="$root/$run"
REPLY="$RUN_DIR/reply"
CARDS="${SWEEP_CARDS_FILE:-$HOME/.bearings/inbox-sweep/questions.json}"
ANSWERS="$(dirname "$CARDS")/answers.jsonl"
SERVER_JS="${SWEEP_BEARINGS_SERVER:-$HOME/.claude/skills/bearings/scripts/server.mjs}"
[ -d "$REPLY/drafts" ] || { echo "reply-cards: no reply/drafts in $RUN_DIR" >&2; exit 3; }
export SWEEP_RUN_DIR="$RUN_DIR"
LEDGER="${SWEEP_LEDGER_FILE:-$(sweep_win_home)/inbox-triage-${run:0:8}/ledger.jsonl}"
DECISIONS="$REPLY/decisions.jsonl"
mkdir -p "$RUN_DIR/logs" "$(dirname "$CARDS")" "$(dirname "$LEDGER")"
LOG="$RUN_DIR/logs/reply-cards.log"
log() { printf '%s %s\n' "$(sweep_now)" "$*" >>"$LOG"; }
touch "$DECISIONS" "$LEDGER"
[ -f "$CARDS" ] || echo '{"title":"Inbox sweep","items":[]}' >"$CARDS"
SCRATCH="$(mktemp -d)"
trap 'rm -rf "$SCRATCH"' EXIT

# Recipient and thread come from the RP-DRAFTED ledger row if the drafting seat wrote them (fields `to`, `thread_url`).
# They are optional: the card must still be raised, with the draft id as its only handle, rather than wait on metadata.
drafted_field() { jq -rs --arg id "$1" --arg f "$2" '[.[] | select(.code == "RP-DRAFTED" and .id == $id) | .[$f] // empty] | last // empty' "$LEDGER" 2>/dev/null || true; }

ledger_add() { # <code> <draft id> <card id>
  jq -cn --arg at "$(sweep_now)" --arg code "$1" --arg id "$2" --arg card "$3" --arg run "$run" \
    '{schema_version:1, at:$at, code:$code, id:$id, card:$card, run_id:$run}' >>"$LEDGER"
}

# 1. Cards. A draft whose name is not a plain token is skipped and logged: it becomes part of a card id and a path.
candidates="[]"
for f in "$REPLY"/drafts/*.txt; do
  [ -f "$f" ] || continue
  did="$(basename "$f" .txt)"
  if ! [[ $did =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]]; then log "skipped draft with unsafe name: $did"; continue; fi
  to="$(drafted_field "$did" to)"
  url="$(drafted_field "$did" thread_url)"
  card="$(jq -cn --rawfile text "$f" --arg id "RP-$run-$did" --arg did "$did" --arg to "$to" --arg url "$url" '
    {schema_version:1, id:$id,
     about:("LinkedIn reply draft " + $did + (if $to != "" then " to " + $to else "" end) + (if $url != "" then " (" + $url + ")" else "" end)),
     decide:("Nothing sends until you answer this card. Full draft text:\n\n" + $text),
     options:[{label:"Send as written", then:"An agent sends exactly this text; you confirm once in the send pane"},
              {label:"Send with my edits", then:"Put your finished message in the answer box; it is sent byte for byte, nothing added or fixed"},
              {label:"Drop", then:"No reply, nothing is sent"}], rec:0}')"
  candidates="$(jq -c --argjson c "$card" '. + [$c]' <<<"$candidates")"
done

before="$(jq '.items | length' "$CARDS")"
# Existing items are never edited or removed, so an answered card keeps its id and its text.
sweep_json_set "$CARDS" '.items += ([$c[] | select(.id as $i | ($cur | index($i)) == null)] | map(. + {asked:$at}))' \
  --argjson c "$candidates" --argjson cur "$(jq -c '[.items[].id]' "$CARDS")" --arg at "$(sweep_now)"
after="$(jq '.items | length' "$CARDS")"
log "drafts $(jq length <<<"$candidates"), items before $before, after $after, added $((after - before))"

# RP-AWAITING-OWNER once per card, however many reruns: keyed on the ledger, not on whether the card was just added, so a
# crash between the two writes is healed by the next pass instead of leaving a card with no ledger row.
for f in "$REPLY"/drafts/*.txt; do
  [ -f "$f" ] || continue
  did="$(basename "$f" .txt)"
  [[ $did =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] || continue
  if [ "$(jq -s --arg c "RP-$run-$did" '[.[] | select(.code == "RP-AWAITING-OWNER" and .card == $c)] | length' "$LEDGER")" = 0 ]; then
    ledger_add RP-AWAITING-OWNER "$did" "RP-$run-$did"
  fi
done

# 2. Read back. answers.jsonl holds every answer ever given; the latest line per id is the owner's current one.
latest="[]"
if [ -s "$ANSWERS" ]; then
  latest="$(jq -sc --arg p "RP-$run-" '[.[] | select((.id // "") | startswith($p))] | reduce .[] as $a ({}; .[$a.id] = $a) | [.[]]' "$ANSWERS" 2>/dev/null || echo '[]')"
fi
# Snapshot for the run (spec output `reply/answers.json`); written through a temp file so a reader never sees half of it.
jq -n --argjson a "$latest" '{schema_version:1, answers:$a}' >"$SCRATCH/answers.json"
mv "$SCRATCH/answers.json" "$REPLY/answers.json"

statuses="$SCRATCH/status.tsv"
: >"$statuses"
for f in "$REPLY"/drafts/*.txt; do
  [ -f "$f" ] || continue
  did="$(basename "$f" .txt)"
  [[ $did =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] || continue
  cid="RP-$run-$did"
  existing="$(jq -s --arg id "$did" '[.[] | select(.id == $id)] | last // empty | .code' -r "$DECISIONS")"
  ans="$(jq -c --arg id "$cid" 'map(select(.id == $id)) | last // empty' <<<"$latest")"
  if [ -n "$existing" ]; then
    # Final once recorded. Log if the owner has since answered differently, so it is visible rather than silent.
    if [ -n "$ans" ] && [ "$(jq -r .choice <<<"$ans")" != "$(jq -s --arg id "$did" '[.[] | select(.id == $id)] | last | .choice' -r "$DECISIONS")" ]; then
      log "$did: answer changed after decision $existing; ignored, a changed text needs a new card (design 14.5)"
    fi
    printf '%s\t%s\n' "$did" "$existing" >>"$statuses"
    continue
  fi
  if [ -z "$ans" ]; then printf '%s\tRP-AWAITING-OWNER\n' "$did" >>"$statuses"; continue; fi
  choice="$(jq -r .choice <<<"$ans")"
  case "$choice" in
    "Send as written")
      code=RP-APPROVED
      cp "$f" "$SCRATCH/text.bin" ;;
    "Send with my edits")
      code=RP-APPROVED-EDITED
      jq -j '.words' <<<"$ans" >"$SCRATCH/text.bin"
      if [ ! -s "$SCRATCH/text.bin" ]; then
        log "$did: Send with my edits with empty words; not an approval, card stays open"
        printf '%s\tRP-AWAITING-OWNER\n' "$did" >>"$statuses"
        continue
      fi ;;
    "Drop")
      code=RP-DROPPED
      : >"$SCRATCH/text.bin" ;;
    *)
      log "$did: unknown choice '$choice'; card stays open"
      printf '%s\tRP-AWAITING-OWNER\n' "$did" >>"$statuses"
      continue ;;
  esac
  if [ "$code" = RP-DROPPED ]; then
    jq -cn --arg at "$(sweep_now)" --arg id "$did" --arg card "$cid" --arg run "$run" --arg choice "$choice" --arg code "$code" \
      '{schema_version:1, at:$at, run_id:$run, id:$id, card:$card, choice:$choice, code:$code, text:null, sha256:null}' >>"$DECISIONS"
  else
    sha="$(sha256sum "$SCRATCH/text.bin" | cut -d' ' -f1)"
    jq -cn --rawfile text "$SCRATCH/text.bin" --arg at "$(sweep_now)" --arg id "$did" --arg card "$cid" --arg run "$run" \
      --arg choice "$choice" --arg code "$code" --arg sha "$sha" \
      '{schema_version:1, at:$at, run_id:$run, id:$id, card:$card, choice:$choice, code:$code, text:$text, sha256:$sha}' >>"$DECISIONS"
  fi
  log "$did: decision $code"
  printf '%s\t%s\n' "$did" "$code" >>"$statuses"
done

# Server: only when nothing is serving, so the owner can find the cards. Labeled pane, never a background job.
sweep_bearings_server "$CARDS" "$SERVER_JS"
while IFS=$'\t' read -r d c; do printf '%s %s\n' "$d" "$c"; done <"$statuses"
