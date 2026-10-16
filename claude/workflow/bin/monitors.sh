#!/usr/bin/env bash
# monitors.sh - a line's monitoring tab: one labelled 3x3 tab, every monitor declared in config/monitors.json at its slot.
# name: monitors.sh
# purpose: build the "<line> monitor" herdr tab and run every monitor of config/monitors.json in its slot
# inputs: config/monitors.json, LINE, WS, environment for ${NAME} substitution
# outputs: one status line per monitor
# writes-to: herdr panes and tabs only
# cleanup: make monitors-down LINE=
#
# usage: monitors.sh up <line> | down <line> | status <line> | grid <tab-label>
#   up      build tab "<line> monitor" if absent and start every declared monitor not already running in its slot
#   down    run each monitor's `down`, then close every "<line> monitor*" tab: the tab and its panes go together
#   status  one line per declared monitor: slot, pane, running or not
#   grid    build one more 3x3 tab of panes labelled "free R.C" and print its top-left pane (overflow for per-seat watchers)
# env: WS (default $HERDR_WORKSPACE_ID), LW_MONITORS (config/monitors.json); every ${NAME} in a command comes from the env.
#
# BREADCRUMB - ported, not invented: ~/projects/coq-jev-herdr-plugin/herdr/bin/monitors.sh (itself from bearings-v2 F-28).
# What it keeps: the grid is drawn once, whole, and afterwards a pane only changes label and command; slots are named by
#   position, so a monitor lands in the same pane after every restart; no agent ever runs in a monitoring tab.
# What it changes, by owner order 2026-10-16T04:36Z ("that lives and dies in a monitoring tab too along with those scripts
#   from makefiles"): `down` closes the tab, where coq's never closes a pane; and the map is a flat list of monitors that
#   seats extend with their own entry, not coq's reserved-slot table. Rejected: sourcing coq's script, which needs its
#   seat-lib.sh, herdr session and workspace label; that is a second project's plumbing inside this one.
# Cost: a monitor whose slot another entry already took is refused (exit 3), not moved.
set -uo pipefail
HERE="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
# shellcheck source=bin/workflow-lib.sh disable=SC1091
. "$HERE/workflow-lib.sh"
wf_need herdr; wf_need jq
MC="${LW_MONITORS:-$WF_REPO/config/monitors.json}"; [ -f "$MC" ] || wf_die "no monitors config at $MC"
WS="${WS:-${HERDR_WORKSPACE_ID:-}}"; [ -n "$WS" ] || wf_die "no workspace: run inside herdr or set WS="
verb="${1:-}"; arg="${2:-}"
if [ -z "$verb" ] || [ -z "$arg" ]; then sed -n '4,9p' "$HERE/monitors.sh" | sed 's/^# \{0,1\}//' >&2; exit 2; fi

panes() { herdr pane list --workspace "$WS" 2>/dev/null; }
tab_of() { herdr tab list --workspace "$WS" 2>/dev/null | jq -r --arg t "$1" 'first(.result.tabs[] | select((.label // "") == $t) | .tab_id) // empty'; }
in_tab() { panes | jq -r --arg t "$1" --arg l "$2" 'first(.result.panes[] | select(.tab_id == $t and (.label // "") == $l) | .pane_id) // empty'; }

# subst <text>: ${line} ${ws} ${repo} and any ${NAME} from the environment; an unset name becomes empty.
subst() {
  local s="$1" n
  s="${s//\$\{line\}/$LINE}"; s="${s//\$\{ws\}/$WS}"; s="${s//\$\{repo\}/$WF_REPO}"
  while [[ "$s" =~ \$\{([A-Za-z_][A-Za-z0-9_]*)\} ]]; do n="${BASH_REMATCH[1]}"; s="${s//\$\{$n\}/${!n:-}}"; done
  printf '%s' "$s"
}

# grid <label>: 3 columns split right, then each column split down twice; every pane labelled "free R.C".
cmd_grid() {
  local r root c rr prev
  local -a cols
  r="$(herdr tab create --workspace "$WS" --cwd "$WF_REPO" --label "$1" --no-focus)" || return 1
  root="$(jq -r '.result.root_pane.pane_id' <<<"$r")"; cols=("$root")
  for c in 1 2; do
    r="$(herdr pane split "${cols[c-1]}" --direction right --ratio "$(awk -v k=$((4 - c)) 'BEGIN{printf "%.4f", 1/k}')" --cwd "$WF_REPO" --no-focus)" || return 1
    cols[c]="$(jq -r '.result.pane.pane_id' <<<"$r")"
  done
  for c in 0 1 2; do
    herdr pane rename "${cols[c]}" "free 1.$((c + 1))" >/dev/null; prev="${cols[c]}"
    for rr in 2 3; do
      r="$(herdr pane split "$prev" --direction down --ratio "$(awk -v k=$((5 - rr)) 'BEGIN{printf "%.4f", 1/k}')" --cwd "$WF_REPO" --no-focus)" || return 1
      prev="$(jq -r '.result.pane.pane_id' <<<"$r")"; herdr pane rename "$prev" "free $rr.$((c + 1))" >/dev/null
    done
  done
  printf '%s\n' "$root"
}

cmd_up() {
  local tab name slot cmd iv label p rc=0
  tab="$(tab_of "$TAB")"
  if [ -z "$tab" ]; then cmd_grid "$TAB" >/dev/null || wf_die "could not build tab $TAB"; tab="$(tab_of "$TAB")"; fi
  [ -n "$tab" ] || wf_die "tab $TAB not found after building it"
  while IFS=$'\t' read -r name slot iv cmd; do
    label="$SAFE-$name"
    if [ -n "$(in_tab "$tab" "$label")" ]; then echo "monitor $name: already in its slot"; continue; fi
    p="$(in_tab "$tab" "free $slot")"
    [ -n "$p" ] || { echo "monitor $name: slot $slot is not free in $TAB" >&2; rc=3; continue; }
    cmd="$(subst "$cmd")"
    case "${cmd%% *}" in claude|codex|*/claude|*/codex) echo "monitor $name: refusing to run an agent in a monitoring tab" >&2; rc=1; continue ;; esac
    [ "$iv" -gt 0 ] && cmd="while :; do clear; date -u +%FT%TZ; $cmd; sleep $iv; done"
    if ! herdr pane rename "$p" "$label" >/dev/null || ! herdr pane run "$p" "HERDR_ENV=1 WS=$WS $cmd" >/dev/null; then
      echo "monitor $name: herdr could not start it in $p" >&2; rc=4; continue
    fi
    echo "monitor $name: on in $p ($label, slot $slot)"
  done < <(jq -r '.monitors[] | [.name, .slot, (.interval // 0), .command] | @tsv' "$MC")
  return "$rc"
}

cmd_down() {
  local down t
  while IFS= read -r down; do
    [ -n "$down" ] || continue
    bash -c "$(subst "$down")" >/dev/null 2>&1 || echo "a down command failed: $(subst "$down")" >&2
  done < <(jq -r '.monitors[] | .down // empty' "$MC")
  for t in $(herdr tab list --workspace "$WS" 2>/dev/null | jq -r --arg t "$TAB" '.result.tabs[] | select((.label // "") == $t or ((.label // "") | startswith($t + " "))) | .tab_id'); do
    herdr tab close "$t" >/dev/null 2>&1 && echo "closed tab $t"
  done
  return 0
}

cmd_status() {
  local tab name slot p rc=0
  tab="$(tab_of "$TAB")"
  [ -n "$tab" ] || { echo "tab $TAB: down"; return 1; }
  echo "tab $TAB: $tab"
  while IFS=$'\t' read -r name slot; do
    p="$(in_tab "$tab" "$SAFE-$name")"
    if [ -n "$p" ]; then printf '  %s  %-12s %s\n' "$slot" "$name" "$p"; else printf '  %s  %-12s missing\n' "$slot" "$name"; rc=1; fi
  done < <(jq -r '.monitors[] | [.slot, .name] | @tsv' "$MC" | awk -F'\t' '{print $2"\t"$1}')
  return "$rc"
}

case "$verb" in
  grid) cmd_grid "$arg" ;;
  up|down|status)
    LINE="$arg"; SAFE="${LINE//[^A-Za-z0-9_-]/-}"; TAB="$(subst "$(jq -r .tab "$MC")")"
    "cmd_$verb" ;;
  *) wf_die "unknown verb $verb (up|down|status|grid)" ;;
esac
