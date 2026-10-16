---
{
  "id": "WO-20261016-2aef",
  "slug": "a2a-lint-fails-a-raw-herdr-pane-send-text-outsid",
  "title": "a2a-lint fails a raw herdr pane send-text outside a2a-guard, run in CI",
  "type": "feature",
  "status": "ready",
  "priority": "p2",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T05:19:49+00:00",
  "parent": "WO-20261016-916d",
  "branch": null,
  "pr": null,
  "closed": null,
  "approval": {
    "via": "override",
    "reason": "Claude seat: owner rule bars Lavish for Claude runtimes; brief BR-20261016-a2a-guard from the architect is the approval",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [],
  "blocks": [
    "WO-20261016-9682"
  ]
}
---

# WO-20261016-2aef - a2a-lint fails a raw herdr pane send-text outside a2a-guard, run in CI

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

P1 recurs whenever a script types into a pane directly

## Scope

**In**

- claude/workflow/a2a-guard/a2a-lint.sh .github/workflows/a2a-lint.yml

**Out - non-goals**

- herdr agent prompt callers (follow-up)

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [ ] `AC-H1` *(human)* lint exits 1 on a raw send-text

## Test plan

```sh
make a2a-lint
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
