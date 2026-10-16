---
{
  "id": "WO-20261016-f9a7",
  "slug": "inbox-sweep-b14-reply-cards-sh-owner-cards-per-l",
  "title": "Inbox sweep B14 - reply-cards.sh owner cards per LinkedIn draft",
  "type": "feature",
  "status": "in-progress",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T03:03:13+00:00",
  "parent": "WO-20261016-1703",
  "branch": "feat/inbox-sweep-b14-reply-cards-sh-owner-cards-per-l",
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
    "WO-20261016-c8c8"
  ],
  "blocks": [
    "WO-20261016-1130"
  ]
}
---

# WO-20261016-f9a7 - Inbox sweep B14 - reply-cards.sh owner cards per LinkedIn draft

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

Each LinkedIn draft needs exactly one owner card, and the owner's answer must be read back into decisions

## Scope

**In**

- the node's files as listed in docs/design/inbox-sweep.md sections 10, 14 to 17 and docs/design/linkedin-reply.spec.xml
- bin/reply-cards.sh and its suite (design 14.3 L3 and L4 read-back)

**Out - non-goals**

- touching a real LinkedIn thread, mailbox, the owner's Chrome or a real herdr session (B18 only)
- any step that works around the Claude Code auto mode classifier; a denial is RP-DENIED-CLASSIFIER and stops
- writing approval files (B15)

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [x] `AC-H1` *(human)* a card carries the full draft text and exactly 3 options: Send as written, Send with my edits, Drop (test)
  - observed `2026-10-16` test_reply_cards: AC-H1 ok - card holds full multi-line and 3000 char draft, exactly 3 options Send as written,Send with my edits,Drop
- [x] `AC-H2` *(human)* a rerun adds no duplicate card (test)
  - observed `2026-10-16` test_reply_cards: AC-H2 ok - rerun leaves 4 cards, 4 RP-AWAITING-OWNER rows, 3 decisions, existing card not rewritten
- [x] `AC-H3` *(human)* an unanswered card stays RP-AWAITING-OWNER (test)
  - observed `2026-10-16` test_reply_cards: AC-H3 ok - 4 unanswered cards report RP-AWAITING-OWNER, decisions.jsonl empty; empty-words edit stays open
- [x] `AC-H4` *(human)* every record this ticket writes carries an integer schema_version (design 15.2) (test)
  - observed `2026-10-16` test_reply_cards: AC-H4 ok - cards, ledger rows, decisions rows and answers.json carry integer schema_version

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
