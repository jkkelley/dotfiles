#!/usr/bin/env bash
# watch-ctl.sh on|off|status|pause|unpause <compact PANE | seat PANE | workflow ID [WORKTREE]> - every watcher's switch.
#
#   watch-ctl.sh on compact wC1:p1        keep the seat in pane wC1:p1 under its context threshold
#   watch-ctl.sh on seat wC1:p1           report the seat done, hot swap it along its model chain (bin/seat-watch.sh)
#   watch-ctl.sh on workflow scaffold-build ~/wt   watch that workflow's gates, run in the seat's worktree
#   watch-ctl.sh off compact wC1:p1       stop it; the seat is never touched
#   watch-ctl.sh off seat wC1:p1 --close  stop it and close its monitor pane (bin/seat-watch.sh's teardown)
#   watch-ctl.sh pause seat wC1:p1        the seat watcher idles until unpause; nothing restarts
#   watch-ctl.sh status compact wC1:p1    pid, pane and the last three log lines
#   watch-ctl.sh status                   every watcher this project knows about
#
# BREADCRUMB - why a switch that places watchers in herdr panes instead of backgrounding them.
# What broke: bin/workflow-watch.sh, as ported from the kimi proxy, started its loop with `( ... ) & disown`.
#   bearings-v2's ceremony-watch.sh did the same with `( ... ) &`.
# Why it mattered: dotfiles CLAUDE.md Rule 18 - the owner watches work in herdr, and a backgrounded loop is invisible.
#   A dead background watcher is indistinguishable from a quiet one, and a live one cannot be read without a shell.
# Why this fix: `on` opens (or reuses) a pane labeled watch-<kind>-<target> in a `monitors` tab of the configured
#   workspace and runs the watcher in its foreground. The pane IS the monitor: its label says what it watches and its
#   screen is the log. Rejected: nohup plus a tail pane, which keeps the process invisible and adds a second thing to die.
# Cost: watchers need herdr up. Outside herdr `on` refuses and says so, per Rule 18, rather than falling back.
set -uo pipefail
# shellcheck source=bin/workflow-lib.sh disable=SC1091
. "$(dirname "$(readlink -f "$0")")/workflow-lib.sh"
wf_need jq
BIN="$(dirname "$(readlink -f "$0")")"

action="${1:-status}"; kind="${2:-}"; target="${3:-}"; cwd="${4:-}"
usage() { sed -n '3,11p' "$(readlink -f "$0")" | sed 's/^# \{0,1\}//' >&2; exit 2; }

pidfile_for() {
  case "$1" in
    compact)  printf '%s/compact-watch.pid' "$(wf_seat_dir "$2")" ;;
    seat)     printf '%s/seat-watch.pid' "$(wf_seat_dir "$2")" ;;
    workflow) printf '%s/%s-watch.pid' "$(wf_state_dir)" "$2" ;;
  esac
}
logfile_for() { local p; p="$(pidfile_for "$1" "$2")"; printf '%s.log' "${p%.pid}"; }
cmd_for() {
  case "$1" in
    compact)  printf 'bash %q %q' "$BIN/compact-watch.sh" "$2" ;;
    seat)     printf 'bash %q %q' "$BIN/seat-watch.sh" "$2" ;;
    workflow) printf 'bash %q %q run' "$BIN/workflow-watch.sh" "$2"; [ -n "$cwd" ] && printf ' --cwd %q' "$cwd" ;;
  esac
}
label_for() { printf 'watch-%s-%s' "$1" "${2//[^A-Za-z0-9-]/-}"; }
alive() { local p; p="$(cat "$1" 2>/dev/null)"; [ -n "$p" ] && kill -0 "$p" 2>/dev/null; }

status_one() {
  local pf lf; pf="$(pidfile_for "$1" "$2")"; lf="$(logfile_for "$1" "$2")"
  if alive "$pf"; then printf '%s %s: on, pid %s, pane %s\n' "$1" "$2" "$(cat "$pf")" "$(pane_by_label "$(label_for "$1" "$2")" || echo '?')"
  else printf '%s %s: off\n' "$1" "$2"; fi
  tail -n 3 "$lf" 2>/dev/null | sed 's/^/  /'
}

ws_id() { herdr workspace list | jq -r --arg l "$(wf_cfg .workflow.herdr.workspace_label)" 'first(.result.workspaces[] | select(.label == $l) | .workspace_id) // empty'; }
pane_by_label() { herdr pane list --workspace "$(ws_id)" 2>/dev/null | jq -er --arg l "$1" 'first(.result.panes[] | select(.label == $l) | .pane_id)'; }

case "$action" in
  status)
    if [ -n "$kind" ]; then [ -n "$target" ] || usage; status_one "$kind" "$target"; exit 0; fi
    found=0
    for pf in "$(wf_state_dir)"/seats/*/compact-watch.pid; do [ -f "$pf" ] || continue; found=1
      status_one compact "$(basename "$(dirname "$pf")" | sed 's/_/:/')"; done
    for pf in "$(wf_state_dir)"/seats/*/seat-watch.pid; do [ -f "$pf" ] || continue; found=1
      status_one seat "$(basename "$(dirname "$pf")" | sed 's/_/:/')"; done
    for pf in "$(wf_state_dir)"/*-watch.pid; do [ -f "$pf" ] || continue; found=1
      status_one workflow "$(basename "$pf" -watch.pid)"; done
    [ "$found" = 1 ] || echo "no watchers on"
    ;;
  on)
    case "$kind" in compact|seat|workflow) ;; *) usage ;; esac; [ -n "$target" ] || usage
    [ "${HERDR_ENV:-}" = 1 ] || wf_die "not inside herdr; watchers run in labeled herdr panes only (dotfiles Rule 18). Not starting."
    pf="$(pidfile_for "$kind" "$target")"
    alive "$pf" && { printf '%s %s already on, pid %s\n' "$kind" "$target" "$(cat "$pf")"; exit 0; }
    ws="$(ws_id)"; [ -n "$ws" ] || wf_die "no herdr workspace labelled $(wf_cfg .workflow.herdr.workspace_label)"
    label="$(label_for "$kind" "$target")"
    pane="$(pane_by_label "$label" || true)"
    if [ -z "$pane" ]; then
      tab="$(herdr tab list --workspace "$ws" | jq -r 'first(.result.tabs[] | select(.label == "monitors") | .tab_id) // empty')"
      if [ -z "$tab" ]; then
        herdr tab create --workspace "$ws" --cwd "$WF_REPO" --label monitors >/dev/null || wf_die "cannot create monitors tab"
        tab="$(herdr tab list --workspace "$ws" | jq -r 'first(.result.tabs[] | select(.label == "monitors") | .tab_id) // empty')"
        pane="$(herdr pane list --workspace "$ws" | jq -r --arg t "$tab" 'first(.result.panes[] | select(.tab_id == $t) | .pane_id) // empty')"
      else
        anchor="$(herdr pane list --workspace "$ws" | jq -r --arg t "$tab" '[.result.panes[] | select(.tab_id == $t)] | last | .pane_id')"
        herdr pane split "$anchor" --direction down --cwd "$WF_REPO" >/dev/null || wf_die "cannot split a pane in the monitors tab"
        pane="$(herdr pane list --workspace "$ws" | jq -r --arg t "$tab" '[.result.panes[] | select(.tab_id == $t and (.label == null or .label == ""))] | last | .pane_id // empty')"
      fi
      [ -n "$pane" ] || wf_die "could not find the new monitor pane"
      herdr pane rename "$pane" "$label" >/dev/null
    fi
    # BREADCRUMB - a watcher that already finished its job counts as having come up.
    # What broke: the seat-smoke gate watcher ran at 2026-09-22T22:25:09Z, found every gate passing and ended in the same
    #   second, as bin/workflow-watch.sh is designed to. This check only asked whether its pid was alive, so it reported
    #   "did not come up", and under set -e bin/workflow-spawn.sh aborted before it sent the seat its brief.
    # Why this fix: the watcher's own state file says `ended` when it stopped because its work was done; one written
    #   after this arming began is proof it ran. Rejected: letting workflow-watch linger after all gates pass, which is
    #   the unattended loop its breadcrumb exists to prevent.
    # Cost: one marker file per arming, removed on the way out.
    st="${pf%.pid}.state.json"; mark="$pf.arming"; : > "$mark"
    herdr pane run "$pane" "$(cmd_for "$kind" "$target")" >/dev/null || { rm -f "$mark"; wf_die "herdr could not run the watcher in $pane"; }
    ended=0
    for _ in 1 2 3 4 5 6; do
      alive "$pf" && break
      if [ "$st" -nt "$mark" ] && [ "$(jq -r .state "$st" 2>/dev/null)" = ended ]; then ended=1; break; fi
      sleep 1
    done
    rm -f "$mark"
    if [ "$ended" = 1 ]; then printf '%s %s ran and ended: %s\n' "$kind" "$target" "$(tail -n 1 "$(logfile_for "$kind" "$target")" 2>/dev/null)"; exit 0; fi
    alive "$pf" || wf_die "watcher did not come up in $pane; read it with: herdr pane read $pane"
    printf '%s %s on, pid %s, pane %s (%s)\n' "$kind" "$target" "$(cat "$pf")" "$pane" "$label"
    ;;
  # Ported from bearings-v2 bin/watch-toggle.sh: a flag the loop reads every tick, so pausing needs no restart and
  # the seat keeps working while its watcher stands off. Only the seat watcher acts on a seat, so only it pauses.
  pause)
    if [ "$kind" != seat ] || [ -z "$target" ]; then usage; fi
    wf_now > "$(wf_seat_dir "$target")/PAUSED"; printf 'seat %s watcher paused since %s\n' "$target" "$(cat "$(wf_seat_dir "$target")/PAUSED")"
    ;;
  unpause)
    if [ "$kind" != seat ] || [ -z "$target" ]; then usage; fi
    rm -f "$(wf_seat_dir "$target")/PAUSED"; printf 'seat %s watcher running\n' "$target"
    ;;
  off)
    case "$kind" in compact|seat|workflow) ;; *) usage ;; esac; [ -n "$target" ] || usage
    # Signals only the watcher's own pid. The seat and the run it watches are never touched.
    pf="$(pidfile_for "$kind" "$target")"
    if alive "$pf"; then kill "$(cat "$pf")"; printf '%s %s off\n' "$kind" "$target"
    else printf '%s %s was not running\n' "$kind" "$target"; rm -f "$pf"; fi
    # --close also closes the labeled monitor pane. Off alone leaves it, so a watcher can be restarted where the owner
    # was already looking; a retired seat's watchers have nothing left to show, and their panes are debris.
    if [ "$cwd" = --close ] && mp="$(pane_by_label "$(label_for "$kind" "$target")")" && [ -n "$mp" ]; then
      herdr pane close "$mp" >/dev/null 2>&1 && printf '%s %s pane %s closed\n' "$kind" "$target" "$mp"
    fi
    ;;
  *) usage ;;
esac
