# Onboarding checklist: the four repositories carrying the stale session-start block

Four repositories still carry the prose session-start version check that `CLAUDE.md.tmpl` dropped in PR #85.
Each needs one run of `claude/tools/skill-onboard.sh` inside it, producing one pull request in that repository.

Delivered by `WO-20260824-6a33 - Checklist for the four repositories carrying the stale session-start block`.

## This repository cannot tick a single box below

Read that before anything else, because the state column looks like every other checklist and is not one.

A row closes **only when that repository's own pull request merges.**
Not when someone here believes it will, not when a dry run looks right, and not when this ticket closes.
The work happens inside four other repositories, on four different days, and nothing in dotfiles observes it.

So this file outlives the ticket that created it.
`WO-20260824-6a33` was archived on the pull request that added this page, with all four rows open, and that is the correct end state for it.
Whoever performs a run edits the row here afterwards, in that repository's own follow-up commit to this file, and pastes the pull request URL into the Evidence column.

An unticked box on this page means the run has not merged.
It never means nobody got round to updating the page.

## State

| #   | Repository                  | Base           | Block                      | Status                                                                      | Evidence |
| --- | --------------------------- | -------------- | -------------------------- | --------------------------------------------------------------------------- | -------- |
| 1   | `gatehouse-click`           | `5d9ed0c0f50b` | `CLAUDE.md` 315-382 of 408 | [ ] open, closes only on `gatehouse-click`'s own merged PR                  |          |
| 2   | `aws-lightsail-k8s-router`  | `8f672e9689e4` | `CLAUDE.md` 363-430 of 456 | [ ] open, closes only on `aws-lightsail-k8s-router`'s own merged PR         |          |
| 3   | `template-resume-builder`   | `8be88f471d3b` | `CLAUDE.md` 131-195 of 622 | [ ] open, closes only on `template-resume-builder`'s own merged PR          |          |
| 4   | `claudes-markdown-12-rules` | `dce8129b4b3e` | `CLAUDE.md` 69-136 of 287  | [ ] **blocked**, closes only on `claudes-markdown-12-rules`'s own merged PR |          |

Every line number above was read on 2026-08-31 from that repository's `origin/main` ref at the SHA in the Base column, and every working tree was clean at the time.
**Line numbers rot, so a row's numbers mean nothing without its SHA.**
Confirm before acting on one:

```bash
git -C <repo> rev-parse --short=12 origin/main       # matches the Base column?
git -C <repo> grep -n '^## Session start' origin/main -- CLAUDE.md
```

If the SHA has moved, re-read the block position and update the row.
The Base column is not decoration; it is the only thing that makes the Block column checkable.

Row 2's SHA is deliberately not that repository's `HEAD`.
It sits on a feature branch where the same block starts at line 370, and `skill-onboard.sh` works from `origin/$BASE`, so 363 is the number that matters and 370 is the number that misleads.

## The edit, written once

All four rows perform the same edit, so it is described here and the rows point at it rather than repeating it four times and letting three copies drift.

`skill-onboard.sh` writes exactly three things, and every one is copied from the templates `project-scaffold` ships rather than re-authored:

| Path                  | Change                                                                                                  |
| --------------------- | ------------------------------------------------------------------------------------------------------- |
| `.claude/skills.toml` | created, listing that project's skills                                                                  |
| `.gitignore`          | `**/.claude/skills/` and `.claude/cache/` stanzas appended, each `grep -qxF` checked first              |
| `CLAUDE.md`           | the block in the row's range replaced in place by the `## Skills` section, roughly 68 lines becoming 10 |

and it stops git tracking the declared skill directories, one at a time, only where they were committed.

That last narrowing is deliberate and is not what `WO-20260824-6a33`'s Scope originally said.
A whole-directory `git rm -r --cached .claude/skills/` would also un-track a hand-authored project-local skill, and with `**/.claude/skills/` newly blanketed that skill would vanish from the repository with nothing reporting it.
Row 3 is the row where this matters: it carries three project-local skills that no registry knows.

The working tree is never touched.
The run leases a treehouse workbench, does the work there, and asserts the slot is free afterwards rather than trusting `treehouse return`'s exit code.

## The rows

### 1. `gatehouse-click`

Base `5d9ed0c0f50b`, block at `CLAUDE.md` 315-382.
The reference copy of the block: rows 1 and 2 are byte-identical to each other across all 68 lines.

Six skills installed, all known to the registry, so discovery needs no help:

```
container-sandbox  context-compaction  figma-wireframe
hydration-prompt   project-scaffold    work-order
```

```bash
bash ~/dotfiles/claude/tools/skill-onboard.sh --project . --dry-run
bash ~/dotfiles/claude/tools/skill-onboard.sh --project .
```

### 2. `aws-lightsail-k8s-router`

Base `8f672e9689e4` on `origin/main`, block at `CLAUDE.md` 363-430.
Byte-identical to row 1.

Five skills, all registry-known:

```
container-sandbox  context-compaction  hydration-prompt
project-scaffold   work-order
```

The local checkout is on a feature branch.
That does not affect the run, which branches from `origin/main` in a workbench, but it does mean **the line numbers you see in your editor are not the ones in this row.**

```bash
bash ~/dotfiles/claude/tools/skill-onboard.sh --project . --dry-run
bash ~/dotfiles/claude/tools/skill-onboard.sh --project .
```

### 3. `template-resume-builder`

Base `8be88f471d3b`, block at `CLAUDE.md` 131-195.

**This copy has drifted and is not byte-identical to rows 1 and 2.**
Five prose differences, plus four extra lines at the end about sending a skill fix upstream before pulling it back down.
Splicing is keyed on the heading, which is unchanged, so the run still replaces the whole section correctly.
It is called out because anything asserting "the block is identical in all four" is wrong, and because the four extra lines are worth reading once before they are deleted.

Nine skills installed, six registry-known and three project-local:

```
declared:    container-sandbox  context-compaction  cover-letter
             hydration-prompt   project-scaffold    work-order
project-local: one-off-resume   resume-onboarding   role-description
```

The three project-local skills are not declared, not un-tracked, and not touched.
Confirm that in the dry run before the real run, because this is the only row where the distinction is live.

```bash
bash ~/dotfiles/claude/tools/skill-onboard.sh --project . --dry-run
bash ~/dotfiles/claude/tools/skill-onboard.sh --project .
```

### 4. `claudes-markdown-12-rules` - blocked, do not run

Base `dce8129b4b3e`, block at `CLAUDE.md` 69-136.

**An unmodified `skill-onboard.sh` fails this repository twice.**
Both defects are recorded as a note on `WO-20260824-00d5 - Skills package manager: roll it out across the repository` and neither is on a ticket.

**Defect one: the heading does not match, and the mismatch is invisible.**

```
claudes-markdown-12-rules CLAUDE.md:69   e2 80 94   U+2014 EM DASH
the other three, and skill-onboard.sh:71  2d        U+002D HYPHEN-MINUS
```

`section_of` matches whole lines with `$0 == h`, so `LEGACY_HEADING` misses, the `else` at `skill-onboard.sh:430` fires, and the run **appends** `## Skills` at the end of the file while leaving all 68 stale lines in place above it.
It exits 0.
The failure is silent, and the two glyphs are indistinguishable in most fonts, which is why the codepoints are given rather than the characters.

**Defect two: there is nothing to declare.**
This repository has no `.claude/skills/` directory at all.
Discovery finds nothing and the run dies at `skill-onboard.sh:358` with exit 3, `nothing to declare`.

That second one is not only a defect, it is a question.
Rows 1 to 3 are **migrations**: the skills are already there and the run changes how they are managed.
Row 4 would be an **installation**: choosing skills this repository has never had.
That is a different decision and it does not have an obviously right answer, so it is not made here.

Unblocking it needs, in order:

1. `LEGACY_HEADING` matching both dash codepoints, or the heading normalised in that repository first.
2. A decision on which skills it should declare, then `--skills a,b,c` on the run.

## Running one

`--dry-run` resolves everything, prints the plan, leases no workbench and writes nothing.
It is free and it is the only step that is.
A row that sends someone straight to the real run has skipped it.

The real run does the whole thing: branch, write, un-track, commit, push, open the pull request, squash-merge, delete the branch, hand the workbench back.
Use `--no-merge` to stop after the pull request is opened and read the diff yourself.

```bash
bash ~/dotfiles/claude/tools/skill-onboard.sh --project . --no-merge
```

Exit codes worth recognising:

| Code | Meaning                                                                     |
| ---- | --------------------------------------------------------------------------- |
| 3    | nothing to declare, an unknown skill name, or the workbench was not clean   |
| 4    | a missing dependency, or the template source could not be read              |
| 5    | **the workbench is still leased.** Free the slot it names before re-running |

`skill-onboard.sh` runs from a checkout or straight off GitHub, and fetches its templates from `main` either way.
Nothing in it has been run against a real repository.
It is proved against a scratch repository in a container with a real bare origin and a stubbed `gh`, which is a deliberate non-goal of `WO-20260824-c6b0 - skill-onboard.sh brings an existing project onto the sync` and of this ticket.
Both defects on row 4 were found by reading four real repositories rather than by running against one, and a first real run is still a first real run.

## Closing a row

In the repository whose run just merged, edit this file in dotfiles:

1. `[ ] open` becomes `[x] done`.
2. Paste the pull request URL into Evidence.
3. Commit it to dotfiles on its own branch, in a pull request of its own.

Four repositories means four such edits, on four different days.
That is the cost of the state column, and it is why this page is not generated.

## Why this is not the epic's finish line

Plan `E2.10` says _"Done when: no repository on the list still carries the prose block."_
`WO-20260824-6a33` is scoped to the checklist alone, at 3 points, with the four runs named as explicit non-goals.

Those are different finish lines and only one of them can be reached from a dotfiles session.
The ticket closes when this page is accurate.
`E2.10` closes when every row above says `[x] done`.
