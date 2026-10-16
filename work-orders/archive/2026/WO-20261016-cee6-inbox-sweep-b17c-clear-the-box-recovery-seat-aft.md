---
{
  "id": "WO-20261016-cee6",
  "slug": "inbox-sweep-b17c-clear-the-box-recovery-seat-aft",
  "title": "Inbox sweep B17c - clear-the-box recovery seat after a send seat dies",
  "type": "feature",
  "status": "done",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T03:46:52+00:00",
  "parent": "WO-20261016-1703",
  "branch": "feat/inbox-sweep-b17c-clear-the-box-recovery-seat-aft",
  "pr": 133,
  "closed": "2026-10-16",
  "approval": {
    "via": "override",
    "reason": "Covered by the reply DAG design approved on Bearings card D-18, 2026-10-16 UTC, section 14.4",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [
    "WO-20261016-4682"
  ],
  "blocks": [
    "WO-20261016-80aa"
  ]
}
---

# WO-20261016-cee6 - Inbox sweep B17c - clear-the-box recovery seat after a send seat dies

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

Design 14.4 says a box is never left holding text: when a send seat dies, the controller starts a fresh seat whose only job is to clear the box in that thread and prove it empty. B17b did not build it.

## Scope

**In**

- templates/brief-linkedin-clear.md, the RP-BOX-CLEARED branch in bin/reply-send.sh, its suite

**Out - non-goals**

- touching a real LinkedIn thread, mailbox, the owner's Chrome or a real herdr session (B18 only)
- any step that works around the Claude Code auto mode classifier; a denial is RP-DENIED-CLASSIFIER and stops
- typing or sending anything; the clear seat only empties the box and reads it back

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [x] `AC-H1` *(human)* a stub seat death after typing starts one clear seat for that thread, and the ledger gets RP-BOX-CLEARED then the original code (test)
  - observed `2026-10-16` test_reply_send: 'ok AC-H1: one clear seat is started for the dead seat' and ledger 'RP-READY RP-SENDING RP-AWAITING-CONFIRM RP-CONFIRMED RP-BOX-CLEARED RP-UNPROVEN'
- [x] `AC-H2` *(human)* the clear brief names one thread, forbids typing and Send, and requires an empty read-back (grep in test)
  - observed `2026-10-16` test_reply_send: AC-H2 greps ok on the rendered clear brief: one Thread URL, 'This seat types nothing into LinkedIn.', 'This seat never clicks Send', 'The box must read back empty'
- [x] `AC-H3` *(human)* a clear seat that cannot prove the box empty after 3 tries raises one owner card (test)
  - observed `2026-10-16` test_reply_send: 'ok AC-H3: exactly one owner card is raised' (RP-BOX-m1) after 3 clear seats, rerun adds no duplicate; make test-all ran 23 suites, 0 failed

## Test plan

```sh
make -C claude/workflow/inbox-sweep test; make -C claude/workflow/inbox-sweep test-all once before the PR
```

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
