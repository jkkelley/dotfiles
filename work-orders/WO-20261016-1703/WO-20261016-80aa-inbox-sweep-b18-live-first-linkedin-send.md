---
{
  "id": "WO-20261016-80aa",
  "slug": "inbox-sweep-b18-live-first-linkedin-send",
  "title": "Inbox sweep B18 - live first LinkedIn send",
  "type": "feature",
  "status": "draft",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T03:03:26+00:00",
  "parent": "WO-20261016-1703",
  "branch": null,
  "pr": null,
  "closed": null,
  "approval": null,
  "evidence": null,
  "surfaces": [],
  "depends_on": [
    "WO-20261016-4682",
    "WO-20261016-cee6",
    "WO-20261016-73cd"
  ],
  "blocks": []
}
---

# WO-20261016-80aa - Inbox sweep B18 - live first LinkedIn send

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

The send path is unproven until one real approved reply is sent and proven

## Scope

**In**

- the node's files as listed in docs/design/inbox-sweep.md sections 10, 14 to 17 and docs/design/linkedin-reply.spec.xml

**Out - non-goals**

- touching a real LinkedIn thread, mailbox, the owner's Chrome or a real herdr session (B18 only)
- any step that works around the Claude Code auto mode classifier; a denial is RP-DENIED-CLASSIFIER and stops
- running before the owner has answered the card for that reply

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [ ] `AC-H1` *(human)* the thread read-back shows the text once (screenshot in proof/)
- [ ] `AC-H2` *(human)* the tab bar is clean (CLEAN-OK)
- [ ] `AC-H3` *(human)* exactly one ledger row for the file (jq)
- [ ] `AC-H4` *(human)* whether the owner's own pane line clears the classifier is recorded in the design

## Test plan

```sh
make -C claude/workflow/inbox-sweep reply-send for one approved file; live, owner-gated
```

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
