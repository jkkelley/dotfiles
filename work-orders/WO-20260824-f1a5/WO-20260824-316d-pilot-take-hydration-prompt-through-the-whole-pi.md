---
{
  "id": "WO-20260824-316d",
  "slug": "pilot-take-hydration-prompt-through-the-whole-pi",
  "title": "Pilot: take hydration-prompt through the whole pipeline end to end",
  "type": "chore",
  "status": "ready",
  "priority": "p1",
  "created": "2026-08-24",
  "updated": "2026-08-24",
  "created_at": "2026-08-24T13:19:09-05:00",
  "parent": "WO-20260824-f1a5",
  "branch": null,
  "pr": null,
  "merge_sha": null,
  "closed": null,
  "approval": {
    "via": "override",
    "reason": "Reviewed and approved on PR #55 on GitHub, which is where the whole cut was read as one diff. Lavish was offered and declined in favour of the PR.",
    "at": "2026-08-24"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [
    "WO-20260824-2ad1",
    "WO-20260824-360d",
    "WO-20260824-bb0d"
  ],
  "blocks": [
    "WO-20260824-9712",
    "WO-20260824-d058"
  ]
}
---

# WO-20260824-316d - Pilot: take hydration-prompt through the whole pipeline end to end

## Problem

Every piece of the pipeline has been tested on its own. Nothing has yet proved they compose. hydration-prompt is the right pilot because it ships a test suite, so the matrix is genuinely exercised, and because it is used every session, so a break shows up immediately rather than in three weeks.

## Scope

**In**

- removing the notice from hydration-prompt/SKILL.md and only that file
- opening the PR with the Bump: trailer in the description
- confirming the gate prints the resolution table and runs exactly one matrix leg
- confirming the publisher bumps and regenerates on merge

**Out - non-goals**

- any other skill's notice, which is epic 2
- fixing gate or publisher defects here - those are defects against their own tickets, not scope on this one

## Acceptance criteria


- [ ] `AC-H1` *(human)* main carries a bumped hydration-prompt version that nobody typed by hand
- [ ] `AC-H2` *(human)* the registry on main matches render_registry immediately after the publish run
- [ ] `AC-H3` *(human)* verify is green on main afterwards

## Test plan

_none recorded - Rule 14 says this runs in a container_

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

- `2026-08-24` Poker 2026-08-24: 2 points. Almost no authored work - it is an observation ticket. Deliberately does not absorb gate or publisher rework.

## Outcome

_Written by `work-order close`. Empty until then._
