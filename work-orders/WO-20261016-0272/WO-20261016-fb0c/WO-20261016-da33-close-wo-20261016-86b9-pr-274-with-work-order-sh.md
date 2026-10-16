---
{
  "id": "WO-20261016-da33",
  "slug": "close-wo-20261016-86b9-pr-274-with-work-order-sh",
  "title": "Close WO-20261016-86b9 (PR 274) with work-order.sh done --at merge once PR 274 merges",
  "type": "chore",
  "status": "ready",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T09:31:01+00:00",
  "parent": "WO-20261016-fb0c",
  "branch": null,
  "pr": null,
  "closed": null,
  "approval": {
    "via": "override",
    "reason": "infra-design10 cut for ORD-0830 RR-orch-14 and ORD-0921; design approvals ruled done, ORD-0550 O4",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [
    "WO-20261016-4710"
  ],
  "blocks": [],
  "ac_checks": [
    {
      "index": 1,
      "command": "bash claude/skills/work-order/scripts/work-order.sh show --id WO-20261016-86b9 --json | jq -r .status",
      "exit": 0,
      "expect": "^done$"
    },
    {
      "index": 2,
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

# WO-20261016-da33 - Close WO-20261016-86b9 (PR 274) with work-order.sh done --at merge once PR 274 merges

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

WO-20261016-86b9 - work-order start accepts a test plan on a locally built image by tag (RR-orch-18) - is in-review on PR 274 (CI green, no auto-merge set at 2026-10-16T09:4xZ). Its check 4 is ^(work-orders/|...)$: the bare work-orders/ matches no ticket file, so on the PR branch the 86b9 file itself is printed and done refuses. amend is draft-only (work-order.sh cmd_amend wo_require_status draft), so the check cannot be corrected on an in-review ticket; at the merge commit the diff against origin/main is empty, so done --at merge (WO-20261016-4710) passes it.

## Owner words

> get this code merged the fuck in, dead code is shit, it sitting under agents is stupid (Design principles 101 item 21)

## Context

Order ORD-0921 E4 (brief BR-20261016-infra-design10). Same F35 scope-regex defect as WO-20261016-75b7, closed the same way by WO-20261016-4575. The cut-time guard is WO-20261016-25f7.

## Scope

**In**

- touches: none outside work-orders: the 86b9 ticket file moves to work-orders/archive/2026/ by work-order.sh done only
- touches (generated, written only by work-order.sh start/submit/evidence/done, never by hand or git add): this ticket file and its archive path; work-orders/INDEX.md and the parent epic README.md are ignored generated views
- step: gh pr view 274 --json state -q .state must print MERGED, else stop with DESIGN-GAP naming PR 274; branch from origin/main in your own worktree after WO-20261016-4710 merged
- step: bash claude/skills/work-order/scripts/work-order.sh done --id WO-20261016-86b9 --at merge; commit chore(work-orders): close WO-20261016-86b9 at the PR 274 merge commit with this ticket id; no Bump trailer
- tool: script:claude/skills/work-order/scripts/work-order.sh done --at merge (WO-20261016-4710) - not yet on main, this ticket depends on it; fallback: missing on main: stop with DESIGN-GAP naming it
- tool: cmd:git, cmd:jq, cmd:gh, cmd:make, cmd:podman - fallback: missing on the host: stop with ENV-MISSING naming it; gh or GitHub down: retry 3 times, then stop with A2A-003 and its output

**Out - non-goals**

- any edit to the closed ticket content beyond what work-order.sh start, submit, evidence and done write
- any file of PR 274
- work-orders/INDEX.md and epic READMEs by hand or by git add; waiting on CI or merging: push, open the PR, write the result, leave
- any file not named under In: stop with DESIGN-GAP

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [ ] `AC-H1` *(human)* WO-20261016-86b9 is done and archived
  - check: `bash claude/skills/work-order/scripts/work-order.sh show --id WO-20261016-86b9 --json | jq -r .status` exit 0 expect /^done$/
- [ ] `AC-H2` *(human)* the diff holds only work-orders files
  - check: `git diff --name-only origin/main...HEAD | grep -vE '^(work-orders/.*)$'` exit 1

## Test plan

{"scope":"close-out of WO-20261016-86b9 with done --at merge","cases":[ {"id":"TP-1","intent":"86b9 check 4 anchors work-orders/ with $, so on the PR branch its own ticket file fails it; at the merge commit the diff against origin/main is empty and every check passes","command":"bash claude/skills/work-order/scripts/work-order.sh done --id WO-20261016-86b9 --at merge","expected":"exit 0; prints WO-20261016-86b9 -> done"}, {"id":"TP-2","intent":"the ticket is archived as done","command":"bash claude/skills/work-order/scripts/work-order.sh show --id WO-20261016-86b9 --json","expected":"exit 0; .status is done"}], "isolation":{"runtime":"podman","image":"docker.io/library/debian@sha256:328d16499860ae6cb9b345e2e4cebca08c2a36e4f7278482c7bd1f39d71e5bfd"}, "out_of_scope":["the checks of WO-20261016-86b9 themselves: done --at merge runs them"]}

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
