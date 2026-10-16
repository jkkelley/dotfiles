---
{
  "id": "WO-20261016-af17",
  "slug": "line-build-l0-stuck-watch-stuck-watch-timing-and",
  "title": "Line build L0 - stuck-watch: stuck-watch, timing and deadman",
  "type": "chore",
  "status": "ready",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T05:38:44+00:00",
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
  "depends_on": [
    "WO-20261016-4b6c",
    "WO-20261016-783f"
  ],
  "blocks": [
    "WO-20261016-ab87"
  ],
  "labels": [
    "line:inbox-triage"
  ]
}
---

# WO-20261016-af17 - Line build L0 - stuck-watch: stuck-watch, timing and deadman

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

Node sw of the inbox-triage line build order, layer L0. State: PR 170. Brief: /home/luna/.local/state/zenith/inbox-triage/20261015/stuck-watch-brief.v3.json.

## Scope

**In**

- Deliver node sw per its brief

**Out - non-goals**

- Any other DAG node

## Degrees of freedom

- [free] none

## Acceptance criteria

- [ ] `AC-H1` *(human)* Node sw merged on main with CI green

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
