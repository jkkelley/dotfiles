#!/usr/bin/env bash
# .gitignore and .dockerignore: opt-in, template-owned, never clobbered.
#
# These two files came from an upstream repo, so the thing worth asserting is
# not their exact text - that is expected to change when upstream changes - but
# that the copy is byte-identical to the template and that the scaffold's own
# entries survive the copy. A re-pull that quietly dropped `.claude/cache/`
# would start committing derived state to every project this skill touches.
CASE_NAME=120-ignore-files
source "${SKILL:-/skill}/testing/assert.sh"

gi_tmpl="$SKILL/references/templates/gitignore.tmpl"
di_tmpl="$SKILL/references/templates/dockerignore.tmpl"

# On by default. A plain scaffold gets both without asking for them - an agent
# that commits .claude/cache/ has already done the damage by review time.
p=$(scaffolded_project)
assert_file "$p/.gitignore" "created .gitignore with no flag"
assert_file "$p/.dockerignore" "created .dockerignore with no flag"
assert_same "$gi_tmpl" "$p/.gitignore" ".gitignore copied verbatim from the template"
assert_same "$di_tmpl" "$p/.dockerignore" ".dockerignore copied verbatim from the template"

# The upstream set actually arrived, not just the scaffold block.
assert_contains "$p/.gitignore" "**/node_modules/" "carries the upstream dependency rule"
assert_contains "$p/.gitignore" "!**/.env.example" "carries the upstream env-file exception"
assert_contains "$p/.dockerignore" "**/.git/" "dockerignore excludes .git from the build context"

# The scaffold's own entries survive the copy. If a future re-pull drops these,
# derived state and machine-specific settings start reaching git.
assert_contains "$p/.gitignore" ".claude/cache/" "ignores the derived cache"
assert_contains "$p/.gitignore" ".claude/settings.local.json" "ignores machine-local settings"
assert_contains "$p/.gitignore" ".issues.lock" "ignores the issue lock"
assert_contains "$p/.gitignore" ".backlog.lock" "ignores the backlog lock"

# Provenance is recorded with a placeholder owner, not a real handle - the PII
# rule as an assertion, same as 110 does for settings.
assert_contains "$gi_tmpl" "<your-github-username>" "gitignore template records upstream via a placeholder"
assert_contains "$di_tmpl" "<your-github-username>" "dockerignore template records upstream via a placeholder"

# Opt out is still possible, and opting out of one does not opt out of the other.
q=$(new_project)
run 0 "scaffold --no-gitignore" scaffold --project "$q" --apply --yes --no-gitignore
assert_no_file "$q/.gitignore" "--no-gitignore suppresses .gitignore"
assert_file "$q/.dockerignore" "--no-gitignore leaves .dockerignore alone"

# Never clobber: a hand-written ignore file must survive a re-run.
printf 'mine-only/\n' >"$p/.gitignore"
printf 'mine-only/\n' >"$p/.dockerignore"
cp "$p/.gitignore" "$WORK/mine.gitignore"
run 0 "re-apply over edited ignore files" scaffold --project "$p" --apply --yes
assert_same "$p/.gitignore" "$WORK/mine.gitignore" "hand-edited .gitignore left untouched"
assert_same "$p/.dockerignore" "$WORK/mine.gitignore" "hand-edited .dockerignore left untouched"

finish
