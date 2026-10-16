#!/usr/bin/env bash
# Stub `claude` (WSL Claude Code, `claude -p` reading a screenshot) for the inbox sweep's tests, installed as `claude`.
# Logs one line per call to $TEST_OUT/calls.log as `claude <args>`. It answers like `--output-format json`:
# {"result": "<the verdict text>"}.
#   STUB_VERDICT_SEQ  file with one verdict text per line; call N prints line N, the last line repeats
#   STUB_VERDICT      verdict text when there is no SEQ file (default: a CLEAN-OK verdict)
#   STUB_CLAUDE_RC    exit code (default 0)
: "${TEST_OUT:?stub-claude: TEST_OUT must be set}"
printf 'claude %s\n' "$*" >>"$TEST_OUT/calls.log"
counter="$TEST_OUT/claude.count"
n=$(($(cat "$counter" 2>/dev/null || echo 0) + 1))
printf '%s\n' "$n" >"$counter"
if [ -n "${STUB_VERDICT_SEQ:-}" ] && [ -f "$STUB_VERDICT_SEQ" ]; then
  total="$(wc -l <"$STUB_VERDICT_SEQ")"
  line="$n"; [ "$line" -le "$total" ] || line="$total"
  text="$(sed -n "${line}p" "$STUB_VERDICT_SEQ")"
else
  default='{"code":"CLEAN-OK","claude_groups_open":0,"tabs_beyond_baseline":0,"orphan_tabs":[]}'
  text="${STUB_VERDICT:-$default}"
fi
jq -cn --arg r "$text" '{result:$r}'
exit "${STUB_CLAUDE_RC:-0}"
