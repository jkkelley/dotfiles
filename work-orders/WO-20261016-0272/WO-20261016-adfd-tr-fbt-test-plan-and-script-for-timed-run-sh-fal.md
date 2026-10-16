---
{
  "id": "WO-20261016-adfd",
  "slug": "tr-fbt-test-plan-and-script-for-timed-run-sh-fal",
  "title": "TR-FBt: test plan and script for timed-run.sh --fallback",
  "type": "test",
  "status": "ready",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T06:18:12+00:00",
  "parent": "WO-20261016-0272",
  "branch": null,
  "pr": null,
  "closed": null,
  "approval": {
    "via": "override",
    "reason": "architect ruled design approvals done, ORD-0550 O4",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [
    "WO-20261016-d304"
  ],
  "blocks": []
}
---

# WO-20261016-adfd - TR-FBt: test plan and script for timed-run.sh --fallback

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

Test sibling of TR-FB. The tester runs exactly this plan from ~/dotfiles on the TR-FB branch and nothing else. Orchestrator orders 2026-10-16 (MSG-20261016T061019Z-yp-design): ORD-0552 O2 'write each AC as command + expected exit code + expected output in the ticket text, and carry owner words verbatim and full context in Problem'; ORD-0555 O1 'before a ticket goes ready, list every tool, script, Make target and fixture its steps and AC checks call; any not on main gets a tooling ticket first'; ORD-0556 O1 'every tooling ticket builds a generic, config-driven tool in dotfiles'; ORD-0558 O1 'every design and ready ticket names the fallback for each tool and dependency it uses, the scripted switch with its status code, and a test case for the fallback path'.

## Scope

**In**

- Run every case below from ~/dotfiles
- Evidence: the output of every case, written to the path printed by `make -s -C ~/dotfiles artifact-new KEY=log NAME=tr-fb-test EXT=log` (fallback FB-004: `bash ~/dotfiles/claude/tools/artifact/artifact.sh new` with the same KEY NAME EXT)

**Out - non-goals**

- Editing any file; a failing case is a note on the build ticket with its output

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [ ] `AC-H1` *(human)* Every case passes: each case's command exits as its expected line says. Proof: the evidence log path on this ticket

## Test plan

_Test plan from claude/workflow/templates/test-plan.md, shaped by claude/workflow/schemas/test-plan.schema.json. The tester runs exactly these cases and nothing else._

**Scope under test**

timed-run.sh --fallback

**Cases**

- `TP-1`
  - intent: without the switch every ticket hand-writes its own fallback and nothing is coded
  - command: `podman run --rm --network=none --userns=keep-id -v $PWD:/work:Z -w /work -e HOME=/tmp localhost/dotfiles-workflow-test:1 bash claude/workflow/tests/unit/test_timed_run_fallback.sh`
  - expected: exit 0, no FAIL line
- `TP-2`
  - intent: the forced path is what every ticket's fallback test case runs
  - command: `FORCE_FALLBACK=1 bash claude/workflow/bin/timed-run.sh --node tp --fallback 'true' --fallback-code FB-001 -- false`
  - expected: exit 0, stderr contains FALLBACK FB-001 tp
- `TP-3`
  - intent: an existing caller without --fallback must not change (no regression)
  - command: `podman run --rm --network=none --userns=keep-id -v $PWD:/work:Z -w /work -e HOME=/tmp localhost/dotfiles-workflow-test:1 bash claude/workflow/timing/tests/test_timing.sh`
  - expected: exit 0
- `TP-4`
  - intent: fallback path of this plan itself: the test image is cached when the build cannot pull
  - command: `podman image exists localhost/dotfiles-workflow-test:1 || echo FB-001`
  - expected: exit 0

**Isolation**

- runtime: podman
- image: `docker.io/library/debian@sha256:3783cc01769c7b2b1b83a5c5ad96c815348e28ed7da68e2e3687004faa906251` (debian:bookworm-slim, the FROM of claude/workflow/tests/container/Containerfile, built as localhost/dotfiles-workflow-test:1 by make -C ~/dotfiles/claude/workflow image)

**Out of scope - CI covers**

- lint and the full suite run in CI

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
