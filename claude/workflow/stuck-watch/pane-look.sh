#!/usr/bin/env bash
# shellcheck disable=SC2016 # jq programs are single-quoted on purpose
# pane-look.sh - judge each seat from its pane: QUEUED-STALE and IDLE-STALE, working/idle from the spinner timer. No model calls.
# name: pane-look.sh
# purpose: snapshot seat panes to the artifact store and code QUEUED-STALE / IDLE-STALE on the bus
# inputs: stuck-watch/config.json pane_look, --line, --ws, herdr, LW_RESULTS, PL_* env
# outputs: status lines on stdout
# writes-to: NATS line.<line>.stuck.<code>, artifact store pane-look/, ~/.local/state/zenith/stuck-watch/pane-look
# cleanup: make stuck-watch-clean
#
# usage: pane-look.sh --line L --ws WS [--once] [--config FILE]
#   every judge_every_s, for each named agent pane of WS: read the last 60 lines; working = a spinner line whose timer text
#   moved since the previous tick, idle otherwise. QUEUED-STALE: a queued line below the last spinner line, text unchanged
#   queued_stale_s. IDLE-STALE: idle idle_stale_s and no $LW_RESULTS/<seat>-result.json. One bus event per seat+code per
#   episode (state file); evidence = the snapshot path. A snapshot per seat every snapshot_every_s.
# env: SW_CONFIG, SW_STATE_DIR, SW_PUB_CMD, HERDR_BIN, LW_RESULTS, ARTIFACT_ROOT, PL_NOW (epoch override, tests).
#
# BREADCRUMB - working/idle comes from the spinner timer, never from herdr's agent_status.
# What broke: herdr read "idle" for wD9:p3 sweep-build at 05:26Z while it was mid-turn (29m spinner, 6 subagents; ORD-0550 O3).
# Why this fix: the spinner line carries a timer that moves every second while the seat works; a timer text that differs from
#   the previous tick is work, whatever agent_status says. agent_status is recorded in the event and decides nothing.
# Cost: a seat whose spinner is hidden by a full-screen dialog reads idle; IDLE-STALE then needs the result file absent too.
set -uo pipefail
export LC_ALL=C.UTF-8 # the spinner glyph and the prompt marker are multibyte
HERE="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
LINE=""; WS=""; ONCE=0
while [ $# -gt 0 ]; do case "$1" in
  --line) LINE="$2"; shift 2 ;; --ws) WS="$2"; shift 2 ;; --once) ONCE=1; shift ;; --config) SW_CONFIG="$2"; shift 2 ;;
  -h|--help) sed -n '11,16p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;; *) echo "pane-look: unknown argument $1" >&2; exit 2 ;; esac; done
# shellcheck source=stuck-watch/lib.sh disable=SC1091
. "$HERE/lib.sh"
if [ -z "$LINE" ] || [ -z "$WS" ]; then sw_die "--line and --ws are required"; fi
command -v jq >/dev/null || sw_die "jq is required"
HERDR="${HERDR_BIN:-herdr}"
LSUB="$(sw_tok "$LINE")"; ROOT="$(sw_val SW_SUBJECT_ROOT subject_root)"
EVERY="$(sw_cfg .pane_look.judge_every_s)"; SNAP_S="$(sw_cfg .pane_look.snapshot_every_s)"
Q_S="$(sw_cfg .pane_look.queued_stale_s)"; I_S="$(sw_cfg .pane_look.idle_stale_s)"
SPIN_RE="$(sw_cfg .pane_look.spinner_re)"; QUEUE_RE="$(sw_cfg .pane_look.queued_re)"; KEY="$(sw_cfg .pane_look.artifact_key)"
RESULTS="$(sw_expand "${LW_RESULTS:-$(sw_cfg .run_dir)}")"
SDIR="$(sw_state_dir)/pane-look"; mkdir -p "$SDIR"
ART="$(sw_expand "${ARTIFACT_ROOT:-$HOME/.local/state/zenith}")"
now() { printf '%s' "${PL_NOW:-$(date -u +%s)}"; }

# snapshot <seat> <text>: the pane text in the artifact store (item 23), prints its path.
snapshot() {
  local d f repo br
  d="$ART/$KEY/$(date -u -d "@$(now)" +%Y/%m)"; mkdir -p "$d"
  f="$d/$(date -u -d "@$(now)" +%Y%m%d-%H%M%S)-$(sw_tok "$1" | cut -c1-30).txt"
  repo="$(basename "$(git -C "$HERE" rev-parse --show-toplevel 2>/dev/null)" 2>/dev/null)"; br="$(git -C "$HERE" branch --show-current 2>/dev/null)"
  printf -- '---\nwhat: pane snapshot of seat %s\nby: pane-look\nrepo: %s\nbranch: %s\ncreated: %s\n---\n%s\n' \
    "$1" "${repo:-unknown}" "${br:-unknown}" "$(date -u -d "@$(now)" +%Y-%m-%dT%H:%M:%SZ)" "$2" > "$f"
  printf '%s' "$f"
}

# fire <seat> <pane> <code> <since> <agent_status> <snapshot>: once per episode (the caller checks the state).
fire() {
  local ev
  ev="$(jq -nc --arg s "$1" --arg p "$2" --arg c "$3" --argjson since "$4" --arg a "$5" --arg e "$6" \
    '{seat:$s,pane:$p,code:$c,since:$since,agent_status:$a,evidence:$e}')"
  sw_pub "$ROOT.$LSUB.stuck.$3" "$ev" || echo "WARN bus unreachable, $3 $1 not published" >&2
  printf '%s %s %s\n' "$(date -u -d "@$(now)" +%H:%M:%SZ)" "$3" "$1"
}

seat_tick() { # seat_tick <seat> <pane> <agent_status>
  local seat="$1" pane="$2" astat="$3" t text spin timer queued st sf snap="" last_snap spin_at idle_at q_text q_at fired
  t="$(now)"; sf="$SDIR/$(sw_tok "$seat").json"
  [ -s "$sf" ] || echo '{"timer":"","timer_at":0,"idle_at":0,"q_text":"","q_at":0,"snap_at":0,"fired":{}}' > "$sf"
  text="$("$HERDR" pane read "$pane" --source recent-unwrapped --lines 60 2>/dev/null)" || { echo "WARN pane read failed $pane" >&2; return 0; }
  spin="$(grep -E "$SPIN_RE" <<<"$text" | tail -1)"
  timer=""; [ -z "$spin" ] || timer="$(sed -E 's/^[^(]*\(([0-9hms ]+).*/\1/' <<<"$spin")"
  # queued: below the last spinner line, or anywhere when there is no spinner
  if [ -n "$spin" ]; then queued="$(awk -v s="$spin" 'f{print} index($0,s)==1{f=1}' <<<"$text" | grep -E "$QUEUE_RE" | tail -1)"
  else queued="$(grep -E "$QUEUE_RE" <<<"$text" | tail -1)"; fi
  st="$(cat "$sf")"
  # working: the timer text moved. Same timer, or no spinner at all: idle since the last change (or first sight).
  if [ -n "$timer" ] && [ "$timer" != "$(jq -r .timer <<<"$st")" ]; then idle_at=0; spin_at="$t"
  else spin_at="$(jq -r .timer_at <<<"$st")"; idle_at="$(jq -r .idle_at <<<"$st")"; [ "$idle_at" -gt 0 ] || idle_at="$t"; fi
  q_text="$(jq -r .q_text <<<"$st")"; q_at="$(jq -r .q_at <<<"$st")"
  if [ -z "$queued" ]; then q_text=""; q_at=0
  elif [ "$queued" != "$q_text" ]; then q_text="$queued"; q_at="$t"; fi
  last_snap="$(jq -r .snap_at <<<"$st")"; fired="$(jq -c .fired <<<"$st")"
  if (( t - last_snap >= SNAP_S )); then snap="$(snapshot "$seat" "$text")"; last_snap="$t"; fi
  # a code is raised once per episode; the episode ends when its condition clears
  if [ "$q_at" -gt 0 ] && (( t - q_at >= Q_S )); then
    if [ "$(jq -r '.["QUEUED-STALE"] // empty' <<<"$fired")" = "" ]; then
      [ -n "$snap" ] || snap="$(snapshot "$seat" "$text")"
      fire "$seat" "$pane" QUEUED-STALE "$q_at" "$astat" "$snap"; fired="$(jq -c '.["QUEUED-STALE"]=true' <<<"$fired")"; fi
  else fired="$(jq -c 'del(.["QUEUED-STALE"])' <<<"$fired")"; fi
  if [ "$idle_at" -gt 0 ] && (( t - idle_at >= I_S )) && [ ! -f "$RESULTS/$seat-result.json" ]; then
    if [ "$(jq -r '.["IDLE-STALE"] // empty' <<<"$fired")" = "" ]; then
      [ -n "$snap" ] || snap="$(snapshot "$seat" "$text")"
      fire "$seat" "$pane" IDLE-STALE "$idle_at" "$astat" "$snap"; fired="$(jq -c '.["IDLE-STALE"]=true' <<<"$fired")"; fi
  else fired="$(jq -c 'del(.["IDLE-STALE"])' <<<"$fired")"; fi
  jq -nc --arg tm "${timer:-$(jq -r .timer <<<"$st")}" --argjson ta "$spin_at" --argjson ia "$idle_at" --arg qt "$q_text" --argjson qa "$q_at" \
    --argjson sa "$last_snap" --argjson f "$fired" '{timer:$tm,timer_at:$ta,idle_at:$ia,q_text:$qt,q_at:$qa,snap_at:$sa,fired:$f}' > "$sf.tmp" && mv "$sf.tmp" "$sf"
}

while :; do
  agents="$("$HERDR" agent list)" || { echo "WARN herdr agent list failed" >&2; agents='{"result":{"agents":[]}}'; }
  while IFS=$'\t' read -r seat pane astat; do
    [ -n "$seat" ] || continue
    seat_tick "$seat" "$pane" "$astat"
  done < <(jq -r --arg ws "$WS" '.result.agents[] | select(.name != null and .workspace_id == $ws) | [.name, .pane_id, (.agent_status // "")] | @tsv' <<<"$agents")
  [ "$ONCE" = 1 ] && break
  sleep "$EVERY"
done
