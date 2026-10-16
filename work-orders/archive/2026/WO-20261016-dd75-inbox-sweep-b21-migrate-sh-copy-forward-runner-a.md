---
{
  "id": "WO-20261016-dd75",
  "slug": "inbox-sweep-b21-migrate-sh-copy-forward-runner-a",
  "title": "Inbox sweep B21 - migrate.sh copy-forward runner and rollback",
  "type": "feature",
  "status": "done",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T03:03:17+00:00",
  "parent": "WO-20261016-1703",
  "branch": "feat/inbox-sweep-b21-migrate-sh-copy-forward-runner-a",
  "pr": 125,
  "closed": "2026-10-16",
  "approval": {
    "via": "override",
    "reason": "Owner approved the reply DAG design on Bearings card D-18, 2026-10-16 UTC; Claude seats never use lavish (global owner rule)",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [
    "WO-20261016-07bb"
  ],
  "blocks": [
    "WO-20261016-41f2",
    "WO-20261016-4682"
  ]
}
---

# WO-20261016-dd75 - Inbox sweep B21 - migrate.sh copy-forward runner and rollback

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

A schema change today strands every record of the previous version

## Scope

**In**

- the node's files as listed in docs/design/inbox-sweep.md sections 10, 14 to 17 and docs/design/linkedin-reply.spec.xml
- bin/migrate.sh, migrations/, make migrate and make migrate-rollback, one fixture migration v1 to v2

**Out - non-goals**

- touching a real LinkedIn thread, mailbox, the owner's Chrome or a real herdr session (B18 only)
- any step that works around the Claude Code auto mode classifier; a denial is RP-DENIED-CLASSIFIER and stops
- migrating the built records (B21b)

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [x] `AC-H1` *(human)* a v1 fixture upgrades to v2 and validates (test)
  - observed `2026-10-16` test_migrate: ok AC-H1 v2 copy written beside the original; ok AC-H1 the v2 copy validates against fixture.v2.schema.json
- [x] `AC-H2` *(human)* the v1 file is still present after (test)
  - observed `2026-10-16` test_migrate: ok AC-H2 the v1 file is still present; ok AC-H2 the v1 file is byte-identical
- [x] `AC-H3` *(human)* rollback restores the pinned versions and the run finishes (test)
  - observed `2026-10-16` test_migrate: ok AC-H3 the node pin is restored; new runs read the v1 record again; the run finishes: the resolved record validates at the pinned version
- [x] `AC-H4` *(human)* a schema bump with no migration and test fails nodes-check (test)
  - observed `2026-10-16` test_migrate: ok AC-H4 a v3 schema with no migration fails nodes-check; the failure names the schema and the missing script; missing fixture also fails
- [x] `AC-H5` *(human)* a migration that would change an approved text refuses (test)
  - observed `2026-10-16` test_migrate: ok AC-H5 the code is MIG-REFUSED-TEXT; no migrated file is written; editing text_sha256 is refused too

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
