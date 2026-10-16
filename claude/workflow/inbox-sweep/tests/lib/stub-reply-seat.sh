#!/usr/bin/env bash
# Stub LinkedIn send seat for reply-send.sh's suite. Run by stub-herdr.sh on every `pane read`: one call is one step, and it
# prints what the pane shows. It plays the batch seat's brief (templates/brief-linkedin-send.md) with no browser:
#   step 1  show, for every reply, the id, recipient, sha256 and text, then `RP-AWAITING-CONFIRM batch <batch-id>`
#   later   once the owner's line has been SHOWN in the pane (an earlier step), take the replies one after another: type (write
#           the readback), wait for the token, click once, write the result, then the next reply. The seat never looks at the
#           controller's ledger to decide anything.
# Environment (tests set these):
#   STUB_SEAT_DIR      state dir, same as stub-reply-start.sh
#   STUB_SEAT_MODES    one mode per reply, space separated, in batch order; the last one repeats. STUB_SEAT_MODE is the same for all.
#                      Modes: ok (default) | mismatch (types one character wrong, three times) | denied | already | early (types at step 1)
#                      | die (types a wrong text, then the pane goes empty: a seat that died with text in the box, no token)
#                      | die-token (types the right text so the controller issues the token, then dies: no result)
#                      | rogue (claims RP-SENT with no readback and no token) | badresult (writes a result that does not validate)
#   STUB_OWNER_LINE    the line the owner "types"; unset = never. STUB_OWNER_AT is the step it appears at (default 2).
#   STUB_LEDGER        the ledger file, ONLY so `typed` log lines can say whether RP-CONFIRMED was already in it
# Log: $STUB_SEAT_DIR/seat.log, one line per act: shown, typed <n> confirmed=<yes|no>, clicked, result <status>.
: "${STUB_SEAT_DIR:?stub-reply-seat: STUB_SEAT_DIR must be set}"
D="$STUB_SEAT_DIR"
n=$(($(cat "$D/step" 2>/dev/null || echo 0) + 1)); echo "$n" >"$D/step"
# A fresh seat start resets step; its own per-reply state goes with it.
[ "$n" = 1 ] && rm -f "$D/cur" "$D/attempts"
b="$D/brief.md"
batch="$(sed -n 's/^Batch id: //p' "$b" | head -n1)"
count="$(grep -c '^Reply id: ' "$b")"
field() { awk -v n="$1" -v key="$2" 'index($0, "Reply id: ") == 1 { c++ } c == n && index($0, key ": ") == 1 { print substr($0, length(key) + 3); exit }' "$b"; }
cur=$(($(cat "$D/cur" 2>/dev/null || echo 0) + 1))   # the reply being worked, 1-based
read -r -a modes <<<"${STUB_SEAT_MODES:-${STUB_SEAT_MODE:-ok}}"   # SC2206, WO-20261016-4409
mode_of() { local m="${modes[$(($1 - 1))]:-${modes[${#modes[@]}-1]}}"; echo "$m"; }
now() { date -u +%Y-%m-%dT%H:%M:%SZ; }
log() { echo "$*" >>"$D/seat.log"; }
confirmed() { if grep -q '"code":"RP-CONFIRMED"' "${STUB_LEDGER:-/dev/null}" 2>/dev/null; then echo yes; else echo no; fi; }
load() { # <k>: the reply's fields
  id="$(field "$1" 'Reply id')" file="$(field "$1" 'Approval file')" sha="$(field "$1" 'Approved sha256')" url="$(field "$1" 'Thread URL')"
  to="$(field "$1" 'Recipient')"
  rb="$(dirname "$file")/readback-$id.txt" tok="$(dirname "$file")/verified-$id.token" res="$(dirname "$file")/send-result-$id.json"
}
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
type_text() { # attempt number; uses the current reply's mode
  case "$mode" in
    mismatch) { cat "$file"; printf 'X'; } >"$rb"; printf '%s' "$1" >>"$rb" ;;   # one character too many, differently placed per attempt
    *) cp "$file" "$rb" ;;
  esac
  log "typed $1 confirmed=$(confirmed)"
}
next() { echo "$cur" >"$D/cur"; rm -f "$D/attempts"; }

# A dead seat shows nothing, ever again (the die modes, B17c).
[ -f "$D/died" ] && exit 0

# What the pane shows. The owner's line is part of it from STUB_OWNER_AT on.
{
  for ((r = 1; r <= count; r++)); do
    load "$r"
    printf 'Reply id: %s\nRecipient: %s\nApproved sha256: %s\n' "$id" "$to" "$sha"
    cat "$file"; printf '\n'
  done
  printf 'RP-AWAITING-CONFIRM batch %s\n' "$batch"
  if [ -n "${STUB_OWNER_LINE:-}" ] && [ "$n" -ge "${STUB_OWNER_AT:-2}" ]; then printf '%s\n' "$STUB_OWNER_LINE"; fi
}
[ "$n" = 1 ] && log "shown"

seen_before="$D/line-seen"   # set at the end of the step that first displayed the owner's line
if [ "$n" = 1 ]; then
  load 1; [ "$(mode_of 1)" = early ] && { mode=early; type_text 1; }
  exit 0
fi
if [ -f "$seen_before" ] && [ "$cur" -le "$count" ]; then
  load "$cur"; mode="$(mode_of "$cur")"
  if [ -f "$res" ]; then next   # this reply is done; the next step starts the next one
  else
    case "$mode" in
      early) next ;;
      denied) write_result RP-DENIED-CLASSIFIER 0 true false '[{"at":"2026-10-16T00:00:00Z","step":"L7","message":"denied by the auto mode classifier"}]'; echo 999 >"$D/cur" ;;   # the seat stops: the batch is over
      already) write_result RP-ALREADY-SENT 0 true false '[]' ;;
      rogue) log clicked; write_result RP-SENT 1 true true '[]' ;;
      badresult) echo '{}' >"$res"; log "result invalid" ;;
      die) { cat "$file"; printf 'X'; } >"$rb"; log "typed 1 confirmed=$(confirmed)"; : >"$D/died" ;;
      die-token) cp "$file" "$rb"; log "typed 1 confirmed=$(confirmed)"; : >"$D/died" ;;
      mismatch)
        a=$(($(cat "$D/attempts" 2>/dev/null || echo 0) + 1))
        if [ "$a" -le 3 ]; then echo "$a" >"$D/attempts"; type_text "$a"
        else write_result RP-TEXT-MISMATCH 0 true false '[{"at":"2026-10-16T00:00:00Z","step":"L8","message":"three mismatches"}]'; fi ;;
      ok)
        if [ -f "$rb" ] && [ -f "$tok" ]; then log clicked; write_result RP-SENT 1 true true '[]'
        elif [ ! -f "$rb" ]; then type_text 1; fi ;;
    esac
  fi
fi
if [ -n "${STUB_OWNER_LINE:-}" ] && [ "$n" -ge "${STUB_OWNER_AT:-2}" ] && [ "$STUB_OWNER_LINE" = "Send them" ]; then : >"$seen_before"; fi
exit 0
