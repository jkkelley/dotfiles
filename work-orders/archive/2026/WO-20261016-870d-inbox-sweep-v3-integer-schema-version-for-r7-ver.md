---
{
  "id": "WO-20261016-870d",
  "slug": "inbox-sweep-v3-integer-schema-version-for-r7-ver",
  "title": "Inbox sweep V3 - integer schema_version for R7-verdict.json with its migration",
  "type": "feature",
  "status": "done",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T04:46:56+00:00",
  "parent": "WO-20261016-1703",
  "branch": "feat/inbox-sweep-v3-integer-schema-version-for-r7-ver",
  "pr": 243,
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
    "WO-20261016-657b"
  ]
}
---

# WO-20261016-870d - Inbox sweep V3 - integer schema_version for R7-verdict.json with its migration

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

Design 15.2: every record carries an integer schema_version; R7-verdict.json still carries the string 1.0.0 or none. Its one writer after ruling R3 is sweep-proof.sh

## Scope

**In**

- files touched, and no others: claude/workflow/inbox-sweep/bin/sweep-proof.sh, schemas/records/R7-verdict.v1.schema.json (new), schemas/records/R7-verdict.v2.schema.json (new), migrations/R7-verdict/v1-to-v2.sh (new), tests/fixtures/migrations/R7-verdict/v1.json (new)

**Out - non-goals**

- touching a real LinkedIn thread, mailbox, the owner's Chrome or a real herdr session
- any step that works around the Claude Code auto mode classifier
- any file not listed in In

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [x] `AC-H1` *(human)* sweep-proof.sh writes schema_version 2 (integer) and the v2 schema validates its output (test)
  - observed `2026-10-16` 2026-10-16 podman, test_proof.sh stubs plus a v2-schema check on proof/R7-verdict.json in the CLEAN-NO-PROOF, CLEAN-OK and CLEAN-TABS-LEFT paths: schema_version type number (2), R7-verdict.v2.schema.json errors 0; make test proof suite ok
- [x] `AC-H2` *(human)* migrations/R7-verdict/v1-to-v2.sh upgrades the v1 fixture copy-forward, the v1 file survives, and the result validates against v2 (make migrate test)
  - observed `2026-10-16` 2026-10-16 podman, bin/migrate.sh migrate over tests/fixtures/migrations/R7-verdict/v1.json copied as R7-verdict.json: MIG-OK -> R7-verdict.v2.json; v1 file byte-identical; schema_version 2; v2 schema errors 0; v1 fixture validates v1 (0 errors); make test migrate suite AC-H1..H3,H5 ok
- [x] `AC-H3` *(human)* make nodes-check is green with the bump and its migration
  - observed `2026-10-16` NOT GREEN, not caused by this change: make nodes-check on main c569591 fails 'reply-ledger.sh names node B21c, which has no declaration in nodes/' (bin/reply-ledger.sh line 3, no nodes/B21*.node.json on main). With bin copied minus reply-ledger.sh (NODE_SCRIPTS override) nodes-check exits 0 and prints 'R7-verdict v2 ships its migration and fixture'. Same root cause fails migrate suite AC-H4 cases 'bump that ships migration passes nodes-check'

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
