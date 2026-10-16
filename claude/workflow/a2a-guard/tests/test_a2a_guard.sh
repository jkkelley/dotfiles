#!/usr/bin/env bash
# name: test_a2a_guard.sh
# purpose: the a2a-guard dev gate: send, deliver and lint against a fake herdr and fake nats.
# inputs: none; run by make a2a-guard-test
# outputs: stdout ok/FAIL lines, exit code
# writes-to: a mktemp scratch path
# cleanup: removes its own temp files on exit
# shellcheck disable=SC2016  # jq programs and the planted bad script are single-quoted on purpose.
# test_a2a_guard.sh - the a2a-guard dev gate: a2a-send, a2a-deliver and a2a-lint against a fake herdr and a fake nats.
# Run by `make a2a-guard-test` in Podman (dotfiles Rule 14), --network=none. Notifies nobody (item 35).
set -uo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"; WF="$(cd "$HERE/.." && pwd)"
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
export FAKE_DIR="$T/fake" HERDR_BIN="$HERE/tests/fake-herdr" A2A_STATE_DIR="$T/state" ARTIFACT_ROOT="$T/store"
export NATS_BIN="$T/nats" A2A_LINE=dev
mkdir -p "$FAKE_DIR/status" "$FAKE_DIR/input"; : > "$FAKE_DIR/calls.log"
printf '#!/bin/sh\necho "$@" >> %s/nats.log\n' "$T" > "$NATS_BIN"; chmod +x "$NATS_BIN"
fail=0
check() { if [ "$1" = "$2" ]; then echo "ok  $3"; else echo "FAIL $3 (want '$1', got '$2')"; fail=1; fi; }
now=$(date -u +%Y-%m-%dT%H:%M:%SZ)
brief() { jq --arg at "$now" "$1" "$WF/templates/a2a/brief.json" > "$2"; }
brief '.at=$at | .actions=["build make a2a-send"]' "$T/order.json"
SEND="$HERE/a2a-send.sh"; DELIVER="$HERE/a2a-deliver.sh"
prompts() { grep -c '^agent prompt' "$FAKE_DIR/calls.log"; }

# AC2 - ack-only orders, both shapes, are refused before anything is written.
brief '.at=$at | .actions=["acknowledge this order"]' "$T/ack1.json"
out=$(bash "$SEND" --to sweep-build --file "$T/ack1.json" 2>&1); rc=$?
check "3 A2A-ACK-REFUSED" "$rc $(printf '%s' "$out" | awk '{print $1}')" "AC2 ack-only order refused with A2A-ACK-REFUSED (exit 3)"
brief '.at=$at | .acceptance_criteria[0].statement="reply with ok when read"' "$T/ack2.json"
bash "$SEND" --to sweep-build --file "$T/ack2.json" >/dev/null 2>&1; check 3 $? "an AC that asks for an ack is refused (exit 3)"
check 0 "$(find "$T/store" -name '*.json' ! -name '*.meta.json' 2>/dev/null | wc -l)" "a refused order writes nothing to the store"

# P3 - a hand-guessed future timestamp and a non-schema file are refused.
brief '.at="2099-01-01T00:00:00Z"' "$T/future.json"
out=$(bash "$SEND" --to sweep-build --file "$T/future.json" 2>&1); check "3 A2A-AT-FUTURE" "$? ${out%% *}" "a future-dated order is refused"
echo "please ack" > "$T/prose.txt"
out=$(bash "$SEND" --to sweep-build --file "$T/prose.txt" 2>&1); check "3 A2A-INVALID" "$? ${out%% *}" "prose is refused"

# AC3 - two sends in the same second get two distinct store paths.
echo working > "$FAKE_DIR/status/sweep-build"
# Both sends start together (xargs -P2, no background job), and the pair is retried until both land in one second.
for _ in 1 2 3 4 5 6 7 8; do
  mapfile -t p < <(printf '1\n2\n' | xargs -P2 -I{} bash "$SEND" --to sweep-build --file "$T/order.json" 2>/dev/null | awk '/^A2A-QUEUED/{print $2}')
  a=${p[0]:-} b=${p[1]:-}
  [ -n "$a" ] && [ "$(basename "$a" | cut -c1-15)" = "$(basename "$b" | cut -c1-15)" ] && break
done
check "same-second distinct" "$([ "$(basename "$a" | cut -c1-15)" = "$(basename "$b" | cut -c1-15)" ] && echo same-second)$([ -n "$a" ] && [ "$a" != "$b" ] && [ -s "$a" ] && [ -s "$b" ] && echo ' distinct')" \
  "AC3 two sends in one second, two distinct artifact paths"
echo "     $a"; echo "     $b"
[[ $(basename "$a") =~ ^[0-9]{8}-[0-9]{6}-sweep-build-[0-9a-f]{6}\.json$ ]]; check 0 $? "the name is the store format YYYYMMDD-HHMMSS-<seat>-<tail>.json"
check 1 "$([ -f "$a.meta.json" ] && echo 1)" "artifact.sh wrote the frontmatter beside it"

# AC1 (dev half) - busy seat: queued, nothing typed. Idle seat: one prompt carrying every queued pointer.
rm -rf "$T/state"; : > "$FAKE_DIR/calls.log"; : > "$T/nats.log"
bash "$SEND" --to sweep-build --file "$T/order.json" >/dev/null 2>&1
held=$(bash "$SEND" --to sweep-build --file "$T/order.json" 2>&1 | grep -c '^A2A-HELD sweep-build status=working')
check "0 1" "$(prompts) $held" "busy seat: nothing typed, A2A-HELD status=working"
check 2 "$(find "$T/state/queue/dev/sweep-build" -maxdepth 1 -name "*.ptr" | wc -l)" "busy seat: both messages queued"
check 2 "$(grep -c ' pub a2a.dev.sweep-build ' "$T/nats.log")" "each send was published on a2a.<line>.<seat>"
echo idle > "$FAKE_DIR/status/sweep-build"; echo "half typed owner line" > "$FAKE_DIR/input/sweep-build"
out=$(bash "$DELIVER" --line dev); check "0 A2A-HELD" "$(prompts) ${out%% *}" "idle seat with text on its input line: nothing typed"
: > "$FAKE_DIR/input/sweep-build"
out=$(bash "$DELIVER" --line dev)
check "1 2" "$(prompts) $(grep '^agent prompt' "$FAKE_DIR/calls.log" | grep -o '/a2a/[0-9/]*[0-9-]*sweep-build-[0-9a-f]*\.json' | sort -u | wc -l)" \
  "idle seat: exactly one prompt carrying both pointers"
check "A2A-DELIVERED" "${out%% *}" "the pass reports A2A-DELIVERED"
bash "$DELIVER" --line dev >/dev/null; check 1 "$(prompts)" "a second pass delivers nothing again"

# P3 - a hand-named pointer slipped into the queue is refused at delivery, never typed.
mkdir -p "$T/state/queue/dev/sweep-build"; echo "$T/orchestrator-msg-20261016T0512Z.json" > "$T/state/queue/dev/sweep-build/1.ptr"
touch "$T/orchestrator-msg-20261016T0512Z.json"
out=$(bash "$DELIVER" --line dev); check "1 A2A-NAME-REFUSED" "$(prompts) ${out%% *}" "a hand-named order file is refused, not delivered"

# AC4 - lint fails a raw send-text outside a2a-guard, passes the tree.
mkdir -p "$T/repo/claude/x"; printf '#!/bin/sh\nherdr pane send-text "$p" "do the thing"\n' > "$T/repo/claude/x/bad.sh"
out=$(bash "$HERE/a2a-lint.sh" --root "$T/repo"); check "1 A2A-RAW-SEND" "$? ${out%% *}" "AC4 lint fails a raw send-text (exit 1)"
echo "     $out"
bash "$HERE/a2a-lint.sh" --root "$WF/../.." >/dev/null; check 0 $? "the dotfiles tree itself is clean"

if [ $fail = 0 ]; then echo "ok  a2a-guard dev gate"; else echo "FAIL a2a-guard dev gate"; exit 1; fi
