---
{
  "id": "WO-20261016-db0f",
  "slug": "line-timing-sh-and-timing-mk-make-line-timing-li",
  "title": "line-timing.sh and timing.mk: make line-timing LINE= SINCE= report of durations vs budgets and top 5 bottlenecks to the artifact store",
  "type": "feature",
  "status": "done",
  "priority": "p2",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T05:20:12+00:00",
  "parent": "WO-20261016-3570",
  "branch": "feat/line-timing-sh-and-timing-mk-make-line-timing-li",
  "pr": 170,
  "closed": "2026-10-16",
  "approval": {
    "via": "override",
    "reason": "Claude seat: lavish prohibited outside firstmate; brief BR-20261016-stuck-watch v2 is the approval",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [],
  "blocks": []
}
---

# WO-20261016-db0f - line-timing.sh and timing.mk: make line-timing LINE= SINCE= report of durations vs budgets and top 5 bottlenecks to the artifact store

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

No morning view of where the time went.

## Scope

**In**

- claude/workflow/timing/line-timing.sh
- claude/workflow/timing/timing.mk
- claude/workflow/Makefile (one include)

**Out - non-goals**

- writing to the bus

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [x] `AC-H1` *(human)* make line-timing prints durations and top 5 bottlenecks and the report artifact path
  - observed `2026-10-16` dev report: top 5 sorted by overrun, durations vs budgets, artifact written; UAT AC8 make line-timing LINE=timing-uat -> /home/luna/.local/state/zenith/report/2026/10/20261016-052528-line-timing-timing-uat.md

## Test plan

```sh
make -C claude/workflow timing-test
```

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
