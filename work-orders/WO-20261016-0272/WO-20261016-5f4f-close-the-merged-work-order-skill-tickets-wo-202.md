---
{
  "id": "WO-20261016-5f4f",
  "slug": "close-the-merged-work-order-skill-tickets-wo-202",
  "title": "Close the merged work-order skill tickets WO-20261016-1c04, WO-20261016-565d and WO-20261016-6e76 (PRs 204, 207, 271)",
  "type": "chore",
  "status": "in-progress",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T12:19:39+00:00",
  "parent": "WO-20261016-0272",
  "branch": "feat/5f4f-close-the-merged-work-order-skill-tickets-wo-202",
  "pr": null,
  "closed": null,
  "approval": {
    "via": "override",
    "reason": "infra-design21 cut DESIGN-GAP d38a and ORD-1140 S3 (brief BR-20261016-infra-design21); design approvals ruled done, ORD-0550 O4; Claude seats never use lavish (global owner rule)",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [],
  "blocks": [],
  "ac_checks": [
    {
      "index": 1,
      "command": "bash claude/skills/work-order/scripts/work-order.sh show --id WO-20261016-1c04 --json | jq -r .status",
      "exit": 0,
      "expect": "^done$"
    },
    {
      "index": 2,
      "command": "bash claude/skills/work-order/scripts/work-order.sh show --id WO-20261016-565d --json | jq -r .status",
      "exit": 0,
      "expect": "^done$"
    },
    {
      "index": 3,
      "command": "bash claude/skills/work-order/scripts/work-order.sh show --id WO-20261016-6e76 --json | jq -r .status",
      "exit": 0,
      "expect": "^done$"
    },
    {
      "index": 4,
      "command": "make -C claude/workflow image && podman run --rm --network=none --userns=keep-id -v \"$PWD:/work:Z\" -w /work -e HOME=/tmp localhost/dotfiles-workflow-test:1 bash -c 'bash scripts/tests/test_wo_untrack_generated.sh'",
      "exit": 0,
      "expect": "plan writes nothing"
    },
    {
      "index": 5,
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

# WO-20261016-5f4f - Close the merged work-order skill tickets WO-20261016-1c04, WO-20261016-565d and WO-20261016-6e76 (PRs 204, 207, 271)

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

WO-20261016-1c04 (PR 204, in-review), WO-20261016-565d (PR 207, in-review), WO-20261016-6e76 (PR 271, in-progress) merged but stay open, found by work-order.sh stale-merged (READY-MERGED); open tickets that are merged block their dependents and inflate next --line.

## Owner words

> ORD-1140 S3: cut ready dotfiles leaves to keep the ready buffer at 6 (L0 first per ORD-0537); declare disjoint touches (orchestrator brief BR-20261016-infra-design21). get this code merged the fuck in, dead code is shit, it sitting under agents is stupid (Design principles 101 item 21)

> make sure you clean up too (Design principles 101 item 11)

## Context

Found by infra-design21 inventory: work-order.sh stale-merged lists WO-20261016-1c04 (PR 204, in-review), WO-20261016-565d (PR 207, in-review), WO-20261016-6e76 (PR 271, in-progress) as READY-MERGED; each one's ## Acceptance criteria are all [x] with observed lines, so done needs no evidence call. Same close-out shape as WO-20261016-5092 (close of WO-20261016-5569). Open WO-20261016-377c (PR 246) touches work-order SKILL.md and SOP.md; this ticket touches neither. 6e76 is in-progress with no pr recorded, so it takes submit --pr 271 before done.

## Scope

**In**

- touches: none outside work-orders: the WO-20261016-1c04, WO-20261016-565d, WO-20261016-6e76 ticket files move to work-orders/archive/2026/ by work-order.sh done only
- touches (generated, written only by work-order.sh start/submit/evidence/done, never by hand or git add): this ticket file and its archive path; work-orders/INDEX.md and the parent epic README.md are ignored generated views
- step: branch from origin/main in your own git worktree (fallback: treehouse fails, use git worktree add), never the ~/dotfiles primary clone; bash claude/skills/work-order/scripts/work-order.sh start --id <this ticket>
- step: run every TP case in order; any red case: stop with DESIGN-GAP and its output, never close that ticket
- step: bash claude/skills/work-order/scripts/work-order.sh submit --id WO-20261016-6e76 --pr 271 (it is in-progress; submit must precede done)
- step: bash claude/skills/work-order/scripts/work-order.sh done --id WO-20261016-1c04; bash claude/skills/work-order/scripts/work-order.sh done --id WO-20261016-565d; bash claude/skills/work-order/scripts/work-order.sh done --id WO-20261016-6e76; commit 'chore(work-orders): close 1c04 565d 6e76 at merged PRs 204 207 271' with this ticket id; no Bump trailer; push, gh pr create, submit --pr <N>, done on the branch, push, leave
- tool: make:claude/workflow/Makefile:image - on main; fallback: the image fails to build: stop with ENV-MISSING podman
- tool: cmd:git, cmd:jq, cmd:gh, cmd:make, cmd:podman - fallback: missing on the host: stop with ENV-MISSING naming it; gh or GitHub down: retry 3 times, then stop with A2A-003 and its output

**Out - non-goals**

- any edit to the closed tickets' content beyond what work-order.sh submit and done write
- any file outside work-orders/: stop with DESIGN-GAP
- work-orders/INDEX.md and epic READMEs by hand or by git add; waiting on CI or merging: push, open the PR, write the result, leave

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [ ] `AC-H1` *(human)* WO-20261016-1c04 is done
  - check: `bash claude/skills/work-order/scripts/work-order.sh show --id WO-20261016-1c04 --json | jq -r .status` exit 0 expect /^done$/
- [ ] `AC-H2` *(human)* WO-20261016-565d is done
  - check: `bash claude/skills/work-order/scripts/work-order.sh show --id WO-20261016-565d --json | jq -r .status` exit 0 expect /^done$/
- [ ] `AC-H3` *(human)* WO-20261016-6e76 is done
  - check: `bash claude/skills/work-order/scripts/work-order.sh show --id WO-20261016-6e76 --json | jq -r .status` exit 0 expect /^done$/
- [ ] `AC-H4` *(human)* the merged code is green on main (TP-1)
  - check: `make -C claude/workflow image && podman run --rm --network=none --userns=keep-id -v "$PWD:/work:Z" -w /work -e HOME=/tmp localhost/dotfiles-workflow-test:1 bash -c 'bash scripts/tests/test_wo_untrack_generated.sh'` exit 0 expect /plan writes nothing/
- [ ] `AC-H5` *(human)* the diff holds only work-orders files
  - check: `git diff --name-only origin/main...HEAD | grep -vE '^(work-orders/.*)$'` exit 1

## Test plan

_Test plan from claude/workflow/templates/test-plan.md, shaped by claude/workflow/schemas/test-plan.schema.json. The tester runs exactly these cases and nothing else._

**Scope under test**

the merged wo-untrack-generated target and work-order skill suite on origin/main

**Cases**

- `TP-1`
  - intent: wo-untrack-generated still plans before apply before 1c04 closes
  - command: `make -C claude/workflow image && podman run --rm --network=none --userns=keep-id -v "$PWD:/work:Z" -w /work -e HOME=/tmp localhost/dotfiles-workflow-test:1 bash -c 'bash scripts/tests/test_wo_untrack_generated.sh'`
  - expected: exit 0; prints ok  plan writes nothing
- `TP-2`
  - intent: the work-order suite is green on main before 565d and 6e76 close
  - command: `bash claude/skills/work-order/testing/run-tests.sh`
  - expected: exit 0

**Isolation**

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
