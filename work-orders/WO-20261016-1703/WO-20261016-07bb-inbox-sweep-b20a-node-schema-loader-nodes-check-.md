---
{
  "id": "WO-20261016-07bb",
  "slug": "inbox-sweep-b20a-node-schema-loader-nodes-check-",
  "title": "Inbox sweep B20a - node schema, loader, nodes-check and bottleneck-check with R1 to R7 declared",
  "type": "feature",
  "status": "in-progress",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T03:03:14+00:00",
  "parent": "WO-20261016-1703",
  "branch": "feat/inbox-sweep-b20a-node-schema-loader-nodes-check-",
  "pr": null,
  "closed": null,
  "approval": {
    "via": "override",
    "reason": "Owner approved the reply DAG design on Bearings card D-18, 2026-10-16 UTC; Claude seats never use lavish (global owner rule)",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [
    "WO-20261016-c8c8"
  ],
  "blocks": [
    "WO-20261016-dd0c",
    "WO-20261016-dd75"
  ]
}
---

# WO-20261016-07bb - Inbox sweep B20a - node schema, loader, nodes-check and bottleneck-check with R1 to R7 declared

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

Nodes have no declaration files, so changing a node means editing prose and code with nothing to check them against

## Scope

**In**

- the node's files as listed in docs/design/inbox-sweep.md sections 10, 14 to 17 and docs/design/linkedin-reply.spec.xml
- schemas/node.schema.json, bin/node-lib.sh, nodes/R1..R7.node.json, Makefile targets nodes-check and bottleneck-check

**Out - non-goals**

- touching a real LinkedIn thread, mailbox, the owner's Chrome or a real herdr session (B18 only)
- any step that works around the Claude Code auto mode classifier; a denial is RP-DENIED-CLASSIFIER and stops
- L and S node declarations (B20b)
- nodes.lock at init (B20b)

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [x] `AC-H1` *(human)* each declaration validates against node.schema.json (test)
  - observed `2026-10-16` test_nodes.sh: ok R1..R7 .node.json validates (make nodes-check); malformed declarations refused (ok AC-H1)
- [x] `AC-H2` *(human)* a script naming an undeclared node fails nodes-check (test)
  - observed `2026-10-16` test_nodes.sh: ok AC-H2 a script naming undeclared node R8 fails nodes-check, names rogue.sh and R8
- [x] `AC-H3` *(human)* a serial node with no reason fails bottleneck-check (test)
  - observed `2026-10-16` test_nodes.sh: ok AC-H3 serial node with empty reason fails bottleneck-check, names R5
- [x] `AC-H4` *(human)* the design table and a declaration that disagree fail nodes-check (test)
  - observed `2026-10-16` test_nodes.sh: ok AC-H4 edited design table and edited declaration each fail nodes-check, naming the node

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
