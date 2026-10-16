---
{
  "id": "WO-20261016-a29e",
  "slug": "pr-flow-merge-sh-ported-from-coq-with-its-three-",
  "title": "pr-flow merge.sh ported from coq with its three test files (T5)",
  "type": "feature",
  "status": "done",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T05:39:10+00:00",
  "parent": "WO-20261016-ebe4",
  "branch": "feat/pr-flow-merge-sh-ported-from-coq-with-its-three-",
  "pr": 190,
  "closed": "2026-10-16",
  "approval": {
    "via": "override",
    "reason": "Claude seat; design PR 169 merged under ORD-0550 is the approval",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [
    "WO-20261016-e6f1",
    "WO-20261016-984d"
  ],
  "blocks": [
    "WO-20261016-83fb",
    "WO-20261016-1708"
  ]
}
---

# WO-20261016-a29e - pr-flow merge.sh ported from coq with its three test files (T5)

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

Build ticket from claude/workflow/docs/pr-process/pr-process.md section 13; files: claude/workflow/pr-flow/bin/merge.sh claude/workflow/pr-flow/tests/merge.test.sh claude/workflow/pr-flow/tests/merge-hold.test.sh claude/workflow/pr-flow/tests/merge-cleanup.test.sh

## Scope

**In**

- claude/workflow/pr-flow/bin/merge.sh claude/workflow/pr-flow/tests/merge.test.sh claude/workflow/pr-flow/tests/merge-hold.test.sh claude/workflow/pr-flow/tests/merge-cleanup.test.sh

**Out - non-goals**

- any file not listed in Scope
- a review gate or gh pr merge --auto

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [x] `AC-H1` *(human)* the named test cases pass in podman
  - observed `2026-10-16` merge.test.sh 27/27, merge-hold.test.sh 9/9, merge-cleanup.test.sh 10/10 in localhost/dotfiles-workflow-test:1 --network=none
- [x] `AC-H2` *(human)* files touched equal the Scope list
  - observed `2026-10-16` files: pr-flow/bin/merge.sh, tests/merge.test.sh, merge-hold.test.sh, merge-cleanup.test.sh, plus tests/lib-merge.sh (shared fixture)

## Test plan

```sh
make -C claude/workflow pr-flow-test CASES='merge merge-hold merge-cleanup'
```

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
