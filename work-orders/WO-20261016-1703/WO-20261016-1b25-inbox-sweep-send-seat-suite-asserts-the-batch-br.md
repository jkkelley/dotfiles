---
{
  "id": "WO-20261016-1b25",
  "slug": "inbox-sweep-send-seat-suite-asserts-the-batch-br",
  "title": "Inbox sweep send-seat suite asserts the batch brief from B17d",
  "type": "bug",
  "status": "ready",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T06:54:22+00:00",
  "parent": "WO-20261016-1703",
  "branch": null,
  "pr": null,
  "closed": null,
  "approval": {
    "via": "override",
    "reason": "orchestrator bug ticket, item 22, repro in Problem",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [],
  "blocks": []
}
---

# WO-20261016-1b25 - Inbox sweep send-seat suite asserts the batch brief from B17d

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

CI run 38862696743 and podman on main: FAIL send-seat, 13 cases, for example 'the brief names exactly one approval file line', 'the brief makes the seat wait for the owner's line send <id>'. B17d (PR 168, WO-20261016-c606) rewrote templates/brief-linkedin-send.md to one seat and one owner line 'Send them' per batch (design docs/design/inbox-sweep.md section 18.4, ruling R4); tests/unit/test_send_seat.sh still asserts the one-message brief.

## Scope

**In**

- tests/unit/test_send_seat.sh: assert the batch brief exactly as design 18.4 and templates/brief-linkedin-send.md on main state it

**Out - non-goals**

- templates/brief-linkedin-send.md and anything under bin/
- tests/suites.tsv

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [ ] `AC-H1` *(human)* podman tests/run.sh --suite send-seat ok
- [ ] `AC-H2` *(human)* every removed assertion has a batch-form replacement that fails if the template drops that rule

## Test plan

```sh
make -C claude/workflow/inbox-sweep test (changed suites)
```

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
