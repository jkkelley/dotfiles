#!/usr/bin/env bash
# Fresh directory: the plan is a dry run, and --apply installs the full layer.
CASE_NAME=010-scaffold-fresh
source "${SKILL:-/skill}/testing/assert.sh"

p=$(new_project)

run 0 "dry run exits 0" scaffold --project "$p"
assert_no_file "$p/CLAUDE.md" "dry run wrote nothing"

run 0 "apply exits 0" scaffold --project "$p" --apply --yes
for f in CLAUDE.md COMPASS.md BACKLOG.md ISSUES.md NAMING.md; do
  assert_file "$p/$f" "created $f"
done
assert_file "$p/.claude/settings.json" "created settings.json"
assert_file "$p/.claude/scripts/log-issue.sh" "vendored log-issue.sh"
assert_file "$p/.claude/scripts/lib/common.sh" "vendored lib/common.sh"
assert_file "$p/.claude/scaffold.json" "recorded scaffold.json"
assert_contains "$p/ISSUES.md" "ISSUES:BEGIN" "ISSUES.md carries its sentinel"
assert_contains "$p/CLAUDE.md" "CONTEXT_STATE.md" "CLAUDE.md carries the session-state pointer"

finish
