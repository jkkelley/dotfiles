---
{
  "id": "WO-20261016-4376",
  "slug": "inbox-sweep-b3-sweep-init-sh-run-dir-run-json-an",
  "title": "Inbox sweep B3 - sweep-init.sh run dir, run.json and rendered briefs",
  "type": "feature",
  "status": "done",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T01:19:09+00:00",
  "parent": "WO-20261016-1703",
  "branch": "feat/inbox-sweep-b3-sweep-init-sh-run-dir-run-json-an",
  "pr": 113,
  "closed": "2026-10-16",
  "approval": {
    "via": "override",
    "reason": "Owner approved the design on Bearings card D-04, 2026-10-16 UTC; Claude seats never use lavish (global owner rule)",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [
    "WO-20261016-c8c8",
    "WO-20261016-5bf0"
  ],
  "blocks": [
    "WO-20261016-61ae"
  ]
}
---

# WO-20261016-4376 - Inbox sweep B3 - sweep-init.sh run dir, run.json and rendered briefs

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

A run needs its dir, run.json and one rendered brief per seat before anything starts

## Scope

**In**

- the node's files as listed in docs/design/inbox-sweep.md section 10 and docs/design/inbox-sweep.spec.xml build-dag
- bin/sweep-init.sh and the init suite

**Out - non-goals**

- sending, replying, deleting or archiving anything in any mailbox
- touching a real mailbox, the owner's Chrome or a real herdr session (B11 only)
- starting seats (B9)

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [x] `AC-H1` *(human)* missing owner words exits 3 with PF-NO-OWNER-WORDS (test)
  - observed `2026-10-16` test_init: 'ok missing owner words exits 3', 'ok missing owner words names PF-NO-OWNER-WORDS', 'ok a refused init creates no run dir, no root and no latest link'
- [x] `AC-H2` *(human)* run id matches ^[0-9]{8}T[0-9]{6}Z$ (test)
  - observed `2026-10-16` test_init: 'ok run id matches ^[0-9]{8}T[0-9]{6}Z$' and 'ok run.json run_id equals the dir name'
- [x] `AC-H3` *(human)* one brief per enabled seat, one per Proton account with a 2-account config (test)
  - observed `2026-10-16` test_init: 'ok one brief per enabled seat, two for the 2-account Proton config' (gmail linkedin proton-first proton-second), 'ok run.json lists 4 seats'

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
