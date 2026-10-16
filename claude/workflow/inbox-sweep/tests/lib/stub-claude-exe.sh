#!/usr/bin/env bash
# Stub `claude.exe` (Windows Claude Code, reached from WSL) for the inbox sweep's tests. Installed as `claude.exe` on PATH.
#
# Why it exists: the browser seats and the extension probe run through a Windows binary that does not exist in the Podman
# image and must never start a real browser seat in a test. Every call is one line in $TEST_OUT/calls.log, in the format
# `claude.exe <args joined by single spaces>`, newline in an argument written as \n.
#
# Answers, driven by environment:
#   STUB_CLAUDE_SEQ    path of a file with one stdout answer per line; call N prints line N, the last line repeats.
#                      This is how a test says "the extension probe returns [] three times".
#   STUB_CLAUDE_OUT    stdout when there is no SEQ file (default `[]`, the sleeping-extension answer)
#   STUB_CLAUDE_RC     exit code (default 0)
#   STUB_CLAUDE_FAIL=1 prints nothing and exits 127, as if claude.exe were not runnable (PF-NO-CLAUDE-EXE)
: "${TEST_OUT:?stub-claude-exe: TEST_OUT must be set}"
args="$*"
printf 'claude.exe %s\n' "${args//$'\n'/\\n}" >>"$TEST_OUT/calls.log"
[ "${STUB_CLAUDE_FAIL:-0}" = 1 ] && exit 127
# The call counter lives in TEST_OUT so each test, with its own TEST_OUT, starts at call 1.
counter="$TEST_OUT/claude-exe.count"
n=$(($(cat "$counter" 2>/dev/null || echo 0) + 1))
printf '%s\n' "$n" >"$counter"
if [ -n "${STUB_CLAUDE_SEQ:-}" ] && [ -f "$STUB_CLAUDE_SEQ" ]; then
  total="$(wc -l <"$STUB_CLAUDE_SEQ")"
  line="$n"
  [ "$line" -le "$total" ] || line="$total"
  sed -n "${line}p" "$STUB_CLAUDE_SEQ"
else
  printf '%s\n' "${STUB_CLAUDE_OUT:-[]}"
fi
exit "${STUB_CLAUDE_RC:-0}"
