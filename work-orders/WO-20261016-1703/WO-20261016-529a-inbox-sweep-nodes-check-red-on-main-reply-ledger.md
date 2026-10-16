---
{
  "id": "WO-20261016-529a",
  "slug": "inbox-sweep-nodes-check-red-on-main-reply-ledger",
  "title": "Inbox sweep nodes-check red on main: reply-ledger.sh names build ticket B21c as its node",
  "type": "bug",
  "status": "ready",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T08:21:08+00:00",
  "parent": "WO-20261016-1703",
  "branch": null,
  "pr": null,
  "closed": null,
  "approval": {
    "via": "override",
    "reason": "bug fix ticket cut by sweep-build under item 22; Claude seat, lavish prohibited",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [],
  "blocks": [],
  "ac_checks": [
    {
      "index": 1,
      "command": "make -C claude/workflow/inbox-sweep nodes-check",
      "exit": 0,
      "expect": null
    },
    {
      "index": 2,
      "command": "make -C claude/workflow/inbox-sweep suite SUITE=migrate",
      "exit": 0,
      "expect": null
    }
  ],
  "provides": []
}
---

# WO-20261016-529a - Inbox sweep nodes-check red on main: reply-ledger.sh names build ticket B21c as its node

## Contents

- Problem
- Owner words
- Context
- Scope
- Degrees of freedom
- Acceptance criteria
- Test plan
- Assumptions
- Open questions
- Notes
- Outcome

## Problem

make nodes-check fails on main b4d1b2e: 'FAIL reply-ledger.sh names node B21c, which has no declaration in nodes/' (bin/reply-ledger.sh line 3). B21c is a build ticket id, not a design node; the same cause fails 2 AC-H4 cases in the migrate suite. Reported with reproduction by the V1 to V3 seats.

## Owner words

> see a bug, isolate it, and get it fixed as asap, if you don't know how to fix shit, get the fuck out of my way in the proper engineering way

## Context

linkedin-reply.spec.xml line 208 names reply-ledger.sh as owner of ledger.jsonl and names no node; node markers are optional (sweep-cards.sh, the B21e record owner, carries none). Removing the invalid marker invents nothing; naming an L node would be a design decision.

## Scope

**In**

- files touched, and no others: claude/workflow/inbox-sweep/bin/reply-ledger.sh

**Out - non-goals**

- declaring a new node or naming an L node for ledger.jsonl

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [ ] `AC-H1` *(human)* nodes-check is green
  - check: `make -C claude/workflow/inbox-sweep nodes-check` exit 0
- [ ] `AC-H2` *(human)* migrate suite is green
  - check: `make -C claude/workflow/inbox-sweep suite SUITE=migrate` exit 0

## Test plan

```sh
make -C claude/workflow/inbox-sweep nodes-check; make -C claude/workflow/inbox-sweep suite SUITE=migrate
```

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
