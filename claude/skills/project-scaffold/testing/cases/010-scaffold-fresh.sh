#!/usr/bin/env bash
# Fresh directory: the plan is a dry run, and --apply installs the full layer.
CASE_NAME=010-scaffold-fresh
source "${SKILL:-/skill}/testing/assert.sh"

p=$(new_project)

run 0 "dry run exits 0" scaffold --project "$p"
assert_no_file "$p/CLAUDE.md" "dry run wrote nothing"
assert_no_file "$p/issues/.gitkeep" "dry run created no directories"

run 0 "apply exits 0" scaffold --project "$p" --apply --yes
for f in AGENTS.md CLAUDE.md COMPASS.md NAMING.md; do
  assert_file "$p/$f" "created $f"
done
# The monoliths are gone: issues and backlog items are one file per entry, so
# two concurrent agents never touch the same path (dotfiles #95).
assert_no_file "$p/ISSUES.md" "no ISSUES.md monolith"
assert_no_file "$p/BACKLOG.md" "no BACKLOG.md monolith"
assert_file "$p/issues/.gitkeep" "created issues/ tree"
for d in now next later done; do
  assert_file "$p/backlog/$d/.gitkeep" "created backlog/$d/"
done
assert_file "$p/.claude/settings.json" "created settings.json"
assert_file "$p/.claude/scripts/log-issue.sh" "vendored log-issue.sh"
assert_file "$p/.claude/scripts/lib/common.sh" "vendored lib/common.sh"
assert_file "$p/.claude/skills.toml" "created skills.toml"
assert_no_file "$p/.claude/scaffold.json" "no scaffold.json - the receipt supersedes it"
# The pointer lives in AGENTS.md now; CLAUDE.md is a stub that points there.
assert_contains "$p/AGENTS.md" "CONTEXT_STATE.md" "AGENTS.md carries the session-state pointer"

finish
