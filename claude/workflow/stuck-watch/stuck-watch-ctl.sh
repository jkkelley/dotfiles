#!/usr/bin/env bash
# shellcheck disable=SC2016 # jq programs are single-quoted on purpose
# stuck-watch-ctl.sh - stuck-watch as one monitor of the line's monitor tab (item 27, Rule 18): up, down, status.
#
# usage: stuck-watch-ctl.sh <up|down|status> <line>
#   up      bin/monitors.sh up <line>: the tab "<line> monitor" and every declared monitor, stuck-watch at its slot
#           (config/monitors.json entry stuck-watch). Idempotent: monitors.sh starts only what is not running.
#   down    stop this watcher only (pid written by stuck-watch.sh's loop); the tab and the other monitors stay.
#   status  pid, last heartbeat age on the bus.
# env: WS (default $HERDR_WORKSPACE_ID), plus every stuck-watch.sh env var.
#
# BREADCRUMB - placement belongs to bin/monitors.sh, not to this script.
# What broke: the first cut of this script took a free pane of line-watch's grid itself; #171 then landed the generic
#   bin/monitors.sh and a slot-based config/monitors.json, and two placers would race for the same panes.
# Why this fix: stuck-watch is one config entry (slot 2.3) and `up` delegates to monitors.sh; only `down` and `status`
#   stay here, through the pid file the loop writes. Rejected: keeping a private placer (item 27: one pattern).
# Cost: `up` also starts any other declared monitor that is not running, which is what monitors-up means anyway.
set -uo pipefail
HERE="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
# shellcheck source=stuck-watch/lib.sh disable=SC1091
. "$HERE/lib.sh"
cmd="${1:-}"; LINE="${2:-}"
if [ -z "$cmd" ] || [ -z "$LINE" ]; then sed -n '4,9p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 2; fi
LSUB="$(sw_tok "$LINE")"; PID="$(sw_state_dir)/$LSUB.pid"
running() { [ -f "$PID" ] && kill -0 "$(cat "$PID")" 2>/dev/null; }
case "$cmd" in
  up) bash "$HERE/../bin/monitors.sh" up "$LINE" ;;
  down)
    if running; then kill "$(cat "$PID")" && echo "stuck-watch $LINE off"; else echo "stuck-watch $LINE already off"; fi
    rm -f "$PID" ;;
  status)
    if running; then echo "stuck-watch $LINE on, pid $(cat "$PID")"; else echo "stuck-watch $LINE off"; fi
    r="$(sw_js_get "$(jq -nc --arg s "$(sw_cfg .subject_root).$LSUB.heartbeat" '{last_by_subj:$s}')")" || { echo "bus unreachable"; exit 1; }
    t="$(jq -r '.message.time // empty' <<<"$r")"
    if [ -n "$t" ]; then echo "last heartbeat $t ($(( $(date -u +%s) - $(date -u -d "$t" +%s) ))s ago)"; else echo "no heartbeat on the bus"; exit 1; fi ;;
  *) sw_die "unknown command $cmd" ;;
esac
