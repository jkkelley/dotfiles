---
{
  "id": "WO-20261016-d9f4",
  "slug": "inbox-sweep-suites-preflight-init-and-watch-read",
  "title": "Inbox sweep suites preflight, init and watch read per-node steps and checklist files",
  "type": "bug",
  "status": "ready",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T06:54:16+00:00",
  "parent": "WO-20261016-1703",
  "branch": null,
  "pr": null,
  "closed": null,
  "approval": {
    "via": "override",
    "reason": "orchestrator bug ticket, item 22, repro in Problem",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [],
  "blocks": []
}
---

# WO-20261016-d9f4 - Inbox sweep suites preflight, init and watch read per-node steps and checklist files

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

CI run 38862696743 (PR 197, first CI run of inbox-sweep suites) and podman on main: FAIL preflight, FAIL init, FAIL watch. Cases: 'four R2 checklist rows, one per passed box', 'PF-NO-BROWSER: the retried step is recorded in run.json', 'three checklist rows are recorded', 'the two R4 checklist boxes were ticked'. B21f1 (PR 163, WO-20261016-824b) moved sweep_retry rows to <run>/steps/<node>.jsonl and sweep_check rows to <run>/checklist/<node>.jsonl; these tests still read run.json .steps and <run>/checklist.jsonl. They escaped because tests/suites.tsv does not list bin/sweep-lib.sh for these suites.

## Scope

**In**

- tests/unit/test_preflight.sh, tests/unit/test_init.sh, tests/unit/test_watch.sh: read rows from <run>/steps/*.jsonl and <run>/checklist/*.jsonl
- tests/suites.tsv: add bin/sweep-lib.sh to the file lists of preflight, init and watch

**Out - non-goals**

- any change under bin/
- tests/unit/test_send_seat.sh

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [ ] `AC-H1` *(human)* podman tests/run.sh --suite preflight, init and watch each ok
- [ ] `AC-H2` *(human)* suites.tsv lists bin/sweep-lib.sh for preflight, init and watch

## Test plan

```sh
make -C claude/workflow/inbox-sweep test (changed suites)
```

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
