#!/usr/bin/env bash
# Proves the spawner starts the link of the model chain it is asked for, and reports on the surface that link can use.
#
# Each check names the failure it rules out:
#   - kimi-k3 started as plain `claude` because herdr calls it kind claude: opus runs, billed, under the kimi link's name
#   - kimi-k3 handed RAIL_SURFACE=artifact because herdr calls it kind claude: it cannot mint a claude.ai URL, so it
#     invents one or produces nothing (the O-08 trap; surface comes from the link, never from herdr_kind)
#   - a --link past the end of the chain starting something anyway
#   - a single-form declaration changing behaviour because the chain arrived
# Hermetic: herdr is a stub on PATH and every run is --dry-run, so nothing is started and nothing is written.
set -uo pipefail
R="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
fail=0; n=0
ok()  { n=$((n+1)); printf 'ok  %s\n' "$1"; }
bad() { n=$((n+1)); fail=1; printf 'FAIL %s\n' "$1"; [ $# -gt 1 ] && printf '     %s\n' "${@:2}"; }
has()  { if grep -qF -- "$2" <<<"$3"; then ok "$1"; else bad "$1" "missing [$2] in:" "$3"; fi; }
hasnt(){ if grep -qF -- "$2" <<<"$3"; then bad "$1" "unexpected [$2] in:" "$3"; else ok "$1"; fi; }

# ---- stub herdr: one workspace, one tab per seat label, one free pane in each; no agent is live
mkdir -p "$T/bin" "$T/wt"
cat > "$T/bin/herdr" <<'STUB'
#!/usr/bin/env bash
case "$1 $2" in
  "workspace list") printf '{"result":{"workspaces":[{"workspace_id":"wT","label":"dotfiles"}]}}\n' ;;
  "tab list") printf '{"result":{"tabs":[{"tab_id":"wT:t1","label":"agent-architect"},{"tab_id":"wT:t2","label":"agent-orch"}]}}\n' ;;
  "pane list") printf '{"result":{"panes":[{"pane_id":"wT:p1","tab_id":"wT:t1"},{"pane_id":"wT:p2","tab_id":"wT:t2"}]}}\n' ;;
  "agent get") exit 1 ;;
esac
exit 0
STUB
chmod +x "$T/bin/herdr"
export PATH="$T/bin:$PATH" HERDR_ENV=1
jq --arg s "$T/state" --arg w "$T/wt" '.project.state_dir=$s | .workflow.seats |= map(.worktree=$w)' \
  "$R/config/project.json" > "$T/config.json"
export WORKFLOW_CONFIG="$T/config.json"
spawn() { "$R/bin/workflow-spawn.sh" "$@" --dry-run 2>&1; }

out="$(spawn architect)"
has   "link 0 by default is kimi-k3 through kimi-claude" "link 0/3 kimi-k3 via kimi-claude (herdr kind claude)" "$out"
has   "kimi-k3 exports RAIL_SURFACE=lavish although herdr sees kind claude" 'RAIL_SURFACE=lavish\ RAIL_SEAT=architect' "$out"
has   "kimi-k3 runs its launcher in the pane" "DRY: herdr pane run wT:p1 kimi-claude\\ " "$out"
hasnt "kimi-k3 is never started as plain claude by herdr agent start" "agent start" "$out"
has   "kimi-k3: the detected agent is given the seat's name" "DRY: herdr agent rename wT:p1 architect" "$out"
has   "the seat-link would record link 0 of 3" "DRY: seat-link wT:p1 link=0 links=3" "$out"
has   "the spawner arms the seat watcher on the seat's pane" "watch-ctl.sh on seat wT:p1" "$out"
has   "the spawner arms the gate watcher in the seat's worktree" "watch-ctl.sh on workflow architect $T/wt" "$out"

out="$(spawn architect --link 1)"
has   "--link 1 is opus through claude" "link 1/3 opus via claude (herdr kind claude)" "$out"
has   "opus exports RAIL_SURFACE=artifact" 'RAIL_SURFACE=artifact\ RAIL_SEAT=architect' "$out"
has   "opus is started by herdr with its model id" "agent start architect --kind claude --pane wT:p1 --timeout 60000 -- --model claude-opus-5-5" "$out"

out="$(spawn architect --link 2)"
has   "--link 2 is codex-sol through codex" "link 2/3 codex-sol via codex (herdr kind codex)" "$out"
has   "codex-sol exports RAIL_SURFACE=lavish" 'RAIL_SURFACE=lavish\ RAIL_SEAT=architect' "$out"
has   "codex-sol is started by herdr in codex's dialect" "agent start architect --kind codex --pane wT:p1 --timeout 60000 -- -m gpt-5.6-sol" "$out"
hasnt "codex is never handed claude-only tool flags" "--allowed-tools" "$out"
has   "codex: Agent and Task denied through codex's own sub-agent features" "--disable multi_agent --disable multi_agent_v2 -a never" "$out"
has   "codex: an architect that may write gets the workspace-write sandbox" "-s workspace-write" "$out"

# A codex link whose declaration denies a tool codex cannot deny must not start: that is the silent gap e3e545c had.
mkdir -p "$T/wf"; cp "$R"/schemas/workflows/*.json "$T/wf/"
jq '.agent.denied_tools += ["NotebookEdit"]' "$R/schemas/workflows/architect.workflow.json" > "$T/wf/architect.workflow.json"
out="$(WF_SCHEMA_DIR="$T/wf" spawn architect --link 2)"; rc=$?
if [ "$rc" -ne 0 ] && grep -q "cannot enforce denied tool 'NotebookEdit'" <<<"$out"; then ok "codex refuses a denial it cannot enforce"
else bad "codex refuses a denial it cannot enforce" "rc=$rc" "$out"; fi
hasnt "the refused codex link starts nothing" "agent start" "$out"
jq '.agent.denied_tools += ["Edit","Write"]' "$R/schemas/workflows/architect.workflow.json" > "$T/wf/architect.workflow.json"
out="$(WF_SCHEMA_DIR="$T/wf" spawn architect --link 2)"
has   "codex: a declaration denying Edit and Write gets the read-only sandbox" "-s read-only" "$out"

out="$(spawn architect --pane wT:p9 --link 1)"
has   "--pane pins the pane the next link starts in" "agent start architect --kind claude --pane wT:p9" "$out"

out="$(spawn architect --link 3)"; rc=$?
if [ "$rc" -ne 0 ] && grep -q 'there is no link 3' <<<"$out"; then ok "--link past the chain refuses"; else bad "--link past the chain refuses" "rc=$rc" "$out"; fi
hasnt "--link past the chain starts nothing" "DRY: herdr" "$out"

out="$(spawn orchestration-build orch-builder)"
has   "a single-form declaration still starts claude on artifact" 'RAIL_SURFACE=artifact\ RAIL_SEAT=orch-builder' "$out"
has   "a single-form declaration keeps its model mapping" "--model claude-opus-5-5 --allowed-tools" "$out"
out="$(spawn orchestration-build orch-builder --link 1)"; rc=$?
if [ "$rc" -ne 0 ]; then ok "a single-form declaration has only link 0"; else bad "a single-form declaration has only link 0" "$out"; fi

[ "$fail" = 0 ] && echo "ok  model-chain: $n checks" || echo "FAIL model-chain: see above ($n checks)"
exit "$fail"
