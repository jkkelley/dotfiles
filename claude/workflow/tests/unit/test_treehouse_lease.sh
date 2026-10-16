#!/usr/bin/env bash
# rolodex: header drafted by scripts/rolodex.py headers - correct any line that is wrong
# name: test_treehouse_lease.sh
# purpose: Proves workflow-spawn.sh takes a seat's worktree as a treehouse lease held by the seat, and stays idempotent.
# inputs: none (stubs treehouse and herdr on PATH)
# outputs: stdout, exit code
# writes-to: a mktemp scratch dir only
# cleanup: trap removes the scratch dir on exit
# Proves workflow-spawn.sh takes a seat's worktree as a treehouse lease held by the seat, and stays idempotent.
#
# Each check names the failure it rules out:
#   - a seat with no worktree still getting `git worktree add` instead of a pooled slot nobody can see or give back
#   - a lease taken without the seat as holder, so herdr-grid.sh seat-down cannot find and return it
#   - a rerun taking a second slot when the seat already holds one
#   - an existing configured directory being abandoned for a new slot (the old idempotence)
#   - a missing treehouse falling back silently to something else
# Hermetic: herdr and treehouse are stubs on PATH and every run is --dry-run, so nothing is leased or started.
set -uo pipefail
R="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
fail=0; n=0
ok()  { n=$((n+1)); printf 'ok  %s\n' "$1"; }
bad() { n=$((n+1)); fail=1; printf 'FAIL %s\n' "$1"; [ $# -gt 1 ] && printf '     %s\n' "${@:2}"; }
has()  { if grep -qF -- "$2" <<<"$3"; then ok "$1"; else bad "$1" "missing [$2] in:" "$3"; fi; }
hasnt(){ if grep -qF -- "$2" <<<"$3"; then bad "$1" "unexpected [$2] in:" "$3"; else ok "$1"; fi; }

mkdir -p "$T/bin" "$T/nobin" "$T/wt"
cat > "$T/bin/herdr" <<'STUB'
#!/usr/bin/env bash
case "$1 $2" in
  "workspace list") printf '{"result":{"workspaces":[{"workspace_id":"wT","label":"dotfiles"}]}}\n' ;;
  "tab list") printf '{"result":{"tabs":[{"tab_id":"wT:t1","label":"agent-architect"}]}}\n' ;;
  "pane list") printf '{"result":{"panes":[{"pane_id":"wT:p1","tab_id":"wT:t1"}]}}\n' ;;
  "agent get") exit 1 ;;
esac
exit 0
STUB
cat > "$T/bin/treehouse" <<'STUB'
#!/usr/bin/env bash
[ "$1" = status ] && { cat "$TH_STATUS"; exit 0; }
exit 0
STUB
chmod +x "$T/bin/herdr" "$T/bin/treehouse"
cp "$T/bin/herdr" "$T/nobin/herdr"
echo '[]' > "$T/none.json"
echo '[{"name":"3","path":"/pool/3/dotfiles","lease_holder":"architect"},{"name":"4","path":"/pool/4/dotfiles","lease_holder":"other"}]' > "$T/held.json"
jq --arg s "$T/state" --arg w "$T/absent" '.project.state_dir=$s | .workflow.seats |= map(.worktree=$w)' "$R/config/project.json" > "$T/config.json"
jq --arg w "$T/wt" '.workflow.seats |= map(.worktree=$w)' "$T/config.json" > "$T/config-dir.json"
export HERDR_ENV=1 WORKFLOW_CONFIG="$T/config.json"
spawn() { PATH="$T/bin:$PATH" "$R/bin/workflow-spawn.sh" "$@" --dry-run 2>&1; }

out="$(TH_STATUS="$T/none.json" spawn architect --link 1)"
has   "no slot and no directory: the seat leases one, as holder" "DRY: treehouse get --lease --lease-holder architect" "$out"
has   "the lease asks for JSON so the path is read, not guessed" "--json" "$out"
hasnt "git worktree add is gone"                                "worktree add" "$out"
has   "the seat's gate watcher runs in the leased slot"          "on workflow architect \\<treehouse-slot\\>" "$out"

out="$(TH_STATUS="$T/held.json" spawn architect --link 1)"
has   "a rerun reuses the slot the seat already leases"          "seat architect: already leases /pool/3/dotfiles" "$out"
hasnt "and takes no second slot"                                 "treehouse get" "$out"
hasnt "another holder's slot is never taken over"                "/pool/4" "$out"

out="$(TH_STATUS="$T/none.json" WORKFLOW_CONFIG="$T/config-dir.json" spawn architect --link 1)"
has   "an existing configured directory is still used as is"     "seat architect: worktree present at $T/wt" "$out"
hasnt "and no slot is leased beside it"                          "treehouse get" "$out"

# Runs in podman, whose image has no treehouse; nobin holds only the herdr stub.
if command -v treehouse >/dev/null 2>&1; then bad "no-treehouse case needs a PATH without treehouse"; else
  out="$(PATH="$T/nobin:$PATH" "$R/bin/workflow-spawn.sh" architect --link 1 --dry-run 2>&1)"; rc=$?
  if [ "$rc" -ne 0 ] && grep -q 'treehouse is not on PATH' <<<"$out"; then ok "no treehouse refuses loudly, no fallback"
  else bad "no treehouse refuses loudly, no fallback" "rc=$rc" "$out"; fi
fi

[ "$fail" = 0 ] && echo "ok  treehouse-lease: $n checks" || echo "FAIL treehouse-lease: see above ($n checks)"
exit "$fail"
