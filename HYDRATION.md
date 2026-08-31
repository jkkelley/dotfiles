# HYDRATION.md

The prompt that starts the next session, and the 10 before it.

**Read the top entry only.** It is the current one and it is complete on its own.
Everything below it has been superseded and is kept for history, not for reading.

**Newest on top.** Adding an entry removes the oldest in the same commit, so this
file holds exactly 10 once it has filled up. Entries are never renumbered and
never edited in place - a correction is a new entry.

Written by `hydration.sh add`. Do not hand-edit.
<!-- hydration-entry: WO-20260824-00d5 -->
## WO-20260824-00d5 - Skills package manager: roll it out across the repository
_Generated 2026-08-31 by hydration.sh. Newest entry._

### Ticket

`WO-20260824-00d5` - `Skills package manager: roll it out across the repository`.
It is the epic itself, `feature`, `p2`, `ready`, and it is now the only thing `work-order.sh next` offers.
All 22 children are `done` and archived; the seventh and last of the approved order, `WO-20260830-eb89` - `skill-sync fills the CLAUDE.md skills table between the markers`, merged as PR #92.

Closing an epic is its own act with its own acceptance criteria, and it goes through the same lifecycle as any other ticket: `start`, evidence, `submit --pr N`, `done`, on a branch, inside one pull request.
There is no `work-order.sh close`, whatever the epic's own Outcome placeholder says.

Three acceptance criteria, all `(human)`.
Two are greps over this repository.
The third, `AC-H3`, is an end-to-end run and it is the one that decides how the session is shaped - read `Before you start` before planning anything.

Predecessor `WO-20260830-eb89` - `skill-sync fills the CLAUDE.md skills table between the markers`, merged, closed and archived.

### What just landed

**PR #92, `WO-20260830-eb89`.**
`claude/tools/skill-sync.sh` grew one function, `fill_skills_block`, called from `cmd_boot` after the receipt and the stamp and only after an apply that worked.
It rewrites the block between `skills:begin` and `skills:end` in the project's `CLAUDE.md` with one `- name` line per skill, sorted under `LC_ALL=C`.
`skill-tool-version` was raised by hand from `2.0.0` to `2.1.0`; the publisher rendered the registry's `tools` row from it and committed `registry.json` alone.

Two files changed, plus the ticket paperwork.
The suite went from 350 assertions to 406, all green.

**Three decisions inside it, each of which was a fork.**

A **list**, not the `Skill | Agent` table the design doc draws at `docs/superpowers/specs/2026-08-23-skills-package-manager-design.md:747`.
`skill-sync` installs no agents - `resolve`'s own comment says a name under `[agents]` must never reach the skills set - so the second column is one the writer cannot fill, and the template's own prose, shipped later by `WO-20260824-b21b`, calls it "the list below".

**`CLAIMED`, not `OWNED`.**
A skill the registry promises and the source tree does not have is owned and is not on disk, and listing it would be the same lie as a stale version, in the same file, to the same reader.

**Written only when it would change something.**
Byte-identity is what `AC-H2` asked for and an unconditional rewrite also satisfies it; not writing at all is strictly better, because a project's `CLAUDE.md` is a tracked file a human has open and a new mtime every fifteen minutes is churn a watcher sees.
The comparison is a string compare and not `cmp`, per Rule 17.

**The markers are matched as whole lines, byte for byte, and every miss has the same outcome.**
No pair, half a pair, a reworded pair, an end before a begin: nothing written, sync still succeeds, exactly as a project with no `CLAUDE.md` at all.

**The three assertions that matter were proved by breaking the implementation on purpose**, one mutation at a time against the real tree, and watching the suite go red.
A substring marker match turns `[reworded] CLAUDE.md is byte-identical afterwards` red.
Removing the unchanged-file guard turns `does not rewrite the file at all` red.
Emitting `- name 1.2.3` turns six assertions red including `AC-H4`'s own.
This is the rung that is worth keeping: it is the only one that proves an assertion of absence can fail.

Before that: PR #91 shipped `238b`, PR #90 shipped `79b6`, PR #89 shipped `d058`, PR #88 shipped `6a33`, PR #87 put the discovery on the epic, PR #86 shipped `c6b0` and `skill-onboard.sh`, PR #85 shipped `b21b`, PR #84 shipped `81a6`, PR #83 shipped `slot.sh`.
Epic 1 closed at PR #79.

### What is NOT done

**No project on this machine has had the fill applied to it**, because nothing has synced since PR #92 merged and a sync only fetches what is published on `main`.
`grep -rl 'skills:begin' ~/ --include=CLAUDE.md` is the command whose output tells you which projects even carry the pair; a filled block is one with `- ` lines between the markers.

**The two `publish.sh` defects found on `238b` are still on no ticket**, and PR #92 did not touch them.
A `FRESH` skill never reaches `record()`, so a rename can never carry a level and a `Bump: <renamed>=major` trailer is read, validated and silently discarded.
And `report()` and `commit_message()` both print `1.0.0` unconditionally for a `FRESH` skill while `init` stamps only unversioned ones, so a rename of an already-versioned skill misreports.

**Two `skill-onboard.sh` defects are on no ticket**, both recorded on the epic and on row 4 of `docs/skills-onboarding-checklist.md`.
`LEGACY_HEADING` at `skill-onboard.sh:71` is byte `2d`, U+002D HYPHEN-MINUS, and `claudes-markdown-12-rules` `CLAUDE.md:69` is `e2 80 94`, U+2014 EM DASH, so `section_of`'s whole-line match misses and the `else` at line 430 appends `## Skills` while leaving 68 stale lines above it, exiting 0.
The same repository has no `.claude/skills/` directory, so discovery dies at line 358 with exit 3.

**`CLAUDE.md.tmpl:98` carries `https://github.com/jkkelley/local-k8s-docs`**, a username and a repository name together, and it is not one of the two exceptions the PII policy documents at `CLAUDE.md:297`.
On no ticket.

**11 of 13 skills with a `scripts/` directory still have no `justfile`**, which root `CLAUDE.md` Rule 17 requires.
Only `context-compaction` and `living-docs` have one, and `bump-gate.sh:33` and `.github/scripts/testing/run-tests.sh:30` both still claim `skill-registry` has one when it does not.
On no ticket, named here for the sixteenth cycle.

Branch protection is still absent and is still on no ticket.

**`work-order.sh approve` and `link` both strand themselves, and it is on no ticket.**
Each writes the ticket file and `INDEX.md`; `start` refuses a dirty tree; `start` is what creates the branch.
A `start --on-current-branch` would remove it.

Root `CLAUDE.md`'s `## Consuming These Files` section still contradicts Rule 16 steps 7 and 8, **on no ticket** after fifteen cycles.

**The four onboarding runs in `docs/skills-onboarding-checklist.md` are the user's own, claimed on 2026-08-22.**
`grep -c '\[x\] done' docs/skills-onboarding-checklist.md` returns 0 and that is the expected state, not a gap.
It is recorded here so you do not rediscover it and treat it as work.
**Do not raise it in a reply, do not list it as an open item, do not fold it into a recommendation.**
It comes back up only if the user raises it.

### Stale or false in the docs

**`workflows/close-out-procedure.md` was stale on exactly this point and is now fixed, on PR #92.**
Lines 20 and 21 told a contributor to run `skill-version.sh bump <skill> --patch` on the feature branch and then to expect plain `verify` at rc 0.
Both describe the pre-Rule-16 world, and plain `verify` is _expected_ to be red on any branch that touched a skill.
They now read `skill-version.sh verify --structure` and the `Bump: <skill>=major|minor|patch` trailer, at `workflow-version 1.0.1`.
The rest of that document is current and it is the file to follow for the ordering.
Note that nothing in CI covers it: `bump-gate.sh detect` watches `claude/skills/`, `claude/tools/` and the gate itself, so a change under `workflows/` runs no suite.
`tools/testing/run-tests.sh` is the one that covers `workflow-version.sh`, it is run by hand, and it was green at 38 assertions.

**The design document's installed-list example no longer matches what ships.**
`docs/superpowers/specs/2026-08-23-skills-package-manager-design.md:747` draws a two-column `Skill | Agent` table; `skill-sync` writes a one-per-line list of skill names, for the reason recorded above and in PR #92's body.
The rest of that section - names only, no versions, generated between the markers - is exactly what shipped.

**Both design documents under `docs/superpowers/` still name `skill-versioning`, and that was a deliberate decision.**
`238b`'s `AC-H1` drew the line to put both documents inside "history": they are dated, the spec is marked `Status: settled`, and every occurrence is the old name as the subject of a recorded decision rather than a path anyone follows.
`notes/skills-pm-discovery.md`, `HYDRATION.md` and the whole `work-orders/` tree were treated the same way.
**Do not "finish" the rename in those files.** If you disagree, that is a conversation to have, not an edit to make.

**The design doc's example manifest is stale and decision 20 wins.**
`docs/superpowers/specs/2026-08-23-skills-package-manager-design.md:195` lists `project-scaffold` where decision 20 lists `context-compaction`.

**Both design documents still say the runner only has Docker.**
`ubuntu-24.04` ships Podman 5.8.4.

**`claude/skills/work-order/settings.local.json.tmpl:6` still names `work-order.sh close`.**
There is no `close` verb; the lifecycle ends at `done`, on the branch, inside the pull request.
The epic's own Outcome placeholder says the same thing and is wrong in the same way.
On no ticket.

**The close-out diagram in `CLAUDE.md.tmpl` puts the pull request at step 4, after `done` at step 2.**
The real order is `gh pr create`, then `submit --pr N`, then `done`.
On no ticket.

**`project-scaffold/testing/run-tests.sh` pins `python:3.12-slim` by tag, not by digest**, a Rule 15 violation.
Left alone deliberately eight times now.
On no ticket.

**`scaffold.sh:214` depends on `cmp`**, which Rule 17 says to check for.
Present in Git Bash so not a live break.
On no ticket.

### Your scope

The epic's Scope block defines it and this section does not restate it.
What is worth knowing is that the epic's three criteria are not three greps.

`AC-H1`, no SKILL.md contains the inline read-only notice, and `AC-H2`, `git grep skill-versioning` returns nothing outside history, are both assertions of absence over this repository.
`d058`, `79b6` and `238b` each already evidenced their own half of these; the epic's job is to state the whole, at the end, on the tree as it now stands.
An assertion of absence is worth nothing until it has returned non-zero on purpose, and both of these have a live regression check behind them - `verify --structure` fails on a notice that is present.

`AC-H3`, a freshly scaffolded project syncs the four default skills on its first session, is the only one that exercises the thing end to end, and it now covers PR #92 as well: a project scaffolded from `CLAUDE.md.tmpl` gets the marker pair, and its first sync should fill it with those four names.
That makes `AC-H3` the strongest evidence available that the epic actually closed, and the weakest to fake.

Nothing in the epic asks for new code.
If the run turns up a defect, the honest outcome is a criterion evidenced as NOT MET with the defect named, plus a ticket - not a fix smuggled into the closing commit.

### Before you start

**`AC-H3` needs the network and it needs PR #92 on `main` first.**
`skill-sync --boot` fetches `registry.json` and the source tarball from `jkkelley/dotfiles@main`, so a container running it must have the network on, which is the opposite of how every suite in this repository runs.
`claude/tools/testing/run-tests.sh` stubs `curl` precisely so it never needs this; a real first-session run does not have that option.
Decide deliberately: a network-enabled container for that one run, per `container-sandbox`, or a local source tree served in place of codeload.
Whichever you choose, say which one you did in the evidence, because "it synced" means two different things.

**PR #92 is merged before you start.** If `git log origin/main --oneline -3` does not show it, the epic cannot be evidenced yet and the session's first act is to say so.

The epic has no assumptions and no open questions.
It has one long note dated `2026-08-31` recording the four-repository discovery, and three notes on the approved order.
Read the notes rather than re-deriving anything from them.

`work-order.sh start` needs a clean tree and creates the branch for you.
It leaves the ticket file and `INDEX.md` uncommitted, so commit them before anything else.

An untracked `.claude/worktrees/smoke-tests` sits in the working directory.
It is a registered git worktree on branch `worktree-smoke-tests`, left by an earlier session, and it predates this ticket and the four before it.
`git status` shows it as `?? .claude/worktrees/` and `gh pr create` warns `Warning: 1 uncommitted change` because of it.
It is harmless and it is not yours; leave it or ask the user before removing it.
Its vendored copy of `CLAUDE.md.tmpl` still names `skill-versioning` - that is a stale worktree, not a missed reference.

### Read in this order

1. The epic, `work-orders/WO-20260824-00d5/WO-20260824-00d5-skills-package-manager-roll-it-out-across-the-re.md`, in full, notes included.
2. This entry, the top entry of `HYDRATION.md`. Read only this one.
3. `workflows/close-out-procedure.md`, for the ordering. It is current as of `1.0.1`, which PR #92 corrected.
4. `claude/tools/skill-sync.sh`, `fill_skills_block` and `cmd_boot`, for what a first session now writes.
5. `claude/skills/project-scaffold/references/templates/CLAUDE.md.tmpl` and `skills.toml.tmpl`, which are what `AC-H3` scaffolds from.
6. PR #92's body, for how a criterion is evidenced when the proof is a mutation rather than a green run.
7. `claude/skills/container-sandbox/references/skill-testing.md`, the "Driving a repository-level gate against the real tree" section, which is the container shape to start from.

### Reuse, it is proven

**Break the implementation on purpose and watch the suite go red.**
Three mutations on PR #92, one at a time, each restored from a copy taken first: a loosened marker match, a removed idempotency guard, a version appended to each name.
Every one was caught, and the count of assertions that went red is the evidence.
This is cheaper than it sounds - one suite run each, about ninety seconds - and it is the only thing that proves an assertion of absence can fail.

**`bump-gate.sh run-suite <skill-dir>` is how a suite is run**, and `--print` tells you whether it self re-execs into a container or has to be wrapped.
`claude/tools` is `self`.
`skill-registry` is `wrapped`.

**`bump-gate.sh detect --base origin/main` tells you the matrix before you push.**
On PR #92 it emitted `skills=[]`, `tools=true`, `gate=false`, which is what a tools-only change looks like and is why that pull request carried no `Bump:` trailer at all.

**`bump-gate.sh resolve --base origin/main --title-file F --body-file F`** prints the `current -> next` table locally, exactly as the gate will.
With no skill changed it prints `No skill changed on this branch. Nothing to resolve.` and exits 0, which is the correct green.

**Simulating the squash merge and running `publish.sh apply` over it is still the rung that pays for itself.**
On PR #92 it showed the whole tool-only path: `verify` red on the drifted `skill-sync` row, `No skill changed in this range. Nothing to allocate.`, `init` regenerating the registry, `verify` green at 43 skills, and one commit carrying `registry.json` alone.

**The container pattern is `references/skill-testing.md` "Driving a repository-level gate against the real tree".**
Clone into `/work`, mount the repository read-only at `/repo`, `bitnami/git` pinned by digest, `--network=none`.
It has now worked unmodified on `d058`, `79b6`, `238b` and `eb89`.

**`git clone` carries commits, not a working tree.**
Commit before the container run or you measure `main`.

### The verification ladder

Cheapest rung first.
Rung 0 is new and it is the one `eb89` got its confidence from.

0. **`bash -n` on every file you touched**, in a container. Free, and it catches an unbalanced quote before a suite spends two minutes finding it.
1. **`bash <script> --help`** in a container - also free, and it proves the file still parses as a program rather than as text.
2. **The changed suite** via `bump-gate.sh run-suite`. On `eb89`: 406 assertions, all green.
3. **Mutate the implementation, one defect at a time, and re-run.** An assertion that stays green under the defect it was written for is decoration. Restore from a copy taken before the first mutation, and re-run once more to prove you restored it.
4. **`bump-gate.sh detect --base origin/main`** - proves the matrix will run what you just ran, and tells you which other skills you dragged in.
5. **`bump-gate.sh resolve`** with the real title and body files, plus `skill-version.sh verify --structure --base origin/main`.
6. **The squash merge simulated, and `publish.sh apply` run over it, on a clone of the real tree.** The only rung that shows you what actually reaches `main`.

### Traps, already paid for

**A file the container cannot read makes `cat` print nothing and the pipeline carry on.**
Symptom: `git commit -F -` fails on an empty message, the squash stays staged, and `publish.sh`'s own commit swallows every file the branch changed - a six-file "registry" commit that looks almost right.
Cause: the title and body files were written outside the directory that was mounted at `/work`.
Fix: put them inside the mount, and run the inner script under `bash -euc` so the failed `cat` stops the run instead of narrating past it.

**`mv` needs the directory writable, not the file.**
Symptom: a `chmod a-w` on a file does not produce the failure path you were trying to test, because the replace succeeds anyway.
Cause: replacing a file is an unlink plus a rename in its parent.
Make the parent directory unwritable, and assert the lock really took - a run as root ignores the mode and the case passes for the wrong reason.

**An mtime comparison inside one second proves nothing.**
Symptom: "it did not rewrite the file" is green against an implementation that rewrites it every time.
Fix: `touch -d '1 hour ago'` the file first, then assert the mtime did not move.

**A `!` in the title applies to every skill in the changed set that has no trailer.**
Symptom: an unrelated skill you edited one comment line in is published as a major.
Cause: `title_level` at `bump-lib.sh:123` returns `major` on the bang before it ever looks at the type.
Fix: a `Bump: <skill>=patch` trailer per incidental skill. `resolve`'s `source` column is where you see it.

**`work-order.sh evidence` checks the box unconditionally**, and `done` refuses any unchecked criterion.
Symptom: a criterion that was not met still renders as `- [x]`.
Cause: the tick means "observed and recorded", not "passed"; the observation text carries the verdict, so put MET or NOT MET in its first words.

**`grep -q` in a pipeline kills the writer with SIGPIPE and `pipefail` reports it as no-match.**
Symptom: a check passes precisely when it should fail.
`diff_check` at `skill-version.sh:425` captures into a variable first and there is a comment there saying why.

**`gh pr create` warns about untracked files and creates the PR anyway.**
Symptom: `Warning: 1 uncommitted change` in the middle of the output.
Cause: the stale `.claude/worktrees/` directory. It is not your branch being dirty.

### Workflow

```sh
WO=~/.claude/skills/work-order/scripts/work-order.sh
HP=~/.claude/skills/hydration-prompt/scripts/hydration.sh

git log origin/main --oneline -3          # PR #92 must be here first

bash $WO start    --id WO-20260824-00d5
git add work-orders && git commit -m "chore(work-order): start WO-20260824-00d5"

# AC-H1 and AC-H2, both assertions of absence, both in a container
git grep -n 'This copy is read-only' -- 'claude/skills/**/SKILL.md'
git grep -n skill-versioning -- . ':!docs/superpowers' ':!work-orders' ':!HYDRATION.md' ':!notes'

# AC-H3 is the end-to-end one and it needs the network. Decide and record which.

bash $WO evidence --id WO-20260824-00d5 --index 1 --observed "MET|NOT MET. ..."
bash $WO evidence --id WO-20260824-00d5 --index 2 --observed "MET|NOT MET. ..."
bash $WO evidence --id WO-20260824-00d5 --index 3 --observed "MET|NOT MET. ..."

git push -u origin feat/skills-package-manager-roll-it-out-across-the-re
gh pr create --base main --title "chore(skills): close the skills package manager rollout epic" \
  --body-file /tmp/pr-body.md

bash $WO submit   --id WO-20260824-00d5 --pr <N>
bash $WO done     --id WO-20260824-00d5
bash $HP check    --project . --body-file /tmp/entry.md
bash $HP add      --project . --id <next> --title "..." --body-file /tmp/entry.md
git add -A && git commit && git push        # rides the same pull request

# after the merge, when the user says it is merged
bash $WO cleanup  --id WO-20260824-00d5
```

`submit` must precede `done`, and both happen on the branch before the merge.
Nothing is written to `main` afterwards except the publisher's own commit.

**When this epic closes there is no next ticket.**
`work-order.sh next` will offer nothing, and the several items above marked "on no ticket" are the candidate list.
Do not cut any of them without asking - the user decides what comes next.

### Conventions

Every reference to a work-order in a chat reply carries the ticket ID **and** its full title, joined by a dash, on the first mention and on every mention after it.
A bare ID is a defect, and so is "the next ticket" or "the blocked one".
Take the title from the ticket file, never from the truncated tree in `INDEX.md`.

Never use the em dash.
Use a plain dash instead.

Never add an agent co-author line to a commit message, and never add the Claude footer to a PR body.
Root `CLAUDE.md` Rule 13 makes the second one absolute.

Report failing tests as failing, with the output.
Say what was skipped.
Rule 12: "completed" is wrong if anything was skipped silently, and a criterion that was not met is reported as not met.

All testing runs in Podman, per Rule 14, with no size threshold.
A single `--help` invocation counts.

Feature branches only.
`main` is written directly by `.github/workflows/skill-publish.yml` and by nothing else.

<!-- hydration-entry: WO-20260830-eb89 -->
## WO-20260830-eb89 - skill-sync fills the CLAUDE.md skills table between the markers
_Generated 2026-08-31 by hydration.sh. Newest entry._

### Ticket

`WO-20260830-eb89` - `skill-sync fills the CLAUDE.md skills table between the markers`.
It is a `feature`, `p2`, a child of `WO-20260824-00d5` - `Skills package manager: roll it out across the repository`.
Position 7 of 7 in the approved order, which is a note on the epic dated 2026-08-30.
Read that note rather than re-deriving the order; if you think it is wrong, say so and ask.

Its single dependency, `WO-20260824-238b` - `Rename skill-versioning to skill-registry, the closing commit`, is now `done`.
`work-order.sh next` offers it and `WO-20260824-00d5` - `Skills package manager: roll it out across the repository` and nothing else.

It has no point estimate and no notes.
Four acceptance criteria, all `(human)`, and three of the four are assertions about a file being **byte-identical** after an operation - which is the shape that decides how you test it long before you write any code.

Predecessor `WO-20260824-238b` - `Rename skill-versioning to skill-registry, the closing commit`, merged, closed and archived.

### What just landed

**PR #91, `WO-20260824-238b`.**
`claude/skills/skill-versioning` is now `claude/skills/skill-registry`.
Twelve files: four renamed with git pairing both halves, eight edited.
`skill-version.sh` deliberately keeps its name, which is the ticket's explicit non-goal, so the directory and the script inside it now disagree - `publish.sh` has a comment saying that is intended rather than a half-done rename.

**The rename is not the part worth reading. Two findings are.**

**`AC-H3` was recorded NOT MET, and the pipeline cannot satisfy a criterion of that shape.**
It asked that the publish run record a major bump for `skill-registry`.
`publish.sh` files a skill absent from `registry.json` into `FRESH` at `note()`, line 188; a `FRESH` skill never reaches `record()`, because `collect()` does `note "$s" || continue`, and `cmd_apply` loops `EXISTING` only.
A renamed directory is absent from the registry under its new name by definition, so **a rename can never carry a level**.
A `Bump: skill-registry=major` trailer is read, validated, and silently discarded.
No such trailer was written, deliberately.
Extending the publisher to carry a level across a rename is real work and it is **on no ticket**.

**A second defect, found on the way, and on no ticket.**
`report()` and `commit_message()` in `publish.sh` both print `1.0.0` unconditionally for a `FRESH` skill, but `init` stamps only _unversioned_ ones.
The first run of the branch still carried the `version: 2.1.0` line the `git mv` brought across, and the publisher produced a commit message saying `skill-registry -> 1.0.0` beside a `registry.json` it wrote in that same commit saying `2.1.0`.
The `version:` line was dropped on the user's decision of 2026-08-31 so the two agree at `1.0.0`.
**That masks the misreport; it does not fix it.** Any future rename of an already-versioned skill hits it again.

**`project-scaffold` was nearly shipped a false major.**
One comment line in `claude/skills/project-scaffold/testing/run-tests.sh` named the old skill and had to change, which put the skill in the changed set, and the `!` in `chore(skills)!:` resolved it to `major` by the title fallback.
A `Bump: project-scaffold=patch` trailer fixed it, and the published result was `1.5.1 -> 1.5.2`.
Caught by running `publish.sh apply` against a clone of the real tree **before pushing**, not by reading the diff.
This is the general trap: a `!` title plus an incidental one-line edit in an unrelated skill is a breaking-change signal to every project holding it.

Before that: PR #90 shipped `79b6`, PR #89 shipped `d058`, PR #88 shipped `6a33`, PR #87 put the discovery on the epic, PR #86 shipped `c6b0` and `skill-onboard.sh`, PR #85 shipped `b21b`, PR #84 shipped `81a6`, PR #83 shipped `slot.sh`.
Epic 1 closed at PR #79.

### What is NOT done

**Nothing about the marker fill has been started.**
No branch exists, and `claude/tools/skill-sync.sh` writes nothing outside `.claude/skills/` today - which the ticket's Problem statement says was never anyone's scope rather than anyone's omission.

**The two `publish.sh` defects above are on no ticket**, and they are the freshest thing in the repository.

**Two `skill-onboard.sh` defects are on no ticket**, both recorded on the epic and on row 4 of `docs/skills-onboarding-checklist.md`.
`LEGACY_HEADING` at `skill-onboard.sh:71` is byte `2d`, U+002D HYPHEN-MINUS, and `claudes-markdown-12-rules` `CLAUDE.md:69` is `e2 80 94`, U+2014 EM DASH, so `section_of`'s whole-line match misses and the `else` at line 430 appends `## Skills` while leaving 68 stale lines above it, exiting 0.
The same repository has no `.claude/skills/` directory, so discovery dies at line 358 with exit 3.

**`CLAUDE.md.tmpl:98` carries `https://github.com/jkkelley/local-k8s-docs`**, a username and a repository name together, and it is not one of the two exceptions the PII policy documents at `CLAUDE.md:297`.
On no ticket.

**11 of 13 skills with a `scripts/` directory still have no `justfile`**, which root `CLAUDE.md` Rule 17 requires.
Only `context-compaction` and `living-docs` have one - note that `bump-gate.sh:33` and `.github/scripts/testing/run-tests.sh:30` both still _claim_ `skill-registry` has one, and it does not.
On no ticket, named here for the fifteenth cycle.

Branch protection is still absent and is still on no ticket.

**`work-order.sh approve` and `link` both strand themselves, and it is on no ticket.**
Each writes the ticket file and `INDEX.md`; `start` refuses a dirty tree; `start` is what creates the branch.
A `start --on-current-branch` would remove it.

Root `CLAUDE.md`'s `## Consuming These Files` section still contradicts Rule 16 steps 7 and 8, **on no ticket** after fourteen cycles.

**The four onboarding runs in `docs/skills-onboarding-checklist.md` are the user's own, claimed on 2026-08-22.**
`grep -c '\[x\] done' docs/skills-onboarding-checklist.md` returns 0 and that is the expected state, not a gap.
It is recorded here so you do not rediscover it and treat it as work.
**Do not raise it in a reply, do not list it as an open item, do not fold it into a recommendation.**
It comes back up only if the user raises it.

### Stale or false in the docs

**Both design documents under `docs/superpowers/` still name `skill-versioning`, and that was a deliberate decision, not an oversight.**
`AC-H1` asked that `git grep skill-versioning` return nothing "outside history", and the line was drawn to put both documents inside it: they are dated, the spec is marked `Status: settled`, and every occurrence is the old name as the **subject of a recorded decision** rather than a path anyone follows.
Rewriting the spec would produce the sentence "Renaming `skill-registry` to `skill-registry`".
The full reasoning is in PR #91's body under `AC-H1`.
`notes/skills-pm-discovery.md`, `HYDRATION.md` and the whole `work-orders/` tree were treated the same way.
**Do not "finish" the rename in those files.** If you disagree, that is a conversation to have, not an edit to make.

**The design doc's example manifest is stale and decision 20 wins.**
`docs/superpowers/specs/2026-08-23-skills-package-manager-design.md:195` lists `project-scaffold` where decision 20 lists `context-compaction`.

**Both design documents still say the runner only has Docker.**
`ubuntu-24.04` ships Podman 5.8.4.

**`claude/skills/work-order/settings.local.json.tmpl:6` still names `work-order.sh close`.**
There is no `close` verb; the lifecycle ends at `done`, on the branch, inside the pull request.
On no ticket.

**The close-out diagram in `CLAUDE.md.tmpl` puts the pull request at step 4, after `done` at step 2.**
The real order is `gh pr create`, then `submit --pr N`, then `done`.
On no ticket.

**`project-scaffold/testing/run-tests.sh` pins `python:3.12-slim` by tag, not by digest**, a Rule 15 violation.
Left alone deliberately seven times now.
On no ticket.

**`scaffold.sh:214` depends on `cmp`**, which Rule 17 says to check for.
Present in Git Bash so not a live break.
On no ticket.

### Your scope

The ticket's Scope block defines it and this section does not restate it.
Five things are worth knowing before you read it.

**The markers already exist and you must match them byte for byte.**
`WO-20260824-b21b` shipped `skills:begin` and `skills:end` into `project-scaffold`'s `CLAUDE.md.tmpl` and named `skill-sync` as their writer.
Changing the marker text is an explicit non-goal.
Read the template first and copy the bytes; do not retype them.

**Three of the four criteria are byte-identity assertions**, which means the suite needs a real before-and-after comparison and not a grep.
Note that root `CLAUDE.md` Rule 17 warns `cmp` is absent from minimal test images, and `project-scaffold/scripts/scaffold.sh:214` already hits this - its `assert_same` hashes when `cmp` is missing. Reuse that shape rather than rediscovering it.

**`AC-H4` says "asserted on the data with comments stripped first"**, which is the criterion telling you its own failure mode: a version string sitting in a comment inside the block would pass a naive grep and fail the intent.

**The suite is `claude/tools/testing/run-tests.sh` and it is `self`-dispatching**, so `bump-gate.sh run-suite claude/tools` invokes it directly and it makes its own container.
`bump-gate.sh detect` reports `tools=true` when anything under `claude/tools/` changes, which is what puts it on the matrix.

**The ticket asks for cases that feed `project-scaffold`'s real `CLAUDE.md.tmpl` to the writer**, per the existing "the manifest project-scaffold ships" pattern, because the two files live in different skills and drift between them is silent.
Find that existing pattern before writing a new one.

### Before you start

Nothing is open.
The ticket has no assumptions, no open questions and no notes.

`work-order.sh start` needs a clean tree and creates the branch for you.
It leaves the ticket file and `INDEX.md` uncommitted, so commit them before anything else.

An untracked `.claude/worktrees/smoke-tests` sits in the working directory.
It is a registered git worktree on branch `worktree-smoke-tests`, left by an earlier session, and it predates this ticket and the three before it.
`git status` shows it as `?? .claude/worktrees/` and `gh pr create` warns `Warning: 1 uncommitted change` because of it.
It is harmless and it is not yours; leave it or ask the user before removing it.
Note that its vendored copy of `CLAUDE.md.tmpl` still names `skill-versioning` - that is a stale worktree, not a missed reference.

### Read in this order

1. The ticket, and its Scope block in full.
2. This entry, the top entry of `HYDRATION.md`. Read only this one.
3. The approved-order note on `WO-20260824-00d5` - `Skills package manager: roll it out across the repository`, dated 2026-08-30, and the note beside it explaining why this ticket was appended as a seventh step rather than folded into `WO-20260824-b21b`.
4. `claude/skills/project-scaffold/references/templates/CLAUDE.md.tmpl`, for the marker pair as shipped.
5. `claude/tools/skill-sync.sh`, end to end - it is the file you are changing and it currently writes nothing outside `.claude/skills/`.
6. `claude/tools/testing/run-tests.sh`, for the "the manifest project-scaffold ships" pattern the ticket points at.
7. PR #91's body, for what a criterion evidenced as NOT MET looks like when the pipeline cannot satisfy it.

### Reuse, it is proven

**`bump-gate.sh run-suite <skill-dir>` is how a suite is run**, and `--print` tells you whether it self re-execs into a container or has to be wrapped.
`claude/tools` is `self`.
`skill-registry` is `wrapped`.

**`bump-gate.sh detect --base origin/main` tells you the matrix before you push.**
It emits `skills=[...]`, `tools=`, `gate=`.
On PR #91 it emitted `skills=["project-scaffold","skill-registry"]`, `tools=false`, `gate=true`, and the `project-scaffold` entry is the whole reason the false-major trap was caught.
**Read the skills list and ask why each name is on it.** A skill you only touched a comment in is still a skill CI will version.

**`bump-gate.sh resolve --base origin/main --title-file F --body-file F` prints the `current -> next` table locally**, exactly as the gate will.
Run it before you push and read the `source` column: `trailer` means your `Bump:` line was found, `title` means it fell back to the title, and a fallback you did not intend is the failure mode.

**Simulating the squash merge and running `publish.sh apply` over it is the rung that pays for itself.**
Clone the repo in a container, `git checkout -B main origin/main`, `git merge --squash <branch>`, commit with the **real title and body concatenated the way GitHub joins them**, then `publish.sh apply --before <the old main sha>`.
It prints the exact allocation table, the exact commit message, and the exact `registry.json` the publisher will write.
Both PR #91 findings came out of this and neither was visible in the diff.

**The container pattern is `references/skill-testing.md` "Driving a repository-level gate against the real tree".**
Clone into `/work`, mount the repository read-only at `/repo`, `bitnami/git` pinned by digest, `--network=none`.
It has now worked unmodified on `d058`, `79b6` and `238b`.

**`git clone` carries commits, not a working tree.**
Commit before the container run or you measure `main`.

### The verification ladder

Cheapest rung first.
This is the ladder `238b` used, and rung 6 is where both of its findings came from.

1. **`bash skill-version.sh --help`** in a container - free, and it catches an unbalanced heredoc immediately.
2. **The changed skill's own suite** via `bump-gate.sh run-suite`. On `238b`: 165 assertions, all green.
3. **`bump-gate.sh detect --base origin/main`** - proves the matrix will run what you just ran, and tells you which _other_ skills you dragged in.
4. **Every other suite `detect` named.** On `238b` that meant `project-scaffold` and `.github/scripts/testing/run-tests.sh` as well, 145 assertions.
5. **`bump-gate.sh resolve`** with the real title and body files.
6. **The squash merge simulated, and `publish.sh apply` run over it, on a clone of the real tree.** This is the only rung that shows you what actually reaches `main`.

**An assertion of absence is worth nothing until it has returned non-zero on purpose.**
`238b`'s `AC-H1` grep was run twice: once returning nothing, once after pasting `# skill-versioning` into a live file, where it returned that file.
Your `AC-H2` and `AC-H3` are the same shape - "byte-identical" proves nothing until you have watched the comparison fail on a file you changed on purpose.

### Traps, already paid for

**A `!` in the title applies to every skill in the changed set that has no trailer.**
Symptom: an unrelated skill you edited one comment line in is published as a major.
Cause: `title_level` at `bump-lib.sh:123` returns `major` on the bang before it ever looks at the type.
Fix: a `Bump: <skill>=patch` trailer per incidental skill. `resolve`'s `source` column is where you see it.

**`work-order.sh evidence` checks the box unconditionally**, and `done` refuses any unchecked criterion.
Symptom: a criterion that was not met still renders as `- [x]`.
Cause: the tick means "observed and recorded", not "passed"; the observation text carries the verdict.
On `238b` the verdict is the first two words of `AC-H3`'s observation, and a `note` was added so it cannot be missed.

**A rename is two halves and git pairs them only when it can.**
Symptom: the gate treats the new directory as a brand new skill and says nothing about the old one.
`skill-registry/testing/run-tests.sh` section 5c exercises both halves and passes either way, which is why `238b` was safe.

**`grep -q` in a pipeline kills the writer with SIGPIPE and `pipefail` reports it as no-match.**
Symptom: a check passes precisely when it should fail.
`diff_check` at `skill-version.sh:425` captures into a variable first and there is a comment there saying why.

**`gh pr create` warns about untracked files and creates the PR anyway.**
Symptom: `Warning: 1 uncommitted change` in the middle of the output.
Cause: the stale `.claude/worktrees/` directory. It is not your branch being dirty.

### Workflow

```sh
WO=~/.claude/skills/work-order/scripts/work-order.sh
HP=~/.claude/skills/hydration-prompt/scripts/hydration.sh

bash $WO start    --id WO-20260830-eb89
git add work-orders && git commit -m "chore(work-orders): start WO-20260830-eb89"

# ... the work, and the ladder ...
bash .github/scripts/bump-gate.sh run-suite claude/tools
bash .github/scripts/bump-gate.sh detect --base origin/main

bash $WO evidence --id WO-20260830-eb89 --index 1 --observed "..."
bash $WO evidence --id WO-20260830-eb89 --index 2 --observed "..."
bash $WO evidence --id WO-20260830-eb89 --index 3 --observed "..."
bash $WO evidence --id WO-20260830-eb89 --index 4 --observed "..."

git push -u origin feat/skill-sync-fills-the-claude-md-skills-table-betw
gh pr create --base main --title "feat(tools): skill-sync fills the CLAUDE.md skills table" \
  --body-file /tmp/pr-body.md          # last paragraph: the Bump: trailers

bash $WO submit   --id WO-20260830-eb89 --pr <N>
bash $WO done     --id WO-20260830-eb89
bash $HP check    --project . --body-file /tmp/entry.md
bash $HP add      --project . --id <next> --title "..." --body-file /tmp/entry.md
git add -A && git commit && git push        # rides the same pull request

# after the merge, when the user says it is merged
bash $WO cleanup  --id WO-20260830-eb89
```

`submit` must precede `done`, and both happen on the branch before the merge.
Nothing is written to `main` afterwards except the publisher's own commit.

**This is the last ticket in the epic.** When it is done, `WO-20260824-00d5` - `Skills package manager: roll it out across the repository` has no open children left, and closing the epic is its own act with its own acceptance criteria - read them rather than assuming the epic closes itself.

### Conventions

Every reference to a work-order in a chat reply carries the ticket ID **and** its full title, joined by a dash, on the first mention and on every mention after it.
A bare ID is a defect, and so is "the next ticket" or "the blocked one".
Take the title from the ticket file, never from the truncated tree in `INDEX.md`.

Never use the em dash.
Use a plain dash instead.

Never add an agent co-author line to a commit message, and never add the Claude footer to a PR body.
Root `CLAUDE.md` Rule 13 makes the second one absolute.

Report failing tests as failing, with the output.
Say what was skipped.
Rule 12: "completed" is wrong if anything was skipped silently, and a criterion that was not met is reported as not met.

All testing runs in Podman, per Rule 14, with no size threshold.
A single `--help` invocation counts.

Feature branches only.
`main` is written directly by `.github/workflows/skill-publish.yml` and by nothing else.

<!-- hydration-entry: WO-20260824-238b -->
## WO-20260824-238b - Rename skill-versioning to skill-registry, the closing commit
_Generated 2026-08-31 by hydration.sh. Newest entry._

### Ticket

`WO-20260824-238b` - `Rename skill-versioning to skill-registry, the closing commit`.
It is a `chore`, `p2`, a child of `WO-20260824-00d5` - `Skills package manager: roll it out across the repository`.
Position 6 of 7 in the approved order, which is a note on the epic dated 2026-08-30.
Read that note rather than re-deriving the order; if you think it is wrong, say so and ask.

It is the last of its eight dependencies to clear, and every one of them is now `done`.
`work-order.sh next` offers it and `WO-20260824-00d5` - `Skills package manager: roll it out across the repository` and nothing else.

It is 3 points and the ticket's own note calls it mechanical.
Do not let that word set the pace.
It is mechanical in the sense that every edit is obvious and in no other sense: it renames the skill that owns the registry, so a reference missed anywhere breaks the pipeline that installs every skill into every project.

Predecessor `WO-20260824-79b6` - `Invert the notice assertion: verify --structure now fails on a notice that is present`, merged, closed and archived.

### What just landed

**PR #90, `WO-20260824-79b6`.**
`verify --structure` now refuses a read-only notice committed into any `SKILL.md`, which closes the window PR #89 opened when it stripped the notice from 42 files and left nothing to stop it being pasted back.

Three files changed and no others.

`claude/skills/skill-versioning/scripts/skill-version.sh` gained `NOTICE_OPENER` near `SCHEMA`, one `grep -qF` inside the skill walk in `cmd_verify` guarded on `$structure -eq 1`, and a `noticed` branch in the failure block that prints the message.

`claude/skills/skill-versioning/testing/run-tests.sh` lost the notice from both fixture skills and gained a `NOTICE` constant, a `verify --structure: the read-only notice` section, and one case in the new-skill section.
The suite went from 145 to 165 assertions.

`claude/skills/skill-versioning/SKILL.md` gained a `#### The read-only notice` subsection under `The two forms of verify`, and the `--structure` row of the two-forms table now names the check.

Four decisions are in the PR body and each is load-bearing.
The check keys on `> **This copy is read-only.**` and nothing else, because that opener is the only line shared by the inline notice that was deleted (which named `skill-update.sh`) and the rendered one at `claude/tools/partials/read-only-notice.md.tmpl` (which names `skill-sync.sh`).
It lives in `--structure` alone, because plain `verify` runs on `main` after the merge where a refusal fires somewhere nobody can act on it.
It walks the whole tree rather than the branch's diff, because the property being held is that no upstream `SKILL.md` carries the notice.
A new skill gets no exemption, because the exemption `--structure` grants an unregistered skill is about a number nobody has allocated, not about the file's contents.

`Bump: skill-versioning=minor` was stated as a trailer rather than left to the `feat:` title fallback, and `bump-gate.sh resolve` reported `2.0.5 -> 2.1.0 minor trailer`.

Before that: PR #89 shipped `d058`, PR #88 shipped `6a33`, PR #87 put the discovery on the epic, PR #86 shipped `c6b0` and `skill-onboard.sh`, PR #85 shipped `b21b`, PR #84 shipped `81a6`, PR #83 shipped `slot.sh`.
Epic 1 closed at PR #79.

### What is NOT done

**Nothing about the rename has been started.**
`git grep -l skill-versioning -- . ':!.git'` returns a long list and every entry on it is work for you, which is the ticket's own `AC-H1`.
No branch exists, no file has moved.

**Two `skill-onboard.sh` defects are on no ticket**, both recorded on the epic and on row 4 of `docs/skills-onboarding-checklist.md`.
`LEGACY_HEADING` at `skill-onboard.sh:71` is byte `2d`, U+002D HYPHEN-MINUS, and `claudes-markdown-12-rules` `CLAUDE.md:69` is `e2 80 94`, U+2014 EM DASH, so `section_of`'s whole-line match misses and the `else` at line 430 appends `## Skills` while leaving 68 stale lines above it, exiting 0.
The same repository has no `.claude/skills/` directory, so discovery dies at line 358 with exit 3.

**`CLAUDE.md.tmpl:98` carries `https://github.com/jkkelley/local-k8s-docs`**, a username and a repository name together, and it is not one of the two exceptions the PII policy documents at `CLAUDE.md:297`.
On no ticket.
Note that the file moves under this ticket if it lives inside the skill; check before you assume it does not.

**11 of 13 skills with a `scripts/` directory still have no `justfile`**, which root `CLAUDE.md` Rule 17 requires.
Only `context-compaction` and `living-docs` have one.
On no ticket, named here for the fourteenth cycle.

Branch protection is still absent and is still on no ticket.

**`work-order.sh approve` and `link` both strand themselves, and it is on no ticket.**
Each writes the ticket file and `INDEX.md`; `start` refuses a dirty tree; `start` is what creates the branch.
A `start --on-current-branch` would remove it.

Root `CLAUDE.md`'s `## Consuming These Files` section still contradicts Rule 16 steps 7 and 8, **on no ticket** after thirteen cycles.

`WO-20260830-eb89` - `skill-sync fills the CLAUDE.md skills table between the markers` is still not yours.
It is blocked by this ticket and `next` will offer it once this one is `done`.

**The four onboarding runs in `docs/skills-onboarding-checklist.md` are the user's own, claimed on 2026-08-22.**
`grep -c '\[x\] done' docs/skills-onboarding-checklist.md` returns 0 and that is the expected state, not a gap.
It is recorded here so you do not rediscover it and treat it as work.
**Do not raise it in a reply, do not list it as an open item, do not fold it into a recommendation.**
It comes back up only if the user raises it.

### Stale or false in the docs

**`docs/superpowers/specs/2026-08-23-skills-package-manager-design.md` names `skill-versioning` throughout, and the rename is exactly what makes that false.**
Decide deliberately whether a design document is history or a live reference before you rewrite it.
`AC-H1` says `git grep skill-versioning returns nothing outside history`, and "outside history" is the phrase that has to be interpreted rather than pattern-matched.
If you leave the design docs naming the old name, say so in the PR body and say why, so the criterion is evidenced as a judgement rather than quietly satisfied.

**The design doc's example manifest is stale and decision 20 wins.**
`docs/superpowers/specs/2026-08-23-skills-package-manager-design.md:195` lists `project-scaffold` where decision 20 lists `context-compaction`.

**Both design documents still say the runner only has Docker.**
`ubuntu-24.04` ships Podman 5.8.4.

**`claude/skills/work-order/settings.local.json.tmpl:6` still names `work-order.sh close`.**
There is no `close` verb; the lifecycle ends at `done`, on the branch, inside the pull request.
On no ticket.

**The close-out diagram in `CLAUDE.md.tmpl` puts the pull request at step 4, after `done` at step 2.**
The real order is `gh pr create`, then `submit --pr N`, then `done`.
On no ticket.

**`project-scaffold/testing/run-tests.sh` pins `python:3.12-slim` by tag, not by digest**, a Rule 15 violation.
Left alone deliberately six times now.
On no ticket.

**`scaffold.sh:214` depends on `cmp`**, which Rule 17 says to check for.
Present in Git Bash so not a live break.
On no ticket.

### Your scope

The ticket's Scope block defines it and this section does not restate it.
Five things are worth knowing before you read it.

**There is no compat symlink and the ticket says why in its Problem statement.**
`skill_dirs` at `skill-version.sh:82` uses `find -type d`, which does not match a symlink to a directory.
A symlink would therefore hide the breakage rather than surface it, which is the worst of both outcomes.

**The script is not renamed.**
`skill-version.sh` keeps its name; only the skill directory moves.
That is an explicit non-goal in the ticket and it is easy to over-reach on, because the script's name is the one that reads oddest after the rename.

**The references are in more places than a grep of `claude/skills/` reaches.**
`.github/workflows/skill-pr-gate.yml` and `.github/workflows/skill-publish.yml` both drive the script by path.
`.github/scripts/bump-gate.sh` resolves suites by skill directory.
Root `CLAUDE.md` Rule 16 names `claude/skills/skill-versioning/scripts/skill-version.sh` and `skill-update.sh` several times.
`claude/tools/skill-sync.sh` and `claude/tools/skill-onboard.sh` are worth checking rather than assuming.

**`registry.json` is rendered, not edited, and the rename changes what it renders to.**
The old name leaves the registry and the new one enters it, which is a `stale entry` plus a new skill as far as plain `verify` is concerned.
Under `--structure` the renamed directory reads as **new**, and `run-tests.sh` section 5c exists specifically to cover that: `--structure PASSES on a renamed skill directory` and names it `new beta-renamed`.
Read that section before you decide the gate is broken.

**`AC-H3` asks for a major bump and it is the publisher that records it, not you.**
Write `Bump: skill-registry=major` in the PR body.
The old name does not appear in a trailer at all - there is nothing to bump, it is gone.

### Before you start

Nothing is open.
The ticket has no assumptions and no open questions, and its three acceptance criteria are all `(human)`.

One thing to decide early rather than at the end, because it changes the size of the diff: whether `AC-H1`'s "outside history" covers the two design documents under `docs/superpowers/specs/`.
Decide it, state it in the PR body, and evidence the criterion against the decision you stated.

`work-order.sh start` needs a clean tree and creates the branch for you.
It leaves the ticket file and `INDEX.md` uncommitted, so commit them before anything else.

An untracked `.claude/worktrees/smoke-tests` sits in the working directory.
It is a registered git worktree on branch `worktree-smoke-tests`, left by an earlier session, and it predates this ticket and the one before it.
`git status` shows it as `?? .claude/worktrees/` and `gh pr create` warns about it.
It is harmless and it is not yours; leave it or ask the user before removing it.

### Read in this order

1. The ticket, and every note on it.
2. This entry, the top entry of `HYDRATION.md`. Read only this one.
3. The approved-order note on `WO-20260824-00d5` - `Skills package manager: roll it out across the repository`, dated 2026-08-30.
4. `claude/skills/skill-versioning/testing/run-tests.sh` section 5c, `verify --structure: a renamed skill`, which is the behaviour your own change depends on.
5. Root `CLAUDE.md` Rule 16, end to end, because it names the paths you are moving.
6. `.github/workflows/skill-publish.yml` and `.github/workflows/skill-pr-gate.yml`.
7. PR #90's description, for the shape of a PR body that states a bump level and its reasoning rather than letting the title fallback decide.

### Reuse, it is proven

**`bump-gate.sh run-suite <skill-dir>` is how a suite is run**, and `--print` tells you whether it self re-execs into a container or has to be wrapped.
`skill-versioning` is `wrapped`.
Note that the argument is a path, so it changes with the rename.

**`bump-gate.sh detect --base origin/main` tells you the matrix before you push.**
It emits `skills=[...]`, `tools=`, `gate=`, and it only lists changed skills that ship `testing/run-tests.sh`.
On PR #90 it correctly emitted `skills=["skill-versioning"]`.
Watch what it emits for a rename - that is the single most informative thing you can run early.

**`bump-gate.sh resolve --base origin/main --title-file F --body-file F` prints the `current -> next` table locally**, exactly as the gate will on the PR.
It reported `skill-versioning 2.0.5 -> 2.1.0 minor trailer` for PR #90.
Run it before you push and read the `source` column: `trailer` means your `Bump:` line was found, `title` means it fell back.

**The container pattern is `references/skill-testing.md` "Driving a repository-level gate against the real tree".**
Clone into `/work`, mount the repository read-only at `/repo`, `bitnami/git` pinned by digest, `--network=none`.
It has now worked unmodified on `d058` and on `79b6`.

**`git clone` carries commits, not a working tree.**
Commit before the container run or you measure `main`.

### The verification ladder

Cheapest rung first.
This is the ladder `79b6` used and every rung of it caught something or proved something the rung below could not.

1. **`bash skill-version.sh --help`** - free, and it catches an unbalanced heredoc in a failure message immediately. The new message on `79b6` is a `cat <<EOF` block inside an `if`, which is exactly the shape that breaks this.
2. **`bump-gate.sh run-suite claude/skills/skill-versioning`** - the fixture suite, in a container, 165 assertions. This is where every refusal is enumerated cheaply. On `79b6` it caught nothing, because the fixtures had been fixed first - which is itself the finding: the fixtures carried a notice and would have failed the new gate, so a suite left alone would have been passing on the gate being broken.
3. **`bump-gate.sh detect --base origin/main`** - proves the CI matrix will actually run the suite you just ran. A skill changed with no `testing/run-tests.sh` is silently absent from the matrix.
4. **The gate against a clone of the real tree, in a container.** The fixture is 3 skills; the tree is 43, with real history. On `79b6` this is what turned `AC-H1` from a fixture assertion into evidence: green on the real tree, red with a notice pasted into a real `SKILL.md`, green again on revert. For your ticket the equivalent is `verify` and `verify --structure` both run on a clone with the rename applied.
5. **`bump-gate.sh resolve`** with the real title and body files, which is the last thing that can be wrong after the code is right.

**An assertion of absence is worth nothing until it has returned non-zero on purpose.**
That is why rung 4 pastes the thing in and asserts red before restoring.
Your ticket's `AC-H1` is the same shape - `git grep` returning nothing proves the grep ran only if you have watched it return something.

### Traps, already paid for

**A gate that scans `SKILL.md` files for a string cannot have that string in its own documentation.**
Symptom: the skill's own `SKILL.md` turns the gate red the moment you document the check.
Cause: the check greps every `SKILL.md` including the one you are writing.
`skill-versioning/SKILL.md` now describes the notice opener instead of quoting it, and says so in the text.

**`git checkout -- .` inside a test restores only committed state.**
Symptom: a test case passes in isolation and fails after the case before it.
Cause: the fixture repo has uncommitted changes from an earlier case.
Sections 5 and 5a of `run-tests.sh` restore with `git checkout` in some places and a `.bak` copy in others, deliberately, and the choice depends on whether the file was committed.

**`grep -q` in a pipeline kills the writer with SIGPIPE and `pipefail` reports it as no-match.**
Symptom: a check passes precisely when it should fail.
Cause: `grep -q` closes the pipe on its first match.
`diff_check` at `skill-version.sh:425` captures into a variable first and there is a comment there saying why.

**`gh pr create` warns about untracked files and creates the PR anyway.**
Symptom: `Warning: 1 uncommitted change` in the middle of the output.
Cause: the stale `.claude/worktrees/` directory. It is not your branch being dirty.

**A rename is two halves and git pairs them only when it can.**
Symptom: the gate treats the new directory as a brand new skill and says nothing about the old one.
Cause: how much else the commit changed decides whether git detects the rename at all.
`run-tests.sh` section 5c exercises both halves for this exact ticket, and the comment there names `WO-20260824-238b` by ID.

### Workflow

```sh
WO=~/.claude/skills/work-order/scripts/work-order.sh
HP=~/.claude/skills/hydration-prompt/scripts/hydration.sh

bash $WO start    --id WO-20260824-238b
git add work-orders && git commit -m "chore(work-orders): start WO-20260824-238b"

# ... the work, and the ladder ...
bash .github/scripts/bump-gate.sh run-suite claude/skills/skill-registry
bash .github/scripts/bump-gate.sh detect --base origin/main

bash $WO evidence --id WO-20260824-238b --index 1 --observed "..."
bash $WO evidence --id WO-20260824-238b --index 2 --observed "..."
bash $WO evidence --id WO-20260824-238b --index 3 --observed "..."

git push -u origin feat/rename-skill-versioning-to-skill-registry-the-cl
gh pr create --base main --title "chore(skills)!: rename skill-versioning to skill-registry" \
  --body-file /tmp/pr-body.md          # last paragraph: Bump: skill-registry=major

bash $WO submit   --id WO-20260824-238b --pr <N>
bash $WO done     --id WO-20260824-238b
bash $HP check    --project . --body-file /tmp/entry.md
bash $HP add      --project . --id <next> --title "..." --body-file /tmp/entry.md
git add -A && git commit && git push        # rides the same pull request

# after the merge, when the user says it is merged
bash $WO cleanup  --id WO-20260824-238b
```

`submit` must precede `done`, and both happen on the branch before the merge.
Nothing is written to `main` afterwards except the publisher's own commit.

### Conventions

Every reference to a work-order in a chat reply carries the ticket ID **and** its full title, joined by a dash, on the first mention and on every mention after it.
A bare ID is a defect, and so is "the next ticket" or "the blocked one".
Take the title from the ticket file, never from the truncated tree in `INDEX.md`.

Never use the em dash.
Use a plain dash instead.

Never add an agent co-author line to a commit message, and never add the Claude footer to a PR body.
Root `CLAUDE.md` Rule 13 makes the second one absolute.

Report failing tests as failing, with the output.
Say what was skipped.
Rule 12: "completed" is wrong if anything was skipped silently.

All testing runs in Podman, per Rule 14, with no size threshold.
A single `--help` invocation counts.

Feature branches only.
`main` is written directly by `.github/workflows/skill-publish.yml` and by nothing else.

<!-- hydration-entry: WO-20260824-79b6 -->
## WO-20260824-79b6 - Invert the notice assertion: verify --structure now fails on a notice that is present
_Generated 2026-08-31 by hydration.sh. Newest entry._

### Ticket

`WO-20260824-79b6` - `Invert the notice assertion: verify --structure now fails on a notice that is present`.
It is a `feature`, `p2`, a child of `WO-20260824-00d5` - `Skills package manager: roll it out across the repository`.
Position 5 of 7 in the approved order, reviewed on 2026-08-29 and recorded as a note on the epic itself. Do not re-derive it; if you think it is wrong, say so and ask.

Predecessor `WO-20260824-d058` - `Remove the inline read-only notice from the other 42 SKILL.md files`, merged, closed and archived. It and this ticket are both step 5, and this one could not run before it.

It is 2 points: one assertion and a message. It is the smallest ticket left in the epic, and the only one whose entire value is a refusal that fires on a file nobody has written yet.

### What just landed

**PR #89, `WO-20260824-d058`.** 42 `SKILL.md` files, 294 deletions, 0 insertions, no other file touched.
Every skill in the repository is now free of the inline read-only notice, `hydration-prompt` included, which had been the only clean one since `WO-20260824-f1a5`.

The edit was a one-shot bash script, run twice and deliberately not committed. Its full text is in the PR #89 description and the reasoning is a note on the archived ticket. The short version: this deletion happens once in the repository's history, so a committed script would be dead code forever, and the durable guard against the notice returning is your ticket, not a script.

No `Bump:` trailer was written. The title `fix(skills): ...` was the whole mechanism and `bump-gate.sh resolve` returned 42 rows, every one `patch` with source `title`.

Before that: PR #88 shipped `6a33`, PR #87 put the discovery on the epic, PR #86 shipped `c6b0` and `skill-onboard.sh`, PR #85 shipped `b21b`, PR #84 shipped `81a6`, PR #83 shipped `slot.sh`. Epic 1 closed at PR #79.

### What is NOT done

**There is no notice assertion anywhere in `skill-version.sh` right now, and that is the gap you close.** Nothing in the repository stops the notice being pasted back into a `SKILL.md`, and the obvious reaction to seeing it missing is to put it back.

`WO-20260824-6a33` - `Checklist for the four repositories carrying the stale session-start block` shipped the checklist only. The four runs were an explicit non-goal of that ticket and all four rows are open by design; `grep -c '\[x\] done' docs/skills-onboarding-checklist.md` returns 0.

**Two `skill-onboard.sh` defects are on no ticket**, both recorded on the epic and on row 4 of the checklist. `LEGACY_HEADING` at `skill-onboard.sh:71` is byte `2d`, U+002D HYPHEN-MINUS, and `claudes-markdown-12-rules` `CLAUDE.md:69` is `e2 80 94`, U+2014 EM DASH, so `section_of`'s whole-line match misses and the `else` at line 430 appends `## Skills` while leaving 68 stale lines above it, exiting 0. The same repository has no `.claude/skills/` directory, so discovery dies at line 358 with exit 3.

**`CLAUDE.md.tmpl:98` carries `https://github.com/jkkelley/local-k8s-docs`**, a username and a repository name together, and it is not one of the two exceptions the PII policy documents at `CLAUDE.md:297`. On no ticket.

**11 of 13 skills with a `scripts/` directory still have no `justfile`**, which root `CLAUDE.md` Rule 17 requires. Only `context-compaction` and `living-docs` have one. On no ticket, named here for the thirteenth cycle.

Branch protection is still absent and is still on no ticket.

**`work-order.sh approve` and `link` both strand themselves, and it is on no ticket.** Each writes the ticket file and `INDEX.md`; `start` refuses a dirty tree; `start` is what creates the branch. A `start --on-current-branch` would remove it.

Root `CLAUDE.md`'s `## Consuming These Files` section still contradicts Rule 16 steps 7 and 8, **on no ticket** after twelve cycles.

`WO-20260830-eb89` - `skill-sync fills the CLAUDE.md skills table between the markers` is still not yours and `next` will not offer it. It runs after `WO-20260824-238b` - `Rename skill-versioning to skill-registry, the closing commit`.

### Stale or false in the docs

**The comment at `claude/skills/skill-versioning/testing/run-tests.sh:149-153` is now false, and it is the most important line in this entry.**
It reads "The read-only notice is no longer verify's business. It is asserted present nowhere and absent nowhere, which is the only state that holds while the repository is mid-rollout and some SKILL.md files carry it and some do not."
The mid-rollout window it describes closed with PR #89. Every `SKILL.md` is clean, so "absent nowhere" is exactly the state your ticket ends. Rewrite that comment as part of the change; leaving it is a comment that argues against the code beside it.

**The assertion at `run-tests.sh:157` is about plain `verify`, not `--structure`.** It checks that `bash "$SV" verify` says nothing about a missing notice, on a fixture skill with the notice stripped. If your new assertion lives in `--structure` alone, that check stays true and stays correct, and you are adding rather than inverting. Read it before you assume you have to change it. The word "invert" in your own title is about the repository's posture, not necessarily about that one line.

**The notice text you are asserting against is not the text that was removed.** The removed inline notice named `skill-update.sh`; the rendered replacement at `claude/tools/partials/read-only-notice.md.tmpl:23-24` names `skill-sync.sh`, and that partial's own header comment says the difference is deliberate. The only string common to both is the opener, `> **This copy is read-only.**`. Key on that. An assertion written against a line mentioning `skill-update.sh` will miss a pasted-back copy of the rendered form.

**Your ticket's Test plan names only `claude/skills/skill-versioning/testing/run-tests.sh`.** That suite is `wrapped` dispatch, so run it through `bump-gate.sh run-suite claude/skills/skill-versioning` rather than as `bash <suite>`, or it runs on the host.

**`claude/skills/work-order/settings.local.json.tmpl:6` still names `work-order.sh close`.** There is no `close` verb; the lifecycle ends at `done`, on the branch, inside the pull request. On no ticket.

**The close-out diagram in `CLAUDE.md.tmpl` puts the pull request at step 4, after `done` at step 2.** The real order is `gh pr create`, then `submit --pr N`, then `done`. On no ticket.

**The design doc's example manifest is stale and decision 20 wins.** `docs/superpowers/specs/2026-08-23-skills-package-manager-design.md:195` lists `project-scaffold` where decision 20 lists `context-compaction`.

**Both design documents still say the runner only has Docker.** `ubuntu-24.04` ships Podman 5.8.4.

**`project-scaffold/testing/run-tests.sh` pins `python:3.12-slim` by tag, not by digest**, a Rule 15 violation. Left alone deliberately five times now. On no ticket.

**`scaffold.sh:214` depends on `cmp`**, which Rule 17 says to check for. Present in Git Bash so not a live break. On no ticket.

### Your scope

The ticket's Scope block defines it and this section does not restate it. Four things are worth knowing before you read it.

**The assertion belongs in `--structure`, which is the PR gate.** `skill-version.sh:448` is where `--structure` is parsed and `505` is where its structure-only block runs. Plain `verify` is the publisher's gate and answers a different question - whether the registry matches the tree - and a notice check there would fire on `main` at publish time rather than on the branch where someone can still fix it.

**The failure message is half the ticket, and `AC-H2` is only about the message.** The failure has to say that the notice is rendered at install and must not be committed, because the reader's instinct on seeing no notice is to paste one in. An error naming what is wrong but not what to do instead is how the notice comes back a third time.

**`AC-H1` is a negative that has to be made to fail before it is believed.** Paste the notice into a `SKILL.md` in a container clone, assert the gate goes red, restore, assert it goes green. A gate asserting an absence is worth nothing until it has returned non-zero once on purpose. That pattern was used on `d058` for the same reason and it is the cheapest thing in the ladder.

**You do need a `Bump:` trailer this time, unlike `d058`.** One skill changes, `skill-versioning`, and a new refusal that can fail an existing consumer's pull request is a behaviour change rather than a wording fix. Decide `minor` or `major` against the Rule 16 table and say why in the PR body. The title fallback would give you `feat` -> `minor` from a `feat:` title, which is probably right, but state it rather than let it happen.

### Before you start

Nothing is open. The scope is two lines of `In` and both are unambiguous.

The approved order is a note on `WO-20260824-00d5` - `Skills package manager: roll it out across the repository` dated 2026-08-30; read it rather than re-deriving it. After this ticket, step 6 is `WO-20260824-238b` - `Rename skill-versioning to skill-registry, the closing commit`, which still carries open dependencies including `WO-20260824-6a33` - `Checklist for the four repositories carrying the stale session-start block`.

`work-order.sh start` needs a clean tree and creates the branch for you. It leaves the ticket file and `INDEX.md` uncommitted, so commit them before anything else.

### Read in this order

1. The ticket, and every note on it.
2. This entry, the top entry of `HYDRATION.md`. Read only this one.
3. `claude/skills/skill-versioning/testing/run-tests.sh` lines 140 to 165, which is the fixture and the now-false comment.
4. `claude/skills/skill-versioning/scripts/skill-version.sh` lines 448 to 510, where `--structure` is parsed and where its checks run.
5. `claude/tools/partials/read-only-notice.md.tmpl`, so you assert against the rendered text and not the deleted text.
6. PR #89's description, for the shape of a verification ladder on an assertion of absence.

### Reuse, it is proven

**`bump-gate.sh run-suite <skill-dir>` is how a suite is run**, and `--print` tells you whether it self re-execs into a container or has to be wrapped. `skill-versioning` is `wrapped`.

**`bump-gate.sh detect --base origin/main` tells you the matrix before you push.** It emits `skills=[...]`, `tools=`, `gate=`, and it only lists changed skills that ship `testing/run-tests.sh`.

**The container pattern is `references/skill-testing.md` "Driving a repository-level gate against the real tree".** Clone into `/work`, mount the repository read-only at `/repo`, `bitnami/git` pinned by digest, `--network=none`. It worked unmodified on `d058` and it is the right shape for a gate that diffs against a base ref.

**`git clone` carries commits, not a working tree.** Commit before the container run or you measure `main`.

### The verification ladder

Rung 1: paste the notice into one `SKILL.md` in the clone, run the gate, assert non-zero and assert the message. Restore, assert zero. That is `AC-H1` and `AC-H2` together and it is the whole ticket.

Rung 2: `bump-gate.sh run-suite claude/skills/skill-versioning`. It was 148 checks before your change.

Rung 3: `skill-version.sh verify --structure --base origin/main` green on the real tree, which after PR #89 is 43 clean skills, so a new notice assertion must pass on it untouched. If it does not, your matcher is too broad.

Rung 4: the gate on the pull request.

### Traps, already paid for

**An assertion of absence that has never returned non-zero is not an assertion.** Make it fail on purpose, once, in the container.

**The notice text has two forms and they differ.** `skill-update.sh` in the deleted inline copy, `skill-sync.sh` in the rendered one. Match the opener.

**A block described by line numbers moves.** On `d058` the notice sat at `9-14` in 38 skills, `10-15` in two, `13-18` in one and `15-20` in one, and the offset was entirely the length of the frontmatter above it - `requires:` adds one line, a folded multi-line `description:` adds several. Anything you write that walks a `SKILL.md` must match on text.

**A markdown formatter rewrites `*emphasis*` into `_emphasis_` on lines you never touched.** It is a `PostToolUse` hook in the machine's global `~/.claude/settings.json`. On this ticket it fired on the PR body file the moment it was written. It did not corrupt anything, but that was checked rather than assumed: the fenced script in the body was extracted and `diff`ed against the file that actually ran. **If you write a `Bump:` trailer, re-read the body file afterwards and confirm the trailer is still the last line.**

**The gate matrix is not 42 suites, it is however many changed skills ship one.** A previous entry said to budget for 42 on `d058`; it ran 6 and took minutes. `detect` is the answer, not an estimate.

**A glyph you cannot see is a glyph you will get wrong.** Write codepoints, not characters.

**`treehouse return` exits 0 having freed nothing.** A dirty worktree makes it prompt, take the no-TTY default, abandon the return and leave the slot leased. Assert the post-state; never read `$?`.

**`treehouse get` hands out a second slot for a holder that already has one.** `slot.sh acquire` guards it; raw `treehouse` does not.

**A freed slot inspected from inside its own directory reports `you're here`, not `available`.** Key the check on `lease_holder`.

**`rc=$?` on the line after a `podman run` never executes under `set -e`.** `|| rc=$?` on the run itself.

**A digest you did not copy from a real registry does not exist.** `podman pull <tag>` then `podman image inspect --format '{{index .RepoDigests 0}}'`. `podman image exists <ref>` checks one is already local before you pull.

**A suite with no self re-exec, run as `bash <suite>`, runs on the host.** Use `bump-gate.sh run-suite`.

**`grep -qxF "$ROW"` where `$ROW` starts with a dash is parsed as an option.** `grep -qxF -- "$ROW"`.

**A `grep -q` in a pipeline reports "no match" when it matched.** SIGPIPE plus `pipefail`. Capture to a variable and use a herestring.

**`.claude/worktrees/smoke-tests` is a locked git worktree sitting untracked inside this repository.** It is not yours. `git add -A` at close-out is unsafe here - add explicit paths, which is what PR #76 through #89 all did. `gh pr create` warns `1 uncommitted change` because of it. Expected.

### Workflow

```bash
WO=claude/skills/work-order/scripts/work-order.sh
HP=claude/skills/hydration-prompt/scripts/hydration.sh
SL=claude/skills/hydration-prompt/scripts/slot.sh

bash $WO show    --project . --id WO-20260824-79b6
bash $WO start   --project . --id WO-20260824-79b6   # run it alone, never in an && chain
git add work-orders && git commit -m "chore(work-orders): start WO-20260824-79b6"

# ... the assertion, the message, and the fixture that proves both ...

bash $WO evidence --project . --id WO-20260824-79b6 --index N --observed '...'
bash $WO note     --project . --id WO-20260824-79b6 --text 'retro ...'
git add <explicit paths>            # NOT -A, see .claude/worktrees/smoke-tests above
git commit && git push -u origin <branch>
gh pr create --base main --title "feat(skills): ..." --body-file <file>
bash $WO submit  --project . --id WO-20260824-79b6 --pr <N>
bash $WO done    --project . --id WO-20260824-79b6   # on the branch, before the merge
bash $HP check   --project . --body-file /tmp/entry.md
bash $HP add     --project . --id WO-20260824-238b \
  --title "Rename skill-versioning to skill-registry, the closing commit" \
  --body-file /tmp/entry.md
git add <explicit paths> && git commit && git push   # rides the SAME pull request

# after the merge
bash $WO cleanup --project . --id WO-20260824-79b6
bash $SL release --holder <holder>                   # if you took a slot
```

### Conventions

Every reference to a work-order carries its ID **and** its full title, joined by a dash, on first mention and every mention after it. A bare ID is a defect, and so is "the next ticket" or "the blocked one".

No em dashes anywhere. Plain `-`.

No agent co-author line on a commit, and no "Generated with Claude Code" footer on a pull request body. Root `CLAUDE.md` Rule 13 makes the second absolute.

Report failures as failures. "Tests pass" is wrong if any were skipped, and "completed" is wrong if anything was silently left out. Rule 12.

All testing runs in Podman, with no size threshold. Rule 14.

Long markdown gets one sentence per physical line.

<!-- hydration-entry: WO-20260824-d058 -->
## WO-20260824-d058 - Remove the inline read-only notice from the other 42 SKILL.md files
_Generated 2026-08-31 by hydration.sh. Newest entry._

### Ticket

`WO-20260824-d058` - `Remove the inline read-only notice from the other 42 SKILL.md files`.
It is a `chore`, `p2`, a child of `WO-20260824-00d5` - `Skills package manager: roll it out across the repository`.
Position 5 of 7 in the approved order, which was reviewed on 2026-08-29 and is recorded as a note on the epic itself. Do not re-derive it; if you think it is wrong, say so and ask.

Predecessor `WO-20260824-6a33` - `Checklist for the four repositories carrying the stale session-start block`, merged, closed and archived.

It is the largest mechanical change in the epic and the riskiest, because it touches every skill in the repository at once. That is not the same as being the hardest, and it is not licence to be quick about it.

Its sibling `WO-20260824-79b6` - `Invert the notice assertion: verify --structure now fails on a notice that is present` runs immediately after and cannot run before. Both are step 5.

### What just landed

**PR #88, `WO-20260824-6a33`.** `docs/skills-onboarding-checklist.md`, one new file, no code.
Four rows naming `gatehouse-click`, `aws-lightsail-k8s-router`, `template-resume-builder` and `claudes-markdown-12-rules`, each pinned to the `origin/main` SHA its `CLAUDE.md` line numbers were read at on 2026-08-31, with the shared edit written once and the rows pointing at it.
Row 4 is marked **blocked, do not run**.

Every row's numbers were verified rather than asserted: `git show <sha>:CLAUDE.md` at the recorded start line returns the session-start heading and at end+1 returns the next H2, for all four.

**PR #87** put the discovery on the epic as a note before the ticket was started, so the findings survive `6a33`'s archival.

Before that: PR #86 shipped `c6b0` and `skill-onboard.sh`, PR #85 shipped `b21b`, PR #84 shipped `81a6`, PR #83 shipped `slot.sh`. Epic 1 closed at PR #79.

### What is NOT done

**Nothing has been run against any of the four repositories, and nothing in them has changed.** All four rows are open. That is the designed end state of `6a33`, not a shortfall: the runs are deliberate acts inside four other repositories and were an explicit non-goal. `grep -c '\[x\] done' docs/skills-onboarding-checklist.md` returns 0, which is what proves it.

**Two `skill-onboard.sh` defects are on no ticket**, both recorded on the epic and on row 4 of the checklist.
`LEGACY_HEADING` at `skill-onboard.sh:71` is byte `2d`, U+002D HYPHEN-MINUS, and `claudes-markdown-12-rules` `CLAUDE.md:69` is `e2 80 94`, U+2014 EM DASH, so `section_of`'s whole-line match misses and the `else` at line 430 appends `## Skills` while leaving 68 stale lines above it, exiting 0.
The same repository has no `.claude/skills/` directory, so discovery dies at line 358 with exit 3.

**`CLAUDE.md.tmpl:98` carries `https://github.com/jkkelley/local-k8s-docs`**, a username and a repository name together, and it is not one of the two exceptions the PII policy documents at `CLAUDE.md:297`. A third undocumented case in a policy this repository enforces on every commit. Found on 2026-08-31, on no ticket.

**11 of 13 skills with a `scripts/` directory still have no `justfile`**, which root `CLAUDE.md` Rule 17 requires. Only `context-compaction` and `living-docs` have one. Repo-wide, on no ticket, named here for the twelfth cycle.

Branch protection is still absent and is still on no ticket.

**`work-order.sh approve` and `link` both strand themselves, and it is on no ticket.** Each writes the ticket file and `INDEX.md`; `start` refuses a dirty tree; `start` is what creates the branch. A `start --on-current-branch` would remove it.

Root `CLAUDE.md`'s `## Consuming These Files` section still contradicts Rule 16 steps 7 and 8, **on no ticket** after eleven cycles of being named here.

`WO-20260830-eb89` - `skill-sync fills the CLAUDE.md skills table between the markers` is still not yours and `next` will not offer it. It runs after `WO-20260824-238b` - `Rename skill-versioning to skill-registry, the closing commit`.

### Stale or false in the docs

**Your own ticket's Scope is wrong, and this is the most important line in this entry.**
`WO-20260824-d058` says _"removing lines 9 to 14 from all 42 remaining skills"_. Measured on 2026-08-31 at `5d6aeaa`, that is true for 38 of them and false for four:

```
9-14    38 skills
10-15   cartography, living-docs
13-18   eso-secret-workflow
15-20   dba
```

A `sed -i '9,14d'` across the directory corrupts those four and the damage is plausible-looking prose loss, not a syntax error. Match on the notice text, never on line numbers.

**The block is not identical across files either.** Line 12 embeds each skill's own name in its upstream URL, so all 42 hash differently. Anything that assumes one canonical six-line string to delete is wrong for the same reason.

**`claude/skills/work-order/settings.local.json.tmpl:6` still names `work-order.sh close`.** There is no `close` verb; the lifecycle ends at `done`, on the branch, inside the pull request. On no ticket.

**The close-out diagram in `CLAUDE.md.tmpl` puts the pull request at step 4, after `done` at step 2.** The real order is `gh pr create`, then `submit --pr N`, then `done`. On no ticket.

**The design doc's example manifest is stale and decision 20 wins.** `docs/superpowers/specs/2026-08-23-skills-package-manager-design.md:195` lists `project-scaffold` where decision 20 lists `context-compaction`.

**Both design documents still say the runner only has Docker.** `ubuntu-24.04` ships Podman 5.8.4.

**`project-scaffold/testing/run-tests.sh` pins `python:3.12-slim` by tag, not by digest**, a Rule 15 violation. Left alone deliberately four times now. On no ticket.

**`scaffold.sh:214` depends on `cmp`**, which Rule 17 says to check for. Present in Git Bash so not a live break. On no ticket.

### Your scope

The ticket's Scope block defines it and this section does not restate it. Four things are worth knowing before you read it.

**The line range is per file, not a constant.** See the section above. This is the whole technical content of the ticket and getting it wrong is silent.

**Frontmatter must come out byte-identical**, `AC-H1`, in the order `name`, `description`, `version`. The deletion is below the frontmatter and must stay below it. Assert this on all 42 afterwards rather than trusting the edit; a script that miscounts on four files is a script that might have miscounted on more.

**You need no `Bump:` trailer at all, and the ticket forbids writing 42 of them.** The mechanism already exists and is proved: `bump-gate.sh` resolves a level per changed skill, and when a skill has no trailer it falls back to the conventional title for **each** one independently. The ticket's own planned title, `fix(skills): remove the inline read-only notice, now rendered at install`, makes that `patch` for all 42. Zero trailers, one title. `AC-H2` is then a single publish run going up one patch level across 42 skills.

**Do not touch `79b6`'s assertion in this pull request.** Inverting it before every file is clean fails the gate on the repository's own contents, which is exactly why they are two tickets.

### Before you start

One thing is genuinely open, and it is a judgement call rather than a question with a lookup answer.

**Decide how you are going to make the edit before you make it, and write the decision into the pull request.** 42 files, four of them at different offsets, and a block whose text varies per file. A hand-run `sed` per file, a script committed to the repository, and a script run once and discarded are all defensible, and they are not the same artefact - one of them the repository has to maintain forever. Root `CLAUDE.md` Rule 2 and the documentation-lifetime rule both bear on it. Pick one and say why.

Everything else is settled. The approved order is a note on `WO-20260824-00d5` - `Skills package manager: roll it out across the repository` dated 2026-08-30; read it rather than re-deriving it.

`work-order.sh start` needs a clean tree and creates the branch for you. It leaves the ticket file and `INDEX.md` uncommitted, so commit them before anything else.

### Read in this order

1. The ticket, and every note on it.
2. This entry, the top entry of `HYDRATION.md`. Read only this one.
3. The two notes on `WO-20260824-00d5` - `Skills package manager: roll it out across the repository` dated 2026-08-30, which are the approved order and its seventh step.
4. `docs/superpowers/plans/2026-08-24-skills-package-manager-implementation.md` section E2.6, which is the design of what you are doing.
5. `claude/tools/partials/read-only-notice.md.tmpl` - the rendered replacement, so you can see what the installed copy gets instead.
6. `claude/skills/dba/SKILL.md` lines 1 to 21, which is the worst-case offset and the file most likely to be corrupted by a line-number edit.
7. `.github/scripts/bump-gate.sh` around line 160, the per-skill title fallback that means you write no trailers.

### Reuse, it is proven

**`claude/tools/skill-sync.sh`'s `render_notice` already strips an existing inline notice before inserting the rendered one**, and its comment says it was written for this transition window. So a project onboarded before this ticket lands does not get a doubled notice. That is why `d058` was moved off the front of the order: the doubling it guards against cannot actually happen.

**`bump-gate.sh resolve` prints the whole `current -> next` table on the pull request** before anything is allocated. For 42 skills that table is the review artefact - read it rather than spot-checking files.

**`hydration-prompt` is the one skill already clean**, so `claude/skills/hydration-prompt/SKILL.md` is the shape all 42 must end up matching. Diff against it rather than imagining the target state.

**`grep -L` is how you assert the negative.** `grep -l 'This copy is read-only' claude/skills/*/SKILL.md` returning empty is `AC-H3`, and it is one command.

### The verification ladder

Rung 1: `grep -c 'This copy is read-only' claude/skills/*/SKILL.md` before and after, and the frontmatter assertion across all 42. Costs nothing and catches the four-file offset bug, which is the only bug this ticket can really have.

Rung 2: `bash .github/scripts/bump-gate.sh run-suite claude/skills/<name>` for the skills whose suites you can run locally. Note that this ticket changes 42 skills, so **the gate's matrix will run 42 suites**. Budget for that and do not be surprised by the run time.

Rung 3: `skill-version.sh verify --structure --base origin/main`. Green. Per Rule 14 this belongs in a container or in the gate, not on the host.

Rung 4: the gate on the pull request, and then the publish run, which is where `AC-H2` is actually observed.

### Traps, already paid for

**A block described by line numbers moves.** Four of 42 skills carry the notice somewhere other than lines 9-14, and a line-based delete on those removes real prose with no error. Match on text.

**Six lines that look identical are not.** Line 12 embeds the skill name, so every one of the 42 blocks differs. A single hardcoded string will not match.

**A markdown formatter rewrites `*emphasis*` into `_emphasis_` on lines you never touched.** It is a `PostToolUse` hook in the machine's global `~/.claude/settings.json`. It fired twice on this ticket, on a file it had just been handed. `git diff -U0 | grep '^-'` before committing and account for every deleted line. **Check the `Bump:` trailer, if you write one, is still the last line of the body file afterwards.**

**A glyph you cannot see is a glyph you will get wrong.** Writing prose about an em dash produced a hyphen and a sentence that contradicted itself, on this ticket, in the note documenting exactly that defect. Write codepoints, not characters.

**Line numbers read from a working tree are not the ones a tool will see.** One of the four repositories sits on a feature branch where the same block is seven lines lower than on `origin/main`. Both numbers are real and only one is useful.

**`treehouse return` exits 0 having freed nothing.** A dirty worktree makes it prompt, take the no-TTY default, abandon the return and leave the slot leased. Assert the post-state; never read `$?`.

**`treehouse get` hands out a second slot for a holder that already has one.** `slot.sh acquire` guards it; raw `treehouse` does not.

**A freed slot inspected from inside its own directory reports `you're here`, not `available`.** Key the check on `lease_holder`.

**`rc=$?` on the line after a `podman run` never executes under `set -e`.** `|| rc=$?` on the run itself.

**A digest you did not copy from a real registry does not exist.** `podman pull <tag>` then `podman image inspect --format '{{index .RepoDigests 0}}'`.

**A container check against "the branch" silently runs `main`'s code if you have not committed.** `git clone` carries commits, not a working tree.

**A suite with no self re-exec, run as `bash <suite>`, runs on the host.** Use `bump-gate.sh run-suite`.

**`grep -qxF "$ROW"` where `$ROW` starts with a dash is parsed as an option.** `grep -qxF -- "$ROW"`.

**A `grep -q` in a pipeline reports "no match" when it matched.** SIGPIPE plus `pipefail`. Capture to a variable and use a herestring.

**`.claude/worktrees/smoke-tests` is a locked git worktree sitting untracked inside this repository.** It is not yours. `git add -A` at close-out is unsafe here - add explicit paths, which is what PR #76 through #88 all did. `gh pr create` warns `1 uncommitted change` because of it. Expected.

### Workflow

```bash
WO=claude/skills/work-order/scripts/work-order.sh
HP=claude/skills/hydration-prompt/scripts/hydration.sh
SL=claude/skills/hydration-prompt/scripts/slot.sh

bash $WO show    --project . --id WO-20260824-d058
bash $WO start   --project . --id WO-20260824-d058   # run it alone, never in an && chain
git add work-orders && git commit -m "chore(work-orders): start WO-20260824-d058"

# ... the 42 files, matched on text and never on line numbers ...

bash $WO evidence --project . --id WO-20260824-d058 --index N --observed '...'
bash $WO note     --project . --id WO-20260824-d058 --text 'retro ...'
git add <explicit paths>            # NOT -A, see .claude/worktrees/smoke-tests above
git commit && git push -u origin <branch>
gh pr create --base main \
  --title "fix(skills): remove the inline read-only notice, now rendered at install" \
  --body-file <file>
bash $WO submit  --project . --id WO-20260824-d058 --pr <N>
bash $WO done    --project . --id WO-20260824-d058   # on the branch, before the merge
bash $HP check   --project . --body-file /tmp/entry.md
bash $HP add     --project . --id WO-20260824-79b6 \
  --title "Invert the notice assertion: verify --structure now fails on a notice that is present" \
  --body-file /tmp/entry.md
git add <explicit paths> && git commit && git push   # rides the SAME pull request

# after the merge
bash $WO cleanup --project . --id WO-20260824-d058
bash $SL release --holder <holder>                   # if you took a slot
```

### Conventions

Every reference to a work-order carries its ID **and** its full title, joined by a dash, on first mention and every mention after it. A bare ID is a defect, and so is "the next ticket" or "the blocked one".

No em dashes anywhere. Plain `-`.

No agent co-author line on a commit, and no "Generated with Claude Code" footer on a pull request body. Root `CLAUDE.md` Rule 13 makes the second absolute.

Report failures as failures. "Tests pass" is wrong if any were skipped, and "completed" is wrong if anything was silently left out. Rule 12.

All testing runs in Podman, with no size threshold. Rule 14.

Long markdown gets one sentence per physical line.

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

