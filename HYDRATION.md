# HYDRATION.md

The prompt that starts the next session, and the 10 before it.

**Read the top entry only.** It is the current one and it is complete on its own.
Everything below it has been superseded and is kept for history, not for reading.

**Newest on top.** Adding an entry removes the oldest in the same commit, so this
file holds exactly 10 once it has filled up. Entries are never renumbered and
never edited in place - a correction is a new entry.

Written by `hydration.sh add`. Do not hand-edit.
<!-- hydration-entry: WO-20260824-6a33 -->
## WO-20260824-6a33 - Checklist for the four repositories carrying the stale session-start block
_Generated 2026-08-30 by hydration.sh. Newest entry._

### Ticket

`WO-20260824-6a33` - `Checklist for the four repositories carrying the stale session-start block`.
It is a `feature`, `p2`, a child of `WO-20260824-00d5` - `Skills package manager: roll it out across the repository`.

The order for the whole epic was reviewed and approved on 2026-08-29 and is recorded as a note on `WO-20260824-00d5` itself, not only here. This ticket is **step 4 of 6**, and step 3 is now closed. Do not re-derive the order; if you think it is wrong, say so and ask.

It is 3 points, sized as the checklist only. The four runs happen inside those four repositories and are not tickets here.

**It is the smallest ticket left in the epic and it is entirely documentation.** No script, no suite, no bump. That is not licence to be quick about it: the whole value of the artefact is that its line numbers resolve.

### What just landed

**PR #86, `WO-20260824-c6b0` - `skill-onboard.sh brings an existing project onto the sync`.** Step 3 is complete. `claude/tools/skill-onboard.sh` exists, at 636 lines, and it is the tool your checklist names.

One run, one pull request: it writes `.claude/skills.toml`, the two `.gitignore` stanzas and the `## Skills` section, stops git tracking the declared skills, commits, pushes, opens the PR, squash-merges, deletes the branch and hands the workbench back. **There is no template text in it at all** - it fetches the real templates from GitHub, or from `--dotfiles` with `--from local`, and splices. The suite asserts the `## Skills` section that lands is `CLAUDE.md.tmpl`'s byte for byte.

`slot.sh` finally has its caller. `acquire --holder skill-onboard` takes the workbench, an `EXIT` trap releases it on every path out, and the release's verdict outranks whatever else went wrong: a run that cannot free its slot exits **5** even when the failure that got it there was something else.

**One deliberate narrowing, and it is in the pull request body rather than only here.** The ticket's Scope said `git rm -r --cached .claude/skills/`. It un-tracks the **declared** skills one directory at a time instead, and only where they were committed. The whole-directory form would also un-track a hand-authored project-local skill, and with `**/.claude/skills/` newly blanketed that skill would vanish from the repository with nothing reporting it.

**The tools test image gained git and moved to `:3`.** Git was absent because nothing touched it; something does now. The hazard moved to an assertion, exactly as it did for jq: no runnable line of `skill-sync.sh` names git. **`claude/tools`'s suite went 258 -> 350.**

`container-sandbox/references/skill-testing.md` gained "When the real tool lies, the stub has to lie the same way" - reproduce the recorded misbehaviour, assert the post-state, never `$?`, and keep the stub permissive where the real tool is permissive so the wrapper's guard stays testable. That is the one skill this PR bumped, at `patch`.

Before that: PR #85 shipped `b21b`, PR #84 shipped `81a6`, PR #83 shipped `slot.sh` and step 1. Epic 1 closed at PR #79.

### What is NOT done

**The four repositories are named nowhere in this repository, and finding them is the first half of your ticket.** `git grep` over `docs/` and `work-orders/` finds the phrase "four repositories" and never a list. `docs/.../2026-08-24-skills-package-manager-implementation.md:521` describes them and counts them; it does not name one. Only `local-k8s-docs` appears anywhere by name, at `docs/superpowers/specs/2026-08-23-skills-package-manager-design.md:784`, and it is named there for an unrelated reason. **The list has to be discovered on this machine, not read out of here.**

The string to grep for is the heading `## Session start - skill version check`, which is what `CLAUDE.md.tmpl` carried until PR #85 deleted it. `skill-onboard.sh` encodes that exact heading as `LEGACY_HEADING` and replaces it in place, so the tool and the checklist agree on what the block is by construction.

**Nothing in `claude/tools/skill-onboard.sh` has ever been run against a real repository.** That is a non-goal of both tickets, deliberately. Everything proved about it is proved against a scratch repository in a container with a real bare origin and a stubbed `gh` that performs a genuine squash-merge.

**`WO-20260830-eb89` - `skill-sync fills the CLAUDE.md skills table between the markers` is still not yours** and `next` will not offer it. It runs after `WO-20260824-238b` - `Rename skill-versioning to skill-registry, the closing commit`. A `CLAUDE.md` written by `skill-onboard.sh` carries an empty marker pair until it lands, which is inert rather than broken.

**11 of 13 skills with a `scripts/` directory still have no `justfile`**, which root `CLAUDE.md` Rule 17 requires. Only `context-compaction` and `living-docs` have one. `claude/tools/` has none either, and Rule 17 speaks about skills rather than tools, so that one is arguably not a gap. Repo-wide, on no ticket, named here for the eleventh cycle.

Branch protection is still absent and is still on no ticket.

**`work-order.sh approve` and `link` both strand themselves, and it is on no ticket.** Each writes the ticket file and `INDEX.md`; `start` refuses a dirty tree; `start` is what creates the branch. A `start --on-current-branch` would remove it.

Root `CLAUDE.md`'s `## Consuming These Files` section still contradicts Rule 16 steps 7 and 8, and **it is still on no ticket** after ten cycles of being named here.

### Stale or false in the docs

**`claude/skills/work-order/settings.local.json.tmpl:6` still names `work-order.sh close`.** There is no `close` verb; the lifecycle ends at `done`, on the branch, inside the pull request. It is the last of the four and it is on no ticket.

**The close-out diagram in `CLAUDE.md.tmpl` puts the pull request at step 4, after `done` at step 2.** The real order is `gh pr create`, then `submit --pr N`, then `done`, all inside the PR window. Surfaced on PR #85, on no ticket.

**The design doc's example manifest is stale and decision 20 wins.** `docs/superpowers/specs/2026-08-23-skills-package-manager-design.md:195` lists `project-scaffold` where decision 20 lists `context-compaction`.

**Both design documents still say the runner only has Docker.** `ubuntu-24.04` ships Podman 5.8.4.

**`project-scaffold/testing/run-tests.sh` pins `python:3.12-slim` by tag, not by digest**, a root `CLAUDE.md` Rule 15 violation. It predates `81a6` and has now been left alone deliberately three times. On no ticket.

**`scaffold.sh:214` depends on `cmp`**, which Rule 17 says to check for. Present in Git Bash so not a live break, but the same class of assumption the rule names. On no ticket.

### Your scope

The ticket's Scope block defines it and this section does not restate it. Four things are worth knowing before you read it.

**The PII policy is going to bite this ticket, and it is the one thing here you should decide with the user rather than alone.** Root `CLAUDE.md` bans repository URLs containing a real GitHub owner, with exactly two documented exceptions, both pointing at this repo's own published files. A checklist naming four of the user's repositories is neither of them. There are three honest ways out - angle-bracket placeholders with the real names held outside this repo, a fifth documented exception argued for on its merits, or the checklist living somewhere that is not this public repository - and picking one silently is the wrong move. Ask.

**`AC-H1` says the line numbers must resolve, and line numbers rot.** Record the commit SHA each row's numbers were read at, in the row. A number with no commit beside it resolves for a week and misleads afterwards, which is worse than a row that says only which file.

**`AC-H2` says a row closes only on that repository's own merged PR.** So the checklist has a state column that this repository can never tick from here. Write it so that is obvious on the page rather than a rule somebody has to remember.

**Non-goals, from the ticket and from plan E2.10 both.** Do not edit any of the four repositories from this session. Do not run `skill-onboard.sh` against one. That is a deliberate act inside each repository and it is not what this ticket delivers.

### Before you start

One thing is genuinely open and it is the PII question above. Everything else is settled.

The approved order is a note on `WO-20260824-00d5` dated 2026-08-30; read it rather than re-deriving it. The seventh step is a second note on the same ticket, same date.

`work-order.sh start` needs a clean tree and creates the branch for you. It leaves the ticket file and `INDEX.md` uncommitted, so commit them before anything else.

**Decide where the checklist file lives before you write a word of it.** `docs/` and the ticket's own body are both defensible and they are not the same artefact: one outlives the ticket and one does not. Root `CLAUDE.md`'s documentation-lifetime rule - the one PR #85 added to `CLAUDE.md.tmpl` - is the question to put it to: would this still be true after this repo is deleted?

### Read in this order

1. The ticket, and every note on it.
2. This entry, the top entry of `HYDRATION.md`. Read only this one.
3. `docs/superpowers/plans/2026-08-24-skills-package-manager-implementation.md` section E2.10, which is four sentences and contains the whole design of what you are writing.
4. The note on `WO-20260824-00d5` - `Skills package manager: roll it out across the repository` dated 2026-08-30 that is the approved order.
5. `claude/tools/skill-onboard.sh` - the header and `--help`, not the body. Your checklist names it and every row is a run of it, so the flags a row should carry are the thing to take from it. `--dry-run` and `--no-merge` both exist and both matter for a real repository.
6. Root `CLAUDE.md`'s `## PII & PHI Policy` and `### The documented exception`, together, before you write a repository name down.

### Reuse, it is proven

**`work-orders/INDEX.md` is the repository's existing example of a generated checklist with a state column**, and `work-order.sh reindex` is what regenerates it. If your checklist wants to be generated rather than hand-maintained, that is the shape already here.

**The four rows all describe the same edit**, because the block is identical in all four. Write the edit once and have the rows point at it, rather than repeating it four times and letting three copies drift.

**`skill-onboard.sh --dry-run` is the per-repository preflight a row can name.** It resolves, prints what it would declare, leases no workbench and writes nothing. A row that tells the operator to run the real thing first has skipped the only step that is free.

### The verification ladder

Rung 1: nothing, if the change is confined to `docs/` and `work-orders/`. Neither has a suite and neither is a skill. Say so in the pull request rather than leaving the reader to wonder which suite you skipped.

Rung 2: `bash .github/scripts/bump-gate.sh run-suite claude/skills/<name>` for any skill you do touch. If the checklist ends up inside a skill, that skill's suite runs and that skill needs a `Bump:` trailer.

Rung 3: `skill-version.sh verify --structure --base origin/main`. Green.

Rung 4: the gate on the pull request. A change confined to `docs/` and `work-orders/` needs **no** `Bump:` trailer and no level - the publisher's fallback covers it.

### Traps, already paid for

**A markdown formatter rewrites `*emphasis*` into `_emphasis_` on lines you never touched.** It is a `PostToolUse` hook in the machine's global `~/.claude/settings.json`. It fired on this ticket, on three lines of `skill-testing.md` that were nowhere near the edit, and it also rewrites a PR body file after `Write`. `git diff -U0 | grep '^-'` before committing and account for every deleted line. **Check the `Bump:` trailer is still the last line of the body file after the formatter has been at it.**

**`treehouse return` exits 0 having freed nothing.** A dirty worktree makes it prompt, take the no-TTY default, abandon the return and leave the slot leased. Assert the post-state; never read `$?`. `slot.sh` handles it and `skill-onboard.sh` now propagates it as exit 5.

**`treehouse get` hands out a second slot for a holder that already has one.** `slot.sh acquire` guards it; raw `treehouse` does not.

**A freed slot inspected from inside its own directory reports `you're here`, not `available`.** Key the check on `lease_holder`.

**`git switch --detach origin/main` after a commit that un-tracked files refuses**, because the identical untracked copies are still on disk and git cannot know they are the same bytes. `git switch --detach` with no ref detaches where you already are and changes not one file. That is what `skill-onboard.sh` does and it is why.

**A stub written from a tool's documented behaviour tests the tool you wish you had.** New section in `skill-testing.md` as of this PR.

**`rc=$?` on the line after a `podman run` never executes under `set -e`.** `|| rc=$?` on the run itself.

**A digest you did not copy from a real registry does not exist.** `podman pull <tag>` then `podman image inspect --format '{{index .RepoDigests 0}}'`.

**A container check against "the branch" silently runs `main`'s code if you have not committed.** `git clone` carries commits, not a working tree.

**A suite with no self re-exec, run as `bash <suite>`, runs on the host.** Use `bump-gate.sh run-suite`.

**`grep -qxF "$ROW"` where `$ROW` starts with a dash is parsed as an option.** `grep -qxF -- "$ROW"`.

**A `grep -q` in a pipeline reports "no match" when it matched.** SIGPIPE plus `pipefail`. Capture to a variable and use a herestring.

**`.claude/worktrees/smoke-tests` is a locked git worktree sitting untracked inside this repository.** It is not yours. `git add -A` at close-out is unsafe here - add explicit paths, which is what PR #76 through #86 all did. `gh pr create` warns `1 uncommitted change` because of it. Expected.

### Workflow

```bash
WO=claude/skills/work-order/scripts/work-order.sh
HP=claude/skills/hydration-prompt/scripts/hydration.sh
SL=claude/skills/hydration-prompt/scripts/slot.sh

bash $WO show    --project . --id WO-20260824-6a33
bash $WO start   --project . --id WO-20260824-6a33   # run it alone, never in an && chain
git add work-orders && git commit -m "chore(work-orders): start WO-20260824-6a33"

# ... find the four, write the checklist, ask about the PII question ...

bash $WO evidence --project . --id WO-20260824-6a33 --index N --observed '...'
git add <explicit paths>            # NOT -A, see .claude/worktrees/smoke-tests above
git commit && git push -u origin <branch>
gh pr create --base main --title "docs: ..." --body-file <file>
bash $WO submit  --project . --id WO-20260824-6a33 --pr <N>
bash $WO done    --project . --id WO-20260824-6a33   # on the branch, before the merge
bash $HP check   --project . --body-file /tmp/entry.md
bash $HP add     --project . --id <next> --title "<next title>" --body-file /tmp/entry.md
git add <explicit paths> && git commit && git push   # rides the SAME pull request

# after the merge
bash $WO cleanup --project . --id WO-20260824-6a33
bash $SL release --holder <holder>                   # if you took a slot
```

**Never run `skill-version.sh bump`.** The publisher allocates on `main`.

Step 5 of the approved order is `WO-20260824-d058` - `Remove the inline read-only notice from the other 42 SKILL.md files`, then `WO-20260824-79b6` - `Invert the notice assertion: verify --structure now fails on a notice that is present`.

### Conventions

Every reference to a work-order in a chat reply carries the ticket ID and its full title joined by a dash. A bare ID is a defect, and so is "the next ticket" or "the blocked one".

Feature branches only. `skill-publish.yml` is the one named exception, and root `CLAUDE.md` says so.

<!-- hydration-entry: WO-20260824-c6b0 -->
## WO-20260824-c6b0 - skill-onboard.sh brings an existing project onto the sync
_Generated 2026-08-30 by hydration.sh. Newest entry._

### Ticket

`WO-20260824-c6b0` - `skill-onboard.sh brings an existing project onto the sync`.
It is a `feature`, `p2`, a child of `WO-20260824-00d5` - `Skills package manager: roll it out across the repository`.

The order for the whole epic was reviewed and approved on 2026-08-29 and is recorded as a note on `WO-20260824-00d5` itself, not only here. This ticket is **step 3 of 6**, and step 2 is now closed on both halves. Do not re-derive the order; if you think it is wrong, say so and ask.

It is 5 points, sized below medium-plus on the grounds that the risky half - asserting the slot actually went free - is already solved knowledge. That is still true, and `slot.sh` is the solution sitting unused waiting for you.

**It is the largest ticket in the epic and the only one that touches other people's projects.**

### What just landed

**PR #85, `WO-20260824-b21b` - `CLAUDE.md.tmpl: replace the session-start prose, add the skills markers, the treehouse policy and the documentation-lifetime rule`.** Step 2 is complete. Four edits to one template, plus the suite that holds them.

The 68-line session-start skill version check is gone, replaced by a `## Skills` section that tells the agent it runs nothing. The `skills:begin` / `skills:end` marker pair is in, with `skill-sync` named in the marker text as the writer.

**`## Where your workspace comes from` is new and it is the paragraph decision 19 said it would be paid with.** One source: `~/.treehouse/<repo>-<hash>/`. A hand-rolled `git worktree add` and a second in-project pool are both refused by name. It points at `treehouse status` and reproduces no flags.

`## Hard rule: every runbook and playbook lives in one repository` is replaced by `## Hard rule: documentation goes where its lifetime says it goes`. One question - would this still be true after this repo is deleted - and one answer per document. Three rules the old section carried and the design doc's short block had dropped were kept deliberately: runbooks and playbooks named together, ask rather than route around, and do not invent a local procedure when a documented one exists.

The two dead `work-order.sh close` references at `:207` and `:248` are fixed. Step 5 is now `cleanup`, and the diagram renumbers.

**`project-scaffold`'s suite went 176 + 9 -> 187 + 9.** `140-skill-version-check` became `140-skills-block` (9), `150-runbooks-source-of-truth` became `150-documentation-lifetime` (12), and `170-treehouse-policy` is new (7). Three `testing/SOP.md` sections were rewritten with them.

Before that: PR #84 shipped `81a6`, PR #83 shipped `slot.sh` and step 1. Epic 1 closed at PR #79.

### What is NOT done

**Nothing in `claude/tools/skill-onboard.sh` exists. This ticket has not started.**

**`b21b` shipped the markers inert, and `WO-20260830-eb89` - `skill-sync fills the CLAUDE.md skills table between the markers` is the new ticket that fills them.** It was cut on `b21b`'s branch after the user was asked, is parented to the epic, and depends on `WO-20260824-238b` - `Rename skill-versioning to skill-registry, the closing commit`, so it runs first once the original six steps are done. The epic carries a note explaining why it exists and why it is last. **It is not yours and `next` will not offer it.** What matters to you: the CLAUDE.md block you write into an existing project will carry an empty marker pair, and that is correct and expected, not something to fill by hand.

**`slot.sh` still has no caller, and you are it.** `claude/skills/hydration-prompt/scripts/slot.sh` - `acquire --holder`, `release --holder`, `holder --holder`, `status` - is built, tested and documented, and nothing invokes it. Its header names `skill-onboard.sh` explicitly. `b21b` did not use it either: that session worked directly in the repository, as every session in this epic has.

**11 of 13 skills with a `scripts/` directory still have no `justfile`**, which root `CLAUDE.md` Rule 17 requires. Only `context-compaction` and `living-docs` have one. Repo-wide, on no ticket, named here for the tenth cycle.

Branch protection is still absent and is still on no ticket.

**`work-order.sh approve` and `link` both strand themselves, and it is on no ticket.** Each writes the ticket file and `INDEX.md`; `start` refuses a dirty tree; `start` is what creates the branch. `b21b` cut and approved `eb89` on its own branch, which worked because the branch already existed. A `start --on-current-branch` would remove it.

Root `CLAUDE.md`'s `## Consuming These Files` section still contradicts Rule 16 steps 7 and 8, and **it is still on no ticket** after nine cycles of being named here.

### Stale or false in the docs

**The dead `work-order.sh close` reference is now fixed in three of four places, and the survivor is on no ticket.** `claude/skills/work-order/settings.local.json.tmpl:6` still names it. There is no `close` verb; the lifecycle ends at `done`, on the branch, inside the pull request.

**The close-out diagram in `CLAUDE.md.tmpl` puts the pull request at step 4, after `done` at step 2.** The real order is `gh pr create`, then `submit --pr N`, then `done`, all inside the PR window. `b21b` fixed the `close` references and deliberately did not rewrite the ordering, which is a different edit. Surfaced on PR #85, on no ticket.

**The design doc's example manifest is stale and decision 20 wins.** `docs/superpowers/specs/2026-08-23-skills-package-manager-design.md:195` lists `project-scaffold` where decision 20 lists `context-compaction`.

**Both design documents still say the runner only has Docker.** `ubuntu-24.04` ships Podman 5.8.4.

**`project-scaffold/testing/run-tests.sh` pins `python:3.12-slim` by tag, not by digest**, a root `CLAUDE.md` Rule 15 violation. It predates `81a6` and was left alone deliberately twice. On no ticket.

**`scaffold.sh:214` depends on `cmp`**, which Rule 17 says to check for. Present in Git Bash so not a live break, but the same class of assumption the rule names. On no ticket.

### Your scope

The ticket's Scope block defines it and this section does not restate it. Five things are worth knowing before you read it.

**Take a slot, and take it with `slot.sh`, not with raw `treehouse`.** The Scope says `--lease-holder skill-onboard`; `slot.sh acquire --holder skill-onboard` is that call plus the guard that stops one holder taking two slots. You are the first caller of a file built for you, so if its interface is wrong for a real caller, that is a finding worth writing down rather than working around.

**The release is the load-bearing half and it must not read `$?`.** A dirty worktree makes `treehouse return` prompt, take its no-TTY default, abandon the return, leave the slot leased and exit 0. `slot.sh release` already throws that exit code away and asks the pool. Your AC-H2 - a dirty working tree reports a failure rather than exiting 0 having done nothing - is the same finding one level up, and it is about `skill-onboard.sh` itself, not about `slot.sh`.

**The written shape you are retrofitting is now finished and it is in three files.** `references/templates/skills.toml.tmpl` is the manifest, `gitignore.tmpl`'s project-scaffold block at the bottom carries `**/.claude/skills/`, and `CLAUDE.md.tmpl` carries the `## Skills` section with its marker pair. Read all three before writing the retrofit, and copy their content rather than re-authoring it - a second version of the manifest that drifts from the template is exactly the failure the ordering was designed to prevent.

**`git rm -r --cached .claude/skills/` runs only where they were committed.** A project that never committed them has nothing to un-track, and an unconditional `git rm` there fails in a way that reads like a broken script.

**Non-goals, from the ticket.** Do not install the hook - that is machine level and `setup.sh` owns it. Do not run this against any real repository; that is a separate deliberate act, and `WO-20260824-6a33` - `Checklist for the four repositories carrying the stale session-start block` is the ticket that writes down which ones.

### Before you start

Nothing is reserved for you to decide.

Two things are settled and recorded rather than open. The approved order is a note on `WO-20260824-00d5` dated 2026-08-30; read it rather than re-deriving it. The reason this ticket depends on `WO-20260824-a6cb` - `The hydration-prompt close-out acquires and releases a treehouse slot` is a note on this ticket dated 2026-08-30, and it is the leaked-slot-at-exit-0 finding, not a scheduling preference.

`work-order.sh start` needs a clean tree and creates the branch for you. It leaves the ticket file and `INDEX.md` uncommitted, so commit them before anything else.

**Grep the suite for any heading you are about to delete from a template.** `b21b` paid for not doing this: cases 140 and 150 asserted the exact section headings that ticket removed, and the failure surfaced on the first suite run rather than in the plan. It is ten seconds and it turns a discovery into a task.

### Read in this order

1. The ticket, and every note on it.
2. This entry, the top entry of `HYDRATION.md`. Read only this one.
3. The note on `WO-20260824-00d5` - `Skills package manager: roll it out across the repository` dated 2026-08-30 that is the approved order, and the one dated 2026-08-30 that records the seventh step.
4. `claude/skills/hydration-prompt/scripts/slot.sh` in full, and the `## The workbench` section of `claude/skills/hydration-prompt/SKILL.md` beside it. You are its first caller.
5. `docs/superpowers/plans/2026-08-24-skills-package-manager-implementation.md` section E2.1, and E2.10 below it for what this script is eventually pointed at.
6. The three template files named under `Your scope`, together, before writing anything that retrofits their shape.
7. `claude/tools/skill-sync.sh` - `manifest_list` and `resolve_project` - so what you write is what the sync reads.

### Reuse, it is proven

**`slot.sh` is the acquire-and-release shape and was built for you.** `claude/skills/hydration-prompt/scripts/slot.sh`, verbs `acquire --holder`, `release --holder`, `holder --holder`, `status`. Its two guards are the two findings from the gate probe, and both are asserted in `hydration-prompt`'s suite with a stubbed `treehouse`.

**`testing/live-check.sh` is the pattern for proving a host CLI still behaves as documented.** `claude/skills/hydration-prompt/testing/live-check.sh`, 19 checks, real binary bind-mounted read-only with `TREEHOUSE_ROOT` redirected into container scratch so the live pool is untouched. It is not run by the gate. If this ticket needs to know what real `treehouse` does in a case a stub cannot fake, that file is the shape.

**Feeding a real template to the parser that reads it is the shape that catches silent drift.** `claude/tools/testing/run-tests.sh`, section "the manifest `project-scaffold` ships", copies `skills.toml.tmpl` itself into a fixture project and runs `skill-sync --plan` over it. A retrofit that writes a manifest belongs in the same shape: assert against the template, not against a hand-built copy of it.

**The two-image suite split is built and documented.** `claude/skills/project-scaffold/testing/run-tests.sh` runs `cases/` and `cases-git/` under different images from one shared `INNER` body, and `container-sandbox/references/skill-testing.md` carries the pattern and its four traps. This ticket is git-heavy - `git rm --cached`, a real commit, a real push - so `cases-git/` and its pinned `bitnami/git` digest is where most of it belongs.

### The verification ladder

Rung 1: `bash .github/scripts/bump-gate.sh run-suite claude/tools`. Never `bash <suite>` directly. It is at **258**.

Rung 2: `bash .github/scripts/bump-gate.sh run-suite claude/skills/hydration-prompt` if you change `slot.sh`. It is at **86** across two images, and `testing/live-check.sh` at **19** is separate and not run by the gate.

Rung 3: `bash .github/scripts/bump-gate.sh run-suite claude/skills/project-scaffold` if you touch a template. **187 + 9**, prints `all cases passed, both images`.

Rung 4: `skill-version.sh verify --structure --base origin/main`. Green.

Rung 5: the gate on the pull request. `skill-onboard.sh` is a tool, not a skill, so a change confined to `claude/tools/` needs **no** `Bump:` trailer and no level - the publisher's fallback covers tools. If you also change `hydration-prompt` or `project-scaffold`, that skill needs one.

### Traps, already paid for

**`treehouse return` exits 0 having freed nothing.** A dirty worktree makes it prompt, take the no-TTY default, abandon the return and leave the slot leased. Assert the post-state; never read `$?`. This is the single most expensive finding in the epic and it is what this ticket's AC-H2 exists for.

**`treehouse get` hands out a second slot for a holder that already has one.** Two `get`s with one `--lease-holder` record the same holder against both. `slot.sh acquire` guards it; raw `treehouse` does not.

**A freed slot inspected from inside its own directory reports `you're here`, not `available`.** Key the check on `lease_holder`, which is cleared to `""` on a successful return. Checking the status field reports a leak on every clean close-out.

**A markdown formatter rewrites `*emphasis*` into `_emphasis_` on lines you never touched.** It is a `PostToolUse` hook in the machine's global `~/.claude/settings.json`. It also re-pads tables and rewrites a PR body file after `Write`. `git diff -U0 | grep '^-'` before committing and account for every deleted line. It did not fire on `b21b`, which is not evidence it is gone.

**`rc=$?` on the line after a `podman run` never executes under `set -e`.** The failing run ends the script before the capture. `|| rc=$?` on the run itself.

**`--entrypoint=""` is required for `bitnami/git`.** Its entrypoint is `git`, so a `bash -c` without it is handed to `git` as arguments.

**`bitnami/git` ships no `cmp`**, and a missing `cmp` exits 127, which is indistinguishable from "the files differ".

**An assertion that greps a file for a word its own comments explain will fail on the explanation.** Strip comments first, then assert on the data.

**A digest you did not copy from a real registry does not exist.** `podman pull <tag>` then `podman image inspect --format '{{index .RepoDigests 0}}'`.

**A container check against "the branch" silently runs `main`'s code if you have not committed.** `git clone` carries commits, not a working tree.

**A suite with no self re-exec, run as `bash <suite>`, runs on the host and fails with `mkdir: cannot create directory '/work'`.** Use `bump-gate.sh run-suite`.

**`grep -qxF "$ROW"` where `$ROW` starts with a dash is parsed as an option.** `grep -qxF -- "$ROW"`.

**A `grep -q` in a pipeline reports "no match" when it matched.** SIGPIPE plus `pipefail`. Capture to a variable and use a herestring.

**`.claude/worktrees/smoke-tests` is a locked git worktree sitting untracked inside this repository.** It is not yours. `git add -A` at close-out is unsafe here - add explicit paths, which is what PR #76 through #85 all did. `gh pr create` warns `1 uncommitted change` because of it. Expected.

### Workflow

```bash
WO=claude/skills/work-order/scripts/work-order.sh
HP=claude/skills/hydration-prompt/scripts/hydration.sh
SL=claude/skills/hydration-prompt/scripts/slot.sh

bash $WO show    --project . --id WO-20260824-c6b0
bash $WO start   --project . --id WO-20260824-c6b0   # run it alone, never in an && chain
git add work-orders && git commit -m "chore(work-orders): start WO-20260824-c6b0"

# ... the work ...

bash .github/scripts/bump-gate.sh run-suite claude/tools
bash .github/scripts/bump-gate.sh run-suite claude/skills/hydration-prompt   # if slot.sh changed

bash $WO evidence --project . --id WO-20260824-c6b0 --index N --observed '...'
git add <explicit paths>            # NOT -A, see .claude/worktrees/smoke-tests above
git commit && git push -u origin <branch>
gh pr create --base main --title "feat(tools): ..." --body-file <file>
bash $WO submit  --project . --id WO-20260824-c6b0 --pr <N>
bash $WO done    --project . --id WO-20260824-c6b0   # on the branch, before the merge
bash $HP check   --project . --body-file /tmp/entry.md
bash $HP add     --project . --id <next> --title "<next title>" --body-file /tmp/entry.md
git add <explicit paths> && git commit && git push   # rides the SAME pull request

# after the merge
bash $WO cleanup --project . --id WO-20260824-c6b0
bash $SL release --holder <holder>                   # if you took a slot
```

**A change confined to `claude/tools/` needs no `Bump:` trailer**, because tools are not skills and the publisher's fallback covers them. A change that also touches `claude/skills/<name>/` does. **Never run `skill-version.sh bump`.** The publisher allocates on `main`.

Step 4 of the approved order is `WO-20260824-6a33` - `Checklist for the four repositories carrying the stale session-start block`, which already depends on this ticket.

### Conventions

Every reference to a work-order in a chat reply carries the ticket ID and its full title joined by a dash. A bare ID is a defect, and so is "the next ticket" or "the blocked one".

Feature branches only. `skill-publish.yml` is the one named exception, and root `CLAUDE.md` says so.

<!-- hydration-entry: WO-20260824-b21b -->
## WO-20260824-b21b - CLAUDE.md.tmpl: replace the session-start prose, add the skills markers, the treehouse policy and the documentation-lifetime rule
_Generated 2026-08-30 by hydration.sh. Newest entry._

### Ticket

`WO-20260824-b21b` - `CLAUDE.md.tmpl: replace the session-start prose, add the skills markers, the treehouse policy and the documentation-lifetime rule`.
It is a `feature`, `p2`, a child of `WO-20260824-00d5` - `Skills package manager: roll it out across the repository`.

The order for the whole epic was reviewed and approved on 2026-08-29 and is recorded as a note on `WO-20260824-00d5` itself, not only here. This ticket is the **second half of step 2 of 6**. Do not re-derive the order; if you think it is wrong, say so and ask.

It is 5 points, sized above the plan's "small" and deliberately kept out of the four-part bundle beside it, because it is prose, it is four distinct edits, and one of them arbitrates a real conflict.

### What just landed

**PR #84, `WO-20260824-81a6` - `project-scaffold plumbing: skills.toml, the gitignore blanket, scaffold.json removed, skill-update.sh narrowed`.** The first half of step 2. Three skills changed, so the trailer carried three `Bump:` lines rather than one.

`claude/skills/project-scaffold/references/templates/skills.toml.tmpl` is new and carries decision 20's four - `work-order`, `living-docs`, `container-sandbox`, `context-compaction` - plus an empty `[agents]` block. `scaffold.sh` writes it into `.claude/skills.toml` and then never touches it again: a re-run plans it `skip`, the same rule `settings.local.json` gets.

`gitignore.tmpl` gained `**/.claude/skills/`. **It is in the project-scaffold block at the bottom, not beside `**/.claude/agents/` where the ticket's Scope said "beside the existing agents line".** Everything above that block is re-pulled verbatim from upstream, so a line added there is dropped by the next re-pull with no conflict and no warning - and that one line is the only thing stopping a skill copy from being committed. The comment on the line names the agents line it mirrors and says why it is not next to it.

`.claude/scaffold.json` is gone. `scaffold.sh` no longer writes it, and case 030's idempotence claim is now total - the build timestamp in that file was the one documented hole in it, and the `! -name` exclusion is deleted rather than left as dead code.

`skill-update.sh` opens with `SHOULD YOU BE RUNNING THIS?` and a three-row table keyed on the project's `.claude/skills.toml`. Header only; `--mode inline` and `--mode standalone` are untouched.

**`project-scaffold`'s suite now runs two images and sums the totals.** `testing/cases/` on `python:3.12-slim`, `testing/cases-git/` on the pinned `bitnami/git` digest. **176 + 9.** `claude/tools` went **251 -> 258**, and the seven added checks feed `project-scaffold`'s real template to `skill-sync`'s parser - every other case there builds its manifest with `mkproject`, which writes the shape the parser was written against, so nothing proved a scaffolded project ships that shape. `skill-versioning` unchanged at **148**.

`container-sandbox/references/skill-testing.md` gained "The other answer: two stock images, one suite", per Rule 14.

Before that: PR #83 shipped `slot.sh` and step 1 of 6. Epic 1 closed at PR #79; PRs #80, #81 and #82 followed.

### What is NOT done

**Nothing in `CLAUDE.md.tmpl` has been touched.** `81a6` did not edit that file at all, which is exactly why the two were split - the rebase surface for this ticket is empty.

**`WO-20260824-c6b0` - `skill-onboard.sh brings an existing project onto the sync` is startable and is step 3, not step 2.** It is the largest ticket in the epic and the only one that touches other people's projects. Take `b21b` first: `81a6` and `b21b` together set the written shape - manifest, gitignore stanza, template block - that `c6b0` retrofits onto repositories that already exist, and retrofitting a shape nobody has finished writing is the failure mode the order exists to prevent.

**`slot.sh` still has no caller.** `claude/skills/hydration-prompt/scripts/slot.sh` is built, tested and documented; nothing invokes it. `c6b0` is the first real caller, and its header names `skill-onboard.sh` explicitly.

**11 of 13 skills with a `scripts/` directory still have no `justfile`**, which root `CLAUDE.md` Rule 17 requires. Only `context-compaction` and `living-docs` have one. Repo-wide, on no ticket, named here for the ninth cycle.

Branch protection is still absent and is still on no ticket.

**`work-order.sh approve` and `link` both strand themselves, and it is on no ticket.** Each writes the ticket file and `INDEX.md`; `start` refuses a dirty tree; `start` is what creates the branch. This session worked around it by running `start` first and then `link`, so the graph edit rode the branch that already existed. A `start --on-current-branch` would remove it.

Root `CLAUDE.md`'s `## Consuming These Files` section still contradicts Rule 16 steps 7 and 8, and **it is still on no ticket** after eight cycles of being named here.

### Stale or false in the docs

**The dead `work-order.sh close` reference is fixed in two of four places and two of the remaining survivors are yours.** `claude/skills/project-scaffold/references/templates/CLAUDE.md.tmpl:207` and `:248` both still say `archive - work-order.sh close, straight to main`. There is no `close` verb; the lifecycle ends at `done`, on the branch, inside the pull request. The fourth is `claude/skills/work-order/settings.local.json.tmpl:6`, which is on no ticket.

**The design doc's example manifest is stale and decision 20 wins.** `docs/superpowers/specs/2026-08-23-skills-package-manager-design.md:195` lists `project-scaffold` where decision 20 lists `context-compaction`. `81a6` shipped decision 20's four. The example was not edited; it is noted here and in PR #84.

**Both design documents still say the runner only has Docker.** `ubuntu-24.04` ships Podman 5.8.4.

**`project-scaffold/testing/run-tests.sh` pins `python:3.12-slim` by tag, not by digest**, which is a root `CLAUDE.md` Rule 15 violation. It predates `81a6` and was left alone deliberately: repinning the image a suite runs on, in the same change that adds cases to that suite, mixes two failures that must stay distinguishable. On no ticket.

**`scaffold.sh:214` depends on `cmp`**, which Rule 17 says to check for. It is present in Git Bash so it is not a live break, but it is the same class of assumption the rule names, and `assert_same` was fixed for exactly this in `81a6` while the script beside it was not. On no ticket.

### Your scope

Four edits to one file, `claude/skills/project-scaffold/references/templates/CLAUDE.md.tmpl`, which the ticket's Scope block defines and this section does not restate.

Three things are worth knowing before you read it.

**The sync writes the skills table, not `scaffold.sh`.** The plan says so at E2.4 and says why: the design doc's body specifies the sync as the writer and its "Open" list carries a stale contradiction, and the body wins because the sync is the only actor that knows what actually landed. So your job is the `skills:begin` / `skills:end` markers and nothing between them. **Names only, never versions** - a hand-maintained version table is wrong within a week, and a stale one is worse than none because agents believe it.

**The two `work-order.sh close` references at `:207` and `:248` are in the file you are editing.** Fix them while you are there. They name a verb that does not exist.

**The documentation-lifetime rule is the one that arbitrates, and arbitration is the deliverable.** `local-k8s-docs` and `living-docs` both write into `<project>/docs/sops/`. The done-when is that the template names _one_ destination for a document and _one_ source for a workspace - not that it describes both and leaves the reader to choose.

**Non-goals.** Do not start `c6b0` in this branch. Do not touch `claude/skills/skill-versioning/` beyond what you must - the rename is `WO-20260824-238b` - `Rename skill-versioning to skill-registry, the closing commit` and it is last for a reason. Do not edit the four downstream repositories; that is `WO-20260824-6a33` - `Checklist for the four repositories carrying the stale session-start block`, and even that one only writes a checklist.

### Before you start

Nothing is reserved for you to decide. The branch question that opened the last session is settled and recorded: the note on `WO-20260824-00d5` dated 2026-08-30 explains why step 2 became two branches and why the graph now carries a `b21b` depends-on `81a6` edge. Read it rather than re-deriving it.

`work-order.sh start` needs a clean tree and creates the branch for you. It leaves the ticket file and `INDEX.md` uncommitted, so commit them before anything else.

### Read in this order

1. The ticket, and every note on it.
2. This entry, the top entry of `HYDRATION.md`. Read only this one.
3. The note on `WO-20260824-00d5` - `Skills package manager: roll it out across the repository` dated 2026-08-30 about the two-branch split, and the one dated 2026-08-30 that is the approved order.
4. `docs/superpowers/plans/2026-08-24-skills-package-manager-implementation.md` section E2.4, which is the four edits, and decision 19 above it for the treehouse pool.
5. `claude/skills/project-scaffold/references/templates/CLAUDE.md.tmpl` lines 269 to 336, the prose being replaced, before reading the replacement.
6. `claude/tools/skill-sync.sh`, `render_notice` and whatever writes between markers, before writing markers for it to fill.

### Reuse, it is proven

**The two-image suite split is built and documented.** `claude/skills/project-scaffold/testing/run-tests.sh` runs `cases/` and `cases-git/` under different images from one shared `INNER` body. `container-sandbox/references/skill-testing.md`, "The other answer: two stock images, one suite", carries the pattern and the four traps. If this ticket needs a git assertion, the directory already exists.

**Feeding a real template to the parser that reads it is the shape that caught the gap `81a6` could not see.** `claude/tools/testing/run-tests.sh`, section "the manifest project-scaffold ships", copies `skills.toml.tmpl` itself into a fixture project and runs `skill-sync --plan` over it. If you add markers to `CLAUDE.md.tmpl` that the sync is expected to fill, the assertion belongs there too, not in `project-scaffold`'s suite - the two files live in different skills and drift between them is silent.

**`slot.sh` is the acquire-and-release shape and is built for a second caller.** `claude/skills/hydration-prompt/scripts/slot.sh`, verbs `acquire --holder`, `release --holder`, `holder --holder`, `status`. Reach for it at `c6b0`, not here.

### The verification ladder

Rung 1: `bash .github/scripts/bump-gate.sh run-suite claude/skills/project-scaffold`. Never `bash <suite>` directly. It is at **176 + 9** across two images and prints both totals plus `all cases passed, both images`.

Rung 2: whichever suite owns the thing you changed the format of. A marker the sync fills is `claude/tools`, at **258**. A template a case reads is `project-scaffold`. If both, both.

Rung 3: `skill-version.sh verify --structure --base origin/main`. Green.

Rung 4: the gate on the pull request, with `Bump: project-scaffold=minor` or a `feat(` title.

Rung 5 is not needed. Do not run the nine suites for a change confined to one template.

### Traps, already paid for

**A markdown formatter rewrites `*emphasis*` into `_emphasis_` on lines you never touched.** It is a `PostToolUse` hook in the machine's global `~/.claude/settings.json`. Paid on `81a6`: three untouched lines in `skill-testing.md` were rewritten and had to be reverted with `perl -i -pe` after the last edit to that file, because a further edit would only re-trigger it. It also re-pads tables and rewrites a PR body file after `Write`. `git diff -U0 | grep '^-'` before committing and account for every deleted line, and check the `Bump:` trailer is still last with nothing after it.

**`rc=$?` on the line after a `podman run` never executes under `set -e`.** Paid on `81a6` while adding a second image: the failing run ends the script before the capture, so the second image never runs and the post-run guard is skipped. `|| rc=$?` on the run itself.

**`--entrypoint=""` is required for `bitnami/git`.** Its entrypoint is `git`, so a `bash -c` without it is handed to `git` as arguments and fails in a way that looks nothing like a test failure.

**`bitnami/git` ships no `cmp`**, and a missing `cmp` exits 127, which is indistinguishable from "the files differ". `assert_same` now hashes when `cmp` is absent.

**An assertion that greps a file for a word its own comments explain will fail on the explanation.** Paid on `81a6`: `assert_not_contains skills.toml "version"` failed on the header sentence saying why nothing pins a version. Strip comments first, then assert on the data.

**A digest you did not copy from a real registry does not exist.** `podman pull <tag>` then `podman image inspect --format '{{index .RepoDigests 0}}'`.

**A container check against "the branch" silently runs `main`'s code if you have not committed.** `git clone` carries commits, not a working tree.

**A suite with no self re-exec, run as `bash <suite>`, runs on the host and fails with `mkdir: cannot create directory '/work'`.** Use `bump-gate.sh run-suite`, which dispatches `self` or `wrapped` correctly.

**`grep -qxF "$ROW"` where `$ROW` starts with a dash is parsed as an option.** `grep -qxF -- "$ROW"`.

**A `grep -q` in a pipeline reports "no match" when it matched.** SIGPIPE plus `pipefail`. Capture to a variable and grep the variable with a herestring.

**`.claude/worktrees/smoke-tests` is a locked git worktree sitting untracked inside this repository.** It is not yours. `git add -A` at close-out is unsafe here - add explicit paths, which is what PR #76 through #84 all did. `gh pr create` warns `1 uncommitted change` because of it. Expected.

### Workflow

```bash
WO=claude/skills/work-order/scripts/work-order.sh
HP=claude/skills/hydration-prompt/scripts/hydration.sh

bash $WO show    --project . --id WO-20260824-b21b
bash $WO start   --project . --id WO-20260824-b21b   # run it alone, never in an && chain
git add work-orders && git commit -m "chore(work-orders): start WO-20260824-b21b"

# ... the work ...

bash .github/scripts/bump-gate.sh run-suite claude/skills/project-scaffold
bash .github/scripts/bump-gate.sh run-suite claude/tools     # if a marker the sync fills changed

bash $WO evidence --project . --id WO-20260824-b21b --index N --observed '...'
git add <explicit paths>            # NOT -A, see .claude/worktrees/smoke-tests above
git commit && git push -u origin <branch>
gh pr create --base main --title "feat(project-scaffold): ..." --body-file <file>
bash $WO submit  --project . --id WO-20260824-b21b --pr <N>
bash $WO done    --project . --id WO-20260824-b21b   # on the branch, before the merge
bash $HP check   --project . --body-file /tmp/entry.md
bash $HP add     --project . --id <next> --title "<next title>" --body-file /tmp/entry.md
git add <explicit paths> && git commit && git push   # rides the SAME pull request

# after the merge
bash $WO cleanup --project . --id WO-20260824-b21b
```

**This ticket changes `claude/skills/project-scaffold/`, so it needs a level.** A `feat(` title resolves it for a single-skill pull request, or state `Bump: project-scaffold=minor` as the last paragraph of the body with nothing after it. **Never run `skill-version.sh bump`.** The publisher allocates on `main`.

Step 3 of the approved order is `WO-20260824-c6b0` - `skill-onboard.sh brings an existing project onto the sync`, which is the largest ticket in the epic and the only one that touches other people's projects.

### Conventions

Every reference to a work-order in a chat reply carries the ticket ID and its full title joined by a dash. A bare ID is a defect, and so is "the next ticket" or "the blocked one".

Feature branches only. `skill-publish.yml` is the one named exception, and root `CLAUDE.md` says so.

<!-- hydration-entry: WO-20260824-81a6 -->
## WO-20260824-81a6 - project-scaffold plumbing: skills.toml, the gitignore blanket, scaffold.json removed, skill-update.sh narrowed
_Generated 2026-08-30 by hydration.sh. Newest entry._

### Ticket

`WO-20260824-81a6` - `project-scaffold plumbing: skills.toml, the gitignore blanket, scaffold.json removed, skill-update.sh narrowed`.
It is a child of `WO-20260824-00d5` - `Skills package manager: roll it out across the repository`.

The order for the whole epic was reviewed and approved on 2026-08-29 and is recorded as a note on `WO-20260824-00d5` itself, not only here. This ticket is **step 2 of 6**, and `WO-20260824-b21b` - `CLAUDE.md.tmpl: replace the session-start prose, add the skills markers, the treehouse policy and the documentation-lifetime rule` sits beside it in the same step. Do not re-derive the order; if you think it is wrong, say so and ask.

Read the ticket's own Scope block before deciding what any of the four sub-parts means. Four things were bundled into one ticket deliberately, and the bundling is the reason it is one step rather than four.

### What just landed

**PR #83, `WO-20260824-a6cb` - `The hydration-prompt close-out acquires and releases a treehouse slot`.** Step 1 of 6 is done, which is the first code in this epic.

`claude/skills/hydration-prompt/scripts/slot.sh` is new: `acquire`, `release`, `holder`, `status`. A session takes a treehouse workbench leased to its ticket ID and hands it back, and `slot.sh status` is the live map keyed by that ID.

**The whole point of the file is that it never reads `$?` to decide whether treehouse did anything.** `treehouse return` prompts on a dirty worktree, takes its no-TTY default, abandons the return, leaves the slot leased and exits 0. `release` throws that exit code away, asks the pool whether the ticket still holds anything, and reports that. Exit 5 with the slot named and the command that frees it.

Two probe findings changed the design and neither is visible from `--help`:

- **`treehouse get` does not refuse a holder that already holds a slot.** Two `get`s with one `--lease-holder` produce two slots recorded against the same holder. `acquire` grew the guard.
- **A freed slot inspected from inside its own directory reports its status as `you're here`, not `available`.** Checking the status field would have reported a leak on every clean close-out, because the close-out stands in the slot it just returned. The check keys on `lease_holder`, which is cleared to `""` on a successful return.

`claude/skills/hydration-prompt/testing/run-tests.sh` went **47 -> 86**. `testing/live-check.sh` is new at **19**, runs the real binary, and is not run by the gate.

`docs/worktree-workflow.md` now says the `hydration-prompt` half is built and describes what shipped.

Before that: epic 1 closed (PR #79), and PRs #80, #81 and #82 followed. `skill-versioning` is at 2.0.3 and its suite is at 148.

### What is NOT done

**Nothing in `project-scaffold` has been touched.** This ticket has not started. `claude/skills/project-scaffold/` is exactly as PR #82 left it.

`WO-20260824-c6b0` - `skill-onboard.sh brings an existing project onto the sync` is **startable again** now that `a6cb` is done, and `work-order next` will offer it. It is step 3, not step 2. Take `81a6` and `b21b` first: they set the written shape of `skills.toml` and the gitignore stanza on the greenfield path, and `c6b0` retrofits that shape onto projects that already exist. Retrofitting a shape nobody has written yet is the failure mode the order exists to prevent.

**`slot.sh` is written but nothing calls it yet.** The close-out documents it in `claude/skills/hydration-prompt/SKILL.md`; no script invokes it, and this session did not run its own close-out inside a slot. The first real caller is `c6b0`. That is by design and it is also the reason the interface, not just the mechanism, is the deliverable of `a6cb`.

**`hydration-prompt` ships executable code and has no `justfile`, which root `CLAUDE.md` Rule 17 requires.** So do 11 of the 13 skills with a `scripts/` directory; only `context-compaction` and `living-docs` have one. It is a real repo-wide gap, it is on no ticket, and `a6cb` did not fix it because it is not one skill's problem.

Branch protection is still absent and is still on no ticket.

**`work-order.sh approve` and `link` both strand themselves, and it is on no ticket.** Each writes the ticket file and `INDEX.md`; `start` refuses a dirty tree; `start` is what creates the branch. So a board edit made outside a branch has nowhere to be committed. A `start --on-current-branch` would remove it.

Root `CLAUDE.md`'s `## Consuming These Files` section still contradicts Rule 16 steps 7 and 8, and **it is still on no ticket** after seven cycles of being named here.

### Stale or false in the docs

**The dead `work-order.sh close` reference is now fixed in two of four places.** `claude/skills/hydration-prompt/SKILL.md` and `docs/worktree-workflow.md` both said `archive - work-order.sh close, straight to main`; both now say `cleanup`, and both state that the lifecycle ends at `done`, on the branch, inside the pull request. There is no `close` verb.

**It survives in two more.** `claude/skills/project-scaffold/references/templates/CLAUDE.md.tmpl:207` and `:248`, which is `WO-20260824-b21b` - `CLAUDE.md.tmpl: replace the session-start prose, add the skills markers, the treehouse policy and the documentation-lifetime rule`, the ticket beside this one. And `claude/skills/work-order/settings.local.json.tmpl:6`, which is on no ticket.

**Both design documents still say the runner only has Docker.** `ubuntu-24.04` ships Podman 5.8.4.

### Your scope

`project-scaffold` plumbing, in four parts that the ticket's Scope block defines and this section does not restate: `.claude/skills.toml`, the gitignore blanket, `scaffold.json` removed, `skill-update.sh` narrowed to the hand-authored path.

Two things are worth knowing before you read it.

**`skill-update.sh` narrowing is a header change, not a behaviour change.** Root `CLAUDE.md` Rule 16 already states the split: a skill the manifest declares is owned by `skill-sync`, and pointing `skill-update.sh` at one only produces a copy the next session start replaces. `--mode inline` and `--mode standalone` survive, for the hand-authored case only. The plan's done-when is that the header answers "should I be running this?" without reading the body.

**The gitignore blanket and `skills.toml` are the shape `WO-20260824-c6b0` - `skill-onboard.sh brings an existing project onto the sync` will retrofit.** Whatever you write here, that script writes into repositories that already exist. Write it once, here, deliberately.

**Non-goals.** Do not start `c6b0` in this branch even though it is now offered. Do not touch `claude/skills/skill-versioning/` - the rename is `WO-20260824-238b` - `Rename skill-versioning to skill-registry, the closing commit` and it is last for a reason. Do not edit the four downstream repositories; that is `WO-20260824-6a33` - `Checklist for the four repositories carrying the stale session-start block`, and even that one only writes a checklist.

### Before you start

**Decide whether you are taking `WO-20260824-b21b` - `CLAUDE.md.tmpl: replace the session-start prose, add the skills markers, the treehouse policy and the documentation-lifetime rule` in the same branch or a separate one.** The approved order puts it beside this ticket rather than after it, and both edit `claude/skills/project-scaffold/`. Two branches touching one skill directory means the second rebases; one branch means one version bump covering both. Ask the user rather than choosing.

Everything else is settled. `work-order.sh start` needs a clean tree and creates the branch for you. It leaves the ticket file and `INDEX.md` uncommitted, so commit them before anything else.

### Read in this order

1. The ticket, and every note on it.
2. This entry, the top entry of `HYDRATION.md`. Read only this one.
3. The note on `WO-20260824-00d5` - `Skills package manager: roll it out across the repository` dated 2026-08-30, which is the approved order and the reasoning behind it.
4. `docs/superpowers/plans/2026-08-24-skills-package-manager-implementation.md`, sections E2.2, E2.3, E2.4 and E2.9, which are the four parts this ticket bundles.
5. `claude/tools/skill-sync.sh` for what actually reads `skills.toml`, before writing the format it reads.
6. Root `CLAUDE.md` Rule 16, once, for the split between `skill-sync` and `skill-update.sh`.

### Reuse, it is proven

**`slot.sh` is the acquire-and-release shape, and it is built for a second caller.** `claude/skills/hydration-prompt/scripts/slot.sh`, verbs `acquire --holder`, `release --holder`, `holder --holder`, `status`. Its header names `skill-onboard.sh` explicitly. When you reach `c6b0`, call it with `--holder skill-onboard` rather than writing a second copy - and if it turns out not to fit, say so loudly, because that is the whole justification for the dependency edge added on 2026-08-29.

**The two-suite split earned itself and is the model for anything that wraps a host CLI.** `run-tests.sh` stubs the tool and is the only way to script both a success that did nothing and a failure that did the work; `live-check.sh` runs the real binary and is the only way to prove the stub still describes reality. `container-sandbox/references/skill-testing.md` "Verifying against live infrastructure" is the pattern, and `hydration-prompt/testing/` is now a second worked example beside `workflows/credential-rotation/testing/`.

`claude/tools/testing/run-tests.sh` is at 193 and already drives `skill-sync` end to end against a real manifest. It is where a `skills.toml` format change gets proved, not in `project-scaffold`'s suite.

### The verification ladder

Rung 1: `bash .github/scripts/bump-gate.sh run-suite claude/skills/project-scaffold`. Never `bash <suite>` directly.

Rung 2: `bash .github/scripts/bump-gate.sh run-suite claude/tools` - it is at **193** and it is the suite that actually reads `skills.toml`. A format change that passes `project-scaffold`'s suite and not this one has not been tested.

Rung 3: scaffold a throwaway project in a container and assert the gitignore blanket covers what it claims. Assert the positive and the negative on the same tree in the same run: a managed skill ignored, and a hand-authored one beside it still tracked.

Rung 4: `skill-version.sh verify --structure --base origin/main`. Green.

Rung 5: the gate on the pull request, with `Bump: project-scaffold=minor` or a `feat(` title. Add a second `Bump:` line if `b21b` rides the same branch.

Rung 6 is not needed. Do not run the nine suites for a change confined to one skill and `claude/tools`.

### Traps, already paid for

**A digest you did not copy from a real registry does not exist.** Paid again on `a6cb`: an invented `shellcheck-alpine` digest failed with `manifest unknown`, which reads like a network problem and is not. `podman pull <tag>` then `podman image inspect --format '{{index .RepoDigests 0}}'`.

**A stub that applies its scripted exit code to every subcommand tests nothing.** On `a6cb` the treehouse stub let `TH_RC` reach its `status` subcommand as well as `get` and `return`, so every case scripting a non-zero return failed as an unreadable pool rather than proving the exit code was ignored. A stub's failure injection has to be scoped to the call under test.

**`grep -qxF "$ROW"` where `$ROW` starts with a dash is parsed as an option.** `grep -qxF -- "$ROW"`.

**`PATH=/nonexistent bash script.sh` exits 127 because the shell cannot be found, not because the script reported anything.** To test a missing tool, remove that tool's directory from `PATH` rather than emptying it.

**A container check against "the branch" silently runs `main`'s code if you have not committed.** `git clone` carries commits, not a working tree. Commit first, then clone, and print the clone's HEAD subject.

**A markdown formatter re-pads tables in a file you only meant to add a line to.** It is a `PostToolUse` hook in the machine's global `~/.claude/settings.json`. `git diff -U0 | grep '^-'` before committing and account for every deleted line. It also rewrites a PR body file after `Write`, so check the `Bump:` trailer is still last with nothing after it.

**A suite with no self re-exec, run as `bash <suite>`, runs on the host and fails with `mkdir: cannot create directory '/work'`.** Use `bump-gate.sh run-suite`, which dispatches `self` or `wrapped` correctly. A wrapped suite that gains a non-comment line mentioning `podman` silently flips to `self` and breaks.

**A `grep -q` in a pipeline reports "no match" when it matched.** SIGPIPE plus `pipefail`. Capture to a variable and grep the variable with a herestring.

**`.claude/worktrees/smoke-tests` is a locked git worktree sitting untracked inside this repository.** It is not yours. `git add -A` at close-out is unsafe here - add explicit paths, which is what PR #76 through #83 all did. `gh pr create` warns `1 uncommitted change` because of it. Expected.

### Workflow

```bash
WO=claude/skills/work-order/scripts/work-order.sh
HP=claude/skills/hydration-prompt/scripts/hydration.sh

bash $WO show    --project . --id WO-20260824-81a6
bash $WO start   --project . --id WO-20260824-81a6   # run it alone, never in an && chain
git add work-orders && git commit -m "chore(work-orders): start WO-20260824-81a6"

# ... the work ...

bash .github/scripts/bump-gate.sh run-suite claude/skills/project-scaffold
bash .github/scripts/bump-gate.sh run-suite claude/tools

bash $WO evidence --project . --id WO-20260824-81a6 --index N --observed '...'
git add <explicit paths>            # NOT -A, see .claude/worktrees/smoke-tests above
git commit && git push -u origin <branch>
gh pr create --base main --title "feat(project-scaffold): ..." --body-file <file>
bash $WO submit  --project . --id WO-20260824-81a6 --pr <N>
bash $WO done    --project . --id WO-20260824-81a6   # on the branch, before the merge
bash $HP check   --project . --body-file /tmp/entry.md
bash $HP add     --project . --id <next> --title "<next title>" --body-file /tmp/entry.md
git add <explicit paths> && git commit && git push   # rides the SAME pull request

# after the merge
bash $WO cleanup --project . --id WO-20260824-81a6
```

**This ticket changes `claude/skills/project-scaffold/`, so it needs a level.** A `feat(` title resolves it for a single-skill pull request, or state `Bump: project-scaffold=minor` as the last paragraph of the body with nothing after it. **Never run `skill-version.sh bump`.** The publisher allocates on `main`.

Step 3 of the approved order is `WO-20260824-c6b0` - `skill-onboard.sh brings an existing project onto the sync`, which is the largest ticket in the epic and the only one that touches other people's projects.

### Conventions

Every reference to a work-order in a chat reply carries the ticket ID and its full title joined by a dash. A bare ID is a defect, and so is "the next ticket" or "the blocked one".

Feature branches only. `skill-publish.yml` is the one named exception, and root `CLAUDE.md` says so.

<!-- hydration-entry: WO-20260824-a6cb -->
## WO-20260824-a6cb - The hydration-prompt close-out acquires and releases a treehouse slot
_Generated 2026-08-30 by hydration.sh. Newest entry._

### Ticket

`WO-20260824-a6cb` - `The hydration-prompt close-out acquires and releases a treehouse slot`.
It is a `feature`, `p2`, a child of `WO-20260824-00d5` - `Skills package manager: roll it out across the repository`.
It has **no dependencies at all** - the only ticket in the epic that does not - and it blocks two: `WO-20260824-238b` - `Rename skill-versioning to skill-registry, the closing commit`, and now `WO-20260824-c6b0` - `skill-onboard.sh brings an existing project onto the sync`.

The order for the whole epic was reviewed and approved on 2026-08-29 and is recorded as a note on `WO-20260824-00d5` itself, not only here. This ticket is step 1 of 6. Do not re-derive the order; if you think it is wrong, say so and ask.

### What just landed

**A dependency edge and two notes. No code.**

`WO-20260824-c6b0` - `skill-onboard.sh brings an existing project onto the sync` now depends on this ticket. That edge did not exist when either was cut, and its absence was letting `work-order next` offer `c6b0` - the largest ticket in the epic and the only one that touches other people's projects - before the mechanism it is built on had been proved.

The reason was already written in both tickets and joined up nowhere. `c6b0` says its script "has to work without ever touching the user's working tree, which means a treehouse slot, and the gate finding proved it must assert the slot went free rather than trusting an exit code". This ticket says "the gate finding makes the release the load-bearing half: a dirty tree makes treehouse return prompt, take the no-TTY default, abort, leave the slot leased and exit 0". Same finding, same failure mode, and `git grep` over `work-orders/` puts that language on those two tickets and no others.

`work-order next` went from six startable to five. `WO-20260824-c6b0` reappears when this ticket is `done`.

Before that, in the three sessions this window covers: epic 1 closed (PR #79) after `WO-20260825-dac4` - `verify --structure refuses a brand new skill, whichever way it is written` (PR #78), and the two defects that ticket surfaced were fixed in PR #80 and PR #81. `skill-versioning` is at 2.0.3 and its suite is at **148**.

### What is NOT done

**Nothing in this epic has started.** All eight children are `ready`; five are startable.

An earlier draft of the approved order put `WO-20260824-d058` - `Remove the inline read-only notice from the other 42 SKILL.md files` first, on the theory that onboarding a project before it would install the notice twice. **That is false and the note on the epic says so.** `render_notice` in `claude/tools/skill-sync.sh:574` strips an existing inline notice before inserting the rendered one, and the comment above it says it was written for exactly this transition window. `d058` is the largest mechanical change in the epic, which is not the same as the first.

Branch protection is still absent and is still on no ticket.

**`work-order.sh approve` and `link` both strand themselves, and it is on no ticket.** Each writes the ticket file and `INDEX.md`; `start` refuses a dirty tree; `start` is what creates the branch. So any board edit made outside a branch has nowhere to be committed. Worked around on PR #81 by committing on local `main`, letting `start` branch from it, then `git branch -f main origin/main`. Handled here by giving the edge its own branch. A `start --on-current-branch` would remove it.

Root `CLAUDE.md`'s `## Consuming These Files` section still contradicts Rule 16 steps 7 and 8, and **it is still on no ticket** after six cycles of being named here.

### Stale or false in the docs

**`claude/skills/hydration-prompt/SKILL.md:38` still puts `archive - work-order.sh close, straight to main` under `AFTER THE MERGE`.**
There is no `close` verb. The lifecycle ends at `done`, on the branch, inside the PR. Do not follow the diagram - and note that this ticket edits that skill, so you will be looking straight at it.

The same dead reference lives at `claude/skills/project-scaffold/references/templates/CLAUDE.md.tmpl:207` and `:248`, which is `WO-20260824-b21b` - `CLAUDE.md.tmpl: replace the session-start prose, add the skills markers, the treehouse policy and the documentation-lifetime rule`, and at `claude/skills/work-order/settings.local.json.tmpl:6`, which is on no ticket.

**Both design documents still say the runner only has Docker.** `ubuntu-24.04` ships Podman 5.8.4.

### Your scope

The `hydration-prompt` close-out acquires a treehouse slot keyed by ticket ID, and releases it.

**The release is the load-bearing half and the ticket says why.** The failure it exists to prevent is not "the slot was never taken" but "the slot was taken and never given back, and the exit code said everything was fine": a dirty tree makes `treehouse` prompt, the prompt takes its no-TTY default, the run aborts, the lease survives and the process exits 0. So the assertion is that the slot went free, observed directly, never inferred from an exit code.

Read the ticket's own Scope block before deciding what "acquire" means here - `treehouse` is referenced in `docs/worktree-workflow.md`, `claude/skills/container-sandbox/SKILL.md` and both design documents, and those are the definition of the mechanism.

**Non-goals.** Do not start a second ticket in this branch. Do not touch `claude/skills/skill-versioning/` - the rename is `WO-20260824-238b` - `Rename skill-versioning to skill-registry, the closing commit` and it is last for a reason. Do not edit the four downstream repositories; that is `WO-20260824-6a33` - `Checklist for the four repositories carrying the stale session-start block`, and even that one only writes a checklist.

### Before you start

`work-order.sh start` needs a clean tree and creates `feat/the-hydration-prompt-close-out-acquires-and-rele` for you. It leaves the ticket file and `INDEX.md` uncommitted, so commit them before anything else. This ticket is already approved; do not run `approve`.

**Run lifecycle verbs one at a time.** `approve && start && git commit` put a commit on local `main` on 2026-08-29: `start` refused the tree `approve` had just dirtied, `&&` skipped it, and the trailing commit ran on whatever branch was current.

**`.claude/worktrees/smoke-tests` is a locked git worktree sitting untracked inside this repository**, left by a session before epic 1. It is not yours. `git add -A` at close-out is unsafe here - add explicit paths, which is what PR #76 through #82 all did.

### Read in this order

1. The ticket, and every note on it.
2. This entry, the top entry of `HYDRATION.md`. Read only this one.
3. The note on `WO-20260824-00d5` - `Skills package manager: roll it out across the repository` dated 2026-08-29, which is the approved order and the reasoning behind it.
4. `docs/worktree-workflow.md` for what a treehouse slot is, then `claude/skills/container-sandbox/SKILL.md` for how a session is expected to hold one.
5. `claude/skills/hydration-prompt/SKILL.md`, the close-out it changes - remembering `:38` is wrong.
6. `workflows/close-out-procedure.md`, once.

### Reuse, it is proven

`WO-20260824-c6b0` - `skill-onboard.sh brings an existing project onto the sync` will inherit whatever acquire-and-release shape this ticket lands on. Build it so a second caller can use it, and name that caller in the code, because the edge between the two is now recorded but the interface is not.

`claude/skills/hydration-prompt/testing/run-tests.sh` is at 47 checks and already drives the close-out end to end. Its window-boundary and duplicated-section cases are the model for asserting a state rather than an exit code - which is exactly what the release half needs.

`container-sandbox/references/skill-testing.md` covers three shapes: the bundled-script case, the live-infrastructure split, and `Driving a repository-level gate against the real tree`. A slot that must be observed going free is closest to the second: the offline suite proves the logic, and something has to prove the real `treehouse` was actually asked.

### The verification ladder

Rung 1: `bash .github/scripts/bump-gate.sh run-suite claude/skills/hydration-prompt`. It is at **47** and your cases move it. Never `bash <suite>` directly.

Rung 2: the release, asserted as a state. Acquire a slot, force the dirty-tree abort, then read `treehouse status` and assert the slot is free. An exit code of 0 is the symptom this ticket exists to disbelieve, so a check that reads one has not checked anything.

Rung 3: the acquire under contention - a slot already held is refused rather than double-leased.

Rung 4: `skill-version.sh verify --structure --base origin/main`. Green.

Rung 5: the gate on the pull request, with `Bump: hydration-prompt=minor` or a `feat(` title. It is a new capability on the close-out.

Rung 6 is not needed. Do not run the nine suites for a single-skill change; they were green on PR #81 at 251, 299, 161, 145, **148**, 85, 47, 41 and 39.

### Traps, already paid for

**A container check against "the branch" silently runs `main`'s code if you have not committed.** `git clone` carries commits, not a working tree. Twice on PR #81 a before-and-after comparison showed no difference because both sides were the same committed script. Commit first, then clone, and print the clone's HEAD subject so the run says which code it measured.

**A markdown formatter re-pads tables in a file you only meant to add a line to.** It is a `PostToolUse` hook in the machine's global `~/.claude/settings.json`. `git diff -U0 | grep '^-'` before committing and account for every deleted line.

**A suite with no self re-exec, run as `bash <suite>`, runs on the host and fails with `mkdir: cannot create directory '/work'`.** Use `bump-gate.sh run-suite`, which dispatches `self` or `wrapped` correctly.

**A `grep -q` in a pipeline reports "no match" when it matched.** It closes the pipe on the first hit, the upstream dies of SIGPIPE, and `pipefail` turns that into a non-zero pipeline. Capture to a variable and grep the variable with a herestring.

**Scoping a report can silence it.** PR #80 stopped two false lines and, in the same move, stopped a true one nobody had asked about; PR #81 was the ticket for that. Assert the positive and the negative on the same tree in the same run.

**A digest you did not copy from a real registry does not exist.** `podman pull` fails with `manifest unknown`, which reads like a network problem and is not.

`gh pr create` warns `1 uncommitted change` because of the untracked `.claude/worktrees/`. Expected, not your branch.

### Workflow

```bash
WO=claude/skills/work-order/scripts/work-order.sh
HP=claude/skills/hydration-prompt/scripts/hydration.sh

bash $WO show    --project . --id WO-20260824-a6cb
bash $WO start   --project . --id WO-20260824-a6cb   # run it alone, never in an && chain
git add work-orders && git commit -m "chore(work-orders): start WO-20260824-a6cb"

# ... the work ...

bash .github/scripts/bump-gate.sh run-suite claude/skills/hydration-prompt

bash $WO evidence --project . --id WO-20260824-a6cb --index N --observed '...'
git add <explicit paths>            # NOT -A, see .claude/worktrees/smoke-tests above
git commit && git push -u origin feat/the-hydration-prompt-close-out-acquires-and-rele
gh pr create --base main --title "feat(hydration-prompt): ..." --body-file <file>
bash $WO submit  --project . --id WO-20260824-a6cb --pr <N>
bash $WO done    --project . --id WO-20260824-a6cb   # on the branch, before the merge
bash $HP check   --project . --body-file /tmp/entry.md
bash $HP add     --project . --id WO-20260824-81a6 --title "project-scaffold plumbing: skills.toml, the gitignore blanket, scaffold.json removed, skill-update.sh narrowed" --body-file /tmp/entry.md
git add <explicit paths> && git commit && git push   # rides the SAME pull request

# after the merge
bash $WO cleanup --project . --id WO-20260824-a6cb
```

**This ticket changes `claude/skills/hydration-prompt/`, so it needs a level.** A `feat(` title resolves it for a single-skill pull request, or state `Bump: hydration-prompt=minor` as the last paragraph of the body with nothing after it. **Never run `skill-version.sh bump`.** The publisher allocates on `main`.

Step 2 of the approved order is `WO-20260824-81a6` - `project-scaffold plumbing: skills.toml, the gitignore blanket, scaffold.json removed, skill-update.sh narrowed`, with `WO-20260824-b21b` - `CLAUDE.md.tmpl: replace the session-start prose, add the skills markers, the treehouse policy and the documentation-lifetime rule` beside it.

### Conventions

Every reference to a work-order in a chat reply carries the ticket ID and its full title joined by a dash. A bare ID is a defect, and so is "the next ticket" or "the blocked one".

Feature branches only. `skill-publish.yml` is the one named exception, and root `CLAUDE.md` says so.

PR bodies carry no agent attribution, Rule 13.

No em dashes. Plain dashes only, in every file and every reply.

<!-- hydration-entry: none -->
## Epic 1 is closed and its two follow-up defects are fixed - pick from the rollout epic
_Generated 2026-08-29 by hydration.sh. Newest entry._

### Ticket

Nothing is assigned. Pick from `work-order next`, which returns eight, all `p2`, all `ready`:

`WO-20260824-00d5` - `Skills package manager: roll it out across the repository` and its seven startable children - `WO-20260824-81a6` - `project-scaffold plumbing: skills.toml, the gitignore blanket, scaffold.json removed, skill-update.sh narrowed`, `WO-20260824-a6cb` - `The hydration-prompt close-out acquires and releases a treehouse slot`, `WO-20260824-b21b` - `CLAUDE.md.tmpl: replace the session-start prose, add the skills markers, the treehouse policy and the documentation-lifetime rule`, `WO-20260824-c6b0` - `skill-onboard.sh brings an existing project onto the sync`, `WO-20260824-d058` - `Remove the inline read-only notice from the other 42 SKILL.md files`, `WO-20260824-6a33` - `Checklist for the four repositories carrying the stale session-start check`, and `WO-20260824-79b6` - `Invert the notice assertion: verify --structure now fails on an inline notice`.

The eighth child, `WO-20260824-238b` - `Rename skill-versioning to skill-registry, the closing commit`, is the epic's closing commit and waits on the other seven.

The board is otherwise empty. Nothing is in `draft`, nothing is `in-progress`, and no ticket is blocked on anything outside that epic.

**Ask the user which one, rather than choosing.** They are all p2 and the ordering between them is a judgement about what the repository needs next, not something `next` can answer.

### What just landed

Four pull requests, and epic 1 is closed.

PR #78 - `WO-20260825-dac4` - `verify --structure refuses a brand new skill, whichever way it is written`. `registry_has` in `claude/skills/skill-versioning/scripts/skill-version.sh`, and absence from `registry.json` is the test for "this skill is new". Two call sites, both gated on `--structure`: the version loop stops calling an unregistered skill `unversioned`, and `diff_check` stops reading its `version:` line as a hand-edit. A `SKILL.md` gone from the tree is exempt too, which is the deletion half of a rename. All three criteria observed on the real gate: runs 33203202657, 33203318713, 33203392408.

PR #79 - `WO-20260824-f1a5` - `Skills package manager: prove the path on one skill` is `done` and archived after all fourteen children shipped. Its own three criteria were discharged explicitly, each naming the child that proved it, and `AC-H3` was re-observed fresh rather than quoted.

PR #80 - `WO-20260829-5ad4` - `verify's drift report walks the registry's tools block and names tools as missing skills`. `skills_block` scopes both reporting loops, so a failing `verify` stopped printing `stale entry       skill-sync (no such skill)`.

PR #81 - `WO-20260829-f97b` - `verify names nothing when only a tool has drifted`. The regression #80 shipped knowingly and cut a ticket for. The tools block now has its own pair of loops and its own three lines - `tool drifted`, `tool unregistered`, `tool gone` - and the trailer is one per kind, printed only for a kind that was named. `bump` is never suggested for a tool, because a tool has no frontmatter and its version is the `skill-tool-version:` marker in the file.

`skill-versioning`'s suite went 103 -> 120 -> 131 -> **148**. `container-sandbox/references/skill-testing.md` gained `Driving a repository-level gate against the real tree`.

The publisher allocated `skill-versioning` 2.0.1 then 2.0.2, and `container-sandbox` 1.4.0. Nobody typed any of them.

### What is NOT done

**Nothing from epic 2 has started.** All eight children of `WO-20260824-00d5` - `Skills package manager: roll it out across the repository` are `ready` and untouched.

Branch protection is still absent and is still on no ticket.

**`work-order.sh approve` strands its own approval, and it is on no ticket.** `approve` writes the ticket file and `INDEX.md`; `start` refuses a dirty tree; `start` is what creates the branch. So a ticket created and left in `draft` in an earlier pull request has nowhere to commit its approval. The normal path hides this because `new` and `approve` ride the previous ticket's close-out. Worked around on PR #81 by committing the approval on local `main`, letting `start` branch from it, then `git branch -f main origin/main` - nothing was pushed to `main`. Recorded as a note on `WO-20260829-f97b`. A `start --on-current-branch`, or an `approve` that leaves nothing to commit, would remove it.

Root `CLAUDE.md`'s `## Consuming These Files` section still contradicts Rule 16 steps 7 and 8, and **it is still on no ticket** after five cycles of being named here. It tells a consumer to clone or symlink `claude/skills/` via `setup.sh` and never mentions `.claude/skills.toml` or `skill-sync.sh`. It either wants a ticket or it wants a decision that it stays wrong; carrying it forward a sixth time is not either.

### Stale or false in the docs

**`claude/skills/hydration-prompt/SKILL.md:38` still puts `archive - work-order.sh close, straight to main` under `AFTER THE MERGE`.**
There is no `close` verb. The lifecycle ends at `done`, on the branch, inside the PR. Do not follow the diagram.

The same dead reference lives at `claude/skills/project-scaffold/references/templates/CLAUDE.md.tmpl:207` and `:248`, which is `WO-20260824-b21b` - `CLAUDE.md.tmpl: replace the session-start prose, add the skills markers, the treehouse policy and the documentation-lifetime rule`, and at `claude/skills/work-order/settings.local.json.tmpl:6`, which is on no ticket.

**Both design documents still say the runner only has Docker.** `ubuntu-24.04` ships Podman 5.8.4.

`claude/skills/skill-versioning/SKILL.md` is accurate about both forms of `verify` and about the drift report's two vocabularies. Root `CLAUDE.md` Rule 16 is accurate.

### Your scope

Whichever ticket the user names, and nothing beside it.

If it is `WO-20260824-d058` - `Remove the inline read-only notice from the other 42 SKILL.md files`, it and `WO-20260824-79b6` - `Invert the notice assertion: verify --structure now fails on an inline notice` are two halves of one change and the order matters: inverting the assertion first turns 42 files red at once.

If it is `WO-20260824-238b` - `Rename skill-versioning to skill-registry, the closing commit`, the gate is ready for it - PR #78 proved a renamed directory green both when git pairs the two paths and when it cannot - but the other seven come first, and the rename also moves paths that `.github/workflows/skill-pr-gate.yml` and `bump-gate.sh run-suite` name literally.

**Non-goal for every one of them: do not start a second ticket in the same branch.** Epic 2 is eight tickets, not one.

### Before you start

`work-order.sh start` needs a clean tree and creates the branch for you. It leaves the ticket file and `INDEX.md` uncommitted, so commit them before anything else. Every ticket on the board is already approved; do not run `approve` again.

**`.claude/worktrees/smoke-tests` is a locked git worktree sitting untracked inside this repository**, left by a session before epic 1. It is not yours. It means `git add -A` at close-out is unsafe here - add explicit paths instead, which is what PR #76 through #81 all did.

### Read in this order

1. `work-order.sh next`, then the ticket the user names, and every note on it.
2. This entry, the top entry of `HYDRATION.md`. Read only this one.
3. `work-orders/WO-20260824-00d5/` - the epic README, for how its eight children fit together.
4. Root `CLAUDE.md` Rule 16 and `## Close-out and post-merge cleanup`. Both accurate.
5. `workflows/close-out-procedure.md`, once.

### Reuse, it is proven

`skills_block` and `tools_block` in `skill-version.sh`, and `registry_version` in `bump-lib.sh`, are one idiom in three places and between them the only correct way to read a name out of `registry.json`. Anything new that reads that file goes through one of them rather than grepping the whole thing, because the two blocks share an indent and a whole-file reader cannot tell them apart.

`bump-gate.sh detect` answers "which suites must run"; `resolve` answers "what level does each changed skill get". They disagree by design for a skill that ships no suite. Do not reconcile them.

`container-sandbox/references/skill-testing.md` now covers three shapes: the bundled-script case, the live-infrastructure split, and `Driving a repository-level gate against the real tree` - clone inside the container from a read-only `/repo` mount so `origin/main` resolves. If a check needs a container and the pattern is not documented, write the section rather than falling back to the host.

Section 6b of `claude/skills/skill-versioning/testing/run-tests.sh` builds a fixture tool with a `skill-tool-version:` marker and drives a populated tools block, an empty one, a vanished one and an unregistered one. Any assertion about the tools block wants that fixture.

### The verification ladder

Rung 1: the changed skill's own suite, via `bash .github/scripts/bump-gate.sh run-suite claude/skills/<name>`. Never `bash <suite>` directly.

Rung 2: `skill-version.sh verify --structure --base origin/main` on the branch. Green.

Rung 3: for anything touching the registry or its readers, plain `verify` on a clone of `main` in a container. Green, `ok - 43 skills versioned, registry in sync`.

Rung 4: the nine suites, at 251, 299, 161, 145, **148**, 85, 47, 41 and 39. Only run all nine when the change reaches beyond one skill.

Rung 5: the gate on the pull request. It is the only place the gate exists, so a green local `--structure` is not the same claim.

### Traps, already paid for

**Chaining `approve && start && git commit` puts a commit on `main`.** `start` fails on the tree `approve` just dirtied, `&&` skips it, and the `git commit` at the end runs anyway - on whatever branch you were on. Caught and rewound on PR #81 before anything was pushed. Run lifecycle verbs one at a time and read each result.

**A container check against "the branch" silently runs `main`'s code if you have not committed.** `git clone` carries commits, not a working tree. Twice on PR #81 a before-and-after comparison showed no difference because both sides were the same committed script. Commit first, then clone, and print the clone's HEAD subject so the run says which code it measured.

**`git checkout origin/main -- claude/skills` clobbers the script under test** when the script lives under `claude/skills/`. Copy it out to the scratch mount first.

**A markdown formatter re-pads tables in a file you only meant to add a line to.** It is a `PostToolUse` hook in the machine's global `~/.claude/settings.json`. `git diff -U0 | grep '^-'` before committing and account for every deleted line.

**A suite with no self re-exec, run as `bash <suite>`, runs on the host and fails with `mkdir: cannot create directory '/work'`.** Use `bump-gate.sh run-suite`, which dispatches `self` or `wrapped` correctly.

**A `grep -q` in a pipeline reports "no match" when it matched.** It closes the pipe on the first hit, the upstream dies of SIGPIPE, and `pipefail` turns that into a non-zero pipeline. Capture to a variable and grep the variable with a herestring.

**Scoping a report can silence it.** PR #80 stopped two false lines and, in the same move, stopped a true one nobody had asked about; PR #81 was the ticket for that. Assert the positive and the negative on the same tree in the same run.

**A digest you did not copy from a real registry does not exist.** `podman pull` fails with `manifest unknown`, which reads like a network problem and is not.

`gh pr create` warns `1 uncommitted change` because of the untracked `.claude/worktrees/`. Expected, not your branch.

### Workflow

```bash
WO=claude/skills/work-order/scripts/work-order.sh
HP=claude/skills/hydration-prompt/scripts/hydration.sh

bash $WO next    --project .
bash $WO show    --project . --id <the one the user named>
bash $WO start   --project . --id <id>              # run it alone, never in an && chain
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

Every reference to a work-order in a chat reply carries the ticket ID and its full title joined by a dash. A bare ID is a defect, and so is "the next ticket" or "the blocked one".

Feature branches only. `skill-publish.yml` is the one named exception, and root `CLAUDE.md` says so.

PR bodies carry no agent attribution, Rule 13.

No em dashes. Plain dashes only, in every file and every reply.

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

