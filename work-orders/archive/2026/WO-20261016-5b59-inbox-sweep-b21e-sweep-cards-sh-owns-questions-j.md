---
{
  "id": "WO-20261016-5b59",
  "slug": "inbox-sweep-b21e-sweep-cards-sh-owns-questions-j",
  "title": "Inbox sweep B21e - sweep-cards.sh owns questions.json with an add verb",
  "type": "feature",
  "status": "done",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T04:46:29+00:00",
  "parent": "WO-20261016-1703",
  "branch": "feat/inbox-sweep-b21e-sweep-cards-sh-owns-questions-j",
  "pr": 206,
  "closed": "2026-10-16",
  "approval": {
    "via": "override",
    "reason": "Architect rulings R3 and R4, 2026-10-16T04:25Z, recorded in design 18 (PR 153); Claude seats never use lavish",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [
    "WO-20261016-6242"
  ],
  "blocks": [
    "WO-20261016-cbb4",
    "WO-20261016-002d"
  ]
}
---

# WO-20261016-5b59 - Inbox sweep B21e - sweep-cards.sh owns questions.json with an add verb

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

Ruling R3: questions.json is written by sweep-cards.sh, reply-cards.sh, sweep-proof.sh and reply-send.sh

## Scope

**In**

- files touched, and no others: claude/workflow/inbox-sweep/bin/sweep-cards.sh, bin/reply-cards.sh, bin/sweep-proof.sh, bin/reply-send.sh, tests/unit/test_cards.sh

**Out - non-goals**

- touching a real LinkedIn thread, mailbox, the owner's Chrome or a real herdr session
- any step that works around the Claude Code auto mode classifier
- any file not listed in In

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [x] `AC-H1` *(human)* grep shows questions.json written only by sweep-cards.sh (test)
  - observed `2026-10-16` test_cards.sh: grep -lE of writes to $CARDS/$cards across bin/*.sh yields only 'sweep-cards.sh '; make -C claude/workflow/inbox-sweep test: ok cards, 9 suites, 0 failed
- [x] `AC-H2` *(human)* sweep-cards.sh add is idempotent by card id: a rerun adds no duplicate (test)
  - observed `2026-10-16` test_cards.sh: add on same id twice prints 'added 1' then 'added 0'; existing card about unchanged; array with duplicate ids adds once; all checks ok
- [x] `AC-H3` *(human)* the three callers use sweep-cards.sh add and their suites stay green
  - observed `2026-10-16` reply-cards.sh, sweep-proof.sh, reply-send.sh call 'sweep-cards.sh add'; suites proof, reply-cards, reply-send, followup, seats, cards all ok in make test (9 suites, 0 failed)

## Test plan

```sh
make -C claude/workflow/inbox-sweep test (changed suites only, Podman, --network=none); CI runs lint and the full suite
```

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
