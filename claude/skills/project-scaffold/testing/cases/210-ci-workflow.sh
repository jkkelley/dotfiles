#!/usr/bin/env bash
# The CI workflow is opt-in: --ci copies it, no flag does not.
#
# Both halves are the contract. A workflow that arrived without --ci would put a
# red X on every host that never runs GitHub Actions, and a --ci that silently
# copied nothing would leave a project believing CI backs its entry trees when
# nothing does. The workflow is also executed, not only diffed: its run lines
# are pulled out and run against a real scaffolded tree, so a workflow that
# calls a verb the vendored scripts do not have fails here rather than on the
# first pull request.
CASE_NAME=210-ci-workflow
source "${SKILL:-/skill}/testing/assert.sh"

wf=.github/workflows/context-check.yml
tmpl="$SKILL/references/templates/ci/context-check.yml"

# --- no flag: no workflow, and no .github/ directory created on the side
p=$(scaffolded_project)
assert_no_file "$p/$wf" "no --ci, no workflow"
if [[ -e $p/.github ]]; then _fail "no --ci, no .github/" "found $p/.github"; else _pass "no --ci, no .github/"; fi
capture plan scaffold --project "$p" --json
assert_not_contains <(printf '%s' "$plan") "context-check.yml" "no --ci, workflow absent from the plan"

# --- dry run with --ci names the workflow and writes nothing
q=$(new_project)
capture plan scaffold --project "$q" --ci --json
case $plan in *'"file":".github/workflows/context-check.yml","action":"create"'*) _pass "--ci dry run plans the workflow" ;;
  *) _fail "--ci dry run plans the workflow" "got: ${plan:0:400}" ;; esac
assert_no_file "$q/$wf" "--ci dry run writes nothing"

# --- apply with --ci copies the template byte for byte
run 0 "--ci apply exits 0" scaffold --project "$q" --apply --yes --ci
assert_file "$q/$wf" "--ci copies the workflow"
assert_same "$q/$wf" "$tmpl" "workflow matches its template byte for byte"

# --- a workflow the project edited is its own: a re-run skips it
printf '# project edit\n' >>"$q/$wf"
cp "$q/$wf" "$WORK/wf-before.yml"
capture plan scaffold --project "$q" --ci --json
case $plan in *'"file":".github/workflows/context-check.yml","action":"skip"'*) _pass "existing workflow is skipped" ;;
  *) _fail "existing workflow is skipped" "got: ${plan:0:400}" ;; esac
run 0 "--ci re-apply exits 0" scaffold --project "$q" --apply --yes --ci
assert_same "$q/$wf" "$WORK/wf-before.yml" "edited workflow left byte-identical"

# --- Rule 15: every action pinned by a 40-hex commit SHA with its tag beside it
uses=$(grep -cE '^\s*-?\s*uses:' "$tmpl" || true)
pinned=$(grep -cE '^\s*-?\s*uses: [^@ ]+@[0-9a-f]{40} # v[0-9]+(\.[0-9]+)*$' "$tmpl" || true)
if ((uses > 0 && uses == pinned)); then _pass "every action pinned by SHA with a tag comment ($pinned)"; else
  _fail "every action pinned by SHA with a tag comment" "uses=$uses pinned=$pinned"; fi

# --- the workflow's own commands pass on a real tree, and fail on a broken one
mapfile -t cmds < <(sed -n 's/^ *run: //p' "$tmpl")
assert_count 2 "${#cmds[@]}" "workflow runs both check verbs"
r=$(scaffolded_project)
log_issue --project "$r" --title t --severity low --area a \
  --symptom s --trigger t --cause c --fix f --verify v >/dev/null 2>&1
backlog add --project "$r" --title t --why w --done-when d >/dev/null 2>&1
for c in "${cmds[@]}"; do
  run 0 "green tree: $c" bash -c "cd '$r' && $c"
done
printf '# hand-written\n' >"$r/ISSUES.md"
printf '# hand-written\n' >"$r/BACKLOG.md"
for c in "${cmds[@]}"; do
  run 3 "red tree: $c" bash -c "cd '$r' && $c"
done

finish
