---
{
  "id": "WO-20261016-377c",
  "slug": "work-order-ticket-template-a-before-submit-secti",
  "title": "work-order ticket template: a Before submit section whose one box is make pre-push, the last box before submit",
  "type": "feature",
  "status": "ready",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T08:28:31+00:00",
  "parent": "WO-20261016-ebe4",
  "branch": null,
  "pr": null,
  "closed": null,
  "approval": {
    "via": "override",
    "reason": "infra-design6 cut for ORD-0814 P1 P2; design approvals ruled done, ORD-0550 O4",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [
    "WO-20261016-e4b4",
    "WO-20261016-565d"
  ],
  "blocks": [
    "WO-20261016-4814",
    "WO-20261016-138a"
  ],
  "ac_checks": [
    {
      "index": 1,
      "command": "bash claude/skills/work-order/testing/run-tests.sh",
      "exit": 0,
      "expect": null
    },
    {
      "index": 2,
      "command": "bash -c awk\\ \\'/\\^##\\ Test\\ plan\\$/\\{t=NR\\}\\ /\\^##\\ Before\\ submit\\$/\\{b++\\;\\ at=NR\\}\\ /\\^##\\ Assumptions\\$/\\{a=NR\\}\\ END\\{exit\\ \\!\\(b==1\\ \\&\\&\\ t\\<at\\ \\&\\&\\ at\\<a\\)\\}\\'\\ claude/skills/work-order/references/ticket.tmpl",
      "exit": 0,
      "expect": null
    },
    {
      "index": 3,
      "command": "bash claude/skills/skill-registry/scripts/skill-version.sh verify --structure",
      "exit": 0,
      "expect": null
    },
    {
      "index": 4,
      "command": "make rolodex-check BASE=origin/main",
      "exit": 0,
      "expect": null
    },
    {
      "index": 5,
      "command": "bash -c \\!\\ git\\ diff\\ --name-only\\ origin/main...HEAD\\ \\|\\ grep\\ -vE\\ \\'\\^\\(work-orders/\\|claude/skills/work-order/\\(references/ticket\\\\.tmpl\\|SKILL\\\\.md\\|testing/SOP\\\\.md\\|testing/cases/300-before-submit-box\\\\.sh\\)\\)\\$\\'",
      "exit": 0,
      "expect": null
    }
  ],
  "provides": []
}
---

# WO-20261016-377c - work-order ticket template: a Before submit section whose one box is make pre-push, the last box before submit

## Contents

- Problem
- Owner words
- Context
- Scope
- Degrees of freedom
- Acceptance criteria
- Test plan
- Assumptions
- Open questions
- Notes
- Outcome

## Problem

A ticket gives the seat no step to run the fast gates before submit. This is the template half of ORD-0814 P1.

## Owner words

> ORD-0814 P1: "cut the tooling ticket: make pre-push in dotfiles runs every fast gate on the changed files in under 30 s (rolodex-check, md-contents-check, tracked-ignored-check, bump-gate resolve against the PR body draft, a2a-lint, spec-check); seat-up installs it as a git pre-push hook in every seat worktree, and the work-order template adds it as the last checklist box before submit."

## Context

Evidence 2026-10-16 08:00-08:15Z: PRs 216, 219, 225, 234 red on headers or tracked-ignored-check; 213, 219, 210 red on bump intent. Each red costs a CI round and a seat; every one of those gates is local and fast.

Inventory: claude/skills/work-order/references/ticket.tmpl has no checklist outside Acceptance criteria; evidence, amend, check and the AC-H index all scan only the ## Acceptance criteria section, and the Contents list is derived from the template H2 headings, so a new H2 section with one literal box moves no index and no gate. WO-20261016-565d (in review) touches SKILL.md and testing, so this ticket waits on it, and on the root include ticket because the box names make pre-push from the dotfiles root. The hook from the seat-up ticket is the enforcement; the box is the line the seat reads before submit.

The box line, exactly: - [ ] `make -s -C "${DOTFILES:-$HOME/dotfiles}" pre-push REPO="$PWD"` exits 0 and prints `PREPUSH-OK`, run in the ticket worktree as the last step before `work-order.sh submit`; the seat git pre-push hook runs the same gates on every push

The SKILL.md sentence, exactly: Before submit carries one box, `make pre-push` from dotfiles, the last thing a seat runs before `submit`; it sits outside Acceptance criteria, so no index or gate moves (ORD-0814 P1).

## Scope

**In**

- touches: claude/skills/work-order/references/ticket.tmpl
- touches: claude/skills/work-order/SKILL.md
- touches: claude/skills/work-order/testing/SOP.md
- touches: claude/skills/work-order/testing/cases/300-before-submit-box.sh (new)
- touches (generated, written only by work-order.sh start/submit/done, never by hand): work-orders/INDEX.md, this ticket file and its archive path, work-orders/WO-20261016-ebe4/README.md
- step: start only after WO-20261016-565d and the root include ticket are done and merged; branch from origin/main
- step: ticket.tmpl: after the test-plan placeholder line of the Test plan section (and its following blank line) and "## Assumptions" insert "## Before submit", a blank line, the box line in Context, and a blank line
- step: SKILL.md, section "What a ticket says": the sentence listing the sections an agent reads gains "Before submit" between "Test plan" and "Assumptions", followed by the sentence in Context
- step: testing/cases/300-before-submit-box.sh, same structure and helpers as 250-degrees-of-freedom.sh (rolodex header): mint one ticket; assert ## Before submit is the H2 after ## Test plan and before ## Assumptions; exactly one "- [ ]" line in that section and it contains "pre-push"; the Contents list names Before submit between Test plan and Assumptions; the first "- [ ]" line under ## Acceptance criteria is still AC-H1
- step: testing/SOP.md: a 300-before-submit-box entry in its contents list and a section in the shape of the 250 one, stating the why (ORD-0814 P1; the box is outside Acceptance criteria so no index moves)
- step: the PR body last paragraph is exactly "Bump: work-order=minor"
- step: run only TP-1, TP-2 and the AC checks; CI runs the rest
- tool: path:claude/skills/work-order/testing/run-tests.sh - on main; fallback: no case-name filter: run the whole work-order suite, which is this skill own suite and so still the relevant tests only
- tool: make pre-push from the dotfiles root - lands with the root include ticket; fallback: missing on main: stop with DESIGN-GAP naming it
- tool: cmd:git, cmd:jq, cmd:make, cmd:podman - fallback: missing on the host: stop with ENV-MISSING naming it
- tool: make:Makefile:rolodex-check - on main; fallback: missing: stop with DESIGN-GAP naming it

**Out - non-goals**

- work-order.sh: submit neither runs nor gates the box; the git hook is the enforcement
- existing tickets: the box applies to tickets minted after merge; no backfill
- any version: line or registry.json: CI allocates the number (Rule 16)
- any file not named under In: stop with DESIGN-GAP

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [ ] `AC-H1` *(human)* the work-order suite passes, case 300 included
  - check: `bash claude/skills/work-order/testing/run-tests.sh` exit 0
- [ ] `AC-H2` *(human)* Before submit sits between Test plan and Assumptions, once
  - check: `bash -c awk\ \'/\^##\ Test\ plan\$/\{t=NR\}\ /\^##\ Before\ submit\$/\{b++\;\ at=NR\}\ /\^##\ Assumptions\$/\{a=NR\}\ END\{exit\ \!\(b==1\ \&\&\ t\<at\ \&\&\ at\<a\)\}\'\ claude/skills/work-order/references/ticket.tmpl` exit 0
- [ ] `AC-H3` *(human)* skill structure verifies with no version or registry change
  - check: `bash claude/skills/skill-registry/scripts/skill-version.sh verify --structure` exit 0
- [ ] `AC-H4` *(human)* every new script has a rolodex header
  - check: `make rolodex-check BASE=origin/main` exit 0
- [ ] `AC-H5` *(human)* the diff holds only In files and generated work-orders files
  - check: `bash -c \!\ git\ diff\ --name-only\ origin/main...HEAD\ \|\ grep\ -vE\ \'\^\(work-orders/\|claude/skills/work-order/\(references/ticket\\.tmpl\|SKILL\\.md\|testing/SOP\\.md\|testing/cases/300-before-submit-box\\.sh\)\)\$\'` exit 0

## Test plan

_Test plan from claude/workflow/templates/test-plan.md, shaped by claude/workflow/schemas/test-plan.schema.json. The tester runs exactly these cases and nothing else._

**Scope under test**

claude/skills/work-order/references/ticket.tmpl section Before submit

**Cases**

- `TP-1`
  - intent: every new ticket carries the pre-push box as its last checklist box before submit (order ORD-0814 P1)
  - command: `bash claude/skills/work-order/testing/run-tests.sh 300-before-submit-box`
  - expected: exit 0; a minted ticket has `## Before submit` after `## Test plan` and before `## Assumptions`, exactly one `- [ ]` line in it naming `pre-push`, and the Contents list names Before submit
- `TP-2`
  - intent: the box sits outside Acceptance criteria, so evidence indexes, amend and done gates are unchanged
  - command: `bash claude/skills/work-order/testing/run-tests.sh`
  - expected: exit 0; every case passes, 150, 160, 250 and 270 included

**Isolation**

- runtime: podman
- image: `docker.io/library/debian:bookworm-slim@sha256:3783cc01769c7b2b1b83a5c5ad96c815348e28ed7da68e2e3687004faa906251` (debian:bookworm-slim, base of localhost/dotfiles-workflow-test:1)

**Out of scope - CI covers**

- skill-pr-gate.yml runs the work-order suite and the bump intent on the PR

## Assumptions

1. the box is a plain checklist line that no verb ticks or gates; the order asks for a box, and the hook from the seat-up ticket enforces the same gates on every push
1. fallback: if a new H2 breaks an existing case, stop with DESIGN-GAP naming the case; never move the box into Acceptance criteria

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

- `2026-10-16` WO-20261016-565d is in review; its blocks field is left unedited so this PR does not conflict with its close-out; depends_on here is the authoritative edge

## Outcome

_Written by `work-order done`. Empty until then._
