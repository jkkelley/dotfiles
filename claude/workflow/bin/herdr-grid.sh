#!/usr/bin/env bash
# herdr-grid.sh - every multi-agent line runs in herdr tabs on a 3 by 3 grid, placed, labelled and cleaned by script.
#
# Layout (owner, 2026-10-16 UTC: "3X3 and the 1(YOU ONLY ON AGENT IN THIS FULL 3 slots)|3 panes|3 panes, everything
# labeled, make new tabs when not, driven by makefiles and scripts with automated cleanup too"):
#   tab "<line> 1": architect alone in the left column at full height | 3 seat slots | 3 seat slots
#   tab "<line> N" (N>=2): three columns of 3 seat slots; the architect lives once, so overflow tabs hold seats only
# A slot nobody holds is a shell pane labelled "free". A seat holds a slot by renaming the pane to the seat name.
# Slot order: middle column top to bottom, then right column top to bottom (overflow: left, middle, right).
#
# usage: herdr-grid.sh <cmd> ...
#   line-up    <line>                       create tab "<line> 1" with the architect pane and the skeleton
#   seat-up    <line> <seat> [cmd]          claim the next free slot, label it, optionally run cmd and name the agent
#   claim      <line> <seat>                like seat-up without cmd; prints the pane id (for PANE=$(...) workflow-spawn.sh)
#   seat-down  <seat> [line]                close a finished seat's pane, reflow, close an emptied overflow tab
#   line-clean <line>                       seat-down for every finished seat of the line
#   line-status <line>                      one table: tab, slot, seat, agent, status. No model calls
#   line-adopt <line> <arch-pane> <seat=pane>...   migrate a live line into the grid without restarting any seat
# env: WS (default $HERDR_WORKSPACE_ID), CWD (cwd for new panes), FORCE=1 (close an unfinished seat), DRY=1,
#      GRID_STATE (default ~/.local/state/zenith/herdr-grid), GRID_RETRY_SLEEP (default 1)
#
# BREADCRUMB - the skeleton is built up front, not split lazily per seat.
# What broke: nothing yet; this is the rejected alternative. Splitting a slot only when a seat arrives leaves the right
#   column's first pane beside the middle column's top pane only, because herdr splits one pane's region, so the second
#   and third middle panes then span the full middle width and the 3x3 is gone.
# Why this fix: 6 (or 9) shell panes labelled "free" are created at once through right splits then down splits, so every
#   seat takes a place that already exists. Cost: up to 8 idle shells per tab until seats arrive; seat-down gives a pane
#   back to the layout rather than leaving a hole.
# Rejected: pane layout presets (herdr has none); a stored slot map (ids are not stable across a herdr restart, so
#   geometry from `pane layout` is rediscovered every call and nothing is stored but the agent-seen marker).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=workflow-lib.sh
. "$HERE/workflow-lib.sh"
wf_need herdr; wf_need jq

DRY="${DRY:-0}"
WS="${WS:-${HERDR_WORKSPACE_ID:-}}"
# Inputs come from arguments, env set by the Make targets (VAR=value) or config/project.json .workflow.herdr.grid, never
# from constants here (owner, 2026-10-16 UTC: "config and arguments are good ways to pass things, easy in makefiles too").
gcfg() { [ -f "$WF_CONFIG" ] && jq -r ".workflow.herdr.grid.$1 // empty" "$WF_CONFIG" 2>/dev/null; }
STATE="$(wf_expand "${GRID_STATE:-$(gcfg state_dir)}")"; [ -n "$STATE" ] || STATE="$HOME/.local/state/zenith/herdr-grid"
FREE="${GRID_FREE_LABEL:-$(gcfg free_label)}"; FREE="${FREE:-free}"
ROWS="${GRID_ROWS:-$(gcfg rows)}"; ROWS="${ROWS:-3}"
START_TIMEOUT_MS="${START_TIMEOUT_MS:-$(gcfg start_timeout_ms)}"; START_TIMEOUT_MS="${START_TIMEOUT_MS:-60000}"
[ -n "$WS" ] || wf_die "no workspace: run inside a herdr pane or set WS="

keep_of() { awk -v k="$1" 'BEGIN{printf "%.4f", 1/k}'; }
log() { printf 'grid: %s\n' "$*" >&2; }

# Every herdr call retries 3 times, then reports and fails; a mutating call is never retried blindly after DRY.
# hj prints the JSON of the first attempt that exits 0.
hj() {
  local i out
  if [ "$DRY" = 1 ]; then
    case "$2" in list|layout|get|current) : ;; *) printf 'DRY: herdr %s\n' "$*" >&2; printf '{"result":{"pane":{"pane_id":"<new>"},"tab":{"tab_id":"<new-tab>"},"root_pane":{"pane_id":"<new>"}}}\n'; return 0 ;; esac
  fi
  for i in 1 2 3; do
    if out="$(herdr "$@" 2>&1)"; then printf '%s\n' "$out"; return 0; fi
    log "retry $i/3: herdr $* -> $(printf '%s' "$out" | head -c 160)"
    sleep "${GRID_RETRY_SLEEP:-1}"
  done
  log "FAILED after 3: herdr $*"
  return 1
}

state_file() { printf '%s/%s/%s.agent-seen' "$STATE" "$1" "$2"; }

# ---- discovery: every id is rediscovered from herdr on every call ---------------------------------------------
# line_tabs <line>: "<n> <tab_id>" ascending, tabs labelled exactly "<line> <n>".
line_tabs() {
  hj tab list --workspace "$WS" | jq -r --arg l "$1" \
    '[.result.tabs[] | select(.label | test("^" + ($l | gsub("[^A-Za-z0-9_-]"; "\\\(.)")) + " [0-9]+$"))
      | {n: (.label | capture(" (?<n>[0-9]+)$").n | tonumber), id: .tab_id}] | sort_by(.n)[] | "\(.n) \(.id)"'
}

# tab_slots <tab>: JSON array of every pane in the tab ordered by column then row, with col, label, agent, status.
tab_slots() {
  local tab="$1" pl any lay
  pl="$(hj pane list --workspace "$WS")" || return 1
  any="$(jq -r --arg t "$tab" 'first(.result.panes[] | select(.tab_id == $t) | .pane_id) // empty' <<<"$pl")"
  [ -n "$any" ] || { echo '[]'; return 0; }
  lay="$(hj pane layout --pane "$any")" || return 1
  jq -n --argjson P "$pl" --argjson L "$lay" '
    ($L.result.layout.panes) as $r | ([$r[].rect.x] | unique) as $xs
    | [ $r[] | . as $q | ($P.result.panes[] | select(.pane_id == $q.pane_id)) as $p
        | {pane: $q.pane_id, col: ($xs | index($q.rect.x)), y: $q.rect.y,
           label: ($p.label // ""), agent: ($p.agent // ""), status: ($p.agent_status // "")} ]
    | sort_by(.col, .y)'
}

# seat_slots <n> <slots-json>: the seat panes of a tab. Tab 1 has the architect in column 0, which is never a seat slot.
seat_slots() { jq -c --argjson n "$1" 'if $n == 1 then map(select(.col >= 1)) else . end' <<<"$2"; }

# ---- building the skeleton ------------------------------------------------------------------------------------
# new_pane <tab> <parent> <dir> <keep> <supply-pane|''>: make the pane that sits right of / below <parent> and print its
# id. With a supply pane (migration) the existing pane is moved there, so its process is never restarted; otherwise a
# shell is split off and labelled free. <keep> is the share the parent keeps, verified against herdr 2026-10-16.
new_pane() {
  local tab="$1" parent="$2" dir="$3" keep="$4" supply="$5" j
  if [ -n "$supply" ]; then
    j="$(hj pane move "$supply" --tab "$tab" --split "$dir" --target-pane "$parent" --ratio "$keep" --no-focus)" || return 1
    jq -r '.result.move_result.pane.pane_id // "<new>"' <<<"$j"
  else
    j="$(hj pane split "$parent" --direction "$dir" --ratio "$keep" --cwd "${CWD:-$PWD}" --no-focus)" || return 1
    local p; p="$(jq -r '.result.pane.pane_id' <<<"$j")"
    hj pane rename "$p" "$FREE" >/dev/null || return 1
    printf '%s\n' "$p"
  fi
}

# grid_build <tab> <root-pane> <has-architect> [supply-pane...]
# root is the architect (tab 1) or seat slot 0 (overflow). supply[i] is moved into seat slot i, if given.
grid_build() {
  local tab="$1" root="$2" arch="$3"; shift 3
  local -a supply=("$@") cols=("$root") seatcols=()
  local c keep first_seat=0 idx
  [ "$arch" = 1 ] && first_seat=1
  for c in 1 2; do # columns 1 and 2 are new; column 0 is the root
    keep="$(awk -v k=$((3 - c + 1)) 'BEGIN{printf "%.4f", 1/k}')"
    idx=$(( (c - first_seat) * ROWS ))
    cols[c]="$(new_pane "$tab" "${cols[c-1]}" right "$keep" "${supply[idx]:-}")" || return 1
  done
  for ((c = first_seat; c < 3; c++)); do seatcols+=("${cols[c]}"); done
  local r prev
  for ((c = 0; c < ${#seatcols[@]}; c++)); do
    prev="${seatcols[c]}"
    for ((r = 1; r < ROWS; r++)); do # row r keeps 1/(ROWS-r+1) of what is left, so every row ends up equal
      prev="$(new_pane "$tab" "$prev" down "$(keep_of $((ROWS - r + 1)))" "${supply[c*ROWS+r]:-}")" || return 1
    done
  done
}

# ---- commands ----------------------------------------------------------------------------------------------
cmd_line_up() {
  local line="$1" r tab root
  if [ -n "$(line_tabs "$line" | head -1)" ]; then log "line $line already has tab(s); nothing to do"; return 0; fi
  r="$(hj tab create --workspace "$WS" --cwd "${CWD:-$PWD}" --label "$line 1" --no-focus)" || return 1
  tab="$(jq -r '.result.tab.tab_id' <<<"$r")"; root="$(jq -r '.result.root_pane.pane_id' <<<"$r")"
  hj pane rename "$root" architect >/dev/null || return 1
  grid_build "$tab" "$root" 1 || return 1
  log "line $line up: tab $tab, architect $root"
}

# open_overflow <line> <n> [supply-pane...]: tab "<line> N" with 9 seat slots; prints the tab id.
open_overflow() {
  local line="$1" n="$2" r tab root; shift 2
  if [ "$#" -gt 0 ]; then
    # The first migrated pane becomes the tab's root, so no spare shell is created and nothing is restarted.
    r="$(hj pane move "$1" --new-tab --workspace "$WS" --label "$line $n" --no-focus)" || return 1
    root="$(jq -r '.result.move_result.pane.pane_id // "<new>"' <<<"$r")"
    tab="$(jq -r '.result.move_result.pane.tab_id // "<new-tab>"' <<<"$r")"; shift
    grid_build "$tab" "$root" 0 "" "$@" || return 1
  else
    r="$(hj tab create --workspace "$WS" --cwd "${CWD:-$PWD}" --label "$line $n" --no-focus)" || return 1
    tab="$(jq -r '.result.tab.tab_id' <<<"$r")"; root="$(jq -r '.result.root_pane.pane_id' <<<"$r")"
    hj pane rename "$root" "$FREE" >/dev/null || return 1
    grid_build "$tab" "$root" 0 || return 1
  fi
  printf '%s\n' "$tab"
}

# find_free <line>: prints "<tab> <pane>" of the first free slot in tab order then slot order, else nothing.
find_free() {
  local n tab slots
  while read -r n tab; do
    [ -n "$n" ] || continue
    slots="$(seat_slots "$n" "$(tab_slots "$tab")")" || return 1
    jq -r --arg t "$tab" --arg f "$FREE" 'first(.[] | select(.label == $f) | "\($t) \(.pane)") // empty' <<<"$slots"
  done < <(line_tabs "$1") | head -1
}

# find_seat <seat> [line]: prints "<n> <tab> <pane> <line>" of the pane labelled <seat>, if any.
find_seat() {
  local seat="$1" line="${2:-}" tabs n tab lbl s
  tabs="$(hj tab list --workspace "$WS")" || return 1
  while IFS=$'\t' read -r tab lbl; do
    [[ "$lbl" =~ ^(.+)\ ([0-9]+)$ ]] || continue
    [ -z "$line" ] || [ "${BASH_REMATCH[1]}" = "$line" ] || continue
    n="${BASH_REMATCH[2]}"
    s="$(seat_slots "$n" "$(tab_slots "$tab")")"
    jq -r --arg s "$seat" --arg n "$n" --arg t "$tab" --arg l "${BASH_REMATCH[1]}" \
      'first(.[] | select(.label == $s) | "\($n) \($t) \(.pane) \($l)") // empty' <<<"$s"
  done < <(jq -r '.result.tabs[] | [.tab_id, .label] | @tsv' <<<"$tabs") | head -1
}

cmd_claim() { # claim <line> <seat> [cmd]; prints the pane id
  local line="$1" seat="$2" slot tab pane n
  [[ "$seat" =~ ^[a-z][a-z0-9_-]{0,31}$ ]] || wf_die "seat '$seat' is not a valid herdr agent name"
  [ -z "$(find_seat "$seat" "$line")" ] || wf_die "seat '$seat' already holds a slot on line $line"
  slot="$(find_free "$line")" || return 1
  if [ -z "$slot" ]; then
    n=$(( $(line_tabs "$line" | tail -1 | cut -d' ' -f1) + 1 ))
    [ "$n" -ge 2 ] || wf_die "line $line has no tab yet: run line-up first"
    tab="$(open_overflow "$line" "$n")" || return 1
    log "line $line is full: opened tab $line $n"
    slot="$tab $(jq -r 'first(.[]|select(.label=="'"$FREE"'")|.pane)' <<<"$(tab_slots "$tab")")"
  fi
  pane="${slot#* }"
  hj pane rename "$pane" "$seat" >/dev/null || return 1
  printf '%s\n' "$pane"
}

cmd_seat_up() {
  local line="$1" seat="$2" cmd="${3:-}" pane
  pane="$(cmd_claim "$line" "$seat")" || return 1
  if [ -n "$cmd" ]; then
    hj pane run "$pane" "$cmd" >/dev/null || return 1
    hj agent wait "$pane" --until idle --timeout "$START_TIMEOUT_MS" >/dev/null || { log "seat $seat: agent never reached idle in $pane"; return 1; }
    # An agent already holding the name is not displaced (herdr answers agent_name_taken); report and keep the label.
    hj agent rename "$pane" "$seat" >/dev/null || return 1
    mkdir -p "$STATE/$line" && date -u +%Y-%m-%dT%H:%M:%SZ > "$(state_file "$line" "$seat")"
  fi
  printf 'seat %s: %s (line %s)\n' "$seat" "$pane" "$line"
}

# finished <line> <seat> <pane> <agent>: 0 when the seat printed its DONE token, or its agent exited after being seen.
# The token needs a non-placeholder word after the seat name, so a brief that quotes "DONE <seat> <pr-url>" in the pane
# does not count as the seat being done.
finished() {
  local line="$1" seat="$2" pane="$3" agent="$4"
  if hj pane read "$pane" --source recent-unwrapped --lines 40 2>/dev/null | grep -Eq "(^|[[:space:]])DONE ${seat} [^< ]"; then return 0; fi
  [ -z "$agent" ] && [ -f "$(state_file "$line" "$seat")" ]
}

# reflow <tab> <n>: after a close, put every seat column back to 3 panes and move seats up so free slots trail.
# A column that vanished entirely is not rebuilt; the next seat-up opens a new tab instead. That is the stated cost.
reflow() {
  local tab="$1" n="$2" slots cols panes last i j
  slots="$(tab_slots "$tab")" || return 1
  cols="$(jq -r --argjson n "$n" '[.[] | select($n != 1 or .col >= 1)] | group_by(.col)[] | "\(length) \(.[-1].pane)"' <<<"$slots")"
  while read -r cnt last; do
    [ -n "$cnt" ] || continue
    for ((i = cnt; i < ROWS; i++)); do last="$(new_pane "$tab" "$last" down 0.5 "")" || return 1; done
  done <<<"$cols"
  slots="$(seat_slots "$n" "$(tab_slots "$tab")")" || return 1
  local -a lbl; mapfile -t panes < <(jq -r '.[].pane' <<<"$slots")
  mapfile -t lbl < <(jq -r '.[].label' <<<"$slots")
  for ((i = 0; i < ${#panes[@]}; i++)); do
    [ "${lbl[i]}" = "$FREE" ] || continue
    for ((j = i + 1; j < ${#panes[@]}; j++)); do
      [ "${lbl[j]}" != "$FREE" ] || continue
      hj pane swap --source-pane "${panes[i]}" --target-pane "${panes[j]}" >/dev/null || return 1
      lbl[i]="${lbl[j]}"; lbl[j]="$FREE"; break
    done
  done
}

# close_if_empty <tab> <n>: an overflow tab with only free slots is closed. Tab 1 and the architect are never closed.
close_if_empty() {
  local tab="$1" n="$2" slots
  [ "$n" -ge 2 ] || return 0
  slots="$(tab_slots "$tab")" || return 1
  if jq -e --arg f "$FREE" 'all(.[]; .label == $f)' <<<"$slots" >/dev/null; then
    hj tab close "$tab" >/dev/null && log "closed empty overflow tab $tab"
  fi
}

cmd_seat_down() {
  local seat="$1" line="${2:-}" hit n tab pane l agent
  hit="$(find_seat "$seat" "$line")"
  [ -n "$hit" ] || wf_die "no seat '$seat' holds a slot${line:+ on line $line}; the architect pane and panes outside a line are never closed"
  read -r n tab pane l <<<"$hit"
  agent="$(tab_slots "$tab" | jq -r --arg p "$pane" '.[] | select(.pane == $p) | .agent')"
  if [ "${FORCE:-0}" != 1 ] && ! finished "$l" "$seat" "$pane" "$agent"; then
    log "refused-unfinished: seat $seat has neither printed DONE nor exited (FORCE=1 overrides)"; return 2
  fi
  hj pane close "$pane" >/dev/null || return 1
  rm -f "$(state_file "$l" "$seat")"
  reflow "$tab" "$n" && close_if_empty "$tab" "$n"
  log "seat $seat down"
}

cmd_line_clean() {
  local line="$1" n tab slots seat pane agent rc=0
  while read -r n tab; do
    [ -n "$n" ] || continue
    slots="$(seat_slots "$n" "$(tab_slots "$tab")")"
    while IFS=$'\t' read -r seat pane agent; do
      [ -n "$seat" ] && [ "$seat" != "$FREE" ] || continue
      finished "$line" "$seat" "$pane" "$agent" && { FORCE=1 cmd_seat_down "$seat" "$line" || rc=1; }
    done < <(jq -r '.[] | [.label, .pane, .agent] | @tsv' <<<"$slots")
  done < <(line_tabs "$line")
  # An overflow tab that was already empty (a seat closed by hand) is swept too.
  while read -r n tab; do [ -n "$n" ] && close_if_empty "$tab" "$n"; done < <(line_tabs "$line")
  return "$rc"
}

cmd_line_status() {
  local line="$1" n tab slots
  printf '%-18s %-5s %-24s %-10s %s\n' TAB SLOT SEAT AGENT STATUS
  while read -r n tab; do
    [ -n "$n" ] || continue
    tab_slots "$tab" | jq -r --arg l "$line $n" --argjson n "$n" '
      . as $all | [ $all[] | select($n != 1 or .col >= 1) ] as $s
      | ( $all[] | select($n == 1 and .col == 0) | [$l, "A", (.label|if .=="" then "-" else . end), (.agent|if .=="" then "-" else . end), (.status|if .=="" then "-" else . end)] ),
        ( $s | to_entries[] | [$l, "\(.key + 1)", .value.label, (.value.agent|if .=="" then "-" else . end), (.value.status|if .=="" then "-" else . end)] )
      | @tsv' | while IFS=$'\t' read -r a b c d e; do printf '%-18s %-5s %-24s %-10s %s\n' "$a" "$b" "${c:--}" "$d" "$e"; done
  done < <(line_tabs "$line")
}

# line-adopt: put a live line into the grid. Panes are moved, never killed, so no process restarts (same workspace keeps
# pane ids). Panes in the architect's tab that are not named are parked in a tab "<line> stash" for the owner to see.
cmd_line_adopt() {
  local line="$1" arch="$2"; shift 2
  local -a names panes; local s tab pl others o n=2
  for s in "$@"; do names+=("${s%%=*}"); panes+=("${s#*=}"); done
  pl="$(hj pane list --workspace "$WS")" || return 1
  tab="$(jq -r --arg p "$arch" '.result.panes[] | select(.pane_id == $p) | .tab_id' <<<"$pl")"
  [ -n "$tab" ] || wf_die "architect pane $arch not found in workspace $WS"
  # stage every other pane of the architect's tab out, so the tab holds the architect alone
  others="$(jq -r --arg t "$tab" --arg a "$arch" '.result.panes[] | select(.tab_id == $t and .pane_id != $a) | .pane_id' <<<"$pl")"
  local stash=""
  for o in $others; do
    if [ -z "$stash" ]; then
      stash="$(hj pane move "$o" --new-tab --workspace "$WS" --label "$line stash" --no-focus | jq -r '.result.move_result.pane.tab_id')" || return 1
    else
      hj pane move "$o" --tab "$stash" --split right --no-focus >/dev/null || return 1
    fi
  done
  hj tab rename "$tab" "$line 1" >/dev/null || return 1
  hj pane rename "$arch" architect >/dev/null || return 1
  grid_build "$tab" "$arch" 1 "${panes[@]:0:6}" || return 1
  # overflow seats beyond the first 6 go to tab 2, 3, ... of 9 each
  local i=6
  while [ "$i" -lt "${#panes[@]}" ]; do
    open_overflow "$line" "$n" "${panes[@]:i:9}" >/dev/null || return 1
    i=$((i + 9)); n=$((n + 1))
  done
  # parked panes are also the stash's only residents once the named seats have left it
  for ((i = 0; i < ${#panes[@]}; i++)); do
    hj pane rename "${panes[i]}" "${names[i]}" >/dev/null || return 1
    hj agent rename "${panes[i]}" "${names[i]}" >/dev/null 2>&1 || log "agent in ${panes[i]} keeps its name (rename refused or no agent)"
  done
  log "line $line adopted: $arch architect, ${#panes[@]} seats"
}

main() {
  local c="${1:-}"; shift || true
  case "$c" in
    line-up)     [ $# -ge 1 ] || wf_die "usage: line-up <line>";  cmd_line_up "$@" ;;
    seat-up)     [ $# -ge 2 ] || wf_die "usage: seat-up <line> <seat> [cmd]"; cmd_seat_up "$@" ;;
    claim)       [ $# -ge 2 ] || wf_die "usage: claim <line> <seat>"; cmd_claim "$@" ;;
    seat-down)   [ $# -ge 1 ] || wf_die "usage: seat-down <seat> [line]"; cmd_seat_down "$@" ;;
    line-clean)  [ $# -ge 1 ] || wf_die "usage: line-clean <line>"; cmd_line_clean "$@" ;;
    line-status) [ $# -ge 1 ] || wf_die "usage: line-status <line>"; cmd_line_status "$@" ;;
    line-adopt)  [ $# -ge 2 ] || wf_die "usage: line-adopt <line> <arch-pane> <seat=pane>..."; cmd_line_adopt "$@" ;;
    *) sed -n '2,19p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//' >&2; return 2 ;;
  esac
}
main "$@"
