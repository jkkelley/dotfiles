#!/usr/bin/env bash
# shellcheck disable=SC2016 # jq programs and the NATS $JS subject are single-quoted on purpose
# stuck-watch.sh - is a seat really stuck? Code it with evidence on the bus, and ring the owner's phone. No model calls.
#
# usage: stuck-watch.sh --line L [--once] [--config FILE]
#   every interval_seconds (foreground loop; the monitor pane runs it, Rule 18), for each claude seat in tabs "L N":
#     STK-001 idle > idle_seconds, no result file        STK-002 no commit or PR change in stale_minutes, no result file
#     STK-003 CPU 0 for cpu_zero_samples ticks, no result STK-004 context over ctx_pct
#     STK-005 result claims done, gh says a PR is not merged or CI not green      A2A-004 SOP breach in a result file
#   each code -> line.<L>.stuck.<code> (every tick, so stuck-audit sees duration); first time per seat+code per
#   dedupe_minutes -> evidence file in the artifact store and an ntfy POST. Then line.<L>.heartbeat (deadman.sh reads it).
# env (each overrides config.json): SW_CONFIG, SW_STATE_DIR, SW_IDLE_S, SW_STALE_MIN, SW_CPU_SAMPLES, SW_CTX_PCT,
#   SW_DEDUPE_MIN, SW_RUN_DIR, NTFY_TOPIC_VAR (topic key; tests and gates pass YPC_NTFY_TEST_TOPIC, item 35), ENV_FILE,
#   HERDR_BIN, GH_BIN, SW_RESOURCES_CMD (prints seat-resources --json), SW_PUB_CMD, SW_CURL_BIN, WF_PROJECTS_DIR.
#
# BREADCRUMB - idle is the transcript's age, never herdr's agent_status.
# What broke: herdr reports "idle" for every unfocused pane (bin/workflow-lib.sh wf_idle_seconds note, bearings-v2
#   compact-now.sh, 2026-09-21), so a status-based check would code every working seat as stuck every minute.
# Why this fix: seconds since the seat's transcript last changed (wf_transcript + wf_idle_seconds), the number the watcher
#   already trusts; a seat with no transcript yet ages from when stuck-watch first saw it. Rejected: herdr agent wait.
# Cost: a single tool call longer than idle_seconds reads as idle; dedupe keeps that to one page per 30 min.
#
# BREADCRUMB - a done claim is checked against gh, never trusted (owner: "i dont trust you or agents or humans").
# What broke: a result file saying status done while its PR sat open or red read as finished work.
# Why this fix: every PR URL in a done result is asked of `gh pr view` (state, statusCheckRollup); anything but MERGED with
#   every check SUCCESS/NEUTRAL/SKIPPED is STK-005. A PR seen MERGED and green is cached, since that cannot change.
# Cost: one gh call per open PR per tick.
set -uo pipefail
HERE="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
LINE=""; ONCE=0
while [ $# -gt 0 ]; do case "$1" in
  --line) LINE="$2"; shift 2 ;; --once) ONCE=1; shift ;; --config) SW_CONFIG="$2"; shift 2 ;;
  -h|--help) sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;; *) echo "stuck-watch: unknown argument $1" >&2; exit 2 ;; esac; done
# shellcheck source=stuck-watch/lib.sh disable=SC1091
. "$HERE/lib.sh"
# shellcheck source=bin/workflow-lib.sh disable=SC1091
. "$HERE/../bin/workflow-lib.sh"
[ -n "$LINE" ] || sw_die "--line is required"
command -v jq >/dev/null || sw_die "jq is required"
HERDR="${HERDR_BIN:-herdr}"; GH="${GH_BIN:-gh}"
LSUB="$(sw_tok "$LINE")"; ROOT="$(sw_val SW_SUBJECT_ROOT subject_root)"
IDLE_S="$(sw_val SW_IDLE_S idle_seconds)"; STALE_S=$(( $(sw_val SW_STALE_MIN stale_minutes) * 60 ))
CPU_N="$(sw_val SW_CPU_SAMPLES cpu_zero_samples)"; CTX="$(sw_val SW_CTX_PCT ctx_pct)"; KIND="$(sw_cfg .agent_kind)"
INTERVAL="$(sw_val SW_INTERVAL interval_seconds)"; RUN_DIR="$(sw_expand "$(sw_val SW_RUN_DIR run_dir)")"
STATE="$(sw_state_dir)/$LSUB.json"; [ -s "$STATE" ] || echo '{"seen":{},"cpu0":{},"green":{}}' > "$STATE"
RES_CMD="${SW_RESOURCES_CMD:-bash $HERE/../resources/seat-resources.sh --json --line $LINE}"

path_for() { local t; t="$(sw_cfg "$1")"; t="${t//\{run_dir\}/$RUN_DIR}"; printf '%s' "${t//\{seat\}/$2}"; }
st_get() { jq -r "$@" "$STATE"; }
st_set() { jq "$@" "$STATE" > "$STATE.tmp" && mv "$STATE.tmp" "$STATE"; }

# emit <seat> <pane> <code> <evidence-json>: bus every tick; evidence file and phone once per dedupe window.
emit() {
  local seat="$1" pane="$2" code="$3" ev="$4" key="$LSUB/$1/$3" means path="" http="" ev_json
  means="$(jq -r --arg c "$code" '.codes[$c].means // ""' "$SW_CONFIG")"
  ev_json="$(jq -nc --arg at "$(sw_now)" --arg l "$LINE" --arg s "$seat" --arg p "$pane" --arg c "$code" --arg m "$means" --argjson e "$ev" \
    '{schema:"stuck-watch/event/1",at:$at,line:$l,seat:$s,pane:$p,code:$c,means:$m,evidence:$e}')"
  if sw_due "$key"; then
    path="$(sw_evidence "$seat" "$code" "$ev_json")"
    http="$(sw_ntfy "$code $seat ($LINE)" "$( [ "$code" = STK-005 ] || [ "$code" = A2A-004 ] && echo high || echo default)" \
            "$means. Evidence: $path")" && sw_stamp "$key"
  fi
  ev_json="$(jq -c --arg p "$path" --arg h "$http" '. + {evidence_path:(if $p=="" then null else $p end), ntfy_http:(if $h=="" then null else $h end)}' <<<"$ev_json")"
  sw_pub "$ROOT.$LSUB.stuck.$(sw_tok "$code")" "$ev_json" || echo "WARN bus unreachable, $code $seat not published" >&2
  printf '%s %s %s ntfy=%s\n' "$(date -u +%H:%M:%SZ)" "$code" "$seat" "${http:-deduped}"
  CODES=$((CODES + 1))
}

# pr_check <url>: prints evidence JSON and exits 1 when the PR is not merged or CI is not green.
pr_check() {
  local url="$1" j
  [ "$(st_get --arg u "$url" '.green[$u] // false')" = true ] && return 0
  j="$("$GH" pr view "$url" --json state,statusCheckRollup 2>/dev/null)" || { jq -nc --arg u "$url" '{pr:$u,gh:"unreadable"}'; return 1; }
  if jq -e '.state=="MERGED" and ([.statusCheckRollup[]? | (.conclusion // .state // "") | ascii_upcase
        | select(IN("SUCCESS","NEUTRAL","SKIPPED")|not)] | length==0)' <<<"$j" >/dev/null; then
    st_set --arg u "$url" '.green[$u]=true'; return 0; fi
  jq -c --arg u "$url" '{pr:$u,state,failing:[.statusCheckRollup[]? | select(((.conclusion // .state // "")|ascii_upcase) | IN("SUCCESS","NEUTRAL","SKIPPED")|not) | {name:(.name // .context),conclusion:(.conclusion // .state)}]}' <<<"$j"
  return 1
}

seat_tick() { # seat_tick <seat> <pane> <session> <cpu|"">
  local seat="$1" pane="$2" sid="$3" cpu="$4" now tr="" idle seen ctx=0 res brief wt br last pr_at ev bad f
  now="$(date -u +%s)"
  [ -n "$sid" ] && for f in "${WF_PROJECTS_DIR:-$HOME/.claude/projects}"/*/"$sid".jsonl; do [ -f "$f" ] && tr="$f"; done
  seen="$(st_get --arg s "$seat" '.seen[$s] // empty')"; [ -n "$seen" ] || { seen="$now"; st_set --arg s "$seat" --argjson t "$now" '.seen[$s]=$t'; }
  if [ -n "$tr" ]; then idle="$(wf_idle_seconds "$tr")"; ctx="$(wf_context_pct "$tr")"; else idle=$((now - seen)); fi
  res="$(path_for .result_file "$seat")"
  [ "$ctx" -gt "$CTX" ] && emit "$seat" "$pane" STK-004 "$(jq -nc --argjson c "$ctx" --argjson t "$CTX" --arg tr "$tr" '{context_pct:$c,threshold:$t,transcript:$tr}')"
  if [ -f "$res" ]; then
    st_set --arg s "$seat" 'del(.cpu0[$s])'
    if jq -e --argjson pc "$(sw_cfg .page_result_codes)" '.status_code as $c | $pc | index($c)' "$res" >/dev/null 2>&1; then
      emit "$seat" "$pane" "$(jq -r .status_code "$res")" "$(jq -c --arg r "$res" '{result_file:$r,status_code,blockers}' "$res")"; fi
    if jq -e '.status=="done" or .status_code=="A2A-002"' "$res" >/dev/null 2>&1; then
      bad="[]"
      while IFS= read -r u; do [ -n "$u" ] || continue
        ev="$(pr_check "$u")" || bad="$(jq -c --argjson e "$ev" '. + [$e]' <<<"$bad")"
      done < <(grep -oE 'https://github\.com/[^/" ]+/[^/" ]+/pull/[0-9]+' "$res" | sort -u)
      [ "$bad" != "[]" ] && emit "$seat" "$pane" STK-005 "$(jq -nc --arg r "$res" --argjson b "$bad" '{result_file:$r,claim:"done",prs:$b}')"
    fi
    return 0
  fi
  [ "$idle" -gt "$IDLE_S" ] && emit "$seat" "$pane" STK-001 "$(jq -nc --argjson i "$idle" --argjson t "$IDLE_S" --arg r "$res" --arg tr "$tr" '{idle_s:$i,threshold_s:$t,result_file:$r,result_exists:false,transcript:$tr}')"
  if [ -n "$cpu" ]; then
    if awk -v c="$cpu" 'BEGIN{exit !(c+0==0)}'; then st_set --arg s "$seat" '.cpu0[$s]=((.cpu0[$s] // 0)+1)'; else st_set --arg s "$seat" '.cpu0[$s]=0'; fi
    local n; n="$(st_get --arg s "$seat" '.cpu0[$s] // 0')"
    [ "$n" -ge "$CPU_N" ] && emit "$seat" "$pane" STK-003 "$(jq -nc --argjson n "$n" --argjson t "$CPU_N" '{cpu_zero_ticks:$n,threshold:$t,cpu_pct:0}')"
  fi
  brief=""; while IFS= read -r f; do f="${f//\{run_dir\}/$RUN_DIR}"; f="${f//\{seat\}/$seat}"; [ -f "$f" ] && { brief="$f"; break; }; done < <(sw_cfg '.brief_files[]')
  [ -n "$brief" ] || return 0
  wt="$(sw_expand "$(jq -r '.facts.worktree // empty' "$brief")")"; br="$(jq -r '.facts.branch // empty' "$brief")"
  [ -n "$wt" ] && [ -n "$br" ] && [ -d "$wt" ] || return 0
  last="$(git -C "$wt" log -1 --format=%ct "$br" 2>/dev/null || echo 0)"
  pr_at="$(cd "$wt" && "$GH" pr list --head "$br" --state all --json updatedAt -q '.[0].updatedAt // empty' 2>/dev/null)"
  [ -n "$pr_at" ] && pr_at="$(date -u -d "$pr_at" +%s 2>/dev/null || echo 0)" || pr_at=0
  [ "$pr_at" -gt "$last" ] && last="$pr_at"
  [ "$seen" -gt "$last" ] && last="$seen"   # a seat gets stale_minutes from when it was first seen, not from main's last commit
  [ $((now - last)) -gt "$STALE_S" ] && emit "$seat" "$pane" STK-002 "$(jq -nc --arg w "$wt" --arg b "$br" --argjson a "$((now - last))" --argjson t "$STALE_S" '{worktree:$w,branch:$b,since_change_s:$a,threshold_s:$t}')"
  return 0
}

tick() {
  local agents tabs res seats
  CODES=0
  agents="$("$HERDR" agent list)" || { echo "WARN herdr agent list failed" >&2; agents='{"result":{"agents":[]}}'; }
  tabs="$("$HERDR" tab list)" || tabs='{"result":{"tabs":[]}}'
  res="$($RES_CMD 2>/dev/null)" || res='{"seats":[]}'; jq -e . <<<"$res" >/dev/null 2>&1 || res='{"seats":[]}'
  seats="$(jq -r --arg k "$KIND" --arg l "$LINE" --argjson tabs "$tabs" --argjson res "$res" --argjson ex "$(sw_cfg .exempt_seats)" '
    ($tabs.result.tabs | map({(.tab_id): .label}) | add // {}) as $tl
    | ($res.seats | map({(.pane): .cpu_pct}) | add // {}) as $cpu
    | .result.agents[] | select(.agent==$k) | select((($tl[.tab_id] // "") | startswith($l + " ")))
    | (.name // .pane_id) as $s | select($ex | index($s) | not)
    | [$s, .pane_id, (.agent_session.value // ""), ($cpu[.pane_id] // "" | tostring)] | @tsv' <<<"$agents")"
  local n=0
  while IFS=$'\t' read -r seat pane sid cpu; do [ -n "$seat" ] || continue; n=$((n + 1)); seat_tick "$seat" "$pane" "$sid" "$cpu"; done <<<"$seats"
  sw_pub "$ROOT.$LSUB.heartbeat" "$(jq -nc --arg at "$(sw_now)" --arg l "$LINE" --argjson n "$n" --argjson c "$CODES" '{schema:"stuck-watch/heartbeat/1",at:$at,line:$l,seats:$n,codes:$c}')" \
    || echo "WARN bus unreachable, heartbeat not published (deadman pages STK-091)" >&2
  printf '%s heartbeat seats=%d codes=%d\n' "$(date -u +%H:%M:%SZ)" "$n" "$CODES"
}

if [ "$ONCE" = 1 ]; then tick; else while true; do tick; sleep "$INTERVAL"; done; fi
