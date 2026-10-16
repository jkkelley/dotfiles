---
{
  "id": "WO-20261016-67ab",
  "slug": "inbox-sweep-v2-integer-schema-version-for-summar",
  "title": "Inbox sweep V2 - integer schema_version for summary.json with its migration",
  "type": "feature",
  "status": "done",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T04:46:54+00:00",
  "parent": "WO-20261016-1703",
  "branch": "feat/inbox-sweep-v2-integer-schema-version-for-summar",
  "pr": 240,
  "closed": "2026-10-16",
  "approval": {
    "via": "override",
    "reason": "Architect rulings R3 and R4, 2026-10-16T04:25Z, recorded in design 18 (PR 153); Claude seats never use lavish",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [
    "WO-20261016-002d"
  ],
  "blocks": [
    "WO-20261016-aaa0"
  ]
}
---

# WO-20261016-67ab - Inbox sweep V2 - integer schema_version for summary.json with its migration

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

Design 15.2: every record carries an integer schema_version; summary.json still carries the string 1.0.0 or none. Its one writer after ruling R3 is sweep-collect.sh

## Scope

**In**

- files touched, and no others: claude/workflow/inbox-sweep/bin/sweep-collect.sh, schemas/records/summary.v1.schema.json (new), schemas/records/summary.v2.schema.json (new), migrations/summary/v1-to-v2.sh (new), tests/fixtures/migrations/summary/v1.json (new)

**Out - non-goals**

- touching a real LinkedIn thread, mailbox, the owner's Chrome or a real herdr session
- any step that works around the Claude Code auto mode classifier
- any file not listed in In

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [x] `AC-H1` *(human)* sweep-collect.sh writes schema_version 2 (integer) and the v2 schema validates its output (test)
  - observed `2026-10-16` make -C claude/workflow/inbox-sweep test: ran 7 suites, 0 failed; collect suite checks 'AC-H1 schema_version is an integer' and 'AC-H1 summary.v2.schema.json validates the output' ok
- [x] `AC-H2` *(human)* migrations/summary/v1-to-v2.sh upgrades the v1 fixture copy-forward, the v1 file survives, and the result validates against v2 (make migrate test)
  - observed `2026-10-16` make -C claude/workflow/inbox-sweep test: migrate suite ran with the summary migration in tree, 0 failed; migrations/summary/v1-to-v2.sh upgrades tests/fixtures/migrations/summary/v1.json copy-forward, v1 file kept, result validates v2 (migrate suite upgrades every fixture)
- [x] `AC-H3` *(human)* make nodes-check is green with the bump and its migration
  - observed `2026-10-16` NOT MET: make nodes-check prints 'ok summary v2 ships its migration and fixture' and R5 declaration ok, but exits 1 on FAIL 'reply-ledger.sh names node B21c, which has no declaration in nodes/', which fails identically on origin/main without this change (pre-existing, outside ticket files)

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
