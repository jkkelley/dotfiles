---
{
  "id": "WO-20261016-4409",
  "slug": "inbox-sweep-lint-red-on-main-after-b17d",
  "title": "Inbox sweep lint red on main after B17d",
  "type": "bug",
  "status": "ready",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T05:52:44+00:00",
  "parent": "WO-20261016-1703",
  "branch": null,
  "pr": null,
  "closed": null,
  "approval": {
    "via": "override",
    "reason": "orchestrator bug fix, item 22, repro attached",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [],
  "blocks": []
}
---

# WO-20261016-4409 - Inbox sweep lint red on main after B17d

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

make -C claude/workflow/inbox-sweep test, suite lint, fails on main 76c4d39: SC2034 waiting unused (bin/reply-send.sh:526), SC2206 (tests/lib/stub-reply-seat.sh:28), SC2154 a and s (tests/unit/test_reply_send.sh:219). Came in with PR 168. Every inbox-sweep PR that runs lint is red.

## Scope

**In**

- drop the dead waiting variable in reply-send.sh
- read -r -a for modes in stub-reply-seat.sh
- declare a and s local in batchfresh

**Out - non-goals**

- any behaviour change to reply-send.sh

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [ ] `AC-H1` *(human)* suite lint ok in podman
- [ ] `AC-H2` *(human)* suite reply-send ok in podman

## Test plan

```sh
make -C claude/workflow/inbox-sweep test (changed suites: lint, reply-send)
```

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
