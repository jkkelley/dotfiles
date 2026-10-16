---
{
  "id": "WO-20261016-73cd",
  "slug": "workflow-spawn-sh-refuses-every-inbox-sweep-and-",
  "title": "workflow-spawn.sh refuses every inbox sweep and send seat: no seat named in project.json",
  "type": "bug",
  "status": "done",
  "priority": "p0",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T04:15:47+00:00",
  "parent": "WO-20261016-1703",
  "branch": "feat/workflow-spawn-sh-refuses-every-inbox-sweep-and-",
  "pr": 149,
  "closed": "2026-10-16",
  "approval": {
    "via": "override",
    "reason": "Architect ruling R1, 2026-10-16T04:25Z",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [
    "WO-20261016-61ae",
    "WO-20261016-4682"
  ],
  "blocks": [
    "WO-20261016-e2e8",
    "WO-20261016-80aa"
  ]
}
---

# WO-20261016-73cd - workflow-spawn.sh refuses every inbox sweep and send seat: no seat named in project.json

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

Live runs cannot start a single seat. Repro on main a358bfa, in Podman on localhost/dotfiles-workflow-test:1 with --network=none: 'bash claude/workflow/bin/workflow-spawn.sh inbox-sweep-gmail gmail --brief-file b.md --ticket IS-x --dry-run' prints 'workflow: no seat named gmail in claude/workflow/config/project.json'; the same for 'inbox-sweep-proton proton-work' and 'inbox-sweep-linkedin-send reply-x'. project.json declares only builder, reviewer, orch-builder, architect, smoke. Callers: claude/workflow/inbox-sweep/bin/sweep.sh line 161 and reply-send.sh SWEEP_SEAT_START default. Tests stub the spawner (SWEEP_SPAWN, SWEEP_SEAT_START), so no suite sees it. Blocks B11 and B18.

## Scope

**In**

- a way for the spawner to accept seats whose names come from run-time config (one per Proton account, one per approved reply), with the fix and a test that runs the real spawner with --dry-run for each sweep seat kind

**Out - non-goals**

- writing owner account names into the public repo
- touching a real mailbox, browser or herdr session

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [x] `AC-H1` *(human)* workflow-spawn.sh --dry-run succeeds for gmail, a proton account seat, linkedin and a reply send seat (test, real spawner, no stub)
  - observed `2026-10-16` tests/unit/test_seats.sh in Podman, network none: the real workflow-spawn.sh --dry-run accepts gmail, two proton account seats, linkedin, agent-reply-abc123 and agent-reply-clear-abc123 from the run-local config (6 ok), and still refuses gmail against the tracked project.json alone (the bug, reproduced)
- [x] `AC-H2` *(human)* no owner account name appears in any tracked file (grep)
  - observed `2026-10-16` test_seats.sh asserts the tracked project.json seat list is unchanged (ok); the diff adds no account name, only the fixture labels acct-a and acct-b inside the test

## Test plan

```sh
make -C claude/workflow chain; make -C claude/workflow/inbox-sweep test (changed suites only)
```

## Assumptions

_none_

## Open questions

- [x] Which shape: a run-local seat overlay passed to the spawner (--seats-file), fixed generic seat names mapped to accounts at run time, or the spawner accepting an inline seat spec? Needs a design ruling (design first, item 20).
  - answer `2026-10-16` Architect ruling R1, 2026-10-16T04:25Z: fix as config, no edit to workflow-spawn.sh. Seat names are run-time and Proton labels are owner data, so each run writes a run-local copy of project.json declaring its seats and passes it through the spawner's existing WORKFLOW_CONFIG override.

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
