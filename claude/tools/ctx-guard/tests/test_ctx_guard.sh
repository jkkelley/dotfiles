#!/usr/bin/env bash
# rolodex: header drafted by scripts/rolodex.py headers - correct any line that is wrong
# name: test_ctx_guard.sh
# purpose: Tests ctx-guard.sh against a stub compaction-guard that behaves like install/doctor (real tool is exercised by
# inputs: env STUB_FAIL STUB_HOOKS
# outputs: stdout, exit code
# writes-to: $HOME/.claude/settings.json, a mktemp scratch path
# cleanup: removes its own temp files on exit
# Tests ctx-guard.sh against a stub compaction-guard that behaves like install/doctor (real tool is exercised by
# `make ctx-guard-install` on the host). Intent: install is idempotent, backs up, retries 3 times, and fails loudly
# when doctor does not show the wiring.
set -uo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
T="$(mktemp -d)"; export HOME="$T/home"; mkdir -p "$HOME/.claude" "$T/bin"
export COMPACTION_GUARD_STATE="$T/state"; mkdir -p "$COMPACTION_GUARD_STATE"
echo '{"statusLine":{"type":"command","command":"/bin/true"}}' > "$HOME/.claude/settings.json"
echo /bin/true > "$COMPACTION_GUARD_STATE/statusline.next"
cat > "$T/bin/cg" <<'STUB'
#!/usr/bin/env bash
echo "$*" >> "$HOME/calls"
case "$1" in
  install) [ -n "${STUB_FAIL:-}" ] && exit 1; echo '{"hooks":{"Stop":[{"hooks":[{"command":"x compaction-guard hook"}]}]},"statusLine":{"command":"compaction-guard tap"}}' > "$HOME/.claude/settings.json" ;;
  doctor) echo "{\"global_hooks\":${STUB_HOOKS:-true},\"statusline_tap\":true}" ;;
esac
STUB
chmod +x "$T/bin/cg"; export COMPACTION_GUARD_BIN="$T/bin/cg"
fail=0; ok() { echo "ok  $1"; }; bad() { echo "FAIL $1"; fail=1; }

bash "$HERE/ctx-guard.sh" install >/dev/null && ok install || bad install
ls "$HOME"/.local/state/zenith/backup/*/*/* >/dev/null 2>&1 && ok backup || bad backup
STUB_HOOKS=false bash "$HERE/ctx-guard.sh" install >/dev/null 2>&1 && bad "unwired install must fail" || ok "unwired install fails"
: > "$HOME/calls"; STUB_FAIL=1 bash "$HERE/ctx-guard.sh" install >/dev/null 2>&1 && bad "failing install must fail" || ok "failing install fails"
[ "$(grep -c '^install' "$HOME/calls")" = 3 ] && ok "3 tries then report" || bad "retry count"
bash "$HERE/ctx-guard.sh" nonsense >/dev/null 2>&1 && bad usage || ok usage
rm -rf "$T"; exit $fail
