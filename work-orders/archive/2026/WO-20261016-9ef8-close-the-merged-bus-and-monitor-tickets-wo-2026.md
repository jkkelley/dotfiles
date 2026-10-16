---
{
  "id": "WO-20261016-9ef8",
  "slug": "close-the-merged-bus-and-monitor-tickets-wo-2026",
  "title": "Close the merged bus and monitor tickets WO-20261016-2092, WO-20261016-cc95 and WO-20261016-e709 (PRs 198, 200, 230)",
  "type": "chore",
  "status": "done",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T12:19:18+00:00",
  "parent": "WO-20261016-af17",
  "branch": "feat/9ef8-close-the-merged-bus-and-monitor-tickets-wo-2026",
  "pr": 359,
  "closed": "2026-10-16",
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
      "command": "bash claude/skills/work-order/scripts/work-order.sh show --id WO-20261016-2092 --json | jq -r .status",
      "exit": 0,
      "expect": "^done$"
    },
    {
      "index": 2,
      "command": "bash claude/skills/work-order/scripts/work-order.sh show --id WO-20261016-cc95 --json | jq -r .status",
      "exit": 0,
      "expect": "^done$"
    },
    {
      "index": 3,
      "command": "bash claude/skills/work-order/scripts/work-order.sh show --id WO-20261016-e709 --json | jq -r .status",
      "exit": 0,
      "expect": "^done$"
    },
    {
      "index": 4,
      "command": "make -C claude/workflow image && podman run --rm --network=none --userns=keep-id -v \"$PWD:/work:Z\" -w /work -e HOME=/tmp localhost/dotfiles-workflow-test:1 bash -c 'bash claude/workflow/tests/unit/test_bus_bind.sh'",
      "exit": 0,
      "expect": "bus-up publishes only on 127.0.0.1"
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

# WO-20261016-9ef8 - Close the merged bus and monitor tickets WO-20261016-2092, WO-20261016-cc95 and WO-20261016-e709 (PRs 198, 200, 230)

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

WO-20261016-2092 (PR 198, in-review), WO-20261016-cc95 (PR 200, in-review), WO-20261016-e709 (PR 230, in-review) merged but stay open, found by work-order.sh stale-merged (READY-MERGED); open tickets that are merged block their dependents and inflate next --line.

## Owner words

> ORD-1140 S3: cut ready dotfiles leaves to keep the ready buffer at 6 (L0 first per ORD-0537); declare disjoint touches (orchestrator brief BR-20261016-infra-design21). get this code merged the fuck in, dead code is shit, it sitting under agents is stupid (Design principles 101 item 21)

> make sure you clean up too (Design principles 101 item 11)

## Context

Found by infra-design21 inventory: work-order.sh stale-merged lists WO-20261016-2092 (PR 198, in-review), WO-20261016-cc95 (PR 200, in-review), WO-20261016-e709 (PR 230, in-review) as READY-MERGED; each one's ## Acceptance criteria are all [x] with observed lines, so done needs no evidence call. Same close-out shape as WO-20261016-5092 (close of WO-20261016-5569).

## Scope

**In**

- touches: none outside work-orders: the WO-20261016-2092, WO-20261016-cc95, WO-20261016-e709 ticket files move to work-orders/archive/2026/ by work-order.sh done only
- touches (generated, written only by work-order.sh start/submit/evidence/done, never by hand or git add): this ticket file and its archive path; work-orders/INDEX.md and the parent epic README.md are ignored generated views
- step: branch from origin/main in your own git worktree (fallback: treehouse fails, use git worktree add), never the ~/dotfiles primary clone; bash claude/skills/work-order/scripts/work-order.sh start --id <this ticket>
- step: run every TP case in order; any red case: stop with DESIGN-GAP and its output, never close that ticket
- step: bash claude/skills/work-order/scripts/work-order.sh done --id WO-20261016-2092; bash claude/skills/work-order/scripts/work-order.sh done --id WO-20261016-cc95; bash claude/skills/work-order/scripts/work-order.sh done --id WO-20261016-e709; commit 'chore(work-orders): close 2092 cc95 e709 at merged PRs 198 200 230' with this ticket id; no Bump trailer; push, gh pr create, submit --pr <N>, done on the branch, push, leave
- tool: make:claude/workflow/Makefile:image - on main; fallback: the image fails to build: stop with ENV-MISSING podman
- tool: cmd:git, cmd:jq, cmd:gh, cmd:make, cmd:podman - fallback: missing on the host: stop with ENV-MISSING naming it; gh or GitHub down: retry 3 times, then stop with A2A-003 and its output

**Out - non-goals**

- any edit to the closed tickets' content beyond what work-order.sh submit and done write
- any file outside work-orders/: stop with DESIGN-GAP
- work-orders/INDEX.md and epic READMEs by hand or by git add; waiting on CI or merging: push, open the PR, write the result, leave

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [x] `AC-H1` *(human)* WO-20261016-2092 is done
  - observed `2026-10-16` show status prints done
  - check: `bash claude/skills/work-order/scripts/work-order.sh show --id WO-20261016-2092 --json | jq -r .status` exit 0 expect /^done$/
- [x] `AC-H2` *(human)* WO-20261016-cc95 is done
  - observed `2026-10-16` show status prints done
  - check: `bash claude/skills/work-order/scripts/work-order.sh show --id WO-20261016-cc95 --json | jq -r .status` exit 0 expect /^done$/
- [x] `AC-H3` *(human)* WO-20261016-e709 is done
  - observed `2026-10-16` show status prints done
  - check: `bash claude/skills/work-order/scripts/work-order.sh show --id WO-20261016-e709 --json | jq -r .status` exit 0 expect /^done$/
- [x] `AC-H4` *(human)* the merged code is green on main (TP-1)
  - observed `2026-10-16` TP-1 exit 0, ok bus-up publishes only on 127.0.0.1; TP-2 pass=1; TP-3 pass=4
  - check: `make -C claude/workflow image && podman run --rm --network=none --userns=keep-id -v "$PWD:/work:Z" -w /work -e HOME=/tmp localhost/dotfiles-workflow-test:1 bash -c 'bash claude/workflow/tests/unit/test_bus_bind.sh'` exit 0 expect /bus-up publishes only on 127.0.0.1/
- [x] `AC-H5` *(human)* the diff holds only work-orders files
  - observed `2026-10-16` git diff names grep -v work-orders exits 1
  - check: `git diff --name-only origin/main...HEAD | grep -vE '^(work-orders/.*)$'` exit 1

## Test plan

_Test plan from claude/workflow/templates/test-plan.md, shaped by claude/workflow/schemas/test-plan.schema.json. The tester runs exactly these cases and nothing else._

**Scope under test**

the merged bus bind guard, pane-look monitor and CI events producer on origin/main

**Cases**

- `TP-1`
  - intent: a bus that can bind beyond loopback is a done that is false (2092)
  - command: `make -C claude/workflow image && podman run --rm --network=none --userns=keep-id -v "$PWD:/work:Z" -w /work -e HOME=/tmp localhost/dotfiles-workflow-test:1 bash -c 'bash claude/workflow/tests/unit/test_bus_bind.sh'`
  - expected: exit 0; prints ok  bus-up publishes only on 127.0.0.1
- `TP-2`
  - intent: the pane-look monitor still judges a working pane (cc95)
  - command: `make -C claude/workflow pane-look-test CASE=working`
  - expected: exit 0
- `TP-3`
  - intent: ci-events still publishes run start and end (e709)
  - command: `make -C claude/workflow timing-test CASE=ci-events`
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
