#!/usr/bin/env bash
# Stub `herdr` for the inbox sweep's tests. Installed as `herdr` on PATH by stubs_install (tests/lib/stubs.sh).
#
# Why it exists: the sweep drives herdr for every tab, pane and seat, and no test may touch a real herdr session
# (B11 is the only node that does). Every call is one line in $TEST_OUT/calls.log, so a test asserts what the sweep did
# by grepping that file instead of by watching a screen.
#
# Line format: `herdr <args joined by single spaces>`; a newline inside an argument is written as the two characters \n,
# so one call is always exactly one line.
#
# Answers, driven by environment:
#   STUB_HERDR_FAIL=1  every call exits 1 (the PF-NO-HERDR case)
#   `workspace list`, `pane list`, `agent get`, `tab list` return small fixed JSON shaped like the real CLI's `.result`.
#   Everything else exits 0 silently.
: "${TEST_OUT:?stub-herdr: TEST_OUT must be set}"
args="$*"
printf 'herdr %s\n' "${args//$'\n'/\\n}" >>"$TEST_OUT/calls.log"
[ "${STUB_HERDR_FAIL:-0}" = 1 ] && exit 1
case "${1:-} ${2:-}" in
  "workspace list") printf '{"result":{"workspaces":[{"workspace_id":"wS","label":"dotfiles"}]}}\n' ;;
  "tab list") printf '{"result":{"tabs":[{"tab_id":"wS:t1","label":"orchestrator"}]}}\n' ;;
  "pane list") printf '{"result":{"panes":[{"pane_id":"wS:p1","label":"claude-main","tab_id":"wS:t1"}]}}\n' ;;
  "agent get") printf '{"result":{"agent":{"agent_status":"%s"}}}\n' "${STUB_HERDR_STATUS:-idle}" ;;
esac
exit 0
