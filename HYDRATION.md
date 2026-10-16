# HYDRATION.md

The prompt that starts the next session, and the 10 before it.

**Read the top entry only.** It is the current one and it is complete on its own.
Everything below it has been superseded and is kept for history, not for reading.

**Newest on top.** Adding an entry removes the oldest in the same commit, so this
file holds exactly 10 once it has filled up. Entries are never renumbered and
never edited in place - a correction is a new entry.

Written by `hydration.sh add`. Do not hand-edit.
<!-- hydration-entry: WO-20261016-529a -->
## WO-20261016-529a - nodes-check green: reply-ledger.sh drops the B21c marker
_Generated 2026-10-16 by hydration.sh. Newest entry._

### Ticket

`WO-20261016-529a` - `Inbox sweep nodes-check red on main: reply-ledger.sh names build ticket B21c as its node`, under the epic `WO-20261016-1703` - `Inbox sweep build`.

### What just landed

`bin/reply-ledger.sh` no longer carries `# node: B21c` (PR #241); `make nodes-check` and the migrate suite are green again.
B21c is a build ticket id, not a design node, and the spec names no node for ledger.jsonl.

### What is NOT done

V1, V2 and V3 under `WO-20261016-1703` are in flight, each with its `--type test` ticket.
B24 and B25 wait for the ypli contracts; B11 and B18 still wait for the architect.

### Stale or false in the docs

None known.

### Your scope

The inbox sweep build tickets under `WO-20261016-1703`, in DAG order.

### Before you start

None.

### Read in this order

1. `docs/design/inbox-sweep.md` section 18.
2. `docs/design/linkedin-reply.spec.xml`, record-owners.

### Reuse, it is proven

`make -C claude/workflow/inbox-sweep nodes-check` and `make suite SUITE=<name>`.

### The verification ladder

`make test` on changed suites, CI runs the full suite, then the live run, which is the only step that touches real mailboxes.

### Traps, already paid for

A `# node:` marker must name a node declared under `nodes/`, never a build ticket id; a script that owns a record with no node carries no marker.

### Workflow

`workflows/close-out-procedure.md`.

### Conventions

Dotfiles `CLAUDE.md`; UTC everywhere; no em dash.

<!-- hydration-entry: WO-20261016-4c73 -->
## WO-20261016-4c73 - CI runs every inbox-sweep suite
_Generated 2026-10-16 by hydration.sh. Newest entry._

### Ticket

`WO-20261016-4c73` - `CI never runs the inbox-sweep suites`, under the epic `WO-20261016-1703` - `Inbox sweep build`.

### What just landed

`make -C claude/workflow test`, which the CI `claude/workflow` job runs, now runs every inbox-sweep suite through a phony `inbox-sweep` target (PR #197).
Before it, inbox-sweep suites ran only on a seat's machine, and PR #168 merged with its lint suite red.

### What is NOT done

B21e, B21f2 and V1 to V3 follow by DAG under `WO-20261016-1703`, each with its `--type test` ticket.
B11 and B18 still wait for the architect.

### Stale or false in the docs

None known.

### Your scope

The inbox sweep build tickets under `WO-20261016-1703`, in DAG order.

### Before you start

None.

### Read in this order

1. `docs/design/inbox-sweep.md` section 18.
2. `work-orders/INDEX.md`, epic `WO-20261016-1703`.
### Reuse, it is proven

`make -C claude/workflow/inbox-sweep test` and `test-all`, with stub `herdr` and stub `claude.exe` in `tests/lib/`.

### The verification ladder

`make test` on changed suites, `make test-all` before a PR, then the live run, which is the only step that touches real mailboxes.

### Traps, already paid for

Parallel PRs collide on `tests/suites.tsv` and the generated `work-orders/INDEX.md`: union the suite rows, rebuild the index with `work-order.sh reindex`.

### Workflow

`workflows/close-out-procedure.md`.

### Conventions

Dotfiles `CLAUDE.md`; UTC everywhere; no em dash.

<!-- hydration-entry: WO-20261016-4409 -->
## WO-20261016-4409 - Inbox sweep lint green after B17d
_Generated 2026-10-16 by hydration.sh. Newest entry._

### Ticket

`WO-20261016-4409` - `Inbox sweep lint red on main after B17d`, under the epic `WO-20261016-1703` - `Inbox sweep build`.

### What just landed

Suite `lint` of `claude/workflow/inbox-sweep` is green again (PR #192); it went red on main with B17d (PR #168).
`bin/reply-send.sh` behaviour is unchanged: a dead flag removed and three `A && B || C` lines made into `if` statements.

### What is NOT done

B21c (PR #178) still has to rebase onto this, then B21e, B21f2 and V1 to V3 follow by DAG, each with its `--type test` ticket.
B11 and B18 still wait for the architect.

### Stale or false in the docs

None known.

### Your scope

The inbox sweep build tickets under `WO-20261016-1703`, in DAG order.

### Before you start

None.

### Read in this order

1. `docs/design/inbox-sweep.md` section 18.
2. `work-orders/INDEX.md`, epic `WO-20261016-1703`.
### Reuse, it is proven

`make -C claude/workflow/inbox-sweep test` and `test-all`, with stub `herdr` and stub `claude.exe` in `tests/lib/`.

### The verification ladder

`make test` on changed suites, `make test-all` before a PR, then the live run, which is the only step that touches real mailboxes.

### Traps, already paid for

Parallel PRs collide on `tests/suites.tsv` and the generated `work-orders/INDEX.md`: union the suite rows, rebuild the index with `work-order.sh reindex`.

### Workflow

`workflows/close-out-procedure.md`.

### Conventions

Dotfiles `CLAUDE.md`; UTC everywhere; no em dash.

<!-- hydration-entry: WO-20261016-e2e8 -->
## WO-20261016-e2e8 - Inbox sweep and reply DAG built; live runs B11 and B18 wait for the architect
_Generated 2026-10-16 by hydration.sh. Newest entry._

### Ticket

`WO-20261016-e2e8` - `Inbox sweep B11 - live end-to-end run`, under the epic `WO-20261016-1703` - `Inbox sweep build`.
It is in draft on purpose: B11 touches real mailboxes and waits for the architect to release it.
Do not approve or start it without that release.

### What just landed

The inbox sweep design (PR #105) and the LinkedIn reply DAG (PR #119) are approved (Bearings D-04 and D-18, 2026-10-16 UTC).
Built and merged: B0 to B8, B10, B13 (PRs #107 to #117), and the reply, node and migration nodes B14, B15, B16, B17a, B17b, B17c, B19, B20a, B20b, B21, B22, B23 (PRs #121 to #133).
B9, the controller, Makefile and README, is PR #118, which carries this entry.

### What is NOT done

B11, the live end-to-end run, has not been run.
B12, the spike on waking the Chrome extension, is in draft and not on the build path.
B18, the live first LinkedIn send, waits for the owner's card and the architect.
B21b, the integer schema_version retrofit, is flagged: run.json has 8 writers, so it needs a one-writer-per-record ruling first.
Scheduling the daily run (design D5) is cut only after three clean live runs.

### Stale or false in the docs

None known.

### Your scope

Only what the architect releases: B11, or a fix the live run needs.

### Before you start

Known gap reported by the B9 seat: `claude/workflow/config/project.json` has no `workflow.seats` entry for the sweep's seat names, so `workflow-spawn.sh <wf> <seat>` dies with "no seat named" on a live run.
Seat names are per Proton account from the owner's config, which cannot be written into this public repo, so the fix is an architect ruling, not a guess.

### Read in this order

1. `docs/design/inbox-sweep.md` sections 10 and 12.
2. `claude/workflow/inbox-sweep/README.md`.
3. Ticket `WO-20261016-e2e8`.

### Reuse, it is proven

`make -C claude/workflow/inbox-sweep test` and `test-all`, with stub `herdr` and stub `claude.exe` in `tests/lib/`.

### The verification ladder

`make test` on changed suites, `make test-all` before a PR, then the live run, which is the only step that touches real mailboxes.

### Traps, already paid for

Parallel PRs collide on `tests/suites.tsv` and the generated `work-orders/INDEX.md`: union the suite rows, rebuild the index with `work-order.sh reindex`.

### Workflow

`workflows/close-out-procedure.md`.

### Conventions

Dotfiles `CLAUDE.md`; UTC everywhere; no em dash.

<!-- hydration-entry: none -->
## Skills package manager epic closed; nothing is startable
_Generated 2026-09-13 by hydration.sh. Newest entry._

### Ticket

No work order.
The epic `WO-20260824-00d5` - `Skills package manager: roll it out across the repository` is done, archived, and closed by PR #97.
`work-order.sh next` prints `nothing is startable: no ticket is 'ready' with all dependencies done`, so there is no ticket for this session to take.
What this session does is the user's to say; do not pick one of the items below and start on it.

### What just landed

**PR #97 closed the epic on evidence, with no code.**
All three criteria were evidenced MET on the tree at `61fe99ea`.

`AC-H1`, no SKILL.md carries the inline read-only notice: `git grep -nF '> **This copy is read-only.**' -- '*SKILL.md'` rc 1 over 43 files, in Podman with `--network=none`.
Proved able to fail: the notice pasted back made the grep hit and `verify --structure` exit 1.

`AC-H2`, `git grep skill-versioning` returns nothing outside history (`docs/superpowers`, `notes`, `HYDRATION.md`, `work-orders`): rc 1, and the old name reintroduced made it hit.

`AC-H3`, a freshly scaffolded project syncs the four default skills on its first session: run with the network on, against published `main`.
`setup.sh` was driven through its own prompts to install `skill-sync` and the SessionStart hook, `scaffold.sh --apply` made the project, and the hook was run exactly as `settings.json` records it.
15 PASS, 0 FAIL, including PR #92's fill between the markers, byte-identity on a second sync, and a reworded marker writing nothing.

**PR #96, a user change, shipped separately.**
`claude/skills/container-sandbox/SKILL.md` gained "Verifying a page at a phone viewport", written by the user's local-k8s-docs architect into this checkout mid-ticket.
It was moved byte for byte to `docs/container-sandbox-phone-viewport` with `Bump: container-sandbox=minor`, resolving `1.4.3 -> 1.5.0`, and recorded as a note on the epic.

### What is NOT done

Every item here is on no ticket.

**`publish.sh`, two defects from `238b`.**
A `FRESH` skill never reaches `record()`, so a `Bump: <renamed>=major` trailer is read, validated and discarded.
`report()` and `commit_message()` print `1.0.0` for any `FRESH` skill, so a rename of an already-versioned skill misreports.

**`skill-onboard.sh`, two defects.**
`LEGACY_HEADING` at `skill-onboard.sh:71` is U+002D where one real repository's heading is U+2014, so `section_of` misses and the run appends `## Skills` beside 68 stale lines, exit 0.
A repository with no `.claude/skills/` dies at line 358 with exit 3.

**`setup.sh`, cosmetic, found on `AC-H3`.**
`_yellow` and `_bold` print a literal `\n`, because the helpers format their argument with `%s`.

**`CLAUDE.md.tmpl:98` carries a username and repository URL** that is not one of the two exceptions at root `CLAUDE.md`.

**11 of 13 skills with a `scripts/` directory have no `justfile`**, which Rule 17 requires; `bump-gate.sh:33` and `.github/scripts/testing/run-tests.sh:30` claim `skill-registry` has one.

**`work-order.sh approve` and `link` strand themselves**: both write files, `start` refuses a dirty tree, and `start` is what makes the branch.

**Root `CLAUDE.md` `## Consuming These Files` contradicts Rule 16 steps 7 and 8.**

**Branch protection is absent.**

### Stale or false in the docs

**`docs/superpowers/specs/2026-08-23-skills-package-manager-design.md:747`** draws a `Skill | Agent` table; `skill-sync` writes a one-per-line list of names.

**The same spec at line 195** lists `project-scaffold` where decision 20 lists `context-compaction`; decision 20 wins.

**Both design documents say the runner only has Docker**; `ubuntu-24.04` ships Podman.

**Both design documents still name `skill-versioning`, deliberately.** They are history by `238b`'s decision. Do not finish the rename in them.

**`claude/skills/work-order/settings.local.json.tmpl:6` names `work-order.sh close`**, which does not exist.

**The close-out diagram in `CLAUDE.md.tmpl` puts the pull request after `done`.** The real order is `gh pr create`, `submit --pr N`, `done`.

**`project-scaffold/testing/run-tests.sh` pins `python:3.12-slim` by tag**, a Rule 15 violation.

**`scaffold.sh:214` depends on `cmp`**, which Rule 17 says to check for.

### Your scope

Whatever the user asks for.
If it is one of the items above, it needs a ticket first: `work-order.sh new`, a Lavish review, `approve`, then `start`.
Nothing above may be fixed inside an unrelated pull request.

### Before you start

**Confirm PR #96 and PR #97 are both merged**: `git log origin/main --oneline -6` should show both.
If either is open, ask the user before doing anything else.

**Ask the user what this session is for.** There is no startable ticket, and choosing one from `What is NOT done` is a guess.

An untracked `.claude/worktrees/smoke-tests` is a registered worktree on `worktree-smoke-tests` from an earlier session; it is not yours, so leave it or ask.

### Read in this order

1. Root `CLAUDE.md`.
2. This entry, the top of `HYDRATION.md`, and only this one.
3. `work-orders/INDEX.md`, to confirm nothing is startable.
4. `workflows/close-out-procedure.md`, if the session becomes a ticket.
5. `claude/skills/container-sandbox/references/skill-testing.md`, before any verification.

### Reuse, it is proven

**Break the implementation on purpose and watch the check go red.** It is the only proof that an assertion of absence can fail, and it caught a false green on `00d5`.

**The repository-level container**: clone into `/work`, mount the repository read-only at `/repo`, `bitnami/git@sha256:1baa6ddb`, `--network=none`. Worked unmodified on five tickets.

**`bump-gate.sh` lives at `.github/scripts/bump-gate.sh`**, not under `claude/skills/skill-registry/scripts/`. `detect`, `resolve --title-file --body-file`, and `run-suite <dir> --print`.

**A network-on first session**: `debian@sha256:328d1649` plus `bash jq git curl ca-certificates tar`, `setup.sh` fed `2\n3\n\n\ny\n`, `scaffold.sh --apply --yes --git-init`, then the hook read back out of `settings.json` and `eval`ed in the project.

### The verification ladder

0. `bash -n` on every file touched, in a container.
1. `bash <script> --help`, in a container.
2. The changed suite via `bump-gate.sh run-suite`.
3. Mutate the implementation one defect at a time and re-run; restore from a copy and re-run once more.
4. `bump-gate.sh detect --base origin/main`.
5. `bump-gate.sh resolve` with the real title and body, plus `skill-version.sh verify --structure --base origin/main`.
6. The squash merge simulated and `publish.sh apply` run over it, on a clone.

### Traps, already paid for

**Every later case passes against a session that never ran.** A setup step failed quietly and `eval ""` exited 0; assert the setup as a gate that aborts, not as one check among many.

**`setup.sh` mode 2 exits 1 on an empty config file.** Use mode 3 with both prompts empty for "skill-sync and its hook only".

**Another agent's edit appears in this working tree.** Stage only your own paths, never `git add -A`, and move the change to its own branch rather than folding it in.

**`pipefail` turns `grep -c` with zero matches into a failure.** Capture into a variable with `|| true`, then compare.

**A file the container cannot read makes `cat` print nothing and the pipeline carry on.** Keep title and body files inside the `/work` mount and run under `bash -euc`.

**An mtime comparison inside one second proves nothing.** `touch -d '1 hour ago'` first.

**`work-order.sh evidence` ticks the box unconditionally.** Put MET or NOT MET in the first words.

**`gh pr create` warns `1 uncommitted change`.** That is `.claude/worktrees/`, not your branch.

### Workflow

```sh
WO=~/.claude/skills/work-order/scripts/work-order.sh
HP=~/.claude/skills/hydration-prompt/scripts/hydration.sh

git log origin/main --oneline -6
bash $WO next
bash $WO new --parent <epic> --type bug --title "..." --problem "..." --out "..." --ac "..."
bash $WO approve  --id <id>
bash $WO start    --id <id>
bash $WO evidence --id <id> --index N --observed "MET. ..."
gh pr create --base main --title "..." --body-file <file>
bash $WO submit   --id <id> --pr <N>
bash $WO done     --id <id>
bash $HP check    --project . --body-file <file>
bash $HP add      --project . --id <next> --title "..." --body-file <file>
git add <your paths> && git commit && git push
bash $WO cleanup  --id <id>
```

### Conventions

Every ticket in a chat reply carries its ID and full title.
One question per reply.
No em dashes, no agent co-author lines, no Claude footer in PR bodies.
Failing checks are reported as failing, and a skipped step is named.
The onboarding runs in `docs/skills-onboarding-checklist.md` are the user's own; do not raise them.

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

