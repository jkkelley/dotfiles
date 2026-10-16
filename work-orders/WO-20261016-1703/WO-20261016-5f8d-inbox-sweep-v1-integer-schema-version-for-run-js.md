---
{
  "id": "WO-20261016-5f8d",
  "slug": "inbox-sweep-v1-integer-schema-version-for-run-js",
  "title": "Inbox sweep V1 - integer schema_version for run.json with its migration",
  "type": "feature",
  "status": "in-review",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T04:46:51+00:00",
  "parent": "WO-20261016-1703",
  "branch": "feat/inbox-sweep-v1-integer-schema-version-for-run-js",
  "pr": 239,
  "closed": null,
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
    "WO-20261016-56c1"
  ]
}
---

# WO-20261016-5f8d - Inbox sweep V1 - integer schema_version for run.json with its migration

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

Design 15.2: every record carries an integer schema_version; run.json still carries the string 1.0.0 or none. Its one writer after ruling R3 is sweep-init.sh

## Scope

**In**

- files touched, and no others: claude/workflow/inbox-sweep/bin/sweep-init.sh, schemas/records/run.v1.schema.json (new), schemas/records/run.v2.schema.json (new), migrations/run/v1-to-v2.sh (new), tests/fixtures/migrations/run/v1.json (new)

**Out - non-goals**

- touching a real LinkedIn thread, mailbox, the owner's Chrome or a real herdr session
- any step that works around the Claude Code auto mode classifier
- any file not listed in In

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [x] `AC-H1` *(human)* sweep-init.sh writes schema_version 2 (integer) and the v2 schema validates its output (test)
  - observed `2026-10-16` podman, sweep-init.sh --seats all with fixture config: run.json schema_version 2 (jq type number); run.v2.schema.json validation errors: 0
- [x] `AC-H2` *(human)* migrations/run/v1-to-v2.sh upgrades the v1 fixture copy-forward, the v1 file survives, and the result validates against v2 (make migrate test)
  - observed `2026-10-16` podman, make migrate path (bin/migrate.sh migrate) over tests/fixtures/migrations/run/v1.json copied as run.json: MIG-OK -> run.v2.json, run.json survives (schema_version 1), run.v2.json schema_version 2, validates against run.v2 with 0 errors; make test migrate suite ran, its AC-H1..H3/H5 cases ok
- [ ] `AC-H3` *(human)* make nodes-check is green with the bump and its migration

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
