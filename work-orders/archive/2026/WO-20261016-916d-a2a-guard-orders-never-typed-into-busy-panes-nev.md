---
{
  "id": "WO-20261016-916d",
  "slug": "a2a-guard-orders-never-typed-into-busy-panes-nev",
  "title": "A2A guard - orders never typed into busy panes, never ack-only, never hand-named",
  "type": "feature",
  "status": "done",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T05:19:45+00:00",
  "parent": null,
  "branch": "feat/a2a-guard-orders-never-typed-into-busy-panes-nev",
  "pr": 175,
  "closed": "2026-10-16",
  "approval": {
    "via": "override",
    "reason": "Claude seat: owner rule bars Lavish for Claude runtimes; brief BR-20261016-a2a-guard from the architect is the approval",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [],
  "blocks": []
}
---

# WO-20261016-916d - A2A guard - orders never typed into busy panes, never ack-only, never hand-named

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

P1 orders typed into busy panes sat 18-25 min; P2 auto-merge refused on all repos; P3 same-minute hand-named order files overwrote each other (brief BR-20261016-a2a-guard)

## Scope

**In**

- a2a-send, a2a-deliver, a2a-lint CI check, repo-settings-check, dev and UAT gates

**Out - non-goals**

- the merge-on-green workflow itself (merge-port owns it)

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [x] `AC-H1` *(human)* AC1 a2a-send to a working seat enqueues and delivers exactly one line when it goes idle
  - observed `2026-10-16` make a2a-uat 2026-10-16T05:26Z: before agent_status=working, 2x A2A-HELD; after agent_status=idle, A2A-DELIVERED count=2, received.txt 1 line with both pointers; evidence ~/.local/state/zenith/log/2026/10/20261016-052639-a2a-guard-uat.log
- [x] `AC-H2` *(human)* AC2 an ack-only order is refused with A2A-ACK-REFUSED
  - observed `2026-10-16` make a2a-guard-test: ok AC2 ack-only order refused with A2A-ACK-REFUSED (exit 3); ok an AC that asks for an ack is refused (exit 3)
- [x] `AC-H3` *(human)* AC3 two sends in the same second get two distinct artifact paths
  - observed `2026-10-16` make a2a-guard-test: ok AC3 two sends in one second, two distinct artifact paths (xargs -P2, same YYYYMMDD-HHMMSS prefix, different random tails)
- [x] `AC-H4` *(human)* AC4 CI fails a script that calls herdr pane send-text directly
  - observed `2026-10-16` make a2a-guard-test: ok AC4 lint fails a raw send-text (exit 1) - A2A-RAW-SEND claude/x/bad.sh:2; make a2a-lint on the tree: A2A-LINT-OK 222 files

## Test plan

_none recorded - Rule 14 says this runs in a container_

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

- `2026-10-16` Built on feat/a2a-guard, the brief's one branch for this epic; the per-ticket branch start minted was empty and removed.

## Outcome

_Written by `work-order done`. Empty until then._
