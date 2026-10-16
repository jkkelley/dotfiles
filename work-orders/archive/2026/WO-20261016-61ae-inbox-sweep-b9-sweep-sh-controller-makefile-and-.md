---
{
  "id": "WO-20261016-61ae",
  "slug": "inbox-sweep-b9-sweep-sh-controller-makefile-and-",
  "title": "Inbox sweep B9 - sweep.sh controller, Makefile and README",
  "type": "feature",
  "status": "done",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T01:19:16+00:00",
  "parent": "WO-20261016-1703",
  "branch": "feat/inbox-sweep-b9-sweep-sh-controller-makefile-and-",
  "pr": 118,
  "closed": "2026-10-16",
  "approval": {
    "via": "override",
    "reason": "Owner approved the design on Bearings card D-04, 2026-10-16 UTC; Claude seats never use lavish (global owner rule)",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [
    "WO-20261016-4376",
    "WO-20261016-f390",
    "WO-20261016-b956",
    "WO-20261016-a865",
    "WO-20261016-eaa9",
    "WO-20261016-3aa8",
    "WO-20261016-c78f",
    "WO-20261016-a99e"
  ],
  "blocks": [
    "WO-20261016-e2e8",
    "WO-20261016-41f2",
    "WO-20261016-73cd"
  ]
}
---

# WO-20261016-61ae - Inbox sweep B9 - sweep.sh controller, Makefile and README

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

Nothing ties the pieces into one make sweep command

## Scope

**In**

- the node's files as listed in docs/design/inbox-sweep.md section 10 and docs/design/inbox-sweep.spec.xml build-dag
- bin/sweep.sh, the sweep targets in the Makefile, README with the WSL-only platform statement (design D2) and the cleanup table

**Out - non-goals**

- sending, replying, deleting or archiving anything in any mailbox
- touching a real mailbox, the owner's Chrome or a real herdr session (B11 only)
- the live run (B11)

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [x] `AC-H1` *(human)* a stubbed full run reaches RUN-OK (integration test)
  - observed `2026-10-16` test_controller: 'ok AC-H1: a full stubbed run reaches RUN-OK in summary.json'; run.json also RUN-OK; test-all ran 15 suites, none failed
- [x] `AC-H2` *(human)* a stubbed run with probe [] gives RUN-PARTIAL with gmail OK and one card (integration test)
  - observed `2026-10-16` test_controller: 'ok AC-H2: probe [] gives RUN-PARTIAL', 'ok AC-H2: the Gmail seat is OK', 'ok AC-H2: exactly one card' (IS-<run>-preflight-B-PF-NO-BROWSER)
- [x] `AC-H3` *(human)* make sweep returns in under 5 seconds (integration test timing)
  - observed `2026-10-16` test_controller: 'ok AC-H3: start returned in 414 ms, under 5000'

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
