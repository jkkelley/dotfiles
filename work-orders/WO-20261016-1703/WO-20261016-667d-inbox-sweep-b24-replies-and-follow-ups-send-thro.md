---
{
  "id": "WO-20261016-667d",
  "slug": "inbox-sweep-b24-replies-and-follow-ups-send-thro",
  "title": "Inbox sweep B24 - replies and follow-ups send through the shared ypli jitter scheduler",
  "type": "feature",
  "status": "draft",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T07:56:08+00:00",
  "parent": "WO-20261016-1703",
  "branch": null,
  "pr": null,
  "closed": null,
  "approval": null,
  "evidence": null,
  "surfaces": [],
  "depends_on": [],
  "blocks": [
    "WO-20261016-c065",
    "WO-20261016-93d3"
  ],
  "labels": [
    "line:inbox-triage"
  ]
}
---

# WO-20261016-667d - Inbox sweep B24 - replies and follow-ups send through the shared ypli jitter scheduler

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

Orchestrator orders MSG-20261016-0549 O2 and batch-0555 B2 (~/AGENTS.md LinkedIn, Post timing): LinkedIn replies and follow-ups use the shared scheduler config and script of the yp-line content engine, never a second mechanism, and send inside the jitter window, never in a burst. reply-send.sh sends an approved batch at once today.

## Scope

**In**

- bin/reply-send.sh: before starting the send seat, call `<ypli> jitter plan` with the batch and wait until each planned time; path from config.json key ypli_bin
- bin/lead-followup.sh: the same call for follow-ups
- tests/unit/test_reply_jitter.sh with a stub ypli; tests/suites.tsv row reply-jitter

**Out - non-goals**

- any scheduler logic in dotfiles (one mechanism, owned by yp-line)
- bin/reply-cards.sh

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [ ] `AC-H1` *(human)* suite reply-jitter ok in podman
- [ ] `AC-H2` *(human)* a failing scheduler records RP-SCHEDULE-FAILED and starts no send seat

## Test plan

```sh
bash claude/workflow/inbox-sweep/tests/run.sh --suite reply-jitter
```

## Assumptions

_none_

## Open questions

- [ ] Input missing: the CLI contract of `ypli jitter plan` (args, output) is defined by business WO-20261016-46f2 - C14a: ypli jitter plan and apply with per-channel config and gates, not merged (business PR 69). Cut-time inputs are incomplete until it merges (item 30).

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
