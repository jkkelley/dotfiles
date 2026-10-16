---
{
  "id": "WO-20261016-24c5",
  "slug": "inbox-sweep-b16-send-seat-brief-declaration-and-",
  "title": "Inbox sweep B16 - send seat brief, declaration and send-result schema",
  "type": "feature",
  "status": "done",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T03:03:20+00:00",
  "parent": "WO-20261016-1703",
  "branch": "feat/inbox-sweep-b16-send-seat-brief-declaration-and-",
  "pr": 128,
  "closed": "2026-10-16",
  "approval": {
    "via": "override",
    "reason": "Owner approved the reply DAG design on Bearings card D-18, 2026-10-16 UTC; Claude seats never use lavish (global owner rule)",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [
    "WO-20261016-a99e",
    "WO-20261016-1130"
  ],
  "blocks": [
    "WO-20261016-4682"
  ]
}
---

# WO-20261016-24c5 - Inbox sweep B16 - send seat brief, declaration and send-result schema

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

A send seat needs a brief naming one file and one thread, and a result contract that refuses two sends

## Scope

**In**

- the node's files as listed in docs/design/inbox-sweep.md sections 10, 14 to 17 and docs/design/linkedin-reply.spec.xml
- templates/brief-linkedin-send.md, schemas/workflows/inbox-sweep-linkedin-send.workflow.json, schemas/send-result.schema.json

**Out - non-goals**

- touching a real LinkedIn thread, mailbox, the owner's Chrome or a real herdr session (B18 only)
- any step that works around the Claude Code auto mode classifier; a denial is RP-DENIED-CLASSIFIER and stops
- the controller (B17b)

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [x] `AC-H1` *(human)* the brief names one file and one thread only (grep in test)
  - observed `2026-10-16` send-seat suite: brief names exactly one 'Approval file:' and one 'Thread URL:' line, hardcodes no URL or send- path, states 'It is given no other file and no other thread'
- [x] `AC-H2` *(human)* the schema refuses a result with two sends (fixture)
  - observed `2026-10-16` send-seat suite: 3 two-send fixtures (array, send_clicks 2, extra field) plus 11 other invalid fixtures all refused; 9 status-code fixtures validate
- [x] `AC-H3` *(human)* the declaration launcher is claude-win-chrome with bypass (make -C claude/workflow schema green)
  - observed `2026-10-16` make -C claude/workflow schema green: declaration models == [claude-win-chrome]; project.json link carries --chrome and --dangerously-skip-permissions (send-seat suite)
- [x] `AC-H4` *(human)* the brief makes the seat wait for the owner's own line before typing (grep in test)
  - observed `2026-10-16` send-seat suite: wait-for-owner-line, open thread, type, click ordered by line number; 'Until that line arrives the seat types nothing into LinkedIn' grep ok; mutation caught

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
