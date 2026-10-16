---
{
  "id": "WO-20261016-6242",
  "slug": "inbox-sweep-b21c-reply-ledger-sh-owns-ledger-jso",
  "title": "Inbox sweep B21c - reply-ledger.sh owns ledger.jsonl with an append verb",
  "type": "feature",
  "status": "in-progress",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T04:46:26+00:00",
  "parent": "WO-20261016-1703",
  "branch": "feat/inbox-sweep-b21c-reply-ledger-sh-owns-ledger-jso",
  "pr": null,
  "closed": null,
  "approval": {
    "via": "override",
    "reason": "Architect rulings R3 and R4, 2026-10-16T04:25Z, recorded in design 18 (PR 153); Claude seats never use lavish",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [
    "WO-20261016-c606",
    "WO-20261016-ae19"
  ],
  "blocks": [
    "WO-20261016-8aed",
    "WO-20261016-5b59"
  ]
}
---

# WO-20261016-6242 - Inbox sweep B21c - reply-ledger.sh owns ledger.jsonl with an append verb

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

Ruling R3: ledger.jsonl has four writers (reply-cards.sh, reply-approve.sh, reply-send.sh, lead-followup.sh)

## Scope

**In**

- files touched, and no others: claude/workflow/inbox-sweep/bin/reply-ledger.sh (new), bin/reply-cards.sh, bin/reply-approve.sh, bin/reply-send.sh, bin/lead-followup.sh, tests/unit/test_reply_ledger.sh (new), tests/suites.tsv

**Out - non-goals**

- touching a real LinkedIn thread, mailbox, the owner's Chrome or a real herdr session
- any step that works around the Claude Code auto mode classifier
- any file not listed in In

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [x] `AC-H1` *(human)* grep shows ledger.jsonl written only by reply-ledger.sh (test)
  - observed `2026-10-16` make -C claude/workflow/inbox-sweep test: ok reply-ledger; its AC-H1 checks found no redirect into a ledger variable or ledger.jsonl in bin/*.sh outside reply-ledger.sh, and all four callers match 'reply-ledger.sh" append'
- [x] `AC-H2` *(human)* the four callers use reply-ledger.sh append and their suites stay green
  - observed `2026-10-16` make test: ok reply-cards, ok reply-approve, ok reply-send (both rows), ok followup, ok seats; the lint suite reports shellcheck info/warnings on lines this change did not touch (reply-send.sh 501/526, stub-reply-seat.sh 28, test_reply_send.sh 219/224); shellcheck is clean on the two new files
- [x] `AC-H3` *(human)* append validates the row has code, id and an integer schema_version and refuses otherwise (test)
  - observed `2026-10-16` ok reply-ledger: refused with exit 2 and file unchanged for missing code, missing id, missing/string/float/null schema_version, empty code, numeric id, array, string, non-JSON; a batch with one bad row writes none of its rows

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
