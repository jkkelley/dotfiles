---
{
  "id": "WO-20261016-5328",
  "slug": "inbox-sweep-b12-spike-can-the-extension-be-woken",
  "title": "Inbox sweep B12 - spike, can the extension be woken without the owner",
  "type": "spike",
  "status": "draft",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T01:19:18+00:00",
  "parent": "WO-20261016-1703",
  "branch": null,
  "pr": null,
  "closed": null,
  "approval": null,
  "evidence": null,
  "surfaces": [],
  "depends_on": [],
  "blocks": [],
  "labels": [
    "line:inbox-triage"
  ]
}
---

# WO-20261016-5328 - Inbox sweep B12 - spike, can the extension be woken without the owner

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

PF-NO-BROWSER today needs the owner to open the Claude side panel (design D3)

## Scope

**In**

- the node's files as listed in docs/design/inbox-sweep.md section 10 and docs/design/inbox-sweep.spec.xml build-dag

**Out - non-goals**

- sending, replying, deleting or archiving anything in any mailbox
- touching a real mailbox, the owner's Chrome or a real herdr session (B11 only)
- any change to the owner's Chrome profile or extension storage

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [ ] `AC-H1` *(human)* a reproducible wake command, or a documented no, recorded in design D3

## Test plan

```sh
reproduce PF-NO-BROWSER, try the candidate wake, rerun the probe; record command and output
```

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
