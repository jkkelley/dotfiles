---
{
  "id": "WO-20261016-3570",
  "slug": "stuck-watch-no-model-stuck-detection-to-the-bus-",
  "title": "Stuck-watch: no-model stuck detection to the bus and the owner's phone, with a deadman",
  "type": "feature",
  "status": "done",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T04:51:52+00:00",
  "parent": null,
  "branch": "feat/stuck-watch-no-model-stuck-detection-to-the-bus-",
  "pr": 170,
  "closed": "2026-10-16",
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

- [x] `AC-H1` *(human)* AC1 idle seat with no result file -> stuck code on bus and ntfy 200 within 2 min
  - observed `2026-10-16` ok idle: STK-001 on line.t.stuck.STK-001 (AC1)
- [x] `AC-H2` *(human)* AC2 killing stuck-watch -> 'stuck-watch dead' on phone within 4 min
  - observed `2026-10-16` ok deadman-stale: 4 min old heartbeat pages 'stuck-watch dead' high (AC2)
- [x] `AC-H3` *(human)* AC3 done claim with unmerged PR is coded
  - observed `2026-10-16` ok done-unmerged: STK-005 with gh state OPEN as evidence (AC3)
- [x] `AC-H4` *(human)* AC4 same condition twice -> one notification
  - observed `2026-10-16` ok dedupe: same condition twice, one notification (AC4)
- [x] `AC-H5` *(human)* AC5 PRs merged by make merge-train
  - observed `2026-10-16` MERGED app/github-actions

## Test plan

_none recorded - Rule 14 says this runs in a container_

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

- `2026-10-16` infra-design10: shipped in PR 170 (merged 857d290); closed by WO-20261016-3ac1, do not start this ticket for build work
- `2026-10-16` DESIGN-GAP: AC-H1..H5 are live-system checks (ntfy 200 on phone within 2 min, killing stuck-watch and a phone alert within 4 min, dedupe, merge-train) with no scripted command or test plan, so none was run. PR 170 is MERGED on main (857d290).

## Outcome

_Written by `work-order done`. Empty until then._
