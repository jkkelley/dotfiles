#!/usr/bin/env bash
# shellcheck disable=SC2015,SC2016 # ok/no never fail; stub bodies are single-quoted on purpose
# test_pane_look.sh - pane-look.sh against fixture panes, a stub herdr and a stub bus
# name: test_pane_look.sh
# purpose: dev gate for pane-look: working from the spinner timer, QUEUED-STALE, IDLE-STALE, finished seat
# inputs: CASE (working|queued|idle|done|agent_status), fixtures/pane-*.txt
# outputs: ok/FAIL lines and pass=N fail=N
# writes-to: a mktemp dir, removed on exit
# cleanup: automatic (trap)
# Time is PL_NOW, so 300s costs nothing. Nothing reaches the bus, ntfy or the owner (item 35).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; SW="$HERE/.."; FX="$HERE/fixtures"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
PASS=0; FAIL=0
ok() { PASS=$((PASS + 1)); echo "ok  $1"; }
no() { FAIL=$((FAIL + 1)); echo "FAIL $1"; [ -z "${2:-}" ] || printf "     %s\n" "$2"; return 0; }
T0=1792000000

setup() {
  rm -rf "$T/c"; mkdir -p "$T/c/bin" "$T/c/res" "$T/c/state" "$T/c/art"; C="$T/c"
  cat > "$C/bin/herdr" <<'STUB'
#!/usr/bin/env bash
case "$1 $2" in
  "agent list") echo '{"result":{"agents":[{"name":"seat-a","pane_id":"w1:p1","agent_status":"idle","workspace_id":"w1"},{"name":null,"pane_id":"w1:p9","workspace_id":"w1"}]}}' ;;
  "pane read") cat "$STUB/pane.txt" ;;
esac
STUB
  printf '#!/usr/bin/env bash\nprintf "%%s %%s\\n" "$1" "$2" >> "$STUB/bus.log"\n' > "$C/bin/pub"
  chmod +x "$C/bin/"*; : > "$C/bus.log"
  export STUB="$C" HERDR_BIN="$C/bin/herdr" SW_PUB_CMD="$C/bin/pub" SW_STATE_DIR="$C/state" LW_RESULTS="$C/res" ARTIFACT_ROOT="$C/art"
}
tick() { PL_NOW=$(( T0 + $1 )) bash "$SW/pane-look.sh" --line t --ws w1 --once >> "$C/out" 2>&1; }
pane() { cp "$FX/$1" "$C/pane.txt"; }
moving() { # moving <seconds>: the fixture spinner with a timer that has advanced
  sed -E "s/\(50m 47s/(50m $(( 47 + $1 ))s/" "$FX/pane-working.txt" > "$C/pane.txt"; }
has() { grep -q "stuck.$1" "$C/bus.log"; }

case_working() {
  setup; : > "$C/out"; moving 0; tick 0; moving 60; tick 60; moving 120; tick 120
  if ! has IDLE-STALE && ! has QUEUED-STALE; then ok "working judged from a moving spinner timer while agent_status says idle"
  else no "working" "$(cat "$C/bus.log")"; fi
}
case_queued() {
  setup; : > "$C/out"; pane pane-queued.txt; tick 0; tick 299
  if has QUEUED-STALE; then no "queued fired before 300s"; return; fi
  tick 300
  if has QUEUED-STALE; then ok "QUEUED-STALE after 300s of unchanged queued input"; else no "queued" "$(cat "$C/out")"; fi
  tick 360; [ "$(grep -c QUEUED-STALE "$C/bus.log")" = 1 ] && ok "QUEUED-STALE once per episode" || no "queued repeated"
  if grep -q 'by: pane-look' "$(sed 's/^[^ ]* //' "$C/bus.log" | jq -r .evidence | head -1)"; then ok "evidence is the snapshot path"; else no "evidence"; fi
}
case_idle() {
  setup; : > "$C/out"; pane pane-idle.txt; tick 0
  if has IDLE-STALE; then no "idle fired at once"; return; fi
  tick 60
  if has IDLE-STALE; then ok "IDLE-STALE after 60s idle with no result file"; else no "idle" "$(cat "$C/out")"; fi
}
case_done() {
  setup; : > "$C/out"; echo '{"status":"done"}' > "$C/res/seat-a-result.json"; pane pane-idle.txt; tick 0; tick 60; tick 600
  if ! has IDLE-STALE; then ok "no IDLE-STALE when the result file exists"; else no "done" "$(cat "$C/bus.log")"; fi
}
case_agent_status() {
  setup; : > "$C/out"; moving 0; tick 0; moving 90; tick 90
  # herdr stub says agent_status idle throughout; a moving spinner is working
  if ! has IDLE-STALE; then ok "agent_status idle with a moving spinner is working"; else no "agent_status decided"; fi
}

for c in working queued idle "done" agent_status; do
  if [ -z "${CASE:-}" ] || [ "$CASE" = "$c" ]; then "case_$c"; fi
done
echo "pass=$PASS fail=$FAIL"; [ "$FAIL" = 0 ]
