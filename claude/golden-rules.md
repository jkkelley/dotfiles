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
