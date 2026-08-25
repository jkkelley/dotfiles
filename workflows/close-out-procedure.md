# Close-out procedure

<!-- workflow-version: 1.0.0 -->

How a ticket in this repository goes from started to shipped.

**Everything happens on the feature branch, inside one pull request.** Nothing is
written to `main` afterwards. The only thing that follows the merge is deleting
the branches, and that writes nothing at all.

## The procedure

```
ON THE FEATURE BRANCH
│
├─ work-order.sh start --id WO-...        creates feat/<slug>, leaves files uncommitted
│
├─ do the work, suite green in Podman     Rule 14, no size threshold
│
├─ skill-version.sh bump <skill> --patch  Rule 16, only if a skill was touched
│  skill-version.sh verify                must be rc 0
│
├─ work-order.sh evidence --index N --observed "..."     one per acceptance criterion
│
├─ git push -u origin <branch>
├─ gh pr create
│
├─ work-order.sh submit --id WO-... --pr N       in-progress ──> in-review
│
├─ work-order.sh done --id WO-...                in-review ──> done
│     stamps closed, moves the ticket to work-orders/archive/<year>/,
│     prunes an emptied epic directory, regenerates INDEX.md and the
│     epic READMEs, and commits NOTHING
│
├─ hydration.sh check --body-file <file>         rc 0, or add refuses
├─ hydration.sh add --id <next> --title "..." --body-file <file>
│
└─ git add -A && git commit && git push          rides the SAME pull request
   │
   ▼
   REVIEW  ── review on the branch, fixes land on the branch
   │
   └─ gh pr merge <N> --squash --delete-branch
      │
      ▼
   AFTER THE MERGE
   │
   └─ work-order.sh cleanup --id WO-...          deletes both branches, writes nothing
```

## Why it is shaped like this

**One pull request holds everything.** The code, the evidence, the ticket
transition, the archive move and the hydration entry all land in the same commit
range. Reading that PR tells you what changed and that it was finished. There is
no second place to look.

**`done` does the whole close-out.** It stamps, archives, prunes and reindexes,
and it leaves every one of those changes uncommitted so they ride the pull
request rather than arriving separately.

**`cleanup` is not bookkeeping.** It fetches, fast-forwards `main`, and deletes
the local and remote branch. It refuses unless `gh` reports the pull request
`MERGED`, because that assertion is guarding a delete. It is idempotent, so it is
safe to re-run, and safe days later on a second machine that still holds the
local branch.

**There is no `merge_sha`.** It was the only field that could not be known on the
branch, since a commit cannot contain its own merge SHA, and storing it was the
single reason close-out used to need a second act after the merge. `pr` is the
durable pointer:

```sh
gh pr view 60 --json mergeCommit -q .mergeCommit.oid   # with a network
git log --grep='(#60)' --oneline                       # without one
```

One redundant field was generating an entire second phase. It is gone and nothing
was lost with it.

## The order that matters

`submit` must run before `done`. The lifecycle is
`in-progress --submit--> in-review --done--> done`, so the pull request has to
exist before the ticket can be marked done. That pins both steps into the window
between `gh pr create` and the merge.

Everything after `done` in that window - the hydration entry, the final commit -
is in that window for the same reason: it belongs to the pull request.

## What this replaces

Close-out used to be split. `done` stamped a status on the branch; a separate
`close` command wrote the archive straight to `main` in a second commit after the
merge, and fell back to opening a second pull request when that push was
rejected.

That produced an ordering trap with no good failure mode. If `done` and the
hydration entry did not make it onto the pull request before the merge, they were
stranded on a deleted branch, and `close` refused with:

```
WO-... reached done on the feature branch, but main's copy still says
'in-review': the PR carrying that transition has not merged to main yet.
```

The only way out was a second pull request carrying the two stranded files - the
exact cost the design was trying to avoid. The trap is gone because the window it
lived in is gone.

## Roll forward

A branch is reviewed and merged. It is not closed, parked, or reopened.

If something lands broken, the fix is a new branch and a new ticket, not a revert
of the ticket that shipped it. `reopen` exists for a ticket whose work was wrong,
and it clears `closed` and returns the ticket to `in-progress`; it is not the
routine path and it is not how a bug in shipped work is handled.

## Verifying the procedure holds

The document is the explanation. The script is the enforcement.

Nothing can diff prose against behaviour, so the assertions live in
`claude/skills/work-order/testing/run-tests.sh`:

- after `done`, the ticket file is under `work-orders/archive/<year>/`
- after `done`, nothing is committed - the move is left in the working tree
- `cleanup` adds no commit to `main`
- `cleanup` refuses when the pull request is not `MERGED`
- `cleanup` is idempotent against a branch that is already gone

`tools/workflow-version.sh verify` asserts that this document carries a version.
That catches an unversioned procedure joining the set. It cannot catch this
document describing something the script stopped doing - only the tests above do
that.
