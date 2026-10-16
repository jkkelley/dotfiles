---
{
  "id": "WO-20261016-e15b",
  "slug": "a2a-deliver-delivers-one-collapsed-pointer-line-",
  "title": "a2a-deliver delivers one collapsed pointer line to an idle seat with an empty input line",
  "type": "feature",
  "status": "in-progress",
  "priority": "p2",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T05:19:48+00:00",
  "parent": "WO-20261016-916d",
  "branch": "feat/a2a-deliver-delivers-one-collapsed-pointer-line-",
  "pr": null,
  "closed": null,
  "approval": {
    "via": "override",
    "reason": "Claude seat: owner rule bars Lavish for Claude runtimes; brief BR-20261016-a2a-guard from the architect is the approval",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [
    "WO-20261016-43bb"
  ],
  "blocks": [
    "WO-20261016-9682"
  ]
}
---

# WO-20261016-e15b - a2a-deliver delivers one collapsed pointer line to an idle seat with an empty input line

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

P1

## Scope

**In**

- claude/workflow/a2a-guard/a2a-deliver.sh claude/workflow/config/monitors.json

**Out - non-goals**

- bus-native pull consumer (follow-up)

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [ ] `AC-H1` *(human)* a working seat gets nothing; an idle one gets exactly one line

## Test plan

```sh
make a2a-guard-test
```

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

- `2026-10-16` Built on feat/a2a-guard, the brief's one branch for this epic; the per-ticket branch start minted was empty and removed.

## Outcome

_Written by `work-order done`. Empty until then._
