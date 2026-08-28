# HYDRATION.md

The prompt that starts the next session, and the 10 before it.

**Read the top entry only.** It is the current one and it is complete on its own.
Everything below it has been superseded and is kept for history, not for reading.

**Newest on top.** Adding an entry removes the oldest in the same commit, so this
file holds exactly 10 once it has filled up. Entries are never renumbered and
never edited in place - a correction is a new entry.

Written by `hydration.sh add`. Do not hand-edit.
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

