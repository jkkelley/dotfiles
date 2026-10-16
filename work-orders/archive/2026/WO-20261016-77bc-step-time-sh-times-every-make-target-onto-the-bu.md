---
{
  "id": "WO-20261016-77bc",
  "slug": "step-time-sh-times-every-make-target-onto-the-bu",
  "title": "step-time.sh times every Make target onto the bus (T3)",
  "type": "feature",
  "status": "done",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T05:39:02+00:00",
  "parent": "WO-20261016-ebe4",
  "branch": "feat/step-time-sh-times-every-make-target-onto-the-bu",
  "pr": 186,
  "closed": "2026-10-16",
  "approval": {
    "via": "override",
    "reason": "Claude seat; design PR 169 merged under ORD-0550 is the approval",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [],
  "blocks": [
    "WO-20261016-83fb"
  ]
}
---

# WO-20261016-77bc - step-time.sh times every Make target onto the bus (T3)

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

Build ticket from claude/workflow/docs/pr-process/pr-process.md section 13; files: claude/workflow/bin/step-time.sh claude/workflow/tests/unit/test_step_time.sh

## Scope

**In**

- claude/workflow/bin/step-time.sh claude/workflow/tests/unit/test_step_time.sh

**Out - non-goals**

- any file not listed in Scope
- a review gate or gh pr merge --auto

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [x] `AC-H1` *(human)* the named test cases pass in podman
  - observed `2026-10-16` make -C claude/workflow step-time: pass=13 fail=0, podman --network=none
- [x] `AC-H2` *(human)* files touched equal the Scope list
  - observed `2026-10-16` files: claude/workflow/bin/step-time.sh, tests/unit/test_step_time.sh, plus one Makefile target so CI runs it

## Test plan

```sh
bash claude/workflow/tests/unit/test_step_time.sh in the workflow test image
```

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
