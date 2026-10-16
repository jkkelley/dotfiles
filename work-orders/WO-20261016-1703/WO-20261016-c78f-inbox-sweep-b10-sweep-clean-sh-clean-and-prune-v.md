---
{
  "id": "WO-20261016-c78f",
  "slug": "inbox-sweep-b10-sweep-clean-sh-clean-and-prune-v",
  "title": "Inbox sweep B10 - sweep-clean.sh clean and prune verbs",
  "type": "feature",
  "status": "in-progress",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T01:19:14+00:00",
  "parent": "WO-20261016-1703",
  "branch": "feat/inbox-sweep-b10-sweep-clean-sh-clean-and-prune-v",
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
    "WO-20261016-61ae"
  ]
}
---

# WO-20261016-c78f - Inbox sweep B10 - sweep-clean.sh clean and prune verbs

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

A run's tabs, briefs and seat dirs must be removable, and run dirs must expire after 14 days (design D6)

## Scope

**In**

- the node's files as listed in docs/design/inbox-sweep.md section 10 and docs/design/inbox-sweep.spec.xml build-dag
- bin/sweep-clean.sh and the clean suite

**Out - non-goals**

- sending, replying, deleting or archiving anything in any mailbox
- touching a real mailbox, the owner's Chrome or a real herdr session (B11 only)
- removing config.json or owner-words.md, ever

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [x] `AC-H1` *(human)* prune keeps a 13-day run and removes a 15-day run (test)
  - observed `2026-10-16` test_clean: ok the 13-day run is kept; ok the 15-day run is removed (make test-all: ran 6 suites)
- [x] `AC-H2` *(human)* clean refuses a RUN-RUNNING run (test)
  - observed `2026-10-16` test_clean: ok clean refuses RUN-RUNNING (exit 3); ok a refused clean removes nothing
- [x] `AC-H3` *(human)* clean closes only this run's agent-sweep-* tabs (calls.log)
  - observed `2026-10-16` test_clean: calls.log holds only 'herdr tab close t2'; not linkedin t3 nor lookalike t4

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
