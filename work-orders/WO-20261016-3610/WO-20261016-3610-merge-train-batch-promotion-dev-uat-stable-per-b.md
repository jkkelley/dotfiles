---
{
  "id": "WO-20261016-3610",
  "slug": "merge-train-batch-promotion-dev-uat-stable-per-b",
  "title": "merge-train batch promotion: dev, UAT, stable per batch on a cadence",
  "type": "feature",
  "status": "draft",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T04:58:39+00:00",
  "parent": null,
  "branch": null,
  "pr": null,
  "closed": null,
  "approval": null,
  "evidence": null,
  "surfaces": [],
  "depends_on": [],
  "blocks": []
}
---

# WO-20261016-3610 - merge-train batch promotion: dev, UAT, stable per batch on a cadence

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

merge-train merges every green PR one at a time on CI state alone. Design principles 101 items 34 and 38 require batches by DAG layer and area, promoted dev then UAT then stable together on a cadence, with no merge before dev and UAT evidence. Order MSG-20261016-0545-rule38 O2.

## Scope

**In**

_none_

**Out - non-goals**

- changing CI workflows

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [ ] `AC-H1` *(human)* the build and test children are done

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
