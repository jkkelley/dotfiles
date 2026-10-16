---
{
  "id": "WO-20261016-4c73",
  "slug": "ci-never-runs-the-inbox-sweep-suites",
  "title": "CI never runs the inbox-sweep suites",
  "type": "bug",
  "status": "done",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T06:37:36+00:00",
  "parent": "WO-20261016-1703",
  "branch": "feat/ci-never-runs-the-inbox-sweep-suites",
  "pr": 197,
  "closed": "2026-10-16",
  "approval": {
    "via": "override",
    "reason": "orchestrator bug fix, item 22, repro attached",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [],
  "blocks": []
}
---

# WO-20261016-4c73 - CI never runs the inbox-sweep suites

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

make -C claude/workflow test (the CI claude/workflow job, skill-pr-gate.yml line 221) has no inbox-sweep prerequisite: grep -c inbox-sweep claude/workflow/Makefile .github/workflows/skill-pr-gate.yml gives 0 and 0. PR 168 merged green with suite lint red (fixed by PR 192).

## Scope

**In**

- claude/workflow/Makefile: test depends on a new inbox-sweep target that runs make -C inbox-sweep test-all

**Out - non-goals**

- changing skill-pr-gate.yml
- changing which inbox-sweep suites exist

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [x] `AC-H1` *(human)* make -n -C claude/workflow test lists the inbox-sweep test-all call
  - observed `2026-10-16` make -n -C claude/workflow inbox-sweep prints: make -s -C inbox-sweep test-all, then podman ... tests/run.sh --all
- [x] `AC-H2` *(human)* suite ci-job ok in podman
  - observed `2026-10-16` make -C claude/workflow ci-job: ok ci-job (podman)

## Test plan

```sh
make -C claude/workflow ci-job; make -n -C claude/workflow test | grep inbox-sweep
```

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
