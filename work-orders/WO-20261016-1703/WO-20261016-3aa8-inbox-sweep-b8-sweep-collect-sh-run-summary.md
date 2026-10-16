---
{
  "id": "WO-20261016-3aa8",
  "slug": "inbox-sweep-b8-sweep-collect-sh-run-summary",
  "title": "Inbox sweep B8 - sweep-collect.sh run summary",
  "type": "feature",
  "status": "in-progress",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T01:19:13+00:00",
  "parent": "WO-20261016-1703",
  "branch": "feat/inbox-sweep-b8-sweep-collect-sh-run-summary",
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
    "WO-20261016-c8c8"
  ],
  "blocks": [
    "WO-20261016-61ae"
  ]
}
---

# WO-20261016-3aa8 - Inbox sweep B8 - sweep-collect.sh run summary

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

A run must end in one summary.json and summary.md with a derived run code

## Scope

**In**

- the node's files as listed in docs/design/inbox-sweep.md section 10 and docs/design/inbox-sweep.spec.xml build-dag
- bin/sweep-collect.sh and the collect suite

**Out - non-goals**

- sending, replying, deleting or archiving anything in any mailbox
- touching a real mailbox, the owner's Chrome or a real herdr session (B11 only)
- cards (B7)

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [x] `AC-H1` *(human)* each row of the spec's codes/run derive table has a fixture (test, 5 cases)
  - observed `2026-10-16` test_collect.sh printed ok for derive 1 (3 cases: --controller-error, PF-NO-HERDR, PF-NO-OWNER-WORDS), derive 2 RUN-OK, derive 3 RUN-PARTIAL, derive 4 RUN-BLOCKED (BLOCKED-* and SKIPPED), derive 5 RUN-FAILED; make test-all ran 11 suites, collect ok
- [x] `AC-H2` *(human)* summary.md has a contents list and no em dash (test grep)
  - observed `2026-10-16` test_collect.sh printed ok: AC-H2 summary.md has no em dash though the result text had one; has a Contents heading listing each source; lint suite clean

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
