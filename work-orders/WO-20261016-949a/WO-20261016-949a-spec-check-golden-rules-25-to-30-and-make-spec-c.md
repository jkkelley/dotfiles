---
{
  "id": "WO-20261016-949a",
  "slug": "spec-check-golden-rules-25-to-30-and-make-spec-c",
  "title": "Spec check - golden rules 25 to 30 and make spec-check",
  "type": "feature",
  "status": "ready",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T04:42:27+00:00",
  "parent": null,
  "branch": null,
  "pr": null,
  "closed": null,
  "approval": {
    "via": "override",
    "reason": "owner: i approved of everything (brief BR-20261016-spec-check)",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [],
  "blocks": []
}
---

# WO-20261016-949a - Spec check - golden rules 25 to 30 and make spec-check

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

Owner item 28 orders every XML spec to be 1000 lines or less, parse, and open with a contents element, enforced by a fast make spec-check in CI; the golden rules block lacks items 25 to 30.

## Scope

**In**

_none_

**Out - non-goals**

- golden rules block carries items 25 to 30 in dotfiles and every ~/projects repo
- make spec-check gates changed XML specs in the fast PR check

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [ ] `AC-H1` *(human)* both child PRs merged by make merge-train

## Test plan

_none recorded - Rule 14 says this runs in a container_

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
