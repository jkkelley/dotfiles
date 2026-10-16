---
{
  "id": "WO-20261016-a865",
  "slug": "inbox-sweep-b6-sweep-watch-sh-result-bridge-to-r",
  "title": "Inbox sweep B6 - sweep-watch.sh result bridge to record rows",
  "type": "feature",
  "status": "done",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T01:19:11+00:00",
  "parent": "WO-20261016-1703",
  "branch": "feat/inbox-sweep-b6-sweep-watch-sh-result-bridge-to-r",
  "pr": 117,
  "closed": "2026-10-16",
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

# WO-20261016-a865 - Inbox sweep B6 - sweep-watch.sh result bridge to record rows

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

Seat completion must be decided by a validated result file, never by reading a pane

## Scope

**In**

- the node's files as listed in docs/design/inbox-sweep.md section 10 and docs/design/inbox-sweep.spec.xml build-dag
- bin/sweep-watch.sh and the watch suite

**Out - non-goals**

- sending, replying, deleting or archiving anything in any mailbox
- touching a real mailbox, the owner's Chrome or a real herdr session (B11 only)
- respawn logic already in seat-watch.sh

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [x] `AC-H1` *(human)* truncated JSON is not accepted (test)
  - observed `2026-10-16` test_watch.sh: 'a truncated result produced no row on any poll before it was fixed' ok; 'the seat was asked once to rewrite' ok; a mutation making the size check eager failed 4 checks
- [x] `AC-H2` *(human)* a deadline in the past gives a TIMEOUT row (test)
  - observed `2026-10-16` test_watch.sh: 'no result at the deadline gives one TIMEOUT row' ok; TIMEOUT results for gmail, proton and linkedin validate against result.schema.json
- [x] `AC-H3` *(human)* a valid result gives exactly one record row (test)
  - observed `2026-10-16` test_watch.sh: 'valid result: exactly one record row' ok; 'a second watcher run adds no second row for a final seat' ok; every non-OK code bridges once
- [x] `AC-H4` *(human)* calls.log has no pane read or wait-output
  - observed `2026-10-16` test_watch.sh: 'calls.log has no pane read or wait-output' ok; 'no other herdr call of any kind' ok (only agent prompt)

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
