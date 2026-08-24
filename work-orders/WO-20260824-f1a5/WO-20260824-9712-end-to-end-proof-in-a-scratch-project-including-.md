---
{
  "id": "WO-20260824-9712",
  "slug": "end-to-end-proof-in-a-scratch-project-including-",
  "title": "End-to-end proof in a scratch project, including the lost-receipt case",
  "type": "chore",
  "status": "draft",
  "priority": "p1",
  "created": "2026-08-24",
  "updated": "2026-08-24",
  "created_at": "2026-08-24T13:19:09-05:00",
  "parent": "WO-20260824-f1a5",
  "branch": null,
  "pr": null,
  "merge_sha": null,
  "closed": null,
  "approval": null,
  "evidence": null,
  "surfaces": [],
  "depends_on": [
    "WO-20260824-316d"
  ],
  "blocks": [
    "WO-20260824-8cd1",
    "WO-20260824-c6b0",
    "WO-20260824-81a6",
    "WO-20260824-b21b"
  ]
}
---

# WO-20260824-9712 - End-to-end proof in a scratch project, including the lost-receipt case

## Problem

The hook only proves itself by firing. Five properties matter and none can be observed from a unit test: that a session start installs the skill, that a hand-authored skill beside it survives, that a manifest removal removes, and above all that a lost receipt orphans a managed directory rather than deleting a local one.

## Scope

**In**

- a scratch repository with a manifest naming hydration-prompt
- a hand-authored skill placed deliberately beside the managed one
- removing from the manifest and re-syncing
- deleting the receipt and re-syncing

**Out - non-goals**

- automating any of this - rung 5 is manual and that is the point

## Acceptance criteria


- [ ] `AC-H1` *(human)* on first session start the skill is installed with the notice rendered into it
- [ ] `AC-H2` *(human)* the hand-authored skill beside it is untouched, unread and unreported
- [ ] `AC-H3` *(human)* removal from the manifest removes the directory, and a deleted receipt deletes nothing
- [ ] `AC-H4` *(human)* the receipt records owned correctly at each of the four steps

## Test plan

```sh
manual, rung 5. A scratch repository and four real session starts
```

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

- `2026-08-24` Poker 2026-08-24: 5 points. Sized above the plan's small. Five scenarios, each needing a real session start, plus a scratch repo staged with a hand-authored skill beside a managed one.

## Outcome

_Written by `work-order close`. Empty until then._
