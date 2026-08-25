# HYDRATION.md

The prompt that starts the next session, and the 10 before it.

**Read the top entry only.** It is the current one and it is complete on its own.
Everything below it has been superseded and is kept for history, not for reading.

**Newest on top.** Adding an entry removes the oldest in the same commit, so this
file holds exactly 10 once it has filled up. Entries are never renumbered and
never edited in place - a correction is a new entry.

Written by `hydration.sh add`. Do not hand-edit.
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

<!-- hydration-entry: WO-20260824-2ad1 -->
## WO-20260824-2ad1 - PR gate workflow: validate the bump intent and run the affected suites
_Generated 2026-08-24 by hydration.sh. Newest entry._

### Ticket

`WO-20260824-2ad1` - `PR gate workflow: validate the bump intent and run the affected suites`.
Both of its dependencies are `done`: `WO-20260824-6acf` - `Split verify into a structure check and a full check, and delete the notice assertion`, and `WO-20260824-efb0` - `skill-sync.sh part two: build, swap, receipt, and self-update`, which merged as PR #65.
`work-order next` returns it first.

It blocks `WO-20260824-316d`, and `WO-20260824-360d` - `Publish workflow: allocate versions on merge to main and regenerate the registry` is the other half of the same pipeline: this one reads and refuses, that one writes.

Poker put it at 8, above the plan's medium. Three non-trivial shell blocks inside YAML, and CI has the worst iteration loop in the plan - every fix costs a push.

### What just landed

`claude/tools/skill-sync.sh` is complete at version `2.0.0`. It resolves *and* applies: sweep, lock, build into `.claude/cache/.sync.XXXXXX`, render the notice, swap each owned directory individually, remove only what the receipt claims, write the receipt and the stamp, then replace itself if the registry publishes a newer version.

The suite went from 80 checks to **193**, and it is the thing your matrix has to run. `claude/tools/testing/run-tests.sh` re-execs itself into Podman, so a runner that invokes it directly gets the container for free - but only if Podman is on the runner, which is a checkbox on your ticket.

Three decisions were taken in the open and are notes on that ticket rather than in either design document: the lock has its own five-minute stale window separate from the build sweep's hour, a failed sync deliberately does not write the stamp, and the receipt's `source` is `jkkelley/dotfiles@main` rather than `@<sha>` because a codeload fetch does not yield one.

Two bugs part one shipped were found by the new cases and fixed in the same PR. `load_registry` read its awk output with `IFS=$'\t'`; a tab is IFS whitespace, so bash collapsed two of them and every skill with an empty `requires` - 41 of the 43 - shifted its version into the next field. And the lock is a directory inside `.claude/cache/`, so a project on its first ever sync could not take it.

Suites at the moment you start: `claude/tools/` **193**, `skill-versioning` 103, `work-order` 299 across 22 case files, repo-local `testing/` 36. All green in Podman on digest-pinned bases with `--network=none`.

### What is NOT done

`git ls-files .github/workflows` still prints nothing. **The directory does not exist.** You are creating it, and `skill-pr-gate.yml` is the first file in it.

Branch protection is still absent and is still on no ticket. Your gate is the thing that would eventually be required, but requiring it is not your ticket either.

The publisher, `.github/workflows/skill-publish.yml`, is `WO-20260824-360d` - `Publish workflow: allocate versions on merge to main and regenerate the registry`. Do not write half of it here. Your workflow writes nothing at all, which is the scope line worth holding: the gate reads and refuses.

`setup.sh` installing the binary and the SessionStart hook is `WO-20260824-bb0d` - `setup.sh installs the skill-sync binary, then the SessionStart hook`. Removing the notice from any `SKILL.md` is epic 2.

### Stale or false in the docs

Both design documents still state the repository settings as `squash_merge_commit_message=COMMIT_MESSAGES`, `allow_merge_commit=true`, `allow_rebase_merge=true` - at `C2` in the plan and under `Repo settings, first` in the spec. All three were changed by `WO-20260824-cc71` - `Repo settings: squash-only, with the commit body taken from the PR description`. **This one bears directly on you**: the `Bump:` trailer arrives in the squash commit body because the body is the PR description, and the spec's paragraph explaining why a trailer in the description would never reach the commit is describing settings this repository no longer has.

Both also still carry the `SessionStart` matcher question as open, at `C7` and `E1.2` in the plan and under `Problem A` in the spec. It was answered by `WO-20260824-0615` - `Confirm whether a SessionStart hook matcher filters by source`. It bears on `WO-20260824-bb0d`, not on you.

`E1.6` in the plan is now fully ticked, both halves. So are the three boxes under `What the notice partial's tests must cover`.

Rule 16 does not bind this ticket unless you touch something under `claude/skills/`. `.github/workflows/` is neither a skill nor a registered tool, so nothing is owed - but `skill-version.sh verify` must still be green before the PR, and your workflow is the thing that will run it on everyone else's.

### Your scope

The plan's `E1.7` is the checklist, in order, and it is two jobs plus a matrix rather than one.

- **Validate the intent.** Every skill a trailer names exists and actually changed in this PR; every level is `major`, `minor` or `patch`; no skill named twice; every changed skill resolves to a level from a trailer or a parseable conventional title.
- **Refuse a hand-edited `version:` or `registry.json`.** Those are CI's files now.
- **`verify --structure`**, which is the split `WO-20260824-6acf` - `Split verify into a structure check and a full check, and delete the notice assertion` delivered for exactly this call site.
- **Print the resolution table**, so the outcome is readable before the merge button rather than after it.
- **Detect job** emits changed skills that ship `testing/run-tests.sh`, as JSON. **Test job** is a matrix, one runner per skill, guarded by `if: needs.detect.outputs.skills != '[]'`.
- **A separate tools job** for `claude/tools/`, which has no registry row and cannot appear in a matrix keyed on skill names.
- **Podman on the runner.** `ubuntu-24.04` ships Docker and Rule 14 requires Podman.
- `runs-on: ubuntu-24.04`, never `ubuntu-latest`.

Out: writing anything. The gate only reads.

### Before you start

`AC-H1` is the one that only shows up live: an empty matrix is a workflow error, not a skipped job, unless the `if:` guard is there. A docs-only PR is the common case and it must be green.

Decide how a level is resolved before writing the YAML, because the trailer and the title are two sources and the precedence between them is a decision the plan states but does not defend.

### Read in this order

1. Root `CLAUDE.md`. Rules 12, 14, 15 and 16 all bear on this one, and Rule 15's limit on runner labels is recorded in the plan rather than worked around.
2. This entry, the top entry of `HYDRATION.md`. Read only this one.
3. The ticket: `work-orders/WO-20260824-f1a5/WO-20260824-2ad1-pr-gate-workflow-validate-the-bump-intent-and-ru.md`.
4. `docs/superpowers/plans/2026-08-24-skills-package-manager-implementation.md` section `E1.7`, and `The test matrix`.
5. `docs/superpowers/specs/2026-08-23-skills-package-manager-design.md`, sections `The `Bump:` trailer`, `The PR gate`, `verify splits` and `Failure is closed, not guessed`.
6. `claude/skills/skill-versioning/scripts/skill-version.sh`, the `verify` path, which is what the gate calls.
7. `claude/tools/testing/run-tests.sh`, the first 51 lines: it re-execs into Podman itself, which decides what the tools job actually has to do.

### Reuse, it is proven

Every suite in this repository re-execs into its own container and is invoked the same way, so the matrix leg is one line per skill rather than a per-skill recipe.

`skill-version.sh verify` already exits non-zero with a readable message on every condition your gate needs to refuse. Call it; do not re-implement its checks in YAML.

### The verification ladder

Rung 1, free: `actionlint` or a YAML parse. A workflow that does not parse is a push wasted.

Rung 2: a docs-only PR. Green, matrix skipped, no empty-matrix error. That is `AC-H1`.

Rung 3: a PR editing `hydration-prompt`. Exactly one matrix leg. That is `AC-H2`.

Rung 4: a PR whose trailer names a skill it did not change. Refused, and the message says which. That is `AC-H3`.

Rung 5: a PR touching `claude/tools/` runs the tools job and not the matrix.

Rung 6: `skill-version.sh verify` still green, and all four suites still at 193, 103, 299 and 36.

### Traps, already paid for

An empty matrix is a workflow error rather than a skipped job. The `if:` guard on the matrix job is not defensive, it is load-bearing, and it is the one thing that cannot be proved locally.

`ubuntu-24.04` ships Docker, not Podman. A suite that re-execs into Podman fails on a runner where Podman is absent, and the error names the missing binary rather than the missing install step.

CI iteration costs a push each time. Everything that can be checked locally - YAML parse, the shell blocks run as plain scripts against a fixture - should be, before the first push.

A `grep -q` in a pipeline reports "no match" when it matched: `grep -q` closes the pipe on the first hit, the upstream dies of SIGPIPE, and `pipefail` turns that into a non-zero pipeline. Capture to a variable and grep the variable.

A markdown formatter re-pads tables in a file you only meant to add one line to. It is a `PostToolUse` hook in the machine's global `~/.claude/settings.json`, not in this repository. `git diff --stat` before committing; a two-line change reporting forty is this.

`work-order.sh start` refuses with "working tree is dirty", and `git rebase` refuses immediately after `start` because `start` leaves the ticket file, `INDEX.md` and the epic README uncommitted. Commit them first.

A command reports success and did nothing. Assert the post-state, never `$?` alone.

### Workflow

```bash
WO=claude/skills/work-order/scripts/work-order.sh
HP=claude/skills/hydration-prompt/scripts/hydration.sh
SV=claude/skills/skill-versioning/scripts/skill-version.sh

bash $WO show    --project . --id WO-20260824-2ad1
bash $WO start   --project . --id WO-20260824-2ad1   # creates the branch, leaves files uncommitted

# ... write .github/workflows/skill-pr-gate.yml, prove what can be proved locally ...

bash $SV verify                                      # this one has to be green

bash $WO evidence --project . --id WO-20260824-2ad1 --index 1 --observed "..."
bash $WO evidence --project . --id WO-20260824-2ad1 --index 2 --observed "..."
bash $WO evidence --project . --id WO-20260824-2ad1 --index 3 --observed "..."

git push -u origin <branch>
gh pr create --base main --title "..." --body-file <file>

bash $WO submit  --project . --id WO-20260824-2ad1 --pr <N>
bash $WO done    --project . --id WO-20260824-2ad1   # archives on the branch, commits nothing

bash $HP check   --project . --body-file /tmp/entry.md
bash $HP add     --project . --id <next> --title "<next title>" --body-file /tmp/entry.md

git add -A && git commit && git push                 # rides the SAME pull request

# after the merge
bash $WO cleanup --project . --id WO-20260824-2ad1   # deletes both branches, writes nothing
```

`approve` is already done for every ticket in both epics and must not be run again.

The pull request description is the merge commit body verbatim. Write it as something worth reading on `main`, because that is where it ends up - and on this ticket it is also where the `Bump:` trailer lands.

### Conventions

Every reference to a work-order in a chat reply carries the ticket ID and its full title joined by a dash. A bare ID is a defect, and so is "the next ticket" or "the blocked one".

Feature branches only, and nothing writes to `main` any more.

Rule 14 has no size threshold. A single `--help` run whose purpose is to check that something works goes in a container.

When the ticket contradicts itself, say so and pick one in the open. Both halves of `skill-sync.sh` did, and each recorded the reasoning as a note on its ticket rather than smoothing it over.

<!-- hydration-entry: WO-20260824-efb0 -->
## WO-20260824-efb0 - skill-sync.sh part two: build, swap, receipt, and self-update
_Generated 2026-08-24 by hydration.sh. Newest entry._

### Ticket

`WO-20260824-efb0` - `skill-sync.sh part two: build, swap, receipt, and self-update`.
Its only dependency, `WO-20260824-5b89` - `skill-sync.sh part one: resolution, and the tools test tree it is proved in`, is `done` and merged as PR #64.
`work-order next` returns it first.

It blocks three: `WO-20260824-2ad1` - `PR gate workflow: validate the bump intent and run the suites`, `WO-20260824-360d` - `Publish workflow: allocate versions on merge to main`, and `WO-20260824-bb0d` - `setup.sh installs the skill-sync binary, then the SessionStart hook`.

Poker put it at 8, the destructive half, sized above part one for the ownership matrix, the four failure modes and the self-update path.

### What just landed

`claude/tools/skill-sync.sh` exists at version `1.0.0`, with a `skill-tool-version:` marker and a `skill-sync` entry in the `tools` block of `claude/skills/registry.json`. `claude/tools/testing/` exists: `run-tests.sh` at 80 checks and a `Containerfile` on `debian@sha256:328d1649`, the same digest the `work-order` and `cartography` suites pin.

**It resolves and writes nothing, anywhere.** That is asserted, not asserted-by-intent: the suite hashes the whole project directory before and after a plan, a boot and a failed boot and compares.

What the script has today:

- `--boot`, `--plan`, `--help`, and a usage error on anything else. `--boot` is silent on both streams when there is no `.claude/skills.toml` here or the stamp is under 15 minutes old.
- `manifest_list`, reading `[skills]` and `[agents]`. Hand-rolled, one shape only.
- `fetch_registry`, three attempts and no sleep between them, returning 2 when `curl` is missing so that case gets its own sentence.
- `load_registry`, `json_array`, `json_string` - awk, no `jq`. `load_registry` is bounded to the skills block explicitly, because the tools block's entries have the same shape.
- `resolve`, breadth-first with a seen set. Cycles terminate.
- `emit_plan`, printing `owned` / `previous` / `dropped` / `unknown`, sorted, one tagged line per name.
- `sync_failed`, the two-line loud warning, on stdout because a hook's stdout reaches the agent's context and its stderr does not.

**The constants you need are already there and already right**: `MANIFEST=.claude/skills.toml`, `RECEIPT=.claude/cache/skills-receipt.json`, `STAMP=.claude/cache/.sync-stamp`, `STAMP_MAX_AGE=900`, `REGISTRY_URL`, `FETCH_ATTEMPTS=3`, and `NAME_RE`. Part one reads the receipt and the stamp and writes neither. They were put there so the two halves could not invent different paths for the same file - do not re-derive them.

`emit_plan` already computes `dropped`, which is exactly the set `AC-H2` turns on. You are wiring an answer that exists, not recomputing it.

Names are already validated against `NAME_RE` before they reach you, so a manifest saying `"../../etc"` never becomes a path. That check lives in `resolve` because a name becomes a directory in **your** half.

Before that: `WO-20260824-2136` - `Extract the read-only notice into a single rendered partial` put the notice in `claude/tools/partials/read-only-notice.md.tmpl`, and `WO-20260824-de9e` - `Registry schema 2, with type derived from the tree and requires read from frontmatter` gave every registry entry a derived `type` and a `requires`.

Suites at the moment you start: `claude/tools/` 80, `skill-versioning` 103, `work-order` 299 across 22 case files, repo-local `tools/` 36. All green in Podman on digest-pinned bases with `--network=none`.

### What is NOT done

Everything that writes. `grep -n 'mkdir\|rm -rf\|SKILL_SYNC_CHILD' claude/tools/skill-sync.sh` prints nothing.

- The stale `.claude/cache/.sync.*` sweep. **It was moved into your ticket** - see "Stale or false in the docs".
- The temp build, the notice render, the per-directory swap.
- Removing a dropped directory.
- The receipt write and the stamp write. Nothing writes `"status": "failed"` on the failure path yet; `sync_failed` prints and returns.
- The self-update path. `SKILL_SYNC_CHILD` appears nowhere in the repository.
- The `mkdir` lock. Part one takes no lock because it writes nothing.
- `--boot` currently ends by printing the plan and the line `skill-sync.sh: resolved N skills. This build resolves only and installs nothing.` **That line is yours to delete.** It is honest today and wrong the moment you install anything.

Still true and still on no ticket: branch protection is absent. `git ls-files .github/workflows` still prints nothing - the gate is `WO-20260824-2ad1` - `PR gate workflow: validate the bump intent and run the suites`, not you. The notice is still in all 43 `SKILL.md` files, which is epic 2.

Nothing was carried off part one. All three acceptance criteria were evidenced against the containerised run.

### Stale or false in the docs

**The `E1.6` seam moved, and the plan now says so.** `docs/superpowers/plans/2026-08-24-skills-package-manager-implementation.md` section `E1.6` has a horizontal rule in it marking the split. The five boxes above it are ticked. **The sweep box is below the rule, which means it is yours**, and that is one box higher than the hydration entry for part one implied.

The reasoning is on the ticket as a note, and it is worth reading before you argue with it: the sweep clears temp directories that only your half creates, so in part one it would have deleted nothing and no case in that suite could have produced a directory for it to find. A guard proved only against a fixture the code cannot generate is decorative.

The last three boxes in `E1.6` - always exit 0, always print loudly, and Rule 17 - are deliberately unticked. Part one honours all three. They stay open because you still owe them.

Both design documents still state the repository settings as `squash_merge_commit_message=COMMIT_MESSAGES`, `allow_merge_commit=true`, `allow_rebase_merge=true` - at `C2` in the plan and under `Repo settings, first` in the spec. All three were changed by `WO-20260824-cc71` - `Repo settings: squash-only, with the commit body taken from the PR description`.

Both also still carry the `SessionStart` matcher question as open, at `C7` and `E1.2` in the plan and under `Problem A` in the spec. It was answered by `WO-20260824-0615` - `Confirm whether a SessionStart hook matcher filters by source`: matchers do filter by source, alternation is honoured, the stdin-read fallback is dead. It bears on `WO-20260824-bb0d` - `setup.sh installs the skill-sync binary, then the SessionStart hook`, not on you.

Root `CLAUDE.md` Rule 16 does not bind this ticket. `claude/tools/` is not under `claude/skills/`, so no skill bump is owed. But `skill-sync.sh` is a registered tool with a `sha256` in the registry, so **editing it changes its hash and `skill-version.sh verify` goes red until you run `init`**. That is new since part one - the entry did not exist before. Bump the marker in the file's header yourself, then run `init`; the script owns the registry, never the marker.

Rule 17's `justfile` clause was read and deliberately not applied to `claude/tools/`, matching the repo-local `tools/` tree. The reasoning is a note on part one's ticket. It is flagged, not closed - only 2 of 43 skills carry one.

`workflows/close-out-procedure.md`, `claude/skills/work-order/SKILL.md` and root `CLAUDE.md` are all current on the close-out.

### Your scope

Everything destructive, and the ownership matrix is the part that has to be right.

- **Sweep** `.claude/cache/.sync.*` older than an hour, **before** starting. The one failure mode that skips the `trap` is a hook timeout, which is also the likeliest one.
- **Build into `.claude/cache/.sync.XXXXXX`**, render the notice into each `SKILL.md`, and swap each owned directory **individually**. A timeout mid-sync then leaves the previous state intact rather than half of it.
- **Remove a dropped directory only when the receipt claims it.** Never `rm -rf` the parent. `emit_plan`'s `dropped` tag is the input.
- **Write the receipt** with `owned` and `status`, and the stamp. `"status": "failed"` on the failure path too - `sync_failed` currently prints and nothing else.
- **Self-update**: `mv` to `.bak`, fork with `SKILL_SYNC_CHILD=1`, roll back on failure. `AC-H4` is the comment explaining why it is `mv` and not `cp`, and it is a deliverable in its own right.
- **Lock with `mkdir`**, which is atomic everywhere. Not `flock`.

Out: nothing in resolution needs revisiting, `.github/workflows/` is `WO-20260824-2ad1` - `PR gate workflow: validate the bump intent and run the suites`, and removing the notice from any `SKILL.md` is epic 2.

### Before you start

The rendering contract for the notice is in the header of `claude/tools/partials/read-only-notice.md.tmpl`, and part one deliberately did not implement it - you are the first renderer. Three steps: discard every line through the first blank line, substitute `%%SKILL_NAME%%` with the skill's directory name, emit the rest byte for byte with one trailing newline. Step 1 exists so the version marker satisfies `read_tool_version` without reaching the output, which has to match six specific lines exactly.

**The notice names `skill-sync.sh` hardcoded, twice. It is not a placeholder and must not become one.** That was a decision recorded on `WO-20260824-2136` - `Extract the read-only notice into a single rendered partial`, not an oversight.

Then decide the fixture shape for the ownership matrix before writing the swap, for the same reason part one wrote its fixtures before its parser.

### Read in this order

1. Root `CLAUDE.md`. Rules 12, 14, 15 and 17 all bear on this one.
2. This entry, the top entry of `HYDRATION.md`. Read only this one.
3. `claude/tools/skill-sync.sh`, all of it. You are extending a file, not writing one, and its header states what it deliberately does not do.
4. `claude/tools/testing/run-tests.sh`, which is the suite you are adding to rather than replacing. Its fixture helpers - `mkproject`, `mkregistry`, `mkreceipt`, `mkstub`, `run_sync`, `plan_has`, `snapshot` - are the ones your cases want.
5. The ticket: `work-orders/WO-20260824-f1a5/WO-20260824-efb0-skill-sync-sh-part-two-build-swap-receipt-and-se.md`.
6. `docs/superpowers/specs/2026-08-23-skills-package-manager-design.md`, sections `Flows` -> `Session sync` and `Self-update`, `Failure modes` including `mv, never cp`, and `Ownership is per-directory, not per-parent`.
7. `docs/superpowers/plans/2026-08-24-skills-package-manager-implementation.md` section `E1.6` below the rule, and `What skill-sync.sh's suite must cover`, which is the ownership matrix in table form.
8. `claude/tools/partials/read-only-notice.md.tmpl`, header included.

### Reuse, it is proven

`claude/tools/testing/run-tests.sh` already re-execs into Podman, stubs `curl` on `PATH` with a call counter, and hashes the project tree before and after. Extend it; do not stand up a second suite.

`snapshot()` in that file is the "nothing was touched" assertion `AC-H1` needs, and it is already there. Point it at a hand-authored skill directory instead of the project root.

`mkstub` takes a mode - `fail`, `empty`, `flaky`, `ok`, `real`. Add modes rather than writing a second stub.

`claude/skills/work-order/scripts/lib/common.sh` emits JSON from hand-rolled bash and is the precedent for writing the receipt without `jq`. `json_array` and `json_string` in `skill-sync.sh` are the matching readers, and the receipt you write has to be one the readers already there can read back.

### The verification ladder

Rung 1, free: `grep -c 'SKILL_SYNC_CHILD' claude/tools/skill-sync.sh` is non-zero, and the `mv`-not-`cp` comment is present. That is `AC-H4`, and it is the one criterion a grep settles.

Rung 2: the ownership matrix, all four rows. The last row - **not in the manifest, not in the receipt** - is the one that matters: assert the directory is untouched _and never even read_. A wrong answer there silently deletes hand-authored work in a gitignored directory, with no diff and nothing to notice it by. That is `AC-H1`.

Rung 3: a missing receipt collapses to "sync owns nothing" and deletes nothing; a corrupt one does the same rather than throwing. That is `AC-H2`'s second half.

Rung 4: exit 0 on every failure path, with the loud print, still asserted separately. That is `AC-H3`, and part one's `AC-H3` group is the shape to copy.

Rung 5: a hard kill during the build leaves every owned directory at its previous version and none half-written. Then the sweep: plant a `.sync.` directory with an old mtime, assert it is gone; plant a fresh one, assert it survives.

Rung 6: two concurrent syncs, one waits, neither corrupts the tree. Per `skill-testing.md`, a script that claims a lock has that claim tested.

Rung 7: `skill-version.sh init` then `verify` rc 0, with the regenerated `registry.json` committed - `skill-sync.sh`'s hash moved.

Rung 8: `bash claude/tools/testing/run-tests.sh`, plus `skill-versioning` still at 103 and repo-local `tools/` still at 36.

### Traps, already paid for

`cp script script.bak && curl -o script` truncates the live inode. Bash reads a script lazily by byte offset, so the running shell then reads garbage from wherever it had reached, and it fails in ways that look like anything except a self-update bug. `mv` is a rename: the inode survives. The spec says this and the comment saying it is `AC-H4`.

A suite written with `set -euo pipefail` dies on its first intentionally-failing check and reports the assertion passing as an error. Every suite in this repository uses `set -uo pipefail` and says why.

A `grep -q` in a pipeline reports "no match" when it matched: `grep -q` closes the pipe on the first hit, the upstream dies of SIGPIPE, and `pipefail` turns that into a non-zero pipeline. Capture to a variable and grep the variable.

A grep over the source for `flock`, `cmp` or `diff` matches the comment saying the script uses none of them. Part one's Rule 17 group strips comments first; reuse it rather than rediscovering why it fails.

Minimal images ship neither `cmp` nor `diff`. `claude/tools/testing/Containerfile` installs bash and nothing else on purpose, and `curl` is absent so the stub is provably the only one on `PATH`. Adding a package to make a case easier removes an assertion.

`flock` does not exist on Git Bash. Lock with `mkdir`. Its absence surfaces as a lock timeout that never happened, which is the worst possible error message.

A markdown formatter re-pads tables in a file you only meant to add one line to. It is a `PostToolUse` hook in the machine's global `~/.claude/settings.json`, not in this repository. `git diff --stat` before committing; a two-line change reporting forty is this.

`work-order.sh start` refuses with "working tree is dirty", and `git rebase` refuses immediately after `start` because `start` leaves the ticket file, `INDEX.md` and the epic README uncommitted. Commit them first.

A command reports success and did nothing. A prompt with no TTY takes its default and exits 0. Assert the post-state, never `$?` alone.

### Workflow

```bash
WO=claude/skills/work-order/scripts/work-order.sh
HP=claude/skills/hydration-prompt/scripts/hydration.sh
SV=claude/skills/skill-versioning/scripts/skill-version.sh

bash $WO show    --project . --id WO-20260824-efb0
bash $WO start   --project . --id WO-20260824-efb0   # creates the branch, leaves files uncommitted

# ... extend skill-sync.sh and its suite, prove it in Podman ...

bash $SV init                                        # skill-sync.sh's hash moved; no skill bump is owed
bash $SV verify                                      # this one has to be green

bash $WO evidence --project . --id WO-20260824-efb0 --index 1 --observed "..."
bash $WO evidence --project . --id WO-20260824-efb0 --index 2 --observed "..."
bash $WO evidence --project . --id WO-20260824-efb0 --index 3 --observed "..."
bash $WO evidence --project . --id WO-20260824-efb0 --index 4 --observed "..."

git push -u origin <branch>
gh pr create --base main --title "..." --body-file <file>

bash $WO submit  --project . --id WO-20260824-efb0 --pr <N>
bash $WO done    --project . --id WO-20260824-efb0   # archives on the branch, commits nothing

bash $HP check   --project . --body-file /tmp/entry.md
bash $HP add     --project . --id <next> --title "<next title>" --body-file /tmp/entry.md

git add -A && git commit && git push                 # rides the SAME pull request

# after the merge
bash $WO cleanup --project . --id WO-20260824-efb0   # deletes both branches, writes nothing
```

`approve` is already done for every ticket in both epics and must not be run again.

The pull request description is the merge commit body verbatim. Write it as something worth reading on `main`, because that is where it ends up.

### Conventions

Every reference to a work-order in a chat reply carries the ticket ID and its full title joined by a dash. A bare ID is a defect, and so is "the next ticket" or "the blocked one".

Feature branches only, and nothing writes to `main` any more.

Rule 14 has no size threshold. A single `--help` run whose purpose is to check that something works goes in a container.

When the ticket contradicts itself, say so and pick one in the open. Part one did, twice - the sweep box and the `justfile` clause - and both are recorded as notes on the ticket rather than smoothed over.

<!-- hydration-entry: WO-20260824-5b89 -->
## WO-20260824-5b89 - skill-sync.sh part one: resolution, and the tools test tree it is proved in
_Generated 2026-08-24 by hydration.sh. Newest entry._

### Ticket

`WO-20260824-5b89` - `skill-sync.sh part one: resolution, and the tools test tree it is proved in`.
Both of its dependencies are now `done`: `WO-20260824-de9e` - `Registry schema 2, with type derived from the tree and requires read from frontmatter`, and `WO-20260824-2136` - `Extract the read-only notice into a single rendered partial`, which merged as PR #63.
`work-order next` returns it first.

It blocks `WO-20260824-efb0` - `skill-sync.sh part two: build, swap, receipt, and self-update`, which is the other half of the same script.

Poker put it at 5 points, split out of a 13. The seam is deliberate: resolution is a pure function of its inputs and can be tested without anything destructive happening, and standing up `claude/tools/testing/` belongs here so that part two is never the ticket where part one first gets tested.

### What just landed

`claude/tools/` exists. It has exactly one file in it: `claude/tools/partials/read-only-notice.md.tmpl`, at version `1.0.0`, and a matching `read-only-notice` entry in the `tools` block of `claude/skills/registry.json` with a version and a `sha256`.

The template carries the rendering contract in its own header, because the renderer that has to honour it is **your ticket** and a convention living anywhere else would not survive the trip:

1. discard every line through the first blank line - that is the header
2. substitute `%%SKILL_NAME%%` with the skill's directory name
3. emit the rest byte for byte, one trailing newline, nothing else

Step 1 exists because `render_tools` requires a `skill-tool-version:` marker in the file's first 20 lines, while the rendered output has to reproduce six specific lines exactly. A stripped header satisfies both without a rule that inspects the body.

**The notice names `skill-sync.sh`, hardcoded, twice.** It is not a placeholder and must not become one. That was a decision, not an oversight: the ticket's `AC-H1` asked for output byte-identical to `claude/skills/work-order/SKILL.md` lines 9-14, and those lines say `skill-update.sh`, while the same ticket's non-goals and the design spec both say `skill-sync.sh`. Both could not hold. The rendered output is identical to those six lines with the two occurrences renamed and nothing else changed, and the ticket's evidence says exactly that rather than claiming the criterion was met as written.

Before that: `WO-20260824-7a63` - `Close-out moves onto the branch: done archives, cleanup only deletes branches` moved the whole close-out onto the feature branch, and `WO-20260824-de9e` - `Registry schema 2, with type derived from the tree and requires read from frontmatter` gave every registry entry a derived `type` and a `requires`.

Suites at the moment you start: `skill-versioning` 103, `work-order` 299 across 22 case files, repo-local `tools/` 36. All green in Podman on digest-pinned bases with `--network=none`.

### What is NOT done

`claude/tools/skill-sync.sh` does not exist, and neither does `claude/tools/testing/`. **Both are your ticket.**

- `ls claude/tools` prints `partials` and nothing else.
- `grep '"skill-sync"' claude/skills/registry.json` prints nothing. `skill-sync` is already in `TOOLS_REGISTERED` in `skill-version.sh`, so its entry appears on its own the moment the file lands with a marker in it. There is no table to extend.
- `git ls-files .github/workflows` prints nothing. No PR gate, no publisher.
- `grep -l "This copy is read-only" claude/skills/*/SKILL.md | wc -l` prints `43`. The notice has left none of them - that is epic 2, and explicitly not this ticket.
- No `.claude/skills.toml` exists anywhere in this repository. You are writing the parser before the first manifest exists, so your fixtures are the only manifests there are.

Nothing was carried off `WO-20260824-2136` - `Extract the read-only notice into a single rendered partial`. Both acceptance criteria were evidenced, `AC-H1` with its deviation recorded in the evidence text and in a note on the ticket.

Branch protection is still absent and still on no ticket.

### Stale or false in the docs

`docs/superpowers/plans/2026-08-24-skills-package-manager-implementation.md` section `E1.6 - claude/tools/skill-sync.sh` is the checklist for **both** halves of the script. The first five boxes plus the `--boot` box are yours; everything from `Build into .claude/cache/.sync.XXXXXX` down belongs to `WO-20260824-efb0` - `skill-sync.sh part two: build, swap, receipt, and self-update`. The plan predates the split and does not mark the seam.

Both design documents still state the repository settings as `squash_merge_commit_message=COMMIT_MESSAGES`, `allow_merge_commit=true`, `allow_rebase_merge=true` - at `C2` in the plan and under `Repo settings, first` in the spec. All three were changed by `WO-20260824-cc71` - `Repo settings: squash-only, with the commit body taken from the PR description`.

Both also still carry the `SessionStart` matcher question as open, at `C7` and `E1.2` in the plan and under `Problem A` in the spec. It was answered by `WO-20260824-0615` - `Confirm whether a SessionStart hook matcher filters by source`: matchers do filter by source, alternation is honoured, the stdin-read fallback is dead. It bears on the hook, which is `WO-20260824-bb0d` - `setup.sh installs the skill-sync binary, then the SessionStart hook`, not on you.

Root `CLAUDE.md` Rule 16 requires a PR touching a skill to bump that skill and ship a regenerated `registry.json`. **It does not bind this ticket**: `claude/tools/` is not under `claude/skills/`, so nothing you write here owes a skill bump. Adding `skill-sync.sh` does change `registry.json`, which must be regenerated with `skill-version.sh init` in the same commit or plain `verify` goes red.

`workflows/close-out-procedure.md`, `claude/skills/work-order/SKILL.md` and root `CLAUDE.md` are all current on the close-out. `claude/skills/skill-versioning/SKILL.md` is current on schema 2.

### Your scope

Two things, and the test tree is half the ticket.

**`claude/tools/skill-sync.sh`, resolution only.** Everything it needs to decide what should be installed, and nothing that installs it:

- `--boot`: no `.claude/skills.toml` in this directory, or a stamp under 15 minutes old, exits 0 and prints nothing at all. Not a quiet message - nothing.
- A minimal hand-rolled manifest parse. No TOML parser exists on Git Bash and Rule 17 says Windows is supported, so this reads `[skills] use = [...]` and `[agents] use = [...]` with the tools that are actually there. The format is under `Data formats` -> `Manifest` in the spec.
- Registry fetch, three attempts, then a loud two-line failure and **exit 0**. A sync that fails must never fail the session it was hooked into.
- Resolve `requires` transitively into the owned set. The two real edges are both on `work-order`, from `cartography` and `living-docs`.
- Read the receipt at its documented path for the previously owned set. The shape is under `Receipt` in the spec.

**`claude/tools/testing/run-tests.sh` and its `Containerfile`**, on the debian digest the existing suites already pin.

Out, and named because they are the obvious next thoughts: writing anything into `.claude/skills/`, the temp build, the directory swap, the receipt write, and the self-update path - all four are `WO-20260824-efb0` - `skill-sync.sh part two: build, swap, receipt, and self-update`. Also out: removing the notice from any `SKILL.md`, which is epic 2, and any `.github/workflows/` file.

### Before you start

Decide where the receipt and the stamp live, and write both paths into `skill-sync.sh` as constants even though part one only reads them. Part two writes them, and two tickets inventing the same path independently is how they end up disagreeing.

Then decide what your fixtures look like before you write the parser. The resolution half has no output anyone can look at - it is a set - so the suite is the only place its correctness is visible, and a fixture tree invented while chasing a failing assertion tends to encode the bug.

### Read in this order

1. `workflows/close-out-procedure.md`. Short, has a diagram, and is the thing that changed most recently.
2. Root `CLAUDE.md`. Rules 12, 14, 15 and 17 all bear on this one - Rule 17 hardest, because this script is the first thing in the repository that has to run under Git Bash.
3. This entry, the top entry of `HYDRATION.md`. Read only this one.
4. The ticket: `work-orders/WO-20260824-f1a5/WO-20260824-5b89-skill-sync-sh-part-one-resolution-and-the-tools-.md`, including both of its notes.
5. `docs/superpowers/specs/2026-08-23-skills-package-manager-design.md`, sections `Data formats` (manifest, registry schema 2, receipt), `Flows` -> `Session sync`, and `Failure modes`.
6. `docs/superpowers/plans/2026-08-24-skills-package-manager-implementation.md` section `E1.6`, remembering it covers both halves.
7. `claude/tools/partials/read-only-notice.md.tmpl`, header included. You do not render it in this ticket, but you are the one who has to keep the contract implementable.

### Reuse, it is proven

`tools/testing/run-tests.sh` is the closest worked example of the suite you have to stand up. It re-execs itself into Podman rather than expecting the caller to remember the `podman run` line, mounts the repo read-only, runs `--network=none`, and builds its own image from a sibling `Containerfile`. Copy the shape.

`claude/skills/skill-versioning/testing/run-tests.sh` is the larger example at 103 checks, and its section 6b builds a fixture tools tree at `$WORK/tools` and proves the populated registry path against it - it needs neither git nor a network, which is exactly your constraint.

`read_tool_version` in `claude/skills/skill-versioning/scripts/skill-version.sh` is the marker reader. `skill-sync.sh` needs its own `# skill-tool-version: 1.0.0` in the first 20 lines or `render_tools` kills every `skill-version.sh` subcommand at once.

`claude/skills/work-order/scripts/lib/common.sh` emits JSON from hand-rolled bash and is the precedent for doing so without `jq`.

### The verification ladder

Rung 1, free: `head -20 claude/tools/skill-sync.sh` shows the marker.

Rung 2: `--boot` in a directory with no manifest produces empty stdout **and** empty stderr, and exits 0. That is `AC-H2`, and asserting the exit code alone does not prove it.

Rung 3: the owned set against a manifest fixture, a registry fixture and a receipt fixture, with a transitive `requires` in the graph. That is `AC-H1`.

Rung 4: three failed fetches produce the two-line failure and still exit 0. That is `AC-H3`. Stub the fetch; `--network=none` means an unreachable registry is the default state, not something you have to arrange.

Rung 5: `skill-version.sh init` then `grep '"skill-sync"' claude/skills/registry.json` shows the entry, and `skill-version.sh verify` exits 0 with the regenerated registry committed.

Rung 6: `bash claude/tools/testing/run-tests.sh`, plus `bash claude/skills/skill-versioning/testing/run-tests.sh` still at 103.

### Traps, already paid for

`skill-sync.sh` lands without a `skill-tool-version:` marker and every `skill-version.sh` subcommand dies at once, inside `render_registry`, so `init`, `bump` and `verify` all fail together. `render_tools` treats a registered tool present without a version as a hard failure on purpose.

A suite written with `set -euo pipefail` dies on its first intentionally-failing check and reports the assertion passing as an error. Every suite in this repository uses `set -uo pipefail` and says why.

A `grep -q` in a pipeline reports "no match" when it matched: `grep -q` closes the pipe on the first hit, the upstream command dies of SIGPIPE, and `pipefail` turns that into a non-zero pipeline. Capture to a variable and grep the variable.

Minimal images ship neither `cmp` nor `diff`. The `bitnami/git` digest the skill suites use has no `diff`. Check for a utility before depending on it, or compare with a shell string test.

`flock` does not exist on Git Bash. Lock with `mkdir`, which is atomic everywhere. Its absence surfaces as a lock timeout that never happened, which is the worst possible error message.

A markdown formatter re-pads tables in a file you only meant to add one line to. It is a `PostToolUse` hook in the machine's global `~/.claude/settings.json`, not in this repository. `git diff --stat` before committing; a two-line change reporting forty is this.

`work-order.sh start` refuses with "working tree is dirty", and `git rebase` refuses immediately after `start` because `start` leaves the ticket file, `INDEX.md` and the epic README uncommitted. Commit them first.

A command reports success and did nothing. A prompt with no TTY takes its default and exits 0. Assert the post-state, never `$?` alone.

### Workflow

```bash
WO=claude/skills/work-order/scripts/work-order.sh
HP=claude/skills/hydration-prompt/scripts/hydration.sh
SV=claude/skills/skill-versioning/scripts/skill-version.sh

bash $WO show    --project . --id WO-20260824-5b89
bash $WO start   --project . --id WO-20260824-5b89   # creates the branch, leaves files uncommitted

# ... write skill-sync.sh and claude/tools/testing/, prove it in Podman ...

bash $SV init                                        # regenerates registry.json; no skill bump is owed
bash $SV verify                                      # this one has to be green

bash $WO evidence --project . --id WO-20260824-5b89 --index 1 --observed "..."
bash $WO evidence --project . --id WO-20260824-5b89 --index 2 --observed "..."
bash $WO evidence --project . --id WO-20260824-5b89 --index 3 --observed "..."

git push -u origin <branch>
gh pr create --base main --title "..." --body-file <file>

bash $WO submit  --project . --id WO-20260824-5b89 --pr <N>
bash $WO done    --project . --id WO-20260824-5b89   # archives on the branch, commits nothing

bash $HP check   --project . --body-file /tmp/entry.md
bash $HP add     --project . --id <next> --title "<next title>" --body-file /tmp/entry.md

git add -A && git commit && git push                 # rides the SAME pull request

# after the merge
bash $WO cleanup --project . --id WO-20260824-5b89   # deletes both branches, writes nothing
```

`approve` is already done for every ticket in both epics and must not be run again.

The pull request description is the merge commit body verbatim. Write it as something worth reading on `main`, because that is where it ends up.

### Conventions

Every reference to a work-order in a chat reply carries the ticket ID and its full title joined by a dash. A bare ID is a defect, and so is "the next ticket" or "the blocked one".

Feature branches only, and nothing writes to `main` any more.

Rule 14 has no size threshold. A single `--help` run whose purpose is to check that something works goes in a container.

When the ticket contradicts itself, say so and pick one in the open. The last ticket did, and the deviation is recorded in three places rather than smoothed over in none.

<!-- hydration-entry: WO-20260824-2136 -->
## WO-20260824-2136 - Extract the read-only notice into a single rendered partial
_Generated 2026-08-24 by hydration.sh. Newest entry._

### Ticket

`WO-20260824-2136` - `Extract the read-only notice into a single rendered partial`. Still the only startable child of `WO-20260824-f1a5` - `Skills package manager: prove the path on one skill`, and `work-order next` returns it.

**This entry supersedes the earlier one for the same ticket.** That one is still in this file, two entries down, and its `Workflow` block is wrong: the close-out procedure changed underneath it. Read this one and ignore that one entirely.

Two things merged since it was written: `WO-20260824-de9e` - `Registry schema 2, with type derived from the tree and requires read from frontmatter`, and `WO-20260824-7a63` - `Close-out moves onto the branch: done archives, cleanup only deletes branches`. The second is why you are reading a second entry.

It unblocks `WO-20260824-5b89` - `skill-sync.sh part one: resolution, and the tools test tree it is proved in`, which is the last edge holding that ticket shut.

### What just landed

**The close-out procedure changed, and it is the thing most likely to trip you.** `workflows/close-out-procedure.md` is the full version with a diagram. The short form:

```
submit --pr N  ->  done  ->  hydration entry  ->  commit  ->  push  ->  merge  ->  cleanup
                    ^                                                              ^
       archives, commits nothing                          deletes branches, writes nothing
```

`done` is now the whole close-out. It stamps `status` and `closed`, moves the ticket to `work-orders/archive/<year>/`, prunes an emptied epic directory, regenerates `INDEX.md` and the epic READMEs, and commits none of it. You commit that move with the hydration entry, onto the same pull request.

`close` no longer exists. It is `cleanup`, it runs after the merge, it deletes the local and remote branch, and it writes nothing at all. It still refuses unless `gh` reports the pull request `MERGED`, because that assertion now guards an actual delete.

There is no `merge_sha`. A commit cannot contain its own merge SHA, and storing it was the only reason close-out ever needed a second act. `pr` is the pointer, and `gh pr view <n> --json mergeCommit` resolves it forever.

A repo-local `tools/` tree now exists at the repository root, with its own `CLAUDE.md`. It is for tooling that maintains this repository and is never vendored. `claude/tools/` is the distributed one. `render_tools` only ever walks `claude/tools/`, so nothing at the root can reach the registry.

`tools/workflow-version.sh` at 1.0.0 owns the versions of the documents in `workflows/`. It has no index on purpose - nothing fetches those documents, so a generated file would have no reader.

Before that, schema 2 landed. Every registry entry carries a derived `type` and a `requires`, `verify` reports an unresolved `requires:` and a schema mismatch as their own failures rather than as drift, and the `tools` block renders `{}` until `claude/tools/` exists.

Suites: 299 checks across 22 case files for `work-order`, 36 for `tools/`, 103 for `skill-versioning`. All green in Podman on digests pinned per Rule 15 with `--network=none`.

### What is NOT done

`claude/tools/` still does not exist. **That is your ticket** - the partial is the first file in it.

- `ls claude/tools` fails. No `skill-sync.sh`, no partial, no `claude/tools/testing/`.
- `git ls-files .github/workflows` prints nothing. No PR gate, no publisher, so nothing calls `verify --structure` and nothing reads a `Bump:` trailer.
- `grep -l "This copy is read-only" claude/skills/*/SKILL.md | wc -l` prints `43`. Removing the notice is the pilot and epic 2, and is explicitly out of scope here.
- `grep -c '"tools": {}' claude/skills/registry.json` prints `1`. The block is real and empty.

Nothing was carried off `WO-20260824-7a63` - `Close-out moves onto the branch: done archives, cleanup only deletes branches`. All four acceptance criteria were met and evidenced separately.

Branch protection is still absent and still on no ticket. It matters less than it did: no command writes to `main` any more, so nothing depends on that push being allowed.

### Stale or false in the docs

**The earlier `HYDRATION.md` entry for this same ticket is wrong about close-out.** Its `Workflow` block calls `close`, and its `Traps` section describes a `close` refusal that can no longer happen. `HYDRATION.md` is append-only and never edited in place, so it is still sitting there. This entry is the correction.

`docs/superpowers/plans/2026-08-24-skills-package-manager-implementation.md` and `docs/superpowers/specs/2026-08-23-skills-package-manager-design.md` both still state the repository settings as `squash_merge_commit_message=COMMIT_MESSAGES`, `allow_merge_commit=true`, `allow_rebase_merge=true`, at `C2` in the plan and under `Repo settings, first` in the spec. All three were changed by `WO-20260824-cc71` - `Repo settings: squash-only, with the commit body taken from the PR description`.

Both also still carry the `SessionStart` matcher question as open, at `C7` and `E1.2` in the plan and under `Problem A` in the spec. It was answered by `WO-20260824-0615` - `Confirm whether a SessionStart hook matcher filters by source`: matchers do filter by source, alternation is honoured, the stdin-read fallback is dead.

Neither is this ticket's business. `WO-20260824-bb0d` - `setup.sh installs the skill-sync binary, then the SessionStart hook` and `WO-20260824-8cd1` - `Rewrite root CLAUDE.md for merge-time allocation and the named main exception` each own their half.

Root `CLAUDE.md` Rule 16 still requires a PR touching a skill to bump the version and ship a regenerated `registry.json` by hand. **It does not bind this ticket**: `claude/tools/` is not under `claude/skills/`, so a PR that only adds the template touches no skill and owes no bump. Adding the template does change `registry.json`, which must be regenerated with `skill-version.sh init` in the same commit or plain `verify` goes red.

`claude/skills/work-order/SKILL.md` and root `CLAUDE.md` are both current on the new close-out. `claude/skills/skill-versioning/SKILL.md` is current on schema 2 and gives its check count as 103.

### Your scope

One file and one registry entry: `claude/tools/partials/read-only-notice.md.tmpl`, and the `read-only-notice` entry it causes `render_tools` to emit.

The template holds the six-line notice with the skill's own name substituted in one place. Its rendered output must be byte-identical to `claude/skills/work-order/SKILL.md` lines 9 to 14 as they stand today. Byte-identical is the acceptance criterion because it is the only way to prove this is a refactor and not a rewrite.

The tool name inside the notice is hardcoded to `skill-sync.sh` and is **not** a placeholder. After this work `skill-update.sh` no longer installs synced skills, so a rendered copy naming it would be wrong.

**The template must carry a version marker in its first 20 lines**, because `render_tools` reads one:

```
<!-- skill-tool-version: 1.0.0 -->
```

`read_tool_version` in `claude/skills/skill-versioning/scripts/skill-version.sh` is the reader. `tools/workflow-version.sh` uses the same token shape against `workflows/`, and is worth reading as a second worked example.

Out of scope, and named because they are the obvious next thoughts: removing the notice from any `SKILL.md`, which is the pilot and epic 2; making the tool name a placeholder; writing the renderer, which belongs to `skill-sync.sh`; and creating `claude/tools/testing/`, which stays with `WO-20260824-5b89` - `skill-sync.sh part one: resolution, and the tools test tree it is proved in`.

### Before you start

Settle how the version marker survives the byte-identical requirement. It is the one thing the ticket text does not anticipate, because the marker convention was introduced after the ticket was written.

The marker must be inside the template's first 20 lines for `render_tools` to find it, and it must not appear in the rendered output, which has to match six specific lines exactly. So something has to strip it. Decide between a template whose first line is the marker and a renderer that drops a leading `<!-- skill-tool-version: -->` line, and a template that stores the marker somewhere the substitution step naturally discards.

Write the rule into the template itself. The renderer that has to honour it does not exist yet - it is `WO-20260824-5b89` - `skill-sync.sh part one: resolution, and the tools test tree it is proved in` and the one after it - and a convention living only in this entry will not survive to meet it.

### Read in this order

1. `workflows/close-out-procedure.md`. It is short, it has a diagram, and it is the thing that changed most recently.
2. Root `CLAUDE.md`. Rules 12, 14, 15 and 17 bear on this work. Rule 16 does not, because `claude/tools/` is not under `claude/skills/`. There is no `CONTEXT_STATE.md` in this repository.
3. This entry, the top entry of `HYDRATION.md`. Read only this one - the older entry for this same ticket is superseded.
4. The note on the epic `WO-20260824-f1a5` - `Skills package manager: prove the path on one skill`, newest first. It records why the `tools` block ships empty.
5. `docs/superpowers/specs/2026-08-23-skills-package-manager-design.md`, the section `The read-only notice becomes a partial`. It quotes the six lines.
6. The ticket file: `work-orders/WO-20260824-f1a5/WO-20260824-2136-extract-the-read-only-notice-into-a-single-rende.md`.
7. `claude/skills/work-order/SKILL.md` lines 9 to 14, the bytes you have to reproduce.
8. `claude/skills/skill-versioning/scripts/skill-version.sh`, `render_tools` and `read_tool_version` together.

### Reuse, it is proven

`render_tools` already does the whole registry side. Drop the file at `claude/tools/partials/read-only-notice.md.tmpl` with a marker in it and the entry appears on its own - `read-only-notice` is already in `TOOLS_REGISTERED`, so there is no table to extend and no edit to make in `skill-version.sh`.

`tools/workflow-version.sh` is the closest worked example of the marker convention: same token shape, its own reader, its own suite. `tools/testing/run-tests.sh` is the closest example of a suite for a tool that is not a skill, and it re-execs itself into the container rather than expecting the caller to remember the `podman run` line.

`claude/skills/skill-versioning/testing/run-tests.sh` section 6b builds a fixture tools tree at `$WORK/tools` and proves the populated path against it. Copy that if this ticket wants its own assertions - it needs neither git nor a network.

`claude/skills/work-order/scripts/work-order.sh` owns every ticket transition. Never hand-edit a ticket file. `note` is the only way a note reaches a ticket, `evidence` the only way a criterion gets ticked.

`claude/skills/hydration-prompt/scripts/hydration.sh` owns `HYDRATION.md`. Run `check --body-file` before `add`; `add` refuses a body that fails `check`.

`gh` is authenticated and works here. `gh-axi` wraps it and is preferred where it fits.

### The verification ladder

Rung 1, free: `head -20 claude/tools/partials/read-only-notice.md.tmpl` shows the marker. Without it `render_tools` dies, and it dies inside `render_registry`, so `init`, `bump` and `verify` all fail at once.

Rung 2, cheap: substitute the skill name by hand in a container and compare against `claude/skills/work-order/SKILL.md` lines 9 to 14. That is `AC-H1`. Minimal images ship neither `cmp` nor `diff`, so check before depending on either or compare with a shell string test.

Rung 3: `skill-version.sh init`, then `grep '"read-only-notice"' claude/skills/registry.json` shows the entry with a version and a `sha256`. That is `AC-H2`.

Rung 4: `skill-version.sh verify` exits 0 on the branch. The template is new, so the registry moves, and the run is green only if the regenerated registry is committed with it.

Rung 5: `bash claude/skills/skill-versioning/testing/run-tests.sh` in Podman, all 103 checks still green.

### Traps, already paid for

The template exists but carries no marker, and every `skill-version.sh` subcommand dies at once. `render_tools` treats a registered tool present without a `skill-tool-version:` as a hard failure on purpose - an entry with no version is one no consumer can compare.

`render_registry` no longer reproduces the file byte for byte and every skill reads as drifted. A trailing newline, a key order change or a space after a colon does it. Compare rendered output to the file before touching any test.

A suite written with `set -euo pipefail` dies on its first intentionally-failing check and reports the assertion passing as an error. Both suites in this repository use `set -uo pipefail` for that reason and say so.

A `grep -q` in a pipeline reports "no match" when it matched. `grep -q` closes the pipe on the first hit, the upstream command dies of SIGPIPE, and `pipefail` turns that into a non-zero pipeline. Capture to a variable and grep the variable.

A markdown formatter re-pads tables in a file you only meant to add one line to. It is a `PostToolUse` hook in the machine's global `~/.claude/settings.json`, not in this repository, so the churn is local and does not belong in a diff. `git diff --stat` before committing; a two-line change reporting forty is this. `git checkout HEAD -- <file>` and re-apply with `sed`, which does not trip the hook.

`work-order.sh start` refuses with "working tree is dirty". `new` and `approve` both write files, so a ticket cut in the same session leaves the tree dirty on `main` and `start` will not cut a branch from it. Carry the change onto a scratch branch, commit it there, then run `start` from that clean tree - it cuts `feat/<slug>` from wherever HEAD is.

`git rebase` refuses with "cannot rebase: You have unstaged changes" immediately after `start`. `start` writes the ticket file, `INDEX.md` and the epic README and leaves them uncommitted. Commit them before rebasing.

A command reports success and did nothing. A prompt with no TTY takes its default and exits 0. Assert the post-state, never `$?` alone.

### Workflow

```bash
WO=claude/skills/work-order/scripts/work-order.sh
HP=claude/skills/hydration-prompt/scripts/hydration.sh
SV=claude/skills/skill-versioning/scripts/skill-version.sh

bash $WO show    --project . --id WO-20260824-2136
bash $WO start   --project . --id WO-20260824-2136   # creates the branch, leaves files uncommitted

# ... write the template, in a container ...

bash $SV init                                        # regenerates registry.json; no bump is owed
bash $SV verify                                      # this one has to be green

bash $WO evidence --project . --id WO-20260824-2136 --index 1 --observed "..."
bash $WO evidence --project . --id WO-20260824-2136 --index 2 --observed "..."

git push -u origin <branch>
gh pr create --base main --title "..." --body-file <file>

bash $WO submit  --project . --id WO-20260824-2136 --pr <N>
bash $WO done    --project . --id WO-20260824-2136   # archives on the branch, commits nothing

bash $HP check   --project . --body-file /tmp/entry.md
bash $HP add     --project . --id <next> --title "<next title>" --body-file /tmp/entry.md

git add -A && git commit && git push                 # rides the SAME pull request

# after the merge
bash $WO cleanup --project . --id WO-20260824-2136   # deletes both branches, writes nothing
```

`approve` is already done for every ticket in both epics and must not be run again.

The pull request description is the merge commit body verbatim. Write it as something worth reading on `main`, because that is where it ends up.

### Conventions

Every reference to a work-order in a chat reply carries the ticket ID and its full title joined by a dash. A bare ID is a defect, and so is "the next ticket" or "the blocked one".

Feature branches only, and `main` is now never written by anything. The old exception was `work-order close` committing its archive directly; that command writes nothing any more.

Rule 14 has no size threshold. A single `--help` run whose purpose is to check that something works goes in a container.

<!-- hydration-entry: WO-20260824-2136 -->
## WO-20260824-2136 - Extract the read-only notice into a single rendered partial
_Generated 2026-08-24 by hydration.sh. Newest entry._

### Ticket

`WO-20260824-2136` - `Extract the read-only notice into a single rendered partial`. It is the only startable child of the epic - `work-order next` returns it and nothing else from `WO-20260824-f1a5` - `Skills package manager: prove the path on one skill`.
Predecessor `WO-20260824-de9e` - `Registry schema 2, with type derived from the tree and requires read from frontmatter`, merged as PR #60, closed and archived.

Poker put it at 2 points and called it the anchor: one template file, one byte-identical acceptance criterion, no unknowns. That was true when it was written and it is one item less true now - see `Before you start`.

It unblocks `WO-20260824-5b89` - `skill-sync.sh part one: resolution, and the tools test tree it is proved in`, which depends on this ticket and on the predecessor. The predecessor is done, so this is the last edge holding `5b89` shut.

### What just landed

The registry is schema 2.

```json
"living-docs": { "version": "1.0.1", "sha256": "100d0484…", "type": "skill", "requires": ["work-order"] }
```

Still one entry per line. That line is what `verify` compares and what it prints when a skill drifts, so nothing may split an entry across lines.

`type` is derived from the tree an entry was found in and is never declared. The walk covers the skills tree only, so all 43 entries render as `skill`. `claude/agents/` still carries no version and no registry row.

`requires` is an optional frontmatter key, comma-separated, read with one line of `awk` from the leading fenced block only. `requires: work-order` is on `living-docs` and `cartography` and on nothing else - 2 of 43 entries carry a non-empty array, the other 41 render `[]`.

`verify` gained two failures that are distinct from drift:

```
unresolved requires   living-docs -> work-ordr (no such skill)
schema mismatch: registry is schema 1, this generator writes schema 2
```

Both forms assert the first, because an unresolved `requires:` is a property of the tree rather than of the registry. The second refuses to run the comparison at all, because a cross-schema comparison differs on every line and would name all 43 skills as drifted while explaining none of them.

**The `tools` block ships empty, and that was a deliberate decision, not an oversight.** `render_tools` emits an entry only for a registered tool that exists on disk. `claude/tools/` does not exist, so it renders `"tools": {}`. The reasoning is a note on the epic `WO-20260824-f1a5` - `Skills package manager: prove the path on one skill` and it is the anchor to point a later session at.

The suite is at 103 checks, 42 negative, green in Podman on `bitnami/git` pinned by digest with `--network=none`. Sections 6, 6b and 6c are new and need neither git nor a network.

Bumps that rode the PR: `skill-versioning` 1.2.0 to 2.0.0, major because the format of `registry.json` changed; `living-docs` to 1.0.1 and `cartography` to 1.0.3, both patch for one frontmatter key.

### What is NOT done

Nothing has been built in either epic outside `claude/skills/skill-versioning/`. Seventeen of the twenty-one tickets have never been started and none of them has a branch.

Each of these is a command whose output proves the claim, measured on `main` after PR #60 merged:

- `ls claude/tools` fails. No `skill-sync.sh`, no partial, no tools test suite. **The partial is your ticket.**
- `git ls-files .github/workflows` prints nothing. No PR gate, no publisher, so nothing yet calls `verify --structure` and nothing yet reads a `Bump:` trailer.
- `grep -l "This copy is read-only" claude/skills/*/SKILL.md | wc -l` prints `43`. Every skill still carries the inline notice. Removing it is the pilot and epic 2, and is explicitly out of scope here.
- `grep -c '"tools": {}' claude/skills/registry.json` prints `1`. The block is real and empty.

`verify --structure` still has no caller. Its first one is `WO-20260824-2ad1` - `PR gate workflow: validate the bump intent and run the affected suites`, which is several tickets away.

Nothing was carried off `WO-20260824-de9e` - `Registry schema 2, with type derived from the tree and requires read from frontmatter`. All three acceptance criteria were met and evidenced separately against the real 43-skill tree.

Branch protection rules and required status checks are still absent, and are still on no ticket at all. That is load-bearing for `work-order.sh close`, which pushes its archive commit straight to `main` and only falls back to a PR when that push is rejected.

### Stale or false in the docs

`docs/superpowers/plans/2026-08-24-skills-package-manager-implementation.md` and `docs/superpowers/specs/2026-08-23-skills-package-manager-design.md` both still state the repository settings as `squash_merge_commit_message=COMMIT_MESSAGES`, `allow_merge_commit=true`, `allow_rebase_merge=true`, at `C2` in the plan and under `Repo settings, first` in the spec. All three were changed by `WO-20260824-cc71` - `Repo settings: squash-only, with the commit body taken from the PR description` and the stated values are false.

Both documents also still carry the `SessionStart` matcher question as open - in the plan at `C7` and in `E1.2`, in the spec under `Problem A - a sync fires while an agent is mid-task`. It was answered by `WO-20260824-0615` - `Confirm whether a SessionStart hook matcher filters by source`: matchers do filter by source, alternation is honoured, and the stdin-read fallback is dead.

Neither correction is this ticket's business. `WO-20260824-bb0d` - `setup.sh installs the skill-sync binary, then the SessionStart hook` touches the matcher material and `WO-20260824-8cd1` - `Rewrite root CLAUDE.md for merge-time allocation and the named main exception` touches the settings material.

The spec's `E1.5` section says the partial is "registered in the registry's `tools` block so a change to it forces a re-render everywhere". That is now true of the mechanism and not yet of the file - the block exists and is empty, and registering the partial is your `AC-H2`.

Root `CLAUDE.md` Rule 16 still requires a PR touching a skill to bump the version and ship a regenerated `registry.json` by hand. That is true today. It does **not** bind this ticket the way it bound the last one: `claude/tools/` is not under `claude/skills/`, so a PR that only adds the template touches no skill and owes no bump. It becomes false at `WO-20260824-8cd1` - `Rewrite root CLAUDE.md for merge-time allocation and the named main exception`.

`claude/skills/skill-versioning/SKILL.md` is current. It documents schema 2, the derived `type`, the comma-separated `requires`, the `tools` block and the marker convention, and gives the check count as 103. If you change the suite, that number moves with it.

### Your scope

One file and one registry entry: `claude/tools/partials/read-only-notice.md.tmpl`, and the `read-only-notice` entry it causes `render_tools` to emit.

The template holds the six-line notice with the skill's own name substituted in one place. Its rendered output must be byte-identical to `claude/skills/work-order/SKILL.md` lines 9 to 14 as they stand today. Byte-identical is the acceptance criterion because it is the only way to prove this is a refactor and not a rewrite.

The tool name inside the notice is hardcoded to `skill-sync.sh` and is **not** a placeholder. After this work `skill-update.sh` no longer installs synced skills, so a rendered copy naming it would be wrong.

**The template must carry a version marker in its first 20 lines**, because `render_tools` reads one:

```
<!-- skill-tool-version: 1.0.0 -->
```

The marker token is deliberately not `version:` - it cannot then be confused with a `version:` in prose, and it reads under any comment syntax. `read_tool_version` in `claude/skills/skill-versioning/scripts/skill-version.sh` is the reader.

Out of scope, and named because they are the obvious next thoughts: removing the notice from any `SKILL.md`, which is the pilot and epic 2; making the tool name a placeholder; and writing the renderer itself, which belongs to `skill-sync.sh`.

### Before you start

Settle how the version marker survives the byte-identical requirement. It is the one thing in this ticket that the ticket text does not anticipate, because the marker convention was introduced by the predecessor after this ticket was written.

The marker has to be inside the template's first 20 lines for `render_tools` to find it, and it must not appear in the rendered output, which has to match six specific lines exactly. So something has to strip it. Decide between a template whose first line is the marker and a renderer that drops any leading `<!-- skill-tool-version: -->` line, and a template that is stored with the marker in a position the substitution step naturally discards.

Whichever you pick, write the rule down in the template itself. The renderer that has to honour it does not exist yet - it is `WO-20260824-5b89` - `skill-sync.sh part one: resolution, and the tools test tree it is proved in` and the one after it - and a convention that lives only in this entry will not survive to meet it.

### Read in this order

1. Root `CLAUDE.md`. Rules 12, 14, 15 and 17 bear on this work. Rule 16 does not, because `claude/tools/` is not under `claude/skills/`. There is no `CONTEXT_STATE.md` in this repository.
2. This entry, which is the top entry of `HYDRATION.md`. Read only this one.
3. The note on the epic `WO-20260824-f1a5` - `Skills package manager: prove the path on one skill`, newest first. It records why the `tools` block ships empty and why building the tools first was not available.
4. `docs/superpowers/specs/2026-08-23-skills-package-manager-design.md`, the section `The read-only notice becomes a partial`. It is the argument for the change and it quotes the six lines.
5. `docs/superpowers/plans/2026-08-24-skills-package-manager-implementation.md`, section `E1.5`.
6. The ticket file: `work-orders/WO-20260824-f1a5/WO-20260824-2136-extract-the-read-only-notice-into-a-single-rende.md`.
7. `claude/skills/work-order/SKILL.md` lines 9 to 14, which are the bytes you have to reproduce.
8. `claude/skills/skill-versioning/scripts/skill-version.sh`, `render_tools` and `read_tool_version` together, before writing the template.

### Reuse, it is proven

`render_tools` already does everything the registry side of this ticket needs. Drop the file at `claude/tools/partials/read-only-notice.md.tmpl` with a marker in it and the entry appears on its own. There is no edit to make in `skill-version.sh` and no table to extend - `read-only-notice` is already registered in `TOOLS_REGISTERED`.

`render_registry` is a pure function of the tree: same tree in, same bytes out. That property is what lets `verify` be a string comparison instead of a JSON parser. Adding the template changes the registry, so the registry has to be regenerated in the same commit or `verify` goes red.

The notice is identical in all 43 files except for the skill's own name in one URL. `claude/skills/work-order/SKILL.md` lines 9 to 14 are the canonical copy and the ones the acceptance criterion names.

`claude/skills/skill-versioning/testing/run-tests.sh` builds a fixture tools tree at `$WORK/tools` in section 6b and proves the populated path against it. That is the pattern to copy if this ticket wants its own assertions, and it needs neither git nor a network.

`claude/skills/work-order/scripts/work-order.sh` owns every ticket transition. Never hand-edit a ticket file. `note` is the only way a note reaches a ticket, and `evidence` is the only way a criterion gets ticked.

`claude/skills/hydration-prompt/scripts/hydration.sh` owns `HYDRATION.md`. Run `check --body-file` before `add`; `add` refuses a body that fails `check`.

`gh` is authenticated and works in this repository. `gh-axi` wraps it and is preferred where it fits.

### The verification ladder

Rung 1, free: `head -20 claude/tools/partials/read-only-notice.md.tmpl` shows the marker. If it does not, `skill-version.sh` dies rather than rendering a version-less entry, and it dies inside `render_registry`, which means `bump`, `init` and `verify` all fail at once.

Rung 2, cheap: substitute the skill name by hand in a container and `diff` the result against `claude/skills/work-order/SKILL.md` lines 9 to 14. That is `AC-H1`, and byte-identical means `diff` is silent and exits 0. Minimal images ship neither `cmp` nor `diff` - check before depending on either, or compare with a shell string test.

Rung 3: `skill-version.sh init` then `grep '"read-only-notice"' claude/skills/registry.json` shows the entry with a version and a `sha256`. That is `AC-H2`.

Rung 4: `skill-version.sh verify` exits 0 on the branch. The template is new, so the registry moves; the run is green only if the regenerated registry is committed with it.

Rung 5: `bash claude/skills/skill-versioning/testing/run-tests.sh` in Podman, the full suite, with the 103 existing checks still green.

### Traps, already paid for

The template exists but carries no marker, and every `skill-version.sh` subcommand dies at once. `render_tools` treats a registered tool present without a `skill-tool-version:` as a hard failure, on purpose - an entry with no version is one no consumer can compare. The message names the file and the marker it wants.

`render_registry` no longer reproduces the file byte for byte and every skill reads as drifted. A trailing newline, a key order change or a space after a colon does it. Compare the rendered output to the file before touching any test.

A `grep -q` in a pipeline reports "no match" when it matched. `grep -q` closes the pipe on the first hit, the upstream command dies of SIGPIPE, and `pipefail` turns that into a non-zero pipeline. Capture to a variable and grep the variable. `diff_check` in `skill-version.sh` is written that way and says why.

The test suite passes on a machine and fails in the container, or the reverse. Minimal images ship neither `cmp` nor `diff`, and Git Bash on Windows has no `flock`. Root `CLAUDE.md` Rule 17 lists what actually bites.

A markdown formatter re-pads tables in a file you only meant to add one line to. It is a `PostToolUse` hook in the machine's global `~/.claude/settings.json`, not in this repository's `.claude/settings.json`, so the churn is local and does not belong in a diff. `git diff --stat` before committing; a two-line change that reports forty is this. `git checkout HEAD -- <file>` and re-apply with `sed`, which does not trip the hook.

`work-order.sh close` refuses with "reached done on the feature branch, but main's copy still says 'in-review'". `done` and the hydration entry are both meant to ride the ticket's own pull request, before it merges. Merging first strands them and costs a second pull request to carry them, which is precisely the thing `close` was rewritten to avoid. Run `submit --pr N`, then `done`, then write the entry, then push - all onto the same PR.

`work-order.sh close` refuses with "working tree is dirty". It stages and commits only `work-orders/`, so anything else has to be committed before it runs.

A command reports success and did nothing. A prompt with no TTY takes its default and exits 0. Assert the post-state, never `$?` alone.

`git merge --ff-only origin/main` refuses with "diverging branches". You are in a treehouse slot at detached HEAD, not in `/home/luna/dotfiles`. Check `git branch --show-current` first.

`git rebase` refuses with "cannot rebase: You have unstaged changes", immediately after `work-order.sh start`. `start` writes the ticket file, `INDEX.md` and the epic README and leaves them uncommitted. Commit them before rebasing.

### Workflow

```bash
WO=claude/skills/work-order/scripts/work-order.sh
HP=claude/skills/hydration-prompt/scripts/hydration.sh
SV=claude/skills/skill-versioning/scripts/skill-version.sh

bash $WO show    --project . --id WO-20260824-2136
bash $WO start   --project . --id WO-20260824-2136   # creates the branch, leaves files uncommitted

# ... write the template, in a container ...

bash $SV init                                        # regenerates registry.json; no bump is owed
bash $SV verify                                      # this one has to be green

bash $WO evidence --project . --id WO-20260824-2136 --index 1 --observed "..."
bash $WO evidence --project . --id WO-20260824-2136 --index 2 --observed "..."

bash $HP check   --project . --body-file /tmp/entry.md
bash $HP add     --project . --id <next> --title "<next title>" --body-file /tmp/entry.md

git push -u origin <branch>
gh pr create --base main --title "..." --body-file <file>

bash $WO submit  --project . --id WO-20260824-2136 --pr <N>
bash $WO done    --project . --id WO-20260824-2136   # on the branch, BEFORE the merge
git commit && git push                               # rides the same PR

# after the merge
bash $WO close   --project . --id WO-20260824-2136 --dry-run
bash $WO close   --project . --id WO-20260824-2136
```

`approve` is already done for every ticket in both epics and must not be run again.

The pull request description is the merge commit body verbatim. Write it as something worth reading on `main`, because that is where it ends up.

### Conventions

Every reference to a work-order in a chat reply carries the ticket ID and its full title joined by a dash. A bare ID is a defect, and so is "the next ticket" or "the blocked one".

Feature branches only. `main` is never written directly by hand. The one exception is `work-order.sh close`, which commits its archive straight to `main` and falls back to a pull request only when that push is rejected.

Rule 14 has no size threshold. A single `--help` run whose purpose is to check that something works goes in a container.

<!-- hydration-entry: WO-20260824-de9e -->
## WO-20260824-de9e - Registry schema 2, with type derived from the tree and requires read from frontmatter
_Generated 2026-08-24 by hydration.sh. Newest entry._

### Ticket

`WO-20260824-de9e` - `Registry schema 2, with type derived from the tree and requires read from frontmatter`. Position 4 of 21 children across two epics.
Predecessor `WO-20260824-6acf` - `Split verify into a structure check and a full check, and delete the notice assertion`, merged, closed and archived.

It is the second of the two tickets that touch `skill-version.sh`, and it is the larger one: rendering, frontmatter reading, a hash block, and a new distinct failure mode. Poker put it at 5 points against the split's 3.

`WO-20260824-2136` - `Extract the read-only notice into a single rendered partial` is also startable and is not blocked by this. Take that one instead if the tools directory is the more useful thing to have first; the two do not collide.

### What just landed

`verify` has two forms, and the read-only notice check is gone.

```
verify              versions present + registry.json matches render_registry
verify --structure  versions present + this branch's diff touches no version:
                    and no registry.json
```

`--structure` says nothing about whether the registry matches the tree. That is the entire point: under merge-time allocation a skill PR edits a skill and leaves the registry alone, and plain `verify` calls that state `drifted` - correctly, because on `main` it would be.

Measured on the branch before its own Rule 16 bump, in the container with the repo mounted read-only: `--structure` printed `base: origin/main` and `ok - 43 skills versioned, no version: or registry.json in the diff` at rc 0, and plain `verify` printed `drifted skill-versioning` with both hashes at rc 1. Two exit codes, one tree.

The diff half resolves a base from the first of `origin/main` or `main` that exists, `--base <ref>` overrides it, and it compares against the working tree rather than `HEAD` so an uncommitted hand-edit is caught before it is ever committed. Outside a git repository it fails and says so rather than passing with nothing checked.

The notice check at `skill-version.sh:192-197` is deleted, and `SKILL_SRC_URL` with it - it had no other caller. Nothing replaced it. `verify` now asserts the notice neither present nor absent, which is the only state that holds while the repository is mid-rollout.

The suite is at 72 checks, 26 negative, green in Podman on `bitnami/git` pinned by digest with `--network=none`. Section 5 is new and drives `--structure` against a real git repository with its skills under `claude/`, because every assertion that form makes is about a diff.

### What is NOT done

Nothing has been built in either epic beyond `skill-version.sh`. Eighteen of the twenty-one tickets have never been started and none of them has a branch.

Each of these is a command whose output proves the claim, measured on `main` after this ticket merged:

- `ls claude/tools` fails. No `skill-sync.sh`, no `skill-onboard.sh`, no notice partial, no tools test suite.
- `git ls-files .github/workflows` prints nothing. There is no PR gate and no publisher, so nothing yet calls `verify --structure` and nothing yet reads the `Bump:` trailer.
- `head -c 40 claude/skills/registry.json` shows `"schema": 1`. **This is your ticket.**
- `grep -l "This copy is read-only" claude/skills/*/SKILL.md | wc -l` prints `43`. Every skill still carries the inline notice. Only the check on it is gone.
- `grep -c 'requires' claude/skills/skill-versioning/scripts/skill-version.sh` prints `0`, and no `SKILL.md` carries a `requires:` key.

`verify --structure` exists but has no caller. Its first one is `WO-20260824-2ad1` - `PR gate workflow: validate the bump intent and run the affected suites`, which is blocked on `WO-20260824-efb0` - `skill-sync.sh part two: build, swap, receipt, and self-update` and is several tickets away.

Nothing was carried off `WO-20260824-6acf` - `Split verify into a structure check and a full check, and delete the notice assertion`. Both acceptance criteria were met and evidenced separately.

Branch protection rules and required status checks are still absent, and are still on no ticket at all.

### Stale or false in the docs

`docs/superpowers/plans/2026-08-24-skills-package-manager-implementation.md` and `docs/superpowers/specs/2026-08-23-skills-package-manager-design.md` both still state the repository settings as `squash_merge_commit_message=COMMIT_MESSAGES`, `allow_merge_commit=true`, `allow_rebase_merge=true`, at `C2` in the plan and under `Repo settings, first` in the spec. All three were changed by `WO-20260824-cc71` - `Repo settings: squash-only, with the commit body taken from the PR description` and the stated values are false.

Both documents also still carry the `SessionStart` matcher question as open - in the plan at `C7` and in `E1.2`, in the spec under `Problem A - a sync fires while an agent is mid-task`. It was answered by `WO-20260824-0615` - `Confirm whether a SessionStart hook matcher filters by source`: matchers do filter by source, alternation is honoured, and the stdin-read fallback is dead.

Neither correction is worth a fix-up commit on its own, and neither is this ticket's business. `WO-20260824-bb0d` - `setup.sh installs the skill-sync binary, then the SessionStart hook` touches the matcher material and `WO-20260824-8cd1` - `Rewrite root CLAUDE.md for merge-time allocation and the named main exception` touches the settings material; each can correct its own in passing.

Root `CLAUDE.md` Rule 16 still requires a PR touching a skill to bump the version and ship a regenerated `registry.json` by hand. That is true today and **it binds this ticket**, which edits `claude/skills/skill-versioning/`. It becomes false at `WO-20260824-8cd1` - `Rewrite root CLAUDE.md for merge-time allocation and the named main exception`, and not before.

One consequence of that is worth expecting rather than discovering. Because Rule 16 obliges the branch to carry the bump and the regenerated registry, `verify --structure` reports both and exits 1 on this ticket's own PR, exactly as it did on the last one. Plain `verify` is the one that has to be green. That inverts at `WO-20260824-8cd1`, and it is on the predecessor's ticket as a note.

`claude/skills/skill-versioning/SKILL.md` is current. It documents both forms of `verify`, states that the notice check is gone and why the middle state is deliberate, and gives the check count as 72. If you change the suite, that number moves with it.

### Your scope

One script, its suite, and two frontmatter keys: `claude/skills/skill-versioning/scripts/skill-version.sh`, `claude/skills/skill-versioning/testing/run-tests.sh`, and `requires: work-order` added to `claude/skills/living-docs/SKILL.md` and `claude/skills/cartography/SKILL.md`.

`render_registry` emits schema 2. Per decision 21, `type` is **derived from the directory the entry was found in and never declared** - `skill` or `agent`, routing only. `requires` is an optional frontmatter key, read with one line of `awk`, comma-separated, no YAML list, because Git Bash has no YAML parser and Rule 17 makes that a portability defect rather than a preference.

`verify` gains one new failure that is its own thing rather than drift: a schema mismatch. Today a registry written by an older generator reads as every skill having drifted at once, which names 43 skills and explains none of them.

`verify` also asserts that every name in a `requires:` resolves to a skill that exists. A typo'd dependency that resolves to nothing is the failure mode the auto-install path cannot recover from later.

**One thing to settle before writing the tools block.** The ticket asks for a `tools` block carrying `skill-sync` and `read-only-notice`, each with a version and a hash. Neither file exists: `claude/tools/` is created by `WO-20260824-2136` - `Extract the read-only notice into a single rendered partial` and `WO-20260824-5b89` - `skill-sync.sh part one: resolution, and the tools test tree it is proved in`. `render_registry` is a pure function of what is on disk and cannot hash a file that is not there. Decide deliberately between rendering the block only for tools that exist, and taking `WO-20260824-2136` first so the partial is there to hash. Do not hash a placeholder - a stable hash over a file nobody wrote is the kind of green that stays green after the real file lands.

Out of scope, and named because they are the obvious next thoughts: declaring `type` in frontmatter, which decision 21 rejected outright; YAML list syntax for `requires`; and soft or optional dependencies.

### Before you start

Settle the `tools` block question above. It is the one thing in this ticket that cannot be answered from the ticket text alone, and it decides whether this ticket or `WO-20260824-2136` - `Extract the read-only notice into a single rendered partial` goes first.

### Read in this order

1. Root `CLAUDE.md`. Rules 12, 14, 15, 16 and 17 bear on this work. There is no `CONTEXT_STATE.md` in this repository, so the usual second step does not apply.
2. This entry, which is the top entry of `HYDRATION.md`. Read only this one. The entries below it are superseded history.
3. `docs/superpowers/specs/2026-08-23-skills-package-manager-design.md`, decision 21. It is the argument for deriving `type` rather than declaring it, and the reason `requires` is comma-separated.
4. `docs/superpowers/plans/2026-08-24-skills-package-manager-implementation.md`, section `E1.4`.
5. The ticket file: `work-orders/WO-20260824-f1a5/WO-20260824-de9e-registry-schema-2-with-type-derived-from-the-tre.md`.
6. `claude/skills/skill-versioning/scripts/skill-version.sh`, `render_registry` and `hash_skill` together, before changing either.
7. `claude/skills/skill-versioning/testing/run-tests.sh`, section 5, which is the newest case shape in the file and the one a schema case should look like.

### Reuse, it is proven

`render_registry` is already a pure function of the tree: same tree in, same bytes out. That property is what lets `verify` be a string comparison instead of a JSON parser, and it is why the registry carries no timestamp. Schema 2 keeps it or it breaks `verify`.

`read_version` is the frontmatter reader to copy for `requires:`. It reads the leading fenced block only, so a `requires:` line in prose is ignored - which is the whole reason it is written that way.

`claude/skills/skill-versioning/testing/run-tests.sh` is the suite to extend, not to replace. Section 5 builds a real git repository fixture; sections 2 to 4 use a plain directory. A schema case needs neither git nor a network.

`claude/skills/work-order/scripts/work-order.sh` owns every ticket transition. Never hand-edit a ticket file. `note` is the only way a note reaches a ticket, and `evidence` is the only way a criterion gets ticked.

`claude/skills/hydration-prompt/scripts/hydration.sh` owns `HYDRATION.md`. Run `check --body-file` before `add`; `add` refuses a body that fails `check`.

`claude/skills/container-sandbox/SKILL.md`, and `references/skill-testing.md` beside it, define how a skill's own bundled scripts are tested. This is an ordinary bash script with an ordinary suite, so Rule 14 applies with full force and there is no exemption to claim.

`gh` is authenticated and works in this repository. `gh-axi` wraps it and is preferred where it fits.

### The verification ladder

Rung 1, free: `bash -n claude/skills/skill-versioning/scripts/skill-version.sh`. A syntax error in a script that is only ever run through a container is otherwise found several minutes later.

Rung 2, cheap: render the registry and compare it to the committed file by hand, in a container. `render_registry` reproducing `registry.json` byte for byte is `AC-H1` and it is the cheapest of the three to check.

Rung 3: `grep` the rendered registry for the two `work-order` edges and for the absence of any other, which is `AC-H2`. Assert both halves - that they are there, and that nothing else has one.

Rung 4: a deliberately mistyped `requires:` fails `verify`, which is `AC-H3`. Assert the exit code deliberately, with `if ! cmd; then` or `cmd; rc=$?`. A check that is expected to fail is the one place where `set -e` will end the run for you and report it as an error rather than as the assertion passing.

Rung 5: `bash claude/skills/skill-versioning/testing/run-tests.sh` in Podman, the full suite, with the new cases included and the 72 existing ones still green.

### Traps, already paid for

`render_registry` no longer reproduces the file byte for byte and every skill reads as drifted at once. A trailing newline, a key order change, or a space after a colon does it. Compare the rendered output to the file before touching any test.

`verify` passes when it should have failed. An unknown flag was accepted and ignored. `verify` now rejects unknown options, and the suite asserts it - keep that assertion working if you add a flag.

A `grep -q` in a pipeline reports "no match" when it matched. `grep -q` closes the pipe on the first hit, the upstream command dies of SIGPIPE, and `pipefail` turns that into a non-zero pipeline. Capture to a variable and grep the variable. `diff_check` in `skill-version.sh` is written that way and says why.

The test suite passes on a machine and fails in the container, or the reverse. Minimal images ship neither `cmp` nor `diff`, and Git Bash on Windows has no `flock`. Root `CLAUDE.md` Rule 17 lists what actually bites.

`skill-version.sh verify` refuses the PR with a version and registry mismatch. The skill was edited without a bump. Rule 16, and it applies to `skill-versioning` editing itself.

A command reports success and did nothing. A prompt with no TTY takes its default and exits 0. Assert the post-state, never `$?` alone.

A loop over IDs passes every ID as one argument. This shell is zsh, which does not word-split an unquoted parameter the way bash does. Use `while read -r`, not `for x in $LIST`.

`git merge --ff-only origin/main` refuses with "diverging branches". You are in a treehouse slot at detached HEAD, not in `/home/luna/dotfiles`. Check `git branch --show-current` first.

`git rebase` refuses with "cannot rebase: You have unstaged changes", immediately after `work-order.sh start`. `start` writes the ticket file, `INDEX.md` and the epic README and leaves them uncommitted. Commit them before rebasing.

`work-order.sh done` refuses with "status is 'in-progress'; this command requires one of: in-review". `done` follows `submit --pr N`, so the pull request has to exist before `done` can be run. Open the PR, `submit`, `done`, then commit and push again onto the same PR.

### Workflow

```bash
WO=claude/skills/work-order/scripts/work-order.sh
HP=claude/skills/hydration-prompt/scripts/hydration.sh
SV=claude/skills/skill-versioning/scripts/skill-version.sh

bash $WO show    --project . --id WO-20260824-de9e
bash $WO start   --project . --id WO-20260824-de9e   # creates the branch, leaves files uncommitted

# ... do the work, in a container ...

bash $SV bump    skill-versioning --minor            # Rule 16, and it writes registry.json too
bash $SV verify                                      # this one has to be green

bash $WO evidence --project . --id WO-20260824-de9e --index 1 --observed "..."
bash $WO evidence --project . --id WO-20260824-de9e --index 2 --observed "..."
bash $WO evidence --project . --id WO-20260824-de9e --index 3 --observed "..."
bash $WO note     --project . --id WO-20260824-de9e --text "..."

bash $HP check   --project . --body-file /tmp/entry.md
bash $HP add     --project . --id <next> --title "<next title>" --body-file /tmp/entry.md

git push -u origin <branch>
gh pr create --base main --title "..." --body-file <file>

bash $WO submit  --project . --id WO-20260824-de9e --pr <N>
bash $WO done    --project . --id WO-20260824-de9e   # on the branch, before the merge
git commit && git push                               # rides the same PR

# after the merge
bash $WO close   --project . --id WO-20260824-de9e --dry-run
bash $WO close   --project . --id WO-20260824-de9e
```

`approve` is already done for all 23 tickets and must not be run again.

The pull request description is the merge commit body verbatim. Write it as something worth reading on `main`, because that is where it ends up.

### Conventions

Every reference to a work-order in a chat reply carries the ticket ID and its full title joined by a dash. A bare ID is a defect, and so is "the next ticket" or "the blocked one".

Feature branches only. `main` is never written directly. The one exception to that rule does not exist yet and arrives with the publish workflow.

Squash is the only merge available in this repository. Merge commits and rebase merges are disabled at the repository level, so `gh pr merge --merge` and `--rebase` will be refused.

No em dashes anywhere. Use a plain dash.

No agent co-author line in a commit message, and no Claude attribution footer in a PR body. Root `CLAUDE.md` Rule 13 makes the second one absolute.

All testing runs in Podman, per Rule 14, with no size threshold. This ticket has no exemption to claim: it is a bash script with an existing suite.

Report failures as failures. A skipped step is not a completed one.

<!-- hydration-entry: WO-20260824-6acf -->
## WO-20260824-6acf - Split verify into a structure check and a full check, and delete the notice assertion
_Generated 2026-08-24 by hydration.sh. Newest entry._

### Ticket

`WO-20260824-6acf` - `Split verify into a structure check and a full check, and delete the notice assertion`. Position 3 of 21 children across two epics.
Predecessor `WO-20260824-0615` - `Confirm whether a SessionStart hook matcher filters by source`, merged, closed and archived.

This one writes code, unlike the two before it.
It changes one script and its own test suite, and it is a gate: `WO-20260824-2ad1` - `PR gate workflow: validate the bump intent and run the affected suites` cannot be written until `verify --structure` exists to be called.

### What just landed

An answer, and no code.

`SessionStart` matchers filter by source, and alternation in a matcher is honoured.
Measured on Claude Code 2.1.220 in a scratch project outside this repository, with three `SessionStart` entries whose commands appended the hook payload from stdin to a per-entry log.

```
source     matcher "startup"   matcher "startup|resume|clear"   matcher "" (control)
startup    fired               fired                            fired
resume     -                   fired                            fired
clear      -                   fired                            fired
compact    -                   -                                fired
```

The control entry is the part that makes the result trustworthy.
Without it, a hook that did not fire is indistinguishable from a session event that never happened, and the conclusion would have rested on an absence nobody could account for.

The consequence is that the design's safety property is available from the matcher alone.
`WO-20260824-bb0d` - `setup.sh installs the skill-sync binary, then the SessionStart hook` uses `"matcher": "startup|resume|clear"`, and that exact string is confirmed rather than assumed.
`WO-20260824-5b89` - `skill-sync.sh part one: resolution, and the tools test tree it is proved in` gains nothing.
It needs no stdin read and no early exit of its own, because the fallback branch did not happen.

The full truth table, how each of the four events was produced, and both consequences are on the ticket as a note.
Be aware that `work-order.sh note` stores a note as a single bullet, so the table is flattened there and is only readable as prose. The readable copy is this entry and the merge commit body.

The repository files that changed are the ticket file, `work-orders/INDEX.md`, the epic README, and `HYDRATION.md`.
`~/.claude/settings.json` was not touched, and the scratch project was deleted.

### What is NOT done

Nothing has been built in either epic. Nineteen of the twenty-one tickets have never been started and none of them has a branch.

Each of these is a command whose output proves the claim, measured on `main` after this ticket merged:

- `ls claude/tools` fails. No `skill-sync.sh`, no `skill-onboard.sh`, no notice partial, no tools test suite.
- `git ls-files .github/workflows` prints nothing. There is no PR gate and no publisher, so nothing yet reads the `Bump:` trailer that `WO-20260824-cc71` - `Repo settings: squash-only, with the commit body taken from the PR description` made possible.
- `head -c 40 claude/skills/registry.json` shows `"schema": 1`. Schema 2 is unwritten.
- `grep -l "This copy is read-only" claude/skills/*/SKILL.md | wc -l` prints `43`. Every skill still carries the inline notice.
- `grep -n "structure" claude/skills/skill-versioning/scripts/skill-version.sh` prints nothing. `verify` has one form, and it is the strict one.

Nothing was carried off `WO-20260824-0615` - `Confirm whether a SessionStart hook matcher filters by source` onto another ticket. Both of its acceptance criteria were met and evidenced separately.

Branch protection rules and required status checks are still absent, and are still on no ticket at all. That has not changed and is not this ticket's business.

### Stale or false in the docs

The design spec `docs/superpowers/specs/2026-08-23-skills-package-manager-design.md` carries an implementation note under `Problem A - a sync fires while an agent is mid-task` reading "Confirm that `SessionStart` matchers accept the source string before building on it. If they do not, the fallback is for `skill-sync` to read the source from the hook payload on stdin and exit early itself."
That is now answered. They do accept it, the fallback is dead, and the note is a question that has been closed.

The plan `docs/superpowers/plans/2026-08-24-skills-package-manager-implementation.md` says the same thing twice: at `C7 - the matcher is unconfirmed and gates the hook`, and in `E1.2`'s "if they do not" branch.
Both are answered by the same result. The gate is open and the fallback branch never fires.

Neither is worth a fix-up commit on its own. `WO-20260824-bb0d` - `setup.sh installs the skill-sync binary, then the SessionStart hook` is the ticket that touches this material and can correct both in passing.

The same two documents still state the repository settings as `squash_merge_commit_message=COMMIT_MESSAGES`, `allow_merge_commit=true`, `allow_rebase_merge=true`, at `C2` in the plan and under `Repo settings, first` in the spec.
Those were true when written on 2026-08-24 and are false now. All three were changed by `WO-20260824-cc71` - `Repo settings: squash-only, with the commit body taken from the PR description`.

Root `CLAUDE.md` Rule 16 still requires a PR touching a skill to bump the version and ship a regenerated `registry.json` by hand.
That is true today and **it binds this ticket**, which edits `claude/skills/skill-versioning/`. It becomes false at `WO-20260824-8cd1` - `Rewrite root CLAUDE.md for merge-time allocation and the named main exception`, and not before.

This repository has no `CONTEXT_STATE.md`. Several skills assume one and the `hydration-prompt` skill's flow references one. It genuinely does not exist here. Do not create one as a side effect of this ticket.

### Your scope

One script and its own test suite: `claude/skills/skill-versioning/scripts/skill-version.sh` and `claude/skills/skill-versioning/testing/run-tests.sh`.

Three changes, and they are one piece of work:

1. `verify --structure` is added. It asserts every skill has a `version:`, and that no `version:` line and no `registry.json` was hand-edited in the diff. It says **nothing** about whether `registry.json` matches the tree.
2. Plain `verify` keeps exactly the meaning it has today: everything `--structure` checks, plus `render_registry` matching `registry.json` on disk.
3. The read-only notice check is **deleted**. It is the `grep -qF 'This copy is read-only.'` block and the `SKILL_SRC_URL` branch beside it, around `skill-version.sh:192-197`, together with the `noro` variable and the failure message it prints.

The reason for the split is merge-time allocation: a skill PR will legitimately edit a skill and leave the registry alone, and that state has to pass the PR gate while still failing the publisher's strict check.

Do **not** add an assertion that the notice is absent. That is `WO-20260824-2ad1`'s successor `E2.7` and it cannot land until all 42 remaining `SKILL.md` files are clean. `C1` in the plan is the whole argument, and skipping the middle state is named there as the single most likely way to make the pilot PR fail its own gate.

Out of scope, and named because they are the obvious next thoughts: removing the notice from any `SKILL.md`, which `E2.6` owns, and writing the PR gate workflow that will call the new form, which is `WO-20260824-2ad1` - `PR gate workflow: validate the bump intent and run the affected suites`.

### Before you start

None.

One thing to be aware of rather than to resolve. This ticket edits a skill, so Rule 16 applies to its own PR, and the skill it edits is the one that owns versioning. Bump `skill-versioning` with its own script and ship the regenerated `registry.json`, exactly as any other skill edit would. There is nothing circular about it in practice; the script bumps itself the same way it bumps anything else. It is worth noticing before the PR rather than after `verify` refuses it.

### Read in this order

1. Root `CLAUDE.md`. Rules 12, 14, 15 and 16 bear on this work. There is no `CONTEXT_STATE.md` in this repository, so the usual second step does not apply.
2. This entry, which is the top entry of `HYDRATION.md`. Read only this one. The entries below it are superseded history.
3. `docs/superpowers/plans/2026-08-24-skills-package-manager-implementation.md`, section `C1 - the notice check cannot invert until the last SKILL.md is clean`, then `E1.3`. C1 is why the notice check is deleted rather than inverted.
4. The ticket file: `work-orders/WO-20260824-f1a5/WO-20260824-6acf-split-verify-into-a-structure-check-and-a-full-c.md`.
5. `claude/skills/skill-versioning/scripts/skill-version.sh`, the whole `verify` function, before changing any of it.
6. `claude/skills/skill-versioning/testing/run-tests.sh`, to see the case shape the two new cases have to match.

### Reuse, it is proven

`claude/skills/skill-versioning/scripts/skill-version.sh` already owns `version:` and `registry.json` as formats. Neither is ever hand-edited, and that rule applies to this ticket's own bump as much as to anyone else's.

`claude/skills/skill-versioning/testing/run-tests.sh` is the suite to extend, not to replace. Seven skills in this repository ship a `testing/run-tests.sh` and they share a shape.

`claude/skills/work-order/scripts/work-order.sh` owns every ticket transition. Never hand-edit a ticket file. `note` is the only way a note reaches a ticket, and `evidence` is the only way a criterion gets ticked.

`claude/skills/hydration-prompt/scripts/hydration.sh` owns `HYDRATION.md`. Run `check --body-file` before `add`; `add` refuses a body that fails `check`.

`claude/skills/container-sandbox/SKILL.md`, and `references/skill-testing.md` beside it, define how a skill's own bundled scripts are tested. Unlike the predecessor ticket, this one is an ordinary bash script with an ordinary suite, so Rule 14 applies with full force and there is no exemption to claim.

`gh` is authenticated and works in this repository. `gh-axi` wraps it and is preferred where it fits.

### The verification ladder

Rung 1, free: `bash -n claude/skills/skill-versioning/scripts/skill-version.sh`. A syntax error in a bash script that is only ever run through a container is otherwise found several minutes later.

Rung 2, cheap: `skill-version.sh verify --help` and `verify --structure --help`, in a container. Proves the new flag is wired into argument parsing at all, which is the failure that otherwise looks like a passing check because an unknown flag was silently ignored.

Rung 3, the actual acceptance criterion: on a branch that edits a skill and leaves the registry alone, `verify --structure` exits 0 and plain `verify` exits non-zero. Two exit codes, and they are the whole point of the ticket.

Rung 4: `bash claude/skills/skill-versioning/testing/run-tests.sh` in Podman, the full suite, both new cases included.

Assert the exit code deliberately, with `if ! cmd; then` or `cmd; rc=$?`. A check that is expected to fail is the one place where `set -e` will end the run for you and report it as an error rather than as the assertion passing.

### Traps, already paid for

`verify` passes when it should have failed. An unknown flag was accepted and ignored, so `--structure` did nothing and the strict path ran. Rung 2 exists for this.

The test suite passes on a machine and fails in the container, or the reverse. Minimal images ship neither `cmp` nor `diff`, and Git Bash on Windows has no `flock`. Root `CLAUDE.md` Rule 17 lists what actually bites.

`skill-version.sh verify` refuses the PR with a version and registry mismatch. The skill was edited without a bump. Rule 16, and it applies to `skill-versioning` editing itself.

A command reports success and did nothing. A prompt with no TTY takes its default and exits 0. Assert the post-state, never `$?` alone.

A loop over IDs passes every ID as one argument. This shell is zsh, which does not word-split an unquoted parameter the way bash does. Use `while read -r`, not `for x in $LIST`.

`git merge --ff-only origin/main` refuses with "diverging branches". You are in a treehouse slot at detached HEAD, not in `/home/luna/dotfiles`. Check `git branch --show-current` first.

`git rebase` refuses with "cannot rebase: You have unstaged changes", immediately after `work-order.sh start`. `start` writes the ticket file, `INDEX.md` and the epic README and leaves them uncommitted. Commit them before rebasing.

`work-order.sh done` refuses with "status is 'in-progress'; this command requires one of: in-review". `done` follows `submit --pr N`, so the pull request has to exist before `done` can be run. Open the PR, `submit`, `done`, then commit and push again onto the same PR.

### Workflow

```bash
WO=claude/skills/work-order/scripts/work-order.sh
HP=claude/skills/hydration-prompt/scripts/hydration.sh
SV=claude/skills/skill-versioning/scripts/skill-version.sh

bash $WO show    --project . --id WO-20260824-6acf
bash $WO start   --project . --id WO-20260824-6acf   # creates the branch, leaves files uncommitted

# ... do the work, in a container ...

bash $SV bump    skill-versioning --minor            # Rule 16, and it writes registry.json too
bash $SV verify

bash $WO evidence --project . --id WO-20260824-6acf --index 1 --observed "..."
bash $WO evidence --project . --id WO-20260824-6acf --index 2 --observed "..."
bash $WO note     --project . --id WO-20260824-6acf --text "..."

bash $HP check   --project . --body-file /tmp/entry.md
bash $HP add     --project . --id <next> --title "<next title>" --body-file /tmp/entry.md

git push -u origin <branch>
gh pr create --base main --title "..." --body-file <file>

bash $WO submit  --project . --id WO-20260824-6acf --pr <N>
bash $WO done    --project . --id WO-20260824-6acf   # on the branch, before the merge
git commit && git push                               # rides the same PR

# after the merge
bash $WO close   --project . --id WO-20260824-6acf --dry-run
bash $WO close   --project . --id WO-20260824-6acf
```

`approve` is already done for all 23 tickets and must not be run again.

The pull request description is the merge commit body verbatim. Write it as something worth reading on `main`, because that is where it ends up.

### Conventions

Every reference to a work-order in a chat reply carries the ticket ID and its full title joined by a dash. A bare ID is a defect, and so is "the next ticket" or "the blocked one".

Feature branches only. `main` is never written directly. The one exception to that rule does not exist yet and arrives with the publish workflow.

Squash is the only merge available in this repository. Merge commits and rebase merges are disabled at the repository level, so `gh pr merge --merge` and `--rebase` will be refused.

No em dashes anywhere. Use a plain dash.

No agent co-author line in a commit message, and no Claude attribution footer in a PR body. Root `CLAUDE.md` Rule 13 makes the second one absolute.

All testing runs in Podman, per Rule 14, with no size threshold. This ticket has no exemption to claim: it is a bash script with an existing suite.

Report failures as failures. A skipped step is not a completed one.

