#!/usr/bin/env bash
# .claude/skills.toml: written once, copied verbatim, never clobbered.
#
# The manifest is the project's declared intent and skill-sync is the only thing
# that acts on it. So the assertions worth making here are about what scaffold.sh
# puts on disk and what it refuses to do to a file that is already there - not
# about what gets installed, which is the sync's suite and not this one.
CASE_NAME=160-skills-manifest
source "${SKILL:-/skill}/testing/assert.sh"

tmpl="$SKILL/references/templates/skills.toml.tmpl"

p=$(scaffolded_project)
assert_file "$p/.claude/skills.toml" "created .claude/skills.toml"
assert_same "$tmpl" "$p/.claude/skills.toml" "copied verbatim from the template"

# Decision 20's four. Named individually, because "four names are present" would
# stay green if one were swapped for another.
for s in work-order living-docs container-sandbox context-compaction; do
  assert_contains "$p/.claude/skills.toml" "\"$s\"" "declares $s"
done

# The section headers skill-sync's parser keys on. It reads exactly one shape,
# and a manifest whose sections are named differently parses to nothing at all -
# silently, because an empty manifest is a legal manifest.
assert_contains "$p/.claude/skills.toml" "[skills]" "carries the [skills] section"
assert_contains "$p/.claude/skills.toml" "[agents]" "carries the [agents] section"
assert_contains "$p/.claude/skills.toml" "use = [" "declares its list with use ="

# No versions. A version here is wrong within a week and a stale one is worse
# than none, because an agent reading it believes it.
#
# Comments are stripped first, on purpose: the template's own header explains
# why nothing pins a version, and a flat grep would fail on the explanation for
# the rule it is checking. What must not appear is a version in the data.
capture declared sed 's/#.*//' "$p/.claude/skills.toml"
case $declared in
  *version*) _fail "names skills, never versions" "a version appears outside the comments" ;;
  *) _pass "names skills, never versions" ;;
esac

# Never clobbered. This is the property that matters most: the manifest is
# hand-edited, so a re-run that re-applied the template would silently delete a
# skill someone added and the next sync would delete its directory.
printf '[skills]\nuse = [\n  "work-order",\n  "cartography",\n]\n' >"$p/.claude/skills.toml"
cp "$p/.claude/skills.toml" "$WORK/mine.skills.toml"
run 0 "re-apply over an edited manifest" scaffold --project "$p" --apply --yes
assert_same "$p/.claude/skills.toml" "$WORK/mine.skills.toml" "hand-edited manifest left untouched"

# And the plan says so before it does it, rather than after.
capture plan scaffold --project "$p" --json
case $plan in *'"file":".claude/skills.toml","action":"skip"'*) _pass "an existing manifest is planned as skip" ;;
  *) _fail "an existing manifest is planned as skip" "got: ${plan:0:400}" ;; esac

q=$(new_project)
capture fresh scaffold --project "$q" --json
case $fresh in *'"file":".claude/skills.toml","action":"create"'*) _pass "an absent manifest is planned as create" ;;
  *) _fail "an absent manifest is planned as create" "got: ${fresh:0:400}" ;; esac
assert_no_file "$q/.claude/skills.toml" "the plan is still a dry run"

finish
