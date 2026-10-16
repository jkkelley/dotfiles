#!/usr/bin/env bash
# shellcheck disable=SC2016 # jq filters use $var; they are jq variables, single quotes are the point
# reply-approve.sh - L4 (apply) and L5 (write approval file) of the LinkedIn reply DAG, build node B15.
#
#   reply-approve.sh --run <run-id>
#
# Reads <run dir>/reply/decisions.jsonl, which reply-cards.sh (B14) wrote from the owner's card answers, and turns each
# approval into exactly one hashed file the send seat may be given:
#   RP-APPROVED / RP-APPROVED-EDITED  ->  <win-home>/inbox-triage-<yyyymmdd>/send-<id>.txt   (first text for a thread)
#                                         <win-home>/inbox-triage-<yyyymmdd>/send-<id>-r<n>.txt   (n-th text, n >= 2)
#                                         + one approvals.jsonl row (path, sha256, thread URL, card id) + one RP-READY row
#   RP-DROPPED                        ->  one RP-DROPPED ledger row. NO file, no approvals row (design 14.5).
# <yyyymmdd> is the UTC day the approval is written, not the run's day: the folder name is what the Windows allow rule
# matches (inbox-triage-*\send-*.txt), and a run can be answered days after it started.
#
# Bytes: the file is the decision row's `text`, written with `jq -j` (no added newline) and re-hashed after writing. If the
# file's sha256 is not the row's sha256 the approval is refused (exit 4) and the file removed: a file that does not hash to
# what the owner approved must never exist where the send seat can find it. For Send as written the file is also compared
# with drafts/<id>.txt, so a draft changed after the card was answered cannot ride an old approval. Nothing is trimmed,
# reflowed or fixed (design 14.5).
#
# One thread, many texts: the thread key is the RP-DRAFTED row's thread_url, or the draft id when there is none. A second
# approved text for a key already in any approvals.jsonl gets the next revision number, its own file and its own sha256, and
# every earlier file for the key gets an RP-SUPERSEDED ledger row. Files are never rewritten or deleted here; the seat is
# given one path, and the sha256 in approvals.jsonl, not the file name, is the real check.
#
# Idempotent: a decision already in an approvals.jsonl (same card and sha256), or a drop already in the ledger, is skipped,
# so a rerun or a poll loop adds nothing. Rejected alternative: deriving the revision from file names on disk; a file
# deleted by `make reply-prune` would then reuse its number, while approvals.jsonl outlives the files (90 days vs 14).
#
# Output, one line per decision:  <draft-id> <code>   (RP-READY, RP-DROPPED)
# Exit: 0 done; 2 usage; 3 precondition (no such run, no decisions.jsonl); 4 integrity (hash mismatch, draft changed, path
# outside the allow-rule shape, file already there with other bytes). Exit 4 stops that decision; others still run.
#
# Environment (tests point these at a sandbox):
#   SWEEP_RUNS_ROOT    default <win-home>/.local/state/zenith/inbox-sweep/runs
#   SWEEP_TRIAGE_ROOT  default <win-home>; holds the inbox-triage-<yyyymmdd> folders
#   SWEEP_TODAY        yyyymmdd the approval folder is named for (default: today, UTC)
#   SWEEP_LEDGER_FILE  default <triage folder of the run's day>/ledger.jsonl, the same file reply-cards.sh writes
#
# Every record written carries an integer schema_version (design 15.2); all are version 1.
# Design: docs/design/inbox-sweep.md sections 14.3 (L4, L5) and 14.5, spec nodes reply-dag L4 L5 and build node B15.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=sweep-lib.sh
. "$HERE/sweep-lib.sh"

usage() { echo "usage: reply-approve.sh --run <run-id>" >&2; exit 2; }
if [ $# -ne 2 ] || [ "$1" != --run ]; then usage; fi
run="$2"
[[ $run =~ ^[0-9]{8}T[0-9]{6}Z$ ]] || { echo "reply-approve: bad run id '$run'" >&2; exit 2; }

root="${SWEEP_RUNS_ROOT:-$(sweep_win_home)/.local/state/zenith/inbox-sweep/runs}"
RUN_DIR="$root/$run"
REPLY="$RUN_DIR/reply"
DECISIONS="$REPLY/decisions.jsonl"
[ -f "$DECISIONS" ] || { echo "reply-approve: no decisions.jsonl in $RUN_DIR/reply" >&2; exit 3; }
export SWEEP_RUN_DIR="$RUN_DIR"
TRIAGE="${SWEEP_TRIAGE_ROOT:-$(sweep_win_home)}"
today="${SWEEP_TODAY:-$(date -u +%Y%m%d)}"
[[ $today =~ ^[0-9]{8}$ ]] || { echo "reply-approve: bad SWEEP_TODAY '$today'" >&2; exit 2; }
FOLDER="$TRIAGE/inbox-triage-$today"
APPROVALS="$FOLDER/approvals.jsonl"
LEDGER="${SWEEP_LEDGER_FILE:-$TRIAGE/inbox-triage-${run:0:8}/ledger.jsonl}"
mkdir -p "$RUN_DIR/logs" "$FOLDER" "$(dirname "$LEDGER")"
LOG="$RUN_DIR/logs/reply-approve.log"
log() { printf '%s %s\n' "$(sweep_now)" "$*" >>"$LOG"; }
touch "$APPROVALS" "$LEDGER"
SCRATCH="$(mktemp -d)"
trap 'rm -rf "$SCRATCH"' EXIT

ledger_add() { # <code> <draft id> <card id> [path] [sha256]
  jq -cn --arg at "$(sweep_now)" --arg code "$1" --arg id "$2" --arg card "$3" --arg run "$run" --arg path "${4-}" --arg sha "${5-}" \
    '{schema_version:1, at:$at, code:$code, id:$id, card:$card, run_id:$run}
     + (if $path != "" then {path:$path, sha256:$sha} else {} end)' | bash "$HERE/reply-ledger.sh" append --file "$LEDGER"
}
drafted_field() { jq -rs --arg id "$1" --arg f "$2" '[.[] | select(.code == "RP-DRAFTED" and .id == $id) | .[$f] // empty] | last // empty' "$LEDGER" 2>/dev/null || true; }
# Every approvals.jsonl in every triage folder: the thread's earlier texts may have been approved on another day.
all_approvals() { cat "$TRIAGE"/inbox-triage-*/approvals.jsonl 2>/dev/null || true; }

rc=0
statuses="$SCRATCH/status.tsv"
: >"$statuses"
# The last decision row per draft id is the recorded one (reply-cards.sh never writes two, but a hand repair might).
while IFS= read -r row; do
  [ -n "$row" ] || continue
  did="$(jq -r .id <<<"$row")"; cid="$(jq -r .card <<<"$row")"; code="$(jq -r .code <<<"$row")"
  if ! [[ $did =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]]; then log "skipped decision with unsafe id: $did"; continue; fi
  case "$code" in
    RP-DROPPED)
      # Drop: a ledger row and nothing else. No text file, no approvals row.
      if [ "$(jq -s --arg c "$cid" '[.[] | select(.code == "RP-DROPPED" and .card == $c)] | length' "$LEDGER")" = 0 ]; then
        ledger_add RP-DROPPED "$did" "$cid"
        log "$did: dropped, no file written"
      fi
      printf '%s\tRP-DROPPED\n' "$did" >>"$statuses" ;;
    RP-APPROVED | RP-APPROVED-EDITED)
      sha="$(jq -r .sha256 <<<"$row")"
      if [ "$(all_approvals | jq -s --arg c "$cid" --arg s "$sha" '[.[] | select(.card == $c and .sha256 == $s)] | length')" != 0 ]; then
        printf '%s\tRP-READY\n' "$did" >>"$statuses"; continue   # already applied
      fi
      jq -j .text <<<"$row" >"$SCRATCH/text.bin"
      if [ "$(sha256sum "$SCRATCH/text.bin" | cut -d' ' -f1)" != "$sha" ] || [ ! -s "$SCRATCH/text.bin" ]; then
        log "$did: REFUSED, decision text does not hash to its sha256 (or is empty)"; echo "reply-approve: $did text does not match its sha256" >&2; rc=4; continue
      fi
      if [ "$code" = RP-APPROVED ] && ! cmp -s "$SCRATCH/text.bin" "$REPLY/drafts/$did.txt"; then
        log "$did: REFUSED, draft changed since the card was answered; a changed text needs a new card (design 14.5)"
        echo "reply-approve: $did draft differs from the approved text" >&2; rc=4; continue
      fi
      url="$(drafted_field "$did" thread_url)"; to="$(drafted_field "$did" to)"
      key="${url:-draft:$did}"
      # Earlier approvals for this thread, oldest first; revision = how many there are, plus one.
      prior="$(all_approvals | jq -sc --arg k "$key" '[.[] | select(.thread_key == $k)]')"
      n=$(( $(jq length <<<"$prior") + 1 ))
      name="send-$did.txt"; [ "$n" -gt 1 ] && name="send-$did-r$n.txt"
      path="$FOLDER/$name"
      # The Windows allow rule matches inbox-triage-*\send-*.txt; a path of any other shape would not be authorised.
      if ! [[ $path == */inbox-triage-*/send-*.txt ]]; then log "$did: REFUSED, $path is outside the allow rule glob"; rc=4; continue; fi
      if [ -e "$path" ]; then
        log "$did: REFUSED, $path already exists; approved files are never overwritten"; echo "reply-approve: $path exists" >&2; rc=4; continue
      fi
      # Written through a temp file in the same folder, then mv, so no reader sees half an approval; hashed again after.
      cp "$SCRATCH/text.bin" "$FOLDER/.$name.tmp" && mv "$FOLDER/.$name.tmp" "$path"
      if [ "$(sha256sum "$path" | cut -d' ' -f1)" != "$sha" ]; then rm -f "$path"; log "$did: REFUSED, written file does not hash to $sha"; rc=4; continue; fi
      jq -cn --arg at "$(sweep_now)" --arg run "$run" --arg id "$did" --arg card "$cid" --arg code "$code" --arg key "$key" \
        --arg url "$url" --arg to "$to" --arg path "$path" --arg sha "$sha" --argjson rev "$n" \
        '{schema_version:1, at:$at, run_id:$run, id:$id, card:$card, code:$code, thread_key:$key, thread_url:(if $url == "" then null else $url end),
          to:(if $to == "" then null else $to end), revision:$rev, path:$path, sha256:$sha}' >>"$APPROVALS"
      # The previous file for the thread is superseded (earlier ones already were): the ledger says so, the files stay (the seat is given one path).
      while IFS=$'\t' read -r oid ocard opath osha; do
        [ -n "$oid" ] || continue
        ledger_add RP-SUPERSEDED "$oid" "$ocard" "$opath" "$osha"
        log "$oid: $opath superseded by $path"
      done < <(jq -r '.[-1:][] | [.id, .card, .path, .sha256] | @tsv' <<<"$prior")
      ledger_add RP-READY "$did" "$cid" "$path" "$sha"
      log "$did: $code -> $path"
      printf '%s\tRP-READY\n' "$did" >>"$statuses" ;;
    *) log "$did: ignored decision code '$code'" ;;
  esac
done < <(jq -sc 'reduce .[] as $d ({}; .[$d.id] = $d) | .[]' "$DECISIONS")

while IFS=$'\t' read -r d c; do printf '%s %s\n' "$d" "$c"; done <"$statuses"
exit "$rc"
