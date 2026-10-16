#!/usr/bin/env bash
# shellcheck disable=SC2016 # jq programs are single-quoted on purpose
# stuck-watch-ctl.sh - put stuck-watch in, or take it out of, a labeled pane of the line's monitor tab (items 27, Rule 18).
#
# usage: stuck-watch-ctl.sh <up|down|status> <line>
#   up      pane "<line>-stuck-watch": reuse it, else take a free slot of tab "<line> monitor" (line-watch's grid);
#           runs stuck-watch.sh --line <line> in its foreground. Idempotent: a running watcher is left alone.
#   down    stop the watcher and give its pane back as a free slot ("free"), never closing line-watch's tab.
#   status  pane, pid, last heartbeat age on the bus.
# env: WS (default $HERDR_WORKSPACE_ID), HERDR_BIN, plus every stuck-watch.sh env var, passed through to the pane.
#
# BREADCRUMB - the pane comes from line-watch's monitor grid; this script opens no tab of its own.
# What broke: nothing yet; the rejected alternative. A second tab-opening routine would duplicate bin/line-watch.sh
#   new_mon_tab() and the two would race for slots. Editing line-watch.sh belongs to its own ticket (item 19).
# Why this fix: take a slot labelled free in "<line> monitor"; when none is free, fail loud and name the target that
#   makes one (`make line-watch LINE=`). Cost: stuck-watch needs line-watch's tab up first.
set -uo pipefail
HERE="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
# shellcheck source=stuck-watch/lib.sh disable=SC1091
. "$HERE/lib.sh"
cmd="${1:-}"; LINE="${2:-}"
if [ -z "$cmd" ] || [ -z "$LINE" ]; then sed -n '4,10p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 2; fi
H="${HERDR_BIN:-herdr}"; WS="${WS:-${HERDR_WORKSPACE_ID:-}}"; LSUB="$(sw_tok "$LINE")"; LABEL="$LSUB-stuck-watch"
PID="$(sw_state_dir)/$LSUB.pid"
wsarg() { [ -n "$WS" ] && printf -- '--workspace\n%s\n' "$WS"; }
panes() { mapfile -t a < <(wsarg); "$H" pane list "${a[@]}"; }
tabs() { mapfile -t a < <(wsarg); "$H" tab list "${a[@]}"; }
pane_by_label() { panes | jq -r --arg l "$1" 'first(.result.panes[] | select(.label == $l) | .pane_id) // empty'; }
running() { [ -f "$PID" ] && kill -0 "$(cat "$PID")" 2>/dev/null; }

case "$cmd" in
  up)
    [ "${HERDR_ENV:-}" = 1 ] || sw_die "not inside herdr; stuck-watch runs in a labeled herdr pane only (Rule 18)"
    if running; then echo "stuck-watch $LINE already on, pid $(cat "$PID")"; exit 0; fi
    p="$(pane_by_label "$LABEL")"
    if [ -z "$p" ]; then
      ids="$(tabs | jq -c --arg t "$LINE monitor" '[.result.tabs[] | select((.label // "") == $t or ((.label // "") | startswith($t + " "))) | .tab_id]')"
      p="$(panes | jq -r --argjson ids "$ids" 'first(.result.panes[] | select(((.label // "") | startswith("free")) and (.tab_id as $t | $ids | index($t)))) | .pane_id // empty')"
      [ -n "$p" ] || sw_die "no free slot in tab \"$LINE monitor\"; run: make -C claude/workflow line-watch LINE=$LINE"
      "$H" pane rename "$p" "$LABEL" >/dev/null
    fi
    envs=""; for v in $(compgen -e | grep -E '^(SW_|NTFY_TOPIC_VAR$|ENV_FILE$|ARTIFACT_ROOT$|WF_PROJECTS_DIR$)'); do envs+="$(printf '%s=%q ' "$v" "${!v}")"; done
    "$H" pane run "$p" "$(printf 'echo $$ > %q; exec env %s bash %q --line %q' "$PID" "$envs" "$HERE/stuck-watch.sh" "$LINE")" >/dev/null \
      || sw_die "herdr could not start stuck-watch in $p"
    echo "stuck-watch $LINE on in $p ($LABEL)" ;;
  down)
    if running; then kill "$(cat "$PID")" && echo "stuck-watch $LINE off"; else echo "stuck-watch $LINE already off"; fi
    rm -f "$PID"
    p="$(pane_by_label "$LABEL")"; [ -n "$p" ] && "$H" pane rename "$p" free >/dev/null && echo "pane $p back to free" ;;
  status)
    if running; then echo "stuck-watch $LINE on, pid $(cat "$PID"), pane $(pane_by_label "$LABEL")"; else echo "stuck-watch $LINE off"; fi
    r="$(sw_js_get "$(jq -nc --arg s "$(sw_cfg .subject_root).$LSUB.heartbeat" '{last_by_subj:$s}')")" || { echo "bus unreachable"; exit 1; }
    t="$(jq -r '.message.time // empty' <<<"$r")"
    [ -n "$t" ] && echo "last heartbeat $t ($(( $(date -u +%s) - $(date -u -d "$t" +%s) ))s ago)" || echo "no heartbeat on the bus" ;;
  *) sw_die "unknown command $cmd" ;;
esac
