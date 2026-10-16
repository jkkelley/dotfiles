---
{
  "id": "WO-20261016-5092",
  "slug": "close-wo-20261016-5569-seat-up-waits-for-idle-or",
  "title": "Close WO-20261016-5569 (seat-up waits for idle or working, PR 199 merged as 1d672ef): every criterion is evidenced, only done is missing",
  "type": "chore",
  "status": "ready",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T12:10:20+00:00",
  "parent": "WO-20261016-4b6c",
  "branch": null,
  "pr": null,
  "closed": null,
  "approval": {
    "via": "override",
    "reason": "infra-design20 close-out leaf for the buffer; design approvals ruled done, ORD-0550 O4",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [],
  "blocks": [],
  "ac_checks": [
    {
      "index": 1,
      "command": "make -C claude/workflow grid",
      "exit": 0,
      "expect": "ok  herdr-grid"
    },
    {
      "index": 2,
      "command": "bash claude/skills/work-order/scripts/work-order.sh show --id WO-20261016-5569 --json | jq -r .status",
      "exit": 0,
      "expect": "^done$"
    },
    {
      "index": 3,
      "command": "git diff --name-only origin/main...HEAD | grep -vE '^(work-orders/.*)$'",
      "exit": 1,
      "expect": null
    }
  ],
  "provides": [],
  "labels": [
    "line:inbox-triage"
  ]
}
---

# WO-20261016-5092 - Close WO-20261016-5569 (seat-up waits for idle or working, PR 199 merged as 1d672ef): every criterion is evidenced, only done is missing

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

WO-20261016-5569 - seat-up waits for the agent to be idle or working, never idle only: PR 199 merged as 1d672ef37b55 and all three criteria carry evidence, but the ticket is still in-review because done never ran on the branch. While it stays in-review, WO-20261016-38a6 (its test sibling) and WO-20261016-ec34 (seat-up refuses a build seat whose brief has no ready work order) never reach next, and with them the whole grid-fix chain (ec34, 2ca4, c2b3, 9756).

## Owner words

> get this code merged the fuck in, dead code is shit, it sitting under agents is stupid (Design principles 101 item 21)

> ready buffer floor 6 (ORD-1140 S3) (orchestrator brief BR-20261016-infra-design20)

## Context

Found by infra-design20 inventory: bash claude/skills/work-order/scripts/work-order.sh show --id WO-20261016-5569 --json reports status in-review, pr 199; gh pr view 199 reports MERGED, mergeCommit 1d672ef37b5598ae3fae008da0aa02b706610c88. Its ## Acceptance criteria are all [x] with observed lines, so done needs no evidence call. Same close-out shape as WO-20261016-3ac1 (close of WO-20261016-3570).

## Scope

**In**

- touches: none outside work-orders: the WO-20261016-5569 ticket file moves to work-orders/archive/2026/ by work-order.sh done only
- touches (generated, written only by work-order.sh start/submit/evidence/done, never by hand or git add): this ticket file and its archive path; work-orders/INDEX.md and the parent epic README.md are ignored generated views
- step: branch from origin/main in your own git worktree (fallback: treehouse fails, use git worktree add), never the ~/dotfiles primary clone; bash claude/skills/work-order/scripts/work-order.sh start --id <this ticket>
- step: run TP-1; red: stop with DESIGN-GAP and its output, never close 5569
- step: bash claude/skills/work-order/scripts/work-order.sh done --id WO-20261016-5569; commit 'chore(work-orders): close WO-20261016-5569 at PR 199' with this ticket id; no Bump trailer
- tool: make:claude/workflow/Makefile:grid - on main; fallback: its image fails to build: stop with ENV-MISSING podman; a red case: stop with DESIGN-GAP and its output
- tool: cmd:git, cmd:jq, cmd:gh, cmd:make, cmd:podman - fallback: missing on the host: stop with ENV-MISSING naming it; gh or GitHub down: retry 3 times, then stop with A2A-003 and its output

**Out - non-goals**

- any edit to WO-20261016-5569 content beyond what work-order.sh done writes
- any edit under claude/workflow/
- work-orders/INDEX.md and epic READMEs by hand or by git add; waiting on CI or merging: push, open the PR, write the result, leave
- any file not named under In: stop with DESIGN-GAP

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [ ] `AC-H1` *(human)* the merged 5569 code is green on main
  - check: `make -C claude/workflow grid` exit 0 expect /ok herdr-grid/
- [ ] `AC-H2` *(human)* WO-20261016-5569 is done
  - check: `bash claude/skills/work-order/scripts/work-order.sh show --id WO-20261016-5569 --json | jq -r .status` exit 0 expect /^done$/
- [ ] `AC-H3` *(human)* the diff holds only work-orders files
  - check: `git diff --name-only origin/main...HEAD | grep -vE '^(work-orders/.*)$'` exit 1

## Test plan

_Test plan from claude/workflow/templates/test-plan.md, shaped by claude/workflow/schemas/test-plan.schema.json. The tester runs exactly these cases and nothing else._

**Scope under test**

the merged WO-20261016-5569 code on origin/main (PR 199, 1d672ef), re-run before its ticket is closed

**Cases**

- `TP-1`
  - intent: closing a ticket whose merged code is red on main records a done that is false, and unblocks WO-20261016-38a6 and WO-20261016-ec34 on broken ground
  - command: `make -C claude/workflow grid`
  - expected: exit 0; output holds ok  seat-up with a prompted seat that is working exits 0 and writes agent-seen and the last line ok  herdr-grid

**Isolation**

_A locally built image uses `- image: localhost/<name>:<tag>` plus `- build: <command>` and `- containerfile: <path>` lines, never a localhost digest (RR-orch-18)._

- runtime: podman
- image: `localhost/dotfiles-workflow-test:1`
- build: `make -C claude/workflow image`
- containerfile: claude/workflow/tests/container/Containerfile

**Out of scope - CI covers**

- lint and the full suite: CI runs them (Design principles 101 item 6)

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
