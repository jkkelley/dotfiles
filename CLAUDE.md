# Dotfiles — Agent Orientation

<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->

- [Hard rule: Design principles 101, right below the contents list](#hard-rule-design-principles-101-right-below-the-contents-list)
- [Hard rule: every Markdown file opens with a contents list](#hard-rule-every-markdown-file-opens-with-a-contents-list)
- [Hard rule: herdr tab layout for every multi-agent line](#hard-rule-herdr-tab-layout-for-every-multi-agent-line)
- [Hard rule: the golden system design rules sit right under every contents list](#hard-rule-the-golden-system-design-rules-sit-right-under-every-contents-list)
- [Rule 1 — Think Before Coding](#rule-1--think-before-coding)
- [Rule 2 — Simplicity First](#rule-2--simplicity-first)
- [Rule 3 — Surgical Changes](#rule-3--surgical-changes)
- [Rule 4 — Goal-Driven Execution](#rule-4--goal-driven-execution)
- [Rule 5 — Use the model only for judgment calls](#rule-5--use-the-model-only-for-judgment-calls)
- [Rule 6 — Token budgets are not advisory](#rule-6--token-budgets-are-not-advisory)
- [Rule 7 — Surface conflicts, don't average them](#rule-7--surface-conflicts-dont-average-them)
- [Rule 8 — Read before you write](#rule-8--read-before-you-write)
- [Rule 9 — Tests verify intent, not just behavior](#rule-9--tests-verify-intent-not-just-behavior)
- [Rule 10 — Checkpoint after every significant step](#rule-10--checkpoint-after-every-significant-step)
- [Rule 11 — Match the codebase's conventions, even if you disagree](#rule-11--match-the-codebases-conventions-even-if-you-disagree)
- [Rule 12 — Fail loud](#rule-12--fail-loud)
- [Rule 13 — Never add the Claude footer to PR bodies](#rule-13--never-add-the-claude-footer-to-pr-bodies)
- [Rule 14 — All testing runs in Podman](#rule-14--all-testing-runs-in-podman)
- [Rule 15 — Pin every version. No floating tags.](#rule-15--pin-every-version-no-floating-tags)
- [Rule 16 - A skill edit carries the intent to bump. CI allocates the number](#rule-16---a-skill-edit-carries-the-intent-to-bump-ci-allocates-the-number)
  - [The path, end to end](#the-path-end-to-end)
  - [`skill-update.sh` is the hand-authored path, and nothing else](#skill-updatesh-is-the-hand-authored-path-and-nothing-else)
- [Starting a session - read `HYDRATION.md` first](#starting-a-session---read-hydrationmd-first)
- [Feature branches only - never commit to `main`](#feature-branches-only---never-commit-to-main)
- [Close-out and post-merge cleanup](#close-out-and-post-merge-cleanup)
- [PII & PHI Policy — Strictly Enforced](#pii--phi-policy--strictly-enforced)
- [How to Handle Environment-Specific Values](#how-to-handle-environment-specific-values)
  - [The documented exception: this repo's own public URLs](#the-documented-exception-this-repos-own-public-urls)
- [Consuming These Files](#consuming-these-files)
- [Before You Commit](#before-you-commit)
- [Rule 17 - Skills are OS aware, and `justfile` is the entry point](#rule-17---skills-are-os-aware-and-justfile-is-the-entry-point)
- [Rule 18 - Herdr-first execution: never background processes](#rule-18---herdr-first-execution-never-background-processes)
- [Rule 19 - Google Drive first, and the surface follows the model](#rule-19---google-drive-first-and-the-surface-follows-the-model)
- [Adding a New Agent or Skill — Ship the MVP Immediately](#adding-a-new-agent-or-skill--ship-the-mvp-immediately)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

<!-- GOLDEN-RULES:START -->
## Hard rule: Design principles 101, right below the contents list

Owner order, 2026-10-16 UTC: "deisgn principal 101 global agents.md rule right below the contents list for it".
Backup of this file before the rule: `~/.local/state/zenith/backup/2026/10/20261016035435-home-agents-md-before-design-principles-101.md`.

Every design document carries a section named "Design principles 101" placed directly below its contents list, before any other section.
It lists the principles below, and for each one says in a line how this design meets it, or why it does not apply.
A design without that section is not ready for the owner to read.

The principles, each in the owner's own words:

1. CI/CD speed is king: "CICD SPEED IS KING"; "speed is king"; "speed is the name of the game, no bottlenecks".
2. Parallelism: "parallelism, speed, work needs to be done"; "do shit in parallel, we need this active".
3. Make and scripts drive the automation, never hands: "makefiles with scripts driving automation, NEVER by hand!".
4. Portable, generic, templated, reused: "everything portable, generic, templated out so everybody gets it, NEVER REINVENT THE WHEEL". Inventory what already exists and reuse it before building anything new.
5. Small scope, proven: "prove shit discover it small scope that an ape could build this shit".
6. Tests where they count, and CI owns the full suite: "i hate slow CICD, we're built for speed, test only things relevant, don't run full suites, make changes and test those relevant changes, CICD does linting and full suite" (2026-10-16 UTC, replacing the earlier "only full suite before prs"). Agents run only the tests their change touches, never a full suite locally; CI runs lint and the full suite.
7. Evidence or silence: "reproduce errors or problems only with supporting evidence otherwise mute". A problem is reported only with its reproduction and evidence attached; without evidence, an agent says nothing about it.
8. Specs: "xml specs 1000 lines or less good never examples unlimited files being specific with content list at the top".
9. DAG and doc design first: "dag this shit out doc design first".
10. Migrations and easy node updates: "ensure migrations plans and easy updates to the nodes".
11. Clean up after itself: "make sure you clean up too".
12. Frictionless for the owner: "ensure its frictionless". The owner only decides, on Bearings, one card at a time.
13. Context discipline: "no more than 30% on the ctx and smart checkpointing built in with monitoring that not disruptive but token efficient".
14. Multi-agent work, shown with GOOD and NEVER examples: "MULTIAGENT WORK MINDSET GOOD NEVER EXAMPLES". Every design is built for many agents working at once, and every rule it sets carries a GOOD and a NEVER example.
15. XML spec, mermaid architecture and DAG, the DAG is the source: "always design with xml spec 1000 lines or less unlimited files doc design first driven by mermaid for architecture and DAG with graceful migration plans and easy of use ... the DAG is the source, build to spec".
16. Migration is the test of the design: "if workflows can't be easily migrated and updated, the design princpal is wrong and flow sucks". A design whose workflows cannot be migrated and updated easily is rejected and redesigned.
17. Config files and arguments pass every input: "config and arguments are good ways to pass things, easy in makefiles too". Every script takes its inputs from a config file or arguments, never hard-coded, and every Make target passes them as `VAR=value`.
18. Agent to agent is schema, never prose: "agent to agent prose sucks, schemas with defined AC always". Every brief, handoff and result between agents is a JSON document valid against a JSON schema, and every one carries defined acceptance criteria, each with the proof that ticks it. Prose is for the owner only.
19. Small tickets, disjoint files, logical order: "scope tickets and work orders small, keep things built for speed, never touching same files and logical ordering". Every ticket and work order is small, declares the files it touches, and no two tickets that can run at the same time touch the same file; the DAG orders the rest so dependent work waits on its input.
20. Worktree, feature branch, deterministic DAG path, the DAG is the state: "worktrees and feature branches with the whole process DAG when getting work so it follows a deterministic path with clear checklist runbooks playbooks documents everything that node needs is there and graceful recovery, always, doc design first with those mermaid and build to spec and keep the idea of terraform in mind, the state file is the source of truth, so should the DAG doc design architecture". Taking work always opens its own worktree and feature branch and walks the process DAG in a fixed order. Each node ships with its checklist, runbook, playbook and every document it needs, and recovers gracefully from wherever it stopped. Like a Terraform state file, the DAG design is the source of truth: the build is planned against it, applied to match it, and any drift from it is detected and reported.
21. Merge, never park: "get this code merged the fuck in, dead code is shit, it sitting under agents is stupid". A PR whose CI is green and whose design was approved merges at once, by a script; PRs never pile up in deep stacks waiting on each other, and a stack is collapsed leaves first by the merge script.
22. See it, isolate it, fix it, or hand it off and get out of the way: "see a bug, isolate it, and get it fixed as asap, if you don't know how to fix shit, get the fuck out of my way in the proper engineering way". An agent that sees a bug isolates it to a reproduction and fixes it at once in a small PR. An agent that cannot fix it files a ticket with the reproduction and evidence, hands it to a seat that can, and steps aside; it never blocks the line or guesses.
23. Artifacts live outside git, named by script, linked in like packages: "any files we ever need to create, they never go in the git repo, artifacts get smartly linked to the outside like packages do on linux, use format <key name>/YYYY/MM/YYYYMMDD-HHMMSS-<descriptive name under 55 chars completely with the prefix included>.<whatever ext> scripted too with frontmatter that makes sense, logs context whatever kind of file that we don't want tracked in git, we don't have time for that shit, point to where its at and if we need context we know where to go looking". Every log, context file, brief, result, screenshot or other untracked file is written by a script to `<key>/YYYY/MM/YYYYMMDD-HHMMSS-<name>.<ext>` under the shared artifact store, where the file name with its timestamp prefix stays under 55 characters. Each one opens with frontmatter that says what it is, who wrote it, from which repo, branch and session, and when, in UTC. Repositories never hold them; they hold a pointer, and the store is reached the way a package is, through a link, so an agent that needs the context knows exactly where to look.
24. Smart checkpointing with compaction is the standard: "checkpointing or smart checkingpointing with compaction is smart as fuck". Every seat runs with compaction-guard checkpoints, and every new seat gets it by default.
25. No AWS spend beyond SSM and a justified S3 bucket; the cluster and GitOps are the platform: "don't spend money on AWS unless its for a ssm parameter or a good reason for an S3 bucket, k8s cluster and jenkins argo cd source of truth, don't be stupid". Workloads run on the owner's Kubernetes cluster, built by Jenkins and deployed by Argo CD, and git through Argo CD is the source of truth for what runs. AWS is used only for SSM parameters and, when a design states the reason, an S3 bucket. The `minecraft-admin` profile rule above still holds.
26. Producer and consumer, never push into a pane: "your gonna get bogged down, thats fucked right there, wtf" and "thats not good, prodcuer consumer model man, wtf". Monitors and seats produce events into a durable queue; consumers pull from it when they are ready. Mechanical events, such as a seat finishing, are consumed by a script with no model; only an event that needs a ruling lands in the queue of the agent who rules, and that agent reads it on its own schedule. No event is ever typed into an agent's pane. The queue is a bus, not files: "man drop that shit on a bus we have nats or some open source liteweight tool, come on". NATS JetStream (local images nats:2.15.1-alpine and natsio/nats-box) carries every event, with durable pull consumers, brought up and down by Make.
27. One pattern for everything that watches: "we need to be conscious of each seat cost the system resouces, so we need a scripted way to monitor ram and cpu too" and "that lives and dies in a monitoring tab too along with those scripts from makefiles, you see a trend forming yet?". Every monitor (line sweep, consumers, bus, herdr bridge, CPU and RAM per seat) is declared once in a monitors config, is a script behind a Make target, runs in a labeled pane of the line's monitoring tab, publishes to the bus, and starts and stops with that tab. Adding a monitor is one config entry, never a new mechanism.
28. XML specs, contents list, mermaid, graceful recovery, idempotency, automation forever: "xml specs 1000 lines or less with content list and mermaid code for doc design first with graceful recovery and idempotentency, automation forever NEVER HAND FED" (2026-10-16 UTC). Every XML spec is 1000 lines or less, parses, and opens with a contents element; the design behind it is drawn in mermaid first. Every step, script and Make target is idempotent: run it again from any state and it lands in the same end state, with no duplicate and no damage, and it recovers gracefully from wherever it stopped. A fast `make spec-check` enforces the spec limits in CI. Nothing is ever hand fed: a step a person or agent has to feed by hand is a defect to turn into automation.
29. Status codes, minimal prose, work orders all the way: "fucking status codes i hate agent prose, keep to minimum, things don't need to be said, you and i have decided, thats why we spec shit out, work-orders skill all the fucking way" (2026-10-16 UTC). Agents report by status code from the status code map, never by prose; what the spec already decided is never restated. Every piece of work is cut and tracked with the work-order skill, never as an ad hoc brief.
30. Ape-sized work, scripted tests, everything up front: "i want work scoped so small a fuck ape could do, testing the same way with test plans and scripts, every node has what it fucking needs up front, not later, design it that way, we don't want dicks in hands, we want work done" (2026-10-16 UTC). Every work order is cut so small that it needs no judgement beyond its declared degrees of freedom. Testing is cut the same way: a `--type test` work order carrying a filled test plan (claude/workflow/templates/test-plan.md) and the script that runs it. Every DAG node carries, at the moment it is cut, everything it needs: inputs, files it touches, exact commands, test plan, acceptance criteria with proofs, and pointers to every doc. A node that has to ask, wait for context or go looking is a design defect, fixed in the design, never worked around by the seat.

GOOD: a design that opens with its contents list, then Design principles 101 with one line per principle, then a mermaid DAG that the XML spec and the build follow exactly.
NEVER: a build that drifts from its DAG, or a workflow that has to be rebuilt by hand to change it.

## Hard rule: every Markdown file opens with a contents list

Owner order, 2026-10-16 UTC: "EVERY .md file starts with content lists at the top, so my global files that aren't checked in need to change and the ones in the dotfiles as well".
This covers the global files outside any repository (this file, `~/OPINIONS.md`) and every Markdown file in dotfiles.
The list is generated and refreshed by a Make target and a script, never by hand, and a fast check fails a PR whose Markdown lacks it.
Files marked auto-generated, CHANGELOG.md files, and vendored skill copies are fixed at their source, never in place.

## Hard rule: herdr tab layout for every multi-agent line

Owner order, 2026-10-16 UTC: "since we use herdr, its should always be known to use herdr in a tab layout with 3X3 and the 1(YOU ONLY ON AGENT IN THIS FULL 3 slots)|3 panes|3 panes, everything labeled, make new tabs when not, driven by makefiles and scripts with automated cleanup too".
Backup of this file before the rule: `~/.local/state/zenith/backup/2026/10/20261016035943-home-agents-md-before-herdr-layout.md`.

Every line runs in herdr tabs on a 3 by 3 grid.
The first tab is the architect's: the left column is the architect alone, at full height across its 3 slots; the middle and right columns hold 3 seat panes each.
When a tab is full, the next seat opens a new tab of the same grid instead of squeezing a pane in; overflow tabs hold seats only, since the architect lives once.
Every tab and every pane is labeled with its line and seat name.
Opening, placing, labeling, closing and cleaning up panes and tabs is done by Make targets and scripts, never by hand: a finished seat's pane closes, and an empty tab closes with it.

GOOD: tab `inbox-triage 1` with the architect on the left, then `sweep-build`, `yp-line`, `ctx-guard` in the middle and `md-toc`, `li-page`, `li-send2` on the right; the eighth seat opens tab `inbox-triage 2`.
NEVER: unlabeled panes split wherever there was room, or a dead seat's pane left open.

## Hard rule: the golden system design rules sit right under every contents list

Owner order, 2026-10-16 UTC: "these we're my new golden system design rules, they sit right under those content list, blast that shit, I don't care if its not dry, i want it wildly known".
The golden system design rules are three sections of this file: "Design principles 101, right below the contents list", "every Markdown file opens with a contents list", and "herdr tab layout for every multi-agent line".
Their text is copied, word for word, into a block placed directly below the contents list of every agent instruction file: every global file outside a repository, and every AGENTS.md, CLAUDE.md, GEMINI.md, CLAUDE_TEMPLATE.md and agent instructions file in dotfiles and in every repository under `~/projects`.
Repeating the block is intended; the owner wants it known everywhere, not kept DRY.
One source file holds the block, and a Make target writes it between markers into every file, so a change to the rules reaches every copy in one run, never by hand.

GOOD: an agent opens any project's CLAUDE.md and the contents list, then the golden rules, are the first things it reads.
NEVER: a project instruction file that an agent can read without meeting the golden rules.
<!-- GOLDEN-RULES:END -->

These rules apply to every task in this project unless explicitly overridden.
Bias: caution over speed on non-trivial work.

## Rule 1 — Think Before Coding

State assumptions explicitly. Ask rather than guess.
Push back when a simpler approach exists. Stop when confused.

## Rule 2 — Simplicity First

Minimum code that solves the problem. Nothing speculative.
No abstractions for single-use code.

## Rule 3 — Surgical Changes

Touch only what you must. Don't improve adjacent code.
Match existing style. Don't refactor what isn't broken.

## Rule 4 — Goal-Driven Execution

Define success criteria. Loop until verified.
Strong success criteria let Claude loop independently.

## Rule 5 — Use the model only for judgment calls

Use for: classification, drafting, summarization, extraction.
Do NOT use for: routing, retries, deterministic transforms.
If code can answer, code answers.

## Rule 6 — Token budgets are not advisory

Per-task: 4,000 tokens. Per-session: 30,000 tokens.
If approaching budget, summarize and start fresh.
Surface the breach. Do not silently overrun.

## Rule 7 — Surface conflicts, don't average them

If two patterns contradict, pick one (more recent / more tested).
Explain why. Flag the other for cleanup.

## Rule 8 — Read before you write

Before adding code, read exports, immediate callers, shared utilities.
If unsure why existing code is structured a certain way, ask.

## Rule 9 — Tests verify intent, not just behavior

Tests must encode WHY behavior matters, not just WHAT it does.
A test that can't fail when business logic changes is wrong.

## Rule 10 — Checkpoint after every significant step

Summarize what was done, what's verified, what's left.
Don't continue from a state you can't describe back.

## Rule 11 — Match the codebase's conventions, even if you disagree

Conformance > taste inside the codebase.
If you think a convention is harmful, surface it. Don't fork silently.

## Rule 12 — Fail loud

"Completed" is wrong if anything was skipped silently.
"Tests pass" is wrong if any were skipped.
Default to surfacing uncertainty, not hiding it.

## Rule 13 — Never add the Claude footer to PR bodies

PR bodies must NEVER contain the "Generated with Claude Code" footer (or any
equivalent Claude/agent attribution line). This is absolute, always, no
exceptions - even when default harness guidance suggests adding it.

## Rule 14 — All testing runs in Podman

Every command whose purpose is to verify that something works runs inside a
container. No exceptions, no size threshold - a single `python3 script.py --help`
counts as testing and goes in a container. Running it on the host and reporting
the result is a Rule 12 violation, not a shortcut.

How to test is defined by the `container-sandbox` skill:

- `claude/skills/container-sandbox/SKILL.md` - npm, Terraform/Ministack, Kind,
  and full-stack compose.
- `claude/skills/container-sandbox/references/skill-testing.md` - **this is the
  file that defines how a skill or agent in this repo is tested.** It covers the
  bundled-script case (Python/Bash shipped inside a skill), the four checks that
  make a script "tested", and worked examples of good and bad testing.

If neither file has a section covering what you are testing, write one. Add it to
`SKILL.md`, or to `references/skill-testing.md` if it is about verifying a skill's
own scripts. Falling back to the host because the pattern is not documented yet is
the one thing that is never allowed.

## Rule 15 — Pin every version. No floating tags.

Anything this repo pulls from a registry, a package index, or an action
marketplace is pinned to an immutable identifier. No exceptions.

| Kind           | Wrong                | Right                   |
| -------------- | -------------------- | ----------------------- |
| Container base | `debian:stable-slim` | `debian@sha256:328d16…` |
| Container run  | `python:3.12-slim`   | `python@sha256:…`       |
| Never          | `:latest`            | anything else           |

`:latest` is banned outright. A moving tag means the thing you tested is not the
thing that ships, and a suite that silently rebases its own base image starts
failing for reasons unrelated to the change under test. That is not a hypothetical

- it is the most common way a green pipeline goes red overnight.

Repinning is a deliberate commit, never a side effect:

```bash
podman pull docker.io/library/debian:stable-slim
podman image inspect docker.io/library/debian:stable-slim \
  --format '{{index .RepoDigests 0}}'
```

Record the human-readable tag in a comment next to the digest so the next person
knows what they are looking at. A digest with no comment is unmaintainable.

This repository is **public and intended to be shared**. The agents, skills, and configurations here are designed to be consumed by anyone. That means every file must be safe to read by the general public at all times.

## Rule 16 - A skill edit carries the intent to bump. CI allocates the number

Every skill carries a `version:` in its SKILL.md frontmatter, and
`claude/skills/registry.json` is the published index of those versions. Skills
are installed into projects as **copies**, so a copy has no way of knowing the
original moved on. The version is the only thing that tells it.

**A branch never allocates a version.** A number chosen on a branch is a number
two branches can choose at once, which is what made `registry.json` a conflict
point between concurrent skill pull requests. So a pull request states only what
it _wants_, and the number is allocated on `main` after the merge - the first
moment at which the ordering is actually known.

Nothing you do on a branch touches a `version:` line or `registry.json`. If
either appears in your diff, the gate refuses the pull request.

### The path, end to end

A skill edit reaches a project through eight steps. A contributor performs steps
1, 2, 3 and 5; steps 4, 6 and 8 are automatic; step 7 is done once per project
and never again. No step anywhere is a human choosing a version number.

1. **Edit** a file under `claude/skills/<name>/`, on a feature branch.

2. **Check locally** with
   `claude/skills/skill-registry/scripts/skill-version.sh verify --structure`.
   It asserts that every skill has a `version:`, that every `requires:` names a
   skill that exists, and that neither a `version:` line nor `registry.json`
   appears anywhere in the branch's diff. It allocates nothing and writes
   nothing.

3. **State the intent in the pull request body** - last paragraph, nothing after
   it, one line per changed skill:

   ```text
   Bump: <skill>=major|minor|patch
   ```

   A single-skill pull request needs no trailer when the title carries a
   conventional type: `feat` is minor, `fix` is patch, and a `!` or a
   `BREAKING CHANGE:` footer is major. A brand new skill needs no trailer
   either - absence from the registry is unambiguous, and the publisher stamps
   it at `1.0.0`.

4. **The gate reads it.** `.github/workflows/skill-pr-gate.yml` resolves a level
   for every skill the branch changed, prints the `current -> next` table on the
   pull request, and runs each changed skill's suite. It reads and it refuses;
   it writes nothing. A level it cannot resolve is a red check while a human is
   still looking at the description, rather than a silent no-op after the merge.

5. **Squash merge**, with the pull request body as the commit message. That is
   what carries the trailer onto `main`, so the body is not decoration.

6. **The publisher allocates.** `.github/workflows/skill-publish.yml` reads the
   trailer with `git interpret-trailers --parse` and drives `skill-version.sh`,
   which writes each skill's new `version:` and renders `registry.json` from the
   tree; the workflow commits both to `main`. It runs no logic of its own beyond
   that script, and its commit carries a `Skill-Publish` marker so the resulting
   push cannot re-trigger it. If it cannot resolve a level it fails having
   written nothing: the registry keeps naming the old version, projects keep the
   skill they already have, and plain `skill-version.sh verify` stays red until
   someone fixes it.

7. **A project declares the skill** by name in its `.claude/skills.toml`.

8. **A session starts.** The `SessionStart` hook runs
   `claude/tools/skill-sync.sh --boot`, which installs every declared skill from
   the published source at the registry's version, renders the read-only notice
   into each copy, and writes a receipt naming what it installed. It removes
   only what the previous receipt claimed and the manifest no longer asks for,
   so a hand-authored skill sitting beside the managed ones is never its
   business.

That is the whole path: an edit, a stated intent, a check that refuses, an
allocation on `main`, and a sync at the next session start.

| Level   | Trigger                                                                                                                                     |
| ------- | ------------------------------------------------------------------------------------------------------------------------------------------- |
| `major` | A consumer's existing usage breaks: renamed skill, removed or renamed script flag, changed format of a file the skill owns, removed trigger |
| `minor` | New capability, backward compatible: new intent, new subcommand, new reference file, new trigger                                            |
| `patch` | Wording, script bugfix, doc clarification, test-only change                                                                                 |

### `skill-update.sh` is the hand-authored path, and nothing else

`claude/skills/skill-registry/scripts/skill-update.sh` refreshes one skill in a
project that has **not** declared it in `.claude/skills.toml`, and it fetches
from GitHub so it works on a machine with no dotfiles checkout. That is its
entire remit.

A skill the manifest declares is owned by `skill-sync`, and pointing
`skill-update.sh` at one only produces a copy that the next session start
replaces.

Refer to the user as _they_ for pronouns - never assume who they may be.

## Starting a session - read `HYDRATION.md` first

`HYDRATION.md` is the prompt that starts this session, and the nine before it.

**Read the top entry only.** It is current and complete on its own; everything below it has been
superseded and is kept so a question about how we got here can be answered, not so it can be read at
the start of a session.

The file is owned by `hydration.sh` from the `hydration-prompt` skill. Never hand-edit it, and never
assemble its launch command by typing one.

## Feature branches only - never commit to `main`

`main` is written once and never again directly, with one exception: the publish
workflow commits the version bump and the regenerated registry after a merge.
It is the only actor permitted to, it runs no logic beyond `skill-version.sh`,
and `verify` is the assertion that it did the right thing.

The exception is named here, in the same file that defines the pipeline it
serves, so that the next thing wanting to skip review has to argue for itself
rather than cite this one as precedent. It covers
`.github/workflows/skill-publish.yml` and nothing else. No other workflow, no
script, and no agent writes `main` - close-out included, which happens on the
feature branch inside the pull request and leaves nothing to do afterwards.

## Close-out and post-merge cleanup

`workflows/close-out-procedure.md` is the procedure, in full, with a diagram.
Read it once. What follows is the part that must not be got wrong.

**Close-out happens on the feature branch, inside the pull request.**
`work-order.sh done` stamps the ticket, moves it to `work-orders/archive/<year>/`, regenerates `INDEX.md`, and commits nothing.
You commit that move, along with the hydration entry, onto the same pull request as the work it records.
Nothing is written to `main` afterwards.

The order is fixed and the middle two steps are the ones that get stranded:

1. `gh pr create`
2. `work-order.sh submit --id <id> --pr <N>` - `submit` must precede `done`
3. `work-order.sh done --id <id>` - **on the branch, before the merge**
4. `hydration.sh check --body-file <file>` then `hydration.sh add ...`
5. `git add -A && git commit && git push` - rides the same pull request

**After the merge, when the user says a PR is merged**, perform this automatically without being asked:

1. `work-order.sh cleanup --id <id>`.
   It fetches, fast-forwards `main`, and deletes the branch locally and on the remote.
   It refuses unless `gh` reports the pull request `MERGED`, and it writes nothing.
   Idempotent, so it is safe to re-run and safe days later on another machine.
2. Verify the result: on `main`, in sync with `origin/main`, and the branch gone from both local and remote.
3. Remove any temporary or scratch directories and scaffolding created during the work.

`gh pr merge <N> --squash --delete-branch` deletes both branches too, and is the faster path when you are merging from the same clone.
`cleanup` is the deterministic version that also works when the merge happened elsewhere.

There is no `merge_sha`.
A commit cannot contain its own merge SHA, and storing one was the only reason close-out ever needed a second act after the merge.
`pr` is the pointer, and `gh pr view <N> --json mergeCommit` resolves it for as long as the repository exists.

## PII & PHI Policy — Strictly Enforced

**Never commit personally identifiable information (PII) or protected health information (PHI) to this repository.**

This includes but is not limited to:

| Category           | Examples                                                  |
| ------------------ | --------------------------------------------------------- |
| Real names         | Your full name, usernames tied to your identity           |
| Account handles    | GitHub usernames, email addresses, social handles         |
| Internal hostnames | `myname.homelab.local`, node names tied to a real network |
| IP addresses       | Any private or public IP specific to your infrastructure  |
| Registry paths     | `ghcr.io/<your-username>/...`, DockerHub org names        |
| Repository URLs    | Any URL containing a real GitHub username or org          |
| Credentials        | Tokens, passwords, API keys, secrets — in any form        |
| PHI                | Any health, medical, or patient-related data              |

## How to Handle Environment-Specific Values

Use angle-bracket placeholders everywhere a real value would otherwise appear:

```
# Wrong
github.com/myusername/my-repo

# Correct
github.com/<your-github-username>/<repo-name>
```

Real values belong in:

- A **project-level `CLAUDE.md`** in the consuming project's repo (not committed here)
- A **`CONTEXT_STATE.md`** file in the project repo (see `context-compaction` skill)
- Environment variables or a secrets manager — never in this repo

### The documented exception: this repo's own public URLs

Two addresses in this repository are written in full, with the real GitHub
owner. The skills registry, wherever the session-start skill version check
appears:

```
https://raw.githubusercontent.com/jkkelley/dotfiles/main/claude/skills/registry.json
```

And each skill's own source, in the read-only notice every `SKILL.md` carries:

```
https://github.com/jkkelley/dotfiles/tree/main/claude/skills/<skill-name>
```

The second exists because the notice's other pointer, `~/dotfiles/claude/skills/`,
is worthless on a machine with no dotfiles checkout - which is precisely the
machine a vendored copy is most likely to be sitting on. A notice that says
"edit it upstream" without a reachable upstream is a notice that gets ignored.

**Neither is a placeholder violation, and neither must be "fixed" into one.**

The rule above exists to keep _environment-specific_ values out of a public
repo. These are not environment-specific values. They are the addresses of
specific published files in this specific public repo, and the whole point of
them is that any reader can fetch them. Replacing the owner with
`<your-github-username>` makes every reader substitute their own handle, which
resolves to a repository that does not exist. The pointer then fails silently
and stays broken forever, which is strictly worse than a visible username on a
repo that is public by design.

Anyone forking this repo who wants to publish their own copy edits those lines.
Everyone else gets a working pointer.

These are the only exceptions in the repo, and both point at this repo's own
public content. Every other environment-specific value stays in angle-bracket
form.

## Consuming These Files

To use the agents and skills in this repo in your own project:

1. Clone or symlink the relevant `claude/agents/` and `claude/skills/` directories into your project (see `setup.sh`)
2. Create a project-level `CLAUDE.md` with your real environment values
3. Reference `CONTEXT_STATE.md` from your `CLAUDE.md` for live session state

The agents and skills here are intentionally generic. Your project-level files are where specifics live.

## Before You Commit

Run a quick self-check:

```
[ ] No real usernames or GitHub handles
[ ] No IP addresses
[ ] No internal hostnames or DNS zones
[ ] No registry paths with real org/username
[ ] No tokens, keys, or passwords
[ ] No email addresses (other than generic example.com placeholders)
[ ] All environment-specific values use <placeholder> format
```

If any box is unchecked, fix it before pushing.

## Rule 17 - Skills are OS aware, and `justfile` is the entry point

Skills here are used from Linux and from Windows. A skill that works on one and
fails on the other is not portable code that happened to break; it is a skill
that was only ever tested on the author's side.

**Every skill that ships executable code carries a `justfile`.** `just` is a
single binary, installable on both platforms (`winget install Casey.Just`,
`apt install just`). It is the entry point, never the implementation - every
recipe has a plain `bash scripts/<tool>.sh ...` equivalent, so a machine without
`just` is inconvenienced rather than blocked.

The recipes exist to hide the differences that actually bite:

| Assumption                | Reality                                                                                          |
| ------------------------- | ------------------------------------------------------------------------------------------------ |
| `flock` exists            | Absent from Git Bash on Windows. Lock with `mkdir`, which is atomic everywhere                   |
| `podman` is on the host   | On Windows it lives inside WSL. `just test` dispatches through WSL and translates the mount path |
| `cmp`, `diff` are present | Minimal test images ship neither. Check for a utility before depending on it                     |

The language is not the portability problem. Bash runs on Windows under Git
Bash. What does not survive the crossing is the assumption that every Linux
utility came with it.

**A skill that genuinely cannot be cross-platform says so in its own SKILL.md
and names the platform it requires.** That is a fine outcome. Silently working
on one OS and failing on the other is not, because the failure surfaces as a
misleading error at the worst moment - `flock`'s absence is reported as a lock
timeout that never happened.

## Rule 18 - Herdr-first execution: never background processes

When a session runs inside Herdr (`HERDR_ENV=1`), every long-running thing -
agents, monitors, polls, watchers, tail views, dev servers - lives in a
**labeled Herdr pane or tab**, never in a harness background job, `nohup`,
shell `&`, `disown`, or a detached process.

The owner watches work in Herdr. A background process is invisible, and
invisible work reads as nothing happening.

How to apply:

- Verify with `test "${HERDR_ENV:-}" = 1`, then load the `herdr` skill before
  issuing control commands.
- Orchestrator layout: rename the current tab `orchestrator`, the main pane
  `claude-main`, and split a labeled `orch-shell` pane beside it for your own
  shell work.
- Every delegated agent gets its own **labeled tab** (`agent-N-<what>`) with a
  real visible agent started via `herdr agent start <name> --kind <kind>` -
  tools and output on screen. Steer with `herdr agent prompt`, wait with
  `herdr agent wait`.
- Polls and monitors (lavish-axi poll, log tails, watchers) each get a labeled
  pane; read them with `herdr pane read`.
- If not inside Herdr, say so and stop rather than silently falling back to
  background jobs - let the owner decide.

## Rule 19 - Google Drive first, and the surface follows the model

**Drive is the source of truth while the system is being built.**
Design is doc-first: before anything is created - a design, a standard, a
schema, a runbook, a template - Drive is searched first, so nothing is built
twice. Drive questions go to the **knowledge-steward** seat, never answered by
the seat that asked. The repo holds the implementation; Drive holds the
decision it implements.

**The owner-facing surface is chosen by the runtime, never by the model.**
A Kimi or Codex seat cannot mint a `claude.ai` artifact URL - that URL comes
from a Claude-only tool - and a seat with no way to produce a page either
invents a URL or produces nothing.

| Seat runtime        | `RAIL_SURFACE` | Surface                                          |
| ------------------- | -------------- | ------------------------------------------------ |
| claude              | `artifact`     | claude.ai artifact, one URL for the life of a plan |
| kimi, codex, others | `lavish`       | `lavish-axi`, a local `127.0.0.1` session URL     |

The spawner exports `RAIL_SURFACE` from the workflow declaration's runtime.
Unset falls back to `lavish`, which every runtime can open. Decisions for the
owner go through that surface, one question at a time. A lavish poll lives in a
labeled herdr pane (Rule 18), never a background job.

The Execution Rail engine that implements this ships with `project-scaffold`
at `claude/skills/project-scaffold/references/templates/rail/`, so every
scaffolded project gets the same routing.

## Adding a New Agent or Skill — Ship the MVP Immediately

Every new agent or skill in this repo must reach `main` through a PR as soon
as it has a working MVP. Don't accumulate uncommitted or branch-only work —
the value of this library is that everything in it is reachable by
`setup.sh` from `main`.

The flow Claude (or anyone) should follow when adding one:

1. **Branch** from `main`: `git checkout -b feat/<short-name>`
2. **Add the MVP** — frontmatter + a working scaffold; `<placeholder>` for
   any environment-specific value; a smoke-tested entry point if the
   agent/skill ships executable code
3. **Commit** with a descriptive message (`feat(agents): add <name>` or
   `feat(skills): add <name>`)
4. **Push** the branch and **open a PR** describing what the agent/skill does
   and any required env vars or configuration
5. **Merge** the PR — Claude is authorized to merge its own dotfiles PRs
   here. Squash or merge commit, your call. Delete the branch after merge.

"MVP" means: it does _one_ thing end-to-end, even if narrowly. A polished
v2 can land in a follow-up PR. What's not allowed is leaving a half-built
agent on a feature branch indefinitely.
