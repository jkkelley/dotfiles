---
{
  "id": "WO-20261016-e9d4",
  "slug": "line-build-l0-a2a-guard-orders-never-typed-into-",
  "title": "Line build L0 - a2a-guard: orders never typed into busy panes",
  "type": "chore",
  "status": "done",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T05:38:39+00:00",
  "parent": "WO-20261016-0272",
  "branch": "feat/line-build-l0-a2a-guard-orders-never-typed-into-",
  "pr": 175,
  "closed": "2026-10-16",
  "approval": {
    "via": "override",
    "reason": "Owner-ordered line build order, ORD-0537 O4",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [
    "WO-20261016-783f"
  ],
  "blocks": [
    "WO-20261016-2e9f"
  ]
}
---

# WO-20261016-e9d4 - Line build L0 - a2a-guard: orders never typed into busy panes

## Contents

- Problem
- Scope
- Degrees of freedom
- Acceptance criteria
- Test plan
- Assumptions
- Open questions
- Notes
- Outcome

## Problem

Node a2a of the inbox-triage line build order, layer L0. State: PR 175, seat up. Brief: /home/luna/.local/state/zenith/inbox-triage/20261015/a2a-guard-brief.json.

## Scope

**In**

- Deliver node a2a per its brief

**Out - non-goals**

- Any other DAG node

## Degrees of freedom

- [free] none

## Acceptance criteria

- [x] `AC-H1` *(human)* Node a2a merged on main with CI green
  - observed `2026-10-16` gh pr view 175: state MERGED, merge 6aea386fe3d8, checks SUCCESS/SKIPPED; main log 6aea386 feat(workflow): a2a-guard

## Test plan

_none recorded - Rule 14 says this runs in a container_

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
