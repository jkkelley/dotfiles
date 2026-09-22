#!/usr/bin/env bash
# after-compact.sh - SessionStart hook, matcher "compact": give the rebuilt session its own state back.
#
# A SessionStart hook's stdout is injected into the fresh context. Without this the seat comes back from a compaction
# knowing only what the summary kept, which is not what it wrote down on purpose. So it prints the seat's newest
# checkpoint - the one it wrote before asking to be compacted - and the rail ledger tail, and names the first act.
#
# The seat is found from HERDR_PANE_ID, which herdr sets in every pane. BREADCRUMB - bearings-v2 after-compact.sh
#   printed one hardcoded project's CHECKPOINT.md into every session, and once printed "loop is running, re-arm the
#   feed" into a session whose loop was paused, so the rebuilt seat had to be told to ignore its own hook. This prints
#   only what is true for this seat, and says plainly when nothing was written. Rejected: printing a project-wide
#   checkpoint, which is the wrong seat's state the moment two seats share a repository.
# Never fails the session: a hook that exits non-zero on the way back from compaction is worse than a quiet one.
set -uo pipefail
# shellcheck source=bin/workflow-lib.sh disable=SC1091
. "$(dirname "$(readlink -f "$0")")/workflow-lib.sh" 2>/dev/null || exit 0
pane="${HERDR_PANE_ID:-}"
[ -n "$pane" ] || { printf 'Compacted outside herdr: no seat checkpoint to restore. Rule 18 expects every seat in a herdr pane.\n'; exit 0; }
seat="$(wf_seat_dir "$pane")"
cp="$(wf_expand "$(wf_cfg '.workflow.skills_dir // "~/.claude/skills"')")/context-compaction/scripts/checkpoint.sh"
printf '%s resumed after compaction\n' "$(wf_now)" >> "$seat/compact.log"
printf 'This seat (herdr pane %s) was just compacted.\n' "$pane"
if bash "$cp" verify --project "$seat" >/dev/null 2>&1; then
  printf 'Your newest checkpoint follows. Read it, state the step it names, then continue from that step. Do not redo finished work.\n\n'
  bash "$cp" read --project "$seat" --top 1 2>/dev/null
else
  printf 'No valid checkpoint at %s/CONTEXT_STATE.md: this was a ceiling compaction or a hand /compact.\n' "$seat"
  printf 'Rebuild state from the rail ledger and git log before acting. Do not guess.\n'
fi
if [ -x "$WF_REPO/report/rail.sh" ]; then printf '\nRail ledger, last 5 rows:\n'; "$WF_REPO/report/rail.sh" show 5 2>/dev/null; fi
exit 0
