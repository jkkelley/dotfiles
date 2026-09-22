#!/usr/bin/env bash
# compact-now.sh <pane> [--no-checkpoint] [--dry-run] - run the compaction ceremony on one seat, hands off.
#
# Order, and why each step is where it is:
#   1. --dry-run is decided before any side effect. bearings-v2 compact-now.sh once checked it below a kill loop,
#      so a dry run killed the live feed while the owner was reading (its breadcrumb, 2026-09-21T03:28Z).
#   2. A model changeover in flight holds the ceremony. Two sends racing into one prompt corrupt both.
#   3. The seat's checkpoint must verify, unless --no-checkpoint (the ceiling backstop only). Compacting a seat whose
#      state was never written down is how a plan is lost; the checkpoint format belongs to the context-compaction
#      skill and is not reimplemented here.
#   4. Idle gate from the transcript's mtime. A slash command only executes at an idle prompt; sent mid-turn it lands
#      as prose and compacts nothing.
#   5. ONE bare `/compact`. Never an argument: `/compact <text>` is submitted as content whichever way it is typed
#      (three failures of evidence in bearings-v2, 2026-09-21T04:42Z). What must survive lives in the checkpoint.
#   6. Proof is a new "subtype":"compact_boundary" line in the transcript, waited for up to 600 s. Never a resend:
#      a retry lands in the fresh session and is the double-compaction defect (bearings-v2, 2026-09-21T18:4xZ).
#   7. The ceremony report is written by this script, synchronously, from transcript rows alone - one send and one
#      boundary is OK, anything else is DEFECT. bearings-v2 watched in a backgrounded subshell; dotfiles Rule 18
#      forbids that, and the ceremony already blocks until its proof, so the watch belongs inline.
#
# Exit: 0 compacted, 1 no proof within the wait, 2 usage, 3 checkpoint missing or invalid, 4 seat never idle, 5 held.
set -uo pipefail
# shellcheck source=bin/workflow-lib.sh disable=SC1091
. "$(dirname "$(readlink -f "$0")")/workflow-lib.sh"
wf_need jq

pane=""; dry=0; nocp=0
for a in "$@"; do
  case "$a" in --dry-run) dry=1 ;; --no-checkpoint) nocp=1 ;; -*) wf_die "unknown flag $a" ;; *) pane="$a" ;; esac
done
[ -n "$pane" ] || { printf 'usage: compact-now.sh <pane> [--no-checkpoint] [--dry-run]\n' >&2; exit 2; }

tr="$(wf_transcript "$pane")" || wf_die "no transcript for $pane; is an agent running there?"
seat="$(wf_seat_dir "$pane")"
cp="$(wf_expand "$(wf_cfg '.workflow.skills_dir // "~/.claude/skills"')")/context-compaction/scripts/checkpoint.sh"
idle_need="$(wf_cfg '.workflow.watchers.idle_seconds // 45')"
wait_s="${COMPACT_WAIT_SECONDS:-600}"
log="$seat/compact.log"
say() { printf '%s %s\n' "$(wf_now)" "$*" | tee -a "$log"; }

if [ "$dry" = 1 ]; then
  printf 'dry run, nothing sent. pane %s, transcript %s, context %s%%, boundaries %s, idle %ss (need %s)\n' \
    "$pane" "$tr" "$(wf_context_pct "$tr")" "$(wf_boundaries "$tr")" "$(wf_idle_seconds "$tr")" "$idle_need"
  [ -f "$seat/changeover-hold" ] && printf 'would HOLD: model changeover in progress\n'
  if [ "$nocp" = 0 ]; then
    bash "$cp" verify --project "$seat" >/dev/null 2>&1 && printf 'checkpoint: verifies\n' || printf 'checkpoint: MISSING or invalid, the real run would stop here\n'
  fi
  exit 0
fi

[ -f "$seat/changeover-hold" ] && { say "held: model changeover in progress, not compacting"; exit 5; }

if [ "$nocp" = 0 ]; then
  bash "$cp" verify --project "$seat" >/dev/null 2>&1 \
    || { say "refused: seat checkpoint at $seat/CONTEXT_STATE.md missing or invalid; see runbooks/RB-compaction.md"; exit 3; }
fi

waited=0
while [ "$(wf_idle_seconds "$tr")" -lt "$idle_need" ]; do
  [ "$waited" -lt 600 ] || { say "blocked: seat never idle within 600 s; nothing sent"; exit 4; }
  sleep 10; waited=$((waited + 10))
done

pct="$(wf_context_pct "$tr")"
b0="$(wf_boundaries "$tr")"; s0="$(grep -c '"content":"/compact' "$tr" 2>/dev/null || true)"
say "sending /compact to $pane at ${pct}%, boundaries before $b0"
herdr agent prompt "$pane" "/compact" >/dev/null 2>&1 || { say "herdr prompt failed; nothing sent"; exit 1; }

rc=1
for (( t = 0; t < wait_s; t += 5 )); do
  sleep 5
  [ "$(wf_boundaries "$tr")" -gt "$b0" ] && { rc=0; break; }
done
b1="$(wf_boundaries "$tr")"; s1="$(grep -c '"content":"/compact' "$tr" 2>/dev/null || true)"
nb=$(( b1 - b0 )); ns=$(( s1 - s0 ))

# Only the raw prompt row matches "content":"/compact. Claude Code also writes a <command-name>/compact</command-name>
# block for the same submission, which the mobile app draws as a second bubble (bearings-v2 RB-seat-compaction,
# 2026-09-21T19:53Z); that block does not match this pattern, so one submission counts once.
verdict=OK; why=""
[ "$nb" -eq 1 ] || { verdict=DEFECT; why="$why boundaries=$nb"; }
[ "$ns" -le 1 ] || { verdict=DEFECT; why="$why sends=$ns"; }
rep="$seat/ceremony-compact-$(date -u +%Y%m%dT%H%M%SZ).md"
{ printf '# Compaction ceremony, %s\n\nVerdict: **%s**%s\n\n' "$pane" "$verdict" "${why:+ (${why# })}"
  printf -- '- context before: %s%%\n- boundaries: %s -> %s\n- submissions: %s\n- transcript: %s\n' "$pct" "$b0" "$b1" "$ns" "$tr"
} > "$rep"
ln -sfn "$rep" "$seat/ceremony-compact.md"

if [ "$rc" = 0 ]; then say "compacted: boundary $b1, verdict $verdict, report $rep"; [ "$verdict" = OK ] || rc=1
else say "no compact_boundary within ${wait_s} s; NOT resending; verdict $verdict, report $rep"; fi
exit "$rc"
