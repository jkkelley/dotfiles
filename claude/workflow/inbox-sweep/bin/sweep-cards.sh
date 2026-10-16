#!/usr/bin/env bash
# shellcheck disable=SC2016 # jq filters use $var; they are jq variables, single quotes are the point
# sweep-cards.sh - R6 of the inbox sweep: turn a finished run's results into Getting My Bearings cards.
#
#   sweep-cards.sh --run <run-id>
#
# Three kinds of card, each with a stable id so a rerun adds nothing (spec script `sweep-cards.sh`, design section 5 R6):
#   owner_decisions[]   IS-<run>-<seat>-<Qn>   about/decide/options/rec copied from the seat's own record
#   drafts[]            IS-<run>-<seat>-<Dn>   decide carries the FULL draft text: the owner approves what they read
#   BLOCKED-* seat or   IS-<run>-<seat>-B-<code>  one per code per run, however many seats hit it; the card is keyed to
#   PF-NO-BROWSER /     IS-<run>-preflight-B-<code>  the first seat (by name) with that code and names the others
#   PF-NO-CHROME
# The spec writes the blocked suffix as plain `B`. It is `B-<code>` here because one seat can be blocked by one code but a
# run can be blocked by several, and the preflight has no seat at all; sweep-proof.sh already uses `B-CLEAN-ORPHAN-TAB`.
#
# Merge: read the current questions.json, append only ids not already present, write through sweep_json_set. Existing
# items are never edited or removed, so an answered card keeps its id. Nothing here sends, replies or posts (design D7).
#
# Server: if <bearings dir>/server.json is absent, start the Bearings server in a new herdr pane labeled
# bearings-inbox-sweep (split, rename, run). Never a background job (CLAUDE.md Rule 18): the owner watches herdr.
# A server that cannot be started is logged, not fatal; the cards are already on disk and the next run tries again.
#
# Exit: 0 cards merged; 2 usage; 3 precondition (no such run, no summary.json).
#
# Environment (tests point these at a sandbox):
#   SWEEP_RUNS_ROOT       default <win-home>/.local/state/zenith/inbox-sweep/runs
#   SWEEP_CARDS_FILE      default ~/.bearings/inbox-sweep/questions.json; server.json is looked up beside it
#   SWEEP_BEARINGS_SERVER default ~/.claude/skills/bearings/scripts/server.mjs
#   SWEEP_HERDR_WORKSPACE herdr workspace label to put the server pane in (default dotfiles)
#
# Design: docs/design/inbox-sweep.md section 5 (R6), spec node `scripts` / `sweep-cards.sh`, build node B7.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=sweep-lib.sh
. "$HERE/sweep-lib.sh"

usage() { echo "usage: sweep-cards.sh --run <run-id>" >&2; exit 2; }
if [ $# -ne 2 ] || [ "$1" != --run ]; then usage; fi
run="$2"
[[ $run =~ ^[0-9]{8}T[0-9]{6}Z$ ]] || { echo "sweep-cards: bad run id '$run'" >&2; exit 2; }

root="${SWEEP_RUNS_ROOT:-$(sweep_win_home)/.local/state/zenith/inbox-sweep/runs}"
RUN_DIR="$root/$run"
CARDS="${SWEEP_CARDS_FILE:-$HOME/.bearings/inbox-sweep/questions.json}"
SERVER_JS="${SWEEP_BEARINGS_SERVER:-$HOME/.claude/skills/bearings/scripts/server.mjs}"
[ -f "$RUN_DIR/summary.json" ] || { echo "sweep-cards: no summary.json in $RUN_DIR" >&2; exit 3; }
export SWEEP_RUN_DIR="$RUN_DIR"
mkdir -p "$RUN_DIR/logs" "$(dirname "$CARDS")"
LOG="$RUN_DIR/logs/cards.log"
log() { printf '%s %s\n' "$(sweep_now)" "$*" >>"$LOG"; }

# What each blocked code asks of the owner. The action text is from the spec code map ("acts" column).
decide_for() {
  case "$1" in
    BLOCKED-NO-BROWSER | PF-NO-BROWSER) echo "Chrome has no connected Claude extension. Open the Claude side panel once to wake it, then say so." ;;
    PF-NO-CHROME) echo "Chrome is not running. Start Chrome in your own profile, then say so." ;;
    BLOCKED-SIGNED-OUT) echo "The site showed a login page. Sign in in your own Chrome, then say so." ;;
    BLOCKED-CHALLENGE) echo "The site asked for 2FA, a CAPTCHA or a security check. Clear it in your own Chrome, then say so." ;;
    BLOCKED-CONNECTOR) echo "The Gmail connector is absent or unauthorised. Reconnect it in claude.ai, then say so." ;;
  esac
}

# Candidate cards as one JSON array. Seat results that do not parse are skipped, not fatal: sweep-watch.sh already
# turned those into FAILED-SCHEMA, which the orchestrator owns.
candidates="$(
  {
    for f in "$RUN_DIR"/results/*.json; do
      [ -f "$f" ] || continue
      jq -c --arg run "$run" '
        . as $r
        | ( .owner_decisions[]? | {id:("IS-\($run)-\($r.seat)-\(.id)"), about:("\($r.source) \($r.account): \(.about)"),
              decide:.decide, options:.options, rec:.rec} ),
          ( .drafts[]? | {id:("IS-\($run)-\($r.seat)-\(.id)"), about:("LinkedIn reply to \(.to) in \(.conversation)"),
              decide:("Approve this draft? Full text: " + .draft_text),
              options:[{label:"Approve",then:"You send it yourself; the sweep never sends"},
                       {label:"Edit",then:"Put your words in the answer box"},
                       {label:"Drop",then:"No reply"}], rec:0} )' "$f" 2>>"$LOG" || log "skipped unreadable result $f"
    done
    # Blocked cards: group by code, keyed to the first seat by name, and name the rest.
    for f in "$RUN_DIR"/results/*.json; do
      if [ -f "$f" ]; then jq -c '{seat, source, status}' "$f" 2>/dev/null || true; fi
    done | jq -sc --arg run "$run" '
        map(select(.status | startswith("BLOCKED-"))) | group_by(.status)[]
        | sort_by(.seat) | . as $g | $g[0] as $f
        | {code:$f.status, seat:$f.seat, source:$f.source, others:([$g[1:][].seat])}' |
      while IFS= read -r g; do
        code="$(jq -r .code <<<"$g")"
        jq -c --arg run "$run" --arg decide "$(decide_for "$code")" --arg src "$(jq -r .source <<<"$g")" '
          {id:("IS-\($run)-\(.seat)-B-\(.code)"),
           about:("Inbox sweep \($run): \(.code)" + (if (.others | length) > 0 then " (also " + (.others | join(", ")) + ")" else "" end)),
           decide:$decide,
           options:[{label:"Done, rerun",then:("Orchestrator runs make sweep-" + $src)},
                    {label:"Skip today",then:"Seat stays blocked until the next run"}], rec:0}' <<<"$g"
      done
    if [ -f "$RUN_DIR/preflight.json" ]; then
      jq -c --arg run "$run" '
        [.checks[]? | select(.code == "PF-NO-BROWSER" or .code == "PF-NO-CHROME") | .code] | unique[] as $c
        | {id:("IS-\($run)-preflight-B-\($c)"), about:("Inbox sweep \($run): \($c)"), code:$c}' "$RUN_DIR/preflight.json" |
        while IFS= read -r g; do
          code="$(jq -r .code <<<"$g")"
          jq -c --arg decide "$(decide_for "$code")" 'del(.code) + {decide:$decide,
            options:[{label:"Done, rerun",then:"Orchestrator runs make sweep"},
                     {label:"Skip today",then:"Browser seats stay skipped until the next run"}], rec:0}' <<<"$g"
        done
    fi
  } | jq -sc 'unique_by(.id)'
)"

[ -f "$CARDS" ] || echo '{"title":"Inbox sweep","items":[]}' >"$CARDS"
before="$(jq '.items | length' "$CARDS")"
sweep_json_set "$CARDS" '.items += ([$c[] | select(.id as $i | ($cur | index($i)) == null)] | map(. + {asked:$at}))' \
  --argjson c "$candidates" --argjson cur "$(jq -c '[.items[].id]' "$CARDS")" --arg at "$(sweep_now)"
after="$(jq '.items | length' "$CARDS")"
log "candidates $(jq length <<<"$candidates"), items before $before, after $after, added $((after - before))"

# Checklist proofs (spec R6): ids unique; one card per BLOCKED code.
if [ "$(jq '[.items[].id] | length == (unique | length)' "$CARDS")" = true ]; then
  log "ids unique: yes"
  sweep_check R6 "ids unique" "logs/cards.log" || true
else
  log "ids unique: NO"
fi
codes="$(jq -s '[.[] | select(.status | startswith("BLOCKED-")) | .status] | unique | length' "$RUN_DIR"/results/*.json 2>/dev/null || echo 0)"
cards="$(jq --arg run "IS-$run-" '[.items[] | select((.id | startswith($run)) and (.id | test("-B-BLOCKED-")))] | length' "$CARDS")"
log "BLOCKED codes $codes, BLOCKED cards $cards"
sweep_check R6 "one card per BLOCKED code" "logs/cards.log" || true

# Server: only when nothing is serving. Labeled pane, never a background job (sweep_bearings_server, sweep-lib.sh).
sweep_bearings_server "$CARDS" "$SERVER_JS"
echo "cards: $((after - before)) added, $after total"
