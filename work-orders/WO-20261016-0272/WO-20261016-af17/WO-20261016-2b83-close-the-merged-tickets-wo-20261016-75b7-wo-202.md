---
{
  "id": "WO-20261016-2b83",
  "slug": "close-the-merged-tickets-wo-20261016-75b7-wo-202",
  "title": "Close the merged tickets WO-20261016-75b7, WO-20261016-6edb and WO-20261016-3ac1 (PRs 220, 327, 293)",
  "type": "chore",
  "status": "ready",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T12:35:37+00:00",
  "parent": "WO-20261016-af17",
  "branch": null,
  "pr": null,
  "closed": null,
  "approval": {
    "via": "override",
    "reason": "infra-design22 cut for BR-20261016-infra-design22; design approvals ruled done, ORD-0550 O4",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [],
  "blocks": [],
  "ac_checks": [
    {
      "index": 1,
      "command": "bash claude/skills/work-order/scripts/work-order.sh show --id WO-20261016-75b7 --json | jq -r .status",
      "exit": 0,
      "expect": "^done$"
    },
    {
      "index": 2,
      "command": "bash claude/skills/work-order/scripts/work-order.sh show --id WO-20261016-6edb --json | jq -r .status",
      "exit": 0,
      "expect": "^done$"
    },
    {
      "index": 3,
      "command": "bash claude/skills/work-order/scripts/work-order.sh show --id WO-20261016-3ac1 --json | jq -r .status",
      "exit": 0,
      "expect": "^done$"
    },
    {
      "index": 4,
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

# WO-20261016-2b83 - Close the merged tickets WO-20261016-75b7, WO-20261016-6edb and WO-20261016-3ac1 (PRs 220, 327, 293)

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

WO-20261016-75b7 (PR 220, in-review), WO-20261016-6edb (PR 327, in-progress) and WO-20261016-3ac1 (PR 293, in-progress) merged but stay open, found by work-order.sh stale-merged (READY-MERGED) and covered by no close-out leaf; open merged tickets block dependents and inflate next --line.

## Owner words

> ORD-1140 S3 buffer: cut ready dotfiles leaves to keep the ready buffer at 6 (L0 first per ORD-0537); declare disjoint touches (orchestrator brief BR-20261016-infra-design22). get this code merged the fuck in, dead code is shit, it sitting under agents is stupid (Design principles 101 item 21)

> make sure you clean up too (Design principles 101 item 11)

## Context

Found by infra-design22 inventory on main 575b196: stale-merged READY-MERGED tickets minus every open 'Close the' leaf leaves 75b7, 6edb, 3ac1, 2d5b, 86b9; 2d5b and 86b9 are infra-design8 tickets the brief forbids touching, so they are left. 75b7 has every criterion [x] and pr 220, so done alone closes it. 6edb has pr null, status in-progress, AC-H1 and AC-H2 [x], AC-H3 (diff holds only work-orders) unchecked; 3ac1 has pr null, status in-progress, AC-H1 (3570 done) and AC-H2 (diff) unchecked. On this ticket's branch the diff is work-orders only and 3570 is archived done, so check ticks them by script. Same close-out shape as WO-20261016-f610.

## Scope

**In**

- touches: none outside work-orders: the WO-20261016-75b7, WO-20261016-6edb, WO-20261016-3ac1 ticket files move to work-orders/archive/2026/ by work-order.sh submit, check and done only
- touches (generated, written only by work-order.sh start/submit/check/done, never by hand or git add): this ticket file and its archive path; work-orders/INDEX.md and the parent epic README.md are ignored generated views
- step: branch from origin/main in your own git worktree (fallback: treehouse fails, use git worktree add), never the ~/dotfiles primary clone; bash claude/skills/work-order/scripts/work-order.sh start --id <this ticket>
- step: run every TP case in order; any red case: stop with DESIGN-GAP and its output, never close that ticket
- step: bash claude/skills/work-order/scripts/work-order.sh done --id WO-20261016-75b7
- step: bash claude/skills/work-order/scripts/work-order.sh submit --id WO-20261016-6edb --pr 327; bash claude/skills/work-order/scripts/work-order.sh check --id WO-20261016-6edb --index 3; bash claude/skills/work-order/scripts/work-order.sh done --id WO-20261016-6edb
- step: bash claude/skills/work-order/scripts/work-order.sh submit --id WO-20261016-3ac1 --pr 293; bash claude/skills/work-order/scripts/work-order.sh check --id WO-20261016-3ac1; bash claude/skills/work-order/scripts/work-order.sh done --id WO-20261016-3ac1
- step: commit 'chore(work-orders): close 75b7 6edb 3ac1 at merged PRs 220 327 293' with this ticket id; no Bump trailer; push, gh pr create, submit --pr <N>, check and done on the branch, push, leave
- tool: cmd:git, cmd:jq, cmd:gh - fallback: missing on the host: stop with ENV-MISSING naming it; gh or GitHub down: retry 3 times, then stop with A2A-003 and its output
- tool: verb:work-order.sh submit/check/done - on main; fallback: a verb refuses: stop with DESIGN-GAP and its output, never edit the ticket by hand

**Out - non-goals**

- any edit to the closed tickets' content beyond what work-order.sh submit, check and done write
- WO-20261016-2d5b and WO-20261016-86b9: infra-design8 tickets, not touched
- any file outside work-orders/: stop with DESIGN-GAP
- work-orders/INDEX.md and epic READMEs by hand or by git add; waiting on CI or merging: push, open the PR, write the result, leave

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [ ] `AC-H1` *(human)* WO-20261016-75b7 is done
  - check: `bash claude/skills/work-order/scripts/work-order.sh show --id WO-20261016-75b7 --json | jq -r .status` exit 0 expect /^done$/
- [ ] `AC-H2` *(human)* WO-20261016-6edb is done
  - check: `bash claude/skills/work-order/scripts/work-order.sh show --id WO-20261016-6edb --json | jq -r .status` exit 0 expect /^done$/
- [ ] `AC-H3` *(human)* WO-20261016-3ac1 is done
  - check: `bash claude/skills/work-order/scripts/work-order.sh show --id WO-20261016-3ac1 --json | jq -r .status` exit 0 expect /^done$/
- [ ] `AC-H4` *(human)* the diff holds only work-orders files
  - check: `git diff --name-only origin/main...HEAD | grep -vE '^(work-orders/.*)$'` exit 1

## Test plan

_Test plan from claude/workflow/templates/test-plan.md, shaped by claude/workflow/schemas/test-plan.schema.json. The tester runs exactly these cases and nothing else._

**Scope under test**

the merged work of WO-20261016-75b7 (sharded CI), WO-20261016-6edb (wiki-review test) and WO-20261016-3ac1 (stuck-watch close) on origin/main

**Cases**

- `TP-1`
  - intent: closing the CI shard ticket while its sharded matrix is gone from main records a false done
  - command: `grep -c matrix .github/workflows/workflow-suite.yml`
  - expected: exit 0 and a count of 1 or more
- `TP-2`
  - intent: closing the wiki-review test ticket while its test file is gone from main records a false done
  - command: `test -f claude/tools/wiki/tests/test_review.py`
  - expected: exit 0
- `TP-3`
  - intent: 3ac1 closes the close-out of WO-20261016-3570; if 3570 is not done, 3ac1 would record a false done
  - command: `bash claude/skills/work-order/scripts/work-order.sh show --id WO-20261016-3570 --json | jq -r .status`
  - expected: exit 0 and done

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
