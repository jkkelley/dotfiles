---
{
  "id": "WO-20261016-93d3",
  "slug": "inbox-sweep-b25-reply-and-follow-up-drafts-pass-",
  "title": "Inbox sweep B25 - reply and follow-up drafts pass the shared ypli style lint and preview",
  "type": "feature",
  "status": "draft",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T07:56:19+00:00",
  "parent": "WO-20261016-1703",
  "branch": null,
  "pr": null,
  "closed": null,
  "approval": null,
  "evidence": null,
  "surfaces": [],
  "depends_on": [
    "WO-20261016-667d"
  ],
  "blocks": [
    "WO-20261016-dc6b"
  ]
}
---

# WO-20261016-93d3 - Inbox sweep B25 - reply and follow-up drafts pass the shared ypli style lint and preview

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

Orchestrator orders MSG-20261016-0513 O2, MSG-20261016-0553 O3 and batch-0516 B1 (~/AGENTS.md LinkedIn, Look): replies and follow-ups use the same voice rules, style lint and approval preview as the content engine, one shared config and script.

## Scope

**In**

- bin/reply-cards.sh: run `<ypli> lint style` on each draft; a failing draft gets RP-STYLE-FAILED and no card; the card body is `<ypli> preview` output; path from config.json key ypli_bin
- bin/lead-followup.sh: the same for follow-up drafts
- tests/unit/test_reply_look.sh with a stub ypli; tests/suites.tsv row reply-look

**Out - non-goals**

- style rules or banned phrases in dotfiles (owned by yp-line style.json)
- bin/reply-send.sh

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [ ] `AC-H1` *(human)* suite reply-look ok in podman
- [ ] `AC-H2` *(human)* a draft failing the stub lint never becomes a card

## Test plan

```sh
bash claude/workflow/inbox-sweep/tests/run.sh --suite reply-look
```

## Assumptions

_none_

## Open questions

- [ ] Input missing: the CLI contracts of `ypli lint style` and the preview renderer are defined by business WO-20261016-19c9 - C16a: ypli lint style script that fails a draft breaking the style spec and WO-20261016-842b - C17a: approval preview renderer for the Bearings card body, not merged (business PR 69).

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
