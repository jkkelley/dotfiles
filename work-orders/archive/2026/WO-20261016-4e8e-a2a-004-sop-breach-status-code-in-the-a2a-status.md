---
{
  "id": "WO-20261016-4e8e",
  "slug": "a2a-004-sop-breach-status-code-in-the-a2a-status",
  "title": "A2A-004 SOP-breach status code in the a2a status code map",
  "type": "chore",
  "status": "done",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T04:44:46+00:00",
  "parent": null,
  "branch": "feat/a2a-004-sop-breach-status-code-in-the-a2a-status",
  "pr": 155,
  "closed": "2026-10-16",
  "approval": {
    "via": "override",
    "reason": "Claude seat: lavish prohibited for Claude runtime; brief BR-20261016-sop-code is the approval",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [],
  "blocks": []
}
---

# WO-20261016-4e8e - A2A-004 SOP-breach status code in the a2a status code map

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

Design principles 101 item 31 makes an error raised without repro or screenshot an SOP breach, but the a2a status code map has no code for it

## Scope

**In**

- one A2A-004 row in claude/workflow/templates/a2a/README.md
- schema description strings that list codes

**Out - non-goals**

- changing the status_code pattern
- orchestrator tooling that files the gap

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [x] `AC-H1` *(human)* A2A-004 row exists in claude/workflow/templates/a2a/README.md Status codes table
  - observed `2026-10-16` claude/workflow/templates/a2a/README.md:34 holds the A2A-004 row
- [x] `AC-H2` *(human)* PR checks green
  - observed `2026-10-16` gh pr checks 155: all pass or skipping, exit 0

## Test plan

```sh
make -C claude/workflow -f a2a.mk a2a-test
```

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

- `2026-10-16` branch is docs/a2a-sop-breach-code per brief BR-20261016-sop-code; start's feat/ branch was renamed to it

## Outcome

_Written by `work-order done`. Empty until then._
