---
{
  "id": "WO-20261016-002d",
  "slug": "inbox-sweep-b21f2-run-json-written-once-by-sweep",
  "title": "Inbox sweep B21f2 - run.json written once by sweep-init.sh; controller, seat status and clean get their own records",
  "type": "feature",
  "status": "in-progress",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T04:46:31+00:00",
  "parent": "WO-20261016-1703",
  "branch": "feat/inbox-sweep-b21f2-run-json-written-once-by-sweep",
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
    "WO-20261016-824b",
    "WO-20261016-5b59"
  ],
  "blocks": [
    "WO-20261016-4794",
    "WO-20261016-5f8d",
    "WO-20261016-67ab",
    "WO-20261016-870d"
  ]
}
---

# WO-20261016-002d - Inbox sweep B21f2 - run.json written once by sweep-init.sh; controller, seat status and clean get their own records

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

Ruling R3: run.json is rewritten by sweep.sh, sweep-watch.sh and sweep-clean.sh after init

## Scope

**In**

- files touched, and no others: claude/workflow/inbox-sweep/bin/sweep.sh, bin/sweep-watch.sh, bin/sweep-clean.sh, bin/sweep-collect.sh, bin/sweep-proof.sh, tests/unit/test_controller.sh, tests/unit/test_watch.sh, tests/unit/test_clean.sh

**Out - non-goals**

- touching a real LinkedIn thread, mailbox, the owner's Chrome or a real herdr session
- any step that works around the Claude Code auto mode classifier
- any file not listed in In

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [x] `AC-H1` *(human)* after init, run.json is byte-identical at the end of a stubbed full run (test)
  - observed `2026-10-16` make -C claude/workflow/inbox-sweep test (8 changed suites, Podman) ok; test_controller: sha256 of run.json taken after init equals sha256 at the end of the stubbed full run (RUN-OK); test_watch and test_clean also assert run.json byte-identical
- [x] `AC-H2` *(human)* run status and panes are in controller.json (sweep.sh), seat status in seats/<seat>.status.json (sweep-watch.sh), cleaned_at in clean.json (sweep-clean.sh) (test)
  - observed `2026-10-16` test_controller: controller.json status RUN-OK and .panes.gmail; seats/*.status.json all OK (sweep-watch.sh); clean.json cleaned_at set (sweep-clean.sh), absent when a tab is left; test_watch/test_clean pass
- [x] `AC-H3` *(human)* sweep-collect.sh and sweep-proof.sh read the new records and the stubbed full run still reaches RUN-OK (test)
  - observed `2026-10-16` test_collect, test_proof pass reading seats/<seat>.status.json and controller.json .panes; stubbed full run still reaches RUN-OK in summary.json (test_controller)

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
