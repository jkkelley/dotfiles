---
{
  "id": "WO-20261016-bb3b",
  "slug": "inbox-sweep-b0-test-harness-stubs-and-make-test-",
  "title": "Inbox sweep B0 - test harness, stubs and make test selection",
  "type": "feature",
  "status": "done",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T01:19:07+00:00",
  "parent": "WO-20261016-1703",
  "branch": "feat/inbox-sweep-b0-test-harness-stubs-and-make-test-",
  "pr": 107,
  "closed": "2026-10-16",
  "approval": {
    "via": "override",
    "reason": "Owner approved the design on Bearings card D-04, 2026-10-16 UTC; Claude seats never use lavish (global owner rule)",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [],
  "blocks": [
    "WO-20261016-c8c8",
    "WO-20261016-5bf0",
    "WO-20261016-f390",
    "WO-20261016-b956",
    "WO-20261016-c78f",
    "WO-20261016-a99e",
    "WO-20261016-75d9"
  ]
}
---

# WO-20261016-bb3b - Inbox sweep B0 - test harness, stubs and make test selection

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

No sweep code can be tested without stub herdr and stub claude.exe and a runner that selects changed suites

## Scope

**In**

- the node's files as listed in docs/design/inbox-sweep.md section 10 and docs/design/inbox-sweep.spec.xml build-dag
- tests/lib stubs logging to $TEST_OUT/calls.log, bin/sweep-lib.sh (sweep_retry, sweep_check), tests/run.sh --changed|--all|--suite, tests/suites.tsv, Makefile targets test, test-all, herdr-first
- a container-sandbox skill-testing.md section for stubbed Windows binaries if none exists

**Out - non-goals**

- sending, replying, deleting or archiving anything in any mailbox
- touching a real mailbox, the owner's Chrome or a real herdr session (B11 only)
- any sweep verb beyond the test targets (B9)

## Degrees of freedom

- [free] stub internals, as long as every call is one line in calls.log

## Acceptance criteria

- [x] `AC-H1` *(human)* stub herdr and stub claude.exe log every call to calls.log (unit test asserts the lines)
  - observed `2026-10-16` test_stubs.sh in Podman: 11 ok, 0 FAIL; 'herdr tab create --label agent-sweep-gmail' and 'claude.exe -p --chrome --model haiku list_connected_browsers' each logged as one line in calls.log; newline in an argument stays on one line
- [x] `AC-H2` *(human)* sweep_retry runs an always-failing command exactly 3 times with waits 10, 30, 90 (overridable in tests), exits 1 and records the step
  - observed `2026-10-16` test_lib.sh in Podman: 25 ok, 0 FAIL; always-failing command ran exactly 3 times, exit 1, step recorded failed attempts=3 in run.json. Waits actually taken were 10 and 30 (no sleep after the final failure); 90 is reached only by a 4-attempt caller, which the test also asserts
- [x] `AC-H3` *(human)* make test with no change against origin/main prints ran 0 suites
  - observed `2026-10-16` make -C claude/workflow/inbox-sweep test BASE=HEAD printed 'ran 0 suites', exit 0; test_select.sh also asserts the exact line with SWEEP_CHANGED empty. Default BASE is origin/main
- [x] `AC-H4` *(human)* make herdr-first is red on a planted ampersand fixture and green on the real bin/
  - observed `2026-10-16` make herdr-first on real bin/: 'ok herdr-first / ran 1 suite'. With SWEEP_BIN_DIR at a planted 'sleep 5 &' script: 'FAIL: .../bad.sh backgrounds a process (Rule 18): 1:sleep 5 &', 'ran 1 suite, 1 failed', make exit 2

## Test plan

```sh
podman run on localhost/dotfiles-workflow-test:1 (claude/workflow/tests/container/Containerfile, pinned): bash tests/run.sh --all; then make -C claude/workflow/inbox-sweep test-all
```

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
