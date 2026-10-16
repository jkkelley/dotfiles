---
{
  "id": "WO-20261016-783f",
  "slug": "line-build-l0-bus-line-events-on-a-nats-jetstrea",
  "title": "Line build L0 - bus: line events on a NATS JetStream bus",
  "type": "chore",
  "status": "ready",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T05:38:36+00:00",
  "parent": "WO-20261016-0272",
  "branch": null,
  "pr": null,
  "closed": null,
  "approval": {
    "via": "override",
    "reason": "Owner-ordered line build order, ORD-0537 O4",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [],
  "blocks": [
    "WO-20261016-e9d4",
    "WO-20261016-af17"
  ]
}
---

# WO-20261016-783f - Line build L0 - bus: line events on a NATS JetStream bus

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

Node bus of the inbox-triage line build order, layer L0. State: PR 171 merged. Brief: /home/luna/.local/state/zenith/inbox-triage/20261015/herdr-bus-brief.json.

## Scope

**In**

- Deliver node bus per its brief

**Out - non-goals**

- Any other DAG node

## Degrees of freedom

- [free] none

## Acceptance criteria

- [ ] `AC-H1` *(human)* Node bus merged on main with CI green

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
