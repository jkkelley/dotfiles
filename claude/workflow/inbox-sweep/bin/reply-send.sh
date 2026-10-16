#!/usr/bin/env bash
# shellcheck disable=SC2016 # jq filters use $var; they are jq variables, single quotes are the point
# node: L6
# node: L6b
# node: L11
# reply-send.sh - L6 (send seat), L6b (owner confirm) and L11 (result record) of the LinkedIn reply DAG, build node B17b.
#
#   reply-send.sh send   --approval <send-*.txt>        start ONE send seat for ONE approved file and see it through
#   reply-send.sh status [--day <yyyymmdd>]              one line per approval: id, latest code, sha256 head, path
#   reply-send.sh prune  [--days N] [--ledger-days N] [--dry-run]
#
# `make reply-send APPROVAL=<file>`, `make reply-status`, `make reply-prune DAYS=14` call these.
#
# WHAT send DOES, in order (each step is a node of the reply DAG, design 14.2 and 14.3):
#   1. Checks the file: it is an approvals.jsonl row's path, its bytes hash to the row's sha256, nothing later superseded it,
#      the row has a thread URL and a recipient. Anything else exits 4 and starts nothing.
#   2. The exactly-once check on the ledger. An RP-SENT or RP-ALREADY-SENT row for this sha256 and thread means no seat is
#      started: the answer is RP-ALREADY-SENT (design 14.4 "Already sent"). RP-UNPROVEN, RP-TEXT-MISMATCH and RP-FAILED-SEAT
#      are terminal too and refuse a rerun (exit 3): after a click the controller never resends (rule exactly-once).
#   3. Renders templates/brief-linkedin-send.md and starts the seat (L6). Ledger row RP-SENDING.
#   4. Polls the seat's pane. When the pane shows RP-AWAITING-CONFIRM, the approved sha256, and then a line that is exactly
#      `send <id>`, it writes RP-CONFIRMED quoting the line (L6b). A line naming any other id is ignored, never guessed at.
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
# all, each beginning with the ledger check; then RP-FAILED-SEAT. Not built here: the fresh seat whose only job is to clear a
# box a dead seat left (design 14.4 "Partial text left in a box"); it needs its own brief and is raised with the result of B17b.
#
# The L6 pane contract and the real seat start (workflow-spawn.sh, then `herdr agent get` for the pane) are exercised only by
# the first live send (B18); the suite drives a stub seat through SWEEP_SEAT_START and a stub herdr.
#
# Environment (tests point these at a sandbox):
#   SWEEP_TRIAGE_ROOT          default <win-home>; holds the inbox-triage-<yyyymmdd> folders
#   SWEEP_LEDGER_FILE          where rows are written (default: the approval's own folder's ledger.jsonl); reads cover every folder
#   SWEEP_OWNER_WORDS          default ~/.config/zenith/inbox-sweep/owner-words.md
#   SWEEP_SEAT_START           command: <brief-file> <seat-name> <ticket-id>; prints the pane id. Default: workflow-spawn.sh
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
    while IFS= read -r f; do gone "$f"; done < <(find "$folder" -maxdepth 1 -type f \( -name 'readback-*' -o -name 'verified-*.token*' -o -name 'send-result-*.json*' -o -name 'brief-*.md' \) -mtime +"$days")
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

# ---------------------------------------------------------------- send
approval=""
while [ $# -gt 0 ]; do
  case "$1" in --approval) [ $# -ge 2 ] || usage; approval="$2"; shift 2 ;; *) usage ;; esac
done
[ -n "$approval" ] || usage
[ -f "$approval" ] || { echo "reply-send: no approval file $approval" >&2; exit 3; }
approval="$(readlink -f "$approval")"
sha="$(sha_of "$approval")"
row="$(all_approvals | jq -sc --arg p "$approval" --arg s "$sha" '[.[] | select((.path == $p) and .sha256 == $s)] | last // empty')"
if [ -z "$row" ]; then
  echo "reply-send: $approval is in no approvals.jsonl row with sha256 $sha; refusing a file the owner's approval does not name" >&2
  exit 4
fi
id="$(jq -r .id <<<"$row")"; url="$(jq -r '.thread_url // empty' <<<"$row")"; to="$(jq -r '.to // empty' <<<"$row")"
key="$(jq -r .thread_key <<<"$row")"; rev="$(jq -r .revision <<<"$row")"
[[ $id =~ ^[A-Za-z0-9][A-Za-z0-9-]{0,63}$ ]] || { echo "reply-send: id '$id' cannot be a seat id" >&2; exit 4; }
[ -n "$url" ] || { echo "reply-send: $id has no thread URL; nothing to send to" >&2; exit 4; }
[ -n "$to" ] || { echo "reply-send: $id has no recipient name; the seat could not check the sender" >&2; exit 4; }
[[ $approval == */inbox-triage-*/send-*.txt ]] || { echo "reply-send: $approval is outside the allow rule glob" >&2; exit 4; }
if [ "$(all_approvals | jq -s --arg k "$key" --argjson r "$rev" '[.[] | select(.thread_key == $k and .revision > $r)] | length')" != 0 ] ||
  [ "$(latest_code "$id" "$sha")" = RP-SUPERSEDED ]; then
  echo "reply-send: $id is superseded by a later revision; a superseded file is never sent" >&2
  exit 4
fi
FOLDER="$(dirname "$approval")"
LEDGER="${SWEEP_LEDGER_FILE:-$FOLDER/ledger.jsonl}"
mkdir -p "$(dirname "$LEDGER")" "$FOLDER/proof"
touch "$LEDGER"
READBACK="$FOLDER/readback-$id.txt" TOKEN="$FOLDER/verified-$id.token" RESULT="$FOLDER/send-result-$id.json"
SEAT_NAME="agent-reply-$id"
SCRATCH="$(mktemp -d)"; trap 'rm -rf "$SCRATCH"' EXIT

ledger() { # <code> [json object of extra fields]
  local extra="${2:-}"
  [ -n "$extra" ] || extra='{}'
  jq -cn --arg at "$(sweep_now)" --arg code "$1" --arg id "$id" --arg sha "$sha" --arg url "$url" --argjson extra "$extra" \
    '{schema_version:1, at:$at, code:$code, id:$id, sha256:$sha, thread_url:$url} + $extra' >>"$LEDGER"
}
finish() { # <code> <exit>
  printf '%s %s\n' "$id" "$1"
  exit "$2"
}

# --- the exactly-once check (L6 checklist box 3)
prior="$(latest_code "$id" "$sha")"
sent_rows="$(all_ledgers | jq -s --arg s "$sha" --arg u "$url" '[.[] | select((.code == "RP-SENT" or .code == "RP-ALREADY-SENT") and .sha256 == $s and .thread_url == $u)] | length')"
if [ "$sent_rows" != 0 ]; then
  [ "$prior" = RP-ALREADY-SENT ] || [ "$prior" = RP-SENT ] || ledger RP-ALREADY-SENT '{"reason":"ledger"}'
  finish RP-ALREADY-SENT 0
fi
case "$prior" in
  RP-UNPROVEN | RP-TEXT-MISMATCH | RP-FAILED-SEAT)
    echo "reply-send: $id already ended $prior; it is not rerun. The orchestrator decides (design 14.6)." >&2; exit 3 ;;
  RP-SENDING | RP-AWAITING-CONFIRM | RP-CONFIRMED)
    if herdr agent get "$SEAT_NAME" >/dev/null 2>&1; then
      echo "reply-send: seat $SEAT_NAME still holds $id ($prior)" >&2; exit 3
    fi ;;   # the seat is gone: the old row is a dead seat's, and this run is a fresh start (counts as one of the 3)
esac

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
render_brief() {
  SEAT="$SEAT_NAME" REPLY_ID="$id" APPROVAL_FILE="$(wp "$approval")" THREAD_URL="$url" RECIPIENT="$to" SHA256="$sha" \
    DEADLINE_AT="$DEADLINE_AT" READBACK_PATH="$(wp "$READBACK")" TOKEN_PATH="$(wp "$TOKEN")" SCREEN_PS1="$(wp "$HERE/screen.ps1")" \
    PROOF_PATH="$(wp "$FOLDER/proof/$id.png")" RESULT_PATH="$(wp "$RESULT")" SCHEMA_PATH="$(wp "$SWEEP/schemas/send-result.schema.json")" \
    OWNER_WORDS="$OWNER_WORDS" \
    envsubst '${SEAT} ${REPLY_ID} ${APPROVAL_FILE} ${THREAD_URL} ${RECIPIENT} ${SHA256} ${DEADLINE_AT} ${READBACK_PATH} ${TOKEN_PATH} ${SCREEN_PS1} ${PROOF_PATH} ${RESULT_PATH} ${SCHEMA_PATH} ${OWNER_WORDS}' \
    <"$SWEEP/templates/brief-linkedin-send.md" >"$FOLDER/brief-$id.md"
}

# Default seat start: the declared workflow through workflow-spawn.sh (launcher claude-win-chrome, bypass). The pane id comes
# from herdr. NOT exercised by the suite; B18 is where this meets a real herdr.
# shellcheck disable=SC2317 # reached through $seat_start, which shellcheck cannot follow
default_seat_start() { # <brief-file> <seat-name> <ticket>
  bash "$SWEEP/../bin/workflow-spawn.sh" inbox-sweep-linkedin-send --ticket "$3" --brief-file "$1" >&2 || return 1
  herdr agent get "$2" | jq -r '.result.agent.pane_id // empty'
}
read_pane() { # prints the pane text; the CLI may wrap it in JSON
  local raw
  raw="$(herdr pane read "$1" 2>/dev/null)" || return 1
  jq -r '.result.text // .result.output // empty' <<<"$raw" 2>/dev/null | grep . || printf '%s\n' "$raw"
}
# Prints the owner's confirming line if the pane shows: the approved sha256, then RP-AWAITING-CONFIRM, then a line exactly `send <id>`.
confirm_line() { # <pane text>
  awk -v id="$id" -v sha="$sha" '
    { line = $0; gsub(/^[ \t]+|[ \t\r]+$/, "", line) }
    index($0, sha) { shown = 1 }
    line == "RP-AWAITING-CONFIRM" && shown { waiting = 1; next }
    waiting && line == "send " id { print line; exit }
  ' <<<"$1"
}
awaiting_shown() { grep -qx 'RP-AWAITING-CONFIRM' <<<"$(sed 's/^[ \t]*//; s/[ \t\r]*$//' <<<"$1")" && grep -q "$sha" <<<"$1"; }

starts=0
while :; do
  # --- L6: one fresh start
  starts=$((starts + 1))
  [ -f "$RESULT" ] && mv -f "$RESULT" "$RESULT.prev-$(date -u +%Y%m%dT%H%M%SZ)-$starts"
  # A token or readback from an earlier attempt must never open this attempt's gate.
  rm -f "$TOKEN" "$TOKEN.tmp" "$READBACK"
  render_brief
  ledger RP-SENDING "$(jq -cn --argjson n "$starts" --arg seat "$SEAT_NAME" '{start:$n, seat:$seat}')"
  seat_start="${SWEEP_SEAT_START:-default_seat_start}"
  if ! pane="$($seat_start "$FOLDER/brief-$id.md" "$SEAT_NAME" "$id" | tail -n1)" || [ -z "$pane" ]; then
    ledger RP-FAILED-SEAT '{"reason":"seat did not start"}'
    finish RP-FAILED-SEAT 1
  fi

  confirmed=0 awaiting=0 mismatches=0 final_mismatch=0 last_key="" died=0 early=0
  i=0
  while [ "$i" -lt "$maxpolls" ]; do
    i=$((i + 1))
    text="$(read_pane "$pane" || true)"
    # --- L6b: the owner's own line
    if [ "$confirmed" = 0 ] && [ -n "$text" ]; then
      if [ "$awaiting" = 0 ] && awaiting_shown "$text"; then awaiting=1; ledger RP-AWAITING-CONFIRM '{}'; fi
      line="$(confirm_line "$text")"
      if [ -n "$line" ]; then
        confirmed=1
        ledger RP-CONFIRMED "$(jq -cn --arg l "$line" '{line:$l}')"
      fi
    fi
    # --- the seat's result, if it is there
    if [ -f "$RESULT" ]; then break; fi
    # --- L8: typing before the owner's line is a broken gate
    if [ -f "$READBACK" ] && [ "$confirmed" = 0 ]; then early=1; break; fi
    if [ -f "$READBACK" ] && [ "$final_mismatch" = 0 ] && [ ! -f "$TOKEN" ]; then
      key="$(stat -c %.9Y "$READBACK"):$(sha_of "$READBACK")"
      if [ "$key" != "$last_key" ]; then
        last_key="$key"
        if bash "$HERE/reply-verify.sh" --id "$id" --approval "$approval" --readback "$READBACK" >/dev/null 2>"$SCRATCH/verify.err"; then
          :   # the token is written; the seat is waiting for it
        else
          mismatches=$((mismatches + 1))
          if [ "$mismatches" -ge 3 ]; then final_mismatch=1; fi   # no token is ever written now; the seat clears the box and reports
        fi
      fi
    fi
    # a seat that is gone and left no result is dead
    if [ -z "$text" ] && ! herdr agent get "$SEAT_NAME" >/dev/null 2>&1; then died=1; break; fi
    "$sleeper" "$poll"
  done

  if [ "$early" = 1 ]; then
    rm -f "$TOKEN"
    ledger RP-FAILED-SEAT '{"reason":"typed before the owner line"}'
    finish RP-FAILED-SEAT 1
  fi
  if [ ! -f "$RESULT" ]; then
    if [ "$final_mismatch" = 1 ]; then   # no result, so nobody proved the box empty
      ledger RP-TEXT-MISMATCH '{"box_state":"unconfirmed"}'
      finish RP-TEXT-MISMATCH 1
    fi
    if [ "$confirmed" = 0 ] && [ "$died" = 0 ]; then finish RP-AWAITING-CONFIRM 5; fi   # the owner has not typed; the seat stays up
    if [ -f "$TOKEN" ]; then   # a token may have opened the gate: never resend, never respawn
      ledger RP-UNPROVEN '{"reason":"seat ended after the token with no result"}'
      finish RP-UNPROVEN 1
    fi
    if [ "$starts" -lt 3 ] && [ "$died" = 1 ]; then continue; fi
    ledger RP-FAILED-SEAT "$(jq -cn --argjson n "$starts" '{reason:"seat produced no result", starts:$n}')"
    finish RP-FAILED-SEAT 1
  fi
  break
done

# ---------------------------------------------------------------- L11: result record
validate() { bash "$SWEEP/../tools/validate-schema.sh" "$SWEEP/schemas/send-result.schema.json" "$RESULT" 2>"$SCRATCH/verr"; }
tries=1
until validate; do
  if [ "$tries" -ge 3 ]; then
    ledger RP-FAILED-SEAT '{"reason":"result did not validate after 3 tries"}'
    finish RP-FAILED-SEAT 1
  fi
  mv -f "$RESULT" "$RESULT.invalid-$tries"
  herdr agent prompt "$pane" "Your result file $RESULT did not validate against the send-result schema. Errors: $(head -c 600 "$SCRATCH/verr" | tr '\n' ' ') Rewrite the whole file as valid JSON, then stop. Do not click anything." >/dev/null 2>&1 || true
  tries=$((tries + 1))
  w=0
  while [ ! -f "$RESULT" ] && [ "$w" -lt "$maxpolls" ]; do w=$((w + 1)); read_pane "$pane" >/dev/null || true; "$sleeper" "$poll"; done
  [ -f "$RESULT" ] || { ledger RP-FAILED-SEAT '{"reason":"no rewritten result"}'; finish RP-FAILED-SEAT 1; }
done
status="$(jq -r .status "$RESULT")"
if [ "$(jq -r .id "$RESULT")" != "$id" ] || [ "$(jq -r .sha256 "$RESULT")" != "$sha" ] || [ "$(jq -r .thread_url "$RESULT")" != "$url" ]; then
  ledger RP-FAILED-SEAT '{"reason":"result names another id, sha256 or thread"}'
  finish RP-FAILED-SEAT 1
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
    finish RP-UNPROVEN 1
  fi
fi
extra="$(jq -c '{send_clicked_at, proof, readback_equals_file, box_empty_at_end, result_path:$r}' --arg r "$RESULT" "$RESULT")"
ledger "$status" "$extra"
case "$status" in RP-SENT | RP-ALREADY-SENT) finish "$status" 0 ;; *) finish "$status" 1 ;; esac
