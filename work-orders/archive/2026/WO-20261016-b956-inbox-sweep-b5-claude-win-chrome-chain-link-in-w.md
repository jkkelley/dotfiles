---
{
  "id": "WO-20261016-b956",
  "slug": "inbox-sweep-b5-claude-win-chrome-chain-link-in-w",
  "title": "Inbox sweep B5 - claude-win-chrome chain link in workflow-spawn.sh",
  "type": "feature",
  "status": "done",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T01:19:11+00:00",
  "parent": "WO-20261016-1703",
  "branch": "feat/inbox-sweep-b5-claude-win-chrome-chain-link-in-w",
  "pr": 116,
  "closed": "2026-10-16",
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

# WO-20261016-b956 - Inbox sweep B5 - claude-win-chrome chain link in workflow-spawn.sh

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

Browser seats must start as Windows claude.exe --chrome, which the spawner cannot launch today

## Scope

**In**

- the node's files as listed in docs/design/inbox-sweep.md section 10 and docs/design/inbox-sweep.spec.xml build-dag
- claude/workflow/bin/workflow-spawn.sh launcher branch with a breadcrumb, link entry in claude/workflow/config/project.json, a case in test_model_chain.sh

**Out - non-goals**

- sending, replying, deleting or archiving anything in any mailbox
- touching a real mailbox, the owner's Chrome or a real herdr session (B11 only)
- changing any existing link's behaviour

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [x] `AC-H1` *(human)* --dry-run prints claude.exe --chrome with a cwd under the resolved Windows home (test_model_chain.sh case)
  - observed `2026-10-16` test_model_chain.sh: ok win-chrome launcher is /mnt/c/Users/testuser/.local/bin/claude.exe --chrome ... and pane cd under Windows home first (34 checks)
- [x] `AC-H2` *(human)* make -C claude/workflow chain is green
  - observed `2026-10-16` make -C claude/workflow chain: ok model-chain: 34 checks; lint and schema also green

## Test plan

```sh
make -C claude/workflow chain; make -C claude/workflow lint
```

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
