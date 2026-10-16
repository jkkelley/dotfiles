#!/usr/bin/env bash
# Stub for reply-send.sh's SWEEP_SEAT_START: <brief-file> <seat-name> <ticket>. Prints the pane id, like the real start.
# Why it exists: the real start is workflow-spawn.sh, which needs herdr and a Windows claude.exe; a test must never start a seat.
# It copies the brief into $STUB_SEAT_DIR so the stub seat (stub-reply-seat.sh) reads the id, file, thread and sha256 the
# controller actually rendered, which makes the brief part of what the tests exercise. Each call is a line in starts.log.
: "${STUB_SEAT_DIR:?stub-reply-start: STUB_SEAT_DIR must be set}"
mkdir -p "$STUB_SEAT_DIR"
cp "$1" "$STUB_SEAT_DIR/brief.md"
printf 'start %s %s\n' "$2" "$3" >>"$STUB_SEAT_DIR/starts.log"
# A fresh seat has not seen the owner's line: the controller must wait for it again (design 14.4 respawn).
rm -f "$STUB_SEAT_DIR/step" "$STUB_SEAT_DIR/died" "$STUB_SEAT_DIR/line-seen"
printf 'wS:p9\n'
