#!/usr/bin/env bash
# Stub LinkedIn send seat for reply-send.sh's suite. Run by stub-herdr.sh on every `pane read`: one call is one step, and it
# prints what the pane shows. It plays the seat's brief (templates/brief-linkedin-send.md) with no browser:
#   step 1  show the id, recipient, sha256 and text, then RP-AWAITING-CONFIRM
#   later   once the owner's line has been SHOWN in the pane (an earlier step), type: write the readback; wait for the token;
#           click once; write the result. The seat never looks at the controller's ledger to decide anything.
# Environment (tests set these):
#   STUB_SEAT_DIR      state dir, same as stub-reply-start.sh
#   STUB_SEAT_MODE     ok (default) | mismatch (types one character wrong, three times) | denied | already | early (types at step 1)
#                      | rogue (claims RP-SENT with no readback and no token) | badresult (writes a result that does not validate)
#   STUB_OWNER_LINE    the line the owner "types"; unset = never. STUB_OWNER_AT is the step it appears at (default 2).
#   STUB_LEDGER        the ledger file, ONLY so `typed` log lines can say whether RP-CONFIRMED was already in it
# Log: $STUB_SEAT_DIR/seat.log, one line per act: shown, typed <n> confirmed=<yes|no>, clicked, result <status>.
: "${STUB_SEAT_DIR:?stub-reply-seat: STUB_SEAT_DIR must be set}"
D="$STUB_SEAT_DIR"
mode="${STUB_SEAT_MODE:-ok}"
n=$(($(cat "$D/step" 2>/dev/null || echo 0) + 1)); echo "$n" >"$D/step"
b="$D/brief.md"
field() { sed -n "s/^$1: //p" "$b" | head -n1; }
id="$(field 'Reply id')" file="$(field 'Approval file')" sha="$(field 'Approved sha256')" url="$(field 'Thread URL')"
to="$(field 'Recipient')"
rb="$(dirname "$file")/readback-$id.txt" tok="$(dirname "$file")/verified-$id.token" res="$(dirname "$file")/send-result-$id.json"
now() { date -u +%Y-%m-%dT%H:%M:%SZ; }
log() { echo "$*" >>"$D/seat.log"; }
confirmed() { if grep -q '"code":"RP-CONFIRMED"' "${STUB_LEDGER:-/dev/null}" 2>/dev/null; then echo yes; else echo no; fi; }
write_result() { # <status> <clicks> <box_empty> <readback_equals> <errors json>
  local click=null at; at="$(now)"
  [ "$2" = 1 ] && click="\"$at\""
  mkdir -p "$(dirname "$file")/proof"
  [ "$2" = 1 ] && printf 'png' >"$(dirname "$file")/proof/$id.png"
  jq -n --arg id "$id" --arg url "$url" --arg f "$file" --arg sha "$sha" --arg st "$1" --arg at "$at" --argjson clicks "$2" \
    --argjson click "$click" --argjson box "$3" --argjson rb "$4" --argjson errs "$5" --arg rbp "$rb" --arg tk "$tok" --arg shot "$(dirname "$file")/proof/$id.png" \
    --argjson conf "$([ "$1" = RP-SENT ] && echo "\"$at\"" || echo null)" \
    '{schema_version:1, id:$id, thread_url:$url, approval_file:$f, sha256:$sha, status:$st, started_at:$at, finished_at:$at,
      confirmed_at:$conf, send_clicks:$clicks, send_clicked_at:$click, typed_attempts:0, box_empty_at_end:$box,
      readback_equals_file:$rb, proof:{readback_path:(if $clicks == 1 then $rbp else null end), token_path:(if $clicks == 1 then $tk else null end), screenshot_path:(if $clicks == 1 then $shot else null end)},
      errors:$errs, tab_closed:true}' >"$res"
  log "result $1"
}
type_text() { # attempt number
  case "$mode" in
    mismatch) { cat "$file"; printf 'X'; } >"$rb" ;;   # one character too many, differently placed per attempt below
    *) cp "$file" "$rb" ;;
  esac
  [ "$mode" = mismatch ] && printf '%s' "$1" >>"$rb"
  log "typed $1 confirmed=$(confirmed)"
}

# What the pane shows. The owner's line is part of it from STUB_OWNER_AT on.
{
  printf 'Reply id: %s\nRecipient: %s\nApproved sha256: %s\n' "$id" "$to" "$sha"
  cat "$file"; printf '\nRP-AWAITING-CONFIRM\n'
  if [ -n "${STUB_OWNER_LINE:-}" ] && [ "$n" -ge "${STUB_OWNER_AT:-2}" ]; then printf '%s\n' "$STUB_OWNER_LINE"; fi
}
[ "$n" = 1 ] && log "shown"
[ -f "$res" ] && exit 0

seen_before="$D/line-seen"   # set at the end of the step that first displayed the owner's line
case "$mode" in
  early) [ "$n" = 1 ] && type_text 1; exit 0 ;;
esac
if [ -f "$seen_before" ]; then
  case "$mode" in
    denied) write_result RP-DENIED-CLASSIFIER 0 true false '[{"at":"2026-10-16T00:00:00Z","step":"L7","message":"denied by the auto mode classifier"}]' ;;
    already) write_result RP-ALREADY-SENT 0 true false '[]' ;;
    rogue) log clicked; write_result RP-SENT 1 true true '[]' ;;
    badresult) echo '{}' >"$res"; log "result invalid" ;;
    mismatch)
      a=$(($(cat "$D/attempts" 2>/dev/null || echo 0) + 1))
      if [ "$a" -le 3 ]; then echo "$a" >"$D/attempts"; type_text "$a"
      else write_result RP-TEXT-MISMATCH 0 true false '[{"at":"2026-10-16T00:00:00Z","step":"L8","message":"three mismatches"}]'; fi ;;
    ok)
      if [ -f "$rb" ] && [ -f "$tok" ]; then log clicked; write_result RP-SENT 1 true true '[]'
      elif [ ! -f "$rb" ]; then type_text 1; fi ;;
  esac
fi
if [ -n "${STUB_OWNER_LINE:-}" ] && [ "$n" -ge "${STUB_OWNER_AT:-2}" ] && [ "$STUB_OWNER_LINE" = "send $id" ]; then : >"$seen_before"; fi
exit 0
