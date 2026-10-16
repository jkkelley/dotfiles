---
{
  "id": "WO-20261016-3570",
  "slug": "stuck-watch-no-model-stuck-detection-to-the-bus-",
  "title": "Stuck-watch: no-model stuck detection to the bus and the owner's phone, with a deadman",
  "type": "feature",
  "status": "ready",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T04:51:52+00:00",
  "parent": null,
  "branch": null,
  "pr": null,
  "closed": null,
  "approval": {
    "via": "override",
    "reason": "Claude seat: lavish is prohibited outside firstmate (~/AGENTS.md owner interaction surface); brief BR-20261016-stuck-watch from the architect is the approval",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [],
  "blocks": []
}
---

# WO-20261016-3570 - Stuck-watch: no-model stuck detection to the bus and the owner's phone, with a deadman

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

Owner: 'what really ensure things are stuck? i dont trust you or agents or humans' and 'ensure it goes to my phone'. Nothing independent of agents detects a stalled seat or a false done claim.

## Scope

**In**

- stuck-watch.sh, deadman.sh plus systemd --user timer, stuck-audit, Make targets, monitors.json entry

**Out - non-goals**

- any model call
- changing herdr-bus or line-watch

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [ ] `AC-H1` *(human)* AC1 idle seat with no result file -> stuck code on bus and ntfy 200 within 2 min
- [ ] `AC-H2` *(human)* AC2 killing stuck-watch -> 'stuck-watch dead' on phone within 4 min
- [ ] `AC-H3` *(human)* AC3 done claim with unmerged PR is coded
- [ ] `AC-H4` *(human)* AC4 same condition twice -> one notification
- [ ] `AC-H5` *(human)* AC5 PRs merged by make merge-train

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
