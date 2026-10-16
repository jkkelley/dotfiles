#!/usr/bin/env bash
# line-watch.sh - one line's monitoring, in labeled herdr panes of a "<line> monitor" tab, driven by Make.
#
# usage: line-watch.sh <cmd> <line> [--once]
#   up     <line>          open tab "<line> monitor", run the sweep in pane "<line>-sweep", then adopt
#   adopt  <line>          put every running seat of the line under the watchers, no restarts
#   sweep  <line> [--once] the loop itself; runs in the foreground of the sweep pane only (Rule 18)
#   off    <line>          stop the sweep and every watcher it armed, close the monitor tabs
#   status <line>          sweep pid, armed watchers, last three log lines
# env (Make passes VAR=value): WS (default $HERDR_WORKSPACE_ID), ARCH (architect pane; default the pane labelled
#   architect in tab "<line> 1"), LW_INTERVAL (60), LW_IDLE (60, seconds before an idle seat is an ALERT),
#   LW_STATE (~/.local/state/zenith/line-watch), ARTIFACT_ROOT (~/.local/state/zenith), LW_COMPACT (1: arm compact-watch)
#
# Owner, 2026-10-16 UTC: "what automation is doing the monitoring, because humans and agents suck and forget, it should
# be in herdr tab too within a herdr pane driven by makefiles and scripts". Every agent is checked every minute, and no
# agent sits idle for more than one minute (~/AGENTS.md).
#
# BREADCRUMB - why this exists and what it reuses.
# What broke: the inbox-triage line was watched by an untracked scratchpad watch.sh the architect ran as a harness
#   background job: invisible in herdr, gone with the session, and it exited after the first event (brief
#   BR-20261016-line-watch, honest_state).
# Why this fix: the sweep is that script's two checks (done token, dialog) plus idle, exit and context, run every minute
#   over every seat of the line, in a labeled pane. Per-seat watching is not rewritten: bin/watch-ctl.sh arms the
#   existing bin/compact-watch.sh for each seat, and bin/seat-watch.sh for seats bin/workflow-spawn.sh started. The done
#   token regex is bin/herdr-grid.sh finished(); the log contract is workflow-lib's (one line on change, ALERT prefix);
#   context percent is compaction-guard's own `ctx`. Rejected: a second seat watcher, and waking the architect on every
#   tick, which burns its tokens on quiet minutes.
# Cost: an adopted seat that bin/workflow-spawn.sh did not start has no seat-link, so seat-watch cannot hot swap it;
#   the sweep still reports it done, idle, blocked or exited.
set -uo pipefail
HERE="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
# shellcheck source=bin/workflow-lib.sh disable=SC1091
. "$HERE/workflow-lib.sh"
wf_need herdr; wf_need jq

cmd="${1:-}"; LINE="${2:-}"; ONCE=0; [ "${3:-}" = --once ] && ONCE=1
if [ -z "$cmd" ] || [ -z "$LINE" ]; then sed -n '4,12p' "$HERE/line-watch.sh" | sed 's/^# \{0,1\}//' >&2; exit 2; fi
WS="${WS:-${HERDR_WORKSPACE_ID:-}}"; [ -n "$WS" ] || wf_die "no workspace: run inside herdr or set WS="
INTERVAL="${LW_INTERVAL:-60}"; IDLE="${LW_IDLE:-60}"
SAFE="${LINE//[^A-Za-z0-9_-]/-}"
STATE="$(wf_expand "${LW_STATE:-$HOME/.local/state/zenith/line-watch}")/$SAFE"; mkdir -p "$STATE/seats"
TAB="$LINE monitor"
FREE=free
CG="${COMPACTION_GUARD_BIN:-compaction-guard}"

# ---- herdr discovery: ids are rediscovered every call, never stored (not stable across a herdr restart) ----------
panes() { herdr pane list --workspace "$WS" 2>/dev/null; }
tabs()  { herdr tab list --workspace "$WS" 2>/dev/null; }
pane_by_label() { panes | jq -r --arg l "$1" 'first(.result.panes[] | select(.label == $l) | .pane_id) // empty'; }

# seats: "<name>\t<pane>\t<agent>\t<status>" for every pane of the line's grid tabs ("<line> N") that is not the
# architect and not a free slot. An unlabelled pane holding an agent is a seat too, named by its pane id.
seats() {
  local re t p; t="$(tabs)"; p="$(panes)"
  [ -n "$t" ] && [ -n "$p" ] || return 1
  re="^$(printf '%s' "$LINE" | sed 's/[^A-Za-z0-9_-]/\\&/g') [0-9]+$"
  jq -rn --argjson T "$t" --argjson P "$p" --arg re "$re" --arg f "$FREE" '
    [$T.result.tabs[] | select((.label // "") | test($re)) | .tab_id] as $ids
    | $P.result.panes[] | select(.tab_id as $t | $ids | index($t))
    | select((.label // "") != "architect" and (.label // "") != $f)
    | select((.label // "") != "" or .agent != null)
    | [(.label // "" | if . == "" then null else . end) // (.pane_id | gsub(":"; "-")), .pane_id, (.agent // ""), (.agent_status // "")]
    | @tsv'
}

arch_pane() {
  [ -n "${ARCH:-}" ] && { printf '%s' "$ARCH"; return; }
  jq -rn --argjson T "$(tabs)" --argjson P "$(panes)" --arg t "$LINE 1" '
    first($T.result.tabs[] | select(.label == $t) | .tab_id) as $id
    | first($P.result.panes[] | select(.tab_id == $id and .label == "architect") | .pane_id) // empty'
}

# ---- monitor tabs: 3x3, labelled, a new tab when full (~/AGENTS.md herdr tab layout) -----------------------------
mon_tabs() { tabs | jq -r --arg t "$TAB" '.result.tabs[] | select((.label // "") == $t or ((.label // "") | startswith($t + " "))) | .tab_id'; }

# new_mon_tab: tab "<line> monitor" (then "... 2", "... 3"), 3 columns of 3 panes, every pane labelled free.
# Prints the root (top left) pane, so the caller takes it without listing again.
new_mon_tab() {
  local n label r root c r2 prev
  local -a cols
  n=$(( $(mon_tabs | wc -l) + 1 )); label="$TAB"; [ "$n" -gt 1 ] && label="$TAB $n"
  r="$(herdr tab create --workspace "$WS" --cwd "$WF_REPO" --label "$label" --no-focus)" || return 1
  root="$(jq -r '.result.root_pane.pane_id' <<<"$r")"
  herdr pane rename "$root" "$FREE" >/dev/null
  cols=("$root")
  for c in 1 2; do
    r="$(herdr pane split "${cols[c-1]}" --direction right --ratio "$(awk -v k=$((4 - c)) 'BEGIN{printf "%.4f", 1/k}')" --cwd "$WF_REPO" --no-focus)" || return 1
    cols[c]="$(jq -r '.result.pane.pane_id' <<<"$r")"; herdr pane rename "${cols[c]}" "$FREE" >/dev/null
  done
  for c in 0 1 2; do
    prev="${cols[c]}"
    for r2 in 3 2; do
      r="$(herdr pane split "$prev" --direction down --ratio "$(awk -v k="$r2" 'BEGIN{printf "%.4f", 1/k}')" --cwd "$WF_REPO" --no-focus)" || return 1
      prev="$(jq -r '.result.pane.pane_id' <<<"$r")"; herdr pane rename "$prev" "$FREE" >/dev/null
    done
  done
  printf '%s\n' "$root"
}

# slot <label>: the pane holding <label>, else the first free monitor slot renamed to it, else a new monitor tab's.
slot() {
  local p ids
  p="$(pane_by_label "$1")"; [ -n "$p" ] && { printf '%s' "$p"; return 0; }
  ids="$(mon_tabs | jq -R . | jq -sc .)"
  p="$(panes | jq -r --argjson ids "$ids" --arg f "$FREE" 'first(.result.panes[] | select(.label == $f and (.tab_id as $t | $ids | index($t)))) | .pane_id // empty')"
  if [ -z "$p" ]; then
    p="$(new_mon_tab)" || wf_die "could not open a monitor tab for $LINE"
  fi
  [ -n "$p" ] || wf_die "no free monitor slot for $1"
  herdr pane rename "$p" "$1" >/dev/null; printf '%s' "$p"
}

# ---- artifact store (Design principles 101 item 23): <root>/log/YYYY/MM/YYYYMMDD-HHMMSS-<name>.log, frontmatter on top.
# claude/tools/artifact/artifact.sh is the writer once it is on this tree; until then the same layout is written here.
log_file() {
  local root d f art
  art="$WF_REPO/../tools/artifact/artifact.sh"
  if [ -x "$art" ] || [ -f "$art" ]; then
    f="$(bash "$art" new --key log --name "line-watch-${SAFE:0:28}" --ext log --what "line-watch sweep for line $LINE" \
         --by "line-watch" 2>/dev/null)" && [ -n "$f" ] && { printf '%s' "$f"; return; }
  fi
  root="$(wf_expand "${ARTIFACT_ROOT:-$HOME/.local/state/zenith}")"; d="$root/log/$(date -u +%Y/%m)"; mkdir -p "$d"
  f="$d/$(date -u +%Y%m%d-%H%M%S)-line-watch-${SAFE:0:28}.log"
  printf -- '---\nwhat: line-watch sweep log for line %s\nby: claude/workflow/bin/line-watch.sh\nrepo: dotfiles\nbranch: %s\nworkspace: %s\nat: %s\n---\n' \
    "$LINE" "$(git -C "$WF_REPO" branch --show-current 2>/dev/null)" "$WS" "$(wf_now)" > "$f"
  printf '%s' "$f"
}

# ---- the architect is woken only by DONE or ALERT, with one JSON line (item 18: schema with acceptance criteria) --
wake() { # wake <code> <seat> <pane> <summary> <evidence> <ctx>
  local a msg
  msg="$(jq -cn --arg code "$1" --arg seat "$2" --arg pane "$3" --arg s "$4" --arg ev "$5" --arg ctx "$6" \
    --arg line "$LINE" --arg at "$(wf_now)" '{
      schema:"line-watch-event", version:"1.0.0", id:("LW-" + ($at|gsub("[-:TZ]";"")) + "-" + $seat), at:$at,
      kind:"event", status_code:$code, from:("line-watch:" + $line), to:"architect", subject:$s,
      facts:{line:$line, seat:$seat, pane:$pane, context_pct:(($ctx|tonumber?) // null), evidence:$ev},
      actions:(if $code == "LW-DONE" then ["read the seat result, then make seat-down SEAT=" + $seat]
               else ["give the seat work, unblock it, or make seat-down SEAT=" + $seat + " FORCE=1"] end),
      acceptance_criteria:[{id:"AC1", statement:("seat " + $seat + " is no longer " + $code), proof_kind:"log",
        proof:("the next line-watch log line for " + $seat)}]}')"
  a="$(arch_pane)"
  if [ -n "$a" ] && herdr agent prompt "$a" "$msg" >/dev/null 2>&1; then wf_watch_log "woke: architect $a $1 $2"
  else wf_watch_log "ALERT could not wake the architect (pane '${a:-none}'); event was: $msg"; fi
}

ctx_of() { # context percent from compaction-guard, else the transcript, else empty
  local sid tr
  sid="$(wf_pane_session "$1")"
  local v
  if [ -n "$sid" ] && command -v "$CG" >/dev/null 2>&1; then
    v="$("$CG" ctx "$sid" 2>/dev/null | jq -r '.pct // empty' 2>/dev/null)"; [ -n "$v" ] && { printf '%s' "$v"; return; }
  fi
  tr="$(wf_transcript "$1" 2>/dev/null)" && wf_context_pct "$tr"
}

# check_seat <name> <pane> <agent> <status>: prints "<code>\t<evidence>". Precedence: exited, done, blocked, idle.
check_seat() {
  local name="$1" pane="$2" agent="$3" st="$4" txt hit tr age f h
  [ -n "$agent" ] || { printf 'LW-ALERT-EXITED\tno agent in the pane'; return; }
  txt="$(herdr pane read "$pane" --source recent-unwrapped --lines 40 2>/dev/null)"
  # bin/herdr-grid.sh finished(): a non-placeholder word after the name, so a quoted "DONE <seat> <pr-url>" never counts.
  if [[ "$name" == *-p* && "$name" == "${pane//:/-}" ]]; then
    hit="$(grep -Eo '(^|[[:space:]])DONE [A-Za-z0-9_-]+ [^< ][^[:space:]]*' <<<"$txt" | tail -1)"
  else
    hit="$(grep -Eo "(^|[[:space:]])DONE ${name} [^< ][^[:space:]]*" <<<"$txt" | tail -1)"
  fi
  [ -n "$hit" ] && { printf 'LW-DONE\t%s' "$(printf '%s' "$hit" | sed 's/^[[:space:]]*//')"; return; }
  # the scratchpad watch.sh dialog check, unchanged: a permission or confirm prompt at the bottom of the pane
  if tail -n 15 <<<"$txt" | grep -qE 'Do you want|Enter to confirm|Esc to cancel'; then
    printf 'LW-ALERT-BLOCKED\t%s' "$(tail -n 15 <<<"$txt" | grep -E 'Do you want|Enter to confirm|Esc to cancel' | head -1 | cut -c1-120)"; return
  fi
  # Idle is transcript age, gated by herdr not reporting working: herdr alone reads idle for every unfocused pane
  # (workflow-lib wf_idle_seconds breadcrumb), and a long tool call leaves the transcript still while herdr says working.
  if [ "$st" != working ]; then
    tr="$(wf_transcript "$pane" 2>/dev/null)"
    if [ -n "$tr" ]; then age="$(wf_idle_seconds "$tr")"
    else # no transcript (kimi, codex): idle is the age of the last change in the pane's text, never herdr status alone
      f="$STATE/seats/$name.idle-since"; h="$(printf '%s' "$txt" | cksum | cut -d' ' -f1)"
      if [ "$(cat "$STATE/seats/$name.text" 2>/dev/null)" != "$h" ] || [ ! -f "$f" ]; then
        printf '%s' "$h" > "$STATE/seats/$name.text"; date -u +%s > "$f"; fi
      age=$(( $(date -u +%s) - $(cat "$f") )); fi
    [ "$age" -gt "$IDLE" ] && { printf 'LW-ALERT-IDLE\tidle %ss' "$age"; return; }
  else rm -f "$STATE/seats/$name.idle-since"; fi
  printf 'LW-OK\t%s' "$st"
}

sweep_once() {
  local name pane agent st out code ev ctx prev key seen
  seen=" "
  while IFS=$'\t' read -r name pane agent st; do
    [ -n "$name" ] || continue
    seen="$seen$name "
    out="$(check_seat "$name" "$pane" "$agent" "$st")"; code="${out%%$'\t'*}"; ev="${out#*$'\t'}"
    ctx="$(ctx_of "$pane")"
    prev="$(cat "$STATE/seats/$name.code" 2>/dev/null)"
    # one line on change: the code (and for DONE the token itself), never the context number, decides what is written
    key="$(printf '%s' "$name $ev" | cksum | cut -d' ' -f1)"
    if [ "$prev" = "$code" ]; then
      if [ "$code" != LW-DONE ] || grep -qxF "$key" "$STATE/notified" 2>/dev/null; then continue; fi
    fi
    printf '%s' "$code" > "$STATE/seats/$name.code"
    case "$code" in
      LW-OK)    wf_watch_log "seat: $name $pane ${ev:-?} ctx=${ctx:-?}%" ;;
      LW-DONE)
        wf_watch_log "DONE $name $pane $ev ctx=${ctx:-?}%"
        grep -qxF "$key" "$STATE/notified" 2>/dev/null && continue
        printf '%s\n' "$key" >> "$STATE/notified"
        wake "$code" "$name" "$pane" "seat $name printed its done token" "$ev" "$ctx" ;;
      *)        wf_watch_log "ALERT $name $pane $code: $ev ctx=${ctx:-?}%"
                wake "$code" "$name" "$pane" "seat $name: ${code#LW-ALERT-} ($ev)" "$ev" "$ctx" ;;
    esac
  done < <(seats || echo DISCOVERY_FAILED)
  # BREADCRUMB - a failed herdr list is not "every seat left". Reviewer finding, 2026-10-16: an empty list once wiped every
  #   seat's code, so the next tick re-alerted all of them. Discovery failure skips the cleanup and logs once.
  case "$seen" in *" DISCOVERY_FAILED "*)
    [ -f "$STATE/discovery-failed" ] || { : > "$STATE/discovery-failed"; wf_watch_log "ALERT herdr list failed for workspace $WS; seats unchecked until it answers"; }
    return ;; esac
  [ -f "$STATE/discovery-failed" ] && { rm -f "$STATE/discovery-failed"; wf_watch_log "discovery: herdr answers again"; }
  # a seat that left the line takes its state with it, so a new seat reusing the name starts clean
  for f in "$STATE"/seats/*.code; do
    [ -f "$f" ] || continue; name="$(basename "$f" .code)"
    case "$seen" in *" $name "*) ;; *) rm -f "$f" "$STATE/seats/$name.idle-since"; wf_watch_log "seat: $name left the line" ;; esac
  done
}

cmd_sweep() {
  [ "${HERDR_ENV:-}" = 1 ] || wf_die "refusing to run outside a herdr pane (dotfiles Rule 18); use: make line-watch LINE=$LINE"
  local pf="$STATE/sweep.pid"
  if [ "$ONCE" = 0 ] && [ -f "$pf" ] && kill -0 "$(cat "$pf")" 2>/dev/null; then echo "sweep for $LINE already on, pid $(cat "$pf")"; exit 0; fi
  WF_WATCH_LOG="$(readlink -f "$STATE/sweep.log" 2>/dev/null)"
  if [ -z "$WF_WATCH_LOG" ] || [ ! -f "$WF_WATCH_LOG" ]; then WF_WATCH_LOG="$(log_file)"; ln -sfn "$WF_WATCH_LOG" "$STATE/sweep.log"; fi
  WF_WATCH_INTERVAL="$INTERVAL"; WF_WATCH_STARTED="$(wf_now)"; export WF_WATCH_LOG WF_WATCH_INTERVAL WF_WATCH_STARTED
  if [ "$ONCE" = 1 ]; then sweep_once; return; fi
  echo "$$" > "$pf"; trap 'rm -f "$pf"; wf_watch_log "watch: stopped"' EXIT
  wf_watch_log "watch: started line=$LINE ws=$WS every=${INTERVAL}s idle=${IDLE}s log=$WF_WATCH_LOG"
  echo "line-watch $LINE: log $WF_WATCH_LOG (ALERT and DONE lines wake the architect)"
  while :; do sweep_once; sleep "$INTERVAL"; done
}

# arm <kind> <pane> <seat>: bin/watch-ctl.sh on, recorded in $STATE/armed only when it came up.
arm() {
  local out rc
  out="$(WATCH_WS="$WS" bash "$HERE/watch-ctl.sh" on "$1" "$2" 2>&1)"; rc=$?
  printf '%s\n' "$out" | sed "s/^/$3: /"
  [ "$rc" = 0 ] || return 0
  grep -qxF "$1 $2" "$STATE/armed" 2>/dev/null || printf '%s %s\n' "$1" "$2" >> "$STATE/armed"
}

# adopt: compact-watch on every seat, seat-watch where bin/workflow-spawn.sh left a seat-link. Nothing is restarted.
cmd_adopt() {
  local name pane agent st label sd
  [ "${HERDR_ENV:-}" = 1 ] || wf_die "not inside herdr; watchers run in labeled herdr panes only (Rule 18)"
  while IFS=$'\t' read -r name pane agent st; do
    if [ -z "$name" ] || [ -z "$agent" ]; then continue; fi
    if [ "${LW_COMPACT:-1}" = 1 ]; then
      label="watch-compact-${pane//[^A-Za-z0-9-]/-}"; ( slot "$label" >/dev/null ) || { echo "$name: no monitor slot for $label" >&2; continue; }
      arm compact "$pane" "$name"
    fi
    sd="$(wf_seat_dir "$pane")"
    if [ -f "$sd/seat-link" ]; then
      label="watch-seat-${pane//[^A-Za-z0-9-]/-}"; ( slot "$label" >/dev/null ) || { echo "$name: no monitor slot for $label" >&2; continue; }
      arm seat "$pane" "$name"
    else
      printf '%s: seat watcher skipped, %s has no seat-link (not started by workflow-spawn.sh); the sweep covers it\n' "$name" "$pane"
    fi
  done < <(seats)
}

cmd_up() {
  [ "${HERDR_ENV:-}" = 1 ] || wf_die "not inside herdr; the sweep runs in a labeled herdr pane only (Rule 18)"
  local p
  p="$(slot "$SAFE-sweep")" || exit 1
  if [ -f "$STATE/sweep.pid" ] && kill -0 "$(cat "$STATE/sweep.pid")" 2>/dev/null; then echo "sweep for $LINE already on in $p"
  else
    herdr pane run "$p" "$(printf 'HERDR_ENV=1 WS=%q ARCH=%q LW_INTERVAL=%q LW_IDLE=%q LW_STATE=%q ARTIFACT_ROOT=%q WORKFLOW_CONFIG=%q COMPACTION_GUARD_BIN=%q bash %q sweep %q' \
      "$WS" "${ARCH:-}" "$INTERVAL" "$IDLE" "${LW_STATE:-$HOME/.local/state/zenith/line-watch}" \
      "${ARTIFACT_ROOT:-$HOME/.local/state/zenith}" "$WF_CONFIG" "$CG" "$HERE/line-watch.sh" "$LINE")" >/dev/null \
      || wf_die "herdr could not start the sweep in $p"
    echo "sweep for $LINE on in $p ($SAFE-sweep), tab $TAB"
  fi
  cmd_adopt
}

cmd_off() {
  local kind pane t
  if [ -f "$STATE/sweep.pid" ] && kill -0 "$(cat "$STATE/sweep.pid")" 2>/dev/null; then kill "$(cat "$STATE/sweep.pid")"; echo "sweep for $LINE off"; fi
  rm -f "$STATE/sweep.pid"
  while read -r kind pane; do
    [ -n "$kind" ] && WATCH_WS="$WS" bash "$HERE/watch-ctl.sh" off "$kind" "$pane" --close
  done < "$STATE/armed" 2>/dev/null
  rm -f "$STATE/armed"
  for t in $(mon_tabs); do herdr tab close "$t" >/dev/null 2>&1 && echo "closed monitor tab $t"; done
  # the log stays in the artifact store; only the pointer and per-seat codes go
  rm -rf "$STATE/seats" "$STATE/notified" "$STATE/sweep.log"
}

cmd_status() {
  if [ -f "$STATE/sweep.pid" ] && kill -0 "$(cat "$STATE/sweep.pid")" 2>/dev/null; then echo "sweep $LINE on, pid $(cat "$STATE/sweep.pid")"
  else echo "sweep $LINE off"; fi
  [ -f "$STATE/armed" ] && sed 's/^/armed: /' "$STATE/armed"
  [ -e "$STATE/sweep.log" ] && { echo "log: $(readlink -f "$STATE/sweep.log")"; tail -n 3 "$STATE/sweep.log"; }
  return 0
}

case "$cmd" in
  up) cmd_up ;; adopt) cmd_adopt ;; sweep) cmd_sweep ;; off) cmd_off ;; status) cmd_status ;;
  *) wf_die "unknown command $cmd (up|adopt|sweep|off|status)" ;;
esac
