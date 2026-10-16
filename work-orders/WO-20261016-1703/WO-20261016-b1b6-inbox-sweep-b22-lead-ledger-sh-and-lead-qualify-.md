---
{
  "id": "WO-20261016-b1b6",
  "slug": "inbox-sweep-b22-lead-ledger-sh-and-lead-qualify-",
  "title": "Inbox sweep B22 - lead-ledger.sh and lead-qualify.sh",
  "type": "feature",
  "status": "ready",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T03:03:24+00:00",
  "parent": "WO-20261016-1703",
  "branch": null,
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
    "WO-20261016-1130"
  ],
  "blocks": [
    "WO-20261016-a47c"
  ]
}
---

# WO-20261016-b1b6 - Inbox sweep B22 - lead-ledger.sh and lead-qualify.sh

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

Inbound LinkedIn threads are not tracked as leads, and nothing decides which deserve a reply

## Scope

**In**

- the node's files as listed in docs/design/inbox-sweep.md sections 10, 14 to 17 and docs/design/linkedin-reply.spec.xml
- bin/lead-ledger.sh, bin/lead-qualify.sh, leads.jsonl, their suites (design 17)

**Out - non-goals**

- touching a real LinkedIn thread, mailbox, the owner's Chrome or a real herdr session (B18 only)
- any step that works around the Claude Code auto mode classifier; a denial is RP-DENIED-CLASSIFIER and stops
- inventing a rubric; it is read from owner-words.md

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [ ] `AC-H1` *(human)* every inbound thread gets exactly one LD- row (test)
- [ ] `AC-H2` *(human)* a thread the rubric rejects gets LD-NOT-A-FIT and no draft (test)
- [ ] `AC-H3` *(human)* the rubric is read from the file, never inlined (grep)
- [ ] `AC-H4` *(human)* every record this ticket writes carries an integer schema_version (design 15.2) (test)

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
