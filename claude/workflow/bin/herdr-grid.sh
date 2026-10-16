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
#   seat-down  <seat> [line]                close a finished seat's pane and its watchers, reflow, close an emptied overflow tab;
#                                           a seat holding no slot is found by herdr agent name or label, and a seat already gone is exit 0
#   seat-adopt <line> <seat> <pane>         move a named pane from outside the grid into the next free slot, no restart
#   adopt-named <line>                      seat-adopt every named agent pane of the workspace that no line grid holds
#   line-clean <line>                       seat-down for every finished seat of the line
#   line-status <line>                      one table: tab, slot, seat, agent, status. No model calls
#   architect-up <line> [resume]           (re)start the architect in its pane with both flags; resume adds --continue
#   line-reconcile <line>                  repair a line: unique numbered tabs, stash emptied, seats packed, no restarts
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
# shellcheck source=bin/workflow-lib.sh disable=SC1091
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
# Owner, 2026-10-16 UTC: "make sure your seat always has bypass permissions on and that you always have /rc on too, i need
# to interface with you away from desk". The architect starts with both flags, named for the line, so the Claude app shows
# one session per line. Remote Control is the architect's alone; seats get bypass only. {line} is replaced by the line name.
# The default is a variable of its own: its closing {line} brace would end a ${VAR:-default} expansion early.
ARCH_DEFAULT='claude --dangerously-skip-permissions --remote-control "{line} architect"'
ARCH_CMD="${ARCH_CMD:-$(gcfg architect_cmd)}"; ARCH_CMD="${ARCH_CMD:-$ARCH_DEFAULT}"
SKIP_FLAG="--dangerously-skip-permissions"
START_TIMEOUT_MS="${START_TIMEOUT_MS:-$(gcfg start_timeout_ms)}"; START_TIMEOUT_MS="${START_TIMEOUT_MS:-60000}"
SEAT_TMP_ROOT="$(wf_expand "${GRID_SEAT_TMP:-$(gcfg seat_tmp_dir)}")"; [ -n "$SEAT_TMP_ROOT" ] || SEAT_TMP_ROOT="$HOME/.cache/zenith/seat-tmp"
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

# Breadcrumb 2026-10-16 (WO-20261016-a36a, ORD-1150 T1): seats started by seat-up inherited the pane's TMPDIR, usually none, so
# every seat on the line shared /tmp (mktemp, work-order.sh code_tree, podman builds, pytest), collided on names and left files
# no seat owned, so cleanup after a finished seat could not find them. Each seat now gets <seat_tmp_dir>/<line>/<seat>, exported
# by seat-up and removed by seat-down. Done in seat-up because it is the one start path (herdr-bus.mk calls it too); per-seat
# env files were rejected since a seat started by herdr-bus.mk would miss them. Cost: one mkdir per seat start; a Windows
# claude.exe seat ignores a Linux TMPDIR, which is harmless.
seat_tmp() { printf '%s/%s/%s' "$SEAT_TMP_ROOT" "$1" "$2"; }

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
  start_architect "$line" "$root" || return 1
  log "line $line up: tab $tab, architect $root"
}

# start_architect <line> <pane> [resume]: runs ARCH_CMD in the architect pane. Every start path goes through here, so a
# restart or resume cannot come back without both flags. Resume appends --continue (claude's own flag).
start_architect() {
  local line="$1" pane="$2" resume="${3:-}" cmd
  cmd="${ARCH_CMD//\{line\}/$line}"
  [ -z "$resume" ] || cmd="$cmd --continue"
  hj pane run "$pane" "$cmd" >/dev/null || return 1
}

cmd_architect_up() {
  local line="$1" resume="${2:-}" hit tab
  tab="$(line_tabs "$line" | head -1 | cut -d' ' -f2)"
  [ -n "$tab" ] || wf_die "line $line has no tab; run line-up first"
  hit="$(tab_slots "$tab" | jq -r 'first(.[] | select(.label == "architect") | "\(.pane) \(.agent)") // empty')"
  [ -n "$hit" ] || wf_die "no architect pane in $tab"
  [ -z "${hit#* }" ] || wf_die "architect already runs an agent in ${hit%% *}; refusing to start a second"
  start_architect "$line" "${hit%% *}" "$resume"
}

# seat_cmd <cmd>: a seat that starts claude always carries bypass permissions, and never Remote Control (architect only).
seat_cmd() {
  local cmd="$1"
  case "$cmd" in *--remote-control*) log "seats never get --remote-control; it is the architect's alone"; return 1 ;; esac
  case "$cmd" in *"$SKIP_FLAG"*) ;; *)
    # first claude / claude.exe word, with or without a path or a leading "cd x &&" (the Windows browser seat has one)
    cmd="$(sed -E "s#(^|[ /;&])(claude(\.exe)?)( |\$)#\1\2 $SKIP_FLAG\4#" <<<"$cmd")" ;;
  esac
  printf '%s' "$cmd"
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
# BREADCRUMB: this ran as `while ...; done < <(line_tabs) | head -1`. With pipefail the loop got SIGPIPE when head quit
#   after the first hit but the loop went on to query the next tab, so find_free exited 1 AFTER printing the right slot and
#   cmd_claim returned 1 with no pane (seat-up exit 1 at Makefile:57, reported 2026-10-16T04:33Z; the hit was
#   "wD9:t1 wD9:p2R"). Fix: return at the first hit, no pipe to head. Rejected: dropping pipefail, which hides real failures.
find_free() {
  local n tab slots hit
  while read -r n tab; do
    [ -n "$n" ] || continue
    slots="$(seat_slots "$n" "$(tab_slots "$tab")")" || return 1
    hit="$(jq -r --arg t "$tab" --arg f "$FREE" 'first(.[] | select(.label == $f) | "\($t) \(.pane)") // empty' <<<"$slots")"
    if [ -n "$hit" ]; then printf '%s\n' "$hit"; return 0; fi
  done < <(line_tabs "$1")
}

# find_seat <seat> [line]: prints "<n> <tab> <pane> <line>" of the pane labelled <seat>, if any. Returns at the first hit.
find_seat() {
  local seat="$1" line="${2:-}" tabs n tab lbl s hit
  tabs="$(hj tab list --workspace "$WS")" || return 1
  while IFS=$'\t' read -r tab lbl; do
    [[ "$lbl" =~ ^(.+)\ ([0-9]+)$ ]] || continue
    [ -z "$line" ] || [ "${BASH_REMATCH[1]}" = "$line" ] || continue
    n="${BASH_REMATCH[2]}"
    s="$(seat_slots "$n" "$(tab_slots "$tab")")"
    hit="$(jq -r --arg s "$seat" --arg n "$n" --arg t "$tab" --arg l "${BASH_REMATCH[1]}" \
      'first(.[] | select(.label == $s) | "\($n) \($t) \(.pane) \($l)") // empty' <<<"$s")"
    if [ -n "$hit" ]; then printf '%s\n' "$hit"; return 0; fi
  done < <(jq -r '.result.tabs[] | [.tab_id, .label] | @tsv' <<<"$tabs")
}

# free_slot <line>: prints "<tab> <pane>" of the first free slot, opening the next overflow tab when the line is full.
free_slot() {
  local line="$1" slot tab n
  slot="$(find_free "$line")" || return 1
  if [ -z "$slot" ]; then
    n=$(( $(line_tabs "$line" | tail -1 | cut -d' ' -f1) + 1 ))
    [ "$n" -ge 2 ] || wf_die "line $line has no tab yet: run line-up first"
    tab="$(open_overflow "$line" "$n")" || return 1
    log "line $line is full: opened tab $line $n"
    slot="$tab $(jq -r 'first(.[]|select(.label=="'"$FREE"'")|.pane)' <<<"$(tab_slots "$tab")")"
  fi
  printf '%s\n' "$slot"
}

cmd_claim() { # claim <line> <seat> [cmd]; prints the pane id
  local line="$1" seat="$2" slot pane
  [[ "$seat" =~ ^[a-z][a-z0-9_-]{0,31}$ ]] || wf_die "seat '$seat' is not a valid herdr agent name"
  [ -z "$(find_seat "$seat" "$line")" ] || wf_die "seat '$seat' already holds a slot on line $line"
  slot="$(free_slot "$line")" || return 1
  pane="${slot#* }"
  hj pane rename "$pane" "$seat" >/dev/null || return 1
  printf '%s\n' "$pane"
}

cmd_seat_up() {
  local line="$1" seat="$2" cmd="${3:-}" pane
  # Breadcrumb ORD-0548 O4 (WO-20261016-ec34): a build seat starts only on a brief that names a ready work order.
  # The check runs before the claim so a refused seat holds no slot and no pane is renamed.
  # Rejected: checking after the start, because the seat would already be running and inventing. Cost: one make call per BUILD=1 seat-up.
  if [ "${BUILD:-}" = 1 ]; then
    [ -n "${BRIEF:-}" ] || { printf 'DESIGN-GAP seat %s: BUILD=1 needs BRIEF=\n' "$seat"; return 3; }
    make -s -C "$HERE/.." -f a2a.mk brief-check FILE="$BRIEF" BUILD=1 >&2 || { printf 'DESIGN-GAP seat %s not started\n' "$seat"; return 3; }
  fi
  [ -z "$cmd" ] || cmd="$(seat_cmd "$cmd")" || return 1
  if [ -n "$cmd" ]; then
    local tmp; tmp="$(seat_tmp "$line" "$seat")"
    mkdir -p "$tmp" || { log "seat $seat: cannot create TMPDIR $tmp"; return 1; }
    cmd="export TMPDIR=$(printf %q "$tmp") && $cmd"
  fi
  pane="$(cmd_claim "$line" "$seat")" || return 1
  if [ -n "$cmd" ]; then
    hj pane run "$pane" "$cmd" >/dev/null || return 1
    # Breadcrumb 2026-10-16T05:42Z: `make seat-up` exited 1 at claude/workflow/Makefile:63 for seat stuck-watch-2 while the seat ran fine.
    # A seat whose CMD carries its prompt is working at once, so waiting for idle alone timed out after 60 s and returned
    # before the agent rename and the agent-seen stamp. Any detected state proves the agent started, so wait on idle or working.
    # Rejected: a longer timeout, which still fails on a long first turn. Cost: none.
    hj agent wait "$pane" --until idle --until working --timeout "$START_TIMEOUT_MS" >/dev/null || { log "seat $seat: agent never reached idle in $pane"; return 1; }
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

# close_watchers <pane>: the seat's compact and seat watchers stop and their panes close in the same call as the seat's.
# BREADCRUMB - a watcher outlived its seat (2026-10-16T05:32Z): 9 orphan watch-compact panes sat in monitor slots 2.1/2.2
#   and the resources and events monitors were refused ("slot is not free"). seat-down closed the seat and left the
#   watchers watch-ctl.sh armed. Fix: seat-down calls watch-ctl off --close for both kinds; the sweep reaps any that
#   still slip through (line-watch.sh reap_watchers). Rejected: leaving it to the sweep alone, which is up to a minute late.
close_watchers() {
  local k
  [ "$DRY" = 1 ] && return 0
  for k in compact seat; do WATCH_WS="$WS" bash "$HERE/watch-ctl.sh" off "$k" "$1" --close >/dev/null 2>&1 || true; done
}

# unreg_pane <seat>: "<tab> <pane> <agent>" of a pane of the workspace that is not the architect and whose label or herdr
# agent name is <seat>, wherever it sits. Empty when no pane answers to the name.
unreg_pane() {
  local pl ag
  pl="$(hj pane list --workspace "$WS")" || return 1
  ag="$(hj agent list 2>/dev/null | jq -c '[(.result.agents // [])[] | {(.pane_id): .name}] | add // {}' 2>/dev/null)"; [ -n "$ag" ] || ag='{}'
  jq -r --arg s "$1" --argjson ag "$ag" 'first(.result.panes[]
    | select((.label // "") != "architect" and ((.label // "") == $s or ($ag[.pane_id] // "") == $s))
    | "\(.tab_id) \(.pane_id) \(.agent // "")") // empty' <<<"$pl"
}

# BREADCRUMB - seat-down of a seat that holds no slot is adoption, never exit 1.
# What broke: 05:28Z `make seat-down SEAT=treehouse-seats` died "no seat holds a slot" (Makefile:65 Error 1) because the
#   seat was spawned outside seat-up, so no pane carried its label in a grid tab; the orchestrator had to close it by hand.
# Why this fix: the seat is found by herdr agent name or pane label anywhere in the workspace, held to the same finished
#   test, closed, and its tab reflowed when it sat in a grid tab. A name nothing answers to means the seat is already
#   down, which is exit 0, so a redelivered LW-DONE and a re-run both land in the same end state (item 28).
#   Rejected: failing so the caller adopts first, which is the hand step this removes. The architect pane is still refused.
down_unregistered() {
  local seat="$1" line="${2:-}" hit tab pane agent lbl n l
  [ "$seat" != architect ] || wf_die "no seat '$seat' holds a slot${line:+ on line $line}; the architect pane and panes outside a line are never closed"
  hit="$(unreg_pane "$seat")" || return 1
  if [ -z "$hit" ]; then log "seat $seat holds no pane; already down"; return 0; fi
  read -r tab pane agent <<<"$hit"
  if [ "${FORCE:-0}" != 1 ] && ! finished "${line:-_}" "$seat" "$pane" "$agent"; then
    log "refused-unfinished: seat $seat has neither printed DONE nor exited (FORCE=1 overrides)"; return 2
  fi
  log "seat $seat held no slot: found by name in $pane"
  hj pane close "$pane" >/dev/null || return 1
  close_watchers "$pane"
  rm -f "$(state_file "${line:-_}" "$seat")"
  lbl="$(hj tab list --workspace "$WS" | jq -r --arg t "$tab" 'first(.result.tabs[] | select(.tab_id == $t) | .label) // empty')"
  if [[ "$lbl" =~ ^(.+)\ ([0-9]+)$ ]] && { [ -z "$line" ] || [ "${BASH_REMATCH[1]}" = "$line" ]; }; then
    n="${BASH_REMATCH[2]}"; reflow "$tab" "$n" && close_if_empty "$tab" "$n"
  fi
  log "seat $seat down"
}

cmd_seat_down() {
  local seat="$1" line="${2:-}" hit n tab pane l agent rc=0
  hit="$(find_seat "$seat" "$line")"
  if [ -z "$hit" ]; then down_unregistered "$seat" "$line"; return; fi
  read -r n tab pane l <<<"$hit"
  agent="$(tab_slots "$tab" | jq -r --arg p "$pane" '.[] | select(.pane == $p) | .agent')"
  if [ "${FORCE:-0}" != 1 ] && ! finished "$l" "$seat" "$pane" "$agent"; then
    log "refused-unfinished: seat $seat has neither printed DONE nor exited (FORCE=1 overrides)"; return 2
  fi
  hj pane close "$pane" >/dev/null || return 1
  close_watchers "$pane"
  rm -f "$(state_file "$l" "$seat")"
  rm -rf "$(seat_tmp "$l" "$seat")"
  return_slot "$seat" || rc=1
  reflow "$tab" "$n" && close_if_empty "$tab" "$n"
  log "seat $seat down"
  return "$rc"
}

# return_slot <seat>: gives back the treehouse slot workflow-spawn.sh leased to <seat>, if it holds one.
# BREADCRUMB 2026-10-16 (brief BR-20261016-treehouse-seats): seats now lease their worktree from the treehouse pool
#   (bin/workflow-spawn.sh, the worktree block), and nothing gave a slot back, so the pool would fill with leased slots
#   (coq line/bin/merge.sh return_slot fixed the same leak there). Why this fix: the pane is closed first, so no seat
#   process is left in the slot, and the return is pinned to the holder with --if-lease-holder, so a slot leased to
#   anyone else is never touched. --force is NOT passed: v3 then refuses a slot with uncommitted work rather than wiping
#   it (dev gate C6: a clean slot returns with stdin closed), and the refusal is reported, leaving the lease for a human.
#   Rejected: coq's --force, which ends every process in the slot and discards uncommitted work. Cost: a dirty slot
#   stays leased until someone commits or discards that work and reruns seat-down.
return_slot() {
  local seat="$1" root st path
  command -v treehouse >/dev/null 2>&1 || return 0
  root="$(git -C "$WF_REPO" rev-parse --show-toplevel 2>/dev/null)" || return 0
  st="$(cd "$root" && treehouse status --json 2>/dev/null)" || { log "treehouse status failed; slot of $seat unchecked"; return 1; }
  path="$(jq -r --arg h "$seat" '[.[]? | select(.lease_holder == $h)] | last | .path // empty' <<<"$st")"
  [ -n "$path" ] || return 0
  if [ "$DRY" = 1 ]; then printf 'DRY: treehouse return %s --if-lease-holder %s\n' "$path" "$seat" >&2; return 0; fi
  if treehouse return "$path" --if-lease-holder "$seat" </dev/null >/dev/null 2>&1; then log "slot $path returned by $seat"; return 0; fi
  log "slot $path leased to $seat would not return (uncommitted work?); left leased"; return 1
}

# seat-adopt <line> <seat> <pane>: a named pane outside the grid takes the next free slot. The pane is moved onto the free
# slot's place and the free shell closed, so the process in it never restarts. Idempotent: a seat already in a slot is left.
cmd_seat_adopt() {
  local line="$1" seat="$2" pane="$3" slot tab free
  [[ "$seat" =~ ^[a-z][a-z0-9_-]{0,31}$ ]] || { log "skip $pane: '$seat' is not a valid seat name"; return 0; }
  if [ -n "$(find_seat "$seat" "$line")" ]; then log "seat $seat already holds a slot on line $line"; return 0; fi
  slot="$(free_slot "$line")" || return 1
  tab="${slot% *}"; free="${slot#* }"
  hj pane move "$pane" --tab "$tab" --split down --target-pane "$free" --ratio 0.5 --no-focus >/dev/null || return 1
  hj pane close "$free" >/dev/null || return 1
  hj pane rename "$pane" "$seat" >/dev/null || return 1
  hj agent rename "$pane" "$seat" >/dev/null 2>&1 || log "agent in $pane keeps its name (rename refused or no agent)"
  log "adopted $seat from $pane into line $line"
}

# adopt-named <line>: every pane of the workspace that runs an agent and has a name (herdr agent name, else label), sits in
# no grid tab ("<x> N"), monitor tab or watchers tab, and is not the architect or a watcher, becomes a seat of the line.
# The sweep runs this every minute (line-watch.sh), so a seat started outside seat-up is in the grid within one tick.
cmd_adopt_named() {
  local line="$1" pl tl ag pane name rc=0
  pl="$(hj pane list --workspace "$WS")" || return 1
  tl="$(hj tab list --workspace "$WS")" || return 1
  ag="$(hj agent list 2>/dev/null | jq -c '[(.result.agents // [])[] | {(.pane_id): .name}] | add // {}' 2>/dev/null)"; [ -n "$ag" ] || ag='{}'
  while IFS=$'\t' read -r pane name; do
    [ -n "$pane" ] || continue
    cmd_seat_adopt "$line" "$name" "$pane" || rc=1
  done < <(jq -r --argjson T "$tl" --argjson ag "$ag" --arg f "$FREE" '
    [$T.result.tabs[] | select((.label // "") | test(" [0-9]+$|^monitors$| (monitor|watchers)( [0-9]+)?$")) | .tab_id] as $skip
    | .result.panes[] | select(.agent != null and (.tab_id as $t | $skip | index($t) | not))
    | (if ($ag[.pane_id] // "") != "" then $ag[.pane_id] else (.label // "") end) as $n
    | select($n != "" and $n != "architect" and ($n | startswith($f) | not) and ($n | startswith("watch-") | not))
    | [.pane_id, $n] | @tsv' <<<"$pl")
  return "$rc"
}

cmd_line_clean() {
  local line="$1" n tab slots seat pane agent rc=0
  while read -r n tab; do
    [ -n "$n" ] || continue
    slots="$(seat_slots "$n" "$(tab_slots "$tab")")"
    while IFS=$'\t' read -r seat pane agent; do
      if [ -z "$seat" ] || [ "$seat" = "$FREE" ]; then continue; fi
      finished "$line" "$seat" "$pane" "$agent" && { FORCE=1 cmd_seat_down "$seat" "$line" || rc=1; }
    done < <(jq -r '.[] | [(.label | if . == "" then "-" else . end), .pane, .agent] | @tsv' <<<"$slots")
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

# line-reconcile: repair a line whose tabs were opened by hand (two tabs both labelled "<line> 2", a stash tab, panes with
# no label). Seats are only ever moved, never closed or restarted, so no process is interrupted (herdr agent list is the
# same before and after). Order kept: tab 1 first, then the other tabs in the order herdr lists them, slot by slot.
# What broke: 2026-10-16 the architect opened a second overflow tab by hand before seat-up existed, so line_tabs saw two
#   tabs numbered 2 and find_free/seat-down could pick either. Why this fix: old tabs are renamed out of the numbering
#   first, so the rebuilt tabs take clean numbers; a tab is closed only once it holds no agent.
cmd_line_reconcile() {
  local line="$1" t1 re tabs t seats=() names=() slots n i free1 p nm agents
  re="$(jq -rn --arg l "$line" '$l | gsub("[^A-Za-z0-9_-]"; "\\\(.)")')"
  t1="$(line_tabs "$line" | awk '$1 == 1 {print $2}')"
  [ -n "$t1" ] || wf_die "line $line has no tab 1; run line-up first"
  reflow "$t1" 1 || return 1
  agents="$(hj agent list | jq -c '[(.result.agents // [])[] | {(.pane_id): .name}] | add // {}')" || return 1
  tabs="$(hj tab list --workspace "$WS" | jq -r --arg r "^$re ([2-9]|[1-9][0-9]+|stash|old-.*)$" '.result.tabs[] | select(.label | test($r)) | .tab_id')"
  for t in $tabs; do
    # BREADCRUMB: an empty field between tabs is eaten by read (tab is whitespace in IFS), which shifted an unlabeled
    #   agent pane's agent into the label column and skipped it (live run 2026-10-16: dag-state, bottlenecks, artifacts,
    #   line-watch stayed behind). "-" stands for empty so every row has three fields.
    while IFS=$'\t' read -r p lbl ag; do
      [ "$ag" != "-" ] || continue
      [ "$lbl" != "-" ] || lbl=""
      nm="$lbl"; if [ -z "$nm" ] || [ "$nm" = "$FREE" ]; then nm="$(jq -r --arg p "$p" '.[$p] // empty' <<<"$agents")"; fi
      [ -n "$nm" ] || { log "pane $p has an agent but no name; leaving it where it is"; continue; }
      seats+=("$p"); names+=("$nm")
    done < <(tab_slots "$t" | jq -r '.[] | [.pane, (.label | if . == "" then "-" else . end), (.agent | if . == "" then "-" else . end)] | @tsv')
  done
  i=0; for t in $tabs; do hj tab rename "$t" "$line old-$i" >/dev/null || return 1; i=$((i + 1)); done
  # fill the free slots of tab 1 first, so a hole left by a finished seat is not wasted
  i=0
  while [ "$i" -lt "${#seats[@]}" ]; do
    free1="$(seat_slots 1 "$(tab_slots "$t1")" | jq -r --arg f "$FREE" 'first(.[] | select(.label == $f) | .pane) // empty')"
    [ -n "$free1" ] || break
    hj pane move "${seats[i]}" --tab "$t1" --split down --target-pane "$free1" --ratio 0.5 --no-focus >/dev/null || return 1
    hj pane close "$free1" >/dev/null || return 1
    i=$((i + 1))
  done
  n=2
  local rest=("${seats[@]:i}")
  while [ "${#rest[@]}" -gt 0 ]; do
    open_overflow "$line" "$n" "${rest[@]:0:9}" >/dev/null || return 1
    rest=("${rest[@]:9}"); n=$((n + 1))
  done
  for ((i = 0; i < ${#seats[@]}; i++)); do hj pane rename "${seats[i]}" "${names[i]}" >/dev/null || return 1; done
  # the old tabs now hold only free shells and unnamed non-agent panes; any that still holds an agent stays open
  for t in $tabs; do
    # herdr closes a tab itself when its last pane is moved out; closing it again would burn 3 retries on tab_not_found
    hj tab list --workspace "$WS" | jq -e --arg t "$t" '.result.tabs | any(.tab_id == $t)' >/dev/null || continue
    if tab_slots "$t" | jq -e 'all(.[]; .agent == "")' >/dev/null 2>&1; then hj tab close "$t" >/dev/null && log "closed old tab $t"
    else log "old tab $t still holds an agent; left open"; fi
  done
  reflow "$t1" 1
  log "line $line reconciled: ${#seats[@]} seats moved, none restarted"
}

main() {
  local c="${1:-}"; shift || true
  case "$c" in
    line-up)     [ $# -ge 1 ] || wf_die "usage: line-up <line>";  cmd_line_up "$@" ;;
    seat-up)     [ $# -ge 2 ] || wf_die "usage: seat-up <line> <seat> [cmd]"; cmd_seat_up "$@" ;;
    claim)       [ $# -ge 2 ] || wf_die "usage: claim <line> <seat>"; cmd_claim "$@" ;;
    seat-down)   [ $# -ge 1 ] || wf_die "usage: seat-down <seat> [line]"; cmd_seat_down "$@" ;;
    seat-adopt)  [ $# -ge 3 ] || wf_die "usage: seat-adopt <line> <seat> <pane>"; cmd_seat_adopt "$@" ;;
    adopt-named) [ $# -ge 1 ] || wf_die "usage: adopt-named <line>"; cmd_adopt_named "$@" ;;
    line-clean)  [ $# -ge 1 ] || wf_die "usage: line-clean <line>"; cmd_line_clean "$@" ;;
    line-status) [ $# -ge 1 ] || wf_die "usage: line-status <line>"; cmd_line_status "$@" ;;
    architect-up) [ $# -ge 1 ] || wf_die "usage: architect-up <line> [resume]"; cmd_architect_up "$@" ;;
    line-reconcile) [ $# -ge 1 ] || wf_die "usage: line-reconcile <line>"; cmd_line_reconcile "$@" ;;
    line-adopt)  [ $# -ge 2 ] || wf_die "usage: line-adopt <line> <arch-pane> <seat=pane>..."; cmd_line_adopt "$@" ;;
    *) sed -n '2,25p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//' >&2; return 2 ;;
  esac
}
main "$@"
