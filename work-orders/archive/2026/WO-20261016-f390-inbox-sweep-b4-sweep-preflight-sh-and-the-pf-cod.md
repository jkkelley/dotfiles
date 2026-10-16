---
{
  "id": "WO-20261016-f390",
  "slug": "inbox-sweep-b4-sweep-preflight-sh-and-the-pf-cod",
  "title": "Inbox sweep B4 - sweep-preflight.sh and the PF codes",
  "type": "feature",
  "status": "done",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T01:19:10+00:00",
  "parent": "WO-20261016-1703",
  "branch": "feat/inbox-sweep-b4-sweep-preflight-sh-and-the-pf-cod",
  "pr": 112,
  "closed": "2026-10-16",
  "approval": {
    "via": "override",
    "reason": "Owner approved the design on Bearings card D-04, 2026-10-16 UTC; Claude seats never use lavish (global owner rule)",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [
    "WO-20261016-bb3b"
  ],
  "blocks": [
    "WO-20261016-61ae"
  ]
}
---

# WO-20261016-f390 - Inbox sweep B4 - sweep-preflight.sh and the PF codes

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

A run must know before starting seats whether herdr, the config and the Chrome extension are reachable

## Scope

**In**

- the node's files as listed in docs/design/inbox-sweep.md section 10 and docs/design/inbox-sweep.spec.xml build-dag
- bin/sweep-preflight.sh writing preflight.json, and the preflight suite

**Out - non-goals**

- sending, replying, deleting or archiving anything in any mailbox
- touching a real mailbox, the owner's Chrome or a real herdr session (B11 only)
- waking the extension (B12)

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [x] `AC-H1` *(human)* each PF-* code has a fixture test with the stubs
  - observed `2026-10-16` test_preflight.sh printed ok lines for PF-OK, PF-NO-HERDR, PF-NO-CLAUDE-EXE, PF-NO-CHROME, PF-NO-BROWSER, each with stubs; make test-all: ran 7 suites, 0 failed
- [x] `AC-H2` *(human)* a stub probe returning [] is tried exactly 3 times then gives PF-NO-BROWSER (calls.log count)
  - observed `2026-10-16` ok PF-NO-BROWSER: the probe was called exactly 3 times (calls.log); attempts recorded as 3

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
