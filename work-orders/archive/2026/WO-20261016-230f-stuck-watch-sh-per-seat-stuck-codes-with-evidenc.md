---
{
  "id": "WO-20261016-230f",
  "slug": "stuck-watch-sh-per-seat-stuck-codes-with-evidenc",
  "title": "stuck-watch.sh: per-seat stuck codes with evidence onto line.<line>.stuck.<code>, ntfy with 30 min dedupe, heartbeat",
  "type": "feature",
  "status": "done",
  "priority": "p2",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T04:51:54+00:00",
  "parent": "WO-20261016-3570",
  "branch": "feat/stuck-watch-sh-per-seat-stuck-codes-with-evidenc",
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
  "blocks": [
    "WO-20261016-c840",
    "WO-20261016-2d3e",
    "WO-20261016-7ce0"
  ]
}
---

# WO-20261016-230f - stuck-watch.sh: per-seat stuck codes with evidence onto line.<line>.stuck.<code>, ntfy with 30 min dedupe, heartbeat

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

No script codes a stalled seat.

## Scope

**In**

- claude/workflow/stuck-watch/stuck-watch.sh
- claude/workflow/stuck-watch/config.json
- claude/workflow/stuck-watch/lib.sh

**Out - non-goals**

- deadman, audit, Make

## Degrees of freedom

- [free] evidence JSON field names, as long as each code carries seat, pane, observed values and threshold

## Acceptance criteria

- [x] `AC-H1` *(human)* codes STK-001..STK-005 emitted per brief conditions
  - observed `2026-10-16` make stuck-watch-dev: idle, done-unmerged, done-red, signals cases emit STK-001/003/004/005 and A2A-004 on line.t.stuck.<code>; UAT STK-001 and STK-005 on the real bus (/home/luna/.local/state/zenith/log/2026/10/20261016-051034-stuck-watch-uat-stuck-uat.log)
- [x] `AC-H2` *(human)* ntfy POST deduped per seat+code per 30 min, topic never printed
  - observed `2026-10-16` dev dedupe case: 2 ticks, 2 bus messages, 1 POST; no-leak case: canary topic absent from all output; UAT AC4 notifications 1 after 2 bus messages
- [x] `AC-H3` *(human)* heartbeat published every tick
  - observed `2026-10-16` dev idle case: line.t.heartbeat published each tick; UAT deadman log OK heartbeat_age lines before the watcher stopped

## Test plan

```sh
make -C claude/workflow stuck-watch-test
```

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
