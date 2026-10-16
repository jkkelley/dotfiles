#!/usr/bin/env bash
# name: uat.sh
# purpose: the a2a-guard UAT gate on the real herdr: a test seat busy then idle gets exactly one line.
# outputs: stdout ok/FAIL lines with herdr status before and after, exit code
# writes-to: the artifact store (a2a and log keys), a mktemp scratch dir
# uat.sh - the a2a-guard UAT gate on the real herdr and bus: a test seat (uat-idle) on the line's grid is reported
#   working, gets two a2a-sends (both must queue, nothing typed), is reported idle, and must receive exactly one line.
#
# usage: uat.sh [--line QUEUE_LINE] [--grid-line GRID_LINE]
#   QUEUE_LINE (default uat) keeps the test queue apart from real lines; GRID_LINE (default config .line) is where the
#   test seat's pane is claimed, by herdr-grid.sh, labeled uat-idle, and closed again at the end.
# exit: 0 AC1 observed, 1 not observed, 4 io. Prints herdr status before and after, then the evidence path.
# inputs: config.json (A2A_CONFIG), HERDR_BIN. writes-to: the artifact store (a2a and log keys), a temp queue dir.
# cleanup: the test seat's pane is closed (seat-down FORCE=1) and the temp queue removed on every exit path.
# Notifies nobody (Design principles 101 item 35): the pane runs `cat`, no model, and reports only working and idle.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; WF="$(cd "$HERE/.." && pwd)"
HERDR="${HERDR_BIN:-herdr}"; SEAT=uat-idle
qline=uat; gline="$(jq -r .line "${A2A_CONFIG:-$HERE/config.json}")"
while [ $# -gt 0 ]; do
  case $1 in --line) qline=$2; shift 2 ;; --grid-line) gline=$2; shift 2 ;; *) echo "A2A-USAGE uat.sh [--line L] [--grid-line G]" >&2; exit 2 ;; esac
done
T=$(mktemp -d); export A2A_STATE_DIR="$T/state"
pane=""
cleanup() { echo exit > "$T/ctl" 2>/dev/null; sleep 1.5; [ -n "$pane" ] && FORCE=1 bash "$WF/bin/herdr-grid.sh" seat-down "$SEAT" "$gline" >/dev/null 2>&1; rm -rf "$T"; }
trap cleanup EXIT
st() { "$HERDR" agent get "$SEAT" 2>/dev/null | jq -r '.result.agent.agent_status // "none"'; }
st_pane() { "$HERDR" pane get "$pane" 2>/dev/null | jq -r '.result.pane.agent_status // "none"'; }
fail=0; log=()
say() { printf '%s\n' "$*"; log+=("$*"); }
check() { if [ "$1" = "$2" ]; then say "ok  $3"; else say "FAIL $3 (want '$1', got '$2')"; fail=1; fi; }

pane=$(bash "$WF/bin/herdr-grid.sh" claim "$gline" "$SEAT" 2>/dev/null | grep -oE 'w[A-Za-z0-9]+:p[A-Za-z0-9]+' | tail -1)
[ -n "$pane" ] || { echo "A2A-IO could not claim a pane on line $gline" >&2; exit 4; }
# The test seat is tests/uat-seat.sh run as a binary named claude: herdr only types into a pane whose foreground process
# is the agent it detected (agent_not_ready otherwise, seen 2026-10-16T05:26Z), and the seat reports its own state.
mkdir -p "$T/bin"; cp "$HERE/tests/uat-seat.sh" "$T/bin/claude"; echo working > "$T/ctl"; : > "$T/received.txt"
"$HERDR" pane run "$pane" "$T/bin/claude $T/ctl $T/received.txt" >/dev/null || exit 4
for _ in $(seq 1 20); do [ "$(st_pane)" = working ] && break; sleep 0.5; done
"$HERDR" agent rename "$pane" "$SEAT" >/dev/null || exit 4
jq --arg at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '.at=$at | .to.name="uat-idle" | .actions=["uat: read this file"]' \
  "$WF/templates/a2a/brief.json" > "$T/order.json"

say "before: herdr $SEAT pane=$pane agent_status=$(st)"
o1=$(bash "$HERE/a2a-send.sh" --to "$SEAT" --line "$qline" --file "$T/order.json" 2>&1)
o2=$(bash "$HERE/a2a-send.sh" --to "$SEAT" --line "$qline" --file "$T/order.json" 2>&1)
say "$o1"; say "$o2"
check 2 "$(printf '%s\n%s\n' "$o1" "$o2" | grep -c "^A2A-HELD $SEAT status=working")" "working seat: both sends held"
check 2 "$(find "$T/state/queue/$qline/$SEAT" -maxdepth 1 -name '*.ptr' | wc -l)" "working seat: both queued"
sleep 2; check 0 "$(wc -l < "$T/received.txt")" "working seat: nothing typed into the pane"

echo idle > "$T/ctl"; for _ in $(seq 1 20); do [ "$(st)" = idle ] && break; sleep 0.5; done
say "after:  herdr $SEAT pane=$pane agent_status=$(st)"
o3=$(bash "$HERE/a2a-deliver.sh" --line "$qline" --seat "$SEAT" 2>&1); say "$o3"
sleep 2
check 1 "$(wc -l < "$T/received.txt")" "idle seat: exactly one line delivered"
check 2 "$(grep -o '/a2a/[0-9/]*[0-9-]*uat-idle-[0-9a-f]*\.json' "$T/received.txt" | sort -u | wc -l)" "the one line carries both store pointers"
say "received: $(cat "$T/received.txt")"
bash "$HERE/a2a-deliver.sh" --line "$qline" --seat "$SEAT" >/dev/null 2>&1; sleep 1
check 1 "$(wc -l < "$T/received.txt")" "a second pass types nothing more"

ev=$(bash "$WF/../tools/artifact/artifact.sh" new --key log --name a2a-guard-uat --ext log --what "a2a-guard UAT gate output" 2>/dev/null) \
  && printf '%s\n' "${log[@]}" >> "$ev" && say "evidence: $ev"
if [ $fail = 0 ]; then say "ok  a2a-guard UAT gate (AC1)"; else say "FAIL a2a-guard UAT gate"; exit 1; fi
