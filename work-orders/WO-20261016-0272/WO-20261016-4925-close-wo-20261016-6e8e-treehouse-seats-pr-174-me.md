---
{
  "id": "WO-20261016-4925",
  "slug": "close-wo-20261016-6e8e-treehouse-seats-pr-174-me",
  "title": "Close WO-20261016-6e8e (treehouse seats, PR 174 merged): start, submit, evidence, done",
  "type": "chore",
  "status": "in-progress",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T09:30:54+00:00",
  "parent": "WO-20261016-0272",
  "branch": "feat/close-wo-20261016-6e8e-treehouse-seats-pr-174-me",
  "pr": null,
  "closed": null,
  "approval": {
    "via": "override",
    "reason": "infra-design10 cut for ORD-0830 RR-orch-14 and ORD-0921; design approvals ruled done, ORD-0550 O4",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [],
  "blocks": [],
  "ac_checks": [
    {
      "index": 1,
      "command": "bash claude/skills/work-order/scripts/work-order.sh show --id WO-20261016-6e8e --json | jq -r .status",
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
  "provides": []
}
---

# WO-20261016-4925 - Close WO-20261016-6e8e (treehouse seats, PR 174 merged): start, submit, evidence, done

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

WO-20261016-6e8e - Line build L0 - treehouse seats: seats lease their worktree - shipped in PR 174 (merged, 7fc65c8) but still reads ready, so work-order.sh next lists merged work and WO-20261016-4b6c waits on it. It has no ac_checks and one human criterion, so plain done closes it once that is evidenced.

## Owner words

> get this code merged the fuck in, dead code is shit, it sitting under agents is stupid (Design principles 101 item 21)

## Context

Order ORD-0830 RR-orch-14 (brief BR-20261016-infra-design10, item STALE-READY); infra-design9 result l0_l1 found it.

## Scope

**In**

- touches: none outside work-orders: the 6e8e ticket file moves to work-orders/archive/2026/ by work-order.sh done only
- touches (generated, written only by work-order.sh start/submit/evidence/done, never by hand or git add): this ticket file and its archive path; work-orders/INDEX.md and the parent epic README.md are ignored generated views
- step: branch from origin/main in your own worktree; bash claude/skills/work-order/scripts/work-order.sh start --id WO-20261016-6e8e; then submit --id WO-20261016-6e8e --pr 174
- step: run TP-1; evidence --id WO-20261016-6e8e --index 1 --observed with its output verbatim; any conclusion other than SUCCESS or SKIPPED: stop with DESIGN-GAP, never tick
- step: bash claude/skills/work-order/scripts/work-order.sh done --id WO-20261016-6e8e; commit chore(work-orders): close WO-20261016-6e8e at PR 174 with this ticket id; no Bump trailer
- tool: cmd:git, cmd:jq, cmd:gh, cmd:make, cmd:podman - fallback: missing on the host: stop with ENV-MISSING naming it; gh or GitHub down: retry 3 times, then stop with A2A-003 and its output

**Out - non-goals**

- any edit to the closed ticket content beyond what work-order.sh start, submit, evidence and done write
- work-orders/INDEX.md and epic READMEs by hand or by git add; waiting on CI or merging: push, open the PR, write the result, leave
- any file not named under In: stop with DESIGN-GAP

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [x] `AC-H1` *(human)* WO-20261016-6e8e is done and archived
  - observed `2026-10-16` done
  - check: `bash claude/skills/work-order/scripts/work-order.sh show --id WO-20261016-6e8e --json | jq -r .status` exit 0 expect /^done$/
- [x] `AC-H2` *(human)* the diff holds only work-orders files
  - observed `2026-10-16` only work-orders files; grep exit 1
  - check: `git diff --name-only origin/main...HEAD | grep -vE '^(work-orders/.*)$'` exit 1

## Test plan

{"scope":"close-out of WO-20261016-6e8e (PR 174 merged)","cases":[ {"id":"TP-1","intent":"AC-H1 of 6e8e: node th merged on main with CI green","command":"gh pr view 174 --json state,statusCheckRollup -q .state+\" \"+([.statusCheckRollup[].conclusion]|unique|join(\",\"))","expected":"exit 0; MERGED followed only by SUCCESS and SKIPPED"}, {"id":"TP-2","intent":"the ticket is archived as done","command":"bash claude/skills/work-order/scripts/work-order.sh show --id WO-20261016-6e8e --json","expected":"exit 0; .status is done"}], "isolation":{"runtime":"podman","image":"docker.io/library/debian@sha256:328d16499860ae6cb9b345e2e4cebca08c2a36e4f7278482c7bd1f39d71e5bfd"}, "out_of_scope":["re-running the treehouse lease suite: CI ran it on PR 174"]}

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
