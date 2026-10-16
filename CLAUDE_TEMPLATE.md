# CLAUDE.md — Project Template

<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->

- [Hard rule: Design principles 101, right below the contents list](#hard-rule-design-principles-101-right-below-the-contents-list)
- [Hard rule: every Markdown file opens with a contents list](#hard-rule-every-markdown-file-opens-with-a-contents-list)
- [Hard rule: herdr tab layout for every multi-agent line](#hard-rule-herdr-tab-layout-for-every-multi-agent-line)
- [Hard rule: the golden system design rules sit right under every contents list](#hard-rule-the-golden-system-design-rules-sit-right-under-every-contents-list)
- [TO CLAUDE — read this block FIRST](#to-claude--read-this-block-first)
- [Session State](#session-state)
- [Session start — skill version check](#session-start--skill-version-check)
- [Cluster & Architecture (homelab — non-negotiable defaults)](#cluster--architecture-homelab--non-negotiable-defaults)
- [Project Overview](#project-overview)
- [Commands](#commands)
- [Architecture](#architecture)
- [Development Workflow (homelab — always in this order)](#development-workflow-homelab--always-in-this-order)
- [Build & Dependency Hygiene (sandbox-only — applies to every project)](#build--dependency-hygiene-sandbox-only--applies-to-every-project)
- [CI/CD Pipeline (homelab standard)](#cicd-pipeline-homelab-standard)
- [Shared Infrastructure (cluster-wide constants)](#shared-infrastructure-cluster-wide-constants)
- [Database](#database)
- [Recommended File Skeleton (when expanding this template)](#recommended-file-skeleton-when-expanding-this-template)
- [Markdown contents lists (every project)](#markdown-contents-lists-every-project)
- [Template provenance (delete after first fill-in)](#template-provenance-delete-after-first-fill-in)

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
31. No evidence means the SOP was broken: "if architects don't ahve supporting evidence and can't reproducre the error or no screenshot with clear evidence, then SOP wasn't followed for the DAG adn that nodes checklist of instructions" (2026-10-16 UTC). Every DAG node's checklist carries the steps that capture its evidence: the reproduction command and its output, and a screenshot for anything visual, written by script to the artifact store. An error raised by anyone, architect included, without a reproduction or clear screenshot evidence is recorded as an SOP breach of that node's checklist: the claim is dropped, and the checklist gap is fixed in the design.
32. Agents have no opinions: "agents don't get to have OPINIONs, thats my job" (2026-10-16 UTC). Opinions are the owner's alone. Agents report facts, evidence and status codes, and build to the spec and the owner's rulings; they never offer a preference, a taste or a "should" of their own. Where the spec is silent, the gap goes to the owner as a Bearings card, never filled with an agent's view.
33. The architect may break glass to unstick the line: "you have permission to breakglass shit too, you need the ability to unstick things" (2026-10-16 UTC). When the line is stuck and the system and orchestrator cannot clear it, the architect acts directly: kill or restart a seat, release a lock, reset a wedged worktree, force a stuck merge-train item, restart a monitor or the bus. Every break glass act is logged by script to the artifact store with its evidence (state before, command, state after), and is followed at once by a work order that turns it into automation, since a hand fix is a defect. Break glass never overrides these rules: no credentials or vaults, no minecraft-admin, no routing around the classifier, no send or post without owner approval of the exact item, no AWS spend beyond item 25, no history rewrite on a shared main.
34. Testing is promoted dev, then UAT, then stable: "Ensure that your testing is dev uat stable." (2026-10-16 UTC). Every change passes three gates in order, each a scripted Make target with its own test plan and evidence: dev (podman sandbox, fakes, only the tests the change touches), UAT (the real line or environment with a test seat or test data, acceptance criteria observed with evidence), and stable (promoted to run for real, watched by its monitor, with a scripted rollback). A change never skips a gate, and a failed gate rolls back to the one before by script.
35. Testing never notifies the owner: "And don't ever bog the user down with notifications when testing." and "Or any testing for that matter." (2026-10-16 UTC). No test at any gate, dev, UAT or stable, sends the owner a notification, card, message or ping, and no test asks the owner to do or check anything. Tests that exercise a notifier send to a separate test channel, and a script reads that channel back as the proof. Only real events reach the owner.
36. The architect hotfixes missing permissions on the spot, then designs them in: "You have the same abilities as I do. If a job or agent needs the permissions and their schema doesn't have it. Hotfix them on the spot and then get that fix into the Doc design DAG for the worker. Easy path with least resistance an no friction." (2026-10-16 UTC). When a job or seat is blocked because its brief, schema, settings or allow list lacks a permission it needs for approved work, the architect grants it at once, logs the hotfix by script to the artifact store (what was missing, what was granted, where), and files a work order that puts the grant into that worker's design, DAG node and schema so the next run has it up front. The rules that name the owner alone stay the owner's: minecraft-admin, approval of each exact send or post, the owner's own typed words where the classifier requires them, credentials and vaults.
37. Time every process, and a slow one is a bottleneck: "Remember never hand 🤚 automation and identitify bottlenecks when things take too long or when any process takes. We need to track time to keep the process from getting stuck. It builds justification" (2026-10-16 UTC). Every DAG node, seat, job, CI run and merge records its start and end in UTC on the bus by script, never by hand. Each node carries a time budget in its design; a run over budget emits status code SLOW with its evidence and becomes a bottleneck work order. A scripted report (durations, budgets, top bottlenecks per line) is the justification for every fix and every design change.
38. Batch logically, push systematically: "Batch things together so they can be logically and systematically pushed out." (2026-10-16 UTC). Work is grouped into batches by DAG layer and by the area it touches, and a batch moves through dev, UAT and stable as one unit on a scripted cadence. Orders, rule broadcasts and reports between agents are batched the same way: one message per cadence carrying every item, never one message per item. Tickets stay small; the batch is how they ship together.

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

> **This file is a template copied from `~/dotfiles/CLAUDE_TEMPLATE.md`.**
> Public dotfiles repo policy applies: no real values may live in the template itself.
> Real values belong here in the project-level `CLAUDE.md` after it's been copied in.

---

## TO CLAUDE — read this block FIRST

If any `<placeholder>` token still appears anywhere in this file, you are reading the
template for the first time in a fresh project and **the operator has not yet filled it in**.

**Before doing any other work — including answering "simple" questions, exploring the
codebase, or running tools — do this:**

1. Scan the file for every `<placeholder>` token.
2. Walk through each one with the user, in order, and ask for the real value.
3. Replace each placeholder via `Edit` as you go (don't batch — confirm each one).
4. When finished, delete this entire `## TO CLAUDE — read this block FIRST` section
   and the surrounding template-instruction blocks (the top "This file is a template"
   admonition and the bottom "Template provenance" footer).
5. Then, and only then, proceed to the user's original task.

If the user explicitly says "skip the placeholder pass" — honor it, but flag any
`<placeholder>` you encounter later as "unresolved template token" and confirm before
relying on it.

---

## Session State

See `CONTEXT_STATE.md` in this project root for current infrastructure state, active
tasks, decisions made, blockers, and lessons learned. **Read it before starting any task.**

If `CONTEXT_STATE.md` doesn't exist yet, create one using the `context-compaction` skill
when context usage exceeds ~30%, or when starting a new session that needs continuity.

---

## Session start — skill version check

Skills are installed into this project as **copies**. A copy has no way of knowing the
original moved on, so this check is the only thing standing between this project and a
silently stale skill. Run it once, before the first task of the session.

Skip the whole thing if `.claude/skills/` does not exist.

**1. Read both sides.**

```bash
curl -fsS --max-time 5 https://raw.githubusercontent.com/jkkelley/dotfiles/main/claude/skills/registry.json
grep -H '^version:' .claude/skills/*/SKILL.md
```

That URL is literal and correct. It is **not** a placeholder to be substituted with your
own handle — see "the one documented exception" in the dotfiles `CLAUDE.md`. Substituting
it points the check at a repository that does not exist and breaks it silently.

**2. Compare.**

- A skill with no `version:` line predates versioning. Treat it as behind.
- A skill installed here but absent from the registry is project-local. Ignore it silently.
- If the fetch fails, say one line — `skill version check skipped, registry unreachable` —
  and start the work. Never block a session on this.

**3. If everything matches, say nothing.** Start the work. No output, no confirmation,
no "all skills current" line.

**4. If anything is behind, print the gap, then ask.** One table, then exactly three
options, then wait for an answer:

| skill            | installed | latest | bump  |
| ---------------- | --------- | ------ | ----- |
| hydration-prompt | 1.1.0     | 1.4.0  | minor |

1. **Update now.** Standalone, before the work starts.

   ```bash
   ~/dotfiles/claude/skills/skill-registry/scripts/skill-update.sh \
     --skill <name> --mode standalone --project .
   ```

   Branches off `origin/main` inside a throwaway worktree, copies, commits, pushes,
   opens a PR, squash-merges it without review, deletes the branch, fast-forwards local
   `main`, and prints the PR URL. The working tree is never touched, so work in progress
   is safe. Merged without review on purpose: the content is a byte copy of a file
   already reviewed in dotfiles, so there is nothing left for a human to decide.

2. **Fold it into this work.** The update rides the commit that is about to happen anyway.

   ```bash
   ~/dotfiles/claude/skills/skill-registry/scripts/skill-update.sh \
     --skill <name> --mode inline --project .
   ```

   Copies the skill in and leaves it uncommitted. No branch, no PR, no round trip.
   Then get straight on with the actual task.

3. **Note it and move on.** The table above was the whole deliverable. Write nothing,
   start the work.

Report the outcome plainly: the new version and the full path on success, or the failing
step and the log path on failure. The script captures both.

If `~/dotfiles` is not checked out on this machine, only option 3 is available — report
the gap and say that updating needs the dotfiles checkout.

---

## Cluster & Architecture (homelab — non-negotiable defaults)

| Fact                   | Value                                |
| ---------------------- | ------------------------------------ |
| Cluster                | homelab Kubernetes                   |
| Node architecture      | **ARM64 (aarch64)**                  |
| Default image platform | `linux/arm64`                        |
| Multi-arch images      | **only when explicitly requested**   |
| Kubernetes version     | `<k8s-version>` (e.g. `1.31`)        |
| Control plane          | `<control-plane-host>`               |
| Worker nodes           | `<worker-node-1>`, `<worker-node-2>` |

**Implications Claude must respect without being told:**

- Every `Dockerfile` in this repo must produce an `arm64` image. Either use a base
  image whose default arch is arm64, or pin `--platform=linux/arm64` / set
  `GOARCH=arm64` / equivalent for the language.
- When pulling container images during local testing (Podman), prefer `arm64`
  variants. Some images (e.g. `wiktorn/overpass-api`) ship amd64-only — flag this
  before suggesting them.
- Don't recommend amd64-only tools (e.g. some `ghcr.io/*` releases without arm64
  builds, certain prebuilt CLIs) without confirming the user has a workaround.
- Cross-compile from amd64 dev hosts when WSL2/x86 is the dev box; build on-cluster
  when possible.

---

## Project Overview

`<one-paragraph description of what this project does, who uses it, and which other
services it interacts with>`

`<table of subdirectories / services if monorepo, otherwise delete>`

| Directory | Language | Role     |
| --------- | -------- | -------- |
| `<dir>`   | `<lang>` | `<role>` |

---

## Commands

```bash
# Local dev
<dev-command>

# Build
<build-command>

# Tests
<test-command>      # or note "no test suite yet"

# Lint
<lint-command>      # or note "no linting configured"
```

---

## Architecture

`<short prose + diagram describing layers, data flow, and any non-obvious design
decisions. Pull only what's NOT derivable from reading the code — design rationale,
constraints, cross-service contracts, schema-flexibility rules.>`

---

## Development Workflow (homelab — always in this order)

This homelab has a strict, opinionated workflow. Claude must follow it even when
"shipping fast" feels tempting. Skipping a step has caused build failures and
cluster drift in the past.

1. **Local development & verification — every change.** Iterate inside an
   ephemeral sandbox. Two flavors, pick whichever fits the change:

   - **Podman** — for unit tests, integration tests, build verification, and any
     work that does not require a Kubernetes API. See _Build & Dependency Hygiene_
     below for the exact pattern.
   - **Kind** (Kubernetes-in-Docker) — for any change that touches manifests,
     RBAC, NetworkPolicies, CRDs, or anything else that needs a real apiserver.
     Spin up a throwaway Kind cluster, apply the manifests there, prove
     correctness, then tear it down. **Never test manifests against the homelab
     cluster directly.**

   **Bring every dependency into the sandbox.** No language toolchains, kubectl
   plugins, helm chart caches, or test fixtures may be installed on the host.
   The container/cluster is the dependency boundary.

2. **Commit + push — only after sandbox verification passes.** Push the project
   repo to its `main` (or feature branch). Don't push code that hasn't been
   exercised in step 1.

3. **Manually trigger Jenkins.** Webhooks and SCM polling are _not_ the trigger
   of record — the operator (the human user) clicks "Build Now" in the Jenkins
   UI when ready. This is intentional: it gives the operator a final chance to
   confirm the right commit will be built. **Claude does not trigger Jenkins.**

4. **Jenkins → Kaniko → GHCR.** The pipeline builds the image, scans it with
   Trivy, and (for ArgoCD-managed apps only) updates the GitOps overlay. See
   _CI/CD Pipeline_.

5. **GitOps prerequisite — for ArgoCD-managed apps only.** **The Jenkins
   `Update GitOps` stage will fail unless `apps/<app-name>/{base,overlays/homelab}/`
   already exists in the `homelab-gitops` repo.** When scaffolding any new
   project that will be ArgoCD-managed:

   - Claude must scaffold the overlay directory in `homelab-gitops`
     **before** the first Jenkins build that includes the GitOps stage.
   - Pattern: `apps/<app-name>/base/{kustomization.yaml, manifests…}` plus
     `apps/<app-name>/overlays/homelab/kustomization.yaml` containing an
     `images:` block.
   - Use an existing app under `apps/` as the template.

   **If the project produces only an image with no continuously-synced k8s
   resources** (e.g. a dispatcher whose Jobs are created on demand by another
   service), drop the `Update GitOps — Homelab` stage from the project's
   `Jenkinsfile` instead of scaffolding an empty overlay.

6. **ArgoCD sync.** Once `homelab-gitops` is updated, ArgoCD picks up the change
   and syncs the cluster. **Never `kubectl apply` against homelab as a workflow
   step** — that bypasses GitOps and causes drift. (One-off `kubectl` against
   homelab is fine for inspection, debugging, and reading state.)

**Claude's responsibility:** Surface step 5 (the `homelab-gitops` overlay) as a
pre-flight check **before** the first Jenkins build of any new ArgoCD-managed
project — not after the build fails. Don't wait to be reminded.

---

## Build & Dependency Hygiene (sandbox-only — applies to every project)

**Never run language toolchains directly on the host.** This includes (but is not
limited to) `go build`, `go mod tidy`, `go test`, `npm install`, `npm run *`,
`pip install`, `pytest`, `cargo build`, `cargo test`, `mvn`, `gradle`, etc.

Use Podman with a throwaway container whose tag matches the `FROM` line in the
project's `Dockerfile`. Mount the repo at `/app`:

```bash
# Pattern (substitute the right base image for the language)
podman run --rm -v .:/app:Z -w /app <base-image> sh -c "<command>"

# Examples
podman run --rm -v .:/app:Z -w /app docker.io/golang:1.22-alpine sh -c "go mod tidy"
podman run --rm -v .:/app:Z -w /app docker.io/node:20-alpine     sh -c "npm install"
podman run --rm -v .:/app:Z -w /app docker.io/python:3.12-slim   sh -c "pip install -r requirements.txt"
```

Notes:

- The `:Z` mount flag is required on SELinux hosts; harmless elsewhere.
- Podman on WSL2 requires **fully-qualified image names** (`docker.io/golang:1.22`,
  not `golang:1.22`).
- See the `container-sandbox` skill for the full protocol.

This rule exists because uncontrolled toolchain use on the host pollutes module/build
caches and causes "works on my machine" drift between local and CI builds.

---

## CI/CD Pipeline (homelab standard)

**Triggering: manual.** Operator clicks "Build Now" in the Jenkins UI. See
_Development Workflow_, step 3.

All projects in this homelab use the same pipeline shape:

1. **Kaniko** builds the OCI image inside the cluster (no Docker daemon).
2. **Trivy** scans the image (non-blocking by default).
3. **Kustomize** overlay at `k8s/overlays/homelab/` is updated with the new image tag.
   _(Skip for projects that produce an image-only artifact with no synced k8s resources.)_
4. **ArgoCD** picks up the manifest change and syncs to the cluster.

**Pre-flight requirement (step 3):** the GitOps overlay path must already exist
in `homelab-gitops` before the stage runs — see _Development Workflow_, step 5.

| Variable            | Value                                                        |
| ------------------- | ------------------------------------------------------------ |
| Image registry      | `ghcr.io/<github-username>/<repo-name>`                      |
| Image tag scheme    | `<tag-scheme>` (typically `${BUILD_NUMBER}` or `${GIT_SHA}`) |
| Pipeline definition | `jenkins/Jenkinsfile`                                        |
| Shared library      | `jenkins-shared-lib` (see the `homelab-shared-lib` skill)    |
| GitOps repo         | `github.com/<github-username>/<gitops-repo-name>`            |
| Overlay path        | `apps/<app-name>/overlays/homelab`                           |

Standard shared-lib steps used: `buildKaniko`, `imageScanTrivy`, `updateGitOpsManifest`.
For Jenkinsfile patterns and snippets, see the `jenkinsfile-snippets` skill.

---

## Shared Infrastructure (cluster-wide constants)

| Resource                 | Value                                                     |
| ------------------------ | --------------------------------------------------------- |
| Cluster name             | `<cluster-name>`                                          |
| Namespace (this project) | `<project-namespace>`                                     |
| Ingress controller       | HAProxy + cert-manager                                    |
| Cert issuer              | `local-ca-issuer`                                         |
| TLS host(s)              | `<host>.homelab`                                          |
| Storage class            | Longhorn (RWO default; RWX where explicitly noted)        |
| Secrets management       | external-secrets-operator (`jenkins-ssm-store`)           |
| Service registry pattern | `http://<svc>.<namespace>.svc.cluster.local:<port>`       |
| Image pull secret        | `<image-pull-secret-name>` (typically `ghcr-pull-secret`) |

**In-cluster service URLs (this project):**

| Service       | URL                                                   |
| ------------- | ----------------------------------------------------- |
| `<service-1>` | `http://<svc-1>.<namespace>.svc.cluster.local:<port>` |
| `<service-2>` | `http://<svc-2>.<namespace>.svc.cluster.local:<port>` |

---

## Database

| Field                     | Value                                                        |
| ------------------------- | ------------------------------------------------------------ |
| Engine                    | `<postgres                                                   | mysql   | sqlite     | ...>` |
| Deployment                | `<StatefulSet                                                | managed | external>` |
| Storage                   | `<longhorn-pvc-size>`                                        |
| Backup                    | `<backup-strategy>` (e.g. daily `pg_dump` to S3 at `<time>`) |
| Connection secret         | `<db-secret-name>`                                           |
| Connection string env var | `DATABASE_URL`                                               |

`<schema-flexibility / migration-strategy notes — only what isn't derivable from
inspecting migration files. Examples: JSONB column for forward-compat, soft-delete
convention, dedup contract shared between services, etc.>`

---

## Recommended File Skeleton (when expanding this template)

Add sections only if they apply. Follow this order so cross-project navigation stays
predictable:

1. Session State (above)
2. Cluster & Architecture (above)
3. Project Overview
4. Commands
5. Architecture
6. Shared Contracts (if monorepo or if this service shares state with others)
7. Development Workflow (above)
8. Build & Dependency Hygiene (above)
9. CI/CD Pipeline (above)
10. Shared Infrastructure (above)
11. Database
12. Environment Variables
13. Known Issues / Footguns

---

## Markdown contents lists (every project)

Every `.md` file opens with a contents list, generated and never typed.
Copy `scripts/md-contents.sh`, `config/md-contents.exclude` and the `md-contents*` targets from `~/dotfiles/Makefile`.
Run `make md-contents` to write the lists, and add `make md-contents-check` to the fast lint job.

## Template provenance (delete after first fill-in)

This file was copied from `~/dotfiles/CLAUDE_TEMPLATE.md`. The dotfiles repo is **public**
and contains only placeholders. Real environment values (registry paths, hostnames,
namespaces, IPs, secret names) live **here** in the project-level `CLAUDE.md` and in
`CONTEXT_STATE.md` — never back in the template.

Once you've filled in every `<placeholder>`, delete:

- The top admonition block
- The `## TO CLAUDE — read this block FIRST` section
- This `## Template provenance` section

What remains is your project-level `CLAUDE.md`.
