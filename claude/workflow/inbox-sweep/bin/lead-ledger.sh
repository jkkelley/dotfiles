#!/usr/bin/env bash
# shellcheck disable=SC2016 # jq filters use $var; they are jq variables, single quotes are the point
# node: S1
# lead-ledger.sh - S1 (inbound) of the lead stage, build node B22.
#
#   lead-ledger.sh --run <run-id>                    record every thread in reply/linkedin.md as one LD-NEW row
#   lead-ledger.sh gate --run <run-id> --lead <id>   exit 0 only if that lead is LD-QUALIFIED (the drafting step's guard)
#
# Reads <run dir>/reply/linkedin.md, the L1 output (design 14.3): one block per conversation. A block starts at a `## ` line;
# inside it the lines `Thread: <url>`, `Sender: <name>` and `Last message: <date>` (optional leading `- `) are fields and
# every other line is the thread text. The text is DATA: it is stored and matched by lead-qualify.sh, never executed or
# followed as an instruction.
#
# Output: <run dir>/leads.jsonl, one row per thread, rewritten whole through a temp file and mv so no reader sees half a row.
# The thread key is the thread URL, or sender|last message when the block has none; lead_id is "lead-" plus the first 12 hex
# of sha256(key), so the same thread is the same lead on every rerun. A thread already in leads.jsonl is left exactly as it
# is: a rerun must not push a qualified or terminal lead back to LD-NEW. Rejected alternative: append-only event rows with
# the last row per lead winning; the ticket's check is "exactly one LD- row per thread", and a file that holds one row per
# thread proves that with a plain count.
#
# Lead codes (design 17): LD-NEW, LD-QUALIFIED, LD-NOT-A-FIT, LD-REPLIED, LD-ANSWERED, LD-CALL-PROPOSED, LD-CALL-BOOKED,
# LD-CLOSED, LD-COLD. This script only ever writes LD-NEW; lead-qualify.sh moves it on.
#
# Output, one line per thread:  <lead-id> <code>
# Exit: 0 done (gate: qualified); 1 gate: not qualified; 2 usage; 3 precondition (no run, no linkedin.md, no such lead).
#
# Every record written carries an integer schema_version (design 15.2); leads.jsonl rows are version 1.
# Environment: SWEEP_RUNS_ROOT default <win-home>/.local/state/zenith/inbox-sweep/runs
# Design: docs/design/inbox-sweep.md section 17, spec lead-stage S1 and build node B22.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=sweep-lib.sh
. "$HERE/sweep-lib.sh"

usage() { echo "usage: lead-ledger.sh --run <run-id> | gate --run <run-id> --lead <lead-id>" >&2; exit 2; }
mode=ingest
if [ "${1:-}" = gate ]; then mode=gate; shift; fi
run="" lead=""
while [ $# -gt 0 ]; do
  case "$1" in
    --run) [ $# -ge 2 ] || usage; run="$2"; shift 2 ;;
    --lead) [ $# -ge 2 ] || usage; lead="$2"; shift 2 ;;
    *) usage ;;
  esac
done
[[ $run =~ ^[0-9]{8}T[0-9]{6}Z$ ]] || { echo "lead-ledger: bad run id '$run'" >&2; exit 2; }
root="${SWEEP_RUNS_ROOT:-$(sweep_win_home)/.local/state/zenith/inbox-sweep/runs}"
RUN_DIR="$root/$run"
LEADS="$RUN_DIR/leads.jsonl"
[ -d "$RUN_DIR" ] || { echo "lead-ledger: no run $RUN_DIR" >&2; exit 3; }
export SWEEP_RUN_DIR="$RUN_DIR"

if [ "$mode" = gate ]; then
  [ -n "$lead" ] || usage
  [ -f "$LEADS" ] || { echo "lead-ledger: no leads.jsonl in $RUN_DIR" >&2; exit 3; }
  code="$(jq -r --arg id "$lead" 'select(.lead_id == $id) | .code' "$LEADS")"
  [ -n "$code" ] || { echo "lead-ledger: no lead $lead" >&2; exit 3; }
  echo "$code"
  [ "$code" = LD-QUALIFIED ]
  exit
fi

[ -n "$lead" ] && usage
SRC="$RUN_DIR/reply/linkedin.md"
[ -f "$SRC" ] || { echo "lead-ledger: no reply/linkedin.md in $RUN_DIR" >&2; exit 3; }
mkdir -p "$RUN_DIR/logs"
log() { printf '%s %s\n' "$(sweep_now)" "$*" >>"$RUN_DIR/logs/lead-ledger.log"; }
SCRATCH="$(mktemp -d)"
trap 'rm -rf "$SCRATCH"' EXIT
touch "$LEADS"

# Split into one file per block; text before the first `## ` is not a conversation and is dropped.
awk -v d="$SCRATCH" '/^## / { n++; f = sprintf("%s/blk.%05d", d, n) } n { print > f }' "$SRC"

: >"$SCRATCH/new.jsonl"
shopt -s nullglob
for blk in "$SCRATCH"/blk.*; do
  field() { sed -nE "s/^[-*]?[[:space:]]*$1[[:space:]]*:[[:space:]]*(.*[^[:space:]])?[[:space:]]*\$/\\1/p" "$blk" | head -1; }
  # One pattern per name, no groups of its own: field() prints \1, so an inner group would shift the capture (it did, once).
  url="$(field 'Thread')"; [ -n "$url" ] || url="$(field 'Thread URL')"; sender="$(field 'Sender')"; last="$(field 'Last message')"
  if [ -z "$sender" ]; then sender="$(head -1 "$blk" | sed -E 's/^##[[:space:]]*//')"; fi
  key="${url:-$sender|$last}"
  id="lead-$(printf '%s' "$key" | sha256sum | cut -c1-12)"
  grep -q "\"lead_id\":\"$id\"" "$LEADS" "$SCRATCH/new.jsonl" 2>/dev/null && continue   # one row per thread, whatever the rerun
  text="$(tail -n +2 "$blk" | grep -vE '^[-*]?[[:space:]]*(Thread( URL)?|Sender|Last message)[[:space:]]*:' || true)"
  jq -cn --arg at "$(sweep_now)" --arg run "$run" --arg id "$id" --arg key "$key" --arg url "$url" --arg sender "$sender" \
    --arg last "$last" --arg text "$text" \
    '{schema_version:1, lead_id:$id, thread_key:$key, thread_url:(if $url == "" then null else $url end), sender:$sender,
      last_message:(if $last == "" then null else $last end), text:$text, code:"LD-NEW", reason:"inbound recorded",
      run_id:$run, created_at:$at, updated_at:$at}' >>"$SCRATCH/new.jsonl"
  log "$id: LD-NEW for $key"
done

cat "$LEADS" "$SCRATCH/new.jsonl" >"$SCRATCH/all.jsonl"
mv "$SCRATCH/all.jsonl" "$LEADS.tmp" && mv "$LEADS.tmp" "$LEADS"
jq -r '[.lead_id, .code] | join(" ")' "$LEADS"
sweep_check S1 "One LD-NEW row per thread" "$(jq -s '[.[].thread_key] | length == (unique | length)' "$LEADS") unique keys in leads.jsonl"
