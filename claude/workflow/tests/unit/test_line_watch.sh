#!/usr/bin/env bash
# Proves the line's monitoring tab, sweep, bus and consumers (bin/monitors.sh, bin/line-watch.sh, bin/bus.sh) against a
# stub herdr, a stub nats CLI (an in-file JetStream: messages, per-consumer deliveries and acks) and a stub
# compaction-guard.
#
# Each check names the failure it rules out:
#   - any pane prompt from line-watch (architect redesign 2026-10-16T04:31Z: events go on the bus, never into a pane)
#   - a quiet tick that publishes anything (tokens burnt downstream on nothing)
#   - a done line already on screen when the seat was first seen raising an event (li-page, 2026-10-16T04:30Z)
#   - a brief quoting "DONE <seat> <pr-url>" being read as the seat being done
#   - a done event not consumed, not acked, acked twice, or acked before the seat was downed
#   - a redelivered done (consumer died before its ack) downing a seat twice
#   - a done whose result fails result-check downing the seat instead of going to the orchestrator
#   - an idle seat over the limit raising no ALERT, or one per tick instead of one
#   - monitors-up placing a monitor anywhere but its declared slot, or monitors-down leaving the tab or skipping a down
# Hermetic: every external command is a stub on PATH. Fixtures in $T/fx, bus state in $T/bus.
# shellcheck disable=SC2015,SC2016
set -uo pipefail
R="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
fail=0
ok()  { printf 'ok  %s\n' "$1"; }
bad() { fail=1; printf 'FAIL %s\n' "$1"; [ $# -gt 1 ] && printf '     %s\n' "${@:2}"; }
pubs() { grep -c "^pub line\.L\.event\.${1:-}" "$T/buslog" 2>/dev/null || true; }

mkdir -p "$T/bin" "$T/fx" "$T/projects/p" "$T/bus" "$T/results"
cat > "$T/bin/herdr" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$T/log"
fx="$T/fx"; n=$(cat "$fx/next" 2>/dev/null || echo 100)
case "$1 $2" in
  "tab list") cat "$fx/tabs.json" ;;
  "pane list") cat "$fx/panes.json" ;;
  "pane layout") cat "$fx/layout.json" ;;
  "pane read") cat "$fx/read-${3//:/_}.txt" 2>/dev/null ;;
  "agent get") s="sid-${3//:/_}"; echo "{\"result\":{\"agent\":{\"agent_session\":{\"value\":\"$s\"}}}}" ;;
  "pane split") echo $((n+1)) > "$fx/next"; echo "{\"result\":{\"pane\":{\"pane_id\":\"wT:p$n\"}}}" ;;
  "tab create") echo $((n+2)) > "$fx/next"; echo "{\"result\":{\"tab\":{\"tab_id\":\"wT:t$n\"},\"root_pane\":{\"pane_id\":\"wT:p$((n+1))\"}}}" ;;
  *) echo '{"result":{"type":"ok"}}' ;;
esac
STUB
# The nats stub keeps a stream in $T/bus/msgs ("seq<TAB>subject<TAB>payload"), acks in $T/bus/acked/<consumer>/<seq>,
# and deliveries in $T/bus/tries/<consumer>/<seq>. Filters come from the real config, so routing is tested, not assumed.
cat > "$T/bin/nats" <<'STUB'
#!/usr/bin/env bash
[ "$1" = -s ] && shift 2
printf '%s\n' "$*" >> "$T/buslog"
B="$T/bus"; mkdir -p "$B/acked" "$B/tries"; touch "$B/msgs"
case "$1" in
  pub)
    if [[ "$2" == '$JS.ACK.'* ]]; then IFS=. read -r _ _ _ con _ seq _ <<<"$2"; mkdir -p "$B/acked/$con"; : > "$B/acked/$con/$seq"
    else printf '%s\t%s\t%s\n' "$(( $(wc -l < "$B/msgs") + 1 ))" "$2" "$3" >> "$B/msgs"; fi ;;
  consumer)
    [ "$2" = next ] || exit 0
    con="$4"; codes="$(jq -r --arg c "$con" '.consumers[$c].codes[]' "$LW_BUS")"
    while IFS=$'\t' read -r seq subj pay; do
      grep -qxF "${subj##*.}" <<<"$codes" || continue
      [ -f "$B/acked/$con/$seq" ] && continue
      mkdir -p "$B/tries/$con"; d=$(( $(cat "$B/tries/$con/$seq" 2>/dev/null || echo 0) + 1 )); echo "$d" > "$B/tries/$con/$seq"
      printf '[00:00:00] subj: %s / tries: %s / cons seq: %s / str seq: %s / pending: 0\n\n%s\n' "$subj" "$d" "$seq" "$seq" "$pay"
      exit 0
    done < "$B/msgs"
    echo "nats: error: no message received: nats: timeout" >&2; exit 1 ;;
esac
STUB
printf '#!/usr/bin/env bash\necho "{\\"pct\\":42}"\n' > "$T/bin/compaction-guard"
chmod +x "$T/bin/herdr" "$T/bin/nats" "$T/bin/compaction-guard"
export PATH="$T/bin:$PATH" T HERDR_ENV=1 WS=wT LW_STATE="$T/state" ARTIFACT_ROOT="$T/art" WF_PROJECTS_DIR="$T/projects" \
  LW_IDLE=60 WORKFLOW_CONFIG="$R/config/project.json" BUS_NATS=nats BUS_RETRY_SLEEP=0 LW_BUS="$R/config/line-watch.json" \
  LW_RESULTS="$T/results" GRID_STATE="$T/grid" GRID_RETRY_SLEEP=0
L="bash $R/bin/line-watch.sh"

# line L: tab "L 1" = architect | alpha, beta, gamma. "other 1" is another line and never watched.
echo '{"result":{"tabs":[{"tab_id":"wT:t1","label":"L 1"},{"tab_id":"wT:t9","label":"other 1"}]}}' > "$T/fx/tabs.json"
panes() { # panes <alpha-status> <beta-status> [no-alpha]
  jq -n --arg a "$1" --arg b "$2" --arg drop "${3:-}" '{result:{panes:([
    {pane_id:"wT:pA",tab_id:"wT:t1",label:"architect",agent:"claude",agent_status:"idle"},
    {pane_id:"wT:p1",tab_id:"wT:t1",label:"alpha",agent:"claude",agent_status:$a},
    {pane_id:"wT:p2",tab_id:"wT:t1",label:"beta",agent:"claude",agent_status:$b},
    {pane_id:"wT:p3",tab_id:"wT:t1",label:"gamma",agent:"claude",agent_status:"working"},
    {pane_id:"wT:p9",tab_id:"wT:t9",label:"stranger",agent:"claude",agent_status:"idle"}] | map(select($drop == "" or .label != "alpha")))}}' > "$T/fx/panes.json"
}
jq -n '{result:{layout:{panes:[{pane_id:"wT:pA",rect:{x:0,y:0}},{pane_id:"wT:p1",rect:{x:110,y:0}},
  {pane_id:"wT:p2",rect:{x:110,y:20}},{pane_id:"wT:p3",rect:{x:110,y:40}}]}}}' > "$T/fx/layout.json"
fresh() { touch "$T/projects/p/sid-wT_p1.jsonl" "$T/projects/p/sid-wT_p2.jsonl" "$T/projects/p/sid-wT_p3.jsonl"; }
stale() { touch -d "@$(( $(date +%s) - 120 ))" "$T/projects/p/sid-wT_$1.jsonl"; }
tick() { : > "$T/log"; : > "$T/buslog"; $L sweep L --once >/dev/null 2>&1; }
consume() { : > "$T/log"; : > "$T/buslog"; $L consume L --once >/dev/null 2>&1; }
LOG() { cat "$T/state/L/sweep.log" 2>/dev/null; }

# ---- first sight: gamma already shows a done line from before line-watch existed -> stale, no event
panes working working; fresh
echo "working on it" > "$T/fx/read-wT_p1.txt"; echo "working" > "$T/fx/read-wT_p2.txt"
printf '● DONE gamma BLOCKED\n' > "$T/fx/read-wT_p3.txt"
tick; tick
[ "$(pubs)" = 0 ] && ok "quiet ticks publish nothing" || bad "quiet ticks publish nothing" "$(cat "$T/buslog")"
! LOG | grep -q 'DONE gamma' && ok "a done line on screen before the seat was first seen raises no event" || bad "stale done" "$(LOG | grep gamma)"
grep -q 'stranger' <(LOG) && bad "another line's seat is not watched" || ok "another line's seat is not watched"
[ "$(LOG | grep -c 'seat: alpha')" = 1 ] && ok "a steady seat logs one line, not one per tick" || bad "one line on change" "$(LOG)"
readlink -f "$T/state/L/sweep.log" | grep -Eq "$T/art/log/[0-9]{4}/[0-9]{2}/[0-9]{8}-[0-9]{6}-line-watch-L\.log$" \
  && head -1 "$(readlink -f "$T/state/L/sweep.log")" | grep -qx -- '---' \
  && ok "log is <key>/YYYY/MM/YYYYMMDD-HHMMSS-<name> in the artifact store, with frontmatter" || bad "artifact log"

# ---- a quoted placeholder is not done
printf 'End with exactly: DONE alpha <pr-url>\n' > "$T/fx/read-wT_p1.txt"; tick
[ "$(pubs)" = 0 ] && ok "a quoted 'DONE alpha <pr-url>' does not count" || bad "placeholder is not done"

# ---- a new done line is published once, as one JSON event on line.<line>.event.LW-DONE
printf '● DONE alpha https://github.com/o/r/pull/7\n' > "$T/fx/read-wT_p1.txt"; tick
[ "$(pubs LW-DONE)" = 1 ] && ok "a new done token is published once" || bad "one publish" "$(cat "$T/buslog")"
msg="$(cut -f3 "$T/bus/msgs" | tail -1)"
jq -e '.status_code == "LW-DONE" and .facts.seat == "alpha" and .facts.context_pct == 42 and .to == "line-consume" and (.acceptance_criteria | length) >= 1' <<<"$msg" >/dev/null \
  && ok "the event is one JSON document with code, seat, context, consumer and AC" || bad "event shape" "$msg"
tick; [ "$(pubs)" = 0 ] && ok "the same done is never published twice" || bad "no repeat"

# ---- line-consume (no model) checks the result, downs the seat, then acks, exactly once
cp "$R/templates/a2a/result.json" "$T/results/alpha-result.json"
consume
grep -q '^pane close wT:p1' "$T/log" && ok "line-consume downs the seat through herdr-grid seat-down, no model" || bad "seat down" "$(cat "$T/log")"
[ -f "$T/bus/acked/line-consume/$(grep -c . "$T/bus/msgs")" ] && [ "$(grep -cF 'pub $JS.ACK' "$T/buslog")" = 1 ] \
  && ok "the event is acked exactly once" || bad "one ack" "$(cat "$T/buslog")"
consume; ! grep -q '^pane close' "$T/log" && ok "a consumed event is not consumed again" || bad "consumed twice"

# ---- the consumer died after downing the seat but before its ack: redelivery downs nothing twice
rm -f "$T/bus/acked/line-consume/"*; panes working working no-alpha; consume
! grep -q '^pane close' "$T/log" && ok "after a restart a redelivered done downs nothing twice" || bad "double down" "$(cat "$T/log")"
[ "$(sort -n "$T/bus/tries/line-consume/"* | tail -1)" = 2 ] && [ -n "$(ls "$T/bus/acked/line-consume")" ] \
  && ok "the redelivery (tries 2) is acked: nothing lost, nothing repeated" || bad "redelivery ack"

# ---- a done whose result fails result-check goes to the orchestrator, the seat stays up
panes working working; printf '● DONE beta https://github.com/o/r/pull/9\n' > "$T/fx/read-wT_p2.txt"; tick; consume
! grep -q '^pane close wT:p2' "$T/log" && ok "a failing result never downs the seat" || bad "failing result downed"
[ "$(pubs LW-AC-FAILED)" = 1 ] && ok "a failing result is published as LW-AC-FAILED" || bad "AC-FAILED" "$(cat "$T/buslog")"
out="$(ROLE=orchestrator $L queue L 2>/dev/null)"
jq -e 'select(.status_code == "LW-AC-FAILED" and .facts.seat == "beta")' <<<"$out" >/dev/null && ok "the orchestrator pulls it from its own consumer" || bad "orchestrator pull" "$out"
[ -z "$(ROLE=orchestrator $L queue L 2>/dev/null)" ] && ok "a pulled event is not pulled again" || bad "pull twice"
[ -z "$(ROLE=architect $L queue L 2>/dev/null)" ] && ok "the architect consumer only gets ruling events" || bad "architect got events"

# ---- an idle seat over 1 minute raises one ALERT
printf 'thinking\n' > "$T/fx/read-wT_p2.txt"; panes working idle; stale p2; tick
[ "$(LOG | grep -c 'ALERT beta .*LW-ALERT-IDLE')" = 1 ] && [ "$(pubs LW-ALERT-IDLE)" = 1 ] && ok "idle over 60s raises one ALERT, published once" || bad "idle ALERT" "$(LOG | tail -3)"
tick; [ "$(LOG | grep -c 'ALERT beta .*LW-ALERT-IDLE')" = 1 ] && [ "$(pubs)" = 0 ] && ok "a still-idle seat does not alert again" || bad "idle once"

# ---- blocked on a dialog
printf 'Bash command\nDo you want to proceed?\nEsc to cancel\n' > "$T/fx/read-wT_p2.txt"; panes working working; fresh; tick
LOG | grep -q 'ALERT beta .*LW-ALERT-BLOCKED' && ok "a seat on a permission dialog raises ALERT" || bad "blocked" "$(LOG | tail -2)"

# ---- monitors: one tab, each declared monitor in its slot; down runs every down and closes the tab
M="bash $R/bin/monitors.sh"
jq --arg d "$T/downs" '.monitors = [
  {name:"bus", slot:"1.1", interval:0, command:"make bus-up", down:("echo bus >> " + $d)},
  {name:"sweep", slot:"1.2", interval:0, command:"make line-sweep LINE=${line} WS=${ws}", down:("echo sweep >> " + $d)},
  {name:"cpu", slot:"3.3", interval:5, command:"top -bn1 | head -5"}]' "$R/config/monitors.json" > "$T/monitors.json"
export LW_MONITORS="$T/monitors.json"
echo '{"result":{"tabs":[{"tab_id":"wT:t1","label":"L 1"}]}}' > "$T/fx/tabs.json"; echo 300 > "$T/fx/next"; : > "$T/log"
$M grid "L monitor" >/dev/null 2>&1
[ "$(grep -c '^pane split' "$T/log")" = 8 ] && grep -q 'pane rename wT:p301 free 1.1' "$T/log" && grep -q 'free 3.3' "$T/log" \
  && ok "grid builds a 3x3 labelled by position" || bad "grid" "$(grep rename "$T/log")"
# the built tab, as herdr would list it
echo '{"result":{"tabs":[{"tab_id":"wT:t1","label":"L 1"},{"tab_id":"wT:t300","label":"L monitor"}]}}' > "$T/fx/tabs.json"
jq -n '{result:{panes:[range(0;9) as $i | {pane_id:"wT:m\($i)", tab_id:"wT:t300", label:"free \($i/3|floor+1).\($i%3+1)", agent:null}]}}' > "$T/fx/panes.json"
: > "$T/log"; $M up L >/dev/null 2>&1
grep -q '^pane rename wT:m0 L-bus$' "$T/log" && grep -q '^pane rename wT:m1 L-sweep$' "$T/log" && grep -q '^pane rename wT:m8 L-cpu$' "$T/log" \
  && ok "monitors-up puts each monitor in its declared slot, labelled with the line" || bad "slots" "$(grep rename "$T/log")"
grep -q '^pane run wT:m1 .*make line-sweep LINE=L WS=wT' "$T/log" && ok "commands get \${line} and \${ws}" || bad "subst" "$(grep 'pane run' "$T/log")"
grep -q '^pane run wT:m8 .*while :; do .*top -bn1.*sleep 5; done' "$T/log" && ok "an interval monitor is re-run every interval" || bad "interval"
! grep -q '^tab create' "$T/log" && ok "an existing monitor tab is reused, not rebuilt" || bad "tab rebuilt"
: > "$T/log"; $M down L >/dev/null 2>&1
grep -q '^tab close wT:t300' "$T/log" && ! grep -q '^tab close wT:t1' "$T/log" && ok "monitors-down closes the monitor tab and no other" || bad "down tab" "$(cat "$T/log")"
[ "$(sort "$T/downs" | tr '\n' ' ')" = "bus sweep " ] && ok "monitors-down runs every monitor's down" || bad "downs" "$(cat "$T/downs" 2>/dev/null)"

# ---- zero pane prompts, anywhere
! grep -q 'agent prompt' "$R/bin/line-watch.sh" "$R/bin/bus.sh" "$R/bin/monitors.sh" && ok "zero pane prompts in line-watch, bus and monitors" || bad "a pane prompt exists"
HERDR_ENV=0 $L sweep L >/dev/null 2>&1 && bad "sweep refuses outside herdr" || ok "sweep refuses outside herdr (Rule 18)"

[ "$fail" = 0 ] && echo "ok  line-watch: monitors tab, bus producer, stale done ignored, line-consume downs once and acks after, pull consumers, zero prompts"
exit "$fail"
