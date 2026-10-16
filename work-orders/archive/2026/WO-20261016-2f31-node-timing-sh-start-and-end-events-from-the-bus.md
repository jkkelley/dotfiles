---
{
  "id": "WO-20261016-2f31",
  "slug": "node-timing-sh-start-and-end-events-from-the-bus",
  "title": "node-timing.sh: start and end events from the bus to a TIMING KV bucket, SLOW and a bottleneck work order over budget",
  "type": "feature",
  "status": "done",
  "priority": "p2",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T05:20:09+00:00",
  "parent": "WO-20261016-3570",
  "branch": "feat/node-timing-sh-start-and-end-events-from-the-bus",
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

# WO-20261016-2f31 - node-timing.sh: start and end events from the bus to a TIMING KV bucket, SLOW and a bottleneck work order over budget

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

Durations are not recorded anywhere.

## Scope

**In**

- claude/workflow/timing/node-timing.sh

**Out - non-goals**

- producers' own files

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [x] `AC-H1` *(human)* durations written to KV bucket TIMING
  - observed `2026-10-16` dev slow/fast: $KV.TIMING.t.make.build.<run> written; UAT KV_TIMING keys for timing-uat written then purged by cleanup (/home/luna/.local/state/zenith/log/2026/10/20261016-052507-timing-uat-timing-uat.log)
- [x] `AC-H2` *(human)* over budget -> SLOW on the bus and a work order
  - observed `2026-10-16` dev slow: line.t.timing.SLOW with budget and duration plus 1 work order, seat span 3600s over 2700s SLOW; UAT AC7 SLOW uat-slow and 1 work order (/home/luna/.local/state/zenith/log/2026/10/20261016-052507-timing-uat-timing-uat.log)

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
