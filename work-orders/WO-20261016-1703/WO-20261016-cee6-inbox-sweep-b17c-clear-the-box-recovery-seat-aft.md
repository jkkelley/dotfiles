---
{
  "id": "WO-20261016-cee6",
  "slug": "inbox-sweep-b17c-clear-the-box-recovery-seat-aft",
  "title": "Inbox sweep B17c - clear-the-box recovery seat after a send seat dies",
  "type": "feature",
  "status": "ready",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T03:46:52+00:00",
  "parent": "WO-20261016-1703",
  "branch": null,
  "pr": null,
  "closed": null,
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

- [ ] `AC-H1` *(human)* a stub seat death after typing starts one clear seat for that thread, and the ledger gets RP-BOX-CLEARED then the original code (test)
- [ ] `AC-H2` *(human)* the clear brief names one thread, forbids typing and Send, and requires an empty read-back (grep in test)
- [ ] `AC-H3` *(human)* a clear seat that cannot prove the box empty after 3 tries raises one owner card (test)

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
