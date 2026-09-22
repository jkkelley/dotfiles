#!/usr/bin/env bash
# Proves the compaction set does what its runbook promises, against a stub herdr and a fixture transcript.
#
# Each check names the failure it rules out:
#   - a dry run that sends anything (bearings-v2 killed a live feed from --dry-run, 2026-09-21T03:28Z)
#   - compacting a seat whose checkpoint does not verify (its work in flight is lost)
#   - compacting into a model changeover (two sends racing into one prompt)
#   - resending when proof is late (the double-compaction defect, bearings-v2 2026-09-21T18:4xZ)
#   - a watcher that compacts at the threshold instead of asking the seat to checkpoint first
#   - a watcher or switch that runs outside herdr (Rule 18)
# Hermetic: herdr is a stub on PATH, the clock is real but the waits are shortened by config.
set -uo pipefail
R="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
REPO="$(cd "$R/../.." && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
fail=0; n=0
ok()  { n=$((n+1)); printf 'ok  %s\n' "$1"; }
bad() { n=$((n+1)); fail=1; printf 'FAIL %s\n' "$1"; [ $# -gt 1 ] && printf '     %s\n' "${@:2}"; }
check() { local want="$1" got="$2" label="$3"; if [ "$want" = "$got" ]; then ok "$label"; else bad "$label" "wanted [$want] got [$got]"; fi; }
holds() { local label="$1"; shift; if "$@"; then ok "$label"; else bad "$label"; fi; }

# ---- stub herdr: records every call; `agent prompt ... /compact` writes a boundary when STUB_BOUNDARY=1
mkdir -p "$T/bin" "$T/projects/p"
cat > "$T/bin/herdr" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$STUB_LOG"
case "$1 $2" in
  "agent get") printf '{"result":{"agent":{"agent_session":{"value":"sess-1"}}}}\n' ;;
  "agent prompt")
    if [ "$4" = "/compact" ] || [ "$3" = "/compact" ]; then
      printf '{"type":"user","message":{"role":"user","content":"/compact"}}\n' >> "$STUB_TR"
      [ "${STUB_BOUNDARY:-1}" = 1 ] && printf '{"type":"system","subtype":"compact_boundary"}\n' >> "$STUB_TR"
    fi ;;
  "workspace list") printf '{"result":{"workspaces":[]}}\n' ;;
esac
exit 0
STUB
chmod +x "$T/bin/herdr"
export PATH="$T/bin:$PATH" STUB_LOG="$T/herdr.log" STUB_TR="$T/projects/p/sess-1.jsonl" WF_PROJECTS_DIR="$T/projects"
jq --arg s "$T/state" --arg k "$REPO/claude/skills" \
  '.project.state_dir=$s | .workflow.skills_dir=$k | .workflow.watchers.idle_seconds=5
   | .workflow.compaction.cooldown_seconds=60 | .workflow.compaction.tick_seconds=5' \
  "$R/config/project.json" > "$T/config.json"
export WORKFLOW_CONFIG="$T/config.json"
CP="$REPO/claude/skills/context-compaction/scripts/checkpoint.sh"
PANE="wX1:p9"; SEAT="$T/state/seats/wX1_p9"

transcript() { # transcript <percent>: one assistant usage row at that percent of a 1M window
  printf '{"type":"assistant","message":{"model":"claude-opus-5-5","usage":{"input_tokens":0,"cache_read_input_tokens":%s,"cache_creation_input_tokens":0}}}\n' "$(( $1 * 10000 ))" > "$STUB_TR"
  touch -d '10 minutes ago' "$STUB_TR"
}
sends() { grep -c '^agent prompt .*/compact$' "$STUB_LOG" 2>/dev/null || true; }
reset() { : > "$STUB_LOG"; rm -rf "$T/state"; }

# ---- context percent and transcript resolution
. "$R/bin/workflow-lib.sh"
transcript 42
check 42 "$(wf_context_pct "$STUB_TR")" "context percent counts cached prefix tokens (42% fixture)"
check "$STUB_TR" "$(wf_transcript "$PANE")" "a pane resolves to its own transcript through its herdr session id"

# ---- compact-now
reset; transcript 40
"$R/bin/compact-now.sh" "$PANE" --dry-run >/dev/null 2>&1
check 0 "$(sends)" "a dry run sends nothing"

reset; transcript 40
"$R/bin/compact-now.sh" "$PANE" >/dev/null 2>&1; rc=$?
check 3 "$rc" "no verified checkpoint: refused with exit 3"
check 0 "$(sends)" "no verified checkpoint: nothing sent"

write_checkpoint() {
  mkdir -p "$SEAT"; bash "$CP" init --project "$SEAT" >/dev/null 2>&1
  printf '#### Infrastructure\n- none\n#### Toolchain\n- bash\n#### Active Tasks\n- O-09 test\n#### Blockers\n- none\n### Hydration prompt\nContinue O-09.\n' > "$T/body.md"
  bash "$CP" new --project "$SEAT" --body-file "$T/body.md" >/dev/null 2>&1
}
reset; transcript 40; write_checkpoint; touch "$SEAT/changeover-hold"
"$R/bin/compact-now.sh" "$PANE" >/dev/null 2>&1; rc=$?
check 5 "$rc" "a model changeover in flight holds the ceremony (exit 5)"
check 0 "$(sends)" "held: nothing sent"

reset; transcript 40; write_checkpoint
"$R/bin/compact-now.sh" "$PANE" >/dev/null 2>&1; rc=$?
check 0 "$rc" "verified checkpoint, idle seat: compacted"
check 1 "$(sends)" "exactly one /compact sent"
holds "ceremony report verdict OK" grep -q 'Verdict: \*\*OK\*\*' "$SEAT/ceremony-compact.md"

reset; transcript 40; write_checkpoint
STUB_BOUNDARY=0 COMPACT_WAIT_SECONDS=5 "$R/bin/compact-now.sh" "$PANE" >/dev/null 2>&1; rc=$?
check 1 "$rc" "no boundary within the wait: exit 1"
check 1 "$(sends)" "no boundary within the wait: never resent"

# ---- compact-watch
reset; transcript 40
env -u HERDR_ENV "$R/bin/compact-watch.sh" "$PANE" --once >/dev/null 2>&1; rc=$?
check 1 "$rc" "compact-watch refuses outside herdr"

reset; transcript 10
HERDR_ENV=1 "$R/bin/compact-watch.sh" "$PANE" --once >/dev/null 2>&1
check 0 "$(grep -c '^agent prompt' "$STUB_LOG" 2>/dev/null || true)" "under the threshold: the seat is left alone"

reset; transcript 40
HERDR_ENV=1 "$R/bin/compact-watch.sh" "$PANE" --once >/dev/null 2>&1
check 0 "$(sends)" "over the threshold without a request: no /compact"
holds "over the threshold: the seat is nudged to checkpoint first" grep -q '^agent prompt .*Finish the step you are on' "$STUB_LOG"

reset; transcript 40; write_checkpoint; touch "$SEAT/compact-request"
HERDR_ENV=1 "$R/bin/compact-watch.sh" "$PANE" --once >/dev/null 2>&1
check 1 "$(sends)" "request plus checkpoint at idle: compacted once"
holds "the request is consumed" test ! -f "$SEAT/compact-request"

reset; transcript 90
HERDR_ENV=1 "$R/bin/compact-watch.sh" "$PANE" --once >/dev/null 2>&1
check 1 "$(sends)" "at the ceiling with no request: forced once"
holds "at the ceiling: ALERT logged for the owner" grep -q 'ALERT' "$SEAT/compact-watch.log"

# ---- switches and hook
env -u HERDR_ENV "$R/bin/watch-ctl.sh" on compact "$PANE" >/dev/null 2>&1; rc=$?
check 1 "$rc" "watch-ctl on refuses outside herdr"
env -u HERDR_ENV "$R/bin/workflow-watch.sh" compaction run >/dev/null 2>&1; rc=$?
check 1 "$rc" "workflow-watch run refuses outside herdr"

reset; transcript 5; write_checkpoint
out="$(HERDR_PANE_ID="$PANE" "$R/bin/after-compact.sh" 2>&1)"; rc=$?
check 0 "$rc" "after-compact never fails the session"
holds "after-compact prints the seat's own newest checkpoint" grep -q 'Continue O-09' <<<"$out"
out="$(env -u HERDR_PANE_ID "$R/bin/after-compact.sh" 2>&1)"; rc=$?
check 0 "$rc" "after-compact outside herdr still exits 0"

out="$(env -u HERDR_ENV "$R/bin/session-arm.sh" 2>&1)"; rc=$?
check 0 "$rc" "session-arm never fails the session"
holds "session-arm outside herdr arms nothing and says why" grep -q 'not armed' <<<"$out"

[ "$fail" = 0 ] && echo "ok  compaction: $n checks" || echo "FAIL compaction: see above ($n checks)"
exit "$fail"
