---
{
  "id": "WO-20261016-c606",
  "slug": "inbox-sweep-b17d-one-send-them-line-per-batch-in",
  "title": "Inbox sweep B17d - one Send them line per batch in reply-send.sh",
  "type": "feature",
  "status": "done",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T04:46:21+00:00",
  "parent": "WO-20261016-1703",
  "branch": "feat/inbox-sweep-b17d-one-send-them-line-per-batch-in",
  "pr": 168,
  "closed": "2026-10-16",
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

- [x] `AC-H1` *(human)* make reply-send with 3 RP-READY files starts exactly one seat agent-reply-batch-<batch-id> whose brief names the 3 files (stub test)
  - observed `2026-10-16` make -C claude/workflow/inbox-sweep suite SUITE=reply-send (Podman, --network=none) -> 'ok reply-send', ran 1 suite, rc 0. Checks: batch of 3 RP-READY files, one start 'start agent-reply-batch-b1 b1', brief has 3 'Approval file:' lines naming the 3 files, 3 RP-SENT. Gap: Makefile reply-send target (still APPROVAL=<file>) is not in the ticket's declared files and was not edited; the script's 'send' with no --approval is the batch entry.
- [x] `AC-H2` *(human)* nothing is typed before the pane shows Send them while RP-AWAITING-CONFIRM batch <batch-id> is printed; send <id> and any other line are ignored (stub test)
  - observed `2026-10-16` make -C claude/workflow/inbox-sweep suite SUITE=reply-send (Podman, --network=none) -> 'ok reply-send', ran 1 suite, rc 0. Checks: lines 'send m1','send m2','sEnd them','Send them please','yes' give exit 5, zero RP-CONFIRMED rows, nothing typed; a seat typing early gives RP-FAILED-SEAT on all 3 files and no click.
- [x] `AC-H3` *(human)* RP-CONFIRMED is written once per file in the batch, each row quoting the line and the batch id (stub test)
  - observed `2026-10-16` make -C claude/workflow/inbox-sweep suite SUITE=reply-send (Podman, --network=none) -> 'ok reply-send', ran 1 suite, rc 0. Checks: 3 RP-CONFIRMED rows (m1 m2 m3), each line 'Send them' and batch 'b1'.
- [x] `AC-H4` *(human)* a one-character mismatch on file 2 ends file 2 with RP-TEXT-MISMATCH and files 1 and 3 still reach RP-SENT (stub test)
  - observed `2026-10-16` make -C claude/workflow/inbox-sweep suite SUITE=reply-send (Podman, --network=none) -> 'ok reply-send', ran 1 suite, rc 0. Checks: modes ok/mismatch/ok give m1 RP-SENT, m2 RP-TEXT-MISMATCH, m3 RP-SENT; 2 clicks; no token for m2; 1 seat start.
- [x] `AC-H5` *(human)* a classifier denial on file 1 gives RP-DENIED-CLASSIFIER on all 3 files and zero retries (stub test)
  - observed `2026-10-16` make -C claude/workflow/inbox-sweep suite SUITE=reply-send (Podman, --network=none) -> 'ok reply-send', ran 1 suite, rc 0. Checks: denial on file 1 gives RP-DENIED-CLASSIFIER x3, 1 seat start, 0 agent prompt calls, nothing typed or clicked; denial on file 2 keeps file 1 RP-SENT.
- [x] `AC-H6` *(human)* more RP-READY files than reply_batch_max (config, default 10) leaves the rest RP-READY for the next batch (stub test)
  - observed `2026-10-16` make -C claude/workflow/inbox-sweep suite SUITE=reply-send (Podman, --network=none) -> 'ok reply-send', ran 1 suite, rc 0. Checks: reply_batch_max 2 in config sends m1 m2 and m3 stays RP-READY then goes in the next batch; --max 1 overrides; default cap 10 of 12 files, m11 stays RP-READY; --max 0 exits 2.
- [x] `AC-H7` *(human)* L6 and L6b declarations bumped (minor) and make nodes-check green
  - observed `2026-10-16` L6 1.2.0 -> 1.3.0 and L6b 1.1.0 -> 1.2.0; config.schema.json gained reply_batch_max; make -C claude/workflow/inbox-sweep nodes-check exits 0 (L6.node.json validates, L6b.node.json validates).

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
