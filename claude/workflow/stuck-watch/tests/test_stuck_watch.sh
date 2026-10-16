#!/usr/bin/env bash
# shellcheck disable=SC2015,SC2016 # ok/no never fail (A && ok || no is safe); stub bodies are single-quoted on purpose
# test_stuck_watch.sh - the dev gate (item 34): stuck-watch.sh, deadman.sh and stuck-audit.sh against stub herdr, gh, bus
# and ntfy. Runs in the podman test image with --network=none; nothing reaches ntfy.sh or the owner (item 35).
# CASE=<name> runs one case (the work orders' test plans name them); unset runs all.
# Every case says why it exists: a stuck seat the owner never hears about is the failure this whole tool removes.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; SW="$HERE/.."
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
PASS=0; FAIL=0
ok() { PASS=$((PASS + 1)); echo "ok   $1"; }
no() { FAIL=$((FAIL + 1)); echo "FAIL $1"; [ -z "${2:-}" ] || printf "     %s\n" "$2"; return 0; }
CANARY="canary-topic-$$-do-not-print"

setup() { # fresh stubs per case
  rm -rf "$T/c"; mkdir -p "$T/c/bin" "$T/c/run" "$T/c/proj/x" "$T/c/state" "$T/c/art"; C="$T/c"
  printf 'YPC_NTFY_TOPIC=owner-%s  # owner phone, note\nYPC_NTFY_TEST_TOPIC=%s  # test topic, note\n' "$CANARY" "$CANARY" > "$C/env"; chmod 600 "$C/env"
  cat > "$C/bin/herdr" <<'EOF'
#!/usr/bin/env bash
case "$1 $2" in
  "agent list") cat "$STUB/agents.json" ;;
  "tab list") echo '{"result":{"tabs":[{"tab_id":"w:t1","label":"t 1"},{"tab_id":"w:t2","label":"other 1"}]}}' ;;
esac
EOF
  cat > "$C/bin/gh" <<'EOF'
#!/usr/bin/env bash
echo "gh $*" >> "$STUB/gh.calls"
case "$1 $2" in "pr view") cat "$STUB/pr.json" ;; "pr list") echo "" ;; esac
EOF
  cat > "$C/bin/pub" <<'EOF'
#!/usr/bin/env bash
printf '%s %s\n' "$1" "$2" >> "$STUB/bus.log"
EOF
  cat > "$C/bin/curl" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$STUB/curl.log"; printf '200'
EOF
  echo '{"seats":[]}' > "$C/res.json"
  chmod +x "$C/bin/"*
  export STUB="$C" HERDR_BIN="$C/bin/herdr" GH_BIN="$C/bin/gh" SW_PUB_CMD="$C/bin/pub" SW_CURL_BIN="$C/bin/curl" \
    SW_STATE_DIR="$C/state" SW_RUN_DIR="$C/run" ENV_FILE="$C/env" NTFY_TOPIC_VAR=YPC_NTFY_TEST_TOPIC \
    WF_PROJECTS_DIR="$C/proj" ARTIFACT_ROOT="$C/art" SW_RESOURCES_CMD="cat $C/res.json"
  : > "$C/bus.log"; : > "$C/curl.log"
}
agent() { # agent <name> <pane> <session> [tab]
  jq -nc --arg n "$1" --arg p "$2" --arg s "$3" --arg t "${4:-w:t1}" '{result:{agents:[{agent:"claude",name:$n,pane_id:$p,tab_id:$t,agent_session:{value:$s}}]}}' > "$C/agents.json"
}
transcript_aged() { # transcript_aged <session> <seconds-ago>
  printf '{"message":{"usage":{"input_tokens":1000}}}\n' > "$C/proj/x/$1.jsonl"; touch -d "@$(( $(date -u +%s) - $2 ))" "$C/proj/x/$1.jsonl"
}
tick() { bash "$SW/stuck-watch.sh" --line t --once > "$C/out" 2> "$C/err"; }

case_idle() {
  setup; agent idle-seat w:p1 s1; transcript_aged s1 300; tick
  grep -q '^line.t.stuck.STK-001 ' "$C/bus.log" && ok "idle: STK-001 on line.t.stuck.STK-001 (AC1)" || no "idle: STK-001 on bus" "$(cat "$C/bus.log" "$C/err")"
  [ "$(wc -l < "$C/curl.log")" = 1 ] && ok "idle: one ntfy POST (AC1)" || no "idle: one ntfy POST" "$(cat "$C/curl.log")"
  grep -q '"evidence_path":"/' "$C/bus.log" && ok "idle: bus event points at an evidence file" || no "idle: evidence path" "$(cat "$C/bus.log")"
  grep -q '^line.t.heartbeat ' "$C/bus.log" && ok "idle: heartbeat published" || no "idle: heartbeat"
  # a busy seat (fresh transcript) is not coded: a false page trains the owner to ignore the phone
  setup; agent busy-seat w:p1 s2; transcript_aged s2 5; tick
  grep -q '^line.t.stuck.' "$C/bus.log" && no "busy: fresh transcript coded" "$(cat "$C/bus.log")" || ok "busy: fresh transcript not coded"
  # a seat in another line's tab is not this watcher's business
  setup; agent other-seat w:p1 s3 w:t2; transcript_aged s3 300; tick
  grep -q '^line.t.stuck.' "$C/bus.log" && no "scope: other line coded" || ok "scope: other line's seat ignored"
  # a seat with a result file is not idle-stuck: it finished
  setup; agent done-seat w:p1 s4; transcript_aged s4 300; echo '{"status":"blocked","status_code":"A2A-003"}' > "$C/run/done-seat-result.json"; tick
  grep -q 'STK-001' "$C/bus.log" && no "result: finished seat coded idle" || ok "result: seat with a result file not coded STK-001"
}

case_done_unmerged() {
  setup; agent claim-seat w:p1 s1; transcript_aged s1 300
  echo '{"status":"done","status_code":"A2A-002","facts":{"pr":"https://github.com/o/r/pull/7"}}' > "$C/run/claim-seat-result.json"
  echo '{"state":"OPEN","statusCheckRollup":[{"name":"ci","conclusion":"SUCCESS"}]}' > "$C/pr.json"; tick
  grep -q '^line.t.stuck.STK-005 .*"state":"OPEN"' "$C/bus.log" && ok "done-unmerged: STK-005 with gh state OPEN as evidence (AC3)" || no "done-unmerged: STK-005" "$(cat "$C/bus.log" "$C/err")"
  grep -q 'Priority: high' "$C/curl.log" && ok "done-unmerged: paged at priority high" || no "done-unmerged: priority" "$(cat "$C/curl.log")"
  setup; agent claim-seat w:p1 s1; transcript_aged s1 300
  echo '{"status":"done","facts":{"pr":"https://github.com/o/r/pull/7"}}' > "$C/run/claim-seat-result.json"
  echo '{"state":"MERGED","statusCheckRollup":[{"name":"ci","conclusion":"FAILURE"}]}' > "$C/pr.json"; tick
  grep -q 'STK-005.*FAILURE' "$C/bus.log" && ok "done-red: merged but CI red is STK-005" || no "done-red: STK-005" "$(cat "$C/bus.log")"
  setup; agent claim-seat w:p1 s1; transcript_aged s1 300
  echo '{"status":"done","facts":{"pr":"https://github.com/o/r/pull/7"}}' > "$C/run/claim-seat-result.json"
  echo '{"state":"MERGED","statusCheckRollup":[{"name":"ci","conclusion":"SUCCESS"}]}' > "$C/pr.json"; tick; tick
  grep -q 'STK-005' "$C/bus.log" && no "done-green: true claim coded" || ok "done-green: merged and green is not coded"
  [ "$(grep -c 'pr view' "$C/gh.calls")" = 1 ] && ok "done-green: a merged green PR is asked of gh once, then cached" || no "done-green: cache" "$(cat "$C/gh.calls")"
}

case_dedupe() {
  setup; agent idle-seat w:p1 s1; transcript_aged s1 300; tick; tick
  [ "$(grep -c '^line.t.stuck.STK-001 ' "$C/bus.log")" = 2 ] && ok "dedupe: both ticks on the bus (audit sees duration)" || no "dedupe: bus count" "$(cat "$C/bus.log")"
  [ "$(wc -l < "$C/curl.log")" = 1 ] && ok "dedupe: same condition twice, one notification (AC4)" || no "dedupe: one notification" "$(cat "$C/curl.log")"
  # a failed POST is not stamped, so the next tick retries instead of losing the page
  setup; agent idle-seat w:p1 s1; transcript_aged s1 300
  printf '#!/usr/bin/env bash\nprintf "%%s\\n" "$*" >> "$STUB/curl.log"; printf 500\n' > "$C/bin/curl"; tick; tick
  [ "$(wc -l < "$C/curl.log")" = 2 ] && ok "dedupe: a failed POST is retried next tick" || no "dedupe: retry after 500" "$(cat "$C/curl.log")"
}

case_no_leak() {
  setup; agent idle-seat w:p1 s1; transcript_aged s1 300; tick
  if grep -rq "$CANARY" "$C/out" "$C/err" "$C/bus.log" "$C/state" "$C/art"; then no "no-leak: topic printed" "$(grep -rl "$CANARY" "$C/out" "$C/err" "$C/bus.log" "$C/state" "$C/art")"
  else ok "no-leak: topic absent from stdout, stderr, bus, state and evidence"; fi
  grep -q "/$CANARY$" "$C/curl.log" && ok "no-leak: the test topic was the one POSTed (item 35)" || no "no-leak: test topic used" "$(sed "s/$CANARY/<topic>/" "$C/curl.log")"
  grep -q "owner-$CANARY" "$C/curl.log" && no "no-leak: owner topic used in a test (AC6)" || ok "no-leak: owner topic never POSTed by a test (AC6)"
}

js_stub() { # js_stub <mode: hb-age-seconds | none | down | audit>
  cat > "$C/bin/js" <<'EOF2'
#!/usr/bin/env bash
mode="$(cat "$STUB/js.mode")"
case "$mode" in
  down) exit 2 ;;
  none) echo '{"error":{"code":404}}' ;;
  audit) q="$(jq -r .seq <<<"$1")"; f="$STUB/stream.$q"; while [ ! -f "$f" ] && [ "$q" -le 20 ]; do q=$((q+1)); f="$STUB/stream.$q"; done
         if [ -f "$f" ]; then jq -nc --argjson q "$q" --arg d "$(base64 -w0 < "$f")" '{message:{seq:$q,data:$d}}'; else echo '{"error":{"code":404}}'; fi ;;
  *) jq -nc --arg t "$(date -u -d "@$(( $(date -u +%s) - mode ))" +%Y-%m-%dT%H:%M:%SZ)" '{message:{subject:"line.t.heartbeat",seq:9,time:$t}}' ;;
esac
EOF2
  chmod +x "$C/bin/js"; echo "$1" > "$C/js.mode"; export SW_JS_GET_CMD="$C/bin/js" SW_DEADMAN_LOG="$C/deadman.log"
}
deadman() { bash "$SW/deadman.sh" --lines t > "$C/out" 2> "$C/err"; }

case_deadman_stale() {
  setup; js_stub 240; deadman
  grep -q 'Title: stuck-watch dead' "$C/curl.log" && grep -q 'Priority: high' "$C/curl.log" && ok "deadman-stale: 4 min old heartbeat pages 'stuck-watch dead' high (AC2)" || no "deadman-stale: page" "$(cat "$C/curl.log" "$C/err")"
  grep -q 'STK-090 line=t ntfy=200' "$C/deadman.log" && ok "deadman-stale: logged with ntfy 200" || no "deadman-stale: log" "$(cat "$C/deadman.log")"
  deadman; [ "$(wc -l < "$C/curl.log")" = 1 ] && ok "deadman-stale: second pass inside 30 min does not page again" || no "deadman-stale: dedupe" "$(cat "$C/curl.log")"
  setup; js_stub none; deadman
  grep -q 'stuck-watch dead' "$C/curl.log" && ok "deadman-never: no heartbeat at all pages" || no "deadman-never: page"
}
case_deadman_bus_down() {
  setup; js_stub down; deadman
  grep -q 'Title: bus down' "$C/curl.log" && grep -q 'Priority: high' "$C/curl.log" && ok "deadman-bus-down: unreachable bus pages high" || no "deadman-bus-down: page" "$(cat "$C/curl.log" "$C/err")"
}
case_deadman_fresh() {
  setup; js_stub 30; deadman
  [ ! -s "$C/curl.log" ] && ok "deadman-fresh: fresh heartbeat stays silent" || no "deadman-fresh: paged" "$(cat "$C/curl.log")"
}
case_audit() {
  setup; js_stub audit
  e() { jq -nc --arg s "$1" --arg c "$2" --arg a "$3" --arg p "$4" '{schema:"stuck-watch/event/1",seat:$s,code:$c,at:$a,evidence_path:(if $p=="" then null else $p end)}'; }
  e a STK-001 2026-10-16T01:00:00Z /e/a1.json > "$C/stream.1"; e a STK-001 2026-10-16T01:10:00Z "" > "$C/stream.3"
  e b STK-005 2026-10-16T02:00:00Z /e/b.json > "$C/stream.4"
  bash "$SW/stuck-audit.sh" --line t --json > "$C/out" 2> "$C/err"
  jq -e 'length==2 and .[0].seat=="a" and .[0].ticks==2 and .[0].duration_s==660 and .[0].evidence=="/e/a1.json" and .[1].code=="STK-005"' "$C/out" >/dev/null \
    && ok "audit: one row per seat+code with first, last, duration and evidence" || no "audit: rows" "$(cat "$C/out" "$C/err")"
  bash "$SW/stuck-audit.sh" --line t > "$C/out"; grep -q '^a .*STK-001.*11m' "$C/out" && ok "audit: table prints duration in minutes" || no "audit: table" "$(cat "$C/out")"
}
case_signals() {
  setup; agent cpu-seat w:p1 s1; transcript_aged s1 5; echo '{"seats":[{"pane":"w:p1","cpu_pct":0}]}' > "$C/res.json"
  for _ in 1 2 3 4; do tick; done; grep -q 'STK-003' "$C/bus.log" && no "signals: STK-003 before 5 samples" || ok "signals: CPU 0 for 4 ticks not coded"
  tick; grep -q '^line.t.stuck.STK-003 ' "$C/bus.log" && ok "signals: CPU 0 for 5 ticks is STK-003" || no "signals: STK-003" "$(cat "$C/bus.log")"
  setup; agent ctx-seat w:p1 s2; printf '{"message":{"usage":{"input_tokens":400000}}}\n' > "$C/proj/x/s2.jsonl"; tick
  grep -q '^line.t.stuck.STK-004 .*"context_pct":40' "$C/bus.log" && ok "signals: context 40% over 30% is STK-004" || no "signals: STK-004" "$(cat "$C/bus.log")"
  setup; agent sop-seat w:p1 s3; transcript_aged s3 5; echo '{"status":"blocked","status_code":"A2A-004"}' > "$C/run/sop-seat-result.json"; tick
  grep -q '^line.t.stuck.A2A-004 ' "$C/bus.log" && grep -q 'Priority: high' "$C/curl.log" && ok "signals: SOP breach A2A-004 paged high" || no "signals: A2A-004" "$(cat "$C/bus.log")"
}

CASES="${CASE:-idle done-unmerged dedupe no-leak signals deadman-stale deadman-bus-down deadman-fresh audit}"
for c in $CASES; do fn="case_${c//-/_}"; declare -F "$fn" >/dev/null && "$fn" || no "unknown case $c"; done
echo "pass=$PASS fail=$FAIL"
[ "$FAIL" = 0 ]
