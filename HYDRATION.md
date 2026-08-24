# HYDRATION.md

The prompt that starts the next session, and the 10 before it.

**Read the top entry only.** It is the current one and it is complete on its own.
Everything below it has been superseded and is kept for history, not for reading.

**Newest on top.** Adding an entry removes the oldest in the same commit, so this
file holds exactly 10 once it has filled up. Entries are never renumbered and
never edited in place - a correction is a new entry.

Written by `hydration.sh add`. Do not hand-edit.
<!-- hydration-entry: WO-20260824-0615 -->
## WO-20260824-0615 - Confirm whether a SessionStart hook matcher filters by source
_Generated 2026-08-24 by hydration.sh. Newest entry._

### Ticket

`WO-20260824-0615` - `Confirm whether a SessionStart hook matcher filters by source`. Position 2 of 21 children across two epics.
Predecessor `WO-20260824-cc71` - `Repo settings: squash-only, with the commit body taken from the PR description`, merged, closed and archived.

This is a spike, not a build. Its whole output is a written answer to one question, and the answer changes what two later tickets are allowed to do.

### What just landed

Four repository settings on `jkkelley/dotfiles`, and no code.

```
squash_merge_commit_title:   COMMIT_OR_PR_TITLE -> PR_TITLE
squash_merge_commit_message: COMMIT_MESSAGES    -> PR_BODY
allow_merge_commit:          true               -> false
allow_rebase_merge:          true               -> false
```

Squash is now the only path into `main` for every pull request in this repository, and the squash commit body is the pull request description verbatim.

The proof that matters is not the read-back. Throwaway PR #56 carried `Bump: nothing=patch` in its description and deliberately carried no trailer in its branch commit message.
After the squash merge, `git log -1 --format=%B origin/main | git interpret-trailers --parse` printed exactly `Bump: nothing=patch`, at merge sha `d7f2f8c44ac2b010bed5cf09e43db20b636d5b64`.
The trailer had nowhere else to come from, so `PR_BODY` is confirmed to carry it through the real merge path rather than merely to have been accepted by the API.

The probe's scaffolding is gone. Branch `chore/trailer-probe` is deleted locally and on the remote, and `notes/trailer-probe.md` was removed in this ticket's own pull request, so `main` carries none of it.

The repository files that changed are the ticket file, `work-orders/INDEX.md`, the epic README, and `HYDRATION.md`. Nothing executable was written.

### What is NOT done

Nothing has been built in either epic. Twenty of the twenty-one tickets have never been started and none of them has a branch.

Each of these is a command whose output proves the claim, measured on `main` after this ticket merged:

- `ls claude/tools` fails. No `skill-sync.sh`, no `skill-onboard.sh`, no notice partial, no tools test suite.
- `git ls-files .github/workflows` prints nothing. There is no PR gate and no publisher, so nothing yet reads the trailer this ticket just made possible.
- `head -c 40 claude/skills/registry.json` shows `"schema": 1`. Schema 2 is unwritten.
- `grep -l "This copy is read-only" claude/skills/*/SKILL.md | wc -l` prints `43`. Every skill still carries the inline notice.

Deliberately out of scope on `WO-20260824-cc71` - `Repo settings: squash-only, with the commit body taken from the PR description`, and still absent: branch protection rules, and required status checks.
Status checks arrive with `WO-20260824-2ad1` - `PR gate workflow: validate the bump intent and run the affected suites`, which is blocked behind four other tickets. Branch protection is not on any ticket at all and is a decision the user has not been asked for.

Nothing was carried off this ticket onto another one. Both acceptance criteria were met and evidenced separately.

### Stale or false in the docs

`docs/superpowers/plans/2026-08-24-skills-package-manager-implementation.md` section `C2` states the live values as `squash_merge_commit_message=COMMIT_MESSAGES`, `allow_merge_commit=true`, `allow_rebase_merge=true`.
Those were true on 2026-08-24 when the plan was written and are false now. `WO-20260824-cc71` - `Repo settings: squash-only, with the commit body taken from the PR description` changed all three. The constraint C2 describes is satisfied, not pending.

`docs/superpowers/specs/2026-08-23-skills-package-manager-design.md` section `Repo settings, first` carries the same snapshot under the heading "Checked on 2026-08-24, and one of them would have killed this silently". Same correction. The `gh api -X PATCH` block immediately below it has been run, and does not need running again.

Neither of those is worth a fix-up commit on its own. They are historical statements about a moment, they are labelled with the date they were checked, and the tickets that touch those documents can correct them in passing.

Root `CLAUDE.md` Rule 16 still requires a PR touching a skill to bump the version and ship a regenerated `registry.json` by hand. That is still true today and must still be obeyed today.
It becomes false at `WO-20260824-8cd1` - `Rewrite root CLAUDE.md for merge-time allocation and the named main exception`, and not before. The new settings do not change it. A `Bump:` trailer reaching `main` does nothing at all until a publisher exists to read it.

This repository has no `CONTEXT_STATE.md`. Several skills assume one and the `hydration-prompt` skill's flow references one. It genuinely does not exist here. Do not create one as a side effect of this ticket.

### Your scope

One question, answered by watching real sessions, and the answer written into the ticket.

Does a `SessionStart` hook with `"matcher": "startup"` fire only on a startup, or does it fire on every source regardless of what the matcher says?

Build a scratch project outside this repository. Install a `SessionStart` hook whose matcher is the literal string `startup` and whose command appends its full stdin payload and a timestamp to a file. Then produce all four session events against that project: a fresh start, a resume, a clear, and a forced compact. Record which of the four caused the hook to fire.

The deliverable is a written decision, not a hook.

If matchers do filter, the answer is the matcher form `startup|resume|clear`, and `WO-20260824-bb0d` - `setup.sh installs the skill-sync binary, then the SessionStart hook` uses it.
If matchers do not filter, the answer is that `"matcher": ""` is used instead and `claude/tools/skill-sync.sh` must read the source out of the hook payload on stdin and exit early on `compact` by itself. That second outcome adds scope to `WO-20260824-5b89` - `skill-sync.sh part one: resolution, and the tools test tree it is proved in`, so say so plainly in the note if it happens.

Out of scope, and named because they are the obvious next thoughts: writing the real hook, which `WO-20260824-bb0d` - `setup.sh installs the skill-sync binary, then the SessionStart hook` owns, and editing `claude/tools/skill-sync.sh`, which does not exist yet and only gains the stdin read if the answer is no.

Do not modify `~/.claude/settings.json`. Every hook on this machine uses an empty matcher, that is precisely why the question is open, and changing the machine's real settings to run an experiment risks breaking every other project's session start.

Clean the scratch project up afterwards. It is scaffolding, not deliverable.

### Before you start

None.

One thing to be aware of rather than to resolve: forcing a compact costs a real context window, so it is the expensive event of the four and is worth doing last, after the cheap three are already recorded. The poker note on the ticket sized it at 3 points for exactly this reason.

### Read in this order

1. Root `CLAUDE.md`. Rules 12, 14 and 17 bear on this work. There is no `CONTEXT_STATE.md` in this repository, so the usual second step does not apply.
2. This entry, which is the top entry of `HYDRATION.md`. Read only this one. The entries below it are superseded history.
3. `docs/superpowers/plans/2026-08-24-skills-package-manager-implementation.md`, the section headed `Sequencing constraints`, specifically `C7`, and then `E1.2`. C7 is why this is a gate and not a detail.
4. The ticket file itself: `work-orders/WO-20260824-f1a5/WO-20260824-0615-confirm-whether-a-sessionstart-hook-matcher-filt.md`.
5. `docs/superpowers/specs/2026-08-23-skills-package-manager-design.md`, only the sections describing the SessionStart hook and the never-run-on-compact property. The rest is not needed for this ticket.

### Reuse, it is proven

`claude/skills/work-order/scripts/work-order.sh` owns every ticket transition. Never hand-edit a ticket file. `note` is the only way a note reaches a ticket, and `evidence` is the only way a criterion gets ticked.

`claude/skills/hydration-prompt/scripts/hydration.sh` owns `HYDRATION.md`. Run `check --body-file` before `add`; `add` refuses a body that fails `check`, which is how a malformed entry is kept out of the file.

`claude/skills/container-sandbox/SKILL.md` has a section on verifying a host CLI's behaviour by bind-mounting the real binary read-only. It is the right pattern for a great many things in these two epics, and it is the wrong pattern for this one. A `SessionStart` hook fires from a real interactive Claude Code session on this host; there is no way to produce a genuine resume or a genuine compact inside a container. Rule 14 is not waived, it simply has nothing to bite on, and the ticket's own test plan already calls this rung 5 and manual.

`gh` is authenticated and works in this repository. `gh-axi` wraps it and is preferred where it fits.

`git interpret-trailers --parse` is confirmed working end to end as of PR #56. Use it, not a regular expression, wherever a trailer is read.

### The verification ladder

Rung 1, free: `jq . <scratch>/.claude/settings.json`. Catches a malformed hook definition before any session is spent. A hook that fails to parse is silently absent, which looks identical to a matcher that filtered it out, and that is the one confusion that would make the whole result wrong.

Rung 2, cheap: start one session in the scratch project and confirm the hook file was appended to at all. If a plain startup does not fire, the hook is broken rather than the matcher being strict, and nothing further is worth doing until that is fixed.

Rung 3, the actual experiment: the resume and the clear. Two more sessions, no context cost worth counting.

Rung 4, expensive and last: the forced compact. This is the event the design's safety property is about, so it cannot be skipped, but it is the only one that costs a real context window.

Assert the post-state of the log file every time. Never assert on the exit status of the session command.

### Traps, already paid for

A hook appears not to fire and the conclusion is that matchers filter. The hook was actually never installed, because the settings file did not parse. Rung 1 exists for this.

A command reports success and did nothing. A prompt with no TTY takes its default and exits 0. Assert the post-state, never `$?`.

A loop over IDs passes every ID as one argument. This shell is zsh, which does not word-split an unquoted parameter the way bash does. Use `while read -r`, not `for x in $LIST`.

`git merge --ff-only origin/main` refuses with "diverging branches". You are in a treehouse slot at detached HEAD, not in `/home/luna/dotfiles`. Check `git branch --show-current` first.

`git rebase` refuses with "cannot rebase: You have unstaged changes", immediately after `work-order.sh start`. `start` writes the ticket file, `INDEX.md` and the epic README and leaves them uncommitted. Commit them before rebasing.

`work-order.sh done` refuses with "status is 'in-progress'; this command requires one of: in-review". `done` follows `submit --pr N`, so the pull request has to exist before `done` can be run. Open the PR, `submit`, `done`, then commit and push again onto the same PR.

### Workflow

```bash
WO=claude/skills/work-order/scripts/work-order.sh
HP=claude/skills/hydration-prompt/scripts/hydration.sh

bash $WO show    --project . --id WO-20260824-0615
bash $WO start   --project . --id WO-20260824-0615   # creates the branch, leaves files uncommitted

# ... do the work ...

bash $WO evidence --project . --id WO-20260824-0615 --index 1 --observed "..."
bash $WO evidence --project . --id WO-20260824-0615 --index 2 --observed "..."
bash $WO note     --project . --id WO-20260824-0615 --text "..."

bash $HP check   --project . --body-file /tmp/entry.md
bash $HP add     --project . --id <next> --title "<next title>" --body-file /tmp/entry.md

git push -u origin <branch>
gh pr create --base main --title "..." --body-file <file>

bash $WO submit  --project . --id WO-20260824-0615 --pr <N>
bash $WO done    --project . --id WO-20260824-0615   # on the branch, before the merge
git commit && git push                                # rides the same PR

# after the merge
bash $WO close   --project . --id WO-20260824-0615 --dry-run
bash $WO close   --project . --id WO-20260824-0615
```

`approve` is already done for all 23 tickets and must not be run again.

The pull request description is now the merge commit body verbatim. Write it as something worth reading on `main`, because that is where it ends up.

### Conventions

Every reference to a work-order in a chat reply carries the ticket ID and its full title joined by a dash. A bare ID is a defect, and so is "the next ticket" or "the blocked one".

Feature branches only. `main` is never written directly. The one exception to that rule does not exist yet and arrives with the publish workflow.

Squash is the only merge available in this repository now. Merge commits and rebase merges are disabled at the repository level, so `gh pr merge --merge` and `--rebase` will be refused.

No em dashes anywhere. Use a plain dash.

No agent co-author line in a commit message, and no Claude attribution footer in a PR body. Root `CLAUDE.md` Rule 13 makes the second one absolute.

All testing runs in Podman, per Rule 14, with no size threshold. This ticket's experiment cannot run in one, for the reason given above, and that is stated rather than quietly skipped.

Report failures as failures. A skipped step is not a completed one.

<!-- hydration-entry: WO-20260824-cc71 -->
## WO-20260824-cc71 - Repo settings: squash-only, with the commit body taken from the PR description
_Generated 2026-08-24 by hydration.sh. Newest entry._

### Ticket

`WO-20260824-cc71` - `Repo settings: squash-only, with the commit body taken from the PR description`. Position 1 of 21 children across two epics.
There is no predecessor. This is the first ticket of the first epic, `WO-20260824-f1a5` - `Skills package manager: prove the path on one skill`.

### What just landed

Five documentation and planning PRs, and nothing executable.

`docs/superpowers/specs/2026-08-23-skills-package-manager-design.md` is the design, 871 lines, with 21 numbered decisions.
Decision 19 puts the treehouse pool at `~/.treehouse/<repo>-<hash>/`, decision 20 fixes the four default skills as `work-order`, `living-docs`, `container-sandbox` and `context-compaction`, and decision 21 says `type` is derived from the tree it was found in and never declared, while `requires` is an optional comma-separated frontmatter key.

`docs/superpowers/plans/2026-08-24-skills-package-manager-implementation.md` is the implementation plan, 689 lines.
Its seven sequencing constraints C1 to C7 are the part worth reading twice.
Its `E1.x` and `E2.x` handles were always plan-internal and are now dead - every piece of work has a real ticket ID.

`docs/worktree-workflow.md` carries the answer to the treehouse gate. `treehouse return` does not lose unpushed commits, with or without `--force`. A dirty working tree is the case that changes code: `return` prompts, takes the no-TTY default, aborts, leaves the slot leased, and exits 0.

`claude/skills/container-sandbox/SKILL.md` gained a section on verifying a host CLI's behaviour by bind-mounting the real binary read-only. That is how the gate was answered and it is reusable.

PR #55 put 23 work-orders on `main`, all `ready`.

### What is NOT done

Nothing has been built. No line of either epic's implementation exists anywhere.

Measured on `main` at the time of writing, and each of these is a command whose output proves it:

- `ls claude/tools` fails. The directory does not exist, so neither `skill-sync.sh`, `skill-onboard.sh`, the notice partial, nor the tools test suite exist.
- `git ls-files .github/workflows` prints nothing. There is no PR gate and no publisher.
- `head -c 40 claude/skills/registry.json` shows `"schema": 1`. Schema 2 is unwritten.
- `grep -l "This copy is read-only" claude/skills/*/SKILL.md | wc -l` prints `43`. Every skill still carries the inline notice.
- `gh api repos/jkkelley/dotfiles --jq .squash_merge_commit_message` prints `COMMIT_MESSAGES`. This is the exact trap this ticket exists to close, and it is still open.

Every one of the 23 tickets is `ready`. None has been started, so none has a branch.

The 23 were approved with `--no-lavish`, and each records the reason: they were reviewed as one diff on PR #55 rather than in Lavish. That is an honest exception, not a skipped gate, but it is recorded on every ticket and a reader will see the warning.

### Stale or false in the docs

The previous top entry of `HYDRATION.md` said under `Before you start`: "Close the open decision on `type` and `requires`. Ask the user; do not choose." That is closed. Decision 21 in the design doc is the answer and it merged as PR #54. There is no open decision anywhere in this work.

Root `CLAUDE.md` Rule 16 still says a PR touching a skill must bump the version and ship a regenerated `registry.json` by hand. That is true today and must be obeyed today. It becomes false at `WO-20260824-8cd1` - `Rewrite root CLAUDE.md for merge-time allocation and the named main exception`, and not before. Do not pre-empt it.

The design doc's "Open" list still carries the question of who writes the generated skills table into `CLAUDE.md.tmpl`. The body of the same document already answers it: the sync writes it. The body wins, it is the more specific statement, and the sync is the only actor that knows what actually landed. The stale line is recorded in `WO-20260824-b21b` - `CLAUDE.md.tmpl: replace the session-start prose, add the skills markers, the treehouse policy and the documentation-lifetime rule` so it is corrected rather than rediscovered.

This repository has no `CONTEXT_STATE.md`. The `hydration-prompt` skill's one flow references one, and several skills assume it. It genuinely does not exist here. Do not create one as a side effect of this ticket.

### Your scope

Four repository settings, and one throwaway pull request that proves they work.

```bash
gh api -X PATCH repos/jkkelley/dotfiles \
  -f squash_merge_commit_title=PR_TITLE \
  -f squash_merge_commit_message=PR_BODY \
  -F allow_merge_commit=false \
  -F allow_rebase_merge=false
```

Then read all four back, then open a throwaway PR carrying a `Bump: nothing=patch` line in its description, merge it, and read the resulting commit on `main`.

The two acceptance criteria are deliberately different things. Reading the setting back proves the API call worked. Only reading the merged commit proves the trailer survives the path it will actually travel. Do not evidence the second criterion with the first one's output.

Out of scope, and named because they are the obvious next thoughts: branch protection rules, and required status checks. The status checks arrive with `WO-20260824-2ad1` - `PR gate workflow: validate the bump intent and run the affected suites`, which is a different ticket and is blocked behind four others.

Clean the throwaway PR's branch up afterwards. It is scaffolding, not deliverable.

### Before you start

None.

One thing to be aware of rather than to resolve: these settings are repository-wide and take effect immediately for every future merge in this repository, including the ticket's own. Disabling merge commits and rebase merges is intended, not collateral.

### Read in this order

1. Root `CLAUDE.md`. Rules 12 through 17 all bear on this work. There is no `CONTEXT_STATE.md` in this repository, so the usual second step does not apply.
2. This entry, which is the top entry of `HYDRATION.md`. Read only this one. The entries below it are superseded history.
3. `docs/superpowers/plans/2026-08-24-skills-package-manager-implementation.md`, the section headed `Sequencing constraints`, specifically C2. That is why this ticket is first.
4. The ticket file itself: `work-orders/WO-20260824-f1a5/WO-20260824-cc71-*.md`.
5. `docs/superpowers/specs/2026-08-23-skills-package-manager-design.md`, only the sections on merge-time allocation. The rest is not needed for this ticket.

### Reuse, it is proven

`gh` is authenticated and works in this repository. `gh-axi` wraps it and is preferred where it fits.

`claude/skills/work-order/scripts/work-order.sh` owns every ticket transition. Never hand-edit a ticket file. `note` is the only way a note reaches a ticket, and `evidence` is the only way a criterion gets ticked.

`git interpret-trailers --parse` is the reader the publisher will use later. Use the same command here, not a regular expression, so the proof matches what production will do.

`claude/skills/container-sandbox/SKILL.md` has a section on verifying a host CLI by bind-mounting the real binary read-only. Nothing in this ticket needs it, but it is the pattern for the tickets that do.

### The verification ladder

Rung 1, free: `gh api repos/jkkelley/dotfiles --jq '{squash_merge_commit_title,squash_merge_commit_message,allow_merge_commit,allow_rebase_merge}'`. Catches a typo'd field name or a `-f` that should have been `-F`. Booleans need `-F`; sending `allow_merge_commit=false` as a string with `-f` is accepted and does nothing.

Rung 2, one throwaway PR: merge it and run `git log -1 --format=%B origin/main | git interpret-trailers --parse`. This is the only rung that proves the thing the ticket is actually for, and it cannot be simulated. Everything downstream in both epics depends on it being true.

### Traps, already paid for

A `Bump:` trailer written in the PR description is absent from the merge commit, and every bump silently drops. `squash_merge_commit_message` defaults to `COMMIT_MESSAGES`, which concatenates the branch's commit messages and discards the PR body entirely. It currently reads `COMMIT_MESSAGES` in this repository, so this is the live state, not a hypothetical.

The settings read back correctly and the trailer still does not arrive. The API read only proves the call was accepted. The two acceptance criteria are separate for this reason.

A command reports success and did nothing. A prompt with no TTY takes its default and exits 0. This bit the treehouse gate work: `treehouse return` on a dirty tree aborts, leaks the slot, and exits 0. Assert the post-state, never `$?`.

A loop over IDs passes every ID as one argument. This shell is zsh, which does not word-split an unquoted parameter the way bash does. Use `while read -r`, not `for x in $LIST`.

`git merge --ff-only origin/main` refuses with "diverging branches". You are in a treehouse slot at detached HEAD, not in `/home/luna/dotfiles`. Check `git branch --show-current` first.

### Workflow

```bash
WO=claude/skills/work-order/scripts/work-order.sh

bash $WO show    --project . --id WO-20260824-cc71
bash $WO start   --project . --id WO-20260824-cc71

# ... do the work ...

bash $WO evidence --project . --id WO-20260824-cc71 --index 1 --observed "..."
bash $WO evidence --project . --id WO-20260824-cc71 --index 2 --observed "..."
bash $WO note     --project . --id WO-20260824-cc71 --text "..."

bash $WO submit  --project . --id WO-20260824-cc71 --pr <N>
bash $WO done    --project . --id WO-20260824-cc71     # on the branch, before the merge

# after the merge
bash $WO close   --project . --id WO-20260824-cc71 --dry-run
bash $WO close   --project . --id WO-20260824-cc71
```

`approve` is already done for all 23 tickets and must not be run again.

`done` is written on the feature branch before the PR lands, alongside the `HYDRATION.md` entry for the next ticket, so all of it rides one pull request.

### Conventions

Every reference to a work-order in a chat reply carries the ticket ID and its full title joined by a dash. A bare ID is a defect, and so is "the next ticket" or "the blocked one".

Feature branches only. `main` is never written directly. The one exception to that rule does not exist yet and arrives with the publish workflow.

No em dashes anywhere. Use a plain dash.

No agent co-author line in a commit message, and no Claude attribution footer in a PR body. Root `CLAUDE.md` Rule 13 makes the second one absolute.

All testing runs in Podman, per Rule 14, with no size threshold. This ticket has nothing to containerise - it is API calls and a merged PR - but the rule is not waived, it simply does not bite here.

Report failures as failures. A skipped step is not a completed one.

<!-- hydration-entry: none -->
## Poker and work-order tickets for the skills package manager
_Generated 2026-08-24 by hydration.sh. Newest entry._

### Ticket

No work order yet - creating them is this session's output. This is phases 4 and 5 of the skills package manager: discovery, design doc, implement doc, **poker**, **cut work-orders**, do work.

Predecessors: `#46` discovery, `#47` the two decided workflow docs, `#48` hydration init, `#49` the settled design, `#50` the implement-doc handoff, `#51` the host-CLI probe pattern, `#52` the implementation plan.

### What just landed

`#52` on `main` at `fe2504c`. The implementation plan exists, 689 lines, covering both epics in one document.

| File                                                                         | Lines | State                                                  |
| ---------------------------------------------------------------------------- | ----- | ------------------------------------------------------ |
| `docs/superpowers/plans/2026-08-24-skills-package-manager-implementation.md` | 689   | **the plan**. 23 tickets, seven sequencing constraints |
| `docs/superpowers/specs/2026-08-23-skills-package-manager-design.md`         | 871   | settled, binding on design. Not reopened               |
| `docs/skill-distribution-workflow.md`                                        | 81    | binding on merge-time allocation                       |
| `docs/worktree-workflow.md`                                                  | 248   | its backlog is now a pointer table into the plan       |
| `notes/skills-pm-discovery.md`                                               | 657   | measurements only, superseded where it differs         |

`#51` added a section to `container-sandbox` covering how to verify a host CLI's behaviour in a container, bumping it 1.0.2 to 1.1.0.

Two decisions closed, bringing the total to twenty:

- **19.** The treehouse pool stays user-level at `~/.treehouse/<repo>-<hash>/`. In-project `--root .` rejected.
- **20.** `project-scaffold`'s default manifest is four skills: `work-order`, `living-docs`, `container-sandbox`, `context-compaction`.

The gate that blocked the plan is answered. `treehouse return` does not lose unpushed commits - the branch ref stays in the repository and the object stays reachable, with or without `--force`.

### What is NOT done

**Nothing has been built. Three documents and one skill section, no implementation.** What proves it:

```sh
ls claude/tools/ 2>&1                    # No such file or directory
ls .github/ 2>&1                         # No such file or directory
git grep -n "skills.toml"                # docs only
git grep -n "SessionStart" -- claude/    # nothing
```

**No work-orders exist for any of this.** `work-orders/INDEX.md` does not carry a single ticket from the plan. Creating them is this session's deliverable.

**One decision in the plan is deliberately open and gates ticket E1.4.** Where `type` and `requires` are declared, so `render_registry` can read them. The plan lays out three shapes with their real costs under "One decision this plan cannot make". E1.4 does not start until it is closed, and E1.6 - the largest ticket - depends on E1.4.

**The repo settings are still wrong.** As of 2026-08-24 the live values remain `squash_merge_commit_message=COMMIT_MESSAGES`, `allow_merge_commit=true`, `allow_rebase_merge=true`. That is ticket E1.1, not a prerequisite for cutting tickets.

### Stale or false in the docs

| Where                                    | What is wrong                                                                                                          |
| ---------------------------------------- | ---------------------------------------------------------------------------------------------------------------------- |
| `notes/skills-pm-discovery.md`           | Predates both workflow docs and both revisions. The plan and the design are the current word wherever they differ      |
| Discovery note, "Decided" table          | Says semver runs on the PR branch and `skill-versioning` keeps its name. Both reversed                                 |
| Root `CLAUDE.md` Rule 16                 | Still says the author bumps and ships the registry. The rewrite text exists in the design doc, unapplied. Ticket E1.12 |
| Root `CLAUDE.md`, "main is written once" | No exception for the publish bot yet. Exact wording is in the design doc                                               |
| Every `SKILL.md`, lines 9-14             | Still carries the inline read-only notice. 43 files. Tickets E1.10 and E2.6                                            |
| `CLAUDE.md.tmpl:269-336`                 | 68 lines of prose session-start check that the hook replaces. Ticket E2.4                                              |
| Design doc, "Open, not designed here"    | Lists who writes the generated skills table. The doc body already answers it - the sync writes it. The body wins       |

### Your scope

**Two outputs, in order.**

**1. Poker.** Size the 23 tickets in the plan. Its "Estimate shape, for poker" section is the starting point, not the answer - it gives shape, not points. `project-manager` carries the estimation guidance, including the one rule that matters here: never average, discuss the outliers, because the highest and lowest estimators usually hold information the others do not.

The two that need the most conversation are `E1.6`, `skill-sync.sh`, which is the only ticket flagged large and carries a named split seam between resolution and application; and `E2.6`, removing the notice from 42 files, which is mechanical and is still the riskiest mechanical change in the plan.

**2. Cut the work-orders.** Two epics, each with children, using `work-order`. The plan's dependency graph is the source for `--depends-on` edges, and the seven sequencing constraints are the reason those edges exist - encode them, do not re-derive them.

**`E1.1` and friends are plan-internal handles, not ticket IDs.** They exist so this document and the plan can point at each other. Real IDs are minted by `work-order.sh new`, and every reference to one in a chat reply carries the ID and its full title joined by a dash.

Out of scope: writing `skill-sync.sh`, any workflow YAML, the notice partial, or a template edit. That is phase 6, one ticket per session.

### Before you start

**Close the open decision on `type` and `requires`.** Ask the user; do not choose. The three options and their costs are in the plan. It blocks `E1.4`, which blocks `E1.6`, so a ticket tree cut without it has a hole in the middle of Epic 1.

**Do not reopen the twenty closed decisions.** Eighteen in the design doc's table, two in the plan's. If sizing reveals one of them is unbuildable, say so plainly and stop - do not quietly substitute a different design.

**Two things are named in the design doc's "Open, not designed here" section and stay there.** They are not to be designed, raised as gaps, or folded into a recommendation.

**The seven sequencing constraints are not advisory.** C1 in particular: the notice check cannot invert until the last `SKILL.md` is clean, which is a three-step ordering across both epics. A ticket tree that lets `E2.7` run before `E2.6` makes the gate fail on 42 skills.

### Read in this order

1. `CLAUDE.md` at the repo root, all 17 rules. Rule 13 (no Claude footer in PR bodies) is absolute; Rule 14 (Podman) and Rule 16 (versioning) both change in this work.
2. `HYDRATION.md`, this entry only.
3. `docs/superpowers/plans/2026-08-24-skills-package-manager-implementation.md` in full. It is the document this session works from.
4. `docs/superpowers/specs/2026-08-23-skills-package-manager-design.md` for the reasoning behind any ticket whose point is unclear.
5. `claude/skills/work-order/SKILL.md`, "Cutting an epic and its children" at line 190.
6. `claude/skills/project-manager/SKILL.md`, "Estimation" at line 46.
7. `docs/skill-distribution-workflow.md` and `docs/worktree-workflow.md` only if a ticket's history is in question.

There is no `CONTEXT_STATE.md` in this repo.

### Reuse, it is proven

| Thing                                   | What it gives you                                            | Sharp edge                                                                          |
| --------------------------------------- | ------------------------------------------------------------ | ----------------------------------------------------------------------------------- |
| `work-order.sh new --json --parent`     | epics with children, a dependency graph, validated lifecycle | the tree in `INDEX.md` truncates long titles. A truncated title is not a title      |
| `project-manager` skill                 | estimation methods, and the never-average rule               | it is advice, not a script. Nothing enforces it                                     |
| The plan's dependency graph             | the `--depends-on` edges, already worked out                 | it encodes seven constraints. Dropping an edge silently drops the reason for it     |
| `skill-version.sh verify`               | pure pass/fail, green on `main` today                        | it must stay green. The publisher in `E1.8` treats a red `verify` as work to do     |
| `container-sandbox`, "host CLI" section | how to probe a tool already on the machine, added in `#51`   | assert the post-state, never `$?`. That is the whole point of the section           |
| `treehouse` v2.3.0, `~/.local/bin`      | worktree pool, detached-HEAD-when-idle, self-updating        | `return` on a dirty tree aborts and exits 0                                         |
| The 7 skills that ship a test suite     | the real input to the CI matrix in `E1.7`                    | the other 36 have nothing to run, which is why the matrix needs an empty-list guard |

### The verification ladder

1. `git grep` for the symbol. Catches a ticket referring to something that does not exist.
2. `bash -n` on any script. Catches the syntax error before a container spins up.
3. `skill-version.sh verify` locally. Catches an unversioned skill and a stale registry. It has caught both.
4. The skill's own `testing/run-tests.sh` in Podman, per Rule 14 and `claude/skills/container-sandbox/references/skill-testing.md`.
5. A real session in a scratch repo, for anything touching the `SessionStart` hook. The hook only proves itself by firing.

For this session the ladder mostly stops at rung 1, because the output is tickets. Rung 1 still matters: a ticket citing a file or line that does not exist is a ticket that wastes a whole session in phase 6.

### Traps, already paid for

- **`treehouse return` on a dirty tree prompts, takes the no-TTY default, aborts, leaves the slot leased, and exits 0.** Assert the post-state, never `$?`. Two tickets in the plan carry this in their acceptance criteria.
- **`squash_merge_commit_message` is `COMMIT_MESSAGES`.** The squash body comes from the branch's commit messages, not the PR description, so a `Bump:` trailer written in the description never reaches the commit and nothing reports an error.
- **`actions/checkout` defaults to `github.sha`**, the triggering commit, not the tip. A run whose sibling merged first sits on a stale tree and its push is rejected non-fast-forward, serialised or not.
- **An empty matrix is a hard error in GitHub Actions.** A docs-only PR emits `[]` and the workflow fails for no reason.
- **`find -type d` does not match symlinks to directories.** `skill_dirs()` uses it, so a compat symlink for the rename would be invisible to the registry - hiding the breakage rather than surfacing it.
- **Two PRs allocating the same version.** `#41` and `#42` both claimed `project-scaffold` 1.2.0. Git blocked them only because they happened to edit the same lines.
- **`git merge --ff-only origin/main` moves whatever branch you are on.** Check `git branch --show-current` first. A treehouse slot sits at detached HEAD and cannot be fast-forwarded at all, which is correct and is not an error to fix.
- **`-p` in a `claude` launch command.** It is `--print`: prints a reply and exits, so no session ever starts. The failure produces plausible output rather than an error.
- **A `SessionStart` hook that exits non-zero takes the session with it.** Always exit 0 and print the failure loudly.
- **Untracked files in the working directory are invisible to a session that starts in a worktree.** A whole session re-derived decided work because `docs/*.md` were never committed.

### Workflow

Cutting tickets is a docs change to `work-orders/`, so it follows the same shape as the last three sessions.

```sh
# isolated workspace
WT=$(treehouse get --lease --lease-holder "skills-pm-poker")
cd "$WT"
git switch -qc feat/skills-pm-work-orders origin/main

WO=.claude/skills/work-order/scripts/work-order.sh
EPIC=$(bash $WO new --json --top-level --type feature --priority p1 --title "..." | jq -r .id)
bash $WO new --parent "$EPIC" --type feature --title "..." --depends-on "..."

git add -A && git commit
git push -u origin HEAD
gh pr create --base main
gh pr merge <N> --squash

# close out - check the branch first, then return the slot and confirm it went
git branch --show-current
git checkout main && git fetch origin --prune && git merge --ff-only origin/main
treehouse return "$WT" --if-lease-holder "skills-pm-poker"
treehouse status                     # assert it is free. rc 0 does not prove it

HP=~/.claude/skills/hydration-prompt/scripts/hydration.sh
bash $HP check --project . --body-file /tmp/entry.md
bash $HP add   --project . --title "..." --body-file /tmp/entry.md
bash $HP command --project .
```

Ticket files touch nothing under `claude/skills/`, so no version bump and no registry regeneration. The moment a script or template is edited, Rule 16 applies.

### Conventions

Ticket references carry the ID **and** the full title, joined by a dash, on every mention. A bare ID is a defect, and so is a pointer with no name: "the next ticket", "the blocked one". Take the title from the ticket file, never from `INDEX.md`, whose tree truncates.

No em dashes anywhere, plain dashes only. No agent co-author lines in commits. No Claude attribution footer in a PR body, ever, per Rule 13.

Feature branches only; `main` is never written directly. All testing runs in Podman per Rule 14. Pin every version to an immutable digest per Rule 15; `:latest` is banned.

This repo is public. No real usernames, IPs, hostnames, registry paths, or credentials. The only documented exceptions are the two `jkkelley/dotfiles` public URLs - the registry raw URL and each skill's own source URL.

Report failing tests as failing, and say plainly what was skipped. "Completed" is wrong if anything was silently left out.

<!-- hydration-entry: none -->
## Implement doc for the skills package manager
_Generated 2026-08-24 by hydration.sh. Newest entry._

### Ticket

No work order. This is the **implement-doc** phase of the skills package manager, phase 3 of 6: discovery, design doc, **implement doc**, poker, cut work-orders, do work. Tickets are cut in phase 5, so there is deliberately no ID yet.

Predecessors: `#46` discovery and first design, `#47` the two decided workflow docs, `#48` hydration init, `#49` the settled design.

### What just landed

`#49` on `main` at `5c7973d`. The design doc is now **settled** - every open decision closed, every known defect corrected. 532 insertions, 88 deletions against the version merged in `#46`.

| File                                                                 | Lines | State                                          |
| -------------------------------------------------------------------- | ----- | ---------------------------------------------- |
| `docs/superpowers/specs/2026-08-23-skills-package-manager-design.md` | 871   | **settled**, the binding document              |
| `docs/skill-distribution-workflow.md`                                | 81    | decided 2026-08-22, binding on merge-time CI   |
| `docs/worktree-workflow.md`                                          | 243   | treehouse model, carries the real task list    |
| `notes/skills-pm-discovery.md`                                       | 657   | measurements only, superseded where it differs |

Eighteen decisions are recorded in the design doc's "Decisions, closed" table. The five that were awaiting sign-off are answered. The four defects merged in `#46` are fixed.

The corrections most likely to be re-derived if skimmed:

- **Version allocation is at merge time**, never on a PR branch.
- **Ownership is per-directory.** Sync never removes or rebuilds `.claude/skills/` itself, only the directories the manifest resolves to. Hand-authored project-only skills live beside the managed ones. The receipt records what sync owns.
- **The read-only notice becomes a rendered partial**, leaving all 43 `SKILL.md` files.
- **The matcher and the stamp solve two different problems.** The stamp cannot prevent a mid-task sync during auto-compact.

### What is NOT done

**Nothing has been built. No script, no workflow, no template change, no gitignore line exists.** What proves it:

```sh
ls claude/tools/ 2>&1                    # No such file or directory
ls .github/ 2>&1                         # No such file or directory
git grep -n "skills.toml"                # design docs only
git grep -n "SessionStart" -- claude/    # nothing
git grep -rn "Bump:" -- .github/         # nothing to search
```

**The implementation document does not exist.** That is this session's only deliverable.

**One design decision is untested and gates part of the plan.** What `treehouse return` does with unpushed commits on a branch. Idle slots are observed detached across all 15, but nothing has been run against a slot carrying unpushed work. `skill-onboard.sh` is specified in terms of treehouse, so this must be settled before the implement doc commits to that shape.

**The repo settings have not been changed.** As of 2026-08-24 the live values are still `squash_merge_commit_message=COMMIT_MESSAGES`, `allow_merge_commit=true`, `allow_rebase_merge=true`. The design specifies changing all three and the `Bump:` trailer does not work until they are. That is an implementation step, not a prerequisite for writing the doc.

### Stale or false in the docs

| Where                                               | What is wrong                                                                                                                                      |
| --------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------- |
| `notes/skills-pm-discovery.md`                      | Written before the two workflow docs were found, and before the 2026-08-24 revision. Treat the design doc as the current word wherever they differ |
| Discovery note, "Decided" table                     | Says semver runs on the PR branch and that `skill-versioning` keeps its name. Both reversed in `#49`                                               |
| Root `CLAUDE.md` Rule 16                            | Still says the author bumps and ships the registry. The rewrite text is in the design doc and has not been applied                                 |
| Root `CLAUDE.md`, "main is written once"            | Has no exception for the publish bot yet. The design doc contains the exact wording to add                                                         |
| Every `SKILL.md`, lines 9-14                        | Still carries the read-only notice inline. 43 files. Removing it is implementation work                                                            |
| `docs/worktree-workflow.md`, "After the compaction" | Six-item task list, predates the design. Reconcile it rather than treating it as a separate stream                                                 |

### Your scope

Produce **one** implementation document. Not the code.

`docs/superpowers/plans/2026-08-24-skills-package-manager-implementation.md`, matching the three plans already in that directory.

One document, not several. It covers both epics, because the second follows the procedure the first proves:

- **Epic 1, the pilot.** `hydration-prompt` through the whole pipeline end to end: trailer, PR gate, test matrix, merge-time bump, registry schema 2, sync into a real project. Nothing else moves until that path works.
- **Epic 2, the rollout.** The remaining 42 skills through the same procedure, closing with the `skill-versioning` to `skill-registry` rename.

It decides build order, file layout, test strategy per Rule 14, and how the six items in "After the compaction" at the bottom of `docs/worktree-workflow.md` interleave with the design. That list is the real backlog and predates the design doc; reconcile the two into one ordered plan.

Out of scope: writing `skill-sync.sh`, the workflow YAML, the notice partial, or any template edit. That is phase 6, after poker and tickets.

### Before you start

**Test `treehouse return` with unpushed commits.** Create a throwaway branch in a leased slot, commit without pushing, return the slot, and record what happens to the commit. `skill-onboard.sh`'s design depends on the answer. This is the one genuinely unknown thing.

**Do not reopen settled decisions.** The eighteen in the design doc's "Decisions, closed" table are closed. If implementation reveals one of them is unbuildable, say so plainly and stop - do not quietly pick a different design.

**Two things are flagged as future work and are not to be designed, mentioned as gaps, or folded into a recommendation:** the project-only skill system, and `justfile` coverage per Rule 17. Both are named in the design doc's "Open, not designed here" section, and that is where they stay.

**Ask before choosing** if the implement doc needs a decision the design doc does not contain. The design phase is over; a new decision made silently during implementation planning is how the two documents drift apart.

### Read in this order

1. `CLAUDE.md` at the repo root, all 17 rules. Rule 14 (Podman) and Rule 16 (versioning) both change in this work, and Rule 13 (no Claude footer in PR bodies) is absolute.
2. `HYDRATION.md`, this entry only.
3. `docs/superpowers/specs/2026-08-23-skills-package-manager-design.md` in full, all 871 lines. It is the binding document.
4. `docs/skill-distribution-workflow.md`, 81 lines. It is binding on merge-time allocation and explains why.
5. `docs/worktree-workflow.md`, especially "After the compaction" at the bottom.
6. `docs/superpowers/plans/2026-05-02-operator-implementation.md` for the shape an implementation doc takes in this repo.
7. `claude/skills/skill-versioning/scripts/skill-version.sh` - `hash_skill` at 102, `render_registry` at 115, `cmd_bump` at 150, `cmd_verify` at 174.
8. `notes/skills-pm-discovery.md` only if you need the measurement behind a decision.

There is no `CONTEXT_STATE.md` in this repo.

### Reuse, it is proven

| Thing                                   | What it gives you                                                                                                            | Sharp edge                                                                                      |
| --------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------- |
| `skill-version.sh`                      | `init`, `bump`, `verify`, `render_registry`, all deterministic                                                               | `cmd_bump` writes `SKILL.md` frontmatter _before_ the registry. Both land on `main`             |
| `skill-version.sh verify`               | a pure pass/fail check, ideal as a CI gate                                                                                   | must be split. The registry-in-sync half cannot pass on a PR branch under merge-time allocation |
| `skill-update.sh`                       | fetch a skill from GitHub with no dotfiles checkout; worktree-based PR flow                                                  | narrows to hand-authored skills only. It stops being part of the sync path                      |
| `treehouse` v2.3.0, `~/.local/bin`      | worktree pool, detached-HEAD-when-idle, self-updating Go binary                                                              | v2.0.0 removed `destroy --force`; scripts using it broke 2026-08-23                             |
| `project-scaffold/testing/`             | 14 numbered cases, `assert.sh`, `run-tests.sh`                                                                               | the pattern to copy for testing `skill-sync.sh`                                                 |
| The 7 skills that ship a test suite     | `cartography`, `context-compaction`, `hydration-prompt`, `living-docs`, `project-scaffold`, `skill-versioning`, `work-order` | the matrix's real input. The other 36 have nothing to run                                       |
| `.claude/cache/`                        | already gitignored, declared derived, never pruned by `cache.sh`                                                             | deleting it also deletes the sync tool's receipt, which is now the ownership record             |
| The `-axi` tools on `~/.npm-global/bin` | precedent for a PATH binary invoked from a `SessionStart` hook                                                               | they run at `timeout: 10`; a cold skill sync needs 30                                           |

### The verification ladder

1. `git grep` for the symbol. Catches an implement doc referring to something that does not exist.
2. `bash -n` on any script. Catches the syntax error before a container spins up.
3. `skill-version.sh verify` locally. Catches an unversioned skill, a missing notice, and a stale registry. It has caught all three.
4. The skill's own `testing/run-tests.sh` in Podman, per Rule 14 and `claude/skills/container-sandbox/references/skill-testing.md`.
5. A real session in a scratch repo, for anything touching the `SessionStart` hook. The hook only proves itself by firing.

Rung 5 matters more than usual here. The current session-start check is prose an agent may or may not follow, and the entire point of this work is replacing it with something that cannot be skipped. That property is unobservable from a unit test.

### Traps, already paid for

- **`squash_merge_commit_message` is `COMMIT_MESSAGES`.** The squash body is built from the branch's commit messages, not the PR description. A `Bump:` trailer written in the description never reaches the commit, the publisher finds nothing, and there is no error to trace.
- **`actions/checkout` defaults to `github.sha`.** That is the commit that triggered the run, not the current tip. A run whose sibling merged first is on a stale tree and its push is rejected non-fast-forward, serialised or not. `ref: main`.
- **An empty matrix is a hard error in GitHub Actions.** A docs-only PR emits `[]` and the workflow fails for no reason.
- **`find -type d` does not match symlinks to directories.** Relevant because `skill_dirs()` uses it, so a symlink in `claude/skills/` is invisible to the registry. This is why a compat symlink for the rename would have hidden the problem rather than surfacing it.
- **Two PRs allocating the same version.** `#41` and `#42` both claimed `project-scaffold` 1.2.0. Git blocked them only because they happened to edit the same lines.
- **`cannot remove a locked working tree` after a successful merge.** A hand-rolled worktree pinning the branch. Hit twice on 2026-08-23. treehouse's detached-HEAD invariant is the fix.
- **`git merge --ff-only origin/main` run from the wrong branch moves that branch.** Happened this session on `feat/stash-commit-unstash`, which had no commits of its own; restored to `a663655` with `git branch -f`. Check `git branch --show-current` before merging.
- **`-p` in a `claude` launch command.** It is `--print`: prints a reply and exits, so no session ever starts. The failure produces plausible output rather than an error.
- **Overwriting a running bash script in place.** Bash reads lazily by byte offset. `mv` preserves the inode; `cp` truncates it.
- **A `SessionStart` hook that exits non-zero takes the session with it.** Always exit 0 and print the failure loudly.
- **Untracked files in the working directory are invisible to a session that starts in a worktree.** A whole session re-derived decided work because `docs/*.md` were never committed.

### Workflow

No work order exists for this phase, so there is no `work-order.sh` sequence to run. Tickets get cut in phase 5, from the document this session produces.

```sh
# isolated workspace
WT=$(treehouse get --lease --lease-holder "skills-pm-implement-doc")
cd "$WT"
git switch -c feat/skills-pm-implementation-doc origin/main

# ... write the implementation doc ...

git add -A && git commit
git push -u origin HEAD
gh pr create --base main
gh pr merge <N> --squash --delete-branch

# close out - check you are on main first
git branch --show-current
git checkout main && git fetch origin --prune && git merge --ff-only origin/main
treehouse return "$WT" --if-lease-holder "skills-pm-implement-doc"

HP=~/.claude/skills/hydration-prompt/scripts/hydration.sh
bash $HP check --project . --body-file /tmp/entry.md
bash $HP add   --project . --title "..." --body-file /tmp/entry.md
bash $HP command --project .
```

Docs-only changes touch nothing under `claude/skills/`, so no version bump and no registry regeneration are required. The moment a template or script is edited, Rule 16 applies.

### Conventions

Ticket references carry the ID **and** the full title, joined by a dash, on every mention. A bare ID is a defect. So is a pointer with no name: "the next ticket", "the blocked one".

No em dashes anywhere, plain dashes only. No agent co-author lines in commits. No Claude attribution footer in a PR body, ever, per Rule 13.

Feature branches only; `main` is never written directly. All testing runs in Podman per Rule 14. Pin every version to an immutable digest per Rule 15; `:latest` is banned.

This repo is public. No real usernames, IPs, hostnames, registry paths, or credentials. The only documented exceptions are the two `jkkelley/dotfiles` public URLs - the registry raw URL and each skill's own source URL.

Report failing tests as failing, and say plainly what was skipped. "Completed" is wrong if anything was silently left out.

<!-- hydration-entry: none -->
## Implement doc for the skills package manager, reconciled with the two decided workflow docs
_Generated 2026-08-23 by hydration.sh. Newest entry._

### Ticket

No work order. This is the **implement-doc** phase of the skills package manager, phase 3 of 6 in the sequence: discovery, design doc, **implement doc**, poker, cut work-orders, do work. Tickets are cut in phase 5, after this one, so there is deliberately no ID yet.

Predecessor: the discovery and design sessions, merged as `#46` and `#47`.

### What just landed

Four documents on `main`, no code. Nothing has been built.

| File                                                                 | Lines | What it is                                    |
| -------------------------------------------------------------------- | ----- | --------------------------------------------- |
| `notes/skills-pm-discovery.md`                                       | 657   | measured state of the repo, and the gaps      |
| `docs/superpowers/specs/2026-08-23-skills-package-manager-design.md` | 428   | the design                                    |
| `docs/skill-distribution-workflow.md`                                | 81    | decided 2026-08-22, was untracked until `#47` |
| `docs/worktree-workflow.md`                                          | 243   | treehouse model, carries the real task list   |

The design settles: a TOML manifest at `.claude/skills.toml` as the only committed artifact, no lockfile, a `SessionStart` hook in `~/.claude/settings.json` rather than the project template, a sync tool as a PATH binary that no-ops without a manifest, registry schema 2 with `type` and `requires`, and five named failure modes with their handling.

The last two documents were written 2026-08-23 and left untracked. The design session never saw them and re-derived three of their decisions.

### What is NOT done

**Nothing has been built. No script, no workflow, no template change, no gitignore line exists.** What proves it:

```sh
ls claude/tools/ 2>&1              # No such file or directory
ls .github/ 2>&1                   # No such file or directory
git grep -n "skills.toml"          # only the two design docs
git grep -n "SessionStart" -- claude/   # nothing
```

**The design doc is wrong on one point and is merged that way.** It puts the CI version bump on the **PR branch**. `docs/skill-distribution-workflow.md` puts it on **merge to main**, and its reasoning is better: a version is a claim about ordering, and ordering is not knowable until merge. PRs `#41` and `#42` both allocated `project-scaffold` 1.2.0 from their own stale snapshots. Bumping on the PR branch reproduces that collision exactly. **Correct this before building.**

**Four things the design doc does not cover**, all raised in the two workflow docs:

- `.claude/scaffold.json` records which skill version the vendored copies came from. Gitignore the directory beside it and that record must survive independently or be regenerated.
- Rule 16 needs a carve-out for shared boilerplate. PR `#42` rewrote the read-only notice in all 42 `SKILL.md` files and forced 42 bumps.
- A skill local to one project that still needs version control. Flagged open and deliberately undesigned.
- `skill-onboard.sh` is specified using `git worktree add` by hand. That is the pattern `docs/worktree-workflow.md` exists to replace.

**Five decisions in the design doc are recommendations, not conclusions.** They are listed under "Decisions needing sign-off" and must be closed with the user, not chosen unilaterally.

### Stale or false in the docs

| Where                                                                      | What is wrong                                                                                                                                       |
| -------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------- |
| `2026-08-23-skills-package-manager-design.md`, "Publish, on the PR branch" | Superseded. Version allocation happens at merge time. See `docs/skill-distribution-workflow.md`                                                     |
| Same doc, "Onboarding an existing project"                                 | Uses `git worktree add` directly. Use treehouse                                                                                                     |
| Same doc, "Prerequisite"                                                   | Presents gitignoring `.claude/skills/` as newly discovered. It was decided 2026-08-22 and is item 3 of the task list in `docs/worktree-workflow.md` |
| `notes/skills-pm-discovery.md`                                             | Written before the two workflow docs were found. Treat the design doc as the current word wherever they differ                                      |
| Root `CLAUDE.md` Rule 16                                                   | Still says the author bumps and ships the registry. The actor becomes CI                                                                            |

### Your scope

Produce the **implementation document**. Not the code.

It decides build order, file layout, test strategy per Rule 14, and how the six items in "After the compaction" at the bottom of `docs/worktree-workflow.md` interleave with the design. That task list is the real backlog and predates the design doc; reconcile the two into one ordered plan rather than treating them as separate streams.

Output goes to `docs/superpowers/plans/2026-08-24-skills-package-manager-implementation.md`, matching the three plans already in that directory.

Also in scope: a follow-up PR correcting the four defects listed under "What is NOT done" in the design doc itself, so `main` stops asserting a superseded CI design.

Out of scope: writing `skill-sync.sh`, the workflow YAML, or any template edit. Those are phase 6.

### Before you start

**Close the five sign-off decisions with the user.** They are in the design doc under "Decisions needing sign-off": single registry source, the 30-minute stamp window, whether `skill-versioning` keeps its name, whether CI runs the skill test suites as well as `verify`, and Rule 17 Windows support. Ask; do not choose.

**Confirm the CI correction.** The design doc and `skill-distribution-workflow.md` disagree about where the bump happens. The recommendation is merge-time, and the evidence is the `#41`/`#42` collision, but the user should confirm before the implement doc bakes it in.

**One thing is genuinely unverified and gates treehouse adoption.** From `docs/worktree-workflow.md`: what `treehouse return` does with unpushed commits left on a branch. Idle slots are observed detached across all 15, but nothing was tested against a slot carrying unpushed work. Test it before the implement doc depends on it.

### Read in this order

1. `CLAUDE.md` at the repo root, all 17 rules. Rule 14 (Podman) and Rule 16 (versioning) both change in this work.
2. `HYDRATION.md`, this entry only.
3. `docs/superpowers/specs/2026-08-23-skills-package-manager-design.md` in full.
4. `docs/skill-distribution-workflow.md`, 81 lines. It overrides the design doc on CI.
5. `docs/worktree-workflow.md`, and especially "After the compaction" at the bottom.
6. `notes/skills-pm-discovery.md` only if you need the measurements behind a decision.
7. `claude/skills/skill-versioning/scripts/skill-version.sh`, `render_registry` at line 115, and `cmd_verify` at 174.

There is no `CONTEXT_STATE.md` in this repo.

### Reuse, it is proven

| Thing                                   | What it gives you                                                           | Sharp edge                                                                                        |
| --------------------------------------- | --------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------- |
| `skill-update.sh`                       | fetch a skill from GitHub with no dotfiles checkout; worktree-based PR flow | its `--mode inline` / `--mode standalone` split only means anything when the skill dir is tracked |
| `skill-version.sh verify`               | a pure pass/fail check, ideal as a CI gate                                  | also enforces the read-only notice and its per-skill URL, not just versions                       |
| `treehouse` v2.3.0, `~/.local/bin`      | worktree pool, self-updating Go binary                                      | v2.0.0 removed `destroy --force`; scripts using it broke 2026-08-23                               |
| `.claude/cache/`                        | already gitignored, declared derived, never pruned by `cache.sh`            | deleting it also deletes the sync tool's `.bak`                                                   |
| `project-scaffold/testing/`             | 14 numbered cases, `assert.sh`, `run-tests.sh`                              | the pattern to copy for testing `skill-sync.sh`                                                   |
| The `-axi` tools on `~/.npm-global/bin` | precedent for a PATH binary invoked from a `SessionStart` hook              | they run at `timeout: 10`; a cold skill sync needs more                                           |

### The verification ladder

1. `git grep` for the symbol. Catches a design doc referring to something that does not exist.
2. `bash -n` on any script. Catches the syntax error before a container spins up.
3. `skill-version.sh verify` locally. Catches an unversioned skill, a missing read-only notice, and a stale registry. It has caught all three.
4. The skill's own `testing/run-tests.sh` in Podman, per Rule 14 and `claude/skills/container-sandbox/references/skill-testing.md`.
5. A real session in a scratch repo, for anything touching the `SessionStart` hook. The hook only proves itself by firing.

Rung 5 matters more than usual here. The current session-start check is prose that an agent may or may not follow, and the entire point of this work is replacing it with something that cannot be skipped. That property is unobservable from a unit test.

### Traps, already paid for

- Untracked files in the working directory are invisible to a session that starts in a worktree. A whole session re-derived decided work because `docs/*.md` were never committed.
- `cannot remove a locked working tree` after a successful merge. A hand-rolled worktree pinning the branch. Hit twice now, once on 2026-08-23 and once in the design session. treehouse's detached-HEAD-when-idle invariant is the fix.
- Two PRs allocating the same version. Both were correct against their own snapshot of `main`. Git caught it only because they touched the same lines - the collision was semantic, the detector textual.
- `-p` in a `claude` launch command. It is `--print`: prints a reply and exits, so no session ever starts. The failure produces plausible output rather than an error.
- Overwriting a running bash script in place. Bash reads lazily by byte offset, so it reads garbage from wherever it had reached. `mv` preserves the inode; `cp` truncates it.
- A `SessionStart` hook that exits non-zero takes the session with it. Always exit 0, and print the failure loudly instead.

### Workflow

No work order exists for this phase, so there is no `work-order.sh` sequence to run. Tickets get cut in phase 5, from this document.

```sh
# isolated workspace
WT=$(treehouse get --lease --lease-holder "skills-pm-implement-doc")
cd "$WT"
git switch -c feat/skills-pm-implementation-doc

# ... write the implement doc, and the design-doc corrections ...

git add -A && git commit
git push -u origin HEAD
gh pr create --base main
gh pr merge <N> --squash --delete-branch

# close out
git checkout main && git fetch origin --prune && git merge --ff-only origin/main
treehouse return "$WT" --if-lease-holder "skills-pm-implement-doc"

HP=~/.claude/skills/hydration-prompt/scripts/hydration.sh
bash $HP add --project . --title "..." --body-file /tmp/entry.md
bash $HP command --project .
```

Docs-only changes touch nothing under `claude/skills/`, so no version bump and no registry regeneration are required. The moment a template or script is edited, Rule 16 applies.

### Conventions

Ticket references carry the ID **and** the full title, joined by a dash, on every mention. A bare ID is a defect.

No em dashes anywhere, plain dashes only. No agent co-author lines in commits. No Claude attribution footer in a PR body, ever, per Rule 13.

Feature branches only; `main` is never written directly. All testing runs in Podman per Rule 14. Pin every version to an immutable digest per Rule 15; `:latest` is banned.

Report failing tests as failing, and say plainly what was skipped. "Completed" is wrong if anything was silently left out.

