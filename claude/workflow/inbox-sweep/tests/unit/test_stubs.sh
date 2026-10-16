#!/usr/bin/env bash
# AC-H1: the stub herdr and stub claude.exe log every call, one line each, to $TEST_OUT/calls.log.
# Rules out: a test that asserts "the sweep did X" against a stub that silently drops the call, and a multi-line
# argument (a brief or prompt body) splitting one call across lines so a grep-count of calls is wrong.
set -uo pipefail
R="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=_t.sh
. "$R/tests/unit/_t.sh"
# shellcheck source=../lib/stubs.sh
. "$R/tests/lib/stubs.sh"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
export TEST_OUT="$T/out"
stubs_install "$T/bin"
LOG="$TEST_OUT/calls.log"

herdr tab create --label agent-sweep-gmail >/dev/null
herdr agent prompt wS:p2 $'line one\nline two' >/dev/null
claude.exe -p --chrome --model haiku "list_connected_browsers" >/dev/null
check "herdr tab create --label agent-sweep-gmail" "$(sed -n 1p "$LOG")" "herdr call logged with its arguments"
check 'herdr agent prompt wS:p2 line one\nline two' "$(sed -n 2p "$LOG")" "a newline inside an argument stays on one line"
check "claude.exe -p --chrome --model haiku list_connected_browsers" "$(sed -n 3p "$LOG")" "claude.exe call logged with its arguments"
check 3 "$(wc -l <"$LOG")" "three calls are exactly three lines"

: >"$LOG"; rm -f "$TEST_OUT/claude-exe.count"
check '[]' "$(claude.exe -p x)" "claude.exe probe answers [] by default (a sleeping extension)"
printf '[]\n[]\n[{"name":"Your Chrome"}]\n' >"$T/seq"
rm -f "$TEST_OUT/claude-exe.count"
a="$(STUB_CLAUDE_SEQ="$T/seq" claude.exe -p x)"; b="$(STUB_CLAUDE_SEQ="$T/seq" claude.exe -p x)"; c="$(STUB_CLAUDE_SEQ="$T/seq" claude.exe -p x)"; d="$(STUB_CLAUDE_SEQ="$T/seq" claude.exe -p x)"
check '[] [] [{"name":"Your Chrome"}] [{"name":"Your Chrome"}]' "$a $b $c $d" "SEQ answers call N with line N and repeats the last"

STUB_CLAUDE_FAIL=1 claude.exe -p x >/dev/null; check 127 "$?" "STUB_CLAUDE_FAIL makes claude.exe unrunnable (exit 127)"
STUB_HERDR_FAIL=1 herdr workspace list >/dev/null; check 1 "$?" "STUB_HERDR_FAIL makes herdr exit 1"
check 1 "$(grep -c '^herdr workspace list$' "$LOG" | awk '$1>=1{print 1}')" "a failing call is still logged"
check '{"result":{"workspaces":[{"workspace_id":"wS","label":"dotfiles"}]}}' "$(herdr workspace list)" "workspace list returns the real CLI's .result shape"

( unset TEST_OUT; herdr x >/dev/null 2>&1 ); check 1 "$?" "stub refuses to run without TEST_OUT, so a call can never go unlogged"
finish
