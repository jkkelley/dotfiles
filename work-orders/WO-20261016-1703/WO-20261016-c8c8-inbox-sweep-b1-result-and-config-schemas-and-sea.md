---
{
  "id": "WO-20261016-c8c8",
  "slug": "inbox-sweep-b1-result-and-config-schemas-and-sea",
  "title": "Inbox sweep B1 - result and config schemas and seat declarations",
  "type": "feature",
  "status": "in-progress",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T01:19:08+00:00",
  "parent": "WO-20261016-1703",
  "branch": "feat/inbox-sweep-b1-result-and-config-schemas-and-sea",
  "pr": null,
  "closed": null,
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
    "WO-20261016-4376",
    "WO-20261016-a865",
    "WO-20261016-eaa9",
    "WO-20261016-3aa8"
  ]
}
---

# WO-20261016-c8c8 - Inbox sweep B1 - result and config schemas and seat declarations

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

Seats need a result contract that refuses forbidden mutations, and the spawner needs one declaration per seat kind

## Scope

**In**

- the node's files as listed in docs/design/inbox-sweep.md section 10 and docs/design/inbox-sweep.spec.xml build-dag
- git mv docs/design/inbox-sweep.result.schema.json to inbox-sweep/schemas/result.schema.json; config.schema.json; schemas/workflows/inbox-sweep-{gmail,proton,linkedin}.workflow.json; fixtures per seat code

**Out - non-goals**

- sending, replying, deleting or archiving anything in any mailbox
- touching a real mailbox, the owner's Chrome or a real herdr session (B11 only)
- scripts that consume the schemas

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [x] `AC-H1` *(human)* make -C claude/workflow schema is green with the 3 declarations
  - observed `2026-10-16` make -C claude/workflow schema printed: ok workflow-schemas: declarations valid, thresholds required, records strict (3 inbox-sweep declarations included)
- [x] `AC-H2` *(human)* one fixture per seat status code validates
  - observed `2026-10-16` make test (schemas suite) printed: all 11 seat status codes have a validating fixture, plus OK-linkedin-with-draft.json validates
- [x] `AC-H3` *(human)* a fixture with mutation action sent fails validation
  - observed `2026-10-16` schemas suite printed ok for invalid/mutation-sent.json refused (also deleted, archived, replied, moved): 'sent' is not 'marked-read'
- [x] `AC-H4` *(human)* docs/design/inbox-sweep.md links point at the new schema path
  - observed `2026-10-16` docs/design/inbox-sweep.md line 6 and spec.xml lines 4 and 411 now point at claude/workflow/inbox-sweep/schemas/result.schema.json; grep finds no docs/design/inbox-sweep.result.schema.json left

## Test plan

```sh
make -C claude/workflow/inbox-sweep test (changed suites, Podman, --network=none); make -C claude/workflow/inbox-sweep test-all once before the PR; make -C claude/workflow schema
```

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
