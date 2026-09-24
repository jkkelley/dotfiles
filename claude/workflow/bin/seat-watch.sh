#!/usr/bin/env bash
# seat-watch.sh <pane> [--once] - supervise one seat: tell the principal when it is done, hot swap it when it cannot go on.
#
# Runs in the FOREGROUND of a labeled herdr pane. Never started directly: bin/watch-ctl.sh on seat <pane> puts it there,
# and bin/workflow-spawn.sh does that for every seat it starts. It refuses to run outside herdr (dotfiles Rule 18).
# It reads what runs in the pane from <seat dir>/seat-link, which only the spawner writes.
#
# Ported, not invented. The shape is bearings-v2's supervisor sweep (~/tools/bearings-v2/bin/watch.sh lines 30-110) cut to
# one seat, its record feed (bin/monitor-feed.sh), its dispatcher's wait rules (bin/dispatch-seat.sh) and its pause flag
# (bin/watch-toggle.sh). What changed in the port, per owner decision O-06 (hot swap through the chain until exhausted;
# a human is notified, never required):
#   bearings "escalate after 3 resumes"  ->  hot swap to the next link of the declaration's model chain
#   bearings "down.sh, owner line"        ->  chain exhausted: ALERT once and prompt the principal, never wait on the owner
#
# Each tick, in order of precedence:
#   paused     <seat dir>/PAUSED exists (watch-ctl.sh pause seat <pane>). Nothing is done; nothing restarts.
#   done       the seat's own record exists: a row of the declaration's record.emitted_to, or a rail ledger `complete`
#              row by this seat, since this link started. Prompt the principal one line, once per row, retire the
#              seat with /exit (bin/seat-record.sh is the seat's last act), and end.
#   stopped    <seat dir>/failover-stopped exists: the chain was exhausted or a swap failed. Watch for done only.
#   hold       changeover-hold exists and is not ours. Never act into another actor's changeover.
#   exhausted  the transcript's newest assistant row is an API error of the exhaustion class (rate limit, 429, quota,
#              credit or spend limit, overloaded, authentication). Swap to the next link now.
#   dead       herdr no longer sees an agent in the pane.         Resume the same link, up to resume_attempts, then swap.
#   silent     no transcript growth for stall_seconds.            Prompt it to continue, up to resume_attempts, then swap.
#
# Log contract (MONITORING-AND-ALERTING v1.0.0), as compact-watch: one line on change only; ALERT only for the owner.
# BREADCRUMB - `set -uo pipefail`, deliberately no -e. A tick is built from checks expected to fail most of the time.
#   bearings-v2 watch.sh ran with -e and died silently six times on 2026-09-21 (its breadcrumb at line 7, 04:46Z) until
#   it grew an ERR trap; a watcher that only needs to not die is better served by not arming -e at all, which is what
#   bin/compact-watch.sh and bin/workflow-watch.sh already do. Cost: a genuine bug keeps ticking; `status` shows it.
set -uo pipefail
# shellcheck source=bin/workflow-lib.sh disable=SC1091
. "$(dirname "$(readlink -f "$0")")/workflow-lib.sh"
wf_need jq

pane=""; once=0
for a in "$@"; do case "$a" in --once) once=1 ;; -*) wf_die "unknown flag $a" ;; *) pane="$a" ;; esac; done
[ -n "$pane" ] || wf_die "usage: seat-watch.sh <pane> [--once]"
[ "${HERDR_ENV:-}" = 1 ] || wf_die "refusing to run outside a herdr pane (dotfiles Rule 18); use bin/watch-ctl.sh on seat $pane"

BIN="$(dirname "$(readlink -f "$0")")"
seat="$(wf_seat_dir "$pane")"
STALL="$(wf_cfg '.workflow.watchers.stall_seconds // 900')"
TRIES="$(wf_cfg '.workflow.watchers.resume_attempts // 3')"
TICK="$(wf_cfg '.workflow.watchers.interval_seconds // 60')"
LEDGER="$(wf_expand "$(wf_cfg '.workflow.watchers.rail_ledger // "~/.local/state/dotfiles/rail/ledger.tsv"')")"
CP="$(wf_expand "$(wf_cfg '.workflow.skills_dir // "~/.claude/skills"')")/context-compaction/scripts/checkpoint.sh"
WF_WATCH_LOG="$seat/seat-watch.log"; WF_WATCH_INTERVAL="$TICK"; WF_WATCH_STARTED="$(wf_now)"
export WF_WATCH_LOG WF_WATCH_INTERVAL WF_WATCH_STARTED
echo "$$" > "$seat/seat-watch.pid"
trap 'rm -f "$seat/seat-watch.pid"; wf_watch_log "watch: stopped"; wf_watch_state seat-watch off 0' EXIT
wf_watch_state seat-watch on "$$" "$(jq -n --arg p "$pane" '{pane:$p}')"
wf_watch_log "watch: started pane=$pane stall=${STALL}s resumes=$TRIES"

link() { jq -r "$1" "$seat/seat-link"; }

# BREADCRUMB - the principal is named by pane label and resolved on every send, never stored as a pane id.
# What broke: nothing yet; herdr ids are not stable across a herdr restart (bin/workflow-spawn.sh says the same), so a
#   stored wC1:p1 is a notification delivered into a stranger's pane after the first restart.
# Why this fix: config workflow.principal_pane holds the label the orchestrator layout gives its main pane
#   (claude-main, dotfiles Rule 18), and the id is looked up at send time. Rejected: an agent name, which the principal
#   usually does not carry. Cost: one pane list per notification.
# The prompt is sent without --wait: herdr's 5 second activity gate reports agent_prompt_stalled while a live seat is
# still reading, and bearings-v2 acted on that false stall and closed a working tester (dispatch-seat.sh, 2026-09-21T02:16Z).
principal() {
  local label ws p
  label="$(wf_cfg '.workflow.principal_pane // empty')"
  [ -n "$label" ] || { wf_watch_log "ALERT no workflow.principal_pane configured; could not tell the principal: $*"; return 1; }
  ws="$(herdr workspace list 2>/dev/null | jq -r --arg l "$(wf_cfg .workflow.herdr.workspace_label)" 'first(.result.workspaces[] | select(.label == $l) | .workspace_id) // empty')"
  p="$(herdr pane list --workspace "$ws" 2>/dev/null | jq -r --arg l "$label" 'first(.result.panes[] | select(.label == $l) | .pane_id) // empty')"
  if [ -n "$p" ] && herdr agent prompt "$p" "$*" >/dev/null 2>&1; then return 0; fi
  wf_watch_log "ALERT could not reach the principal pane '$label'; message was: $*"; return 1
}

# ---- done: the seat's own record, never inferred from idleness -------------
# BREADCRUMB - done is the record the declaration says the seat emits, plus the rail ledger's complete row.
# What broke: S-02 finished at 2026-09-22T21:32Z and nobody noticed until 21:57Z (rail O-12), because nothing read the
#   records seats write. bearings-v2 had this as bin/monitor-feed.sh and it was not ported.
# Why this fix: a record is the seat's own statement that it finished, so it cannot be a false positive the way "idle
#   for 45 seconds" is for a seat that is merely thinking. Rows are deduped by id as monitor-feed.sh does, so a re-read
#   never repeats a line (owner turned the raw feed off at 2026-09-21T03:0?Z because volume blocked typing). Our records
#   carry no record_id, so the id is the row's checksum. Rejected: idle inference, which was the first draft of O-09.
# Cost: a seat that finishes without writing either record is reported as silent, not done. That is the right failure.
done_row() {
  local since ticket wf rec rows
  since="$(link .started_at)"; ticket="$(link '.ticket // ""')"; wf="$(link .workflow)"
  rec="$("$BIN/workflow-spec.sh" "$wf" --full 2>/dev/null | jq -r '.record.emitted_to // empty')"
  rows=""
  # A row with no ticket field matches: some record schemas (architect's) carry none, and the row is then this
  # workflow's since this link started, which is the seat's. A row naming another ticket never matches.
  if [ -n "$rec" ] && [ -f "$(wf_state_dir)/${rec#state:}" ]; then
    rows="$(jq -rc --arg s "$since" --arg t "$ticket" 'select(.at >= $s and ($t == "" or (.ticket // $t) == $t))
      | "\(.outcome // "recorded")\(if .ticket then " " + .ticket else "" end)\(if .note then ": " + .note else "" end)"' \
      "$(wf_state_dir)/${rec#state:}" 2>/dev/null)"
  fi
  if [ -f "$LEDGER" ]; then
    rows="$rows"$'\n'"$(awk -F'\t' -v s="$since" -v by="$(link .seat)" \
      'NR > 1 && $1 >= s && $3 == "complete" && $5 == by { print $2 " complete: " $4 }' "$LEDGER")"
  fi
  local r id
  while IFS= read -r r; do
    [ -n "$r" ] || continue
    id="$(printf '%s' "$r" | cksum | cut -d' ' -f1)"
    grep -qxF "$id" "$seat/.seen" 2>/dev/null && continue
    printf '%s\n' "$id" >> "$seat/.seen"
    printf '%s' "$r"; return 0
  done <<<"$rows"
  return 1
}

# ---- exhaustion: what Claude Code writes when a provider refuses -----------
# Claude Code writes a synthetic assistant row with "isApiErrorMessage":true and an "error" class when the API refuses.
# Observed across this machine's transcripts on 2026-09-22: rate_limit 155 (spend and usage limits among them),
# server_error 7, model_not_found 11, invalid_request 1. Only the exhaustion classes swap; a model_not_found is a
# declaration defect that the next link would not fix, so it is left for silence to catch and a human to read.
api_exhausted() {
  local tr="$1"
  tail -n 200 "$tr" | jq -rs '[.[] | select(.type == "assistant")] | last // {}
    | select(.isApiErrorMessage == true)
    | [(.error // ""), ([.message.content[]?.text // empty] | join(" "))] | join(" ")' 2>/dev/null \
    | grep -iE 'rate_limit|authentication|billing|overloaded|\b429\b|\b529\b|rate limit|quota|credit|spend limit|usage limit' \
    | head -1 | cut -c1-120
}

# ---- the handover packet ---------------------------------------------------
# The checkpoint the seat wrote is the better packet, when it verifies: the seat wrote it knowing what mattered. Else the
# packet is built from rows alone, so a seat that died without checkpointing still hands over its brief and its tree.
packet() {
  local tr="$1" out wt
  out="$seat/handover-$(date -u +%Y%m%dT%H%M%SZ).md"; wt="$(link .worktree)"
  if [ -f "$seat/CONTEXT_STATE.md" ] && bash "$CP" verify --project "$seat" >/dev/null 2>&1; then
    { printf '# Handover packet, %s (from the seat checkpoint)\n\n' "$pane"; cat "$seat/CONTEXT_STATE.md"; } > "$out"
  else
    {
      printf '# Handover packet, %s (built from the transcript; no verified checkpoint)\n\n' "$pane"
      printf 'Workflow %s, seat %s, ticket %s, link %s (%s), worktree %s.\n\n' "$(link .workflow)" "$(link .seat)" \
        "$(link '.ticket // "-"')" "$(link .link)" "$(link .link_id)" "$wt"
      printf '## Last brief\n\n'
      [ -f "$tr" ] && tail -n 400 "$tr" | jq -rs '[.[] | select(.type == "user" and (.message.content | type) == "string")] | last | .message.content // "(none)"' 2>/dev/null
      printf '\n## Last assistant text\n\n'
      [ -f "$tr" ] && tail -n 400 "$tr" | jq -rs '[.[] | select(.type == "assistant") | [.message.content[]? | select(.type == "text") | .text] | join("\n") | select(. != "")] | last // "(none)"' 2>/dev/null
      fence='```'
      printf '\n## git status\n\n%s\n' "$fence"; git -C "$wt" status --short 2>&1 || true
      printf '%s\n\n## git log -5\n\n%s\n' "$fence" "$fence"; git -C "$wt" log -5 --oneline 2>&1 || true
      printf '%s\n' "$fence"
    } > "$out"
  fi
  ln -sfn "$out" "$seat/handover.md"; printf '%s' "$out"
}

# Stop the seat and prove it stopped. /exit at the prompt, as bearings-v2 dispatch-seat.sh retires a seat; esc first,
# because a stalled seat may be mid-turn and /exit typed into a turn is prose. ctrl+c twice is the fallback.
stop_seat() {
  local i
  herdr agent get "$pane" >/dev/null 2>&1 || return 0
  herdr agent send-keys "$pane" esc >/dev/null 2>&1
  herdr agent prompt "$pane" "/exit" >/dev/null 2>&1
  for (( i = 0; i < 15; i++ )); do herdr agent get "$pane" >/dev/null 2>&1 || return 0; sleep 2; done
  herdr agent send-keys "$pane" ctrl+c ctrl+c >/dev/null 2>&1
  for (( i = 0; i < 5; i++ )); do herdr agent get "$pane" >/dev/null 2>&1 || return 0; sleep 2; done
  return 1
}

# restart <link> <why> <transcript>: hold, packet, stop, start that link in the same pane and worktree, release.
restart() {
  local to="$1" why="$2" tr="$3" from pk brief
  from="$(link .link)"
  touch "$seat/changeover-hold"   # bin/compact-watch.sh and bin/compact-now.sh both stand off while it exists
  pk="$(packet "$tr")"
  brief="$seat/takeover-brief.txt"
  printf 'You are taking over seat %s on workflow %s%s from link %s after: %s. Read the handover packet at %s first, then continue the work on this worktree, %s.' \
    "$(link .seat)" "$(link .workflow)" "$( [ -n "$(link '.ticket // ""')" ] && printf ', ticket %s,' "$(link .ticket)")" \
    "$(link .link_id)" "$why" "$pk" "$(link .worktree)" > "$brief"
  if ! stop_seat; then
    rm -f "$seat/changeover-hold"; touch "$seat/failover-stopped"
    wf_watch_log "ALERT $pane would not stop for its $why swap; not starting another agent on top of it"
    principal "seat $(link .seat) in $pane would not stop after $why; failover stopped, read $seat/seat-watch.log"
    return 1
  fi
  if "$BIN/workflow-spawn.sh" "$(link .workflow)" "$(link .seat)" --link "$to" --pane "$pane" \
       ${TICKET:+--ticket "$TICKET"} --brief-file "$brief" >> "$seat/swap.log" 2>&1; then
    rm -f "$seat/changeover-hold" "$seat/.resumes"
    wf_watch_log "swap: $pane link $from -> $to ($(link .link_id)) after $why; packet $pk"
    principal "seat $(link .seat) swapped link $from -> $to ($(link .link_id)) after $why; packet $pk"
  else
    rm -f "$seat/changeover-hold"; touch "$seat/failover-stopped"
    wf_watch_log "ALERT starting link $to in $pane failed after $why; read $seat/swap.log"
    principal "seat $(link .seat): starting link $to in $pane failed after $why; failover stopped, read $seat/swap.log"
  fi
}

# swap <why> <transcript>: the next link, or the end of the chain.
swap() {
  local next=$(( $(link .link) + 1 ))
  if [ "$next" -ge "$(link .links)" ]; then
    touch "$seat/failover-stopped"
    wf_watch_log "ALERT chain exhausted for $pane at link $(link .link) ($(link .link_id)) after $1; not swapping"
    principal "seat $(link .seat) in $pane: model chain exhausted at $(link .link_id) after $1; no link left, nothing restarted"
    return
  fi
  restart "$next" "$1" "$2"
}

tick() {
  local tr r why age alive n
  [ -f "$seat/seat-link" ] || { wf_watch_change state "seat: no seat-link for $pane; start it with bin/workflow-spawn.sh"; return; }
  [ -f "$seat/PAUSED" ] && { wf_watch_change state "paused: since $(cat "$seat/PAUSED")"; return; }
  # BREADCRUMB - a seat retired on its done record stays retired until the spawner writes a new seat-link.
  # What broke: a watcher re-armed on a pane whose seat had recorded done and been sent /exit read that seat as dead and
  #   restarted it, then told the principal it had swapped (found by test_seat_watch.sh, 2026-09-22).
  # Why this fix: seat-done is touched at retirement and only a newer seat-link, which only a real start writes, outranks
  #   it. Rejected: deleting seat-link on done, which throws away the record of what ran for the next reader.
  # Cost: none.
  if [ "$seat/seat-done" -nt "$seat/seat-link" ]; then wf_watch_change state "done: $(link .seat) already retired"; DONE=1; return; fi
  TICKET="$(link '.ticket // ""')"
  if r="$(done_row)"; then
    touch "$seat/seat-done"
    wf_watch_log "done: $(link .seat) ${TICKET:+$TICKET }$r"
    principal "seat $(link .seat) done${TICKET:+ on $TICKET}: $r"
    # BREADCRUMB - a seat that has recorded done is retired here, not trusted to exit.
    # What broke: every brief says "when your work is done, report it and exit", and seats keep ignoring it; a finished
    #   seat left alive holds its pane, its name and its worktree (orchestrator review of 17616c9, 2026-09-22).
    # Why this fix: bearings-v2 dispatch-seat.sh retired its seats with /exit once their record landed (2026-09-21), and
    #   the record is the seat's own statement that nothing is left to do, so the /exit cannot cut work short.
    #   Rejected: waiting for the seat to exit on its own, which is what already fails.
    # Cost: a seat cannot keep talking after its record; anything after it belongs in a new seat.
    if stop_seat; then wf_watch_log "retired: $(link .seat) in $pane exited after its done record"; TEARDOWN=1
    else wf_watch_log "ALERT $(link .seat) in $pane recorded done but would not exit; read it with herdr pane read $pane"; fi
    DONE=1; return
  fi
  [ -f "$seat/failover-stopped" ] && { wf_watch_change state "stopped: failover off for $pane; waiting for a done record only"; return; }
  [ -f "$seat/changeover-hold" ] && { wf_watch_change state "hold: a changeover owns $pane"; return; }

  tr="$(wf_transcript "$pane" || true)"
  alive=0; herdr agent get "$pane" >/dev/null 2>&1 && alive=1
  if [ "$alive" = 1 ] && [ -n "$tr" ] && why="$(api_exhausted "$tr")" && [ -n "$why" ]; then
    swap "api error: $why" "$tr"; return
  fi
  # Resuming into a quota wall is the same wall, which is why exhaustion swaps at once and only dead or silent resumes.
  # The age is the transcript's; without one (a codex link) herdr's working status stands in, as dispatch-seat.sh
  # moved its deadline forward while herdr reported working (2026-09-21T03:44Z, a tester backing off a rate limit).
  if [ -n "$tr" ]; then age="$(wf_idle_seconds "$tr")"
  elif [ "$(herdr agent get "$pane" 2>/dev/null | jq -r '.result.agent.agent_status // ""')" = working ]; then age=0
  else age="$(( $(date -u +%s) - $(date -u -d "$(link .started_at)" +%s) ))"; fi
  if [ "$alive" = 1 ] && [ "$age" -le "$STALL" ]; then
    rm -f "$seat/.resumes"; wf_watch_change state "ok: link $(link .link) $(link .link_id), last activity ${age}s ago"; return
  fi
  why="dead"; [ "$alive" = 1 ] && why="silent ${age}s"
  n=$(( $(cat "$seat/.resumes" 2>/dev/null || echo 0) + 1 ))
  if [ "$n" -gt "$TRIES" ]; then swap "$why after $TRIES resumes" "$tr"; return; fi
  echo "$n" > "$seat/.resumes"
  if [ "$alive" = 1 ]; then
    herdr agent prompt "$pane" "No activity from you for ${age} seconds. Continue your current step; if you are finished, write your record and exit." >/dev/null 2>&1
    wf_watch_log "resume: $pane $why, prompted to continue (attempt $n of $TRIES)"
  else
    wf_watch_log "resume: $pane $why, restarting link $(link .link) (attempt $n of $TRIES)"
    restart "$(link .link)" "$why" "$tr"
  fi
}

# BREADCRUMB - a retired seat takes its debris with it: every watcher on its pane, their monitor panes, and its tab.
# What broke: the live smoke seat retired at 2026-09-22T22:28:02Z and left its compaction watcher running in wC1:pD, this
#   watcher's pane wC1:pE, the finished gate watcher's pane wC1:pF, and tab agent-smoke holding an empty shell
#   (orchestrator review, 22:28Z). bearings-v2 bin/down.sh tore all of that down; the port had not.
# Why this fix: only a seat that recorded done AND exited is torn down, so nothing a live seat needs is closed. Everything
#   goes through watch-ctl.sh, the one switch, with --close for the monitor pane. The workflow's gate watcher is shared
#   per workflow id, so it is left alone while any other live seat runs that workflow. The seat's tab is closed only if
#   its sole pane is the seat's and holds no agent. This watcher is last, by exec, because stopping it ends this script.
#   Rejected: closing the tab outright, which would take any pane the owner opened beside the seat.
# Cost: the owner can no longer scroll a retired seat's pane; the transcript and the seat dir keep everything.
teardown() {
  local wf others tab n
  wf="$(link .workflow)"
  "$BIN/watch-ctl.sh" off compact "$pane" --close >/dev/null 2>&1
  others=0
  for l in "$(wf_state_dir)"/seats/*/seat-link; do
    if [ ! -f "$l" ] || [ "$l" = "$seat/seat-link" ]; then continue; fi
    [ "$(jq -r .workflow "$l")" = "$wf" ] || continue
    [ "$(dirname "$l")/seat-done" -nt "$l" ] && continue
    herdr agent get "$(jq -r .pane "$l")" >/dev/null 2>&1 && others=1
  done
  [ "$others" = 1 ] || "$BIN/watch-ctl.sh" off workflow "$wf" --close >/dev/null 2>&1
  tab="$(herdr pane get "$pane" 2>/dev/null | jq -r '.result.pane.tab_id // empty')"
  if [ -n "$tab" ]; then
    n="$(herdr pane list --workspace "${tab%%:*}" 2>/dev/null | jq --arg t "$tab" '[.result.panes[] | select(.tab_id == $t)] | length')"
    if [ "$n" = 1 ] && ! herdr agent get "$pane" >/dev/null 2>&1; then herdr tab close "$tab" >/dev/null 2>&1 || tab=""
    else tab=""; fi
  fi
  wf_watch_log "teardown: $(link .seat) retired; watchers off for $pane$([ "$others" = 1 ] && printf ' (gate watcher kept, another %s seat is live)' "$wf")${tab:+, tab $tab closed}"
}

DONE=0; TEARDOWN=0; TICKET=""
while :; do
  tick
  if [ "$DONE" = 1 ]; then
    wf_watch_state seat-watch ended 0 "$(jq -n --arg s "$(wf_now)" '{stopped_at:$s}')"; trap - EXIT; rm -f "$seat/seat-watch.pid"
    wf_watch_log "watch: seat done, stopping"
    if [ "$TEARDOWN" = 1 ]; then teardown; exec "$BIN/watch-ctl.sh" off seat "$pane" --close >/dev/null 2>&1; fi
    exit 0
  fi
  [ "$once" = 1 ] && exit 0
  sleep "$TICK"
done
