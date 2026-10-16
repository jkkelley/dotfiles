---
{
  "id": "WO-20261016-824b",
  "slug": "inbox-sweep-b21f1-steps-and-checklist-rows-go-to",
  "title": "Inbox sweep B21f1 - steps and checklist rows go to per-node files",
  "type": "feature",
  "status": "in-progress",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T04:46:24+00:00",
  "parent": "WO-20261016-1703",
  "branch": "feat/inbox-sweep-b21f1-steps-and-checklist-rows-go-to",
  "pr": null,
  "closed": null,
  "approval": {
    "via": "override",
    "reason": "Architect rulings R3 and R4, 2026-10-16T04:25Z, recorded in design 18 (PR 153); Claude seats never use lavish",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [],
  "blocks": [
    "WO-20261016-bd17",
    "WO-20261016-002d"
  ]
}
---

# WO-20261016-824b - Inbox sweep B21f1 - steps and checklist rows go to per-node files

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

Ruling R3: run.json.steps and checklist.jsonl are written by every script through sweep-lib.sh, so neither has one owner

## Scope

**In**

- files touched, and no others: claude/workflow/inbox-sweep/bin/sweep-lib.sh, bin/sweep-collect.sh, tests/unit/test_lib.sh, tests/unit/test_collect.sh

**Out - non-goals**

- touching a real LinkedIn thread, mailbox, the owner's Chrome or a real herdr session
- any step that works around the Claude Code auto mode classifier
- any file not listed in In

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [x] `AC-H1` *(human)* sweep_retry appends to <run>/steps/<node>.jsonl and sweep_check to <run>/checklist/<node>.jsonl, never run.json or checklist.jsonl (test)
  - observed `2026-10-16` make -C claude/workflow/inbox-sweep test: lib ok. sweep_retry writes steps/<node>.jsonl (SWEEP_NODE, default run) and sweep_check writes checklist/<node>.jsonl; run.json unchanged, shared checklist.jsonl never created
- [x] `AC-H2` *(human)* each row carries an integer schema_version (test)
  - observed `2026-10-16` make -C claude/workflow/inbox-sweep test: lib ok. step and checklist rows carry schema_version 1 (integer)
- [x] `AC-H3` *(human)* sweep-collect.sh reads every steps/ and checklist/ file and its fixtures still derive the same run codes (test)
  - observed `2026-10-16` make -C claude/workflow/inbox-sweep test: collect ok. sweep-collect.sh reads steps/ and checklist/ files, derive 1-5 run code fixtures unchanged, lint ok

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
