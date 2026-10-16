#!/usr/bin/env bash
# shellcheck disable=SC2015,SC2016 # ok/no never fail (A && ok || no is safe); stub bodies are single-quoted on purpose
# test_timing.sh - the dev gate (item 34) for bin/timed-run.sh, timing/node-timing.sh and timing/line-timing.sh, against a
# name: test_timing.sh
# purpose: dev gate: timed-run, node-timing and line-timing against stubs
# inputs: CASE
# outputs: ok/FAIL lines and pass=N fail=N
# writes-to: a mktemp dir, removed on exit
# cleanup: automatic (trap)
# stub bus, stub nats CLI, stub KV dump and stub work-order. --network=none; nothing reaches the owner (item 35).
# CASE=<name> runs one case (the work orders' test plans name them); unset runs all.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; WF="$HERE/../.."
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
PASS=0; FAIL=0
ok() { PASS=$((PASS + 1)); echo "ok   $1"; }
no() { FAIL=$((FAIL + 1)); echo "FAIL $1"; [ -z "${2:-}" ] || printf '     %s\n' "$2"; return 0; }

setup() {
  rm -rf "$T/c"; mkdir -p "$T/c/bin" "$T/c/state" "$T/c/art"; C="$T/c"
  printf '#!/usr/bin/env bash\nprintf "%%s %%s\\n" "$1" "$2" >> "$STUB/bus.log"\n' > "$C/bin/pub"
  printf '#!/usr/bin/env bash\necho "wo $*" >> "$STUB/wo.log"; echo "{\\"id\\":\\"WO-TEST-$(wc -l < "$STUB/wo.log")\\"}"\n' > "$C/bin/wo"
  cat > "$C/bin/nats" <<'EOF'
#!/usr/bin/env bash
shift 2  # --server URL
case "$1 $2" in
  "consumer info") exit 0 ;;
  "consumer next") [ -s "$STUB/queue" ] && { head -1 "$STUB/queue"; sed -i 1d "$STUB/queue"; } ;;
esac
EOF
  chmod +x "$C/bin/"*
  : > "$C/bus.log"; : > "$C/wo.log"; : > "$C/queue"
  export STUB="$C" SW_PUB_CMD="$C/bin/pub" WO_BIN="$C/bin/wo" NATS_BIN="$C/bin/nats" SW_STATE_DIR="$C/state" ARTIFACT_ROOT="$C/art" \
    TM_WO_PROJECT="$C/wo-project" TM_TEST_ONCE=1
}
# the wo stub stands in for work-order.sh; tm_wo still git-inits the project, so give it a repo it can init
gitcfg() { :; }  # tm_wo inits git only when git exists; the test image has none

case_timeout() {
  setup; gitcfg
  bash "$WF/bin/timed-run.sh" --node hang --line t --timeout 1 --budget 1 -- sleep 5 > "$C/out" 2> "$C/err"; rc=$?
  [ "$rc" = 124 ] && ok "timeout: exit 124 after the last attempt" || no "timeout: exit code $rc" "$(cat "$C/err")"
  [ "$(grep -c '^line.t.event.node.timeout ' "$C/bus.log")" = 3 ] && ok "timeout: stopped and retried 3 times (AC9)" || no "timeout: attempts" "$(cat "$C/bus.log")"
  grep -q '^line.t.timing.TIMEOUT .*"node":"hang"' "$C/bus.log" && ok "timeout: TIMEOUT coded on the bus (AC9)" || no "timeout: TIMEOUT code"
  [ "$(grep -c 'Bottleneck: hang TIMEOUT' "$C/wo.log")" = 1 ] && ok "timeout: one bottleneck work order filed (AC9)" || no "timeout: work order" "$(cat "$C/wo.log")"
  bash "$WF/bin/timed-run.sh" --node hang --line t --timeout 1 --retries 1 -- sleep 5 >/dev/null 2>&1
  [ "$(grep -c 'Bottleneck: hang TIMEOUT' "$C/wo.log")" = 1 ] && ok "timeout: same node again the same day files no second work order" || no "timeout: wo dedupe" "$(cat "$C/wo.log")"
}

case_start_end() {
  setup
  bash "$WF/bin/timed-run.sh" --node quick --kind make --line t -- bash -c 'exit 3' > "$C/out" 2> "$C/err"; rc=$?
  [ "$rc" = 3 ] && ok "start-end: the command's exit code is passed through" || no "start-end: rc $rc"
  grep -q '^line.t.event.node.start .*"budget_s":120' "$C/bus.log" && ok "start-end: start with the make budget from time-budgets.json" || no "start-end: start" "$(cat "$C/bus.log")"
  grep -q '^line.t.event.node.end .*"rc":3,"duration_s":0' "$C/bus.log" && ok "start-end: end with rc and duration_s (item 37)" || no "start-end: end" "$(cat "$C/bus.log")"
}

ev() { jq -nc --arg p "$1" --arg r "$2" --arg at "$3" --argjson x "${4:-{\}}" '{schema:"timing/event/1",line:"t",node:"build",kind:"make",run_id:$r,phase:$p,at:$at} + $x'; }
nt() { bash "$WF/timing/node-timing.sh" > "$C/out" 2> "$C/err"; }

case_slow() {
  setup; gitcfg
  ev start r1 2026-10-16T01:00:00Z > "$C/queue"; nt
  ev end r1 2026-10-16T01:05:00Z '{"duration_s":300,"budget_s":120}' > "$C/queue"; nt
  grep -q '^\$KV.TIMING.t.make.build.r1 .*"duration_s":300' "$C/bus.log" && ok "slow: duration written to KV TIMING" || no "slow: KV" "$(cat "$C/bus.log" "$C/err")"
  grep -q '^line.t.timing.SLOW .*"budget_s":120' "$C/bus.log" && ok "slow: SLOW on the bus with budget and duration (AC7)" || no "slow: SLOW" "$(cat "$C/bus.log")"
  [ "$(grep -c 'Bottleneck: build SLOW' "$C/wo.log")" = 1 ] && ok "slow: one bottleneck work order (AC7)" || no "slow: work order" "$(cat "$C/wo.log")"
  # a herdr seat that worked past the seat budget is SLOW too, without any wrapper
  setup; gitcfg
  jq -nc '{schema:"herdr-bus/event/1",at:"2026-10-16T01:00:00Z",tab_label:"t 1",pane:"w:p1",name:"seat-a",status:"working",prev:"idle"}' > "$C/queue"; nt
  jq -nc '{schema:"herdr-bus/event/1",at:"2026-10-16T02:00:00Z",tab_label:"t 1",pane:"w:p1",name:"seat-a",status:"idle",prev:"working"}' > "$C/queue"; nt
  grep -q '^line.t.timing.SLOW .*"node":"seat-a".*"duration_s":3600' "$C/bus.log" && ok "slow: a seat working 60 min over its 45 min budget is SLOW" || no "slow: seat" "$(cat "$C/bus.log" "$C/err")"
}

case_fast() {
  setup
  ev start r2 2026-10-16T01:00:00Z > "$C/queue"; nt
  ev end r2 2026-10-16T01:01:00Z '{"duration_s":60,"budget_s":120}' > "$C/queue"; nt
  grep -q '^\$KV.TIMING.t.make.build.r2 .*"slow":false' "$C/bus.log" && ok "fast: KV written, slow false" || no "fast: KV" "$(cat "$C/bus.log")"
  grep -q 'SLOW' "$C/bus.log" "$C/wo.log" && no "fast: SLOW or work order for a fast node" || ok "fast: no SLOW, no work order"
}

case_report() {
  setup
  printf '#!/usr/bin/env bash\nq="$(jq -r .seq <<<"$1")"; while [ ! -f "$STUB/kv.$q" ] && [ "$q" -le 20 ]; do q=$((q+1)); done\n[ -f "$STUB/kv.$q" ] && jq -nc --argjson q "$q" --arg d "$(base64 -w0 < "$STUB/kv.$q")" "{message:{seq:\\$q,data:\\$d}}" || echo "{\\"error\\":{\\"code\\":404}}"\n' > "$C/bin/js"; chmod +x "$C/bin/js"
  export SW_JS_GET_CMD="$C/bin/js"; i=1
  for row in "a make 300 120" "a make 100 120" "b ci 900 600" "c seat 100 2700" "d make 130 120" "e make 500 120" "f gate 700 600"; do
    read -r n k d b <<<"$row"; set -- "$n" "$k" "$d" "$b"; jq -nc --arg n "$1" --arg k "$2" --argjson d "$3" --argjson b "$4" '{line:"t",node:$n,kind:$k,duration_s:$d,budget_s:$b,slow:($d>$b),end:"2026-10-16T03:00:00Z"}' > "$C/kv.$i"; i=$((i+1)); done
  bash "$WF/timing/line-timing.sh" --line t > "$C/out" 2> "$C/err"
  f="$(sed -n 's/^report: //p' "$C/out")"
  [ -f "$f" ] && ok "report: written to the artifact store (AC8)" || no "report: artifact" "$(cat "$C/out" "$C/err")"
  top="$(sed -n '/## Top 5/,/## Durations/p' "$C/out" | grep '^| [a-z] ' | cut -d'|' -f2 | tr -d ' ' | tr '\n' ' ')"
  [ "$top" = "e b a f d " ] && ok "report: top 5 bottlenecks sorted by overrun (AC8)" || no "report: top 5 order" "$top"
  grep -q '^| a | make | 2 | 200 | 300 | 120 | 1 |' "$C/out" && ok "report: durations against budgets per node" || no "report: durations" "$(cat "$C/out")"
}

# ci-events: a stub gh returns fixture JSON; the stub bus records what is published; TM_CI_STATE keeps state inside the temp dir
case_ci_events() {
  setup
  printf '#!/usr/bin/env bash\ncat "$STUB/runs.json"\n' > "$C/bin/gh"; chmod +x "$C/bin/gh"
  export GH_BIN="$C/bin/gh" TM_CI_STATE="$C/state/ci-events.json" CI_EVENTS_RETRY_SLEEP=0
  run='{"databaseId":77,"name":"ci","status":"%s","conclusion":%s,"createdAt":"2026-10-16T01:00:00Z","updatedAt":"2026-10-16T01:%s:00Z","headBranch":"feat/x"}'
  # shellcheck disable=SC2059 # run is a printf template
  printf "[$run]" queued null 00 > "$C/runs.json"
  bash "$WF/timing/ci-events.sh" --once >/dev/null 2>"$C/err"
  [ "$(grep -c '^line.all.event.node.start .*"node":"ci-dotfiles-77".*"workflow":"ci"' "$C/bus.log")" = 1 ] && ok "a new run publishes ci start once" || no "ci start" "$(cat "$C/bus.log" "$C/err")"
  # shellcheck disable=SC2059
  printf "[$run]" completed '"success"' 07 > "$C/runs.json"
  bash "$WF/timing/ci-events.sh" --once >/dev/null 2>>"$C/err"
  [ "$(grep -c '^line.all.event.node.end .*"rc":0,"duration_s":420,"budget_s":600' "$C/bus.log")" = 1 ] && ok "a completed run publishes ci end with duration_s once" || no "ci end" "$(cat "$C/bus.log" "$C/err")"
  [ "$(grep -c '.event.node.start ' "$C/bus.log")" = 1 ] && ok "the start is not published again by the end poll" || no "ci start repeated" "$(cat "$C/bus.log")"
  before="$(wc -l < "$C/bus.log")"
  bash "$WF/timing/ci-events.sh" --once >/dev/null 2>>"$C/err"
  [ "$(wc -l < "$C/bus.log")" = "$before" ] && ok "ci-events is idempotent" || no "ci-events second poll published" "$(cat "$C/bus.log")"
  unset GH_BIN TM_CI_STATE CI_EVENTS_RETRY_SLEEP
}

CASES="${CASE:-timeout start-end slow fast report ci-events}"
for c in $CASES; do fn="case_${c//-/_}"; if declare -F "$fn" >/dev/null; then "$fn"; else no "unknown case $c"; fi; done
echo "pass=$PASS fail=$FAIL"
[ "$FAIL" = 0 ]
