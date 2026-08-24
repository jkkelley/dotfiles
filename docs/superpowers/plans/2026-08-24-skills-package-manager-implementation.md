# Skills package manager - implementation plan

Date: 2026-08-24
Status: ready to size. This is the input to poker (phase 4) and to ticket cutting (phase 5).
Binding design: [`2026-08-23-skills-package-manager-design.md`](../specs/2026-08-23-skills-package-manager-design.md)
Also binding: [`docs/skill-distribution-workflow.md`](../../skill-distribution-workflow.md) on merge-time allocation
Backlog reconciled: [`docs/worktree-workflow.md`](../../worktree-workflow.md), "After the compaction"

> **For agentic workers:** this document does not write code.
> It fixes build order, file layout, and test strategy so that phase 5 can cut tickets from it and phase 6 can execute them one at a time.

## What this plan does not do

It does not reopen the design.
The twenty decisions listed below are closed, and an implementation that finds one of them unbuildable **stops and says so** rather than quietly substituting a different design.

It does not decide the two things the design doc deliberately left open in its "Open, not designed here" section.
Those stay there.

## Two epics, and why it is not one

**Epic 1 proves the path with one skill.**
Every moving part exists after Epic 1 - the trailer, the PR gate, the test matrix, the merge-time bump, registry schema 2, the sync tool, the hook - but exactly one skill has been through it.

**Epic 2 carries the remaining 42 through the procedure Epic 1 proved**, plus the template and onboarding work that makes a project able to receive them, closing with the rename.

The split is not cosmetic.
Epic 1's failure mode is "the design was wrong", which is cheap to discover on one skill and expensive on 43.
Epic 2's failure mode is "we missed a project", which is a checklist problem, not a design problem.

## Decisions this plan adds

The design doc closed eighteen.
Two more were closed on 2026-08-24, in the session that produced this document.

| #   | Decision                                                                                                                         |
| --- | -------------------------------------------------------------------------------------------------------------------------------- |
| 19  | **The treehouse pool stays user-level**, at `~/.treehouse/<repo>-<hash>/`. In-project `--root .` is rejected                     |
| 20  | **`project-scaffold`'s default manifest is four skills**: `work-order`, `living-docs`, `container-sandbox`, `context-compaction` |
| 21  | **`type` is derived from the tree, never declared. `requires` is an optional frontmatter key**, and `verify` resolves it         |

### 19, and the measurement behind it

A slot's weight is not the repository.
`.git` inside a slot is a 108-byte pointer file, so git objects are never duplicated.
The weight is build cache written inside the slot: one measured slot carries 171M of `.cache` for a repository whose tracked content is under a megabyte.

`--root .` puts that cache inside the working tree, which is the thing this repo mounts into containers:

```sh
podman run --rm -v "$PWD:/work:ro,Z" ...
```

Every container test under Rule 14 would bind and relabel the pool on every run, `podman build .` would take it as build context, and `git add -A` would stage another branch's cache unless a gitignore line that does not exist today is added to `gitignore.tmpl` and to every existing repo.

The counter-argument is real and is accepted rather than dismissed: `~/.treehouse/dotfiles-ff4128/` is a hash directory, `ff4128` cannot be reconstructed by hand, and the pool name does not say where its repository lives.
That is a discoverability cost, paid with one paragraph in the template and `treehouse status`.
It is not a structural cost.

### 20, and why an empty default would ship broken

`project-scaffold` vendors no skills today, but its `CLAUDE.md` template references `work-order` in six places.
A scaffolded project whose manifest omits `work-order` therefore arrives with a template pointing at a script that is not installed.
`living-docs` declares `work-order` as a hard `requires` edge, so it would pull it in regardless.

## The gate, answered

`docs/worktree-workflow.md` carried one unverified claim, listed as item 1 of "After the compaction" and marked as gating everything else: what `treehouse return` does with unpushed commits.

Probed on 2026-08-24 in Podman per Rule 14, using the pattern now documented in `container-sandbox`'s "Verifying a host CLI's behaviour" section - real `treehouse` v2.3.0 bind-mounted read-only, throwaway origin, `TREEHOUSE_ROOT` redirected inside the container, so the live pool was never touched.

| Case                                | Observed                                                                                                               |
| ----------------------------------- | ---------------------------------------------------------------------------------------------------------------------- |
| unpushed commit, plain `return`     | **survives.** rc 0, slot resets to detached HEAD, the branch ref remains in the repository, the object stays reachable |
| unpushed commit, `return --force`   | **survives.** `--force` cleans the worktree, not the refs                                                              |
| uncommitted changes, plain `return` | **prompts, takes the no-TTY default, aborts, leaves the slot leased - and exits 0**                                    |

The first two clear the gate.
`treehouse return` is not a data-loss path, and the design's use of it in `skill-onboard.sh` holds unchanged.

The third is the finding that changes code.
A returned-slot check cannot read `$?`:

```
| Worktree has uncommitted changes. Clean and return? [Y/n] 🌳 Aborted.
  return rc                          0
  final pool state                   1  leased  (held by gate-case-3)
```

**Every script in this plan that calls `treehouse return` asserts the post-state instead.**
That is `skill-onboard.sh` in E2.1 and the `hydration-prompt` close-out in E2.8, and it is written into both acceptance criteria rather than left as a convention.

## Sequencing constraints

These are the orderings that break something if reversed.
They matter more than the task list, because a task list can be re-derived and these cannot.

### C1 - the notice check cannot invert until the last `SKILL.md` is clean

`skill-version.sh:195` today asserts the read-only notice is **present** and carries this skill's own URL.
The design's end state asserts it is **absent**.

Between the pilot and the end of the rollout the repository is in a mixed state, and neither assertion holds for all 43 skills.
A gate that asserts "present" fails the pilot PR; a gate that asserts "absent" fails the other 42.

Three steps, in this order, and no fewer:

```
E1.3  delete the present-and-correct-URL check
      verify --structure says nothing about the notice
        |
E2.6  remove the notice from the remaining 42 SKILL.md
        |
E2.7  verify --structure asserts the notice is absent
```

Skipping the middle state is the single most likely way to make the pilot PR fail its own gate.

### C2 - the repo settings land before the first trailer

Live values as of 2026-08-24: `squash_merge_commit_message=COMMIT_MESSAGES`, `allow_merge_commit=true`, `allow_rebase_merge=true`.

`COMMIT_MESSAGES` builds the squash body from the branch's commit messages, not the PR description.
A `Bump:` trailer written where the design says to write it would never reach the commit, the publisher would parse nothing, and nothing would report an error.

E1.1 therefore precedes E1.7 and E1.8, and it is the first ticket in the epic.

### C3 - the publisher must not exist before `verify` is green on `main`

The publisher's first action is `verify`, exiting 0 when it passes.
If `verify` is red on `main` for any reason, every push to `main` starts a run that tries to bump something.

`verify` is green on `main` today.
Any ticket that could turn it red - E1.3 and E1.4 both touch it - lands and is confirmed green before E1.8 merges.

### C4 - the binary is installed before the hook that calls it

A `SessionStart` hook in `~/.claude/settings.json` fires in **every project on the machine**.
A hook pointing at a `skill-sync` that is not yet on `PATH` prints a command-not-found into every session until it is fixed.

E1.9 installs the binary and the hook in that order, in one ticket, and the ticket is not done until a session in a project with no manifest starts silently.

### C5 - the sync works before any gitignore change

Gitignoring `.claude/skills/` means a fresh clone has **no skills at all** until the sync runs.
So E2.2 cannot land before the sync is proven end to end in E1.11.

This is the consequence `docs/skill-distribution-workflow.md` flagged and it is the reason the session-start check becomes "install if absent, else compare" rather than "compare and maybe update".

### C6 - the rename is the closing commit

18 references across 9 files.
Four of the affected repositories carry the **identical two lines**, and those lines are the prose session-start block that E2.10 deletes outright.

Renaming first would mean editing a path inside a block that is about to be deleted.
The rename is E2.11 and nothing follows it.

### C7 - the matcher is unconfirmed and gates the hook

Every hook in `~/.claude/settings.json` today uses `"matcher": ""`, which matches every source, so this machine has no working example of the filtered form.

The design's safety property - the sync never runs on `compact` - depends entirely on `SessionStart` matchers accepting a source string.
E1.2 confirms it before E1.9 is written.
If matchers do not filter, the fallback is already decided: `skill-sync` reads the source from the hook payload on stdin and exits early itself.

## Dependency graph

```
E1.1  repo settings ────────────────────┐
E1.2  matcher confirmed ──────────┐     │
E1.3  verify splits ──────────┐   │     │
E1.4  registry schema 2 ──┐   │   │     │
E1.5  notice partial ──┐  │   │   │     │
                       v  v   │   │     │
E1.6  skill-sync.sh ──────────┼───┼─────┼──┐
                              │   │     │  │
E1.7  PR gate <───────────────┘   │     │  │
E1.8  publisher <─────────────────┼─────┘  │
                                  │        │
E1.9  setup.sh: binary, then hook <┘───────┘
                       |
E1.10 pilot: hydration-prompt through the pipeline
                       |
E1.11 end-to-end proof in a scratch project
                       |
E1.12 root CLAUDE.md: Rule 16, the named exception, the flow
                       |
        ===============|===============  Epic 1 done, path proven
                       |
E2.1  skill-onboard.sh
E2.2  gitignore.tmpl                 (needs E1.11)
E2.3  scaffold writes skills.toml
E2.4  CLAUDE.md.tmpl
E2.5  scaffold.json removed
E2.6  notice removed from the other 42
E2.7  verify --structure asserts absent   (needs E2.6)
E2.8  hydration-prompt takes a slot
E2.9  skill-update.sh narrowed
E2.10 the four repos onboarded
E2.11 rename skill-versioning -> skill-registry   (needs E2.10)
```

## File map

| Path                                                                 | Action | Ticket     | Note                                                    |
| -------------------------------------------------------------------- | ------ | ---------- | ------------------------------------------------------- |
| `claude/tools/skill-sync.sh`                                         | create | E1.6       | the sync. Not under `claude/skills/`                    |
| `claude/tools/skill-onboard.sh`                                      | create | E2.1       | brings an existing project onto the system              |
| `claude/tools/partials/read-only-notice.md.tmpl`                     | create | E1.5       | one copy of the text that was in 43 files               |
| `claude/tools/testing/run-tests.sh`                                  | create | E1.6       | the tools tree needs its own suite, see below           |
| `claude/tools/testing/Containerfile`                                 | create | E1.6       | reuse the existing debian digest                        |
| `.github/workflows/skill-pr-gate.yml`                                | create | E1.7       | validates, tests, writes nothing                        |
| `.github/workflows/skill-publish.yml`                                | create | E1.8       | bumps and regenerates on merge to `main`                |
| `claude/skills/skill-versioning/scripts/skill-version.sh`            | modify | E1.3, E1.4 | `verify` splits; `render_registry` learns schema 2      |
| `claude/skills/skill-versioning/`                                    | rename | E2.11      | becomes `claude/skills/skill-registry/`                 |
| `claude/skills/hydration-prompt/SKILL.md`                            | modify | E1.10      | first skill to lose its notice                          |
| `claude/skills/hydration-prompt/scripts/hydration.sh`                | modify | E2.8       | acquire and release a slot                              |
| The other 42 `claude/skills/*/SKILL.md`                              | modify | E2.6       | notice removed, one PR                                  |
| `claude/skills/project-scaffold/references/templates/gitignore.tmpl` | modify | E2.2       | `.claude/skills/` blanket ignored                       |
| `claude/skills/project-scaffold/references/templates/CLAUDE.md.tmpl` | modify | E2.4       | four changes, listed under E2.4                         |
| `claude/skills/project-scaffold/scripts/`                            | modify | E2.3, E2.5 | writes `skills.toml`; stops writing `scaffold.json`     |
| `setup.sh`                                                           | modify | E1.9       | installs the binary and the machine-level hook          |
| `CLAUDE.md`                                                          | modify | E1.12      | Rule 16 rewrite, the named exception, the pipeline flow |
| `docs/worktree-workflow.md`                                          | modify | this PR    | the unverified section is answered                      |

## Epic 1 - prove the path on one skill

### E1.1 - Repo settings: squash-only, body from the PR description

No code.
Blocks every trailer-dependent ticket, so it is first.

- [ ] Apply the four settings

```bash
gh api -X PATCH repos/jkkelley/dotfiles \
  -f squash_merge_commit_title=PR_TITLE \
  -f squash_merge_commit_message=PR_BODY \
  -F allow_merge_commit=false \
  -F allow_rebase_merge=false
```

- [ ] Read them back and confirm all four
- [ ] Open a throwaway PR with a `Bump: nothing=patch` line in the body, merge it, and confirm the trailer is present in `git log -1 --format=%B` on `main`

The last step is the one that matters.
Reading the setting back proves the API call worked; reading the merged commit proves the trailer survives the path it will actually travel.

**Done when:** a trailer written in a PR description is readable by `git interpret-trailers --parse` on the resulting `main` commit.

### E1.2 - Confirm the `SessionStart` matcher filters by source

Gate for E1.9. See C7.

- [ ] In a scratch project, install a `SessionStart` hook with `"matcher": "startup"` that appends its stdin payload and the time to a file
- [ ] Start a session, resume it, clear it, and force a compact
- [ ] Record which of the four fired

**Done when:** the answer is written down either way.
If matchers filter, E1.9 uses `startup|resume|clear`.
If they do not, E1.6 gains a stdin read and an early exit, and E1.9 uses `"matcher": ""`.

This is rung 5 of the verification ladder and cannot be done any other way - the property is unobservable from a unit test.

### E1.3 - `verify` splits

- [ ] `verify --structure`: every skill has a `version:`; no `version:` or `registry.json` was hand-edited in this diff
- [ ] `verify` unchanged in meaning: the above, plus `render_registry` matching `registry.json` on disk
- [ ] **Delete** the notice check at `skill-version.sh:195`
- [ ] Do **not** add a notice-absent assertion. See C1
- [ ] Extend `skill-versioning`'s own test suite to cover both forms, including the case that motivated the split: a PR branch that edits a skill and leaves the registry alone must pass `--structure` and fail plain `verify`

**Done when:** on a branch with an edited skill and an untouched registry, `verify --structure` exits 0 and `verify` exits non-zero.

That combination is the whole point.
Today's `verify` calls that state `drifted`, and under merge-time allocation it is the correct state for every skill PR.

### E1.4 - Registry schema 2

- [ ] `render_registry` emits `"schema": 2`
- [ ] Per-skill `type`, routing only: `skill` or `agent`
- [ ] Per-skill `requires`, a hard dependency, auto-installed
- [ ] A `tools` block carrying `skill-sync` and `read-only-notice`, each with a version and a hash
- [ ] `verify` understands schema 2 and reports a schema mismatch as a distinct failure, not as drift

Per decision 21, `type` is derived from the tree it was found in and is never declared, and `requires` is an optional frontmatter key read with one line of `awk`, comma-separated, no YAML list.

- [ ] Add `requires: work-order` to `living-docs` and `cartography`, and to nothing else
- [ ] `verify` asserts every name in a `requires:` resolves to a skill that exists

**Done when:** `render_registry` reproduces `registry.json` byte for byte, the two `work-order` edges appear in it, and a deliberately typo'd `requires:` fails `verify`.

### E1.5 - The read-only notice partial

- [ ] `claude/tools/partials/read-only-notice.md.tmpl`, one placeholder for the skill name
- [ ] Its text is the current six lines, with the tool name hardcoded to `skill-sync.sh` - not a placeholder, because after this work `skill-update.sh` no longer installs synced skills and a rendered copy naming it would be wrong
- [ ] Registered in the registry's `tools` block so a change to it forces a re-render everywhere

**Done when:** rendering the template for `work-order` produces text identical to `work-order/SKILL.md:9-14` as it stands today.

Byte-identical output is the acceptance criterion because it is the only way to prove the partial is a refactor and not a rewrite.

### E1.6 - `claude/tools/skill-sync.sh`

The largest ticket in the plan.
It is a candidate for splitting at poker; if it splits, the seam is between resolution (manifest, registry, receipt, the owned set) and application (temp build, render, swap, receipt write).

- [ ] `--boot`: no `.claude/skills.toml` here, or a stamp under 15 minutes old, exits 0 and prints nothing
- [ ] Manifest parse. Minimal, hand-rolled: no TOML parser exists on Git Bash and Rule 17 says Windows is supported
- [ ] Registry fetch, three attempts, then the loud two-line failure and exit 0
- [ ] Resolve `requires` into the owned set
- [ ] Read the receipt for the previously owned set
- [ ] Sweep `.claude/cache/.sync.*` older than an hour **before** starting, because the one failure mode that skips the `trap` is a hook timeout, which is the likeliest one
- [ ] Build into `.claude/cache/.sync.XXXXXX`, render the notice into each `SKILL.md`, swap each owned directory individually
- [ ] Remove directories dropped from the manifest **only when the receipt says sync installed them**
- [ ] Touch nothing else under `.claude/skills/`. Never `rm -rf` the parent
- [ ] Write the receipt, including `owned` and `status`; write the stamp
- [ ] Self-update: `mv` to `.bak`, fork with `SKILL_SYNC_CHILD=1`, roll back on failure. The comment explaining why it is `mv` and not `cp` is part of the deliverable
- [ ] Always exit 0. Always print a failure loudly
- [ ] Rule 17: no `flock`, no `cmp`, no `diff`. Lock with `mkdir`, which is atomic everywhere

**Done when:** the suite in E1.6's testing tree passes in Podman, including the ownership matrix and the four failure modes below.

### E1.7 - `.github/workflows/skill-pr-gate.yml`

Runs on every PR. Writes nothing.

- [ ] Every skill named in a trailer exists, and actually changed in this PR
- [ ] Every level is `major`, `minor` or `patch`, and no skill is named twice
- [ ] Every changed skill resolves to a level, from a trailer or from a parseable title type
- [ ] No hand-edited `version:` and no hand-edited `registry.json`
- [ ] `verify --structure` passes
- [ ] The resolution table is printed, so the outcome is visible before merge
- [ ] `runs-on: ubuntu-24.04`, not `ubuntu-latest`

- [ ] **Detect job** emits changed skills that ship `testing/run-tests.sh`, as JSON
- [ ] **Test job** is a matrix, one runner per skill, guarded by `if: needs.detect.outputs.skills != '[]'`
- [ ] **Tools job**, separate from the matrix, runs `claude/tools/testing/run-tests.sh` when anything under `claude/tools/` changed
- [ ] Podman is installed on the runner. `ubuntu-24.04` ships Docker and Rule 14 requires Podman

The tools job is separate on purpose.
`claude/tools/` is not a skill, so it has no row in the registry and cannot appear in a matrix keyed on skill names.

**Done when:** a docs-only PR is green with the matrix skipped, and a PR editing `hydration-prompt` runs exactly one matrix leg.

Rule 15's limit is recorded here rather than worked around: runner labels cannot be digest-pinned, `ubuntu-24.04` is as close as the rule reaches, and the images inside each suite are pinned already.

### E1.8 - `.github/workflows/skill-publish.yml`

- [ ] `on: push: branches: [main]`
- [ ] `concurrency: {group: skill-publish, cancel-in-progress: false}`. Cancelling would drop a bump
- [ ] `actions/checkout` with `ref: main`, **not** the default `github.sha`
- [ ] `verify` first. Passing means there is nothing to do, exit 0. This is the loop guard and it is free
- [ ] Changed skills from `git diff --name-only <before>..<after> -- claude/skills/`
- [ ] Levels from `git log -1 --format=%B | git interpret-trailers --parse`
- [ ] A skill absent from the registry gets `skill-version.sh init` at 1.0.0 and needs no trailer
- [ ] An unresolvable level **fails the run and bumps nothing**
- [ ] Commit and push with `GITHUB_TOKEN`

**Done when:** two PRs merged back to back produce correct versions for both skills, and the second run exits 0 having found nothing to do.

That is the batching case, and it is why `ref: main` is not a detail.
The default checkout would put the first run on a tree that is no longer `main`, and its push would be rejected non-fast-forward whether or not the runs are serialised.

Failing closed is asymmetric on purpose.
A missing bump leaves the old version and old hash in the registry, so projects keep the skill they already have - stale, safe, and `verify` stays red until someone fixes it.
A guessed bump ships a breaking change to every project as a patch.

### E1.9 - `setup.sh` installs the binary, then the hook

Order within the ticket is not cosmetic. See C4.

- [ ] Install `skill-sync` to `~/.local/bin/`, beside the existing `-axi` tools
- [ ] Then add the `SessionStart` hook to `~/.claude/settings.json`, `timeout: 30`
- [ ] Matcher per E1.2's answer
- [ ] Idempotent: running `setup.sh` twice does not produce two hooks

**Done when:** a session started in a project with no `.claude/skills.toml` prints nothing at all.

Silence in the no-manifest case is the acceptance criterion because that is the state of almost every project on the machine, and a hook that is noisy there will be removed by whoever is annoyed by it first.

### E1.10 - The pilot: `hydration-prompt` through the pipeline

- [ ] Remove the notice from `claude/skills/hydration-prompt/SKILL.md`, and only that file
- [ ] Open the PR with the `Bump:` trailer in the description
- [ ] Confirm the PR gate prints the resolution table and runs exactly one matrix leg
- [ ] Merge, and confirm the publisher bumps the version and regenerates the registry on `main`
- [ ] Confirm `verify` is green on `main` afterwards

`hydration-prompt` is the pilot because it ships a test suite, so the matrix is genuinely exercised, and because it is used every session, so a break is visible immediately rather than in three weeks.

**Done when:** `main` carries a bumped `hydration-prompt` that nobody bumped by hand.

### E1.11 - End-to-end proof in a scratch project

Rung 5. The hook only proves itself by firing.

- [ ] A scratch repository with a `.claude/skills.toml` naming `hydration-prompt`
- [ ] Start a session. Confirm the skill is installed, with the notice rendered into it
- [ ] Confirm a hand-authored skill sitting beside it is untouched, unread and unreported
- [ ] Remove `hydration-prompt` from the manifest, re-sync, confirm it is removed
- [ ] Delete the receipt, re-sync, confirm nothing is deleted

The last two are the ownership rule, and the last one is the one worth the ticket.
A lost receipt must orphan a managed directory, never delete a local one.

**Done when:** all five hold, and the receipt records `owned` correctly at each step.

### E1.12 - Root `CLAUDE.md`

Last in the epic, because it documents what now exists rather than what is planned.

- [ ] Rule 16 rewritten: CI allocates at merge, a PR carries intent, `verify --structure` gates
- [ ] The named exception added to the never-write-`main` rule, in the wording the design doc fixes
- [ ] The pipeline flow documented here, per decision 17, because this repo's `CLAUDE.md` is where the point of the dotfiles project is explained
- [ ] `skill-update.sh` stated explicitly as the hand-authored-skill path and nothing else

**Done when:** an agent reading only root `CLAUDE.md` can describe the whole path from a skill edit to a project receiving it.

## Epic 2 - roll it out

### E2.1 - `claude/tools/skill-onboard.sh`

- [ ] Takes a treehouse slot with `--lease-holder skill-onboard`. Never touches the user's working tree, never stashes
- [ ] Writes `.claude/skills.toml`, the gitignore lines, and the `CLAUDE.md` block
- [ ] `git rm -r --cached .claude/skills/` only where they were committed
- [ ] Commits, pushes, opens a PR, squash-merges, deletes the branch
- [ ] Returns the slot **and asserts it is free afterwards**, per the gate finding. Reading `$?` is not sufficient

**Done when:** run against a scratch repository with committed skills, it lands a merged PR and leaves no leased slot behind.

No hook is installed by this script.
The hook is machine level and `setup.sh` owns it, which is most of why this script no longer needs to be as large as it was first sketched.

### E2.2 - `gitignore.tmpl` ignores `.claude/skills/`

Blocked on E1.11. See C5.

- [ ] Blanket ignore for `**/.claude/skills/`, beside the existing agents line

**Done when:** a project scaffolded from the template cannot commit a skill.

### E2.3 - `project-scaffold` writes `.claude/skills.toml`

- [ ] The four from decision 20, plus an empty `[agents]` block with a comment explaining what it is for

**Done when:** a freshly scaffolded project syncs those four on its first session and its `CLAUDE.md` template's `work-order` references resolve.

### E2.4 - `CLAUDE.md.tmpl`, four changes

- [ ] Replace roughly 68 lines of session-start prose (`CLAUDE.md.tmpl:269-336`) with the short block from the design doc
- [ ] Add the `skills:begin` / `skills:end` markers for the generated table. **The sync writes it**, not `scaffold.sh`
- [ ] Add the treehouse policy section, naming `~/.treehouse/<repo>-<hash>/` per decision 19 and pointing at `treehouse status`. Pointer, not manual
- [ ] Add the documentation-lifetime rule, which arbitrates between `local-k8s-docs` and `living-docs` writing to `<project>/docs/sops/`

**Done when:** the template names one destination for a document and one source for a workspace.

On the second bullet: the design doc's body specifies the sync as the writer, and its "Open" list also carries the question.
The body wins - it is the more specific statement, and the sync is the only actor that knows what actually landed.
The stale line in the "Open" list is noted here rather than left to be rediscovered.

Names only, never versions.
A hand-maintained version table is wrong within a week, and a stale one is worse than none because agents believe it.

### E2.5 - `.claude/scaffold.json` removed

- [ ] `project-scaffold` stops writing it
- [ ] Anything reading it moves to the receipt

**Done when:** `git grep scaffold.json` returns nothing outside history.

### E2.6 - The notice leaves the other 42 `SKILL.md`

One PR. See C1.

- [ ] Remove lines 9-14 from all 42 remaining skills
- [ ] Frontmatter untouched: `name`, `description`, `version`, in that order
- [ ] **No trailers.** Title the PR `fix(skills): remove the inline read-only notice, now rendered at install`

The title is the mechanism, not a style choice.
The publisher's fallback gives every changed-but-unlisted skill the title's conventional level, so one `fix` title produces 42 patch bumps automatically.
42 hand-written trailers would be 42 chances to typo a skill name.

**Done when:** 42 skills go up one patch level in a single publish run, and no `SKILL.md` in the repository contains the notice.

### E2.7 - `verify --structure` asserts the notice is absent

Blocked on E2.6.

- [ ] The assertion inverts: a notice **present** in an upstream `SKILL.md` is now a failure
- [ ] The failure message says why, because the obvious reaction to it is to paste the notice back

**Done when:** pasting the notice into any `SKILL.md` fails the PR gate.

This is what stops a doubled notice appearing in installed copies, where one is rendered and one was committed.

### E2.8 - `hydration-prompt` acquires and releases the slot

Item 5 of the backlog, unblocked by the gate.

- [ ] The close-out acquires a slot with the ticket ID as `--lease-holder`
- [ ] It returns the slot and **asserts the slot is free**, per the gate finding
- [ ] `treehouse status` becomes the live map of which agent holds which workbench, keyed by ticket ID

**Done when:** a close-out that leaves a dirty tree reports a failure instead of reporting success and leaking a slot.

### E2.9 - `skill-update.sh` narrows to hand-authored skills

- [ ] Header states the split explicitly: this is for hand-authored skills, `skill-sync` owns everything in a manifest
- [ ] `--mode inline` / `--mode standalone` survive, for that case only

**Done when:** the header answers "should I be running this?" without reading the body.

### E2.10 - The four repositories carrying the stale block

Four repositories carry the identical two-line prose session-start check that this design deletes.

**This ticket does not edit them from a dotfiles session.**
It delivers `skill-onboard.sh` (E2.1) and a checklist naming each repository and the lines to remove.
Running it against each repository is a deliberate act in that repository, not a change propagated outward from here.

- [ ] The checklist exists, one row per repository, with file and line numbers
- [ ] Each row is checked off only after that repository's own PR merges

**Done when:** no repository on the list still carries the prose block, and each was changed by a run of `skill-onboard.sh` inside it.

### E2.11 - Rename `skill-versioning` to `skill-registry`

The closing commit. See C6.

- [ ] `git mv claude/skills/skill-versioning claude/skills/skill-registry`
- [ ] Update the remaining references, which by now exclude the four deleted by E2.10
- [ ] `skill-version.sh` keeps its filename. The skill is renamed, the script is not
- [ ] Major bump: `Bump: skill-registry=major`. A renamed skill breaks a consumer's existing usage

**Done when:** `git grep skill-versioning` returns nothing, and `verify` is green.

No compat symlink.
`skill_dirs()` uses `find -type d`, which does not match symlinks to directories, so a compat symlink would be invisible to the registry - it would hide the breakage rather than surface it.

The name is wrong in a specific way that this fixes: after this work the skill owns three publish-side things, consumers never touch it, and "versioning" is precisely the part CI took over.

## Test strategy

This section answers the third item in the design doc's "Open, not designed here" list.

Rule 14 governs: every command whose purpose is to verify something runs in Podman, with no threshold.

### Where the suites live

| Tree                    | Suite                               | Run by                                  |
| ----------------------- | ----------------------------------- | --------------------------------------- |
| `claude/skills/<name>/` | `testing/run-tests.sh`              | the PR gate matrix, changed skills only |
| `claude/tools/`         | `claude/tools/testing/run-tests.sh` | the PR gate tools job                   |

`claude/tools/` needs its own suite and its own job because it is not a skill.
It has no registry row and cannot appear in a matrix keyed on skill names.

### The image

Reuse `debian@sha256:328d1649...`, already pinned in `work-order/testing/Containerfile` and `cartography/testing/Containerfile`.
Introducing a second base digest for the same purpose is how a repository ends up with two answers to "what do the tests run on".

Built with the network on, run with `--network=none`.
The build is the only step allowed to fetch, and the sync's own tests must prove they reach nothing.

### What `skill-sync.sh`'s suite must cover

The happy path is the least interesting part.
A green happy path cannot tell a working guard from a decorative one.

**The ownership matrix, all four rows.**
This is the highest-value group in the suite, because a wrong answer in the last row silently deletes hand-authored work in a gitignored directory - no diff, no recovery, nothing to notice it by.

| In the manifest | In the receipt | Assert                             |
| --------------- | -------------- | ---------------------------------- |
| yes             | yes            | replaced                           |
| yes             | no             | installed                          |
| no              | yes            | removed                            |
| no              | no             | **untouched, and never even read** |

Plus: a missing receipt collapses to "sync owns nothing", so nothing is deleted.
Plus: a corrupt receipt does the same, rather than throwing.

**The registry is unreachable.**
Stub `curl` per `skill-testing.md`'s "Stubbing an external CLI" section.
Assert three attempts, the two-line loud warning, `status: failed` in the receipt, an untouched tree, and **exit 0**.

Exit 0 on failure is the assertion most likely to be written backwards by someone who has just read that failures should be loud.

**A kill mid-sync leaves the previous state intact.**
Kill the process during the build phase, assert every owned directory is still the previous version and none is half-written.

**The stale temp sweep.**
Plant a `.sync.` directory with an old mtime, run, assert it is gone.
Plant a fresh one, assert it survives.
`trap ... EXIT` does not fire on a hard kill, which is exactly what a hook timeout is, so the sweep is the only thing covering the likeliest failure.

**Self-update rolls back.**
Serve a deliberately broken replacement, assert the `.bak` is restored and the failure is reported.
Assert the recursion is one deep, via `SKILL_SYNC_CHILD`.

**Rule 17.**
Assert the script calls no `flock`, no `cmp`, no `diff`.
A grep over the source is a legitimate test here: the failure mode on Git Bash is a lock timeout that never happened, which is untraceable from the symptom.

**The lock is real.**
Per `skill-testing.md`, a script that claims to take a lock has that claim tested.
Two concurrent syncs, assert one waits and neither corrupts the tree.

### What the notice partial's tests must cover

- [ ] Rendering for a given skill produces the exact current text for that skill
- [ ] Rendering is idempotent: a `SKILL.md` that already has a rendered notice does not get a second one
- [ ] Insertion lands after the first `# ` heading, not before it and not in the frontmatter

### Determinism

Per `skill-testing.md`: no wall-clock dependence, no network in the cases, injected time where a stamp or a sweep window is under test.
The 15-minute stamp and the 1-hour sweep are both time-dependent and both must be tested with injected time rather than by sleeping.

## Reconciliation with "After the compaction"

`docs/worktree-workflow.md` carries a six-item backlog that predates the design.
It is not a separate stream, and this is where each item lands.

| #   | Backlog item                                  | Lands as                  | Note                                                    |
| --- | --------------------------------------------- | ------------------------- | ------------------------------------------------------- |
| 1   | Test `treehouse return` with unpushed commits | **done, this session**    | Answered above. Item 3 of the probe changes two tickets |
| 2   | In-project pool vs `~/.treehouse/`            | **closed as decision 19** | User-level. No migration                                |
| 3   | Gitignore `<project>/.claude/skills/`         | E2.2                      | Blocked on E1.11, per C5                                |
| 4   | treehouse policy section in the template      | E2.4, third bullet        | Unblocked by decision 19                                |
| 5   | `hydration-prompt` acquires and releases      | E2.8                      | Unblocked by item 1                                     |
| 6   | GitHub Actions bumps at merge                 | E1.1, E1.7, E1.8          | The largest of the six, and the reason Epic 1 exists    |

Items 1 and 2 are closed by this document.
The other four are tickets.

## Decision 21, closed 2026-08-24

This section was "One decision this plan cannot make". It is closed, and the full argument now lives in the design doc under "Where `type` and `requires` come from". The short version, because it unblocks E1.4 and therefore E1.6:

**`type` is not a decision.** It is routing, and the thing already sits in `claude/skills/<name>/` or `claude/agents/<name>.md` upstream. `render_registry` walks those trees to find the entries at all, so declaring the type would write down a fact the filesystem states and create a second source of truth that can disagree with the first.

**`requires` is an optional frontmatter key** on the skill that has the dependency. Absent in 41 of 43 files. Comma-separated, never a YAML list, because Rule 17 makes Git Bash supported and a bracket list needs a real parser where `requires: a, b` needs one line of `awk`.

**The cost this plan originally claimed for that option was wrong.** It said frontmatter would stop being exactly `name`, `description`, `version`. But the agents in `claude/agents/` already carry `tools:` and `model:`, and `skill-version.sh` reads only `version:` - appending it as the last frontmatter key when it is missing, which already assumes an open-ended key set. Nothing enforces three keys and nothing ever did.

The two alternatives lost on **where the fact lives**, not on cost. A table inside `skill-version.sh` is fewer characters and records `cartography`'s dependency inside another skill's script, where the person who needs it is editing a file that never mentions it. A `skill.toml` per skill adds a second format and a second thing to go stale.

**`verify` gains one assertion** and that is what earns the key its keep: every name in a `requires:` resolves to a skill that exists. Free, because `verify` already walks every skill, and it turns a typo'd dependency into a failed PR gate rather than a failed first sync days later in someone else's project.

## Risks

**The pilot passes and the rollout still surprises us.**
42 skills is 42 chances for a `SKILL.md` that does not match the shape the partial expects.
Mitigation: E2.6 asserts byte-level equality of the removed block against the rendered template before removing anything.

**The hook is noisy in unrelated projects.**
It fires in every project on the machine.
Mitigation: E1.9's acceptance criterion is silence in the no-manifest case, and that is checked before the hook ships.

**`verify` goes red on `main` and every push starts a publish run.**
Mitigation: C3. Nothing that can turn `verify` red merges after E1.8.

**A dropped bump goes unnoticed.**
The publisher fails closed, which means a real failure looks like "nothing happened".
Mitigation: `verify` stays red on `main` until it is fixed, which is visible on the next push.

## Estimate shape, for poker

Not points. The shape the sizing conversation should start from.

| Ticket              | Shape                                                                        |
| ------------------- | ---------------------------------------------------------------------------- |
| E1.1, E1.2          | small, but both are gates. Nothing after them starts until they are answered |
| E1.3, E1.5, E1.9    | small, well-bounded                                                          |
| E1.4                | small. Decision 21 closed it; nothing blocks it now                          |
| E1.6                | **large.** The split seam, if it splits, is resolution against application   |
| E1.7, E1.8          | medium each. Mostly YAML, but the failure modes are subtle                   |
| E1.10, E1.11, E1.12 | small. E1.11 is manual and cannot be automated - that is the point of rung 5 |
| E2.1                | medium                                                                       |
| E2.2 - E2.5, E2.9   | small each, all `project-scaffold`. A candidate to bundle at poker           |
| E2.6                | medium, mechanical, and the riskiest mechanical change in the plan           |
| E2.7, E2.8          | small                                                                        |
| E2.10               | small per repository, four of them, and each is run in that repository       |
| E2.11               | small, and it must be last                                                   |
