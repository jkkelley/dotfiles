#!/usr/bin/env bash
# name: a2a-deliver.sh
# purpose: no-model consumer of the a2a queue: one pointer line per idle seat with an empty input line.
# outputs: stdout one status code line per seat, exit code
# a2a-deliver.sh - the no-model consumer of the a2a queue: a seat gets its queued messages as ONE pointer line, and only
#   when herdr says it is idle and its input line is empty. A working seat is never typed into.
#
# usage: a2a-deliver.sh --line LINE [--seat SEAT] [--loop [--interval S]]
#   one pass over every seat queued on LINE (or just SEAT); --loop repeats it, for the line's monitors tab.
# prints one status code line per seat: A2A-DELIVERED, A2A-DELIVERED-RETRIED, A2A-UNCONFIRMED, A2A-HELD (with the reason), A2A-NAME-REFUSED, A2A-DELIVER-FAILED.
# exit: 0 pass done, 2 usage, 4 io.
# inputs: config.json beside this file (A2A_CONFIG), A2A_STATE_DIR, HERDR_BIN.
# writes-to: $A2A_STATE/queue/<line>/<seat>/{delivered,refused}/; herdr agent prompt into idle seats only.
# cleanup: delivered/ and refused/ are pruned by `make a2a-clean OLDER_THAN=` (delivered pointers only, never the store).
#
# BREADCRUMB - why delivery is gated twice and collapsed.
# What broke: P1 of brief BR-20261016-a2a-guard; orders typed into working panes sat in Claude Code's input queue for
#   18-25 min, and a half-typed owner line in a pane would have been clobbered.
# Why this fix: agent_status (herdr's own detection) says whether the agent is working; the visible input line says
#   whether someone is typing. Both must be clear. Several queued messages go as one line, so a seat waking up reads one
#   prompt, not a pile. Rejected: herdr pane send-text, which types raw keys with no notion of the agent's state.
# Cost: the input-line check reads the prompt glyph (config input_prompt_glyph); an agent UI without it is treated as clear.
set -uo pipefail
# shellcheck source=claude/workflow/a2a-guard/a2a-lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/a2a-lib.sh"

line="$A2A_LINE_DEFAULT" seat="" loop=0 interval=15
while [ $# -gt 0 ]; do
  case $1 in
    --line) line=${2:-}; shift 2 ;; --seat) seat=${2:-}; shift 2 ;; --loop) loop=1; shift ;;
    --interval) interval=${2:-}; shift 2 ;;
    -h|--help) sed -n 2,11p "$0"; exit 0 ;;
    *) a2a_die 2 "A2A-USAGE unknown option $1" ;;
  esac
done
[ -n "$line" ] || a2a_die 2 "A2A-USAGE --line is required"
IDLE=$(jq -c '.idle_statuses' "$A2A_CFG"); GLYPH=$(a2a_cfg .input_prompt_glyph); KEY=$(a2a_cfg .artifact_key)
SETTLE=${A2A_SETTLE_S:-$(a2a_cfg .settle_s)}

# Only a path artifact.sh minted is delivered: the store format plus the .meta.json it writes beside every JSON artifact.
minted() {
  [[ $1 =~ /$KEY/[0-9]{4}/[0-9]{2}/[0-9]{8}-[0-9]{6}-[a-z0-9-]+\.json$ ]] && [ -f "$1" ] && [ -f "$1.meta.json" ]
}

# input_line <pane> -> what is typed in the agent's input box, whitespace and nbsp stripped; empty when clear.
# The box is the glyph line directly under a rule line (Claude Code draws ─── above and below it). A shell prompt that
# happens to use the same glyph is not under a rule, so `❯ cat >> file` in a plain pane is not mistaken for typing
# (seen in the first UAT run, 2026-10-16T05:24Z: A2A-HELD input-line-not-empty on a pane running cat).
input_line() {
  "$HERDR" pane read "$1" --source visible --lines 60 2>/dev/null \
    | awk -v g="$GLYPH" -v bar="│" '{ t=$0; sub(/^[[:space:]]+/, "", t); if (index(t, bar) == 1) t = substr(t, length(bar) + 1)
        sub(/^[[:space:]]+/, "", t) }
        prev ~ /^─/ && index(t, g) == 1 { last = substr(t, length(g) + 1); found = 1 }
        { prev = t } END { if (found) print last }' \
    | sed 's/\xc2\xa0//g; s/[[:space:]]//g'
}

deliver_seat() { # <seat>
  local s=$1 q info st pane typed f p n=0 ptrs=() files=()
  q=$(a2a_qdir "$line" "$s")
  compgen -G "$q/*.ptr" >/dev/null || return 0
  a2a_lock "$q" || { printf 'A2A-HELD %s lock busy\n' "$s"; return 0; }
  info=$("$HERDR" agent get "$s" 2>/dev/null)
  st=$(printf '%s' "$info" | jq -r '.result.agent.agent_status // "none"' 2>/dev/null); st=${st:-none}
  pane=$(printf '%s' "$info" | jq -r '.result.agent.pane_id // ""' 2>/dev/null)
  if [ -z "$pane" ] || ! jq -e --arg s "$st" 'index($s) != null' <<<"$IDLE" >/dev/null; then
    printf 'A2A-HELD %s status=%s queued=%s\n' "$s" "$st" "$(compgen -G "$q/*.ptr" | wc -l)"; a2a_unlock "$q"; return 0
  fi
  typed=$(input_line "$pane")
  if [ -n "$typed" ]; then printf 'A2A-HELD %s status=%s input-line-not-empty\n' "$s" "$st"; a2a_unlock "$q"; return 0; fi
  mkdir -p "$q/delivered" "$q/refused"
  for f in "$q"/*.ptr; do
    p=$(head -1 "$f")
    if minted "$p"; then ptrs+=("$p"); files+=("$f"); n=$((n + 1))
    else mv "$f" "$q/refused/"; printf 'A2A-NAME-REFUSED %s %s is not a store-minted a2a file\n' "$s" "$p"; fi
  done
  [ $n -gt 0 ] || { a2a_unlock "$q"; return 0; }
  local msg="a2a: $n message(s) for $s, each a schema JSON file; read each and act on it: ${ptrs[*]}"
  if "$HERDR" agent prompt "$pane" "$msg" >/dev/null 2>&1; then
    # BREADCRUMB - confirm the submit (brief BR-20261016-a2a-enter, ORD-0615 O2).
    # What broke: 06:12Z the orchestrator's input sat unsubmitted after Enter was sent twice; the line above was typed
    #   by `agent prompt` and the box never emptied, so the seat never woke and nothing said so.
    # Why this fix: read the pane back; a non-empty box means the Enter was not taken, so send key `enter` (lowercase,
    #   the form that submitted it by hand) once more and recheck. Exactly one retry: a second one could submit a line the
    #   owner started typing. Rejected: retry in a loop, which can double-submit.
    # Cost: one extra pane read per delivery (about one herdr call) after a short settle wait (config settle_s).
    local code=A2A-DELIVERED
    sleep "$SETTLE"
    if [ -n "$(input_line "$pane")" ]; then
      "$HERDR" pane send-keys "$pane" enter >/dev/null 2>&1; sleep "$SETTLE"
      if [ -n "$(input_line "$pane")" ]; then code=A2A-UNCONFIRMED; else code=A2A-DELIVERED-RETRIED; fi
    fi
    mv "${files[@]}" "$q/delivered/"; printf '%s %s pane=%s status=%s count=%s\n' "$code" "$s" "$pane" "$st" "$n"
  else printf 'A2A-DELIVER-FAILED %s pane=%s; still queued\n' "$s" "$pane"; fi
  a2a_unlock "$q"
}

pass() {
  if [ -n "$seat" ]; then deliver_seat "$seat"; return; fi
  local d; for d in "$A2A_STATE/queue/$line"/*/; do [ -d "$d" ] && deliver_seat "$(basename "$d")"; done
}
pass
while [ $loop = 1 ]; do sleep "$interval"; pass; done
exit 0
