#!/usr/bin/env bash
# Proves bin/line-watch.sh watches a line the way the brief says, against a stub herdr and a stub compaction-guard.
#
# Each check names the failure it rules out:
#   - a seat printing its done token that does not wake the architect, or wakes it twice, or with prose instead of JSON
#   - a quiet tick that sends the architect anything (tokens burnt on nothing)
#   - a brief quoting "DONE <seat> <pr-url>" being read as the seat being done
#   - an idle seat over the limit raising no ALERT, or one ALERT per tick instead of one
#   - a seat stuck on a permission dialog going unnoticed
#   - `up` building anything but a labelled 3x3 "<line> monitor" tab with the sweep in a labelled pane
# Hermetic: herdr and compaction-guard are stubs on PATH. Fixtures in $T/fx.
# shellcheck disable=SC2015
set -uo pipefail
R="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
fail=0
ok()  { printf 'ok  %s\n' "$1"; }
bad() { fail=1; printf 'FAIL %s\n' "$1"; [ $# -gt 1 ] && printf '     %s\n' "${@:2}"; }
prompts() { grep -c '^agent prompt' "$T/log" 2>/dev/null || true; }

mkdir -p "$T/bin" "$T/fx" "$T/projects/p"
cat > "$T/bin/herdr" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$T/log"
fx="$T/fx"; n=$(cat "$fx/next" 2>/dev/null || echo 100)
case "$1 $2" in
  "tab list") cat "$fx/tabs.json" ;;
  "pane list") cat "$fx/panes.json" ;;
  "pane read") cat "$fx/read-${3//:/_}.txt" 2>/dev/null ;;
  "agent get") s="sid-${3//:/_}"; echo "{\"result\":{\"agent\":{\"agent_session\":{\"value\":\"$s\"}}}}" ;;
  "pane split") echo $((n+1)) > "$fx/next"; echo "{\"result\":{\"pane\":{\"pane_id\":\"wT:p$n\"}}}" ;;
  "tab create") echo $((n+2)) > "$fx/next"; echo "{\"result\":{\"tab\":{\"tab_id\":\"wT:t$n\"},\"root_pane\":{\"pane_id\":\"wT:p$((n+1))\"}}}" ;;
  *) echo '{"result":{"type":"ok"}}' ;;
esac
STUB
printf '#!/usr/bin/env bash\necho "{\\"pct\\":42}"\n' > "$T/bin/compaction-guard"
chmod +x "$T/bin/herdr" "$T/bin/compaction-guard"
export PATH="$T/bin:$PATH" T HERDR_ENV=1 WS=wT LW_STATE="$T/state" ARTIFACT_ROOT="$T/art" WF_PROJECTS_DIR="$T/projects" \
  LW_IDLE=60 WORKFLOW_CONFIG="$R/config/project.json"
L="bash $R/bin/line-watch.sh"

# line L: tab "L 1" holds the architect, alpha (working), beta (idle). "other 1" is another line and never watched.
echo '{"result":{"tabs":[{"tab_id":"wT:t1","label":"L 1"},{"tab_id":"wT:t9","label":"other 1"}]}}' > "$T/fx/tabs.json"
panes() { # panes <alpha-status> <beta-status>
  jq -n --arg a "$1" --arg b "$2" '{result:{panes:[
    {pane_id:"wT:pA",tab_id:"wT:t1",label:"architect",agent:"claude",agent_status:"idle"},
    {pane_id:"wT:p1",tab_id:"wT:t1",label:"alpha",agent:"claude",agent_status:$a},
    {pane_id:"wT:p2",tab_id:"wT:t1",label:"beta",agent:"claude",agent_status:$b},
    {pane_id:"wT:p3",tab_id:"wT:t1",label:"free",agent:null,agent_status:"unknown"},
    {pane_id:"wT:p9",tab_id:"wT:t9",label:"stranger",agent:"claude",agent_status:"idle"}]}}' > "$T/fx/panes.json"
}
fresh() { touch "$T/projects/p/sid-wT_p1.jsonl" "$T/projects/p/sid-wT_p2.jsonl"; }
stale() { touch -d "@$(( $(date +%s) - 120 ))" "$T/projects/p/sid-wT_$1.jsonl"; }
tick() { : > "$T/log"; $L sweep L --once >/dev/null 2>&1; }
LOG() { cat "$T/state/L/sweep.log" 2>/dev/null; }

# ---- quiet: both seats working, nothing to say -> nothing sent
panes working working; fresh
echo "working on it" > "$T/fx/read-wT_p1.txt"; echo "working" > "$T/fx/read-wT_p2.txt"
tick; tick
[ "$(prompts)" = 0 ] && ok "quiet ticks send the architect nothing" || bad "quiet ticks send nothing" "$(grep '^agent prompt' "$T/log")"
grep -q 'stranger' <(LOG) && bad "another line's seat is not watched" || ok "another line's seat is not watched"
[ "$(LOG | grep -c 'seat: alpha')" = 1 ] && ok "a steady seat logs one line, not one per tick" || bad "one line on change" "$(LOG)"
head -1 "$(readlink -f "$T/state/L/sweep.log")" | grep -qx -- '---' && ok "log lives in the artifact store with frontmatter" \
  || bad "artifact log frontmatter" "$(readlink -f "$T/state/L/sweep.log")"
readlink -f "$T/state/L/sweep.log" | grep -Eq "$T/art/log/[0-9]{4}/[0-9]{2}/[0-9]{8}-[0-9]{6}-line-watch-L\.log$" \
  && ok "log path is <key>/YYYY/MM/YYYYMMDD-HHMMSS-<name>" || bad "artifact path" "$(readlink -f "$T/state/L/sweep.log")"

# ---- a quoted placeholder is not done
printf 'End with exactly: DONE alpha <pr-url>\n' > "$T/fx/read-wT_p1.txt"; tick
[ "$(prompts)" = 0 ] && ok "a quoted 'DONE alpha <pr-url>' does not count" || bad "placeholder is not done"

# ---- AC2: done token wakes the architect once, as JSON
printf '● DONE alpha https://github.com/o/r/pull/7\n' > "$T/fx/read-wT_p1.txt"; tick
[ "$(prompts)" = 1 ] && ok "AC2 done token wakes the architect once" || bad "AC2 one wake" "$(cat "$T/log")"
msg="$(grep '^agent prompt wT:pA ' "$T/log" | sed 's/^agent prompt wT:pA //')"
jq -e '.status_code == "LW-DONE" and .facts.seat == "alpha" and .facts.context_pct == 42 and (.acceptance_criteria | length) >= 1' <<<"$msg" >/dev/null \
  && ok "AC2 the wake is one JSON line with code, seat, context and AC" || bad "AC2 JSON shape" "$msg"
tick
[ "$(prompts)" = 0 ] && ok "AC2 the same done is never sent twice" || bad "AC2 no repeat"

printf '● DONE alpha https://github.com/o/r/pull/8\n' > "$T/fx/read-wT_p1.txt"; tick
[ "$(prompts)" = 1 ] && ok "a second, different done token is reported too" || bad "second done" "$(LOG | tail -2)"

# ---- a failed herdr list is not "every seat left" (reviewer finding): no state wipe, no re-alerts
mv "$T/fx/tabs.json" "$T/fx/tabs.keep"; tick; mv "$T/fx/tabs.keep" "$T/fx/tabs.json"
LOG | grep -q 'left the line' && bad "discovery failure keeps seat state" "$(LOG | tail -3)" || ok "discovery failure keeps seat state"
LOG | grep -q 'ALERT herdr list failed' && ok "discovery failure is one ALERT line" || bad "discovery ALERT"
tick; [ "$(prompts)" = 0 ] && ok "after recovery nothing is re-sent" || bad "no re-send after recovery"

# ---- AC3: an idle seat over 1 minute raises one ALERT line
panes working idle; stale p2; tick
[ "$(LOG | grep -c 'ALERT beta .*LW-ALERT-IDLE')" = 1 ] && ok "AC3 idle over 60s raises one ALERT line" || bad "AC3 ALERT" "$(LOG)"
[ "$(grep -c '^agent prompt wT:pA .*LW-ALERT-IDLE' "$T/log")" = 1 ] && ok "AC3 the ALERT wakes the architect" || bad "AC3 wake"
tick
[ "$(LOG | grep -c 'ALERT beta .*LW-ALERT-IDLE')" = 1 ] && [ "$(prompts)" = 0 ] && ok "AC3 a still-idle seat does not alert again" || bad "AC3 once" "$(LOG)"
panes working working; fresh; tick
LOG | tail -1 | grep -q 'seat: beta' && ok "a seat back at work logs its recovery" || bad "recovery" "$(LOG | tail -2)"

# ---- blocked on a dialog
printf 'Bash command\n  rm -rf x\nDo you want to proceed?\n  1. Yes\nEsc to cancel\n' > "$T/fx/read-wT_p2.txt"; tick
LOG | grep -q 'ALERT beta .*LW-ALERT-BLOCKED' && ok "a seat on a permission dialog raises ALERT" || bad "blocked" "$(LOG | tail -2)"

# ---- up: a labelled 3x3 monitor tab, the sweep in a labelled pane
echo 200 > "$T/fx/next"; : > "$T/log"; LW_COMPACT=0 $L up L >/dev/null 2>&1
grep -qF 'tab create --workspace wT' "$T/log" && grep -qF -- '--label L monitor' "$T/log" && ok "up opens tab 'L monitor'" || bad "monitor tab" "$(head -3 "$T/log")"
[ "$(grep -c '^pane split' "$T/log")" = 8 ] && ok "up builds a 3x3 (8 splits)" || bad "3x3" "$(grep -c '^pane split' "$T/log") splits"
grep -q '^pane rename wT:p201 L-sweep' "$T/log" && ok "the sweep pane is labelled L-sweep" || bad "sweep label" "$(grep rename "$T/log" | tail -3)"
grep -q '^pane run wT:p201 .*line-watch.sh sweep L' "$T/log" && ok "up runs the sweep in that pane" || bad "sweep run"

# ---- outside herdr: refuse, never background
HERDR_ENV=0 $L sweep L >/dev/null 2>&1 && bad "sweep refuses outside herdr" || ok "sweep refuses outside herdr (Rule 18)"

[ "$fail" = 0 ] && echo "ok  line-watch: done wakes once as JSON, quiet ticks silent, idle and blocked raise one ALERT, 3x3 monitor tab"
exit "$fail"
