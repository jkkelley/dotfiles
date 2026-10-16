---
{
  "id": "WO-20261016-0272",
  "slug": "inbox-triage-line-build-order-dag-of-line-nodes",
  "title": "Inbox-triage line build order - DAG of line nodes",
  "type": "chore",
  "status": "draft",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T05:38:25+00:00",
  "parent": null,
  "branch": null,
  "pr": null,
  "closed": null,
  "approval": null,
  "evidence": null,
  "surfaces": [],
  "depends_on": [],
  "blocks": [],
  "labels": [
    "line:inbox-triage"
  ]
}
---

# WO-20261016-0272 - Inbox-triage line build order - DAG of line nodes

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

The line build order lives in a report, not in tickets, so no node knows its inputs and next cannot sequence the work.

## Scope

**In**

- One child per DAG node
- One depends-on per mermaid edge

**Out - non-goals**

- Building any node
- Adding edges beyond the mermaid DAG

## Degrees of freedom

- [free] none

## Acceptance criteria

- [ ] `AC-H1` *(human)* Epic and one child per DAG node exist with every mermaid edge as depends_on

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
