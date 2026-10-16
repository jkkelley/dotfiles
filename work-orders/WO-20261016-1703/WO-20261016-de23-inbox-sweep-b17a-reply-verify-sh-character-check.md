---
{
  "id": "WO-20261016-de23",
  "slug": "inbox-sweep-b17a-reply-verify-sh-character-check",
  "title": "Inbox sweep B17a - reply-verify.sh character check and token",
  "type": "feature",
  "status": "in-progress",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T03:03:21+00:00",
  "parent": "WO-20261016-1703",
  "branch": "feat/inbox-sweep-b17a-reply-verify-sh-character-check",
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
    "WO-20261016-4682"
  ]
}
---

# WO-20261016-de23 - Inbox sweep B17a - reply-verify.sh character check and token

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

Send must never be clicked unless a script proved the typed text equals the approved file

## Scope

**In**

- the node's files as listed in docs/design/inbox-sweep.md sections 10, 14 to 17 and docs/design/linkedin-reply.spec.xml
- bin/reply-verify.sh with one written newline rule, its suite

**Out - non-goals**

- touching a real LinkedIn thread, mailbox, the owner's Chrome or a real herdr session (B18 only)
- any step that works around the Claude Code auto mode classifier; a denial is RP-DENIED-CLASSIFIER and stops
- the controller (B17b)

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [x] `AC-H1` *(human)* a one-character mismatch writes no token and gives RP-TEXT-MISMATCH (test)
  - observed `2026-10-16` test_reply_verify.sh: 11 one-character/near-match cases (changed, dropped, added char, case, curly apostrophe, trailing space...) each exit 1, print RP-TEXT-MISMATCH, and remove a planted stale token; suite ok in make test-all (20 suites)
- [x] `AC-H2` *(human)* an exact match writes verified-<id>.token (test)
  - observed `2026-10-16` test_reply_verify.sh: exact match exits 0, prints RP-VERIFIED <id> <sha256>, writes verified-m1.token with integer schema_version 1; CRLF, lone CR and one final LF also pass

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
