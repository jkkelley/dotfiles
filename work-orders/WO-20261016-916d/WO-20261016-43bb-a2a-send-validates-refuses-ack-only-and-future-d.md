---
{
  "id": "WO-20261016-43bb",
  "slug": "a2a-send-validates-refuses-ack-only-and-future-d",
  "title": "a2a-send validates, refuses ack-only and future-dated orders, names by artifact store, enqueues",
  "type": "feature",
  "status": "in-progress",
  "priority": "p2",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T05:19:46+00:00",
  "parent": "WO-20261016-916d",
  "branch": "feat/a2a-send-validates-refuses-ack-only-and-future-d",
  "pr": null,
  "closed": null,
  "approval": {
    "via": "override",
    "reason": "Claude seat: owner rule bars Lavish for Claude runtimes; brief BR-20261016-a2a-guard from the architect is the approval",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [],
  "blocks": [
    "WO-20261016-e15b"
  ]
}
---

# WO-20261016-43bb - a2a-send validates, refuses ack-only and future-dated orders, names by artifact store, enqueues

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

P1 P3

## Scope

**In**

- claude/workflow/a2a-guard/a2a-send.sh claude/workflow/a2a-guard/config.json claude/tools/artifact/artifact.conf

**Out - non-goals**

- delivery

## Degrees of freedom

- [free] ack regexes, as long as they live in config.json

## Acceptance criteria

- [ ] `AC-H1` *(human)* ack-only exits 3 A2A-ACK-REFUSED
- [ ] `AC-H2` *(human)* two sends in one second get two paths

## Test plan

```sh
make a2a-guard-test
```

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

- `2026-10-16` Built on feat/a2a-guard, the brief's one branch for this epic; the per-ticket branch start minted was empty and removed.

## Outcome

_Written by `work-order done`. Empty until then._
