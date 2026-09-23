#!/usr/bin/env bash
# A scaffolded project carries its laws in AGENTS.md, and CLAUDE.md only points
# there.
#
# The laws used to live in CLAUDE.md, which only a Claude runtime reads. A Kimi
# or Codex seat in the same project read AGENTS.md, found nothing, and ran
# without herdr-first, the surface rule or the compaction rule - the three that
# fail silently. So each law is asserted by its heading, one at a time: a count
# of "eight laws" stays green when one is swapped for another, and they are not
# interchangeable.
#
# The stub half matters as much. A CLAUDE.md that restates any rule is a second
# copy, and two copies drift until an agent follows the stale one.
CASE_NAME=200-agents-md
source "${SKILL:-/skill}/testing/assert.sh"

p=$(scaffolded_project)

assert_file "$p/AGENTS.md" "AGENTS.md is rendered"
assert_file "$p/CLAUDE.md" "CLAUDE.md is rendered"

# --- the stub: points at AGENTS.md, and carries no rule of its own
assert_contains "$p/CLAUDE.md" 'Read `AGENTS.md`.' "CLAUDE.md points at AGENTS.md"
assert_count 0 "$(grep -c '^## ' "$p/CLAUDE.md")" "CLAUDE.md has no sections of its own"
assert_not_contains "$p/CLAUDE.md" "Hard rule" "CLAUDE.md states no hard rule"
assert_not_contains "$p/CLAUDE.md" "Law:" "CLAUDE.md restates no law"
# A stub is short. Twenty lines is room for the pointer and the skill-sync
# marker pair, and not room for a rule to creep back in.
lines=$(grep -c '' "$p/CLAUDE.md")
if ((lines <= 20)); then _pass "CLAUDE.md is a stub ($lines lines)"; else
  _fail "CLAUDE.md is a stub" "wanted <= 20 lines, got $lines"; fi

# --- every law, by heading, byte for byte
while IFS= read -r law; do
  assert_contains "$p/AGENTS.md" "$law" "AGENTS.md carries: ${law#\#\# }"
done <<'LAWS'
## Law: herdr-first, never background processes
## Law: automation leads, never by hand
## Law: Google Drive first
## Law: the surface follows the runtime
## Law: scope small, integrate in CI
## Law: testing
## Law: the architect model chain
## Law: compaction
LAWS

# The surface rule is the one most likely to be "tidied" into a preference. The
# unset default is the half that matters: a seat that guesses gets it wrong.
assert_contains "$p/AGENTS.md" "Unset means \`lavish-axi\`." "surface law states the unset default"
assert_contains "$p/AGENTS.md" "Never send \`/compact\` yourself." "compaction law forbids self-compaction"

# Cited by name and version, never by Drive id or URL - this repo is public.
for doc in AGENT_CONTRACT_HERDR_FIRST_v1.1.0 SOP_HERDR_FIRST_v1.1.0 \
  "DOCUMENTATION-WORKFLOW-STANDARD v1.0.0" GLOBAL-INTERACTION-SURFACE-POLICY \
  agent-role-v1.1.0.schema.json; do
  assert_contains "$p/AGENTS.md" "$doc" "AGENTS.md cites $doc"
done
for f in AGENTS.md CLAUDE.md; do
  assert_not_contains "$p/$f" "docs.google.com" "$f carries no Drive URL"
  assert_not_contains "$p/$f" "drive.google.com" "$f carries no Drive file URL"
done

# --- no template token survives rendering, in any file the scaffold wrote
# report/rail/ is excluded for the same reason scripts/ is: it is vendored code,
# and its __TITLE__-style tokens are filled by rail-build.sh on every build, not
# by scaffold. The wrapper scaffold does render, report/rail.sh, is still
# checked here, and 230-rail-install checks the built page carries none.
survivors=$(grep -rlE '__[A-Z][A-Z0-9_]*__' "$p" --exclude-dir=scripts --exclude-dir=rail 2>/dev/null || true)
assert_eq "" "$survivors" "no __PLACEHOLDER__ survives in a rendered file"

# --- an existing AGENTS.md missing one law gains it, and keeps what it had
q=$(new_project)
awk '/^## Law: compaction$/ { exit } { print }' "$SKILL/references/templates/AGENTS.md.tmpl" >"$q/AGENTS.md"
printf 'Local note I wrote.\n' >>"$q/AGENTS.md"
run 0 "apply over AGENTS.md missing a law" scaffold --project "$q" --apply --yes
assert_count 1 "$(grep -c '^## Law: compaction$' "$q/AGENTS.md")" "missing law appended exactly once"
assert_contains "$q/AGENTS.md" "Local note I wrote." "existing AGENTS.md content kept"

# --- a hand-written CLAUDE.md is never replaced by the stub
r=$(new_project)
printf '# CLAUDE.md\n\n## My rules\n\nKeep these.\n' >"$r/CLAUDE.md"
cp "$r/CLAUDE.md" "$WORK/claude-before.md"
run 0 "apply over a hand-written CLAUDE.md" scaffold --project "$r" --apply --yes
assert_same "$r/CLAUDE.md" "$WORK/claude-before.md" "hand-written CLAUDE.md left byte-identical"
assert_file "$r/AGENTS.md" "AGENTS.md created beside it"

finish
