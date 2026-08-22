#!/usr/bin/env bash
# A scaffolded project tells its agent to check whether its skills are stale.
#
# Skills are installed into a project as copies. A copy cannot know the original
# moved on, so the session-start check in CLAUDE.md is the only thing that ever
# raises the question. If the template drops it, every project scaffolded from
# then on runs on whatever skill version it happened to be born with, forever,
# and nothing fails loudly - the skills still work, they are just old. That is
# precisely how both aws-lightsail-k8s-router and gatehouse-click ended up
# without the check.
#
# The URL assertion is the sharp one. Root CLAUDE.md carries a standing rule
# that environment-specific values become <angle-bracket> placeholders, and this
# URL is its single documented exception. Somebody "fixing" it into a
# placeholder points the check at a repository that does not exist, the fetch
# fails, the check reports "registry unreachable" and starts the work - so it
# breaks silently and stays broken. A literal-string assertion is the only thing
# standing in the way.
CASE_NAME=140-skill-version-check
source "${SKILL:-/skill}/testing/assert.sh"

p=$(scaffolded_project)

assert_contains "$p/CLAUDE.md" "## Session start - skill version check" \
  "CLAUDE.md carries the session-start check"

# The registry URL, whole and literal. Not a fragment - the owner is the part
# that gets substituted away, so the owner has to be inside the needle.
assert_contains "$p/CLAUDE.md" \
  "https://raw.githubusercontent.com/jkkelley/dotfiles/main/claude/skills/registry.json" \
  "the registry URL is literal, with its real owner"

assert_not_contains "$p/CLAUDE.md" "<your-github-username>/dotfiles" \
  "the registry URL was not turned into a placeholder"

# Both sides of the comparison. Reading only the registry tells you what is
# current but not what this project holds, which answers nothing.
assert_contains "$p/CLAUDE.md" "grep -H '^version:' .claude/skills/*/SKILL.md" \
  "the check reads the installed versions too"

# The two apply modes. Offering only standalone means a mid-session update opens
# a PR the user did not ask for; offering only inline means a check run before
# any work has nothing to ride on.
assert_contains "$p/CLAUDE.md" "--mode standalone" "offers the standalone apply mode"
assert_contains "$p/CLAUDE.md" "--mode inline" "offers the inline apply mode"

# Silence on the happy path. A check that announces itself every session gets
# skipped, and a skipped check is the thing this whole mechanism exists to stop.
assert_contains "$p/CLAUDE.md" "If everything matches, say nothing" \
  "the check stays silent when nothing is behind"

# Never block. An unreachable registry is a network problem, not a reason to
# refuse to start work.
assert_contains "$p/CLAUDE.md" "Never block a session on this" \
  "an unreachable registry does not stop the session"

# Absent skills, absent check. A project with no vendored skills has nothing to
# compare, and running it there would report a gap that cannot be closed.
assert_contains "$p/CLAUDE.md" "Skip the whole thing if \`.claude/skills/\` does not exist" \
  "the check is skipped when there are no vendored skills"

finish
