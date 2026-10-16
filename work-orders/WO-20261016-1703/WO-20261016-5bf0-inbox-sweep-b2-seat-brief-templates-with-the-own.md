---
{
  "id": "WO-20261016-5bf0",
  "slug": "inbox-sweep-b2-seat-brief-templates-with-the-own",
  "title": "Inbox sweep B2 - seat brief templates with the owner-words block",
  "type": "feature",
  "status": "in-progress",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T01:19:09+00:00",
  "parent": "WO-20261016-1703",
  "branch": "feat/inbox-sweep-b2-seat-brief-templates-with-the-own",
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
    "WO-20261016-4376"
  ]
}
---

# WO-20261016-5bf0 - Inbox sweep B2 - seat brief templates with the owner-words block

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

Each seat needs a brief carrying the owner's words, the forbidden-action list and its result path

## Scope

**In**

- the node's files as listed in docs/design/inbox-sweep.md section 10 and docs/design/inbox-sweep.spec.xml build-dag
- templates/brief-gmail.md, brief-proton.md, brief-linkedin.md and the briefs suite

**Out - non-goals**

- sending, replying, deleting or archiving anything in any mailbox
- touching a real mailbox, the owner's Chrome or a real herdr session (B11 only)
- rendering the templates (B3)

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [x] `AC-H1` *(human)* each template holds the owner-words block (test grep)
  - observed `2026-10-16` briefs suite: ok for 3 templates - one owner-words block each, holding ${OWNER_WORDS}, before the forbidden list (53 checks ok)
- [x] `AC-H2` *(human)* the forbidden-action list is verbatim from the spec rules (test diff)
  - observed `2026-10-16` briefs suite: forbidden list diff against spec rules no-send, untrusted, own-tab, no-credentials is empty for all 3; a reworded no-send rule makes the diff fail
- [x] `AC-H3` *(human)* no em dash and one sentence per line (test grep)
  - observed `2026-10-16` briefs suite: 0 em dashes and 0 lines with two sentences in all 3 templates; planted dash and two-sentence line are caught

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
