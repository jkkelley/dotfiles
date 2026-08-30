#!/usr/bin/env bash
# The gitignore blanket, asserted by git rather than by reading the template.
#
# This case is in cases-git/ and not cases/ because it needs a real git, which
# the suite's main image does not have. The distinction is not cosmetic: the
# ticket's done-when is "a project scaffolded from the template cannot commit a
# skill", and grepping the template for a line proves only that the line is
# there. Whether git honours it is a different question - a `**/` prefix that
# behaves differently from the one beside it, or an ordering problem with a
# later negation, would leave the grep green and the property false.
CASE_NAME=010-skills-gitignored
source "${SKILL:-/skill}/testing/assert.sh"

p=$(scaffolded_project)

git -C "$p" init -q
git -C "$p" config user.email t@example.com
git -C "$p" config user.name t

# What skill-sync installs: a managed skill, and a hand-authored one beside it.
# Both are copies as far as git is concerned, and the blanket covers the
# directory rather than picking names out of it.
mkdir -p "$p/.claude/skills/work-order/scripts" "$p/.claude/skills/mine"
printf 'name: work-order\n' >"$p/.claude/skills/work-order/SKILL.md"
printf 'x\n' >"$p/.claude/skills/work-order/scripts/work-order.sh"
printf 'name: mine\n' >"$p/.claude/skills/mine/SKILL.md"

# The positive: nothing under .claude/skills/ can reach the index.
for f in .claude/skills/work-order/SKILL.md \
         .claude/skills/work-order/scripts/work-order.sh \
         .claude/skills/mine/SKILL.md; do
  if git -C "$p" check-ignore -q "$f"; then
    _pass "git ignores $f"
  else
    _fail "git ignores $f" "check-ignore said it is committable"
  fi
done

# The negative, on the same tree in the same run. A blanket that swallowed the
# manifest, the settings or the vendored scripts would take the project's
# declared intent out of git along with the copies, and the failure would be
# invisible until someone cloned it.
for f in .claude/skills.toml .claude/settings.json .claude/scripts/log-issue.sh CLAUDE.md; do
  if git -C "$p" check-ignore -q "$f"; then
    _fail "git tracks $f" "the blanket swallowed it"
  else
    _pass "git tracks $f"
  fi
done

# And the whole thing end to end: add everything, and assert what the index holds.
# check-ignore answers per path; this answers "what would actually be committed",
# which is the sentence the acceptance criterion is written in.
git -C "$p" add -A
capture staged git -C "$p" diff --cached --name-only
case $staged in
  *".claude/skills/"*) _fail "a skill cannot be committed" "staged: ${staged//$'\n'/ }" ;;
  *) _pass "a skill cannot be committed" ;;
esac
case $staged in
  *".claude/skills.toml"*) _pass "the manifest is committed" ;;
  *) _fail "the manifest is committed" "staged: ${staged//$'\n'/ }" ;;
esac

finish
