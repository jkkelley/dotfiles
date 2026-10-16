# Playbook: worker, the PR steps of pr-flow

## Contents

- [Source](#source)
- [Steps](#steps)
- [Records you emit](#records-you-emit)
- [What wakes you](#what-wakes-you)
- [Forbidden](#forbidden)

## Source

Ported from `~/projects/coq-jev-herdr-plugin/playbooks/worker.md` step 6 at `4f7f44c` (pr-process.md section 7, node N1).
Changes from coq: `event.sh add` becomes `pr-flow/bin/records.sh post`; there is no reviewer and no tester seat, CI on the head is the only gate (owner, 2026-10-16 UTC: "automate that process, we dont need gates we need speed").

## Steps

1. Close out on your branch, in this order: `work-order.sh evidence --observed` per criterion, commit, push, `gh pr create` with the criteria as the body.
2. `work-order.sh submit --id <id> --pr <N>`, then `work-order.sh done --id <id>`, then commit and push the archive move onto the same PR, before CI finishes.
3. Post `pr.opened 100` with sha and pr: `records.sh post --kind pr.opened --code 100 --ticket <id> --pr <N> --sha <head> --line <line> --seat <you> --key 100/<owner/name>/<N>/<head>`; the sweep posts it too, and the key keeps it to one.
4. Stop. You never merge: the merge-on-green Action merges the PR when every check on its head is green; the sweep's `merge.sh` is the backstop.

GOOD: the closing commit is pushed within a minute of `gh pr create`, so CI runs once on the final head and the Action merges it.
NEVER: `gh pr merge` by hand, `gh pr merge --auto`, or waiting on a reviewer.

## Records you emit

- `pr.opened` -> 100

## What wakes you

- `ci.failed` 422 on `line.<line>.event.ci.failed`: the failing checks are in the note; it is your fix work order, on the same branch.
- `merge.conflict` 409: merge the base into your branch and push; a conflict only on generated files is fixed by the sweep's `regen-conflicts.sh` before it reaches you.

## Forbidden

- merging your own PR by hand, or with `--auto`
- a fourth attempt at a red check; after 3 failures post `blocked 423` and stop
- prose to another agent; the record is the handoff
