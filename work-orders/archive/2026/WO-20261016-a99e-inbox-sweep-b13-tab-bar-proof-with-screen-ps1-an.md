---
{
  "id": "WO-20261016-a99e",
  "slug": "inbox-sweep-b13-tab-bar-proof-with-screen-ps1-an",
  "title": "Inbox sweep B13 - tab bar proof with screen.ps1 and sweep-proof.sh",
  "type": "feature",
  "status": "done",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T01:19:15+00:00",
  "parent": "WO-20261016-1703",
  "branch": "feat/inbox-sweep-b13-tab-bar-proof-with-screen-ps1-an",
  "pr": 111,
  "closed": "2026-10-16",
  "approval": {
    "via": "override",
    "reason": "Owner approved the design on Bearings card D-04, 2026-10-16 UTC; Claude seats never use lavish (global owner rule)",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [
    "WO-20261016-bb3b"
  ],
  "blocks": [
    "WO-20261016-61ae",
    "WO-20261016-24c5"
  ]
}
---

# WO-20261016-a99e - Inbox sweep B13 - tab bar proof with screen.ps1 and sweep-proof.sh

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

A seat's own report is not proof a run cleaned up (F7); the screen is

## Scope

**In**

- the node's files as listed in docs/design/inbox-sweep.md section 10 and docs/design/inbox-sweep.spec.xml build-dag
- bin/screen.ps1 ported with a breadcrumb naming F6 and F7, bin/sweep-proof.sh baseline and verify, R2 and R7 hooks, the proof suite

**Out - non-goals**

- sending, replying, deleting or archiving anything in any mailbox
- touching a real mailbox, the owner's Chrome or a real herdr session (B11 only)
- the controller wiring (B9)

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [x] `AC-H1` *(human)* a stub powershell.exe capture failing 3 times gives CLEAN-NO-PROOF (test)
  - observed `2026-10-16` proof suite: ok verify prints CLEAN-NO-PROOF when the capture fails; capture tried exactly 3 times; no verdict read
- [x] `AC-H2` *(human)* a verdict naming an orphan tab gives one CLEAN-ORPHAN-TAB card (test)
  - observed `2026-10-16` proof suite: ok an orphan verdict writes exactly one card; rerunning verify adds no second card
- [x] `AC-H3` *(human)* TABS-LEFT prompts the seat at most 3 times (calls.log count)
  - observed `2026-10-16` proof suite: ok TABS-LEFT prompts the live browser seat exactly 3 times (calls.log count)

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
