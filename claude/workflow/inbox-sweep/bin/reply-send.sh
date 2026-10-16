#!/usr/bin/env bash
# shellcheck disable=SC2016 # jq filters use $var; they are jq variables, single quotes are the point
# node: L6
# node: L6b
# node: L11
# reply-send.sh - L6 (send seat), L6b (owner confirm) and L11 (result record) of the LinkedIn reply DAG, build node B17b.
#
#   reply-send.sh send   [--approval <send-*.txt>]... [--max N]   ONE seat, ONE owner line, for a batch of approved files
#   reply-send.sh status [--day <yyyymmdd>]              one line per approval: id, latest code, sha256 head, path
#   reply-send.sh prune  [--days N] [--ledger-days N] [--dry-run]
#
# BATCH (design 18.4, ruling R4): with no --approval, the batch is every approval file whose latest code is RP-READY, up to
# reply_batch_max (--max, else ~/.config/zenith/inbox-sweep/config.json, else 10); the rest stay RP-READY for the next batch.
# With --approval (repeatable) the batch is exactly those files. One seat, agent-reply-batch-<batch-id>, holds the batch; the
# owner types the one line `Send them` once, and nothing else the owner or anyone types is taken for it. The older per-reply
# line `send <id>` is ignored. Each reply still has its own token, single Send, proof and ledger rows. Output: `<id> <code>` per file.
# BREADCRUMB (WO-20261016-c606): this replaced one seat and one owner line per file, which asked the owner to type once per reply.
# Cost: one seat serves the batch, so a seat death or a classifier denial affects every unsent file in it (design 18.4).
# `make reply-send APPROVAL=<file>`, `make reply-status`, `make reply-prune DAYS=14` call these.
#
# WHAT send DOES, in order (each step is a node of the reply DAG, design 14.2 and 14.3):
#   1. Checks the file: it is an approvals.jsonl row's path, its bytes hash to the row's sha256, nothing later superseded it,
#      the row has a thread URL and a recipient. Anything else exits 4 and starts nothing.
#   2. The exactly-once check on the ledger. An RP-SENT or RP-ALREADY-SENT row for this sha256 and thread means no seat is
#      started: the answer is RP-ALREADY-SENT (design 14.4 "Already sent"). RP-UNPROVEN, RP-TEXT-MISMATCH and RP-FAILED-SEAT
#      are terminal too and refuse a rerun (exit 3): after a click the controller never resends (rule exactly-once).
#   3. Renders templates/brief-linkedin-send.md and starts the seat (L6). Ledger row RP-SENDING.
#   4. Polls the seat's pane. When the pane shows every approved sha256, `RP-AWAITING-CONFIRM batch <batch-id>`, and then a line
#      that is exactly `Send them`, it writes RP-CONFIRMED for each file quoting the line and the batch id (L6b). Any other line is ignored.
#   5. Once confirmed it runs reply-verify.sh (L8) on each readback the seat writes. The token is the only thing that opens the
#      seat's Send. Three mismatches end it: RP-TEXT-MISMATCH, no token ever written, so no click.
#   6. Validates the seat's send-result-<id>.json against send-result.schema.json and records the outcome (L11).
#
# THE GATES THIS CONTROLLER OWNS, and what each one does not trust:
#   - Typing. A readback that exists before the owner's line was seen means the seat typed early. That is RP-FAILED-SEAT and
#     no token is ever issued for it. The brief tells the seat to wait; this is the check that it did.
#   - Send. A result that says RP-SENT is recorded as RP-SENT only if the controller itself saw RP-CONFIRMED, the token exists
#     for this approval file's sha256, and the token is not later than the click. Anything else is RP-UNPROVEN: a click with
#     no matching gate is the one thing that must never read as success.
#   - The click is never retried and the seat is never respawned once a token exists (rule exactly-once, design 14.4).
#   - A classifier denial (result status RP-DENIED-CLASSIFIER) is recorded and the controller stops. Zero retries, no second
#     seat, no prompt, no other tool: recovery is the owner's own action in the send session (design 14.4, spec failure
#     classifier-denial). The approval file stays valid.
#
# Seat death before a token: a seat that is gone (herdr cannot find it) and wrote no result is started again, up to 3 starts in
# all, each beginning with the ledger check; then RP-FAILED-SEAT.
#
# A seat that died AFTER typing (its readback file exists) may have left text in the box. Design 14.4 "Partial text left in a
# box": before anything else happens the controller starts a fresh CLEAR seat (templates/brief-linkedin-clear.md, build node
# B17c) whose only job is to empty that one thread's box and prove it empty. It types nothing and clicks nothing. Up to 3 clear
# seats; the first whose result says box_empty true with an empty box_text wins and the ledger gets RP-BOX-CLEARED, then the
# original code follows as before (respawn or RP-FAILED-SEAT, or RP-UNPROVEN when a token had opened the gate). If 3 clear
# seats cannot prove the box empty, ONE Bearings card (id RP-BOX-<id>, never duplicated) asks the owner to look at the thread,
# the original code is written with box_state "unconfirmed", and no further send seat is started for it: a box nobody could
# empty is not given a new seat that would type into it.
#
# The L6 pane contract and the real seat start (workflow-spawn.sh, then `herdr agent get` for the pane) are exercised only by
# the first live send (B18); the suite drives a stub seat through SWEEP_SEAT_START and a stub herdr.
#
# Environment (tests point these at a sandbox):
#   SWEEP_TRIAGE_ROOT          default <win-home>; holds the inbox-triage-<yyyymmdd> folders
#   SWEEP_LEDGER_FILE          where rows are written (default: the approval's own folder's ledger.jsonl); reads cover every folder
#   SWEEP_OWNER_WORDS          default ~/.config/zenith/inbox-sweep/owner-words.md
#   SWEEP_SEAT_START           command: <brief-file> <seat-name> <ticket-id>; prints the pane id. Default: workflow-spawn.sh
#   SWEEP_CLEAR_SEAT_START     same contract, for the clear seat (B17c). Default: the same workflow-spawn.sh start
#   SWEEP_CARDS_FILE           default ~/.bearings/inbox-sweep/questions.json; where the one "box not cleared" card is added
#   SWEEP_CONFIG               default ~/.config/zenith/inbox-sweep/config.json; reply_batch_max is read from it
#   SWEEP_BATCH_ID             default the UTC time yyyymmddHHMMSS; names the seat agent-reply-batch-<batch-id>
#   SWEEP_SEND_POLL_SECONDS    wait between pane reads (default 5); SWEEP_SLEEP is the command that waits
#   SWEEP_SEND_MAX_POLLS       pane reads per seat before giving up (default 4320 = 6 hours at 5 seconds)
#   SWEEP_TODAY                yyyymmdd "today" for prune's ledger tier (default: today, UTC)
#
# Exit (send): 0 RP-SENT or RP-ALREADY-SENT; 1 any other terminal code; 2 usage; 3 precondition (no file, a seat already holds
# it, a terminal code is already recorded); 4 integrity (hash, supersession, no thread); 5 still waiting for the owner's line.
# Output: `<id> <code>`.  Every record written carries an integer schema_version (design 15.2), version 1.
# Design: docs/design/inbox-sweep.md sections 10 (B17), 14.2 to 14.7; spec nodes reply-dag L6 L6b L11 and build node B17.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SWEEP="$(cd "$HERE/.." && pwd)"
# shellcheck source=sweep-lib.sh
. "$HERE/sweep-lib.sh"

usage() {
  echo "usage: reply-send.sh send --approval <file> | status [--day yyyymmdd] | prune [--days N] [--ledger-days N] [--dry-run]" >&2
  exit 2
}
[ $# -ge 1 ] || usage
cmd="$1"; shift

TRIAGE="${SWEEP_TRIAGE_ROOT:-$(sweep_win_home)}"
all_ledgers() { cat "$TRIAGE"/inbox-triage-*/ledger.jsonl 2>/dev/null || true; }
all_approvals() { cat "$TRIAGE"/inbox-triage-*/approvals.jsonl 2>/dev/null || true; }
sha_of() { sha256sum "$1" | cut -d' ' -f1; }
# Latest lifecycle code this controller or reply-approve.sh recorded for one approval (id + sha256), or RP-READY.
latest_code() { # <id> <sha256>
  all_ledgers | jq -rs --arg id "$1" --arg s "$2" \
    '[.[] | select(.id == $id and .sha256 == $s and (.code | IN("RP-READY","RP-SENDING","RP-AWAITING-CONFIRM","RP-CONFIRMED","RP-SENT","RP-ALREADY-SENT","RP-TEXT-MISMATCH","RP-NO-BROWSER","RP-NO-RECIPIENT","RP-SIGNED-OUT","RP-DENIED-CLASSIFIER","RP-UNPROVEN","RP-FAILED-SEAT","RP-SUPERSEDED")))] | (last | .code) // "RP-READY"'
}

case "$cmd" in
  status)
    day=""
    while [ $# -gt 0 ]; do
      case "$1" in --day) [ $# -ge 2 ] || usage; day="$2"; shift 2 ;; *) usage ;; esac
    done
    [ -z "$day" ] || [[ $day =~ ^[0-9]{8}$ ]] || usage
    glob="$TRIAGE/inbox-triage-${day:-*}/approvals.jsonl"
    # shellcheck disable=SC2086 # the glob is the point
    rows="$(cat $glob 2>/dev/null || true)"
    printf '%s\n' "$rows" | jq -rc 'select(.id) | [.id, .sha256, .path] | @tsv' | while IFS=$'\t' read -r id sha path; do
      printf '%s\t%s\t%s\t%s\n' "$id" "$(latest_code "$id" "$sha")" "${sha:0:8}" "$path"
    done
    exit 0 ;;
  prune) ;;
  send) ;;
  *) usage ;;
esac

# ---------------------------------------------------------------- prune
if [ "$cmd" = prune ]; then
  days=14 ledger_days=90 dry=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --days) [ $# -ge 2 ] || usage; days="$2"; shift 2 ;;
      --ledger-days) [ $# -ge 2 ] || usage; ledger_days="$2"; shift 2 ;;
      --dry-run) dry=1; shift ;;
      *) usage ;;
    esac
  done
  [[ $days =~ ^[0-9]+$ ]] || usage
  [[ $ledger_days =~ ^[0-9]+$ ]] || usage
  today="${SWEEP_TODAY:-$(date -u +%Y%m%d)}"
  [[ $today =~ ^[0-9]{8}$ ]] || { echo "reply-send: bad SWEEP_TODAY '$today'" >&2; exit 2; }
  gone() { printf 'prune %s\n' "$1"; [ "$dry" = 1 ] || rm -rf -- "$1"; }
  # A send-<id>.txt whose newest ledger code is a live one is the owner's approval waiting to be sent; it is never pruned
  # however old (design 14.7). Everything else in the 14 day tier goes by age alone.
  for folder in "$TRIAGE"/inbox-triage-*/; do
    [ -d "$folder" ] || continue
    folder="${folder%/}"
    while IFS= read -r f; do
      [ -n "$f" ] || continue
      sha="$(sha_of "$f")"
      id="$(all_approvals | jq -rs --arg s "$sha" --arg p "$f" '[.[] | select(.sha256 == $s and .path == $p)] | (last | .id) // empty')"
      if [ -n "$id" ]; then
        case "$(latest_code "$id" "$sha")" in RP-READY | RP-SENDING | RP-AWAITING-CONFIRM | RP-CONFIRMED) continue ;; esac
      fi
      gone "$f"
    done < <(find "$folder" -maxdepth 1 -type f -name 'send-*.txt' -mtime +"$days")
    while IFS= read -r f; do gone "$f"; done < <(find "$folder" -maxdepth 1 -type f \( -name 'readback-*' -o -name 'verified-*.token*' -o -name 'send-result-*.json*' -o -name 'clear-result-*.json*' -o -name 'brief-*.md' \) -mtime +"$days")
    if [ -d "$folder/proof" ]; then
      while IFS= read -r f; do gone "$f"; done < <(find "$folder/proof" -type f -mtime +"$days")
    fi
    # The ledger tier outlives the files it guards (90 days against 14): a folder keeps its ledger while any approval file is left.
    fday="${folder##*inbox-triage-}"
    [[ $fday =~ ^[0-9]{8}$ ]] || continue
    age=$(( ($(date -u -d "$today" +%s) - $(date -u -d "$fday" +%s)) / 86400 ))
    if [ "$age" -gt "$ledger_days" ] && ! compgen -G "$folder/send-*.txt" >/dev/null; then
      gone "$folder/approvals.jsonl"; gone "$folder/ledger.jsonl"
      [ "$dry" = 1 ] || rmdir "$folder" 2>/dev/null || true
    fi
  done
  exit 0
fi

# ---------------------------------------------------------------- send (one batch, one seat, one owner line)
approvals=() maxn=""
while [ $# -gt 0 ]; do
  case "$1" in
    --approval) [ $# -ge 2 ] || usage; approvals+=("$2"); shift 2 ;;
    --max) [ $# -ge 2 ] || usage; maxn="$2"; shift 2 ;;
    *) usage ;;
  esac
done
auto=0
[ "${#approvals[@]}" -gt 0 ] || auto=1
# reply_batch_max: --max, else the owner's config, else 10 (design 18.4). The cap is a guess at what LinkedIn tolerates (design 16).
if [ -z "$maxn" ]; then
  maxn="$(jq -r '.reply_batch_max // empty' "${SWEEP_CONFIG:-$HOME/.config/zenith/inbox-sweep/config.json}" 2>/dev/null || true)"
fi
maxn="${maxn:-10}"
[[ $maxn =~ ^[0-9]+$ ]] && [ "$maxn" -ge 1 ] || { echo "reply-send: reply_batch_max '$maxn' is not a positive integer" >&2; exit 2; }
BATCH="${SWEEP_BATCH_ID:-$(date -u +%Y%m%d%H%M%S)}"
[[ $BATCH =~ ^[A-Za-z0-9][A-Za-z0-9-]{0,40}$ ]] || { echo "reply-send: batch id '$BATCH' cannot be a seat id" >&2; exit 2; }
SEAT_NAME="agent-reply-batch-$BATCH"
SCRATCH="$(mktemp -d)"; trap 'rm -rf "$SCRATCH"' EXIT

# Per-file state. Index k holds one approval file of the batch; ctx k loads it into the working variables the helpers use.
A_PATH=() A_ID=() A_SHA=() A_URL=() A_TO=() A_FOLDER=() A_LEDGER=() FIN=() MIS=() LKEY=() FMM=()
ctx() { # <k>
  k="$1"; approval="${A_PATH[$k]}" id="${A_ID[$k]}" sha="${A_SHA[$k]}" url="${A_URL[$k]}" to="${A_TO[$k]}" FOLDER="${A_FOLDER[$k]}"
  LEDGER="${A_LEDGER[$k]}"
  READBACK="$FOLDER/readback-$id.txt" TOKEN="$FOLDER/verified-$id.token" RESULT="$FOLDER/send-result-$id.json"
  CLEAR_RESULT="$FOLDER/clear-result-$id.json" CLEAR_SEAT="agent-reply-clear-$id"
}
ledger() { # <code> [json object of extra fields]
  local extra="${2:-}"
  [ -n "$extra" ] || extra='{}'
  jq -cn --arg at "$(sweep_now)" --arg code "$1" --arg id "$id" --arg sha "$sha" --arg url "$url" --arg b "$BATCH" --argjson extra "$extra" \
    '{schema_version:1, at:$at, code:$code, id:$id, sha256:$sha, thread_url:$url, batch:$b} + $extra' >>"$LEDGER"
}

# load_file <approval>: checks one file against the owner's approval and appends it to the arrays. Returns 3 or 4 with a message
# on stderr; the caller decides whether that stops the run (a named file) or only skips the file (the RP-READY collection).
load_file() {
  local approval="$1" sha row id url to key rev folder
  [ -f "$approval" ] || { echo "reply-send: no approval file $approval" >&2; return 3; }
  approval="$(readlink -f "$approval")"
  sha="$(sha_of "$approval")"
  row="$(all_approvals | jq -sc --arg p "$approval" --arg s "$sha" '[.[] | select((.path == $p) and .sha256 == $s)] | last // empty')"
  if [ -z "$row" ]; then
    echo "reply-send: $approval is in no approvals.jsonl row with sha256 $sha; refusing a file the owner's approval does not name" >&2
    return 4
  fi
  id="$(jq -r .id <<<"$row")"; url="$(jq -r '.thread_url // empty' <<<"$row")"; to="$(jq -r '.to // empty' <<<"$row")"
  key="$(jq -r .thread_key <<<"$row")"; rev="$(jq -r .revision <<<"$row")"
  [[ $id =~ ^[A-Za-z0-9][A-Za-z0-9-]{0,63}$ ]] || { echo "reply-send: id '$id' cannot be a seat id" >&2; return 4; }
  [ -n "$url" ] || { echo "reply-send: $id has no thread URL; nothing to send to" >&2; return 4; }
  [ -n "$to" ] || { echo "reply-send: $id has no recipient name; the seat could not check the sender" >&2; return 4; }
  [[ $approval == */inbox-triage-*/send-*.txt ]] || { echo "reply-send: $approval is outside the allow rule glob" >&2; return 4; }
  if [ "$(all_approvals | jq -s --arg k "$key" --argjson r "$rev" '[.[] | select(.thread_key == $k and .revision > $r)] | length')" != 0 ] ||
    [ "$(latest_code "$id" "$sha")" = RP-SUPERSEDED ]; then
    echo "reply-send: $id is superseded by a later revision; a superseded file is never sent" >&2
    return 4
  fi
  folder="$(dirname "$approval")"
  mkdir -p "$folder/proof"
  A_PATH+=("$approval") A_ID+=("$id") A_SHA+=("$sha") A_URL+=("$url") A_TO+=("$to") A_FOLDER+=("$folder")
  A_LEDGER+=("${SWEEP_LEDGER_FILE:-$folder/ledger.jsonl}")
  FIN+=("") MIS+=(0) LKEY+=("") FMM+=(0)
  touch "${A_LEDGER[$((${#A_PATH[@]} - 1))]}"
}

if [ "$auto" = 1 ]; then
  # Every approval file whose latest code is RP-READY, oldest first, up to the cap; the rest stay RP-READY for the next batch.
  while IFS= read -r p; do
    [ -n "$p" ] || continue
    [ "${#A_PATH[@]}" -lt "$maxn" ] || break
    [ -f "$p" ] || continue
    s="$(sha_of "$p")"; rid="$(all_approvals | jq -rs --arg p "$p" --arg s "$s" '[.[] | select(.path == $p and .sha256 == $s)] | (last | .id) // empty')"
    [ -n "$rid" ] && [ "$(latest_code "$rid" "$s")" = RP-READY ] || continue
    load_file "$p" 2>/dev/null || true
  done < <(all_approvals | jq -r '.path // empty' | awk '!seen[$0]++')
  if [ "${#A_PATH[@]}" = 0 ]; then echo "reply-send: no RP-READY reply to send"; exit 0; fi
else
  for p in "${approvals[@]}"; do load_file "$p" || exit $?; done
fi
N="${#A_PATH[@]}"

# --- the exactly-once check (L6 checklist box 3), per file
for ((k = 0; k < N; k++)); do
  ctx "$k"
  prior="$(latest_code "$id" "$sha")"
  sent_rows="$(all_ledgers | jq -s --arg s "$sha" --arg u "$url" '[.[] | select((.code == "RP-SENT" or .code == "RP-ALREADY-SENT") and .sha256 == $s and .thread_url == $u)] | length')"
  if [ "$sent_rows" != 0 ]; then
    [ "$prior" = RP-ALREADY-SENT ] || [ "$prior" = RP-SENT ] || ledger RP-ALREADY-SENT '{"reason":"ledger"}'
    FIN[k]=RP-ALREADY-SENT
    continue
  fi
  case "$prior" in
    RP-UNPROVEN | RP-TEXT-MISMATCH | RP-FAILED-SEAT)
      echo "reply-send: $id already ended $prior; it is not rerun. The orchestrator decides (design 14.6)." >&2; exit 3 ;;
    RP-SENDING | RP-AWAITING-CONFIRM | RP-CONFIRMED)
      holder="$(all_ledgers | jq -rs --arg id "$id" --arg s "$sha" '[.[] | select(.id == $id and .sha256 == $s and .code == "RP-SENDING")] | (last | .seat) // empty')"
      if herdr agent get "${holder:-agent-reply-$id}" >/dev/null 2>&1; then
        echo "reply-send: seat ${holder:-agent-reply-$id} still holds $id ($prior)" >&2; exit 3
      fi ;;   # the seat is gone: the old row is a dead seat's, and this run is a fresh start (counts as one of the 3)
  esac
done

report() { # prints one `<id> <code>` per file and exits: 5 if the owner has not typed, 1 if any file ended otherwise, else 0
  local rc=0 c
  for ((k = 0; k < N; k++)); do
    c="${FIN[$k]:-RP-AWAITING-CONFIRM}"
    printf '%s %s\n' "${A_ID[$k]}" "$c"
    case "$c" in RP-SENT | RP-ALREADY-SENT) ;; RP-AWAITING-CONFIRM) [ "$rc" = 1 ] || rc=5 ;; *) rc=1 ;; esac
  done
  exit "$rc"
}
pending() { P=(); for ((k = 0; k < N; k++)); do [ -n "${FIN[$k]}" ] || P+=("$k"); done; }
pending
[ "${#P[@]}" -gt 0 ] || report

# --- the brief
OWNER_FILE="${SWEEP_OWNER_WORDS:-$HOME/.config/zenith/inbox-sweep/owner-words.md}"
if [ ! -f "$OWNER_FILE" ] || ! grep -q '[^[:space:]]' "$OWNER_FILE"; then
  echo "PF-NO-OWNER-WORDS: $OWNER_FILE is missing or empty; no seat started" >&2; exit 3
fi
OWNER_WORDS="Dated (UTC): $(date -u -r "$OWNER_FILE" +%Y-%m-%dT%H:%M:%SZ)
$(cat "$OWNER_FILE")"
poll="${SWEEP_SEND_POLL_SECONDS:-5}" maxpolls="${SWEEP_SEND_MAX_POLLS:-4320}"
sleeper="${SWEEP_SLEEP:-sleep}"
DEADLINE_AT="$(date -u -d "+$((poll * maxpolls)) seconds" +%Y-%m-%dT%H:%M:%SZ)"
# Browser seats run in Windows claude.exe, which needs Windows paths; wslpath is absent off WSL, where the plain path is all there is.
wp() { if command -v wslpath >/dev/null 2>&1; then wslpath -w "$1"; else printf '%s\n' "$1"; fi; }
BRIEF_FILE=""
render_brief() { # the replies still unsent, in order; one block each so the seat reads exactly its own paths
  local blocks="" n=0 j
  for j in "${P[@]}"; do
    ctx "$j"; n=$((n + 1))
    blocks+="### Reply $n of ${#P[@]}
Reply id: $id
Approval file: $(wp "$approval")
Thread URL: $url
Recipient: $to
Approved sha256: $sha
Readback path: $(wp "$READBACK")
Token path: $(wp "$TOKEN")
Proof path: $(wp "$FOLDER/proof/$id.png")
Result path: $(wp "$RESULT")

"
  done
  ctx "${P[0]}"
  BRIEF_FILE="${A_FOLDER[${P[0]}]}/brief-batch-$BATCH.md"
  SEAT="$SEAT_NAME" BATCH_ID="$BATCH" REPLY_COUNT="${#P[@]}" REPLY_BLOCKS="$blocks" DEADLINE_AT="$DEADLINE_AT" \
    SCREEN_PS1="$(wp "$HERE/screen.ps1")" SCHEMA_PATH="$(wp "$SWEEP/schemas/send-result.schema.json")" OWNER_WORDS="$OWNER_WORDS" \
    envsubst '${SEAT} ${BATCH_ID} ${REPLY_COUNT} ${REPLY_BLOCKS} ${DEADLINE_AT} ${SCREEN_PS1} ${SCHEMA_PATH} ${OWNER_WORDS}' \
    <"$SWEEP/templates/brief-linkedin-send.md" >"$BRIEF_FILE"
}

# Default seat start: the declared workflow through workflow-spawn.sh (launcher claude-win-chrome, bypass). The pane id comes
# from herdr. NOT exercised by the suite; B18 is where this meets a real herdr.
# shellcheck disable=SC2317 # reached through $seat_start, which shellcheck cannot follow
default_seat_start() { # <brief-file> <seat-name> <ticket>
  # The seat is named and declared per run (sweep_seat_config, WO-20261016-73cd); without the name the spawner matched by
  # role, found no seat, and `herdr agent get "$2"` below could never have named the started agent.
  local cfg
  cfg="$(sweep_seat_config "${A_FOLDER[0]}/seats/project.json" "$2" "inbox-sweep-linkedin-send" "$2" "${A_FOLDER[0]}/seats/$2")" || return 1
  WORKFLOW_CONFIG="$cfg" bash "$SWEEP/../bin/workflow-spawn.sh" inbox-sweep-linkedin-send "$2" --ticket "$3" --brief-file "$1" >&2 || return 1
  herdr agent get "$2" | jq -r '.result.agent.pane_id // empty'
}
read_pane() { # prints the pane text; the CLI may wrap it in JSON
  local raw
  raw="$(herdr pane read "$1" 2>/dev/null)" || return 1
  jq -r '.result.text // .result.output // empty' <<<"$raw" 2>/dev/null | grep . || printf '%s\n' "$raw"
}
# Prints the owner's confirming line if the pane shows every pending sha256, then `RP-AWAITING-CONFIRM batch <id>`, then a line
# that is exactly `Send them` (design 18.4). A line naming a file, `send <id>`, or anything else is ignored, never guessed at.
confirm_line() { # <pane text>
  awk -v b="RP-AWAITING-CONFIRM batch $BATCH" -v shas="${PEND_SHAS[*]}" '
    BEGIN { n = split(shas, S, " ") }
    { line = $0; gsub(/^[ \t]+|[ \t\r]+$/, "", line) }
    { for (i = 1; i <= n; i++) if (index($0, S[i])) seen[i] = 1 }
    line == b { all = 1; for (i = 1; i <= n; i++) if (!seen[i]) all = 0; if (all) waiting = 1; next }
    waiting && line == "Send them" { print line; exit }
  ' <<<"$1"
}
awaiting_shown() { # <pane text>
  local s
  grep -qx "RP-AWAITING-CONFIRM batch $BATCH" <<<"$(sed 's/^[ \t]*//; s/[ \t\r]*$//' <<<"$1")" || return 1
  for s in "${PEND_SHAS[@]}"; do grep -q "$s" <<<"$1" || return 1; done
}

# B17c: the fresh seat that only empties a box a dead send seat may have left text in. Returns 0 when a seat proved the box empty
# (ledger RP-BOX-CLEARED), 1 when 3 seats could not (one owner card raised). The clear seat is judged by its result file alone.
# The default start reuses the send workflow declaration (same browser link, same allowed tools) with the clear brief; like the
# send start it meets a real herdr only in B18.
clear_start() { # <brief-file> <seat-name> <ticket>
  if [ -n "${SWEEP_CLEAR_SEAT_START:-}" ]; then "$SWEEP_CLEAR_SEAT_START" "$@"; else default_seat_start "$@"; fi
}
raise_box_card() {
  local cards="${SWEEP_CARDS_FILE:-$HOME/.bearings/inbox-sweep/questions.json}" card
  mkdir -p "$(dirname "$cards")"
  [ -f "$cards" ] || echo '{"title":"Inbox sweep","items":[]}' >"$cards"
  card="$(jq -cn --arg id "RP-BOX-$id" --arg to "$to" --arg url "$url" '
    {schema_version:1, id:$id,
     about:("LinkedIn reply box not proven empty, " + $to + " (" + $url + ")"),
     decide:"A send seat died after typing and 3 clear seats could not prove the message box empty in this thread. Nothing was sent and no new seat will type into it. Please open the thread and empty the box yourself, or tell me it is clean.",
     options:[{label:"The box is empty now", then:"I record it and the reply can be decided again"},
              {label:"Leave it", then:"The reply stays stopped"}], rec:0}')"
  sweep_json_set "$cards" 'if (.items | map(.id) | index($c.id)) == null then .items += [$c + {asked:$at}] else . end' --argjson c "$card" --arg at "$(sweep_now)"
}
clear_box() {
  local n=0 cpane w
  while [ "$n" -lt 3 ]; do
    n=$((n + 1))
    rm -f "$CLEAR_RESULT"
    SEAT="$CLEAR_SEAT" REPLY_ID="$id" THREAD_URL="$url" RECIPIENT="$to" ATTEMPT="$n" DEADLINE_AT="$DEADLINE_AT" \
      RESULT_PATH="$(wp "$CLEAR_RESULT")" OWNER_WORDS="$OWNER_WORDS" \
      envsubst '${SEAT} ${REPLY_ID} ${THREAD_URL} ${RECIPIENT} ${ATTEMPT} ${DEADLINE_AT} ${RESULT_PATH} ${OWNER_WORDS}' \
      <"$SWEEP/templates/brief-linkedin-clear.md" >"$FOLDER/brief-clear-$id.md"
    if cpane="$(clear_start "$FOLDER/brief-clear-$id.md" "$CLEAR_SEAT" "$id" | tail -n1)" && [ -n "$cpane" ]; then
      w=0
      while [ ! -f "$CLEAR_RESULT" ] && [ "$w" -lt "$maxpolls" ]; do w=$((w + 1)); read_pane "$cpane" >/dev/null || true; "$sleeper" "$poll"; done
    fi
    if [ -f "$CLEAR_RESULT" ] &&
      [ "$(jq -r '[.schema_version == 1, .id == $i, .status == "RP-BOX-CLEARED", .box_empty == true, ((.box_text // "") == "")] | all' --arg i "$id" "$CLEAR_RESULT" 2>/dev/null)" = true ]; then
      ledger RP-BOX-CLEARED "$(jq -cn --argjson n "$n" --arg seat "$CLEAR_SEAT" '{clear_start:$n, seat:$seat}')"
      return 0
    fi
  done
  raise_box_card
  return 1
}

# ---------------------------------------------------------------- L11: result record, one file at a time
# settle <k>: validates the file's result, applies the gate, writes its ledger row and sets FIN[k]. A denial sets DENIED.
validate() { bash "$SWEEP/../tools/validate-schema.sh" "$SWEEP/schemas/send-result.schema.json" "$RESULT" 2>"$SCRATCH/verr"; }
DENIED=0
settle() {
  local tries=1 w status clicks click_at tok_at ok extra
  ctx "$1"
  until validate; do
    if [ "$tries" -ge 3 ]; then
      ledger RP-FAILED-SEAT '{"reason":"result did not validate after 3 tries"}'; FIN[$1]=RP-FAILED-SEAT; return
    fi
    mv -f "$RESULT" "$RESULT.invalid-$tries"
    herdr agent prompt "$pane" "Your result file $RESULT did not validate against the send-result schema. Errors: $(head -c 600 "$SCRATCH/verr" | tr '\n' ' ') Rewrite the whole file as valid JSON, then go on with the next reply. Do not click anything for this one." >/dev/null 2>&1 || true
    tries=$((tries + 1))
    w=0
    while [ ! -f "$RESULT" ] && [ "$w" -lt "$maxpolls" ]; do w=$((w + 1)); read_pane "$pane" >/dev/null || true; "$sleeper" "$poll"; done
    [ -f "$RESULT" ] || { ledger RP-FAILED-SEAT '{"reason":"no rewritten result"}'; FIN[$1]=RP-FAILED-SEAT; return; }
  done
  status="$(jq -r .status "$RESULT")"
  if [ "$(jq -r .id "$RESULT")" != "$id" ] || [ "$(jq -r .sha256 "$RESULT")" != "$sha" ] || [ "$(jq -r .thread_url "$RESULT")" != "$url" ]; then
    ledger RP-FAILED-SEAT '{"reason":"result names another id, sha256 or thread"}'; FIN[$1]=RP-FAILED-SEAT; return
  fi
  clicks="$(jq -r .send_clicks "$RESULT")"
  if [ "$clicks" != 0 ]; then
    # A click needs the whole gate: the owner's line seen here, a token for this file, and the token not later than the click.
    ok=0
    click_at="$(jq -r .send_clicked_at "$RESULT")"
    if [ "$confirmed" = 1 ] && [ -f "$TOKEN" ] && [ "$(jq -r .approval_sha256 "$TOKEN")" = "$sha" ]; then
      tok_at="$(jq -r .at "$TOKEN")"
      # UTC timestamps in one fixed shape compare correctly as strings; equal seconds pass (the token is written first).
      [[ ! $tok_at > $click_at ]] && ok=1
    fi
    if [ "$ok" = 0 ]; then
      ledger RP-UNPROVEN '{"reason":"a Send click without the controller gate: no seen owner line, no token for this file, or a token later than the click"}'
      FIN[$1]=RP-UNPROVEN; return
    fi
  fi
  extra="$(jq -c '{send_clicked_at, proof, readback_equals_file, box_empty_at_end, result_path:$r}' --arg r "$RESULT" "$RESULT")"
  ledger "$status" "$extra"
  FIN[$1]="$status"
  # A classifier denial stops the whole batch: the only recovery is the owner's own action in that session (design 18.4).
  [ "$status" != RP-DENIED-CLASSIFIER ] || DENIED=1
}

starts=0 waiting=0 pane="" confirmed=0
while :; do
  pending
  [ "${#P[@]}" -gt 0 ] || break
  starts=$((starts + 1))
  PEND_SHAS=()
  for j in "${P[@]}"; do PEND_SHAS+=("${A_SHA[$j]}"); done
  for j in "${P[@]}"; do
    ctx "$j"
    [ -f "$RESULT" ] && mv -f "$RESULT" "$RESULT.prev-$(date -u +%Y%m%dT%H%M%SZ)-$starts"
    # A token or readback from an earlier attempt must never open this attempt's gate.
    rm -f "$TOKEN" "$TOKEN.tmp" "$READBACK"
    MIS[j]=0 LKEY[j]="" FMM[j]=0
  done
  render_brief
  for j in "${P[@]}"; do ctx "$j"; ledger RP-SENDING "$(jq -cn --argjson n "$starts" --arg seat "$SEAT_NAME" '{start:$n, seat:$seat}')"; done
  seat_start="${SWEEP_SEAT_START:-default_seat_start}"
  if ! pane="$($seat_start "$BRIEF_FILE" "$SEAT_NAME" "$BATCH" | tail -n1)" || [ -z "$pane" ]; then
    for j in "${P[@]}"; do ctx "$j"; ledger RP-FAILED-SEAT '{"reason":"seat did not start"}'; FIN[j]=RP-FAILED-SEAT; done
    break
  fi

  confirmed=0 awaiting=0 died=0 early=0 DENIED=0
  i=0
  while [ "$i" -lt "$maxpolls" ]; do
    i=$((i + 1))
    text="$(read_pane "$pane" || true)"
    # --- L6b: the owner's one line for the batch
    if [ "$confirmed" = 0 ] && [ -n "$text" ]; then
      if [ "$awaiting" = 0 ] && awaiting_shown "$text"; then
        awaiting=1
        for j in "${P[@]}"; do ctx "$j"; ledger RP-AWAITING-CONFIRM '{}'; done
      fi
      line="$(confirm_line "$text")"
      if [ -n "$line" ]; then
        confirmed=1
        for j in "${P[@]}"; do ctx "$j"; ledger RP-CONFIRMED "$(jq -cn --arg l "$line" '{line:$l}')"; done
      fi
    fi
    left=0
    for j in "${P[@]}"; do
      [ -z "${FIN[$j]}" ] || continue
      ctx "$j"
      # --- the seat's result for this file, if it is there
      if [ -f "$RESULT" ]; then settle "$j"; [ "$DENIED" = 0 ] || break; continue; fi
      left=1
      # --- L8: typing before the owner's line is a broken gate
      if [ -f "$READBACK" ] && [ "$confirmed" = 0 ]; then early=1; break; fi
      if [ -f "$READBACK" ] && [ "${FMM[$j]}" = 0 ] && [ ! -f "$TOKEN" ]; then
        key="$(stat -c %.9Y "$READBACK"):$(sha_of "$READBACK")"
        if [ "$key" != "${LKEY[$j]}" ]; then
          LKEY[j]="$key"
          if bash "$HERE/reply-verify.sh" --id "$id" --approval "$approval" --readback "$READBACK" >/dev/null 2>"$SCRATCH/verify.err"; then
            :   # the token is written; the seat is waiting for it
          else
            MIS[j]=$((MIS[j] + 1))
            if [ "${MIS[$j]}" -ge 3 ]; then FMM[j]=1; fi   # no token is ever written now; the seat clears the box and reports
          fi
        fi
      fi
    done
    [ "$early" = 0 ] && [ "$DENIED" = 0 ] || break
    [ "$left" = 1 ] || { for j in "${P[@]}"; do [ -n "${FIN[$j]}" ] || left=1; done; }
    [ "$left" = 1 ] || break
    # a seat that is gone and left no result is dead
    if [ -z "$text" ] && ! herdr agent get "$SEAT_NAME" >/dev/null 2>&1; then died=1; break; fi
    "$sleeper" "$poll"
  done

  if [ "$early" = 1 ]; then
    for j in "${P[@]}"; do
      [ -z "${FIN[$j]}" ] || continue
      ctx "$j"; rm -f "$TOKEN"
      ledger RP-FAILED-SEAT '{"reason":"typed before the owner line"}'; FIN[j]=RP-FAILED-SEAT
    done
    break
  fi
  if [ "$DENIED" = 1 ]; then   # zero retries, no second seat, no prompt: every unsent file takes the denial
    for j in "${P[@]}"; do
      [ -z "${FIN[$j]}" ] || continue
      ctx "$j"; ledger RP-DENIED-CLASSIFIER '{"reason":"the batch stopped on a classifier denial"}'; FIN[j]=RP-DENIED-CLASSIFIER
    done
    break
  fi
  pending
  [ "${#P[@]}" -gt 0 ] || break
  if [ "$confirmed" = 0 ] && [ "$died" = 0 ]; then waiting=1; break; fi   # the owner has not typed; the seat stays up
  for j in "${P[@]}"; do
    ctx "$j"; box_extra='{}'
    if [ "$died" = 1 ] && [ -f "$READBACK" ]; then   # B17c: the seat died after typing
      clear_box || box_extra='{"box_state":"unconfirmed"}'
    fi
    if [ "${FMM[$j]}" = 1 ]; then   # no result, so nobody proved the box empty
      ledger RP-TEXT-MISMATCH '{"box_state":"unconfirmed"}'; FIN[j]=RP-TEXT-MISMATCH
    elif [ -f "$TOKEN" ]; then   # a token may have opened the gate: never resend, never respawn
      ledger RP-UNPROVEN "$(jq -cn --argjson x "$box_extra" '{reason:"seat ended after the token with no result"} + $x')"; FIN[j]=RP-UNPROVEN
    elif [ "$box_extra" != '{}' ]; then   # a box nobody could empty is not given a new seat that would type into it
      ledger RP-FAILED-SEAT "$(jq -cn --argjson n "$starts" --argjson x "$box_extra" '{reason:"seat produced no result", starts:$n} + $x')"; FIN[j]=RP-FAILED-SEAT
    fi
  done
  pending
  [ "${#P[@]}" -gt 0 ] || break
  if [ "$starts" -lt 3 ] && [ "$died" = 1 ]; then continue; fi   # a fresh seat for the unsent files only; it waits for the line again
  for j in "${P[@]}"; do
    ctx "$j"; ledger RP-FAILED-SEAT "$(jq -cn --argjson n "$starts" '{reason:"seat produced no result", starts:$n}')"; FIN[j]=RP-FAILED-SEAT
  done
  break
done
report
