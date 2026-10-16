---
{
  "id": "WO-20261016-529a",
  "slug": "inbox-sweep-nodes-check-red-on-main-reply-ledger",
  "title": "Inbox sweep nodes-check red on main: reply-ledger.sh names build ticket B21c as its node",
  "type": "bug",
  "status": "in-progress",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T08:21:08+00:00",
  "parent": "WO-20261016-1703",
  "branch": "feat/inbox-sweep-nodes-check-red-on-main-reply-ledger",
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

- [x] `AC-H1` *(human)* nodes-check is green
  - observed `2026-10-16` check: make -C claude/workflow/inbox-sweep nodes-check exit 0 output: make: Entering directory '/home/luna/.cache/wt-dotfiles-sweep-nodefix/claude/workflow/inbox-sweep' ok L1.node.json validates ok L10.node.json validates note L10.node.json is script_pending but claude/workflow/inbox-sweep/templates/brief-linkedin-send.md now exists; drop the flag ok L11.node.json validates ok L12.node.json validates ok L2.node.json validates ok L3.node.json validates note L3.node.json is script_pending but claude/workflow/inbox-sweep/bin/reply-cards.sh now exists; drop the flag ok L4.node.json validates note L4.node.json is script_pending but claude/workflow/inbox-sweep/bin/reply-approve.sh now exists; drop the flag ok L5.node.json validates note L5.node.json is script_pending but claude/workflow/inbox-sweep/bin/reply-approve.sh now exists; drop the flag ok L6.node.json validates ok L6b.node.json validates ok L7.node.json validates note L7.node.json is script_pending but claude/workflow/inbox-sweep/templates/brief-linkedin-send.md now exists; drop the flag ok L8.node.json validates ok L9.node.json validates note L9.node.json is script_pending but claude/workflow/inbox-sweep/templates/brief-linkedin-send.md now exists; drop the flag
  - check: `make -C claude/workflow/inbox-sweep nodes-check` exit 0
- [x] `AC-H2` *(human)* migrate suite is green
  - observed `2026-10-16` check: make -C claude/workflow/inbox-sweep suite SUITE=migrate exit 0 output: make: Entering directory '/home/luna/.cache/wt-dotfiles-sweep-nodefix/claude/workflow/inbox-sweep' ok migrate ran 1 suite make: Leaving directory '/home/luna/.cache/wt-dotfiles-sweep-nodefix/claude/workflow/inbox-sweep'
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
