---
{
  "id": "WO-20261016-75d9",
  "slug": "inbox-sweep-b19-spec-lint-keeps-every-spec-at-10",
  "title": "Inbox sweep B19 - spec-lint keeps every spec at 1000 lines or fewer",
  "type": "feature",
  "status": "in-progress",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T03:03:14+00:00",
  "parent": "WO-20261016-1703",
  "branch": "feat/inbox-sweep-b19-spec-lint-keeps-every-spec-at-10",
  "pr": null,
  "closed": null,
  "approval": {
    "via": "override",
    "reason": "Owner approved the reply DAG design on Bearings card D-18, 2026-10-16 UTC; Claude seats never use lavish (global owner rule)",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [
    "WO-20261016-bb3b"
  ],
  "blocks": []
}
---

# WO-20261016-75d9 - Inbox sweep B19 - spec-lint keeps every spec at 1000 lines or fewer

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

Spec files grow until no agent can read one; the 1000-line rule needs a check

## Scope

**In**

- the node's files as listed in docs/design/inbox-sweep.md sections 10, 14 to 17 and docs/design/linkedin-reply.spec.xml
- bin/spec-lint.sh, Makefile target spec-lint, its suite

**Out - non-goals**

- touching a real LinkedIn thread, mailbox, the owner's Chrome or a real herdr session (B18 only)
- any step that works around the Claude Code auto mode classifier; a denial is RP-DENIED-CLASSIFIER and stops
- splitting existing specs

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [x] `AC-H1` *(human)* a 1001-line fixture spec fails with the file name and count (test)
  - observed `2026-10-16` test_spec_lint: ok AC-H1: 1001 lines exits 1; ok AC-H1: output names the file and the count
- [x] `AC-H2` *(human)* a 1000-line fixture passes (test)
  - observed `2026-10-16` test_spec_lint: ok AC-H2: 1000 lines passes; ok AC-H2: 1000 lines with no trailing newline passes
- [x] `AC-H3` *(human)* every docs/design/*.spec.xml parses (test)
  - observed `2026-10-16` test_spec_lint: ok AC-H3: every docs/design/*.spec.xml parses and is within the cap; make spec-lint: ok inbox-sweep.spec.xml (537 lines), ok linkedin-reply.spec.xml (347 lines)

## Test plan

```sh
make -C claude/workflow/inbox-sweep test (changed suites, Podman, --network=none); make -C claude/workflow/inbox-sweep test-all once before the PR
```

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
