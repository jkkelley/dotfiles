---
{
  "id": "WO-20261016-2473",
  "slug": "close-the-merged-wiki-test-tickets-wo-20261016-3",
  "title": "Close the merged wiki test tickets WO-20261016-3475, WO-20261016-7a8f and WO-20261016-f675 (PRs 323, 296, 326)",
  "type": "chore",
  "status": "ready",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T12:19:32+00:00",
  "parent": "WO-20261016-35de",
  "branch": null,
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
      "command": "bash claude/skills/work-order/scripts/work-order.sh show --id WO-20261016-3475 --json | jq -r .status",
      "exit": 0,
      "expect": "^done$"
    },
    {
      "index": 2,
      "command": "bash claude/skills/work-order/scripts/work-order.sh show --id WO-20261016-7a8f --json | jq -r .status",
      "exit": 0,
      "expect": "^done$"
    },
    {
      "index": 3,
      "command": "bash claude/skills/work-order/scripts/work-order.sh show --id WO-20261016-f675 --json | jq -r .status",
      "exit": 0,
      "expect": "^done$"
    },
    {
      "index": 4,
      "command": "podman run --rm --network=none -v $PWD:/w:Z -w /w docker.io/library/python@sha256:2f17fc044b579bab302c2e8054d3a686e2cb9a83de48e70534b94cd8ebbe06a9 python3 -m unittest -v claude/tools/wiki/tests/test_intake.py",
      "exit": 0,
      "expect": "OK"
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

# WO-20261016-2473 - Close the merged wiki test tickets WO-20261016-3475, WO-20261016-7a8f and WO-20261016-f675 (PRs 323, 296, 326)

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

WO-20261016-3475 (PR 323, in-progress), WO-20261016-7a8f (PR 296, in-progress), WO-20261016-f675 (PR 326, in-progress) merged but stay open, found by work-order.sh stale-merged (READY-MERGED); open tickets that are merged block their dependents and inflate next --line.

## Owner words

> ORD-1140 S3: cut ready dotfiles leaves to keep the ready buffer at 6 (L0 first per ORD-0537); declare disjoint touches (orchestrator brief BR-20261016-infra-design21). get this code merged the fuck in, dead code is shit, it sitting under agents is stupid (Design principles 101 item 21)

> make sure you clean up too (Design principles 101 item 11)

## Context

Found by infra-design21 inventory: work-order.sh stale-merged lists WO-20261016-3475 (PR 323, in-progress), WO-20261016-7a8f (PR 296, in-progress), WO-20261016-f675 (PR 326, in-progress) as READY-MERGED; each one's ## Acceptance criteria are all [x] with observed lines, so done needs no evidence call. Same close-out shape as WO-20261016-5092 (close of WO-20261016-5569). The three are in-progress with no pr recorded, so each takes submit --pr before done.

## Scope

**In**

- touches: none outside work-orders: the WO-20261016-3475, WO-20261016-7a8f, WO-20261016-f675 ticket files move to work-orders/archive/2026/ by work-order.sh done only
- touches (generated, written only by work-order.sh start/submit/evidence/done, never by hand or git add): this ticket file and its archive path; work-orders/INDEX.md and the parent epic README.md are ignored generated views
- step: branch from origin/main in your own git worktree (fallback: treehouse fails, use git worktree add), never the ~/dotfiles primary clone; bash claude/skills/work-order/scripts/work-order.sh start --id <this ticket>
- step: run every TP case in order; any red case: stop with DESIGN-GAP and its output, never close that ticket
- step: bash claude/skills/work-order/scripts/work-order.sh submit --id WO-20261016-3475 --pr 323 (it is in-progress; submit must precede done)
- step: bash claude/skills/work-order/scripts/work-order.sh submit --id WO-20261016-7a8f --pr 296 (it is in-progress; submit must precede done)
- step: bash claude/skills/work-order/scripts/work-order.sh submit --id WO-20261016-f675 --pr 326 (it is in-progress; submit must precede done)
- step: bash claude/skills/work-order/scripts/work-order.sh done --id WO-20261016-3475; bash claude/skills/work-order/scripts/work-order.sh done --id WO-20261016-7a8f; bash claude/skills/work-order/scripts/work-order.sh done --id WO-20261016-f675; commit 'chore(work-orders): close 3475 7a8f f675 at merged PRs 323 296 326' with this ticket id; no Bump trailer; push, gh pr create, submit --pr <N>, done on the branch, push, leave
- tool: make:claude/workflow/Makefile:image - on main; fallback: the image fails to build: stop with ENV-MISSING podman
- tool: cmd:git, cmd:jq, cmd:gh, cmd:make, cmd:podman - fallback: missing on the host: stop with ENV-MISSING naming it; gh or GitHub down: retry 3 times, then stop with A2A-003 and its output

**Out - non-goals**

- any edit to the closed tickets' content beyond what work-order.sh submit and done write
- any file outside work-orders/: stop with DESIGN-GAP
- work-orders/INDEX.md and epic READMEs by hand or by git add; waiting on CI or merging: push, open the PR, write the result, leave

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [ ] `AC-H1` *(human)* WO-20261016-3475 is done
  - check: `bash claude/skills/work-order/scripts/work-order.sh show --id WO-20261016-3475 --json | jq -r .status` exit 0 expect /^done$/
- [ ] `AC-H2` *(human)* WO-20261016-7a8f is done
  - check: `bash claude/skills/work-order/scripts/work-order.sh show --id WO-20261016-7a8f --json | jq -r .status` exit 0 expect /^done$/
- [ ] `AC-H3` *(human)* WO-20261016-f675 is done
  - check: `bash claude/skills/work-order/scripts/work-order.sh show --id WO-20261016-f675 --json | jq -r .status` exit 0 expect /^done$/
- [ ] `AC-H4` *(human)* the merged code is green on main (TP-1)
  - check: `podman run --rm --network=none -v $PWD:/w:Z -w /w docker.io/library/python@sha256:2f17fc044b579bab302c2e8054d3a686e2cb9a83de48e70534b94cd8ebbe06a9 python3 -m unittest -v claude/tools/wiki/tests/test_intake.py` exit 0 expect /OK/
- [ ] `AC-H5` *(human)* the diff holds only work-orders files
  - check: `git diff --name-only origin/main...HEAD | grep -vE '^(work-orders/.*)$'` exit 1

## Test plan

_Test plan from claude/workflow/templates/test-plan.md, shaped by claude/workflow/schemas/test-plan.schema.json. The tester runs exactly these cases and nothing else._

**Scope under test**

the merged WK1t, WK-Dt and WK4t test plans and scripts on origin/main

**Cases**

- `TP-1`
  - intent: wiki-intake tests are green on main before 3475 closes
  - command: `podman run --rm --network=none -v $PWD:/w:Z -w /w docker.io/library/python@sha256:2f17fc044b579bab302c2e8054d3a686e2cb9a83de48e70534b94cd8ebbe06a9 python3 -m unittest -v claude/tools/wiki/tests/test_intake.py`
  - expected: exit 0; the last line is OK
- `TP-2`
  - intent: the wiki spec parses within limits before 7a8f closes
  - command: `bash scripts/spec-check.sh docs/design/wiki.spec.xml`
  - expected: exit 0
- `TP-3`
  - intent: the wiki design keeps its contents list before 7a8f closes
  - command: `bash scripts/md-contents.sh check docs/design/wiki.md`
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
