---
{
  "id": "WO-20261016-dd0c",
  "slug": "inbox-sweep-b20b-l1-to-l12-and-s1-to-s7-declarat",
  "title": "Inbox sweep B20b - L1 to L12 and S1 to S7 declarations and nodes.lock at run init",
  "type": "feature",
  "status": "done",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T03:03:15+00:00",
  "parent": "WO-20261016-1703",
  "branch": "feat/inbox-sweep-b20b-l1-to-l12-and-s1-to-s7-declarat",
  "pr": 124,
  "closed": "2026-10-16",
  "approval": {
    "via": "override",
    "reason": "Owner approved the reply DAG design on Bearings card D-18, 2026-10-16 UTC; Claude seats never use lavish (global owner rule)",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [
    "WO-20261016-07bb",
    "WO-20261016-4376"
  ],
  "blocks": [
    "WO-20261016-41f2"
  ]
}
---

# WO-20261016-dd0c - Inbox sweep B20b - L1 to L12 and S1 to S7 declarations and nodes.lock at run init

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

Reply and lead nodes need declarations, and a running sweep must stay on the node versions it started with

## Scope

**In**

- the node's files as listed in docs/design/inbox-sweep.md sections 10, 14 to 17 and docs/design/linkedin-reply.spec.xml
- nodes/L1..L12.node.json, nodes/S1..S7.node.json, sweep-init.sh writes nodes.lock/ and run.json node_versions

**Out - non-goals**

- touching a real LinkedIn thread, mailbox, the owner's Chrome or a real herdr session (B18 only)
- any step that works around the Claude Code auto mode classifier; a denial is RP-DENIED-CLASSIFIER and stops
- changing any node's behaviour

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [x] `AC-H1` *(human)* every L and S declaration validates and bottleneck-check lists L6b as the single intended wait (test)
  - observed `2026-10-16` make test-all suite nodes ok: 13 L (L1-L12 + L6b) and 7 S declarations validate; bottleneck-check printed 'intended wait: L6b'; a second Intended wait fails
- [x] `AC-H2` *(human)* init writes nodes.lock/ and node_versions into run.json (test)
  - observed `2026-10-16` make test-all suite init ok: nodes.lock holds every declaration byte-identical, run.json node_versions names all 27 nodes; empty nodes dir exits 1 with no run dir

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
