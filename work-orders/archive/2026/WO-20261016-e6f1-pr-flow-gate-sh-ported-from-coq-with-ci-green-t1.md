---
{
  "id": "WO-20261016-e6f1",
  "slug": "pr-flow-gate-sh-ported-from-coq-with-ci-green-t1",
  "title": "pr-flow gate.sh ported from coq with ci-green (T1)",
  "type": "feature",
  "status": "done",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T05:39:04+00:00",
  "parent": "WO-20261016-ebe4",
  "branch": "feat/pr-flow-gate-sh-ported-from-coq-with-ci-green-t1",
  "pr": 187,
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
    "WO-20261016-a29e"
  ]
}
---

# WO-20261016-e6f1 - pr-flow gate.sh ported from coq with ci-green (T1)

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

Build ticket from claude/workflow/docs/pr-process/pr-process.md section 13; files: claude/workflow/pr-flow/bin/gate.sh claude/workflow/pr-flow/tests/gate.test.sh

## Scope

**In**

- claude/workflow/pr-flow/bin/gate.sh claude/workflow/pr-flow/tests/gate.test.sh

**Out - non-goals**

- any file not listed in Scope
- a review gate or gh pr merge --auto

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [x] `AC-H1` *(human)* the named test cases pass in podman
  - observed `2026-10-16` gate.test.sh pass=26 fail=0 in localhost/dotfiles-workflow-test:1 --network=none; shellcheck clean
- [x] `AC-H2` *(human)* files touched equal the Scope list
  - observed `2026-10-16` files: claude/workflow/pr-flow/bin/gate.sh, claude/workflow/pr-flow/tests/gate.test.sh

## Test plan

```sh
make -C claude/workflow pr-flow-test CASES=gate
```

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
