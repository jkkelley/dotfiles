#!/usr/bin/env bash
# Proves the spawner carries the seat's name and role into compaction-guard, and never fails the spawn when it cannot.
#
# Each check names the failure it rules out:
#   - the seat's guard session staying nameless: alerts and checkpoints read "unnamed session" (the bug this fixes)
#   - the re-bind taking another pane's session, or a session bound before this spawn (a stale binding on a reused pane)
#   - the re-bind dropping the session's schema/cwd/transcript/driver, because do_bind rewrites binding.json whole
#   - a missing guard, or a binding that never appears, failing the spawn instead of warning on stderr
#   - --dry-run touching the guard instead of printing a DRY: line
# Hermetic: the machinery is copied and its watch-ctl.sh stubbed (the watchers are proven in test_compaction.sh and
# test_seat_watch.sh; here they only have to not abort the spawn), herdr and compaction-guard are stubs on PATH, the guard state is a temp dir, CTXBIND_WAIT=0 so retries are instant.
# shellcheck disable=SC2016  # chk takes its condition as a single-quoted string on purpose; eval expands it
set -uo pipefail
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
mkdir -p "$T/r"; cp -r "$SRC/bin" "$SRC/config" "$SRC/schemas" "$T/r/"; R="$T/r"
printf '#!/usr/bin/env bash\nexit 0\n' > "$R/bin/watch-ctl.sh"
fail=0; n=0
ok()  { n=$((n+1)); printf 'ok  %s\n' "$1"; }
bad() { n=$((n+1)); fail=1; printf 'FAIL %s\n' "$1"; [ $# -gt 1 ] && printf '     %s\n' "${@:2}"; }
has()  { if grep -qF -- "$2" <<<"$3"; then ok "$1"; else bad "$1" "missing [$2] in:" "$3"; fi; }
chk() { if eval "$2"; then ok "$1"; else bad "$1" "${@:3}"; fi; }
hasnt(){ if grep -qF -- "$2" <<<"$3"; then bad "$1" "unexpected [$2] in:" "$3"; else ok "$1"; fi; }

mkdir -p "$T/bin" "$T/nobin" "$T/wt" "$T/gstate/sessions"
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
cat > "$T/bin/compaction-guard" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$GUARD_LOG"
exit 0
STUB
chmod +x "$T/bin/herdr" "$T/bin/compaction-guard"
export PATH="$T/bin:$PATH" HERDR_ENV=1 COMPACTION_GUARD_STATE="$T/gstate" GUARD_LOG="$T/guard.log" CTXBIND_WAIT=0
jq --arg s "$T/state" --arg w "$T/wt" '.project.state_dir=$s | .workflow.seats |= map(.worktree=$w)' \
  "$R/config/project.json" > "$T/config.json"
export WORKFLOW_CONFIG="$T/config.json"
: > "$GUARD_LOG"
bind() { # <session> <pane> <bound_at>
  mkdir -p "$T/gstate/sessions/$1"
  jq -n --arg s "$1" --arg p "$2" --arg at "$3" '{session:$s,pane:$p,schema:"/x/role.json",cwd:"/x/cwd",transcript:"/x/t.jsonl",driver:"herdr",bound_at:$at}' \
    > "$T/gstate/sessions/$1/binding.json"
}

# ---- dry run: a DRY line, the guard untouched
out="$("$R/bin/workflow-spawn.sh" architect --dry-run 2>&1)"
has "dry-run prints the bind it would do" "DRY: compaction-guard bind --name architect --role " "$out"
chk "dry-run never calls the guard" '[ ! -s "$GUARD_LOG" ]' "$(cat "$GUARD_LOG")"

# ---- real run: stale session on this pane and a fresh one on another pane are ignored; the fresh one on this pane is bound
bind stale wT:p1 2000-01-01T00:00:00Z
bind other wT:p9 2999-01-01T00:00:00Z
bind mine  wT:p1 2999-01-01T00:00:00Z
out="$("$R/bin/workflow-spawn.sh" architect --link 1 2>&1)"; rc=$?
chk "spawn succeeds" '[ "$rc" -eq 0 ]' "rc=$rc" "$out"
g="$(cat "$GUARD_LOG")"
has   "the session on this pane bound after the spawn is re-bound with name and role" "bind --session mine --name architect --role " "$g"
has   "the re-bind targets this pane" "--pane wT:p1" "$g"
has   "the re-bind hands back the existing schema, cwd, transcript and driver" "--schema /x/role.json --cwd /x/cwd --transcript /x/t.jsonl --driver herdr" "$g"
hasnt "a session bound before the spawn is left alone" "--session stale" "$g"
hasnt "another pane's session is left alone" "--session other" "$g"

# ---- no binding ever appears: warn, spawn still succeeds
rm -rf "$T/gstate/sessions"/*; : > "$GUARD_LOG"
out="$("$R/bin/workflow-spawn.sh" architect --link 1 2>&1)"; rc=$?
chk "no binding: spawn still succeeds" '[ "$rc" -eq 0 ]' "rc=$rc" "$out"
has "no binding: warns on stderr after 3 tries" "warning: no compaction-guard binding for pane wT:p1 after 3 tries" "$out"
chk "no binding: guard never asked to bind" '[ ! -s "$GUARD_LOG" ]'

# ---- guard absent: warn, spawn still succeeds
rm -f "$T/bin/compaction-guard"
out="$(PATH="$T/bin:/usr/bin:/bin" "$R/bin/workflow-spawn.sh" architect --link 1 2>&1)"; rc=$?
chk "guard absent: spawn still succeeds" '[ "$rc" -eq 0 ]' "rc=$rc" "$out"
has "guard absent: warns on stderr" "warning: compaction-guard is not on PATH" "$out"

printf '%s checks, %s\n' "$n" "$([ "$fail" = 0 ] && echo pass || echo FAIL)"
exit "$fail"
