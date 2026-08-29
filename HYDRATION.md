# HYDRATION.md

The prompt that starts the next session, and the 10 before it.

**Read the top entry only.** It is the current one and it is complete on its own.
Everything below it has been superseded and is kept for history, not for reading.

**Newest on top.** Adding an entry removes the oldest in the same commit, so this
file holds exactly 10 once it has filled up. Entries are never renumbered and
never edited in place - a correction is a new entry.

Written by `hydration.sh add`. Do not hand-edit.
<!-- hydration-entry: none -->
## Epic 1 is closed - pick the next p2 from the rollout epic
_Generated 2026-08-29 by hydration.sh. Newest entry._

### Ticket

Nothing is assigned. Pick from `work-order next`, which returns eight, all `p2`, all `ready`:

`WO-20260824-00d5` - `Skills package manager: roll it out across the repository` and its seven startable children - `WO-20260824-81a6` - `project-scaffold plumbing: skills.toml, the gitignore blanket, scaffold.json removed, skill-update.sh narrowed`, `WO-20260824-a6cb` - `The hydration-prompt close-out acquires and releases a treehouse slot`, `WO-20260824-b21b` - `CLAUDE.md.tmpl: replace the session-start prose, add the skills markers, the treehouse policy and the documentation-lifetime rule`, `WO-20260824-c6b0` - `skill-onboard.sh brings an existing project onto the sync`, `WO-20260824-d058` - `Remove the inline read-only notice from the other 42 SKILL.md files`, `WO-20260824-6a33` - `Checklist for the four repositories carrying the stale session-start check`, and `WO-20260824-79b6` - `Invert the notice assertion: verify --structure now fails on an inline notice`.

The eighth child, `WO-20260824-238b` - `Rename skill-versioning to skill-registry, the closing commit`, is the epic's closing commit and waits on the other seven.

There is also one `draft`, deliberately unapproved and therefore not in `next`: `WO-20260829-f97b` - `verify names nothing when only a tool has drifted`. Read it and approve or cancel it before starting anything else, because it records a regression this session shipped knowingly.

**Ask the user which one, rather than choosing.** They are all p2 and the ordering between them is a judgement about what the repository needs next, not something `next` can answer.

### What just landed

**Epic 1 closed, and the defect it surfaced was fixed.** Three pull requests.

PR #78 - `WO-20260825-dac4` - `verify --structure refuses a brand new skill, whichever way it is written`. `registry_has` is a new function in `claude/skills/skill-versioning/scripts/skill-version.sh`, and absence from `registry.json` is now the test for "this skill is new" - the same test `bump-gate.sh cmd_resolve` already made. Two call sites, both gated on `--structure`: `cmd_verify`'s version loop no longer calls an unregistered skill `unversioned`, and `diff_check` no longer reads its `version:` line as a hand-edit. `diff_check` also exempts a `SKILL.md` gone from the working tree, the deletion half of a rename. All three criteria observed on the real gate, not locally: runs 33203202657, 33203318713 and 33203392408. Two throwaway probes were reverted inside that same pull request and neither reached `main`.

PR #79 - `WO-20260824-f1a5` - `Skills package manager: prove the path on one skill` is `done` and archived, after all fourteen children shipped. It touched no skill; `detect` emitted `skills=[]`, `tools=false`, `gate=false`.

PR #80 - `WO-20260829-5ad4` - `verify's drift report walks the registry's tools block and names tools as missing skills`. Both of `cmd_verify`'s reporting loops walked every four-space-indented entry in the whole registry, and `render_tools` writes at that indent, so a failing plain `verify` printed `stale entry       skill-sync (no such skill)` and the same for `read-only-notice`. `skills_block` is a stdin filter using the same `sed` range `bump-lib.sh`'s `registry_version` uses; both loops and the `grep -m1` inside the drift loop now go through it. No exit code moved.

`skill-versioning`'s suite went 103 -> 120 -> **131**. `container-sandbox/references/skill-testing.md` gained `Driving a repository-level gate against the real tree`.

The publisher allocated `skill-versioning -> 2.0.1` and `container-sandbox -> 1.4.0` at `e292575`. Nobody typed either.

### What is NOT done

**A regression was shipped knowingly on PR #80 and it is on a ticket.** Scoping the drift loops means a tree where every skill is in sync and only a _tool_ has changed now fails `verify` and names nothing - the reader gets the generic trailer and no line saying it was a tool or which one. Before, they got the right filename under the wrong label. `WO-20260829-f97b` - `verify names nothing when only a tool has drifted` is cut as a `p3` and left in `draft` for review rather than self-approved. `claude/tools/` is a live workflow, so this is a shape someone will hit.

**The eight children of `WO-20260824-00d5` - `Skills package manager: roll it out across the repository` are all still `ready`.** Nothing in epic 2 has started.

Branch protection is still absent and is still on no ticket.

Root `CLAUDE.md`'s `## Consuming These Files` section still contradicts Rule 16 steps 7 and 8, and **it is still on no ticket** after four cycles of being named here. It tells a consumer to clone or symlink `claude/skills/` via `setup.sh` and never mentions `.claude/skills.toml` or `skill-sync.sh`. If it is not going to be fixed, it wants a ticket saying so, so it stops being carried forward as a loose end nobody owns.

### Stale or false in the docs

**`claude/skills/hydration-prompt/SKILL.md:38` still puts `archive - work-order.sh close, straight to main` under `AFTER THE MERGE`.**
There is no `close` verb. The lifecycle ends at `done`, on the branch, inside the PR. Do not follow the diagram.

The same dead reference lives at `claude/skills/project-scaffold/references/templates/CLAUDE.md.tmpl:207` and `:248`, which is `WO-20260824-b21b` - `CLAUDE.md.tmpl: replace the session-start prose, add the skills markers, the treehouse policy and the documentation-lifetime rule`, and at `claude/skills/work-order/settings.local.json.tmpl:6`, which is on no ticket.

**Both design documents still say the runner only has Docker.** `ubuntu-24.04` ships Podman 5.8.4.

`claude/skills/skill-versioning/SKILL.md` is accurate about `--structure`. Root `CLAUDE.md` Rule 16 is accurate.

### Your scope

Whichever ticket the user names, and nothing beside it.

If it is `WO-20260824-d058` - `Remove the inline read-only notice from the other 42 SKILL.md files`, note that it and `WO-20260824-79b6` - `Invert the notice assertion: verify --structure now fails on an inline notice` are two halves of one change and the order matters: inverting the assertion first turns 42 files red at once.

If it is `WO-20260824-238b` - `Rename skill-versioning to skill-registry, the closing commit`, the gate is now ready for it - PR #78 proved a renamed directory green both when git pairs the two paths and when it cannot - but the other seven children come first, and the rename also moves paths that `.github/workflows/skill-pr-gate.yml` and `bump-gate.sh run-suite` name literally.

**Non-goal for every one of them: do not start a second ticket in the same branch.** Epic 2 is eight tickets, not one.

### Before you start

`work-order.sh start` needs a clean tree and creates the branch for you. It leaves the ticket file and `INDEX.md` uncommitted, so commit them before anything else.

Every ticket named above is already `approved`. Do not run `approve` again. `WO-20260829-f97b` - `verify names nothing when only a tool has drifted` is the exception and is `draft` on purpose.

**`.claude/worktrees/smoke-tests` is a locked git worktree sitting untracked inside this repository**, left by a session before epic 1. It is not yours. It means `git add -A` at close-out is unsafe here - add explicit paths instead, which is what PR #76 through #80 all did.

### Read in this order

1. `work-order.sh next`, then the ticket the user names, and every note on it.
2. This entry, the top entry of `HYDRATION.md`. Read only this one.
3. `work-orders/WO-20260824-00d5/` - the epic README, for how its eight children fit together.
4. Root `CLAUDE.md` Rule 16 and `## Close-out and post-merge cleanup`. Both accurate.
5. `workflows/close-out-procedure.md`, once.

### Reuse, it is proven

`skills_block` in `skill-version.sh` and `registry_version` in `bump-lib.sh` are the same idiom, and between them they are now the only correct way to read a name out of `registry.json`. Anything new that reads that file goes through one of them rather than grepping the whole thing.

`bump-gate.sh detect` answers "which suites must run", `resolve` answers "what level does each changed skill get". They disagree by design for a skill that ships no suite. Do not reconcile them.

`container-sandbox/references/skill-testing.md` now covers three shapes: the bundled-script case, the live-infrastructure split, and `Driving a repository-level gate against the real tree` - clone inside the container from a read-only `/repo` mount so `origin/main` resolves. If a check here needs a container and the pattern is not documented, write the section rather than falling back to the host.

Section 6b of `claude/skills/skill-versioning/testing/run-tests.sh` builds a fixture tool with a `skill-tool-version:` marker and drives a populated tools block. Any assertion about the tools block wants that fixture.

### The verification ladder

Rung 1: the changed skill's own suite, via `bash .github/scripts/bump-gate.sh run-suite claude/skills/<name>`. Never `bash <suite>` directly.

Rung 2: `skill-version.sh verify --structure --base origin/main` on the branch. Green.

Rung 3: for anything touching the registry's readers, plain `verify` on a clone of `main` in a container. Green, `ok - 43 skills versioned, registry in sync`.

Rung 4: the nine suites, at 251, 299, 161, 145, **131**, 85, 47, 41 and 39. Only run all nine when the change reaches beyond one skill; a single-skill change wants rung 1 and the gate.

Rung 5: the gate on the pull request. It is the only place the gate exists, so a green local `--structure` is not the same claim.

### Traps, already paid for

**A markdown formatter re-pads tables in a file you only meant to add a line to.** It is a `PostToolUse` hook in the machine's global `~/.claude/settings.json`. `git diff -U0 | grep '^-'` before committing and account for every deleted line.

**`work-order.sh start` moves you to a new branch and there is no flag to stop it.** That is what kept epic 1 from closing inside its last child's pull request, and it cost an extra ticket cycle. Plan the branch before running it, never during a close-out.

**A suite with no self re-exec, run as `bash <suite>`, runs on the host and fails with `mkdir: cannot create directory '/work'`.** Use `bump-gate.sh run-suite`, which dispatches `self` or `wrapped` correctly.

**A `grep -q` in a pipeline reports "no match" when it matched.** It closes the pipe on the first hit, the upstream dies of SIGPIPE, and `pipefail` turns that into a non-zero pipeline. Capture to a variable and grep the variable.

**A digest you did not copy from a real registry does not exist.** `podman pull` fails with `manifest unknown`, which reads like a network problem and is not. Reuse the `bitnami/git` digest this repository already pins.

**Scoping a report can silence it.** PR #80 stopped two false lines and, in the same move, stopped a true one nobody had asked about. Assert the positive and the negative on the same tree in the same run, or the wrong implementation passes.

`gh pr create` warns `1 uncommitted change` because of the untracked `.claude/worktrees/`. Expected, not your branch.

### Workflow

```bash
WO=claude/skills/work-order/scripts/work-order.sh
HP=claude/skills/hydration-prompt/scripts/hydration.sh

bash $WO next    --project .
bash $WO show    --project . --id <the one the user named>
bash $WO start   --project . --id <id>
git add work-orders && git commit -m "chore(work-orders): start <id>"

# ... the work ...

bash .github/scripts/bump-gate.sh run-suite claude/skills/<skill>

bash $WO evidence --project . --id <id> --index N --observed '...'
git add <explicit paths>            # NOT -A, see .claude/worktrees/smoke-tests above
git commit && git push -u origin <branch>
gh pr create --base main --title "..." --body-file <file>
bash $WO submit  --project . --id <id> --pr <N>
bash $WO done    --project . --id <id>              # on the branch, before the merge
bash $HP check   --project . --body-file /tmp/entry.md
bash $HP add     --project . --id <next> --title "<next title>" --body-file /tmp/entry.md
git add <explicit paths> && git commit && git push  # rides the SAME pull request

# after the merge
bash $WO cleanup --project . --id <id>
```

**A pull request touching `claude/skills/` needs a level.** A conventional title resolves it for a single-skill change; otherwise state `Bump: <skill>=major|minor|patch` as the last paragraph of the body, one line per changed skill, nothing after it. **Never run `skill-version.sh bump`.** The publisher allocates on `main`.

### Conventions

Every reference to a work-order in a chat reply carries the ticket ID and its full title joined by a dash. A bare ID is a defect, and so is "the next ticket" or "the draft one".

Feature branches only. `skill-publish.yml` is the one named exception, and root `CLAUDE.md` says so.

PR bodies carry no agent attribution, Rule 13.

No em dashes. Plain dashes only, in every file and every reply.

<!-- hydration-entry: WO-20260829-5ad4 -->
## WO-20260829-5ad4 - verify's drift report walks the registry's tools block and names tools as missing skills
_Generated 2026-08-29 by hydration.sh. Newest entry._

### Ticket

`WO-20260829-5ad4` - `verify's drift report walks the registry's tools block and names tools as missing skills`.
It is a `bug`, `p2`, top-level, with no parent, no dependency and nothing blocked on it.
`work-order next` returns it last of seven, all p2, so it is a choice rather than a queue position - it is here because it is small, self-contained, and it is the only ticket on the board that was found by running the pipeline rather than by planning it.

The alternative is any of the eight children of `WO-20260824-00d5` - `Skills package manager: roll it out across the repository`, which is the migration epic and is much larger.

### What just landed

**Epic 1 closed.** `WO-20260824-f1a5` - `Skills package manager: prove the path on one skill` is `done` and archived, in PR #79, after all fourteen of its children shipped.

Two pull requests landed since the last entry.

PR #78 fixed the hole this whole handoff chain was named after. `registry_has` is a new function in `claude/skills/skill-versioning/scripts/skill-version.sh`, and absence from `registry.json` is now the test for "this skill is new" - the same test `bump-gate.sh cmd_resolve` already made. Two call sites use it, both gated on `--structure`: `cmd_verify`'s version loop no longer calls an unregistered skill `unversioned`, and `diff_check` no longer reads its `version:` line as a hand-edit. `diff_check` also exempts a `SKILL.md` gone from the working tree, which is the deletion half of a rename. Plain `verify` is unchanged and still refuses any unversioned skill.

All three of that ticket's criteria were observed on the real gate, not locally: a new skill directory with no `version:` line green on run 33203202657, a hand-edited registered version red and named on run 33203318713, and `git mv` on the registered `repo-sync` green on run 33203392408. Both probes were reverted inside the same pull request and neither reached `main`.

The publisher then allocated `skill-versioning -> 2.0.1` and `container-sandbox -> 1.4.0` on `main` at `e292575`, from the two `Bump:` trailers. Nobody typed either number.

PR #79 closed the epic and cut this ticket. It touched no skill.

`skill-versioning`'s suite is at **120**, up from 103. `container-sandbox/references/skill-testing.md` gained a section, `Driving a repository-level gate against the real tree`.

### What is NOT done

**The eight children of `WO-20260824-00d5` - `Skills package manager: roll it out across the repository` are all still `ready`.** Nothing in epic 2 has started. That is the state, not a warning.

Branch protection is still absent and is still on no ticket.

The other 42 notices are still inline: `WO-20260824-d058` - `Remove the inline read-only notice from the other 42 SKILL.md files`.

Root `CLAUDE.md`'s `## Consuming These Files` section still contradicts Rule 16 steps 7 and 8, and **it is still on no ticket** after three cycles of being named here. It tells a consumer to clone or symlink `claude/skills/` via `setup.sh` and never mentions `.claude/skills.toml` or `skill-sync.sh`. `WO-20260824-c6b0` - `skill-onboard.sh brings an existing project onto the sync` is the nearest thing and does not cover it. If it is not going to be fixed, it wants a ticket saying so.

### Stale or false in the docs

**`claude/skills/hydration-prompt/SKILL.md:38` still puts `archive - work-order.sh close, straight to main` under `AFTER THE MERGE`.**
There is no `close` verb. The lifecycle ends at `done`, on the branch, inside the PR. Not your ticket, and do not follow the diagram.

The same dead reference lives at `claude/skills/project-scaffold/references/templates/CLAUDE.md.tmpl:207` and `:248`, which is `WO-20260824-b21b` - `CLAUDE.md.tmpl: replace the session-start prose, add the skills markers, the treehouse policy and the documentation-lifetime rule`, and at `claude/skills/work-order/settings.local.json.tmpl:6`, which is on no ticket.

**Both design documents still say the runner only has Docker.** `ubuntu-24.04` ships Podman 5.8.4.

`claude/skills/skill-versioning/SKILL.md` is accurate about `--structure`, including the new-skill exemption and both halves of a rename.

### Your scope

Two loops in `cmd_verify`, in `claude/skills/skill-versioning/scripts/skill-version.sh`, and the cases that prove them.

Both walk every line of their input beginning with four spaces and a quote. `render_tools` writes the tools block at that same indent, so both read tool entries as skill entries.

- `skill-version.sh:541` is the visible symptom. A _failing_ plain `verify` prints `stale entry       skill-sync (no such skill)` and the same for `read-only-notice`, because `claude/skills/skill-sync/` is not a directory and never will be.
- `skill-version.sh:529` is the latent one and is worse. Change a tool file and the drift loop prints `drifted           skill-sync`, and the trailer then tells the reader to run `skill-version.sh bump skill-sync --patch`, which dies with `no such skill`.
- `skill-version.sh:532`, the `grep -m1` lookup inside that loop, wants the same scoping so a tool can never satisfy a skill's name.

Neither is a gate failure. Both only appear in output that has already failed for another reason, which is exactly when naming the wrong cause does damage.

**Non-goals, and one is easy to break by accident: no exit code moves.** This is message quality. A `verify` that was red stays red and a green one stays green; only the lines between change. Do not give tools their own drift report or bump path - that is a feature and it is not this ticket. Do not touch `render_tools` or the registry format: the indent is fine, the readers are wrong.

### Before you start

`work-order.sh start` needs a clean tree, and it will create `feat/verify-s-drift-report-walks-the-registry-s-tools` for you.
`start` leaves the ticket file and `INDEX.md` uncommitted, so commit them before anything else.
`approve` has already been run on this ticket and must not be run again.

**`.claude/worktrees/smoke-tests` is a locked git worktree sitting untracked inside this repository**, left by a session before epic 1. It is not yours. It means `git add -A` at close-out is unsafe here - add explicit paths instead, which is what PR #76 through #79 all did.

### Read in this order

1. The ticket, `work-orders/WO-20260829-5ad4/`. Its Problem section names both loops and both line numbers.
2. This entry, the top entry of `HYDRATION.md`. Read only this one.
3. `claude/skills/skill-versioning/scripts/skill-version.sh` - `cmd_verify` from line 500, and `render_tools` at 211 for why the indents collide.
4. `.github/scripts/bump-lib.sh` `registry_version` at 74, which is the idiom to copy.
5. Root `CLAUDE.md` Rule 16, which is accurate.

### Reuse, it is proven

`bump-lib.sh`'s `registry_version` already solves this exact problem and is the model. It scopes its lookup with `sed -n '/^  "skills": {/,/^  },/p'` before grepping, and its comment says why: "The registry is one entry per line and the skills block ends before the tools block. Scoping the lookup to that range costs one sed and removes the only way a tool name could ever be mistaken for a skill's version."

`registry_has`, added to `skill-version.sh` by PR #78, already uses that same idiom inside this file. A stdin filter next to it is the smallest shape that serves both loops - one reads the file, the other reads the `$expected` string.

Section 6b of `claude/skills/skill-versioning/testing/run-tests.sh` already builds a fixture tool at `$WORK/tools/partials/read-only-notice.md.tmpl` with a `skill-tool-version: 2.1.0` marker and drives a populated tools block. That is the fixture these cases want and it exists.

`neg` in that suite inverts a command's success into `check()`'s 0-is-good convention, which is what an assertion of the form "this string does NOT appear" needs.

### The verification ladder

Rung 1: `bash .github/scripts/bump-gate.sh run-suite claude/skills/skill-versioning`. It is at **120** and your new cases move it.

Rung 2: the failing-verify output itself. Build the section 6b fixture, populate the tools block, introduce a real drift, and read the whole stderr. No `stale entry` naming `skill-sync` or `read-only-notice`, and the real drift still named.

Rung 3: the narrowing did not become a silencing. A genuinely stale _skill_ entry - a registry row whose directory is gone - is still reported on that same run. This is the assertion a careless fix breaks.

Rung 4: a changed tool file is not reported as a drifted skill.

Rung 5: plain `verify` on the real `main` tree in a container, green, `ok - 43 skills versioned, registry in sync`. The pattern is written down now: `container-sandbox/references/skill-testing.md`, section `Driving a repository-level gate against the real tree`.

Rung 6: the nine suites at 251, 299, 161, 145, **120 + yours**, 85, 47, 41 and 39.

### Traps, already paid for

**A markdown formatter re-pads tables in a file you only meant to add a line to.** It is a `PostToolUse` hook in the machine's global `~/.claude/settings.json`. `git diff -U0 | grep '^-'` before committing and account for every deleted line; on PR #78 four deletions turned out to be one table re-padded after a single-cell edit.

**A suite with no self re-exec, run as `bash <suite>`, runs on the host and fails with `mkdir: cannot create directory '/work'`.** Use `bash .github/scripts/bump-gate.sh run-suite <dir>`, which dispatches `self` or `wrapped` correctly.

**A `grep -q` in a pipeline reports "no match" when it matched.** It closes the pipe on the first hit, the upstream dies of SIGPIPE, and `pipefail` turns that into a non-zero pipeline. `diff_check` has a comment about this above the line that avoids it. Capture to a variable and grep the variable.

**`work-order.sh start` moves you to a new branch and there is no flag to stop it.** That is what kept epic 1 from closing inside its last child's pull request. Plan the branch before running it, never during a close-out.

**A digest you did not copy from a real registry does not exist.** `podman pull` fails with `manifest unknown`, which reads like a network problem and is not. Reuse the `bitnami/git` digest this repository already pins rather than inventing one.

`gh pr create` warns `1 uncommitted change` because of the untracked `.claude/worktrees/`. That warning is expected and is not your branch.

### Workflow

```bash
WO=claude/skills/work-order/scripts/work-order.sh
HP=claude/skills/hydration-prompt/scripts/hydration.sh

bash $WO show    --project . --id WO-20260829-5ad4
bash $WO start   --project . --id WO-20260829-5ad4   # creates the branch, leaves files uncommitted
git add work-orders && git commit -m "chore(work-orders): start WO-20260829-5ad4"

# ... scope both loops, add the section 6b cases ...

bash .github/scripts/bump-gate.sh run-suite claude/skills/skill-versioning

bash $WO evidence --project . --id WO-20260829-5ad4 --index N --observed '...'
git add <explicit paths>            # NOT -A, see .claude/worktrees/smoke-tests above
git commit && git push -u origin feat/verify-s-drift-report-walks-the-registry-s-tools
gh pr create --base main --title "fix(skill-versioning): ..." --body-file <file>
bash $WO submit  --project . --id WO-20260829-5ad4 --pr <N>
bash $WO done    --project . --id WO-20260829-5ad4   # on the branch, before the merge
bash $HP check   --project . --body-file /tmp/entry.md
bash $HP add     --project . --id <next> --title "<next title>" --body-file /tmp/entry.md
git add <explicit paths> && git commit && git push   # rides the SAME pull request

# after the merge
bash $WO cleanup --project . --id WO-20260829-5ad4
```

**This ticket changes `claude/skills/skill-versioning/`, so it needs a level.** A `fix(` title resolves it on its own for a single-skill pull request, or state `Bump: skill-versioning=patch` as the last paragraph of the body with nothing after it. **Do not run `skill-version.sh bump`.** The publisher allocates on `main`.

### Conventions

Every reference to a work-order in a chat reply carries the ticket ID and its full title joined by a dash. A bare ID is a defect, and so is "the next ticket" or "the bug".

Feature branches only. `skill-publish.yml` is the one named exception, and root `CLAUDE.md` says so.

PR bodies carry no agent attribution, Rule 13.

No em dashes. Plain dashes only, in every file and every reply.

<!-- hydration-entry: WO-20260824-f1a5 -->
## WO-20260824-f1a5 - Skills package manager: prove the path on one skill
_Generated 2026-08-28 by hydration.sh. Newest entry._

### Ticket

`WO-20260824-f1a5` - `Skills package manager: prove the path on one skill`.
It is a `feature`, `p1`, top-level, and it is now an **epic with no children left**.
Its last child `WO-20260825-dac4` - `verify --structure refuses a brand new skill, whichever way it is written` is `done`, merged, and archived to `work-orders/archive/2026/`.
`work-order next` returns it first, and it is the only p1 on the board.

The four p2 tickets under `WO-20260824-00d5` - `Skills package manager: roll it out across the repository` are the work after this, not the work instead of it.

### What just landed

`verify --structure` no longer refuses a brand new skill. PR #78.

`registry_has` is a new eight-line function in `claude/skills/skill-versioning/scripts/skill-version.sh`, next to `registry_schema`.
It answers one question: is this name in the skills block of `registry.json`.
Absence is the test for "the skill is new", the same test `bump-gate.sh cmd_resolve` already made before printing a row as `- -> 1.0.0 new absent from the registry`.

Two call sites use it, both inside `--structure` only.
`cmd_verify`'s version loop skips the `unversioned` refusal for a skill the registry has never carried and collects it into `new_skills` instead, whether or not the author wrote a `version:` line by hand.
`diff_check` skips the `version:`-in-the-diff refusal for the same skill, and skips it again for a `SKILL.md` that is gone from the working tree - the deletion half of a rename, exempted for the reason `bump-lib.sh`'s `skill_exists` already exempts it.

The success line changed shape and now names what it let through:

```text
new           repo-sync-renamed  (absent from the registry, CI stamps it at 1.0.0)
ok - 44 skills, 2 new, no version: or registry.json in the diff
```

**Plain `verify` is byte-for-byte unchanged in behaviour.** The exemption is gated on `$structure -eq 1`, and the suite asserts plain `verify` still refuses the same unversioned skill `--structure` just accepted, on the same tree, in the same run.

`skill-versioning`'s suite is at **120**, up from 103. Seventeen net new checks in three sections: `5b` a new skill written both ways plus a registered skill's version hand-edited beside it, `5c` a `git mv` rename and a registered skill deleted outright, and one case in section 5 rewritten because it had been asserting the bug.

`container-sandbox/references/skill-testing.md` gained a section, `Driving a repository-level gate against the real tree` - clone inside the container from a read-only `/repo` mount so `origin/main` resolves to the real commit. It was written because Rule 14 requires the pattern to exist before it is used, and no section covered a script whose input is the repository itself.

Nothing else changed. `bump-gate.sh`, `publish.sh`, both workflows and `registry.json` were untouched.

### What is NOT done

**The epic did not close, and this time the reason is structural rather than an oversight.**
`done` requires `in-review`, which requires `submit`, which requires `in-progress`, and `start` is the only way in.
`start` refuses a dirty tree and then runs `git checkout -b feat/<slug>`, which would have abandoned `WO-20260825-dac4`'s own branch in the middle of its close-out.
Stamping `.branch` with a branch that never carried a commit would have been a false record, so it was not done.
The reasoning is recorded as a note on `f1a5` itself, not only here.

**Closing it is your ticket and it needs its own branch.** That is the whole of the scope below.

Branch protection is still absent and is still on no ticket.

The other 42 notices are still inline: `WO-20260824-d058` - `Remove the inline read-only notice from the other 42 SKILL.md files`.

Root `CLAUDE.md`'s `## Consuming These Files` section still contradicts Rule 16 steps 7 and 8, and **it is still on no ticket.** It tells a consumer to clone or symlink `claude/skills/` via `setup.sh` and never mentions `.claude/skills.toml` or `skill-sync.sh`. Surfaced on PR #77, carried forward untouched by PR #78 because it is not this ticket either. `WO-20260824-c6b0` - `skill-onboard.sh brings an existing project onto the sync` is the nearest thing and does not cover it.

**A cosmetic defect found on PR #78 and deliberately not fixed.** `cmd_verify`'s stale-entry loop matches every line in `registry.json` beginning with four spaces and a quote, which includes the `tools` block, so a _failing_ plain `verify` prints `stale entry       skill-sync (no such skill)` and the same for `read-only-notice`. It only appears in output that already failed for another reason, it predates the branch - it arrived the moment `claude/tools/` stopped being empty - and it is on no ticket. Recorded as a note on `WO-20260825-dac4`.

### Stale or false in the docs

**`claude/skills/hydration-prompt/SKILL.md:38` still puts `archive - work-order.sh close, straight to main` under `AFTER THE MERGE`.**
There is no `close` verb. The lifecycle ends at `done`, on the branch, inside the PR. Not your ticket, and do not follow the diagram.

The same dead reference lives at `claude/skills/project-scaffold/references/templates/CLAUDE.md.tmpl:207` and `:248`, which is `WO-20260824-b21b` - `CLAUDE.md.tmpl: replace the session-start prose, add the skills markers, the treehouse policy and the documentation-lifetime rule`, and at `claude/skills/work-order/settings.local.json.tmpl:6`, which is on no ticket.

**Both design documents still say the runner only has Docker.** `ubuntu-24.04` ships Podman 5.8.4.

`claude/skills/skill-versioning/SKILL.md` is now accurate about `--structure`, including the new-skill exemption and both halves of a rename. It is no longer in this list.

### Your scope

Close `WO-20260824-f1a5` - `Skills package manager: prove the path on one skill`, and nothing else.

It is a lifecycle transition and a written outcome, not code.
Read the epic's own acceptance criteria before assuming they are all met - the epic ticket has its own `AC` list separate from its children's, and an epic whose children all shipped is not automatically an epic whose criteria were observed.
Where a criterion is met by a child, say which child by ID and full title and where the observation lives; where one was never observed, say that plainly in the `Outcome` rather than closing over it.

The pull request carries the `done` stamp, the archive move, `INDEX.md`, the epic README prune and this hydration entry's successor. That is the whole diff.

**Non-goals.** Do not touch `claude/skills/`, so this pull request needs no `Bump:` trailer and `detect` will emit `skills=[]`. Do not start any p2 under `WO-20260824-00d5` - `Skills package manager: roll it out across the repository` in the same branch. Do not close `WO-20260824-00d5` itself; it has eight live children.

### Before you start

`work-order.sh start` needs a clean tree, and it will create `feat/skills-package-manager-prove-the-path-on-one-ski` for you.
`start` leaves the ticket file, `INDEX.md` and the epic README uncommitted, so commit them before anything else.

**`.claude/worktrees/smoke-tests` is a locked git worktree sitting untracked inside this repository**, left by a session before this epic. It is not yours. It means `git add -A` at close-out is unsafe here - add explicit paths instead, which is what PR #76, #77 and #78 all did.

`approve` has not been run on `f1a5` - check `work-order show` before `start`, because `start` requires `ready` and a `draft` will refuse.

### Read in this order

1. `work-orders/WO-20260824-f1a5/WO-20260824-f1a5-skills-package-manager-prove-the-path-on-one-ski.md` - the epic's own acceptance criteria and all of its notes. The newest note explains why it is still open.
2. This entry, the top entry of `HYDRATION.md`. Read only this one.
3. `work-orders/archive/2026/WO-20260825-dac4-verify-structure-refuses-a-brand-new-skill-which.md` - the last child, and the three `observed` blocks on it, which are where the gate evidence for the whole epic actually lives.
4. `workflows/close-out-procedure.md`, once, for the order the steps run in.
5. Root `CLAUDE.md` Rule 16 and `## Close-out and post-merge cleanup`. Both are accurate.

### Reuse, it is proven

The epic's criteria are almost certainly discharged by evidence already written on its children rather than by anything you have to run.
`work-order show --id <child>` prints the `observed` blocks; quote them by ID and full title into the epic's `Outcome` instead of re-observing.

The children and where each one's proof lives: `WO-20260824-316d` - `Pilot: take hydration-prompt through the whole pipeline` carries the real-`main` publisher observation, `WO-20260824-9712` - `End-to-end proof in a scratch project, including the lost-receipt case` carries the sync receipt case, `WO-20260824-8cd1` - `Rewrite root CLAUDE.md for merge-time allocation and the named main exception` carries the Rule 16 rewrite, and `WO-20260825-dac4` - `verify --structure refuses a brand new skill, whichever way it is written` carries the three gate runs on PR #78.

`work-order.sh done` prunes an emptied epic directory and regenerates `INDEX.md` and the epic READMEs on its own. Do not hand-edit any of the three.

### The verification ladder

Rung 1: `bash claude/skills/work-order/scripts/work-order.sh verify --project .`. Green before you start and green after `done`.

Rung 2: `work-order tree`. `WO-20260824-f1a5` gone from it entirely, not sitting there as `done`, because `done` archives.

Rung 3: `work-order next`. It no longer returns `f1a5` first, and the top of the list is a p2 under `WO-20260824-00d5` - `Skills package manager: roll it out across the repository`.

Rung 4: the epic's `Outcome` block names every criterion and, for each, either the child that discharged it or the fact that it was never observed. A criterion silently absent from that block is a Rule 12 failure.

Rung 5: `bash .github/scripts/bump-gate.sh detect --base origin/main` emits `skills=[]`, `tools=false`, `gate=false`. Any other answer means the branch touched something it should not have.

Rung 6: the gate on the pull request. `No skill changed on this branch. Nothing to resolve.` then `verify --structure` green, and the three test legs skipped.

Rung 7 is not needed. **Do not run the nine suites for a work-orders-only change** - nothing they cover is in the diff, and they were all green on PR #78 at 251, 299, 161, 145, **120**, 85, 47, 41 and 39.

### Traps, already paid for

**A markdown formatter re-pads tables in a file you only meant to add a line to.** It is a `PostToolUse` hook in the machine's global `~/.claude/settings.json`. `git diff -U0 | grep '^-'` before committing and account for every deleted line; on PR #78 four deletions were an entire table re-padded by the hook after a one-cell edit.

**`work-order.sh start` moves you to a new branch and there is no flag to stop it.** That is what prevented this epic closing inside its child's pull request. Plan the branch before running it, never during a close-out.

**A suite with no self re-exec, run as `bash <suite>`, runs on the host and fails with `mkdir: cannot create directory '/work'`.** Use `bash .github/scripts/bump-gate.sh run-suite <dir>`, which dispatches `self` or `wrapped` correctly.

`gh pr create` warns `1 uncommitted change` because of the untracked `.claude/worktrees/`. That warning is expected and is not your branch.

**A digest you did not copy from a real registry does not exist.** `podman pull` fails with `manifest unknown`, which reads like a network problem and is not. Reuse the `bitnami/git` digest this repository already pins rather than inventing one.

### Workflow

```bash
WO=claude/skills/work-order/scripts/work-order.sh
HP=claude/skills/hydration-prompt/scripts/hydration.sh

bash $WO show    --project . --id WO-20260824-f1a5      # read the criteria first
bash $WO approve --project . --id WO-20260824-f1a5 --no-lavish --reason '...'   # only if draft
bash $WO start   --project . --id WO-20260824-f1a5      # creates the branch, leaves files uncommitted
git add work-orders && git commit -m "chore(work-orders): start WO-20260824-f1a5"

bash $WO evidence --project . --id WO-20260824-f1a5 --index N --observed '...'

git add <explicit paths>            # NOT -A, see .claude/worktrees/smoke-tests above
git commit && git push -u origin feat/skills-package-manager-prove-the-path-on-one-ski
gh pr create --base main --title "chore(work-orders): close the skills package manager epic" --body-file <file>
bash $WO submit  --project . --id WO-20260824-f1a5 --pr <N>
bash $WO done    --project . --id WO-20260824-f1a5      # on the branch, before the merge
bash $HP check   --project . --body-file /tmp/entry.md
bash $HP add     --project . --id <next> --title "<next title>" --body-file /tmp/entry.md
git add <explicit paths> && git commit && git push      # rides the SAME pull request

# after the merge
bash $WO cleanup --project . --id WO-20260824-f1a5
```

**This pull request touches no skill, so it carries no `Bump:` trailer.** Adding one is a refusal: `resolve` reports `not changed here` for a skill the branch never touched.

### Conventions

Every reference to a work-order in a chat reply carries the ticket ID and its full title joined by a dash. A bare ID is a defect, and so is "the next ticket" or "the epic".

Feature branches only. `skill-publish.yml` is the one named exception, and root `CLAUDE.md` says so.

PR bodies carry no agent attribution, Rule 13.

No em dashes. Plain dashes only, in every file and every reply.

<!-- hydration-entry: WO-20260825-dac4 -->
## WO-20260825-dac4 - verify --structure refuses a brand new skill, whichever way it is written
_Generated 2026-08-28 by hydration.sh. Newest entry._

### Ticket

`WO-20260825-dac4` - `verify --structure refuses a brand new skill, whichever way it is written`.
It is a `bug`, `p1`, and it is now the **only** child left in epic `WO-20260824-f1a5` - `Skills package manager: prove the path on one skill`.
Its dependency `WO-20260824-8cd1` - `Rewrite root CLAUDE.md for merge-time allocation and the named main exception` is `done`.
It blocks `WO-20260824-238b` - `Rename skill-versioning to skill-registry, the closing commit`, which is why it is p1 and not a backlog item.
`work-order next` returns the epic first and this ticket second.

### What just landed

Root `CLAUDE.md` Rule 16 was rewritten for merge-time allocation, and the never-write-`main` rule gained its named exception. PR #77.

Rule 16 now carries the whole path in eight numbered steps and says which are run by hand: a contributor does 1, 2, 3 and 5; steps 4, 6 and 8 are automatic; step 7 is once per project. The level table survives, rekeyed from `--major/--minor/--patch` to the trailer's `major/minor/patch`. `skill-update.sh` is stated as the hand-authored path and nothing else. The exception names `.github/workflows/skill-publish.yml` and nothing else, in the design doc's fixed wording, narrowed per the `WO-20260824-7a63` note now that `work-order close` is gone and `cleanup` writes nothing.

**Rule 16 is now correct and you can follow it.** The last two ticket cycles were told in their hydration prompt to ignore it. That instruction is retired.

Nothing outside `CLAUDE.md` and `work-orders/` changed. 97 insertions, 21 deletions, and `git diff -U0 | grep '^-'` put every deleted line inside the two sections named above.

All nine suites green at the same counts as before: tools **251**, work-order **299**, project-scaffold **161**, gate **145**, skill-versioning **103**, cartography **85**, hydration-prompt **47**, context-compaction **41**, living-docs **39**.

### What is NOT done

**The epic did not close, and the previous entry predicted it would.** `WO-20260825-dac4` was created on 2026-08-25 under `WO-20260824-f1a5` - `Skills package manager: prove the path on one skill`, after that prediction was written, and it is `ready`. The epic stays open and `f1a5` was not touched by PR #77.

Branch protection is still absent and is still on no ticket.

The other 42 notices are still inline: `WO-20260824-d058` - `Remove the inline read-only notice from the other 42 SKILL.md files`.

Root `CLAUDE.md`'s `## Consuming These Files` section now contradicts Rule 16 steps 7 and 8, and **it is on no ticket.** It tells a consumer to clone or symlink `claude/skills/` via `setup.sh` and never mentions `.claude/skills.toml` or `skill-sync.sh`. Found by the rung 5 reader on PR #77 and surfaced there, deliberately not fixed - it is not Rule 16 and `WO-20260824-8cd1`'s non-goal forbade touching it. `WO-20260824-c6b0` - `skill-onboard.sh brings an existing project onto the sync` is the nearest thing and does not cover it.

### Stale or false in the docs

**`claude/skills/hydration-prompt/SKILL.md:38` still puts `archive - work-order.sh close, straight to main` under `AFTER THE MERGE`.** There is no `close` verb. The lifecycle ends at `done`, on the branch, inside the PR. Not your ticket, and do not follow the diagram.

The same dead reference lives at `claude/skills/project-scaffold/references/templates/CLAUDE.md.tmpl:207` and `:248`, which is `WO-20260824-b21b` - `CLAUDE.md.tmpl: replace the session-start prose, add the skills markers, the treehouse policy and the documentation-lifetime rule`, and at `claude/skills/work-order/settings.local.json.tmpl:6`, which is on no ticket.

**Both design documents still say the runner only has Docker.** `ubuntu-24.04` ships Podman 5.8.4.

Root `CLAUDE.md` Rule 16 is no longer in this list. It was the entry here for two cycles and it is now accurate.

### Your scope

Three criteria, all human, all about what the gate does to a pull request:

- `AC-H1` a PR adding a brand new skill directory with no `version:` line is green on the gate
- `AC-H2` a PR that hand-edits the `version:` of a skill already in the registry is still refused, and the message says which
- `AC-H3` a PR that renames a skill directory is green on the gate

The cause is two functions away from the symptom. `cmd_verify` walks every skill directory and reports any without a `version:` as `unversioned`, and it does that **before** `diff_check` is reached - so a new skill with no version line dies in the first loop. Write the line by hand instead and `diff_check` catches it as a `version:` in the branch diff. Both paths are red, so adding a skill is the one change the pipeline cannot land.

A rename hits the same edge for a different reason: a renamed directory arrives as an added file, so every line including `version:` is a `+` in the diff.

The non-goals are explicit and one of them is easy to break by accident: **plain `verify` must keep requiring every skill to be versioned.** It runs on `main` after the publisher, and that is the assertion the publisher's post-state check depends on. Do not teach `bump-gate.sh` anything either - `resolve` already reports an unregistered skill as new at `1.0.0`, observed on PR #77 and on the pilot.

### Before you start

`work-order.sh start` needs a clean tree. `start` leaves the ticket file, `INDEX.md` and the epic README uncommitted, so commit them before anything else.

**`.claude/worktrees/smoke-tests` is a locked git worktree sitting untracked inside this repository**, left by a session before this epic. It is not yours. It means `git add -A` at close-out is unsafe here - add explicit paths instead, which is what PR #76 and PR #77 both did.

**When your ticket merges the epic really is empty.** Close `WO-20260824-f1a5` - `Skills package manager: prove the path on one skill` in the same pull request if the lifecycle allows it, and say so plainly if it does not. The previous entry made that same prediction and it was wrong, so check `work-order tree` before believing it rather than after.

### Read in this order

1. The ticket, and both notes on it. The second names where this was found and why it was recorded rather than fixed.
2. This entry, the top entry of `HYDRATION.md`. Read only this one.
3. `claude/skills/skill-versioning/scripts/skill-version.sh` - `cmd_verify` at 391, `diff_check` at 328, and the comment block above `diff_check` at 318 which states the assertion in the author's own words.
4. `docs/superpowers/plans/2026-08-24-skills-package-manager-implementation.md` `E1.3` for what the verify split was meant to be, and `E1.8` for the publisher's `init`.
5. Root `CLAUDE.md` Rule 16, which is now accurate and describes the pipeline you are repairing a hole in.

### Reuse, it is proven

The comment block at `skill-version.sh:318` already contains the reasoning your fix has to preserve, in the author's words: under merge-time allocation "the assertion is not 'the edit looks wrong' but 'there is no edit at all'". The fix is a narrowing of *which skills that assertion applies to*, not a rewrite of it.

`bump-gate.sh cmd_resolve` already solves the same problem correctly and is the model: it calls `registry_version "$s"` and, on failure, emits the row `- -> 1.0.0 new absent from the registry`. Absence from the registry is the test for "new", it is already written, and it was exercised on PR #77's `resolve` run and on the pilot.

`.github/scripts/testing/run-tests.sh` builds a fixture repository with a hand-written three-skill registry - see the `alpha`/`beta`/`gamma` fixture near line 103. That is the shape a case for "a skill absent from the registry" wants, and it already exists.

`claude/skills/container-sandbox/SKILL.md` has the section for verifying anything hook-shaped, and `references/skill-testing.md` defines what "tested" means for a skill's own scripts. If a check here needs a container and the pattern is not documented, write the section rather than falling back to the host.

### The verification ladder

Rung 1: `bash .github/scripts/bump-gate.sh run-suite claude/skills/skill-versioning`. It is at **103** and your new cases move it. Cover all three: new skill with no version line, new skill with one, and a rename.

Rung 2: `verify --structure` on a branch that adds a throwaway skill directory. Green.

Rung 3: `verify --structure` on a branch that edits an existing skill's `version:`. Red, and the message names the skill.

Rung 4: plain `verify` still refuses an unversioned skill. This is the non-goal and it is the one a fix here can silently break.

Rung 5: the nine suites at 251, 299, 161, 145, **103 + yours**, 85, 47, 41 and 39.

Rung 6: **a real pull request adding a throwaway skill directory.** The ticket's own test plan says this and it is right - the gate only exists on a pull request, so a green local `verify --structure` is not the claim `AC-H1` makes. Delete the throwaway in the same PR or in a follow-up, and say which.

### Traps, already paid for

**A markdown formatter re-pads tables in a file you only meant to add a line to.** It is a `PostToolUse` hook in the machine's global `~/.claude/settings.json`. `git diff --stat` before committing; PR #77 came out at 97 insertions and 21 deletions and every deletion was inside the two sections it meant to replace.

**A suite with no self re-exec, run as `bash <suite>`, runs on the host and fails with `mkdir: cannot create directory '/work'`.** Use `bash .github/scripts/bump-gate.sh run-suite <dir>`, which dispatches `self` or `wrapped` correctly.

`gh pr create` warns `1 uncommitted change` because of the untracked `.claude/worktrees/`. That warning is expected and is not your branch.

`bump-gate.sh detect` reports `skills=[]` for a skill that ships no `testing/run-tests.sh` while `resolve` still names it. The two commands answer different questions and the disagreement is the design, not a bug.

A `grep -q` in a pipeline reports "no match" when it matched: it closes the pipe on the first hit, the upstream dies of SIGPIPE, and `pipefail` turns that into a non-zero pipeline. Capture to a variable and grep the variable.

**A spawned subagent's summary of what it read is not the same as what it was told.** Used deliberately on PR #77 as the `AC-H1` comprehension test and it worked - it found a real defect in the new prose - but treat its output as a test result, not as a transcript. An agent asked to quote output verbatim will silently drop a line.

### Workflow

```bash
WO=claude/skills/work-order/scripts/work-order.sh
HP=claude/skills/hydration-prompt/scripts/hydration.sh

bash $WO show    --project . --id WO-20260825-dac4
bash $WO start   --project . --id WO-20260825-dac4   # creates the branch, leaves files uncommitted
git add work-orders && git commit -m "chore(work-orders): start WO-20260825-dac4"

# ... fix cmd_verify and diff_check, add the three cases ...

bash .github/scripts/bump-gate.sh run-suite claude/skills/skill-versioning

bash $WO evidence --project . --id WO-20260825-dac4 --index N --observed '...'
git add <explicit paths>            # NOT -A, see .claude/worktrees/smoke-tests above
git commit && git push -u origin <branch>
gh pr create --base main --title "..." --body-file <file>
bash $WO submit  --project . --id WO-20260825-dac4 --pr <N>
bash $WO done    --project . --id WO-20260825-dac4   # on the branch, before the merge
bash $HP check   --project . --body-file /tmp/entry.md
bash $HP add     --project . --id <next> --title "<next title>" --body-file /tmp/entry.md
git add <explicit paths> && git commit && git push   # rides the SAME pull request

# after the merge
bash $WO cleanup --project . --id WO-20260825-dac4
```

**This ticket changes `claude/skills/skill-versioning/`, so it needs a `Bump:` trailer.** Rule 16 as it now reads is the instruction and it is correct: last paragraph of the pull request body, nothing after it, `Bump: skill-versioning=patch` - or let a conventional `fix(` title resolve it, since this is a single-skill change. **Do not run `skill-version.sh bump`.** The publisher allocates on `main`.

`approve` is already done for this ticket and must not be run again.

### Conventions

Every reference to a work-order in a chat reply carries the ticket ID and its full title joined by a dash. A bare ID is a defect, and so is "the next ticket" or "the blocked one".

Feature branches only. `skill-publish.yml` is the one named exception, and root `CLAUDE.md` now says so.

PR bodies carry no agent attribution, Rule 13.

<!-- hydration-entry: WO-20260824-8cd1 -->
## WO-20260824-8cd1 - Rewrite root CLAUDE.md for merge-time allocation and the named main exception
_Generated 2026-08-28 by hydration.sh. Newest entry._

### Ticket

`WO-20260824-8cd1` - `Rewrite root CLAUDE.md for merge-time allocation and the named main exception`.
It is the **last ticket in epic `WO-20260824-f1a5` - `Skills package manager: prove the path on one skill`**, and nothing else stands between it and the epic closing.
Its dependency `WO-20260824-9712` - `End-to-end proof in a scratch project, including the lost-receipt case` is `done`.
`work-order next` returns it first.

This one is prose, and it is the repository's constitution. Three points, and easy to get subtly wrong.

### What just landed

The sync was proved end to end against the live hook, and the ownership rule held.

Six real session starts in a disposable scratch repository at `/tmp/skill-sync-proof`, plus an independent container probe against the same binary.
That merged as PR #76.

| Step             | Hook stdout                       | Post-state                                    | Receipt `owned`        |
| ---------------- | --------------------------------- | --------------------------------------------- | ---------------------- |
| 1 install        | `owned hydration-prompt`, 1 in    | installed, notice rendered, v2.0.4            | `["hydration-prompt"]` |
| 2 churn guard    | silent                            | unchanged                                     | unchanged              |
| 3 re-sync        | `owned` + `previous`, 1 in        | byte-identical                                | `["hydration-prompt"]` |
| 4 manifest empty | `previous` + `dropped`, 1 removed | directory gone, neighbour survives            | `[]`                   |
| 5 restage        | `owned hydration-prompt`, 1 in    | reinstalled, 5 files                          | `["hydration-prompt"]` |
| 6 lost receipt   | no plan tag, 0 in 0 removed       | **managed directory survived byte-identical** | `[]`                   |

Step 6 was the ticket. With the receipt deleted and the manifest no longer asking for it, `previous` is empty, so `dropped` is empty, so there is no `rm -rf` set at all. Orphaned, not deleted.

The hand-authored `local-notes/` beside it was byte-identical at every step, and the string `local-notes` occurs in the `skill-sync` stdout of none of the six sessions.
All four plan tags were exercised: `owned`, `previous`, `dropped`, `unknown`.

`claude/skills/container-sandbox/SKILL.md` gained one section, **"Verifying a hook that only fires on a real session start"**, and **nothing else in the repository outside `work-orders/`**.
The gate resolved `container-sandbox 1.2.0 -> 1.3.0 minor trailer` from the PR body's `Bump:` line. Nothing was hand-edited.

All nine suites green: tools **251**, work-order **299**, project-scaffold **161**, gate **145**, skill-versioning **103**, cartography **85**, hydration-prompt **47**, context-compaction **41**, living-docs **39**.

### What is NOT done

`AC-H1` of `WO-20260824-360d` - `Publish workflow: allocate versions on merge to main and regenerate the registry` wanted **two** real back-to-back merges. The pilot supplied the first and PR #76 supplied the second, so if the publisher allocated `container-sandbox` `1.3.0` on `main` that criterion is now satisfied by observation - **check it before assuming it, the run is the evidence**.

Branch protection is still absent and is still on no ticket.

`verify --structure` still cannot pass for a brand new skill: `WO-20260825-dac4` - `verify --structure refuses a brand new skill, whichever way it is written`.

The other 42 notices are still inline: `WO-20260824-d058` - `Remove the inline read-only notice from the other 42 SKILL.md files`.

### Stale or false in the docs

**Rule 16 of root `CLAUDE.md` is the thing you are fixing and it is currently wrong in the strongest way.** It tells the reader to run `skill-version.sh bump` and ship a regenerated `registry.json`, and the PR gate now refuses exactly that. Two ticket cycles have had to be told in their hydration prompt not to follow it.

**`claude/skills/hydration-prompt/SKILL.md` still describes a close-out this repository no longer runs.** Its diagram puts `archive - work-order.sh close, straight to main` under `AFTER THE MERGE`. There is no `close` verb; the lifecycle ends at `done`, on the branch, inside the PR. The same dead reference appears as an `## Outcome - Written by work-order close` heading in its ticket template. Not your ticket, but do not follow the diagram - and note that your ticket's own file carries that same stale heading.

**Both design documents still say the runner only has Docker.** `ubuntu-24.04` ships Podman 5.8.4.

The note on your ticket from `WO-20260824-7a63` is load-bearing and still correct: the named exception got **narrower**. `work-order close` no longer exists, `cleanup` deletes branches and writes nothing, so **the publish workflow is the only process that writes `main`**. Word the exception against that one process, not two.

### Your scope

Two criteria, both human, both about what a reader can do with the file:

- `AC-H1` an agent reading only root `CLAUDE.md` can describe the whole path from a skill edit to a project receiving it
- `AC-H2` no instruction to hand-edit a `version:` or `registry.json` survives anywhere in the file

The scope's non-goal is explicit: **change no rule other than 16 and the never-write-`main` rule.** Rule 14, Rule 15 and Rule 17 are not yours, however tempting.

The path the file has to describe, end to end, now exists and every leg of it has been observed: a skill edit on a branch -> `verify --structure` locally -> a `Bump: <skill>=<level>` trailer in the PR body -> the gate resolves and prints the table, writing nothing -> squash merge with `PR_BODY` as the commit message -> the publisher reads the trailer with `git interpret-trailers --parse`, allocates the version and regenerates the registry on `main`, carrying `Skill-Publish: true` so its own push cannot re-trigger -> a project declares the skill in `.claude/skills.toml` -> a session starts -> `skill-sync --boot` installs it with the notice rendered in and writes a receipt.

`skill-update.sh` is the hand-authored path and nothing else. State that.

### Before you start

Read `docs/superpowers/plans/2026-08-24-skills-package-manager-implementation.md` section `E1.12` and decision 17 before writing a word. The wording of the exception is fixed by the design doc, not invented here.

`work-order.sh start` needs a clean tree. `start` leaves the ticket file, `INDEX.md` and the epic README uncommitted, so commit them before anything else.

**`.claude/worktrees/smoke-tests` is a locked git worktree sitting untracked inside this repository, left by an earlier session.** It is not yours and it predates this epic. It means `git add -A` at close-out is unsafe here - add explicit paths instead, which is what PR #76 did.

### Read in this order

1. Root `CLAUDE.md`, the whole file, because you are editing its constitution and `AC-H2` is a claim about _anywhere in the file_.
2. This entry, the top entry of `HYDRATION.md`. Read only this one.
3. The ticket, and in particular the `WO-20260824-7a63` note on it.
4. `docs/superpowers/plans/2026-08-24-skills-package-manager-implementation.md`, `E1.12` and decision 17.
5. `workflows/close-out-procedure.md`, because the rule you are rewriting points at it.

### Reuse, it is proven

**Do not invent the wording.** `docs/superpowers/plans/2026-08-24-skills-package-manager-implementation.md` fixes it, and `WO-20260824-7a63` narrowed it afterwards. Between the two the sentence is already written; your job is to place it.

The current `## Close-out and post-merge cleanup` section of root `CLAUDE.md` is the model for the tone this file wants: the procedure lives in `workflows/close-out-procedure.md`, and `CLAUDE.md` carries only the part that must not be got wrong. Rule 16 should shrink the same way.

Every leg of the path Rule 16 has to describe has now been observed rather than inferred, and the evidence is on archived tickets you can quote: the gate and the publisher on `WO-20260824-316d` - `Pilot: take hydration-prompt through the whole pipeline end to end`, and the sync and the receipt on `WO-20260824-9712` - `End-to-end proof in a scratch project, including the lost-receipt case`.

`claude/skills/container-sandbox/SKILL.md` now has the section for verifying anything hook-shaped, added by PR #76. If a check in this ticket needs a container and the pattern is not there, write the section rather than falling back to the host.

### The verification ladder

This ticket ships prose, so the ladder is short and the first rung is the real one.

Rung 1: `grep -rniE 'skill-version\.sh (bump|init)|regenerated registry|hand-edit' CLAUDE.md` returns nothing that instructs. `AC-H2` is a search, so run the search.

Rung 2: `verify --structure` locally. It passes today and must still pass.

Rung 3: `bump-gate.sh resolve` against your real title and body. **Root `CLAUDE.md` is not under `claude/skills/`, so if you touch nothing else the gate resolves nothing and needs no `Bump:` trailer** - `resolve` exiting 0 with an empty table is the correct outcome, not a failure.

Rung 4: the nine suites still at 251, 299, 161, 145, 103, 85, 47, 41 and 39.

Rung 5: hand the finished file to a fresh subagent that has read nothing else and ask it to describe the path from a skill edit to a project receiving it. `AC-H1` is a comprehension claim, and the only honest test of one is a reader who was not in the room.

### Traps, already paid for

**A markdown formatter re-pads tables in a file you only meant to add a line to.** It is a `PostToolUse` hook in the machine's global `~/.claude/settings.json` and it fired on this ticket's one edit. `git diff --stat` before committing; PR #76's edit came out at 83 insertions and 0 deletions, which is how you know it only added.

**A spawned agent asked to quote hook output verbatim will silently drop a line.** This ticket hit it: two lines came back and the third, a `previous hydration-prompt` plan tag, did not, with nothing in the reply to indicate a gap. The raw record is `~/.claude/projects/<cwd-with-slashes-as-dashes>/<session-id>.jsonl`, and the new container-sandbox section documents the parse. This matters for rung 5 above - a subagent's summary of what it understood is not the same as what it was told.

**`--boot` is silent and exits 0 when the last sync was under 15 minutes ago**, `STAMP_MAX_AGE` is 900. Observed on this ticket: a session 20 seconds after the first synced nothing and printed nothing. That is the churn guard, not a bug. `--plan` ignores the stamp.

**`--boot` exits 0 on failure by design** and reports on **stdout**, because a hook's stdout reaches the agent's context and its stderr does not. `$?` will tell you nothing.

`bump-gate.sh detect` reports `skills=[]` for a skill that ships no `testing/run-tests.sh`, while `resolve` still names it and demands a trailer. Observed on PR #76 with `container-sandbox`. The two commands answer different questions - `detect` picks matrix legs, `resolve` validates intent - and the disagreement is the design, not a bug.

**A suite with no self re-exec, run as `bash <suite>`, runs on the host and fails with `mkdir: cannot create directory '/work'`.** Use `bash .github/scripts/bump-gate.sh run-suite <dir>`, which dispatches `self` or `wrapped` correctly.

A `grep -q` in a pipeline reports "no match" when it matched: it closes the pipe on the first hit, the upstream dies of SIGPIPE, and `pipefail` turns that into a non-zero pipeline. Capture to a variable and grep the variable.

### Workflow

```bash
WO=claude/skills/work-order/scripts/work-order.sh
HP=claude/skills/hydration-prompt/scripts/hydration.sh

bash $WO show    --project . --id WO-20260824-8cd1
bash $WO start   --project . --id WO-20260824-8cd1   # creates the branch, leaves files uncommitted
git add work-orders && git commit -m "chore(work-orders): start WO-20260824-8cd1"

# ... rewrite Rule 16 and the never-write-main exception ...

bash $WO evidence --project . --id WO-20260824-8cd1 --index N --observed '...'
git add <explicit paths>            # NOT -A, see .claude/worktrees/smoke-tests above
git commit && git push -u origin <branch>
gh pr create --base main --title "..." --body-file <file>
bash $WO submit  --project . --id WO-20260824-8cd1 --pr <N>
bash $WO done    --project . --id WO-20260824-8cd1   # on the branch, before the merge
bash $HP check   --project . --body-file /tmp/entry.md
bash $HP add     --project . --id <next> --title "<next title>" --body-file /tmp/entry.md
git add <explicit paths> && git commit && git push   # rides the SAME pull request

# after the merge
bash $WO cleanup --project . --id WO-20260824-8cd1
```

When this merges the epic has nothing left in it. Close `WO-20260824-f1a5` - `Skills package manager: prove the path on one skill` in the same pull request if the lifecycle allows it, and say so plainly if it does not.

`approve` is already done for every ticket in both epics and must not be run again.

### Conventions

Every reference to a work-order in a chat reply carries the ticket ID and its full title joined by a dash. A bare ID is a defect, and so is "the next ticket" or "the blocked one".

Feature branches only. The publish workflow is the one named exception, and narrowing that sentence is part of this ticket.

PR bodies carry no agent attribution, Rule 13.

<!-- hydration-entry: WO-20260826-9037 -->
## WO-20260826-9037 - Credential rotation workflow - KMS free tier fix
_Generated 2026-08-26 by hydration.sh. Newest entry._

### Ticket

`WO-20260826-9037` - `Credential rotation workflow - KMS free tier fix` is `done` and archived, on the branch, inside PR #75.

It has no parent and no dependencies. It is the fourth and last repository in the KMS free-tier work, and the only one of the four that ships a tool rather than a configuration change.

### What just landed

`workflows/credential-rotation.md` at 1.0.0, a 14-credential manifest, a driver with `list`, `due`, `verify` and `rotate --dry-run`, and two test suites.

**Nothing in the driver reads a credential value.** `due` and `verify` compare the parameter's `LastModifiedDate` against the `ExternalSecret`'s `status.refreshTime` - if the cluster last refreshed before the parameter last changed, the cluster is stale. That answers the question completely, works for the templated secrets where no plain key holds the raw value, and spends zero KMS requests. The obvious alternative would cost one billable `Decrypt` per credential per run and undo the whole point of the 168h change. The offline suite asserts the absence of that call, not the absence of an error.

**The manifest lists no consumers on purpose.** The fan-out is discovered from the cluster at run time, so it cannot go stale, and the file stays free of cluster object names in a public repository.

Two suites, because neither is sufficient alone. `run-tests.sh` stubs `aws` and `kubectl` with `--network=none`, which is what makes the no-KMS assertion possible; the cost is that the `go-template` behind `verify` is never rendered by a real `kubectl`. `live-check.sh` closes that gap against the real account and cluster, read-only subcommands only.

Green in Podman: credential-rotation **75**, live-check **10**, tools **38**, skill-versioning **103**.

Also fixed a latent bug in `tools/testing/run-tests.sh`. Piping `list` into `grep -q` was safe while `workflows/` held one document; the second one made `list` die on SIGPIPE mid-write and `pipefail` promoted that to the pipeline's status, failing a check whose subject was correct.

### What is NOT done

PR #75 is open and **must not merge until the other three do**. Until they land it describes a cluster that does not exist yet: it tells the reader a rotated credential will not propagate on its own, which only becomes true when `refreshInterval` is actually `168h`.

homelab-gitops #88, yieldpoint-gitops #10, local-k8s-docs #31. All three open and mergeable.

Nothing has been rotated. The driver has never run `rotate` against the real account - only `list`, `due` and `verify`.

Phase 5, confirmation, cannot start until those merge: re-measure CloudTrail 48 hours after the last one and expect roughly 292 KMS calls a day, cross-check Cost Explorer, arm a KMS budget alarm.

Phase 6 is seven follow-up tickets, none of them filed yet, and they are to be filed separately rather than folded into anything: the `eso-secret-workflow` skill mandating the deprecated `vault-seed.sh`; the Jenkins rebuild runbook missing the IRSA annotation on `jenkins-eso-sa`; that same runbook lacking the SecretStore and ExternalSecret steps; `homelab-gitops-index.md` listing a `ghcr-pull-secret/` directory that does not exist; the job-hunter migration to Vault; the GitHub PAT duplication across four namespaces; and `argocd-eso-role` being shared by three namespaces.

### Stale or false in the docs

**Root `CLAUDE.md` Rule 16 describes a flow the repository no longer uses.** It says a PR that touches a skill must bump the version and ship the regenerated `registry.json` in that same PR. `.github/scripts/bump-gate.sh` says the opposite in its own header: "Version allocation happens at merge, on main, in the publisher. A pull request therefore carries the intent and never the number." The publisher is the newer and the tested one. `WO-20260824-8cd1` - `Rewrite root CLAUDE.md for merge-time allocation and the named main exception` is the ticket that already covers this.

`workflows/credential-rotation.md` states as present tense that the interval is `168h`. That is true of the merged end state and not of the cluster today.

### Your scope

Merging, in order: the three gitops PRs first, then #75. Then Phase 5.

Do not start Phase 6 by folding tickets into existing work - each of the seven is its own ticket.

### Before you start

Check whether the three gitops PRs have merged. `gh pr view 88 --repo jkkelley/homelab-gitops --json state` and the same for yieldpoint-gitops #10 and local-k8s-docs #31. Everything downstream depends on that answer and nothing else does.

### Read in this order

1. `workflows/credential-rotation.md` - the procedure, and the reasoning behind the timestamp comparison
2. `workflows/credential-rotation/credentials.tsv` - the header comment explains what is deliberately not a column
3. `local-k8s-docs`, `runbooks/kms-cost-and-eso-refresh/` - the cost model, the free-tier arithmetic, the `OnChange` trap
4. `claude/skills/container-sandbox/references/skill-testing.md`, "Verifying against live infrastructure" - why there are two suites

### Reuse, it is proven

`workflows/credential-rotation/testing/live-check.sh` is the pattern for any tool that has to talk to AWS or the cluster: the image is built from `tools/testing/Containerfile.live` with `aws` and `kubectl` pinned to exact versions, credentials mount read-only, and only read-only subcommands run. It answered the go-template question that a stub could not.

The stub-plus-call-log shape in `run-tests.sh` is how you assert that a call was never made rather than that no error appeared. That is the assertion that protects the KMS saving.

`tools/testing/Containerfile` is bash and coreutils on a pinned debian, and it is now shared by two suites. Reuse it rather than pinning a second digest.

### The verification ladder

1. `bash workflows/credential-rotation/testing/run-tests.sh` - offline, 75 checks
2. `bash tools/testing/run-tests.sh` - 38 checks, includes the real `workflows/` tree
3. `AWS_PROFILE=minecraft-admin bash workflows/credential-rotation/testing/live-check.sh` - 10 checks against the real account and cluster
4. `bash tools/workflow-version.sh verify` - every procedure document carries a version

### Traps, already paid for

**A `local` referenced from an `EXIT` trap is out of scope when the trap fires.** Under `set -u` that turns a clean exit into an unbound-variable failure with all the work already done - `rotate` did every write correctly and returned 1. The scratch file variable and the trap both live at file scope now.

**`done < <(parser)` runs the parser in a subshell, so a `die()` in it kills only the subshell.** The refusal prints and the exit code is 0. A refusal that does not fail is not a refusal. Read into a variable with `$( )` instead, where a failed substitution fails the assignment and `set -e` takes it from there.

**`cmd | grep -q` under `pipefail`.** `grep -q` exits at the first match; if the producer still has output to write it dies on SIGPIPE and `pipefail` makes 141 the pipeline's status. Capture first, match second.

**The global prettier hook in `~/.claude/settings.json` reformats markdown tables and language-tagged code fences on every `Write`/`Edit`.** In this repository that matches the convention and is fine. It will also convert `*italic*` to `_italic_` on lines you did not touch, which is a Rule 3 violation - check `git diff` and revert the churn.

### Workflow

The close-out ran as `workflows/close-out-procedure.md` describes: `gh pr create`, `submit --pr 75`, `done` on the branch, this entry, one commit riding the same PR.

After the merge, `work-order.sh cleanup --id WO-20260826-9037` without being asked. It refuses unless `gh` reports the PR `MERGED` and it writes nothing.

`work-order.sh start` needs a clean tree, and the ticket `new` just wrote makes the tree dirty. `INDEX.md` is the only tracked file in the way - restore it and `start` regenerates it on the branch. Do not stash, because stashing takes the untracked ticket with it and `start` then cannot find the ticket it was asked about.

### Conventions

The branch is `feat/credential-rotation-workflow-kms-free-tier-fix`, cut by `work-order.sh start` from the ticket slug. The other three repositories use `feat/kms-free-tier-fix`; they diverge because `start` owns the branch name here and `cleanup` depends on the ticket's record of it.

PR bodies carry no agent attribution, Rule 13. Skill versions are not hand-edited - the PR body carries `Bump: <skill>=<level>` and the publisher allocates on `main`.

Rule 14 has no host escape hatch. If a verification pattern is undocumented, write the section rather than falling back to the host.

<!-- hydration-entry: WO-20260824-9712 -->
## WO-20260824-9712 - End-to-end proof in a scratch project, including the lost-receipt case
_Generated 2026-08-25 by hydration.sh. Newest entry._

### Ticket

`WO-20260824-9712` - `End-to-end proof in a scratch project, including the lost-receipt case`.
Its one dependency, `WO-20260824-316d` - `Pilot: take hydration-prompt through the whole pipeline end to end`, is `done`.
`work-order next` returns it first.

It is the last technical ticket in epic `WO-20260824-f1a5` - `Skills package manager: prove the path on one skill`.
Only `WO-20260824-8cd1` - `Rewrite root CLAUDE.md for merge-time allocation and the named main exception` stands between it and the epic closing.

**This one is manual and that is deliberate.** The ticket's own non-goal says so: "automating any of this - rung 5 is manual and that is the point". The hook only proves itself by firing, in a real session, in a real project.

### What just landed

The pilot went through the whole pipeline and the pipeline held.

`claude/skills/hydration-prompt/SKILL.md` lost its inline read-only notice, seven lines, and **nothing else in the repository outside `work-orders/`**. That merged as PR #73, squash `fe62080`.

**The publisher then allocated the number and nobody typed it.** Run `32861246926` produced `16541f6` - `chore(skills): allocate versions on main`, authored by `github-actions[bot]`, body `- hydration-prompt -> 2.0.4 (patch, from the trailer)`, carrying `Skill-Publish: true` so its own push cannot re-trigger allocation. `main` now reads `version: 2.0.4` in the SKILL.md and `"hydration-prompt": { "version": "2.0.4", "sha256": "ce66fada..." }` in the registry.

The whole chain is observed rather than inferred. The PR body's last paragraph carried `Bump: hydration-prompt=patch`; the gate resolved `hydration-prompt 2.0.3 -> 2.0.4 patch trailer` and printed that table in both runs; `git interpret-trailers --parse` on `fe62080` **on main** still reads it, so `squash_merge_commit_message=PR_BODY` does deliver the trailer to the publisher. `detect` emitted `skills=["hydration-prompt"]`, `tools=false`, `gate=false`, so **exactly one matrix leg ran**, and the other two jobs are `skipped` in the run's job list.

`verify` on `main` afterwards: `ok - 43 skills versioned, registry in sync`.

All eight suites are green on `main` right now, at: tools **251**, work-order **299**, project-scaffold **161**, gate **145**, skill-versioning **103**, cartography **85**, hydration-prompt **47**, context-compaction **41**, living-docs **39**.

### What is NOT done

**Nothing has yet installed a skill into a real project.** That is this ticket, in full. `skill-sync` has been proved against fixtures in the tools suite's 251 checks and the hook is live in `~/.claude/settings.json`, but no `.claude/skills.toml` exists anywhere on this machine, so the hook has fired many times and correctly done nothing every single time. A green tools suite is not a fired hook.

`AC-H1` of `WO-20260824-360d` - `Publish workflow: allocate versions on merge to main and regenerate the registry` wanted **two** real back-to-back merges. The pilot supplied the first. The second is still outstanding and is not on any ticket.

Branch protection is still absent and is still on no ticket.

`verify --structure` still cannot pass for a brand new skill. That one has a ticket: `WO-20260825-dac4` - `verify --structure refuses a brand new skill, whichever way it is written`.

The other 42 notices are still inline, under `WO-20260824-d058` - `Remove the inline read-only notice from the other 42 SKILL.md files`.

### Stale or false in the docs

**`claude/skills/hydration-prompt/SKILL.md` describes a close-out this repository no longer runs.** Its diagram puts `archive - work-order.sh close, straight to main` under `AFTER THE MERGE`. There is no `close` command - the lifecycle ends at `done`, and `--help` lists no such verb. Root `CLAUDE.md` is the current one: `done` on the branch, inside the PR. The skill also carries an `## Outcome - Written by work-order close` heading in its ticket template, same dead reference. Not your ticket, but do not follow the diagram.

**The pilot closed out in two pull requests, against the standard procedure, on purpose.** The reason is a note on the archived ticket and a second note on the open epic `WO-20260824-f1a5`. Short version: all three of its criteria were observations about `main` _after_ the squash, and the lifecycle has no post-merge slot to record them. **That exception was scoped to one ticket and is already spent.** Yours closes out in one pull request, the normal way.

**Both design documents still say the runner only has Docker.** `ubuntu-24.04` ships Podman 5.8.4.

Root `CLAUDE.md` Rule 16 still tells you to hand-run `skill-version.sh bump`. It is now wrong, and rewriting it is `WO-20260824-8cd1` - `Rewrite root CLAUDE.md for merge-time allocation and the named main exception`. Do not hand-run it in the meantime.

The hydration entry before this one said the suites sat at "251, 103, 299, 145 and 36". The first four are right. **There is no suite at 36** - the real counts are listed above.

### Your scope

The plan's `E1.11` is the checklist, and the ticket's four criteria are the same five properties.

- A scratch repository with a `.claude/skills.toml` naming `hydration-prompt`
- Start a session. Confirm the skill is installed **with the notice rendered into it**
- Confirm a hand-authored skill sitting beside it is untouched, unread and unreported
- Remove `hydration-prompt` from the manifest, re-sync, confirm the directory is removed
- **Delete the receipt, re-sync, confirm nothing is deleted**

The last one is the ticket. A lost receipt must **orphan** a managed directory, never delete a local one. Everything else here is setup for that check.

`AC-H4` is separate and easy to skip: the receipt must record `owned` correctly at **each** of the four steps, not just at the end. Read `.claude/cache/skills-receipt.json` after every step, not once.

**Done when:** all five hold, and the receipt records `owned` correctly at each step.

### Before you start

**Decide where the scratch project lives and confirm it is disposable before the hook can fire in it.** This is the first ticket whose test subject is a directory that a live machine-level hook will write into. `~/.claude/settings.json` runs `skill-sync --boot` on `startup|resume|clear` in _every_ project on this machine.

**You need a real session start, not a manual `--boot` invocation, for at least the first property.** `AC-H1` is about what happens when a session starts. Running the binary by hand proves the binary; it does not prove the hook. Do both and say which is which.

The manifest format is a hand-rolled parse, not TOML:

```toml
[skills]
use = [
  "hydration-prompt",
]
```

### Read in this order

1. Root `CLAUDE.md`. Rule 14 has no size threshold, and Rule 17 is why `skill-sync` avoids `flock`, `cmp` and `diff`.
2. This entry, the top entry of `HYDRATION.md`. Read only this one.
3. The ticket: `work-orders/WO-20260824-f1a5/WO-20260824-9712-end-to-end-proof-in-a-scratch-project-including-.md`.
4. `docs/superpowers/plans/2026-08-24-skills-package-manager-implementation.md`, section `E1.11`.
5. `claude/tools/skill-sync.sh`, its header comment first. The ownership rule is stated there in full and it is the thing under test: ownership is per-directory, never per-parent, and there is no `rm -rf` of the parent anywhere in the file.
6. `claude/tools/skill-sync.sh`, `usage`. The four plan tags - `owned`, `previous`, `dropped`, `unknown` - are the vocabulary your observations should use.
7. The archived pilot, `work-orders/archive/2026/WO-20260824-316d-pilot-take-hydration-prompt-through-the-whole-pi.md`, for the shape of evidence that was accepted.

### Reuse, it is proven

`claude/tools/testing/run-tests.sh` is at 251 checks and covers the sync against fixtures, including the drop path and the receipt. **If a manual observation surprises you, check whether it is already a case in there** - a disagreement between the suite and a real run is a much more interesting finding than either one alone.

`.github/scripts/testing/run-tests.sh` at 145 checks covers both halves of the pipeline against a fixture repository.

The pilot's own ladder is reusable verbatim for anything touching a skill: `verify --structure` locally, `bump-gate.sh resolve` against your real title and body in a container, then the gate, then the merge, then `git show origin/main:claude/skills/registry.json`.

### The verification ladder

Rung 1, free: `skill-sync --plan` in the scratch project. It ignores the stamp, takes no lock and **writes nothing**, so it is the safe way to see the resolution before anything is applied.

Rung 2: a real session start in the scratch project. `.claude/skills/hydration-prompt/SKILL.md` exists and **carries the rendered notice** after the `# ` heading.

Rung 3: the hand-authored neighbour. Byte-identical before and after - hash it, do not eyeball it - and absent from the plan output and the receipt.

Rung 4: manifest removal, re-sync, directory gone, and the receipt no longer claims it.

Rung 5: **delete the receipt, re-sync, and confirm the managed directory is still there.** Orphaned, not deleted.

Rung 6: `.claude/cache/skills-receipt.json` read after each of the four steps, `owned` correct at each.

Rung 7: the eight suites still at 251, 299, 161, 145, 103, 85, 47, 41 and 39.

### Traps, already paid for

**A green suite is not a fired hook.** The tools suite has passed 251 checks for days while the hook did nothing in every project on this machine, because none has a manifest. Do not let the suite stand in for the observation.

**`--boot` is silent and exits 0 when the last sync was under 15 minutes ago.** `STAMP_MAX_AGE` is 900 seconds. Four session starts in quick succession will look like three no-ops and one sync, and that is the churn guard working, not a bug. `--plan` ignores the stamp; `--boot` does not.

**`--boot` exits 0 on failure, by design**, because a SessionStart hook that fails must not take the session with it. It reports on **stdout** - `!! SKILL SYNC FAILED` - because a hook's stdout reaches the agent's context and its stderr does not. `$?` will tell you nothing. Read the output, and assert the post-state.

`~/.local/bin` may not be on `PATH` in a non-interactive shell, which is what a hook runs in. The hook uses `"$HOME/.local/bin/skill-sync"` in full for exactly this reason.

`.claude/skills/` is blanket gitignored in a scaffolded project, so `git status` in the scratch repo will show you **nothing** about what the sync did. Look at the filesystem.

A markdown formatter re-pads tables in a file you only meant to add one line to. It is a `PostToolUse` hook in the machine's global `~/.claude/settings.json`. `git diff --stat` before committing.

A `grep -q` in a pipeline reports "no match" when it matched: it closes the pipe on the first hit, the upstream dies of SIGPIPE, and `pipefail` turns that into a non-zero pipeline. Capture to a variable and grep the variable.

**A suite with no self re-exec, run as `bash <suite>`, runs on the host and fails with `mkdir: cannot create directory '/work'`.** Use `bash .github/scripts/bump-gate.sh run-suite <dir>`, which reads the suite and dispatches `self` or `wrapped` correctly.

`work-order.sh start` refuses with "working tree is dirty", and it leaves the ticket file, `INDEX.md` and the epic README uncommitted. Commit them first.

### Workflow

```bash
WO=claude/skills/work-order/scripts/work-order.sh
HP=claude/skills/hydration-prompt/scripts/hydration.sh

bash $WO show    --project . --id WO-20260824-9712
bash $WO start   --project . --id WO-20260824-9712   # creates the branch, leaves files uncommitted

# the scratch project, somewhere disposable
mkdir -p /tmp/skill-sync-proof/.claude && cd /tmp/skill-sync-proof && git init
printf '[skills]\nuse = [\n  "hydration-prompt",\n]\n' > .claude/skills.toml
"$HOME/.local/bin/skill-sync" --plan                 # writes nothing
# ... then a real session start here, and the four steps ...

# back in the dotfiles checkout, close out in ONE pull request
bash $WO evidence --project . --id WO-20260824-9712 --index N --observed '...'
git push -u origin <branch>
gh pr create --base main --title "..." --body-file <file>
bash $WO submit  --project . --id WO-20260824-9712 --pr <N>
bash $WO done    --project . --id WO-20260824-9712   # on the branch, before the merge
bash $HP check   --project . --body-file /tmp/entry.md
bash $HP add     --project . --id <next> --title "<next title>" --body-file /tmp/entry.md
git add -A && git commit && git push                 # rides the SAME pull request

# after the merge
bash $WO cleanup --project . --id WO-20260824-9712
```

This ticket changes no skill, so the gate will resolve nothing and the publisher will allocate nothing. That is the quiet half working, not a failure.

`approve` is already done for every ticket in both epics and must not be run again.

### Conventions

Every reference to a work-order in a chat reply carries the ticket ID and its full title joined by a dash. A bare ID is a defect, and so is "the next ticket" or "the blocked one".

Feature branches only. The publisher is the one named exception.

Rule 14 has no size threshold. **This ticket is the honest hard case**: a real session start cannot be containerised, because the thing under test is the machine's own hook. Say which rungs ran on the host and why, rather than letting them look containerised.

`registry.json` and every `version:` line belong to CI. Never hand-edit either.

When the ticket contradicts itself, or contradicts the runner, say so and pick one in the open.

<!-- hydration-entry: WO-20260824-316d -->
## WO-20260824-316d - Pilot: take hydration-prompt through the whole pipeline end to end
_Generated 2026-08-25 by hydration.sh. Newest entry._

### Ticket

`WO-20260824-316d` - `Pilot: take hydration-prompt through the whole pipeline end to end`.
All three of its dependencies are `done`: `WO-20260824-2ad1` - `PR gate workflow: validate the bump intent and run the affected suites`, `WO-20260824-360d` - `Publish workflow: allocate versions on merge to main and regenerate the registry`, and `WO-20260824-bb0d` - `setup.sh installs the skill-sync binary, then the SessionStart hook`.
`work-order next` returns it first.

It blocks two things and it closes the epic's argument.
Every piece of the pipeline has now been tested on its own; nothing has proved they compose.

This is the ticket where you touch a skill and let CI allocate the number.
**`registry.json` is not yours to edit and neither is the `version:` line.** The pull request carries a `Bump:` trailer and never a number.

### What just landed

`setup.sh` installs `skill-sync` to `~/.local/bin/` and then writes the `SessionStart` hook, as PR #72.

**The hook is live on this machine right now.** `~/.claude/settings.json` carries four `SessionStart` entries: the three `-axi` ones on `matcher: ""`, and a fourth on `matcher: "startup|resume|clear"` running `"$HOME/.local/bin/skill-sync" --boot` at `timeout: 30`.
This repository has no `.claude/skills.toml`, so the sync does nothing here and says nothing.

Three decisions are notes on that ticket rather than in either design document.

**The binary is a copy, never a symlink, whatever `INSTALL_TYPE` says.** `skill-sync` replaces itself in place - `mv self self.bak`, then `curl` - so a symlink would be swapped for a real file on the first self-update, silently turning a live link to the repo into a stale copy nobody knows is stale.

**The binary and the hook are not derived from `--dest`.** A `--dest` run installs skills into that project and still writes the hook to `~/.claude/settings.json`, because the hook fires in every project on the machine.

**An empty selection no longer exits early.** "Nothing valid to install. Exiting without changes." became false once the tool and hook install on every run. `setup.sh` answered `1`, `3`, Enter, Enter, `y` now installs the hook and nothing else, which is how you re-run it without disturbing anything.

The tools suite went from **193 checks to 251**, and its image is now `:2` - it gained `jq`.

### What is NOT done

`claude/skills/hydration-prompt/SKILL.md` still carries the read-only notice, along with the other 42.

`AC-H1` of `WO-20260824-360d` - `Publish workflow: allocate versions on merge to main and regenerate the registry` still needs two real back-to-back merges. Your pilot is the natural first.

Branch protection is still absent and is still on no ticket. `verify --structure` still cannot pass for a brand new skill, and that one has a ticket - it will bite the first person who adds a skill.

### Stale or false in the docs

**Merging #72 published nothing**, because nothing under `claude/skills/` changed. That is `AC-H2` of the publisher ticket observed once more, and it is the _quiet_ half. Yours is the loud half: a merge that does allocate a number.

**Both design documents still say the runner only has Docker.** `ubuntu-24.04` ships Podman 5.8.4. Not yours, but do not re-add an install step on their say-so.

The ticket says `~/.local/bin` is "beside the existing `-axi` tools". It is not - those live in `~/.npm-global/bin`. The path is right and the prose is wrong; the note on `WO-20260824-bb0d` says so.

### Your scope

The plan's `E1.10` is the checklist.

- Remove the notice from `claude/skills/hydration-prompt/SKILL.md`, **and only that file**
- Open the PR with the `Bump:` trailer in the description
- Confirm the gate prints the resolution table and runs **exactly one** matrix leg
- Merge, and confirm the publisher bumps the version and regenerates the registry on `main`
- Confirm `verify` is green on `main` afterwards

`hydration-prompt` is the pilot because it ships a test suite, so the matrix leg is genuinely exercised, and because it is used every session, so a break is visible immediately rather than in three weeks.

**Done when:** `main` carries a bumped `hydration-prompt` that nobody bumped by hand.

### Before you start

Decide the level before you write the trailer. Removing the notice changes a file a consumer reads but breaks nothing they call, so it is a `--patch` or a `--minor` argument and not a `--major` one. Make it in the open, in the pull request body, because the resolution table is what the gate prints back at you.

The gate resolves from the `Bump:` trailer **or** from a parseable conventional title. Do not let both say different things.

### Read in this order

1. Root `CLAUDE.md`, Rule 16 hardest. It still describes hand-running `skill-version.sh bump`, which is exactly what this ticket must not do. `E1.12` rewrites it afterwards.
2. This entry, the top entry of `HYDRATION.md`. Read only this one.
3. The ticket: `work-orders/WO-20260824-f1a5/WO-20260824-316d-pilot-take-hydration-prompt-through-the-whole-pi.md`.
4. `docs/superpowers/plans/2026-08-24-skills-package-manager-implementation.md`, section `E1.10`.
5. `.github/scripts/bump-gate.sh`, its `usage` and `resolve`. It is what will refuse you, and reading it is cheaper than a CI round.
6. `.github/scripts/bump-lib.sh`, which both halves share. The gate and the publisher reaching different conclusions about the same commit is the failure the whole design exists to prevent.
7. `work-orders/archive/2026/WO-20260824-360d-publish-workflow-allocate-versions-on-merge-to-m.md`, the notes. The range is `<before>..HEAD`, levels come from every commit in it, and the publisher skips its own `Skill-Publish: true` commits.

### Reuse, it is proven

`.github/scripts/testing/run-tests.sh` is at 145 checks and covers both halves of the pipeline against a fixture repository. If the gate refuses you for a reason you did not expect, the answer is likely already a check in there.

`claude/skills/hydration-prompt/testing/run-tests.sh` is the suite the matrix leg will run. Run it locally first - a red leg on the pilot is indistinguishable from a broken gate until you have.

### The verification ladder

Rung 1, free: `skill-version.sh verify --structure` before you push.

Rung 2: `bump-gate.sh resolve --base main --title-file <f> --body-file <f>` locally, in a container, against your own title and body. The table it prints is the table CI prints.

Rung 3: the gate on the real pull request. One matrix leg, named `hydration-prompt`, and the resolution table in the log.

Rung 4: the merge. Watch the publisher run on `main`.

Rung 5: `git fetch && git show origin/main:claude/skills/registry.json` - the number moved, and nobody typed it.

Rung 6: `skill-version.sh verify` green on `main` afterwards.

Rung 7: the suites still at 251, 103, 299, 145 and 36.

### Traps, already paid for

**`registry.json` is not yours.** Hand-editing it, or the `version:` line, is the precise failure `verify` exists to catch, and on this ticket it also destroys the thing being proved.

**Do not touch a second skill.** The gate resolves a level for _every_ changed skill, and a stray edit turns a one-leg matrix into a two-leg one and the pilot into something else.

`jq` reading and writing the same file truncates it. Write to a temp file and move it.

`~/.local/bin` may not be on `PATH` in a non-interactive shell, which is what a hook runs in.

A command reports success and did nothing. Assert the post-state, never `$?` alone.

`work-order.sh start` refuses with "working tree is dirty", and it leaves the ticket file, `INDEX.md` and the epic README uncommitted. Commit them first.

A markdown formatter re-pads tables in a file you only meant to add one line to. It is a `PostToolUse` hook in the machine's global `~/.claude/settings.json`. `git diff --stat` before committing.

A `grep -q` in a pipeline reports "no match" when it matched: it closes the pipe on the first hit, the upstream dies of SIGPIPE, and `pipefail` turns that into a non-zero pipeline. Capture to a variable and grep the variable.

**A suite with no self re-exec, run as `bash <suite>`, runs on the host and fails 89 checks with `mkdir: cannot create directory '/work'`.** `claude/skills/skill-versioning/testing/run-tests.sh` is one of these - its podman command is in its own header comment. That is not a regression, it is the wrong invocation, and it costs ten minutes to work out from the failures alone.

### Workflow

```bash
WO=claude/skills/work-order/scripts/work-order.sh
HP=claude/skills/hydration-prompt/scripts/hydration.sh
SV=claude/skills/skill-versioning/scripts/skill-version.sh

bash $WO show    --project . --id WO-20260824-316d
bash $WO start   --project . --id WO-20260824-316d   # creates the branch, leaves files uncommitted

# ... remove the notice from hydration-prompt/SKILL.md, and only that file ...

bash $SV verify --structure                          # NOT bump. The publisher owns the number

git push -u origin <branch>
gh pr create --base main --title "..." --body-file <file>   # body carries Bump: <level>

bash $WO submit  --project . --id WO-20260824-316d --pr <N>
bash $WO done    --project . --id WO-20260824-316d   # archives on the branch, commits nothing

bash $HP check   --project . --body-file /tmp/entry.md
bash $HP add     --project . --id <next> --title "<next title>" --body-file /tmp/entry.md

git add -A && git commit && git push                 # rides the SAME pull request

# after the merge
bash $WO cleanup --project . --id WO-20260824-316d
gh run watch                                         # the publisher, on main
```

`approve` is already done for every ticket in both epics and must not be run again.

### Conventions

Every reference to a work-order in a chat reply carries the ticket ID and its full title joined by a dash. A bare ID is a defect, and so is "the next ticket" or "the blocked one".

Feature branches only. The publisher is the one named exception and it is now live rather than planned.

Rule 14 has no size threshold. Where a rung genuinely cannot be containerised, say which one and why, rather than letting it look containerised.

When the ticket contradicts itself, or contradicts the runner, say so and pick one in the open.

<!-- hydration-entry: WO-20260824-bb0d -->
## WO-20260824-bb0d - setup.sh installs the skill-sync binary, then the SessionStart hook
_Generated 2026-08-25 by hydration.sh. Newest entry._

### Ticket

`WO-20260824-bb0d` - `setup.sh installs the skill-sync binary, then the SessionStart hook`.
Both of its dependencies are `done`: `WO-20260824-0615` - `Confirm whether a SessionStart hook matcher filters by source`, and `WO-20260824-efb0` - `skill-sync.sh part two: build, swap, receipt, and self-update`.
`work-order next` returns it first.

It blocks `WO-20260824-316d`, and it is the last thing standing between the pipeline and the pilot, `WO-20260824-f1a5` - `Skills package manager: prove the path on one skill`, which `next` returns second.

The plan sized it as small. Order inside the ticket is the whole difficulty, and constraint `C4` in the plan says why: the hook fires in **every project on this machine**, so a hook pointing at a `skill-sync` that is not yet on `PATH` prints a command-not-found into every session until someone fixes it.

### What just landed

`.github/workflows/skill-publish.yml` exists, as PR #70. The pipeline is complete: `skill-pr-gate.yml` reads a pull request and refuses it, `skill-publish.yml` turns the intent it validated into a number on `main` after the merge.

`.github/scripts/publish.sh` is the shell - `plan` and `apply`. `.github/scripts/bump-lib.sh` is new: the resolution both halves now share, extracted out of `bump-gate.sh` rather than copied.

The gate's suite went from **66 checks to 145**, and it is the one your change does not touch.

Three decisions were taken in the open and are notes on that ticket rather than in either design document.

**The range is `<before>..HEAD`, not the plan's `<before>..<after>`, and levels come from every commit in it rather than from `git log -1`.** `skill-version.sh bump` regenerates the _whole_ registry, so a run that bumps only part of what it checked out writes the rest of the tree's new content hashes under their old version numbers, `verify` passes, and that change ships to every project as a version they already have. There is a check that demonstrates it rather than describing it.

**The publisher stamps `Skill-Publish: true` on its own commits and skips any commit carrying it**, so its `chore(skills):` subject cannot map to `patch` and re-bump the previous run's work.

**The loop guard is load-bearing for correctness, not only for cost.** `verify` green means the batch was already published, so the run exits 0 before it reads a trailer. That is what stops the wide range double-counting.

### What is NOT done

`setup.sh` knows nothing about `claude/tools/`. `grep -n skill-sync setup.sh` prints nothing - the file is 417 lines of agent and skill installation and that is all it does.

`~/.claude/settings.json` has no `SessionStart` hook for the sync. The matcher spike wrote one into a scratch project and deleted it afterwards; the machine's own settings were never touched.

Branch protection is still absent and is still on no ticket. `verify --structure` still cannot pass for a brand new skill - it is on no ticket either, and it will bite the first person who adds one.

None of the publisher's three acceptance criteria has been observed against the real `main`, because the workflow did not exist there until #70 merged. The evidence on that ticket says so in those words. `AC-H2` is the merge of #70 itself; `AC-H1` needs two real back-to-back merges and the pilot is the natural first.

### Stale or false in the docs

**The matcher question is answered and the answer is yes.** `WO-20260824-0615` exercised all four sources against a scratch project and wrote the truth table onto its own ticket. `matcher: "startup"` fired on startup only. `matcher: "startup|resume|clear"` fired on those three and not on compact. The control, `matcher: ""`, fired on all four - which is the load-bearing part, because without it a hook that did not fire is indistinguishable from a session event that never happened.

So **use `"matcher": "startup|resume|clear"`**, which is confirmed working rather than assumed, and the plan's fallback branch - `skill-sync` reading the source off stdin and exiting early itself - does not happen. The payload on stdin does carry `source`, but it does not have to be read, and that is the point.

**`ubuntu-24.04` ships Podman**, 5.8.4. Both design documents still say the runner only has Docker. Not yours, but do not re-add an install step on their say-so.

### Your scope

The plan's `E1.9` is the checklist, and constraint `C4` is why the order inside it is not cosmetic.

- Install `skill-sync` to `~/.local/bin/`, beside the existing `-axi` tools. **Then** the hook.
- `SessionStart` hook in `~/.claude/settings.json`, `timeout: 30`, `"matcher": "startup|resume|clear"`.
- Idempotent: running `setup.sh` twice does not produce two hooks.
- **Done when a session started in a project with no `.claude/skills.toml` prints nothing at all.**

Silence in the no-manifest case is the acceptance criterion because that is the state of almost every project on this machine, and a hook that is noisy there gets deleted by whoever is annoyed by it first - and the whole system goes with it.

### Before you start

`setup.sh` writes to `$HOME`. Decide how you are proving idempotency before you write it: the ticket's own test plan says a container with a fake `HOME`, and that is the shape that works - `HOME=/work/home bash setup.sh` twice, then count the hook entries.

The silence criterion cannot run in a container. A `SessionStart` hook fires from a real Claude Code session on the host and there is no way to produce one inside Podman. `WO-20260824-0615` hit exactly this and stated it rather than quietly skipping it; do the same, and say which rung each check ran on.

### Read in this order

1. Root `CLAUDE.md`. Rules 12, 14 and 17 all bear on this one, and 17 hardest: `setup.sh` runs on Windows too.
2. This entry, the top entry of `HYDRATION.md`. Read only this one.
3. The ticket: `work-orders/WO-20260824-f1a5/WO-20260824-bb0d-setup-sh-installs-the-skill-sync-binary-then-the.md`.
4. **`work-orders/archive/2026/WO-20260824-0615-confirm-whether-a-sessionstart-hook-matcher-filte.md`**, the whole note. It is the truth table, and it is the reason you are not spiking this yourself.
5. `setup.sh`, all 417 lines. It has a `usage`, a discovery pass, a validation pass and an install pass, and your change is a fourth thing it does rather than a variation on the third.
6. `claude/tools/skill-sync.sh`, at least its header. `--plan` resolves and prints, `--boot` resolves and applies; the hook calls one of them and the ticket does not say which.
7. `docs/superpowers/plans/2026-08-24-skills-package-manager-implementation.md`, section `E1.9` and constraint `C4`.
8. `~/.claude/settings.json` as it is now. Every hook in it uses `"matcher": ""`, so this machine still has no working example of the filtered form outside the spike's write-up.

### Reuse, it is proven

`claude/tools/testing/run-tests.sh` is the suite for the tools tree, at 193 checks, and it re-execs itself into Podman. If `setup.sh` gains logic worth testing, that is where a fixture-with-a-fake-`HOME` belongs rather than in a second harness.

`.github/scripts/testing/run-tests.sh` is the pattern when the thing under test writes: a fixture built in a scratch mount, the script driven against it in a container, refusals as most of the suite. It is at 145 checks now and it is worth reading for shape even though your change is nowhere near it.

`jq` is the only safe way to add a hook to `settings.json`. A `sed` into JSON is how a settings file gets corrupted in every project on the machine at once.

### The verification ladder

Rung 1, free: `shellcheck -x -s bash setup.sh`, from `docker.io/rhysd/actionlint@sha256:9d36088643581e728c969f35141f88139fec77280b2be23c1f66f8e40e1025e7`, which ships it.

Rung 2: `HOME=/work/home bash setup.sh` in a container, twice. The binary is on `PATH` and there is exactly **one** hook entry, not two. Count it with `jq`, not with eyes.

Rung 3: the same, starting from a `settings.json` that already has other hooks in it. They all survive.

Rung 4: the binary lands before the hook. Assert the order by running with the install step made to fail and confirming no hook was written.

Rung 5, on the host and manual: a real session in a project with **no** `.claude/skills.toml`. It prints nothing at all. That is the acceptance criterion and it cannot be containerised.

Rung 6: a real session in a project that **does** have a manifest. The sync runs.

Rung 7: `skill-version.sh verify` green, and the suites still at 193, 103, 299, 145 and 36.

### Traps, already paid for

**A hook installed before the binary breaks every project on the machine**, not just this one, and the error it prints looks like Claude Code's rather than yours. This is the entire reason the ticket names an order.

`jq` reading and writing the same file truncates it. Write to a temp file and move it.

`~/.local/bin` may not be on `PATH` in a non-interactive shell, which is what a hook runs in. The hook's command may need the absolute path even though the install target is the directory.

A command reports success and did nothing. Assert the post-state, never `$?` alone.

`work-order.sh start` refuses with "working tree is dirty", and it leaves the ticket file, `INDEX.md` and the epic README uncommitted. Commit them first.

A markdown formatter re-pads tables in a file you only meant to add one line to. It is a `PostToolUse` hook in the machine's global `~/.claude/settings.json`, not in this repository - which is the same file you are about to edit. `git diff --stat` before committing.

A `grep -q` in a pipeline reports "no match" when it matched: it closes the pipe on the first hit, the upstream dies of SIGPIPE, and `pipefail` turns that into a non-zero pipeline. Capture to a variable and grep the variable.

### Workflow

```bash
WO=claude/skills/work-order/scripts/work-order.sh
HP=claude/skills/hydration-prompt/scripts/hydration.sh
SV=claude/skills/skill-versioning/scripts/skill-version.sh

bash $WO show    --project . --id WO-20260824-bb0d
bash $WO start   --project . --id WO-20260824-bb0d   # creates the branch, leaves files uncommitted

# ... edit setup.sh, prove rungs 1 to 4 in a container, then rungs 5 and 6 on the host ...

bash $SV verify                                      # this one has to be green

bash $WO evidence --project . --id WO-20260824-bb0d --index 1 --observed "..."
bash $WO evidence --project . --id WO-20260824-bb0d --index 2 --observed "..."

git push -u origin <branch>
gh pr create --base main --title "..." --body-file <file>

bash $WO submit  --project . --id WO-20260824-bb0d --pr <N>
bash $WO done    --project . --id WO-20260824-bb0d   # archives on the branch, commits nothing

bash $HP check   --project . --body-file /tmp/entry.md
bash $HP add     --project . --id <next> --title "<next title>" --body-file /tmp/entry.md

git add -A && git commit && git push                 # rides the SAME pull request

# after the merge
bash $WO cleanup --project . --id WO-20260824-bb0d   # deletes both branches, writes nothing
```

`approve` is already done for every ticket in both epics and must not be run again.

**The publisher is live now.** Merging your pull request starts a run on `main` that will bump anything under `claude/skills/` you touched - so if you touch a skill, the pull request description carries the `Bump:` trailer and never the number, and `registry.json` is not yours to edit. `setup.sh` is at the repository root and is not a skill, so on this ticket that probably means the publisher finds nothing to do, which is `AC-H2` of `WO-20260824-360d` - `Publish workflow: allocate versions on merge to main and regenerate the registry` observed for real. Watch the run either way.

### Conventions

Every reference to a work-order in a chat reply carries the ticket ID and its full title joined by a dash. A bare ID is a defect, and so is "the next ticket" or "the blocked one".

Feature branches only. Nothing writes to `main` except the publisher, which is now the named exception rather than a planned one.

Rule 14 has no size threshold, and Rule 12 is what covers the part of this ticket that cannot obey it: say which rung ran on the host and why, rather than letting it look containerised.

When the ticket contradicts itself, or contradicts the runner, say so and pick one in the open.

<!-- hydration-entry: WO-20260824-360d -->
## WO-20260824-360d - Publish workflow: allocate versions on merge to main and regenerate the registry
_Generated 2026-08-25 by hydration.sh. Newest entry._

### Ticket

`WO-20260824-360d` - `Publish workflow: allocate versions on merge to main and regenerate the registry`.
Both of its dependencies are `done`: `WO-20260824-cc71` - `Repo settings: squash-only, with the commit body taken from the PR description`, and `WO-20260824-efb0` - `skill-sync.sh part two: build, swap, receipt, and self-update`.
`work-order next` returns it first.

It blocks `WO-20260824-316d`, and it is the writing half of the pipeline whose reading half, `WO-20260824-2ad1` - `PR gate workflow: validate the bump intent and run the affected suites`, merged as PR #66.

Poker put it at 8. Same iteration cost as the gate, and this one writes to `main`.

### What just landed

`.github/` exists now. It did not before, and PR #66 is the first thing in it: `workflows/skill-pr-gate.yml`, `scripts/bump-gate.sh`, `scripts/require-podman.sh`, and `scripts/testing/run-tests.sh` at 66 checks.

The gate has run against three real pull requests and refused one of them on purpose. It reads and it writes nothing.

**Most of what you need is already written, in `bump-gate.sh`.** `resolve` parses the `Bump:` trailers, validates them against the file list, falls back to the conventional title, and computes the next version for every changed skill. The publisher needs the same resolution from a merge commit rather than from a pull request. Read it before writing a second copy.

The pieces you can lift directly: `changed_skills` (path split, `registry.json` excluded without a special case, deletions dropped), `registry_version` (scoped to the skills block, so a tool name can never be read as a skill's version), `next_version`, and `title_level` with the type map below.

Three decisions the gate took bind you, because the publisher has to agree with them or the two halves disagree about the same commit. They are notes on `WO-20260824-2ad1` - `PR gate workflow: validate the bump intent and run the affected suites`, and the publisher has to agree with them or the two halves disagree about the same commit.

**The trailer beats the title, always.** The title is the fallback the spec describes for "anything changed but not listed", which makes it the inferred source and the trailer the explicit one.

**The conventional-type map**, which the spec names only for `feat`, `fix` and `BREAKING CHANGE`. `feat` is minor. `fix`, `docs`, `chore`, `refactor`, `test`, `style`, `perf`, `ci` and `build` are patch - that list is Rule 16's own table. A `!` or a `BREAKING CHANGE:` footer is major. **`revert` is deliberately unmapped** and forces an explicit trailer.

**A skill absent from the registry needs no trailer and no title type.** `resolve` already reports it as `new` at 1.0.0, which is your `init` call.

### What is NOT done

`.github/workflows/skill-publish.yml` does not exist. You are creating it.

Branch protection is still absent and is still on no ticket. The gate is the thing that would eventually be required; requiring it is not your ticket either.

`setup.sh` installing the binary and the SessionStart hook is `WO-20260824-bb0d` - `setup.sh installs the skill-sync binary, then the SessionStart hook`. Removing the notice from any `SKILL.md` is `WO-20260824-f1a5` - `Skills package manager: prove the path on one skill`, the pilot, and it needs you first.

### Stale or false in the docs

**`ubuntu-24.04` ships Podman.** 5.8.4, confirmed live in three runs on PR #66 and #67. Both design documents and the plan say the job has to install it because the runner only has Docker. It does not. `.github/scripts/require-podman.sh` asserts instead, because an apt version cannot be pinned to an immutable identifier the way Rule 15 asks and pinning one Ubuntu later retires from the archive is a guaranteed future break. Use the same script.

**The suites are not uniform**, and the last hydration entry said they were. Three of the seven re-exec themselves into Podman - `cartography`, `project-scaffold`, `work-order` - and the other four expect to be started inside a container already. `bump-gate.sh run-suite` reads the suite and dispatches. You probably do not need it: the publisher does not run tests, because the gate already did on the pull request and re-running them after the merge only delays the registry.

Both design documents still state the repository settings as `squash_merge_commit_message=COMMIT_MESSAGES`. That was changed by `WO-20260824-cc71` - `Repo settings: squash-only, with the commit body taken from the PR description`. **This bears directly on you**: the squash commit body _is_ the pull request description, so `git log -1 --format=%B | git interpret-trailers --parse` on `main` sees exactly the text the gate validated. That is the whole reason divergence between the two halves is structurally impossible, and it only holds because that setting is now `PR_BODY`.

### Your scope

The plan's `E1.8` is the checklist and the spec's `The publisher` has the diagram.

- `on: push: branches: [main]`, `concurrency: {group: skill-publish, cancel-in-progress: false}`. Cancelling drops a bump.
- `actions/checkout` with `ref: main`, **not** the default `github.sha`. This is the batching case and it is not a detail.
- `verify` first, the full one, not `--structure`. Green means there is nothing to do, exit 0. This is the loop guard and it is free.
- Changed skills from `git diff --name-only <before>..<after> -- claude/skills/`.
- Levels from `git log -1 --format=%B | git interpret-trailers --parse`.
- A skill absent from the registry gets `init` at 1.0.0.
- An unresolvable level **fails the run and bumps nothing**.
- Commit and push with `GITHUB_TOKEN`. `permissions: contents: write` - the gate is `contents: read` and you are the one job in this repository that is not.
- `runs-on: ubuntu-24.04`, never `ubuntu-latest`.

### Before you start

`AC-H1` is the back-to-back case and it needs two real merged pull requests. Decide how you are going to produce them before you write the YAML, because it is the acceptance criterion and it is the one that cannot be faked.

The pilot, `WO-20260824-f1a5` - `Skills package manager: prove the path on one skill`, is a natural first merge for it.

### Read in this order

1. Root `CLAUDE.md`. Rules 12, 14, 15 and 16 all bear on this one.
2. This entry, the top entry of `HYDRATION.md`. Read only this one.
3. The ticket: `work-orders/WO-20260824-f1a5/WO-20260824-360d-publish-workflow-allocate-versions-on-merge-to-m.md`.
4. **`.github/scripts/bump-gate.sh`**, all of it. It is the resolution logic you are about to need a second copy of, and its header says why it is a script rather than a shell block.
5. `.github/workflows/skill-pr-gate.yml`, for the job shape, the pinned `actions/checkout` SHA and the `permissions` block.
6. `docs/superpowers/plans/2026-08-24-skills-package-manager-implementation.md` section `E1.8`.
7. `docs/superpowers/specs/2026-08-23-skills-package-manager-design.md`, sections `The publisher`, `Failure is closed, not guessed` and `Writing to main`.
8. `claude/skills/skill-versioning/scripts/skill-version.sh`, the `bump`, `init` and `verify` paths.

### Reuse, it is proven

`.github/scripts/testing/run-tests.sh` is the pattern for proving workflow shell without pushing: a fixture repository built in a scratch mount, the script driven against it in a container, refusals as most of the suite. Extend that file rather than starting a second one - the publisher's resolution is the same resolution.

`actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1` is v7.0.1, already pinned in the gate. Use the same SHA.

`actionlint` shellchecks every `run:` block as well as parsing the YAML, and it runs from `docker.io/rhysd/actionlint@sha256:9d36088643581e728c969f35141f88139fec77280b2be23c1f66f8e40e1025e7`. A workflow that does not parse is a push wasted.

### The verification ladder

Rung 1, free: `actionlint`, which also shellchecks the `run:` blocks.

Rung 2: the resolution logic against a fixture, in a container, extending the existing 66 checks.

Rung 3: merge one pull request that bumps one skill. The version and the registry move on `main`, and nobody moved them by hand. That is half of `AC-H1`.

Rung 4: the publisher's own push. `verify` passes, exit 0, nothing done. That is `AC-H2`.

Rung 5: two pull requests merged back to back. Both skills correct. That is the rest of `AC-H1`, and `ref: main` is what makes it work.

Rung 6: a merge with an unresolvable level. The run fails and every version is unchanged. That is `AC-H3`.

Rung 7: `skill-version.sh verify` green on `main`, and the suites still at 193, 103, 299, 66 and 36.

### Traps, already paid for

`actions/checkout` defaults to `github.sha`. On the second of two back-to-back merges that is a tree which is no longer `main`, and the push is rejected non-fast-forward whether or not the runs are serialised.

**`verify --structure` cannot pass for a brand new skill.** With no `version:` line `cmd_verify` calls it unversioned; with one, `diff_check` calls the `version:` hand-edited. Either way the gate refuses the one change nobody can land another way. `bump-gate.sh resolve` handles the case correctly on its own, so the refusal comes out of `skill-version.sh`. It is on no ticket and it will bite the first person who adds a skill.

An empty matrix is a workflow error rather than a skipped job. Not your problem here, but the same class of thing is: a job whose `if:` reads an output that was never set silently never runs.

CI iteration costs a push each time. Everything that can be checked locally should be, before the first push. The gate was written that way and reached CI green on its first run.

A `grep -q` in a pipeline reports "no match" when it matched: it closes the pipe on the first hit, the upstream dies of SIGPIPE, and `pipefail` turns that into a non-zero pipeline. Capture to a variable and grep the variable.

A markdown formatter re-pads tables in a file you only meant to add one line to. It is a `PostToolUse` hook in the machine's global `~/.claude/settings.json`, not in this repository. `git diff --stat` before committing.

`work-order.sh start` refuses with "working tree is dirty", and it leaves the ticket file, `INDEX.md` and the epic README uncommitted. Commit them first.

A command reports success and did nothing. Assert the post-state, never `$?` alone.

### Workflow

```bash
WO=claude/skills/work-order/scripts/work-order.sh
HP=claude/skills/hydration-prompt/scripts/hydration.sh
SV=claude/skills/skill-versioning/scripts/skill-version.sh

bash $WO show    --project . --id WO-20260824-360d
bash $WO start   --project . --id WO-20260824-360d   # creates the branch, leaves files uncommitted

# ... write .github/workflows/skill-publish.yml, prove what can be proved locally ...

bash $SV verify                                      # this one has to be green

bash $WO evidence --project . --id WO-20260824-360d --index 1 --observed "..."
bash $WO evidence --project . --id WO-20260824-360d --index 2 --observed "..."
bash $WO evidence --project . --id WO-20260824-360d --index 3 --observed "..."

git push -u origin <branch>
gh pr create --base main --title "..." --body-file <file>

bash $WO submit  --project . --id WO-20260824-360d --pr <N>
bash $WO done    --project . --id WO-20260824-360d   # archives on the branch, commits nothing

bash $HP check   --project . --body-file /tmp/entry.md
bash $HP add     --project . --id <next> --title "<next title>" --body-file /tmp/entry.md

git add -A && git commit && git push                 # rides the SAME pull request

# after the merge
bash $WO cleanup --project . --id WO-20260824-360d   # deletes both branches, writes nothing
```

`approve` is already done for every ticket in both epics and must not be run again.

The pull request description is the merge commit body verbatim, and on this ticket that is not a style note: it is the input your own workflow parses.

### Conventions

Every reference to a work-order in a chat reply carries the ticket ID and its full title joined by a dash. A bare ID is a defect, and so is "the next ticket" or "the blocked one".

Feature branches only, and nothing writes to `main` any more - except, from this ticket onward, the publisher.

Rule 14 has no size threshold. A single `--help` run whose purpose is to check that something works goes in a container.

When the ticket contradicts itself, or contradicts the runner, say so and pick one in the open. The gate found two: the suites are not uniform, and `ubuntu-24.04` already has Podman. Both are notes on that ticket rather than smoothed over.

