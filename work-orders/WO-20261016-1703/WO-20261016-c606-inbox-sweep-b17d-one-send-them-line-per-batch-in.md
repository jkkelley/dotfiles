---
{
  "id": "WO-20261016-c606",
  "slug": "inbox-sweep-b17d-one-send-them-line-per-batch-in",
  "title": "Inbox sweep B17d - one Send them line per batch in reply-send.sh",
  "type": "feature",
  "status": "ready",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T04:46:21+00:00",
  "parent": "WO-20261016-1703",
  "branch": null,
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
    "WO-20261016-cee6"
  ],
  "blocks": [
    "WO-20261016-ab00",
    "WO-20261016-6242",
    "WO-20261016-80aa"
  ]
}
---

# WO-20261016-c606 - Inbox sweep B17d - one Send them line per batch in reply-send.sh

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

Ruling R4: the send seat waits for one owner line per batch, never one per reply; reply-send.sh still waits for send <id> per file

## Scope

**In**

- files touched, and no others: claude/workflow/inbox-sweep/bin/reply-send.sh, templates/brief-linkedin-send.md, nodes/L6.node.json, nodes/L6b.node.json, schemas/config.schema.json, tests/unit/test_reply_send.sh, tests/lib/stub-reply-seat.sh

**Out - non-goals**

- touching a real LinkedIn thread, mailbox, the owner's Chrome or a real herdr session
- any step that works around the Claude Code auto mode classifier
- any file not listed in In

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [ ] `AC-H1` *(human)* make reply-send with 3 RP-READY files starts exactly one seat agent-reply-batch-<batch-id> whose brief names the 3 files (stub test)
- [ ] `AC-H2` *(human)* nothing is typed before the pane shows Send them while RP-AWAITING-CONFIRM batch <batch-id> is printed; send <id> and any other line are ignored (stub test)
- [ ] `AC-H3` *(human)* RP-CONFIRMED is written once per file in the batch, each row quoting the line and the batch id (stub test)
- [ ] `AC-H4` *(human)* a one-character mismatch on file 2 ends file 2 with RP-TEXT-MISMATCH and files 1 and 3 still reach RP-SENT (stub test)
- [ ] `AC-H5` *(human)* a classifier denial on file 1 gives RP-DENIED-CLASSIFIER on all 3 files and zero retries (stub test)
- [ ] `AC-H6` *(human)* more RP-READY files than reply_batch_max (config, default 10) leaves the rest RP-READY for the next batch (stub test)
- [ ] `AC-H7` *(human)* L6 and L6b declarations bumped (minor) and make nodes-check green

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
