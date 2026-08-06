#!/usr/bin/env bash
# The vendored copy only works if drift from the skill is visible. A silently
# stale copy would write yesterday's format into today's file.
CASE_NAME=100-version-skew
source "${SKILL:-/skill}/testing/assert.sh"

p=$(scaffolded_project)

assert_same "$SKILL/scripts/log-issue.sh" "$p/.claude/scripts/log-issue.sh" "vendored copy matches the skill"
assert_contains "$p/.claude/scaffold.json" '"tool_version"' "scaffold.json records the tool version"

# An out-of-date vendored copy must be reported as refresh, not skip.
printf '# tampered\n' >>"$p/.claude/scripts/log-issue.sh"
capture plan scaffold --project "$p" --json
case $plan in *'"file":".claude/scripts/log-issue.sh","action":"refresh"'*) _pass "skew reported as refresh" ;;
  *) _fail "skew reported as refresh" "got: ${plan:0:400}" ;; esac

run 0 "apply re-syncs the vendored copy" scaffold --project "$p" --apply --yes
assert_same "$SKILL/scripts/log-issue.sh" "$p/.claude/scripts/log-issue.sh" "vendored copy refreshed"

# The vendored copy must actually run from inside the project.
run 0 "vendored script runs in place" bash "$p/.claude/scripts/log-issue.sh" --project "$p" \
  --title "via vendored copy" --severity low --area vendor \
  --symptom s --trigger t --cause c --fix f --verify v
assert_contains "$p/ISSUES.md" "via vendored copy" "vendored copy wrote the entry"

finish
