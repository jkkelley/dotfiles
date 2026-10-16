---
{
  "id": "WO-20261016-92a5",
  "slug": "timed-run-sh-start-end-and-timeout-of-any-step-o",
  "title": "timed-run.sh: start, end and timeout of any step on the bus, timeout enforced, 3 retries, SLOW and TIMEOUT coded",
  "type": "feature",
  "status": "ready",
  "priority": "p2",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T05:20:07+00:00",
  "parent": "WO-20261016-3570",
  "branch": null,
  "pr": null,
  "closed": null,
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

# WO-20261016-92a5 - timed-run.sh: start, end and timeout of any step on the bus, timeout enforced, 3 retries, SLOW and TIMEOUT coded

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

Owner item 37: every node, seat, job, CI run and merge emits start and end; over budget is SLOW. No wrapper does this.

## Scope

**In**

- claude/workflow/bin/timed-run.sh
- claude/workflow/config/time-budgets.json
- claude/workflow/timing/lib.sh

**Out - non-goals**

- routing existing Make targets through it (owner work orders)

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [ ] `AC-H1` *(human)* start and end events on line.<line>.event.node.*
- [ ] `AC-H2` *(human)* a step past TIMEOUT is stopped, retried 3 times, coded TIMEOUT, work order filed
- [ ] `AC-H3` *(human)* over budget is coded SLOW

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
