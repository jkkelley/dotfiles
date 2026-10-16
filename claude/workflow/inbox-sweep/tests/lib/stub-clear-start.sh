#!/usr/bin/env bash
# Stub for reply-send.sh's SWEEP_CLEAR_SEAT_START (B17c): <brief-file> <seat-name> <ticket>. Prints a pane id, like the real start.
# Why it exists: the real clear seat is a Windows claude.exe driving the owner's Chrome; a test must never start one. This stub
# plays the whole seat in one call, judged by what the brief it was handed says, so the rendered brief is part of what is tested.
#   STUB_CLEAR_MODE  ok (default): box emptied, proven empty | dirty: the box still holds text | none: the seat writes no result
#   STUB_CLEAR_OK_AT  with mode dirty, the attempt number (1-3) from which the seat succeeds; unset = never
# Log: $STUB_SEAT_DIR/clear-starts.log, one line per start. The brief is kept as clear-brief-<n>.md.
: "${STUB_SEAT_DIR:?stub-clear-start: STUB_SEAT_DIR must be set}"
mkdir -p "$STUB_SEAT_DIR"
n=$(($(wc -l <"$STUB_SEAT_DIR/clear-starts.log" 2>/dev/null || echo 0) + 1))
cp "$1" "$STUB_SEAT_DIR/clear-brief-$n.md"
printf 'start %s %s\n' "$2" "$3" >>"$STUB_SEAT_DIR/clear-starts.log"
b="$1"
id="$(sed -n 's/^Reply id: //p' "$b" | head -n1)" url="$(sed -n 's/^Thread URL: //p' "$b" | head -n1)"
res="$(sed -n 's/^Result path: //p' "$b" | head -n1)"
mode="${STUB_CLEAR_MODE:-ok}"
[ "$mode" = dirty ] && [ -n "${STUB_CLEAR_OK_AT:-}" ] && [ "$n" -ge "$STUB_CLEAR_OK_AT" ] && mode=ok
case "$mode" in
  ok) jq -n --arg id "$id" --arg url "$url" '{schema_version:1, id:$id, thread_url:$url, status:"RP-BOX-CLEARED", box_empty:true, box_text:"", finished_at:"2026-10-16T00:00:00Z"}' >"$res" ;;
  dirty) jq -n --arg id "$id" --arg url "$url" '{schema_version:1, id:$id, thread_url:$url, status:"RP-BOX-CLEARED", box_empty:false, box_text:"Hi Sam", finished_at:"2026-10-16T00:00:00Z"}' >"$res" ;;
esac
printf 'wS:p8\n'
