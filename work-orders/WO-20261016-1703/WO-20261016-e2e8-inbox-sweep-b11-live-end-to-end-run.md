---
{
  "id": "WO-20261016-e2e8",
  "slug": "inbox-sweep-b11-live-end-to-end-run",
  "title": "Inbox sweep B11 - live end-to-end run",
  "type": "feature",
  "status": "draft",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T01:19:17+00:00",
  "parent": "WO-20261016-1703",
  "branch": null,
  "pr": null,
  "closed": null,
  "approval": null,
  "evidence": null,
  "surfaces": [],
  "depends_on": [
    "WO-20261016-61ae",
    "WO-20261016-73cd"
  ],
  "blocks": []
}
---

# WO-20261016-e2e8 - Inbox sweep B11 - live end-to-end run

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

The only proof the sweep works is one real run against the real inboxes

## Scope

**In**

- the node's files as listed in docs/design/inbox-sweep.md section 10 and docs/design/inbox-sweep.spec.xml build-dag

**Out - non-goals**

- sending, replying, deleting or archiving anything in any mailbox
- touching a real mailbox, the owner's Chrome or a real herdr session (B11 only)
- running before the architect releases it
- any send, reply, delete or archive

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [ ] `AC-H1` *(human)* RUN-OK, or every non-OK seat has its card (summary.json, questions.json)
- [ ] `AC-H2` *(human)* no forbidden mutation: jq over results finds only marked-read
- [ ] `AC-H3` *(human)* herdr tabs gone and proof/R7-verdict.json says CLEAN-OK

## Test plan

```sh
make -C claude/workflow/inbox-sweep sweep, then status and clean; architect-released only
```

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
