#!/usr/bin/env bash
# line-watch.sh - one line's monitoring, in labeled herdr panes of a "<line> monitor" tab, driven by Make.
#
# usage: line-watch.sh <cmd> <line> [--once]
#   run    <line>          adopt, then sweep: the "sweep" monitor of config/monitors.json (make monitors-up LINE= starts it)
#   adopt  <line>          put every running seat of the line under the watchers, no restarts
#   sweep  <line> [--once] the loop itself; runs in the foreground of the sweep pane only (Rule 18)
#   stop   <line>          stop the sweep, the consumer and every watcher this line armed (the sweep monitor's down)
#   status <line>          sweep and consumer pids, armed watchers, bus status, last three log lines
#   consume <line> [--once] consumer line-consume, no model, in pane "<line>-consume": acts on LW-DONE, then acks
#   queue  <line> <role>   consumers orchestrator and architect pull their waiting events (bin/bus.sh pull)
# env (Make passes VAR=value): WS (default $HERDR_WORKSPACE_ID), LW_INTERVAL (60), LW_IDLE (60, seconds before an idle
#   seat is an ALERT), LW_CONSUME_INTERVAL (10), LW_RESULTS (dir holding <seat>-result.json), LW_STATE
#   (~/.local/state/zenith/line-watch), ARTIFACT_ROOT (~/.local/state/zenith), LW_COMPACT (1: arm compact-watch),
#   LW_BUS (config/line-watch.json: the bus, the stream and which consumer filters which event codes)
#
# Producer and consumers (architect redesign 2026-10-16T04:31Z, owner: "prodcuer consumer model man"):
#   sweep (producer) --publish--> NATS JetStream stream LINE, subject line.<line>.event.<status_code> (bin/bus.sh)
#   line-consume consumer 1, this script, no model: LW-DONE -> result-check -> herdr-grid seat-down, ack after acting
#   orchestrator consumer 2 pulls with make line-queue ROLE=orchestrator on its own schedule
#   architect    consumer 3 pulls only codes that need a ruling (LW-RULING-*); nothing is ever pushed into a pane
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
WTAB="$LINE watchers"
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

# ---- events go on the bus (bin/bus.sh), never into a pane ----------------------------------------------------------
# BREADCRUMB - events are published, never prompted into a pane.
# What broke: the first live run (2026-10-16T04:30Z) prompted the architect pane wD9:p1 once per seat with JSON; owner:
#   "your gonna get bogged down, thats fucked right there", then "prodcuer consumer model man" and "drop that shit on a
#   bus we have nats" (item 26).
# Why this fix: the sweep only publishes; each consumer pulls when it chooses, so a busy seat is never interrupted and a
#   restart loses nothing. Mechanical events never reach a model: consumer line-consume is this script.
#   Rejected: prompting the orchestrator pane instead (same interruption one seat down); jsonl queues with offset files
#   (a hand-built bus, superseded 04:32Z).
# Cost: an event waits until its consumer pulls; the bus must be up (make bus-up), else the publish fails loud in the log.
BUS="$HERE/bus.sh"

# ---- watcher tabs: 3x3, labelled, a new tab when full (~/AGENTS.md herdr tab layout) ------------------------------
# BREADCRUMB - per-seat watchers get their own tab "<line> watchers", never the monitor tab.
# What broke: slot() put every watch-compact-<pane> in a free slot of "<line> monitor"; 2026-10-16T05:32Z nine orphans held
#   slots 2.1/2.2, so `monitors-up` refused the resources and events monitors ("slot 2.1 is not free").
# Why this fix: the monitor tab is exactly the declared monitors (config/monitors.json) and nothing else lives or dies
#   there; watchers come and go with seats, so they get "<line> watchers" (3x3, "<line> watchers 2" when full) built by
#   bin/monitors.sh grid. Rejected: reserving slots in the monitor tab, which caps the line at the free slot count.
# Cost: one more tab per line once a seat is watched; stop closes it with the watchers.
watch_tabs() { tabs | jq -r --arg t "$WTAB" '.result.tabs[] | select((.label // "") == $t or ((.label // "") | test("^" + ($t | gsub("[^A-Za-z0-9_-]"; "\\\(.)")) + " [0-9]+$"))) | .tab_id'; }

# new_watch_tab: one more 3x3 tab "<line> watchers N", built by bin/monitors.sh grid; prints its top-left pane.
new_watch_tab() {
  local n label
  n=$(( $(watch_tabs | wc -l) + 1 )); label="$WTAB"; [ "$n" -gt 1 ] && label="$WTAB $n"
  WS="$WS" bash "$HERE/monitors.sh" grid "$label"
}

# slot <label>: the pane holding <label>, else the first free watcher slot renamed to it, else a new watchers tab's.
slot() {
  local p ids
  p="$(pane_by_label "$1")"; [ -n "$p" ] && { printf '%s' "$p"; return 0; }
  ids="$(watch_tabs | jq -R . | jq -sc .)"
  p="$(panes | jq -r --argjson ids "$ids" --arg f "$FREE" 'first(.result.panes[] | select(((.label // "") | startswith($f)) and (.tab_id as $t | $ids | index($t)))) | .pane_id // empty')"
  if [ -z "$p" ]; then
    p="$(new_watch_tab)" || wf_die "could not open a watchers tab for $LINE"
  fi
  [ -n "$p" ] || wf_die "no free watcher slot for $1"
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

# ---- emit: one event (item 18: schema with acceptance criteria) published on the bus under its status code ---------
emit() { # emit <code> <seat> <pane> <summary> <evidence> <ctx>
  local msg
  msg="$(jq -cn --arg code "$1" --arg seat "$2" --arg pane "$3" --arg s "$4" --arg ev "$5" --arg ctx "$6" \
    --arg line "$LINE" --arg at "$(wf_now)" --arg to "$(jq -r --arg c "$1" '[.consumers | to_entries[] | select(.value.codes | index($c)) | .key] | first // "orchestrator"' "${LW_BUS:-$WF_REPO/config/line-watch.json}")" '{
      schema:"line-watch-event", version:"1.0.0", id:("LW-" + ($at|gsub("[-:TZ]";"")) + "-" + $seat + "-" + $code), at:$at,
      kind:"event", status_code:$code, from:("line-watch:" + $line), to:$to, subject:$s,
      facts:{line:$line, seat:$seat, pane:$pane, context_pct:(($ctx|tonumber?) // null), evidence:$ev},
      actions:(if $code == "LW-DONE" then ["read the seat result, then make seat-down SEAT=" + $seat]
               else ["give the seat work, unblock it, or make seat-down SEAT=" + $seat + " FORCE=1"] end),
      acceptance_criteria:[{id:"AC1", statement:("seat " + $seat + " is no longer " + $code), proof_kind:"log",
        proof:("the next line-watch log line for " + $seat)}]}')"
  if bash "$BUS" pub "line.$SAFE.event.$1" "$msg" 2>/dev/null; then wf_watch_log "published: $1 $2"
  else wf_watch_log "ALERT bus publish failed for $1 $2 (is the bus up? make bus-up); event was: $msg"; fi
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

# done_hits <name> <pane> <text>: every done line in the text, trimmed. bin/herdr-grid.sh finished(): a non-placeholder
# word after the name, so a quoted "DONE <seat> <pr-url>" never counts. An unnamed seat (its pane id) matches any name.
done_hits() {
  if [ "$1" = "${2//:/-}" ]; then grep -Eo '(^|[[:space:]])DONE [A-Za-z0-9_-]+ [^< ][^[:space:]]*' <<<"$3"
  else grep -Eo "(^|[[:space:]])DONE ${1} [^< ][^[:space:]]*" <<<"$3"; fi | sed 's/^[[:space:]]*//'
}

# baseline <name> <text>: written once per seat; the done lines visible when line-watch first saw it.
baseline() {
  local f="$STATE/seats/$1.baseline"
  [ -f "$f" ] && return 0
  { printf '%s\n' '#baseline'; done_hits "$1" "${PANE_OF:-}" "$2"; } > "$f"
}

# check_seat <name> <pane> <agent> <status>: prints "<code>\t<evidence>". Precedence: exited, done, blocked, idle.
check_seat() {
  local name="$1" pane="$2" agent="$3" st="$4" txt hit tr age f h
  [ -n "$agent" ] || { printf 'LW-ALERT-EXITED\tno agent in the pane'; return; }
  txt="$(herdr pane read "$pane" --source recent-unwrapped --lines 40 2>/dev/null)"
  # bin/herdr-grid.sh finished(): a non-placeholder word after the name, so a quoted "DONE <seat> <pr-url>" never counts.
  # BREADCRUMB - a done line already on screen when the seat was first seen is stale, never an event.
  # What broke: the first live run sent LW-DONE for li-page off "DONE li-page BLOCKED", printed at 03:10Z, an hour before
  #   line-watch started (architect, 2026-10-16T04:31Z). herdr pane read has no scrollback offset to record.
  # Why this fix: at first sight (adopt or the first sweep) every done line on screen is written to <seat>.baseline, and
  #   only lines not in it count. Rejected: dropping the scrollback read, which loses the done line a seat prints next.
  # Cost: a seat that prints the very same line again after adopt is not re-reported; a new done carries a new token.
  baseline "$name" "$txt"
  hit="$(done_hits "$name" "$pane" "$txt" | grep -vxFf "$STATE/seats/$name.baseline" | tail -1)"
  [ -n "$hit" ] && { printf 'LW-DONE\t%s' "$hit"; return; }
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

# adopt_named: bin/herdr-grid.sh adopt-named, every tick. A seat started outside seat-up is in the grid within a minute.
# Idempotent: a seat already in a slot is left. A failure is an ALERT in the log and never stops the sweep.
adopt_named() {
  local out l
  out="$(WS="$WS" bash "$HERE/herdr-grid.sh" adopt-named "$LINE" 2>&1)" || wf_watch_log "ALERT adopt-named failed: $(tail -1 <<<"$out")"
  while IFS= read -r l; do [ -n "$l" ] && wf_watch_log "$l"; done < <(grep -E '^grid: adopted' <<<"$out")
}

# reap_watchers: a watcher pane (watch-compact-<id>, watch-seat-<id>) whose seat pane no longer exists is stopped and closed.
# A failed or empty herdr list reaps nothing (same rule as the discovery-failed breadcrumb below).
reap_watchers() {
  local p ids pane label kind sfx
  p="$(panes)"; jq -e '(.result.panes | length) > 0' >/dev/null 2>&1 <<<"$p" || return 0
  ids=" $(jq -r '.result.panes[].pane_id | gsub(":"; "-")' <<<"$p" | tr '\n' ' ') "
  while IFS=$'\t' read -r pane label; do
    case "$label" in watch-compact-*) kind=compact ;; watch-seat-*) kind=seat ;; *) continue ;; esac
    sfx="${label#watch-"$kind"-}"
    case "$ids" in *" $sfx "*) continue ;; esac
    WATCH_WS="$WS" bash "$HERE/watch-ctl.sh" off "$kind" "${sfx/-/:}" --close >/dev/null 2>&1
    herdr pane list --workspace "$WS" 2>/dev/null | jq -e --arg p "$pane" '.result.panes | any(.pane_id == $p)' >/dev/null 2>&1 \
      && herdr pane close "$pane" >/dev/null 2>&1
    wf_watch_log "watcher: $label closed, its seat pane is gone"
  done < <(jq -r '.result.panes[] | select((.label // "") | startswith("watch-")) | [.pane_id, .label] | @tsv' <<<"$p")
}

sweep_once() {
  local name pane agent st out code ev ctx prev key seen
  adopt_named; reap_watchers
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
        emit "$code" "$name" "$pane" "seat $name printed its done token" "$ev" "$ctx" ;;
      *)        wf_watch_log "ALERT $name $pane $code: $ev ctx=${ctx:-?}%"
                emit "$code" "$name" "$pane" "seat $name: ${code#LW-ALERT-} ($ev)" "$ev" "$ctx" ;;
    esac
  done < <(seats || echo DISCOVERY_FAILED)
  # BREADCRUMB - a failed herdr list is not "every seat left". Reviewer finding, 2026-10-16: an empty list once wiped every
  #   seat's code, so the next tick re-alerted all of them. Discovery failure skips the cleanup and logs once.
  case "$seen" in *" DISCOVERY_FAILED "*)
    [ -f "$STATE/discovery-failed" ] || { : > "$STATE/discovery-failed"; wf_watch_log "ALERT herdr list failed for workspace $WS; seats unchecked until it answers"
      emit LW-ALERT-DISCOVERY "-" "-" "herdr list failed for workspace $WS" "seats unchecked" ""; }
    return ;; esac
  [ -f "$STATE/discovery-failed" ] && { rm -f "$STATE/discovery-failed"; wf_watch_log "discovery: herdr answers again"; }
  # a seat that left the line takes its state with it, so a new seat reusing the name starts clean
  for f in "$STATE"/seats/*.code; do
    [ -f "$f" ] || continue; name="$(basename "$f" .code)"
    case "$seen" in *" $name "*) ;; *) rm -f "$f" "$STATE/seats/$name".{idle-since,baseline,text}; wf_watch_log "seat: $name left the line" ;; esac
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
  echo "line-watch $LINE: log $WF_WATCH_LOG (ALERT and DONE events go on the bus, never into a pane)"
  while :; do sweep_once; sleep "$INTERVAL"; done
}

# ---- consumer 1, no model --------------------------------------------------------------------------------------
# handle <event-json>: LW-DONE with a result that passes bin/brief.sh result-check -> bin/herdr-grid.sh seat-down.
# What it cannot finish goes back on the bus for the orchestrator. A seat already gone counts as down, so a redelivered
# event (the consumer died before its ack) does nothing twice.
handle() {
  local ev="$1" code seat rf why
  code="$(jq -r .status_code <<<"$ev")"; seat="$(jq -r .facts.seat <<<"$ev")"
  [ "$code" = LW-DONE ] || { wf_watch_log "consume: $code $seat is not line-consume's; acked and ignored"; return; }
  if ! seats | cut -f1 | grep -qxF "$seat"; then wf_watch_log "consume: $seat already off the line"; return; fi
  rf="${LW_RESULTS:+$(wf_expand "$LW_RESULTS")/$seat-result.json}"
  if [ -z "$rf" ]; then why="LW_RESULTS is not set, so there is no result file to check"
  else why="$(bash "$HERE/brief.sh" result-check "$rf" 2>&1 >/dev/null | head -1)" || true
       bash "$HERE/brief.sh" result-check "$rf" >/dev/null 2>&1 && why=""; fi
  if [ -n "$why" ]; then
    emit LW-AC-FAILED "$seat" "$(jq -r .facts.pane <<<"$ev")" "seat $seat printed done but its result does not pass" "$why" ""
    return
  fi
  if WS="$WS" bash "$HERE/herdr-grid.sh" seat-down "$seat" "$LINE" >/dev/null 2>"$STATE/down.err"; then
    wf_watch_log "consume: $seat result passes, seat downed"
  else emit LW-DOWN-FAILED "$seat" "$(jq -r .facts.pane <<<"$ev")" "seat-down failed for $seat" "$(tail -1 "$STATE/down.err")" ""; fi
}

cmd_consume() {
  [ "${HERDR_ENV:-}" = 1 ] || wf_die "refusing to run outside a herdr pane (dotfiles Rule 18); use: make line-consume LINE=$LINE"
  local m
  WF_WATCH_LOG="$(readlink -f "$STATE/sweep.log" 2>/dev/null)"
  if [ -z "$WF_WATCH_LOG" ] || [ ! -f "$WF_WATCH_LOG" ]; then WF_WATCH_LOG="$(log_file)"; ln -sfn "$WF_WATCH_LOG" "$STATE/sweep.log"; fi
  export WF_WATCH_LOG
  [ "$ONCE" = 1 ] || { echo "$$" > "$STATE/consume.pid"; trap 'rm -f "$STATE/consume.pid"' EXIT; }
  while :; do
    while m="$(bash "$BUS" next line-consume)" && [ -n "$m" ]; do
      handle "${m#*$'\t'}"; bash "$BUS" ack "${m%%$'\t'*}"   # acked after the action, never before
    done
    [ "$ONCE" = 1 ] && return 0
    sleep "${LW_CONSUME_INTERVAL:-10}"
  done
}

# queue <role>: consumers orchestrator and architect pull every waiting event, one JSON per line, acked as read.
cmd_queue() {
  case "${ROLE:-}" in orchestrator|architect) ;; *) wf_die "ROLE= must be orchestrator or architect" ;; esac
  bash "$BUS" pull "$ROLE"
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
    PANE_OF="$pane" baseline "$name" "$(herdr pane read "$pane" --source recent-unwrapped --lines 40 2>/dev/null)"
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


# run: what the sweep monitor (config/monitors.json) runs in its pane: adopt every seat, then sweep in the foreground.
cmd_run() { cmd_adopt; cmd_sweep; }

# stop: the sweep monitor's `down`; stops the sweep, the consumer and every watcher this line armed. Tabs are
# bin/monitors.sh's to close (monitors-down), so this never closes one.
cmd_stop() {
  local kind pane t
  if [ -f "$STATE/sweep.pid" ] && kill -0 "$(cat "$STATE/sweep.pid")" 2>/dev/null; then kill "$(cat "$STATE/sweep.pid")"; echo "sweep for $LINE off"; fi
  rm -f "$STATE/sweep.pid"
  if [ -f "$STATE/consume.pid" ] && kill -0 "$(cat "$STATE/consume.pid")" 2>/dev/null; then kill "$(cat "$STATE/consume.pid")"; echo "consumer for $LINE off"; fi
  rm -f "$STATE/consume.pid"
  while read -r kind pane; do
    [ -n "$kind" ] && WATCH_WS="$WS" bash "$HERE/watch-ctl.sh" off "$kind" "$pane" --close
  done < "$STATE/armed" 2>/dev/null
  rm -f "$STATE/armed"
  for t in $(watch_tabs); do herdr tab close "$t" >/dev/null 2>&1 && echo "closed watchers tab $t"; done
  # the log stays in the artifact store and unpulled events stay on the bus; only the pointer and seat codes go
  rm -rf "$STATE/seats" "$STATE/notified" "$STATE/sweep.log"
}

cmd_status() {
  if [ -f "$STATE/sweep.pid" ] && kill -0 "$(cat "$STATE/sweep.pid")" 2>/dev/null; then echo "sweep $LINE on, pid $(cat "$STATE/sweep.pid")"
  else echo "sweep $LINE off"; fi
  [ -f "$STATE/armed" ] && sed 's/^/armed: /' "$STATE/armed"
  if [ -f "$STATE/consume.pid" ] && kill -0 "$(cat "$STATE/consume.pid")" 2>/dev/null; then echo "consumer $LINE on, pid $(cat "$STATE/consume.pid")"; else echo "consumer $LINE off"; fi
  bash "$BUS" status
  [ -e "$STATE/sweep.log" ] && { echo "log: $(readlink -f "$STATE/sweep.log")"; tail -n 3 "$STATE/sweep.log"; }
  return 0
}

case "$cmd" in
  run) cmd_run ;; adopt) cmd_adopt ;; sweep) cmd_sweep ;; stop) cmd_stop ;; status) cmd_status ;;
  consume) cmd_consume ;; queue) ROLE="${ROLE:-${3:-}}" cmd_queue ;;
  *) wf_die "unknown command $cmd (run|adopt|sweep|consume|queue|stop|status)" ;;
esac
