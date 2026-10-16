---
{
  "id": "WO-20261016-4682",
  "slug": "inbox-sweep-b17b-reply-send-sh-controller-and-ma",
  "title": "Inbox sweep B17b - reply-send.sh controller and make reply targets",
  "type": "feature",
  "status": "done",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T03:03:22+00:00",
  "parent": "WO-20261016-1703",
  "branch": "feat/inbox-sweep-b17b-reply-send-sh-controller-and-ma",
  "pr": 130,
  "closed": "2026-10-16",
  "approval": {
    "via": "override",
    "reason": "Owner approved the reply DAG design on Bearings card D-18, 2026-10-16 UTC; Claude seats never use lavish (global owner rule)",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [
    "WO-20261016-24c5",
    "WO-20261016-de23",
    "WO-20261016-dd75"
  ],
  "blocks": [
    "WO-20261016-a47c",
    "WO-20261016-80aa"
  ]
}
---

# WO-20261016-4682 - Inbox sweep B17b - reply-send.sh controller and make reply targets

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

Nothing starts a send seat for an approved file, guards exactly-once, or records the outcome

## Scope

**In**

- the node's files as listed in docs/design/inbox-sweep.md sections 10, 14 to 17 and docs/design/linkedin-reply.spec.xml
- bin/reply-send.sh, Makefile targets reply-status, reply-send, reply-prune, its suite

**Out - non-goals**

- touching a real LinkedIn thread, mailbox, the owner's Chrome or a real herdr session (B18 only)
- any step that works around the Claude Code auto mode classifier; a denial is RP-DENIED-CLASSIFIER and stops
- the live send (B18)

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [x] `AC-H1` *(human)* a stub seat with a one-character mismatch never reaches Send (test)
  - observed `2026-10-16` test_reply_send: AC-H1 mismatch seat typed 3 times, 0 clicks, no token, no RP-SENT row, out 'm1 RP-TEXT-MISMATCH'; rogue RP-SENT without token recorded RP-UNPROVEN
- [x] `AC-H2` *(human)* a classifier denial stub gives RP-DENIED-CLASSIFIER with zero retries (test)
  - observed `2026-10-16` test_reply_send: AC-H2 denial stub gave 'm1 RP-DENIED-CLASSIFIER', 1 seat start, 0 agent prompt calls
- [x] `AC-H3` *(human)* a thread already holding the text gives RP-ALREADY-SENT (test)
  - observed `2026-10-16` test_reply_send: AC-H3 thread-holds-text stub and a ledger RP-SENT both gave 'm1 RP-ALREADY-SENT'; ledger case started no seat, rerun added no row
- [x] `AC-H4` *(human)* nothing is typed before RP-CONFIRMED (test)
  - observed `2026-10-16` test_reply_send: AC-H4 no line, other-id line, and substring line typed nothing (exit 5); early typer ended RP-FAILED-SEAT with no token; typed logged confirmed=yes
- [x] `AC-H5` *(human)* a stub run reaches RP-SENT with one ledger row (test)
  - observed `2026-10-16` test_reply_send: AC-H5 stub run printed 'm1 RP-SENT', ledger RP-READY..RP-SENT order, exactly 1 RP-SENT row; make test-all: ran 22 suites, 0 failed

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
