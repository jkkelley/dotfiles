#!/usr/bin/env bash
# Proves bin/seat-watch.sh does what runbooks/RB-failover.md promises, against a stub herdr and fixture transcripts.
#
# Each check names the failure it rules out:
#   - a finished seat nobody hears about (S-02 finished 2026-09-22T21:32Z, noticed 21:57Z, rail O-12)
#   - the same done line delivered twice (bearings-v2 monitor-feed.sh dedupes by record id for this reason)
#   - a rate-limited seat left sitting on its wall instead of moving to the next link (owner decision O-06)
#   - a swap that leaves changeover-hold behind, which would stop compaction on that seat forever
#   - a swap past the end of the chain, or an exhausted chain that waits on the owner instead of saying so once
#   - a healthy seat that gets prompted or restarted
#   - gates run in the wrong tree (bin/workflow-watch.sh ran them in $WF_REPO until O-09)
# Hermetic: herdr is a stub on PATH; the real bin/workflow-spawn.sh is driven through it.
set -uo pipefail
R="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
REPO="$(cd "$R/../.." && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
fail=0; n=0
ok()  { n=$((n+1)); printf 'ok  %s\n' "$1"; }
bad() { n=$((n+1)); fail=1; printf 'FAIL %s\n' "$1"; [ $# -gt 1 ] && printf '     %s\n' "${@:2}"; }
check() { if [ "$1" = "$2" ]; then ok "$3"; else bad "$3" "wanted [$1] got [$2]"; fi; }
holds() { local label="$1"; shift; if "$@"; then ok "$label"; else bad "$label"; fi; }

# ---- stub herdr. The seat's pane hosts an agent until it is sent /exit or ctrl+c, and again once one is started.
mkdir -p "$T/bin" "$T/projects/p" "$T/wt"
cat > "$T/bin/herdr" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$STUB_LOG"
case "$1 $2" in
  "agent get")
    case "$3" in
      w*:p*) [ -f "$STUB_DEAD" ] && exit 1
             printf '{"result":{"agent":{"agent_status":"%s","agent_session":{"value":"sess-1"}}}}\n' "${STUB_STATUS:-idle}" ;;
      *) exit 1 ;;
    esac ;;
  "agent prompt") [ "$4" = "/exit" ] && touch "$STUB_DEAD" ;;
  "agent send-keys") case "$*" in *ctrl+c*) touch "$STUB_DEAD" ;; esac ;;
  "agent start"|"agent rename") rm -f "$STUB_DEAD" ;;
  "workspace list") printf '{"result":{"workspaces":[{"workspace_id":"wP","label":"dotfiles"}]}}\n' ;;
  "pane list") printf '{"result":{"panes":[{"pane_id":"wP:p1","label":"claude-main","tab_id":"wP:t1"}]}}\n' ;;
esac
exit 0
STUB
chmod +x "$T/bin/herdr"
export PATH="$T/bin:$PATH" STUB_LOG="$T/herdr.log" STUB_DEAD="$T/dead" WF_PROJECTS_DIR="$T/projects" HERDR_ENV=1
TR="$T/projects/p/sess-1.jsonl"
jq --arg s "$T/state" --arg k "$REPO/claude/skills" --arg w "$T/wt" --arg l "$T/ledger.tsv" \
  '.project.state_dir=$s | .workflow.skills_dir=$k | .workflow.seats |= map(.worktree=$w)
   | .workflow.compaction.auto_arm=false | .workflow.watchers.auto_arm=false
   | .workflow.watchers.stall_seconds=300 | .workflow.watchers.rail_ledger=$l' \
  "$R/config/project.json" > "$T/config.json"
export WORKFLOW_CONFIG="$T/config.json"
PANE="wX:p9"; SEAT="$T/state/seats/wX_p9"; LOGF="$SEAT/seat-watch.log"
started="$(date -u -d '1 minute ago' +%Y-%m-%dT%H:%M:%SZ)"

setup() { # setup <link>: a fresh seat running that link of the architect chain, alive, with a healthy transcript
  : > "$STUB_LOG"; rm -rf "$T/state" "$STUB_DEAD" "$T/ledger.tsv"; mkdir -p "$SEAT"
  jq -n --argjson l "$1" --arg at "$started" --arg wt "$T/wt" --arg p "$PANE" \
    '{workflow:"architect", seat:"architect", ticket:"O-99", link:$l, links:3,
      link_id:(["kimi-k3","opus","codex-sol"][$l]), launcher:"x", herdr_kind:"claude", model:null, surface:"lavish",
      worktree:$wt, pane:$p, started_at:$at}' > "$SEAT/seat-link"
  printf '{"type":"user","message":{"role":"user","content":"Architect O-99 and write its test plan."}}\n' > "$TR"
  printf '{"type":"assistant","message":{"model":"k3","stop_reason":"tool_use","content":[{"type":"text","text":"Reading the tree."}]}}\n' >> "$TR"
}
rate_limited() {
  printf '{"type":"assistant","isApiErrorMessage":true,"error":"rate_limit","message":{"model":"<synthetic>","content":[{"type":"text","text":"API Error: 429 rate limit exceeded"}]}}\n' >> "$TR"
}
watch() { "$R/bin/seat-watch.sh" "$PANE" --once >/dev/null 2>&1; }
to_principal() { grep -c '^agent prompt wP:p1 ' "$STUB_LOG" 2>/dev/null || true; }
starts() { grep -c '^agent start\|^pane run wX:p9 kimi-claude' "$STUB_LOG" 2>/dev/null || true; }

# ---- refuses outside herdr
setup 0
env -u HERDR_ENV "$R/bin/seat-watch.sh" "$PANE" --once >/dev/null 2>&1; rc=$?
check 1 "$rc" "seat-watch refuses outside herdr (Rule 18)"

# ---- healthy
setup 0; STUB_STATUS=working watch
check 0 "$(grep -c '^agent prompt' "$STUB_LOG" || true)" "a healthy working seat is never prompted"
check 0 "$(starts)" "a healthy working seat is never restarted"

# ---- done, from the seat's own record
setup 0; mkdir -p "$T/state/records"
printf '{"schema_version":"1.0.0","workflow":"architect","at":"2020-01-01T00:00:00Z","ticket":"O-99","outcome":"planned","note":"an old run"}\n' > "$T/state/records/architect.jsonl"
watch
check 0 "$(to_principal)" "a record older than this link is not this seat's done"
printf '{"schema_version":"1.0.0","workflow":"architect","at":"%s","ticket":"O-99","outcome":"planned","note":"test plan in work-orders"}\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$T/state/records/architect.jsonl"
watch
check 1 "$(to_principal)" "done: the principal is prompted when the seat's record lands"
holds "done: the line names seat, ticket and the report's first line" grep -q '^agent prompt wP:p1 seat architect done on O-99: planned O-99: test plan in work-orders' "$STUB_LOG"
holds "done: the watcher ends itself" grep -q '"state": *"ended"' "$SEAT/seat-watch.state.json"
watch
check 1 "$(to_principal)" "done: the same record is never announced twice"

setup 0
printf 'at_utc\tstep\tstatus\ttext\tby\tref\n%s\tO-99\tcomplete\tplan written\tarchitect\t\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$T/ledger.tsv"
watch
holds "done: a rail ledger complete row by this seat counts" grep -q '^agent prompt wP:p1 seat architect done on O-99: O-99 complete: plan written' "$STUB_LOG"

# ---- 429 on link 0: hot swap to opus
setup 0; rate_limited; watch
check 1 "$(jq -r .link "$SEAT/seat-link")" "429: the seat moves from link 0 to link 1"
check opus "$(jq -r .link_id "$SEAT/seat-link")" "429: link 1 is opus"
holds "429: the old agent was told to /exit first" grep -q '^agent prompt wX:p9 /exit$' "$STUB_LOG"
holds "429: opus starts in the same pane" grep -q '^agent start architect --kind claude --pane wX:p9 .*--model claude-opus-5-5' "$STUB_LOG"
holds "429: a handover packet was written" test -s "$SEAT/handover.md"
holds "429: the packet carries the last brief" grep -q 'Architect O-99 and write its test plan' "$SEAT/handover.md"
holds "429: the new link's brief points at the packet" grep -q "Read the handover packet at $SEAT/handover-" "$STUB_LOG"
holds "429: changeover-hold is cleared, so compaction resumes" test ! -f "$SEAT/changeover-hold"
holds "429: the principal hears one line" grep -q '^agent prompt wP:p1 seat architect swapped link 0 -> 1 (opus) after api error' "$STUB_LOG"
check 0 "$(grep -c ALERT "$LOGF")" "429 with links left: no ALERT, the owner is not needed"

# ---- the packet prefers a verified checkpoint
setup 0; rate_limited
bash "$REPO/claude/skills/context-compaction/scripts/checkpoint.sh" init --project "$SEAT" >/dev/null 2>&1
printf '#### Infrastructure\n- none\n#### Toolchain\n- bash\n#### Active Tasks\n- O-99 plan\n#### Blockers\n- none\n### Hydration prompt\nContinue O-99 from the checkpoint.\n' > "$T/body.md"
bash "$REPO/claude/skills/context-compaction/scripts/checkpoint.sh" new --project "$SEAT" --body-file "$T/body.md" >/dev/null 2>&1
watch
holds "a verified checkpoint is the packet" grep -q 'Continue O-99 from the checkpoint' "$SEAT/handover.md"

# ---- link 2 exhausted: ALERT once, never swap
setup 2; rate_limited; watch
check 0 "$(starts)" "exhausted chain: nothing is started"
check 1 "$(grep -c 'ALERT chain exhausted' "$LOGF")" "exhausted chain: ALERT for the owner"
holds "exhausted chain: the principal is told" grep -q '^agent prompt wP:p1 .*model chain exhausted at codex-sol' "$STUB_LOG"
watch
check 1 "$(grep -c 'ALERT' "$LOGF")" "exhausted chain: the ALERT is not repeated"
check 2 "$(jq -r .link "$SEAT/seat-link")" "exhausted chain: the seat-link is untouched"

# ---- silent, then resumes exhausted, then swap
setup 0; touch -d '20 minutes ago' "$TR"; watch
holds "silent: the seat is prompted to continue" grep -q '^agent prompt wX:p9 No activity from you' "$STUB_LOG"
check 1 "$(cat "$SEAT/.resumes")" "silent: one resume counted"
check 0 "$(starts)" "silent: a resume does not restart the seat"
setup 0; touch -d '20 minutes ago' "$TR"; echo 3 > "$SEAT/.resumes"; watch
check 1 "$(jq -r .link "$SEAT/seat-link")" "silent after 3 resumes: swap to the next link, as bearings escalated after 3"

# ---- dead: restart the same link
setup 0; touch "$STUB_DEAD"; watch
holds "dead: the same link is restarted in the pane" grep -q '^pane run wX:p9 kimi-claude' "$STUB_LOG"
check 0 "$(jq -r .link "$SEAT/seat-link")" "dead: the link does not change on a resume"

# ---- paused and held
setup 0; rate_limited; date -u > "$SEAT/PAUSED"; watch
check 0 "$(grep -c '^agent' "$STUB_LOG" || true)" "paused: nothing is sent"
setup 0; rate_limited; touch "$SEAT/changeover-hold"; watch
check 0 "$(starts)" "another actor's changeover-hold: no swap into it"

# ---- workflow-watch runs gates in the worktree it is given
mkdir -p "$T/wf" "$T/other"; cp "$R"/schemas/workflows/workflow.schema.json "$T/wf/"
jq '.id="gatetest" | .gates=[{"id":"marker","command":"test -f gate-marker","expect":"exit-zero"}]' \
  "$R/schemas/workflows/orchestration-build.workflow.json" > "$T/wf/gatetest.workflow.json"
touch "$T/wt/gate-marker"
WF_SCHEMA_DIR="$T/wf" timeout 20 "$R/bin/workflow-watch.sh" gatetest run --cwd "$T/wt" >/dev/null 2>&1; rc=$?
check 0 "$rc" "workflow-watch: a gate that passes in the seat's worktree ends the watch"
WF_SCHEMA_DIR="$T/wf" timeout 3 "$R/bin/workflow-watch.sh" gatetest run --cwd "$T/other" >/dev/null 2>&1
holds "workflow-watch: the same gate is red in another tree" grep -q 'gate: marker=fail' "$T/state/gatetest-watch.log"

[ "$fail" = 0 ] && echo "ok  seat-watch: $n checks" || echo "FAIL seat-watch: see above ($n checks)"
exit "$fail"
