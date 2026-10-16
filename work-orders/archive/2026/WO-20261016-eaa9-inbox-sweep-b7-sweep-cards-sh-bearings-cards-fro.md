---
{
  "id": "WO-20261016-eaa9",
  "slug": "inbox-sweep-b7-sweep-cards-sh-bearings-cards-fro",
  "title": "Inbox sweep B7 - sweep-cards.sh Bearings cards from results",
  "type": "feature",
  "status": "done",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T01:19:12+00:00",
  "parent": "WO-20261016-1703",
  "branch": "feat/inbox-sweep-b7-sweep-cards-sh-bearings-cards-fro",
  "pr": 114,
  "closed": "2026-10-16",
  "approval": {
    "via": "override",
    "reason": "Owner approved the design on Bearings card D-04, 2026-10-16 UTC; Claude seats never use lavish (global owner rule)",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [
    "WO-20261016-c8c8"
  ],
  "blocks": [
    "WO-20261016-61ae"
  ]
}
---

# WO-20261016-eaa9 - Inbox sweep B7 - sweep-cards.sh Bearings cards from results

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

Owner decisions and LinkedIn drafts must reach the owner as Bearings cards, once each

## Scope

**In**

- the node's files as listed in docs/design/inbox-sweep.md section 10 and docs/design/inbox-sweep.spec.xml build-dag
- bin/sweep-cards.sh and the cards suite

**Out - non-goals**

- sending, replying, deleting or archiving anything in any mailbox
- touching a real mailbox, the owner's Chrome or a real herdr session (B11 only)
- sending an approved draft (design D7)

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [x] `AC-H1` *(human)* a rerun adds no duplicate card (test, item count unchanged)
  - observed `2026-10-16` test_cards.sh: 'AC-H1: a rerun leaves the item count unchanged', ids unique, existing card not rewritten (ok)
- [x] `AC-H2` *(human)* each BLOCKED-* code gives one card (test)
  - observed `2026-10-16` test_cards.sh: one card each for BLOCKED-NO-BROWSER (2 seats, 1 card), CHALLENGE, CONNECTOR, SIGNED-OUT and PF-NO-CHROME (ok); cards.log 'BLOCKED codes 4, BLOCKED cards 4'
- [x] `AC-H3` *(human)* a draft card carries the full draft text (test)
  - observed `2026-10-16` test_cards.sh: 'AC-H3: the draft card carries the full draft text' and a 3000 char draft is not truncated (ok)
- [x] `AC-H4` *(human)* the bearings server starts in a labeled pane only (calls.log: split and rename, no background)
  - observed `2026-10-16` test_cards.sh: calls.log shows pane split wS:p1, pane rename wS:p9 bearings-inbox-sweep, pane run; bg_scan clean; no pane read (ok)

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
