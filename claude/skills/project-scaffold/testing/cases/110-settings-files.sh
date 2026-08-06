#!/usr/bin/env bash
# Both settings files, and the home-directory expansion that keeps a real
# username out of a public repository.
CASE_NAME=110-settings-files
source "${SKILL:-/skill}/testing/assert.sh"

p=$(scaffolded_project)

assert_file "$p/.claude/settings.json" "created settings.json"
assert_file "$p/.claude/settings.local.json" "created settings.local.json"
assert_contains "$p/.claude/settings.json" '"attribution"' "settings.json carries the attribution block"
assert_contains "$p/.claude/settings.local.json" '"permissions"' "settings.local.json carries permissions"

# The permission list is project-scoped: no home paths, no machine-specific
# entries. That keeps the same file correct on every machine, and keeps a
# username out of a public repository - the PII rule as an assertion.
assert_not_contains "$p/.claude/settings.local.json" "/home/" "no home path in the generated file"
assert_not_contains "$p/.claude/settings.local.json" "/Users/" "no macOS home path either"
assert_same "$SKILL/references/templates/settings.local.json.tmpl" "$p/.claude/settings.local.json" \
  "copied verbatim from the template"
assert_contains "$p/.claude/settings.local.json" "Bash(git commit *)" "carries the project-level git entries"

# Both files are valid JSON. A settings file that does not parse is silently
# ignored by the harness, which is the worst kind of broken.
run 0 "settings.json parses" python3 -c "import json,sys; json.load(open('$p/.claude/settings.json'))"
run 0 "settings.local.json parses" python3 -c "import json,sys; json.load(open('$p/.claude/settings.local.json'))"

# Never clobber: a hand-edited settings file must survive a re-run.
printf '{"permissions":{"allow":["Bash(mine)"]}}\n' >"$p/.claude/settings.local.json"
cp "$p/.claude/settings.local.json" "$WORK/mine.json"
run 0 "re-apply over edited settings" scaffold --project "$p" --apply --yes
assert_same "$p/.claude/settings.local.json" "$WORK/mine.json" "hand-edited settings left untouched"

finish
