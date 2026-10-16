---
{
  "id": "WO-20261016-1708",
  "slug": "merge-train-becomes-a-thin-wrapper-over-pr-flow-",
  "title": "merge-train becomes a thin wrapper over pr-flow merge.sh (T8)",
  "type": "feature",
  "status": "ready",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T05:39:13+00:00",
  "parent": "WO-20261016-ebe4",
  "branch": null,
  "pr": null,
  "closed": null,
  "approval": {
    "via": "override",
    "reason": "Claude seat; design PR 169 merged under ORD-0550 is the approval",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [
    "WO-20261016-a29e"
  ],
  "blocks": [
    "WO-20261016-5630"
  ]
}
---

# WO-20261016-1708 - merge-train becomes a thin wrapper over pr-flow merge.sh (T8)

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

Build ticket from claude/workflow/docs/pr-process/pr-process.md section 13; files: tools/merge-train/merge-train.sh tools/merge-train/tests/test_merge_train.sh

## Scope

**In**

- tools/merge-train/merge-train.sh tools/merge-train/tests/test_merge_train.sh

**Out - non-goals**

- any file not listed in Scope
- a review gate or gh pr merge --auto

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [ ] `AC-H1` *(human)* the named test cases pass in podman
- [ ] `AC-H2` *(human)* files touched equal the Scope list

## Test plan

```sh
make -C tools/merge-train test
```

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
