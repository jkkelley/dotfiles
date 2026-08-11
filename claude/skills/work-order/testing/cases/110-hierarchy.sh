#!/usr/bin/env bash
# Hierarchy: a child is written under its parent, and re-homing carries the
# grandchildren with it. The layout is the record of the work, so a move that
# leaves a descendant behind is a lost ticket, not a cosmetic problem.
source "${SKILL:-/skill}/testing/assert.sh"

mk() { # mk <dir> <title> [extra flags...]
  local d="$1" t="$2"; shift 2
  wo new --project "$d" --title "$t" --type feature --problem "p" \
     --out "non-goal" --ac "checked by a command" "$@" 2>/dev/null | tail -1
}

d=$(new_project)
epic=$(mk "$d" "Epic router")
kid=$(mk "$d" "Child one" --parent "$epic")
gkid=$(mk "$d" "Grandchild" --parent "$kid")

assert_file "$d/work-orders/${epic}-epic-router.md" "a parentless ticket sits at the root"
assert_file "$d/work-orders/$epic/${kid}-child-one.md" "a child sits in its parent's directory"
assert_file "$d/work-orders/$epic/$kid/${gkid}-grandchild.md" "nesting recurses"

f="$d/work-orders/$epic/${kid}-child-one.md"
assert_contains "$f" "\"parent\": \"$epic\"" "the child records its parent in frontmatter"

# An ID must resolve wherever it sits - that is what keeps every recorded path
# and every later transition working after a move.
run 0 "show resolves a nested ticket by ID alone" wo show --project "$d" --id "$gkid" --json

run 6 "--parent refuses an ID that does not exist" \
  wo new --project "$d" --title "Orphan" --type chore --problem "p" --out "o" \
     --parent WO-20260101-ffff
run 3 "a ticket cannot be its own parent" wo link --project "$d" --id "$kid" --parent "$kid"
run 3 "a parent cannot be its own descendant" wo link --project "$d" --id "$epic" --parent "$gkid"

# Re-homing. The grandchild must travel with the child.
run 0 "detach moves a child back to the root" wo link --project "$d" --id "$kid" --detach
assert_file "$d/work-orders/${kid}-child-one.md" "the detached ticket is at the root"
assert_file "$d/work-orders/$kid/${gkid}-grandchild.md" "its child came with it"
assert_no_file "$d/work-orders/$epic/${kid}-child-one.md" "and left nothing behind"

assert_no_file "$d/work-orders/$epic/README.md" \
  "an epic that lost its last child does not keep an empty directory open"

run 0 "link --parent re-homes it" wo link --project "$d" --id "$kid" --parent "$epic"
assert_file "$d/work-orders/$epic/$kid/${gkid}-grandchild.md" "the grandchild is back under the epic"

# Every level of the tree carries a generated explainer, so a reader who lands in
# an epic directory is never looking at a bare pile of files.
assert_file "$d/work-orders/$epic/README.md" "an epic directory gets a generated README"
assert_contains "$d/work-orders/$epic/README.md" "$kid" "it lists the direct child"
assert_not_contains "$d/work-orders/$epic/README.md" "$gkid" \
  "and not the grandchild - one level down only"
run 0 "reindex --check passes with the READMEs in place" wo reindex --project "$d" --check
printf 'hand edited\n' >>"$d/work-orders/$epic/README.md"
run 3 "reindex --check catches a child README that drifted" wo reindex --project "$d" --check

finish
