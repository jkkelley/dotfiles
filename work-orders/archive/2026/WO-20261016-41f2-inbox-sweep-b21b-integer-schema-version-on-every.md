---
{
  "id": "WO-20261016-41f2",
  "slug": "inbox-sweep-b21b-integer-schema-version-on-every",
  "title": "Inbox sweep B21b - integer schema_version on every built record with migrations",
  "type": "feature",
  "status": "cancelled",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T03:03:18+00:00",
  "parent": "WO-20261016-1703",
  "branch": null,
  "pr": null,
  "closed": "2026-10-16",
  "approval": {
    "via": "override",
    "reason": "Owner approved the reply DAG design on Bearings card D-18, 2026-10-16 UTC; Claude seats never use lavish (global owner rule)",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [
    "WO-20261016-dd75",
    "WO-20261016-dd0c",
    "WO-20261016-61ae"
  ],
  "blocks": [],
  "superseded_by": "WO-20261016-5f8d"
}
---

# WO-20261016-41f2 - Inbox sweep B21b - integer schema_version on every built record with migrations

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

Built records use the string 1.0.0, preflight uses 1, and checklist rows, verdicts and cards carry none; design 15.2 requires an integer on every record

## Scope

**In**

- the node's files as listed in docs/design/inbox-sweep.md sections 10, 14 to 17 and docs/design/linkedin-reply.spec.xml
- schemas/records/<name>.v1 and v2 schema files, migrations/<name>/v1-to-v2.sh, writers updated to write the pinned version

**Out - non-goals**

- touching a real LinkedIn thread, mailbox, the owner's Chrome or a real herdr session (B18 only)
- any step that works around the Claude Code auto mode classifier; a denial is RP-DENIED-CLASSIFIER and stops
- changing any record field other than schema_version

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [ ] `AC-H1` *(human)* each built record type has a migration from its current form and a test that upgrades a fixture and validates it (test)
- [ ] `AC-H2` *(human)* scripts read N and N-1 and write only N (test)

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

Cancelled `2026-10-16` - nothing shipped.

- reason: Superseded by architect ruling R3 (design 18.3): one owner per record first (B21c, B21d, B21e, B21f1, B21f2), then one version ticket per record (V1 run.json, V2 summary.json, V3 R7-verdict.json). Seat results and config.json need an ownership ruling before a version ticket can be cut.
- superseded by: `WO-20261016-5f8d`

No branch, no PR and no merge commit exist for this work order.

