---
{
  "id": "WO-20261016-1130",
  "slug": "inbox-sweep-b15-reply-approve-sh-writes-the-appr",
  "title": "Inbox sweep B15 - reply-approve.sh writes the approval file verbatim",
  "type": "feature",
  "status": "done",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T03:03:19+00:00",
  "parent": "WO-20261016-1703",
  "branch": "feat/inbox-sweep-b15-reply-approve-sh-writes-the-appr",
  "pr": 126,
  "closed": "2026-10-16",
  "approval": {
    "via": "override",
    "reason": "Owner approved the reply DAG design on Bearings card D-18, 2026-10-16 UTC; Claude seats never use lavish (global owner rule)",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [
    "WO-20261016-f9a7"
  ],
  "blocks": [
    "WO-20261016-24c5",
    "WO-20261016-de23",
    "WO-20261016-b1b6"
  ]
}
---

# WO-20261016-1130 - Inbox sweep B15 - reply-approve.sh writes the approval file verbatim

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

An owner decision must become exactly one hashed file, byte for byte, before any send seat exists

## Scope

**In**

- the node's files as listed in docs/design/inbox-sweep.md sections 10, 14 to 17 and docs/design/linkedin-reply.spec.xml
- bin/reply-approve.sh and its suite (design 14.3 L4, L5 and 14.5)

**Out - non-goals**

- touching a real LinkedIn thread, mailbox, the owner's Chrome or a real herdr session (B18 only)
- any step that works around the Claude Code auto mode classifier; a denial is RP-DENIED-CLASSIFIER and stops
- starting send seats (B17b)

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [x] `AC-H1` *(human)* edited text in gives the same bytes out, sha256 equal (test)
  - observed `2026-10-16` test_reply_approve: 'AC-H1: edited text in gives the same bytes out (untrimmed, trailing newline kept)' and 'sha256 of the file equals sha256 of the owner bytes' ok
- [x] `AC-H2` *(human)* a second text for one thread gets a new revision file and supersedes the first (test)
  - observed `2026-10-16` test_reply_approve: 'AC-H2: second text for the thread is send-<id>-r2.txt', first file untouched, one RP-SUPERSEDED row naming it, ok
- [x] `AC-H3` *(human)* Drop writes no file (test)
  - observed `2026-10-16` test_reply_approve: 'AC-H3: Drop creates no file', no approvals row, one RP-DROPPED ledger row, ok
- [x] `AC-H4` *(human)* every record this ticket writes carries an integer schema_version (design 15.2) (test)
  - observed `2026-10-16` test_reply_approve: 'AC-H4: approvals.jsonl rows and ledger rows have an integer schema_version' ok; test-all: ran 18 suites, all ok

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
