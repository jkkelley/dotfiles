---
{
  "id": "WO-20261016-7ce0",
  "slug": "stuck-audit-sh-every-stuck-node-duration-and-evi",
  "title": "stuck-audit.sh: every stuck node, duration and evidence path, from the LINE stream",
  "type": "feature",
  "status": "ready",
  "priority": "p2",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T04:51:56+00:00",
  "parent": "WO-20261016-3570",
  "branch": null,
  "pr": null,
  "closed": null,
  "approval": {
    "via": "override",
    "reason": "Claude seat: lavish is prohibited outside firstmate (~/AGENTS.md owner interaction surface); brief BR-20261016-stuck-watch from the architect is the approval",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [
    "WO-20261016-230f"
  ],
  "blocks": [
    "WO-20261016-218b",
    "WO-20261016-2c98"
  ]
}
---

# WO-20261016-7ce0 - stuck-audit.sh: every stuck node, duration and evidence path, from the LINE stream

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

No morning view of what stalled overnight.

## Scope

**In**

- claude/workflow/stuck-watch/stuck-audit.sh

**Out - non-goals**

- writing to the bus

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [ ] `AC-H1` *(human)* make stuck-audit LINE= prints seat, code, first, last, duration, evidence path

## Test plan

```sh
make -C claude/workflow stuck-watch-test
```

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
