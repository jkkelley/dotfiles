---
{
  "id": "WO-20261016-8590",
  "slug": "test-timed-run-every-target-of-claude-workflow-m",
  "title": "Test - timed-run: every target of claude/workflow/mk/resources.mk runs through the timing wrapper",
  "type": "test",
  "status": "in-progress",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T06:05:58+00:00",
  "parent": "WO-20261016-af17",
  "branch": "feat/8590-test-timed-run-every-target-of-claude-workflow-m",
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
    "WO-20261016-7ca5"
  ],
  "blocks": [],
  "labels": [
    "line:inbox-triage"
  ]
}
---

# WO-20261016-8590 - Test - timed-run: every target of claude/workflow/mk/resources.mk runs through the timing wrapper

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

Run the filled test plan of WO-20261016-7ca5 - timed-run: every target of claude/workflow/mk/resources.mk runs through the timing wrapper exactly as written; dev gate (item 34), no owner notification (item 35).

## Scope

**In**

_none_

**Out - non-goals**

- writing or changing code: a failing case goes back as A2A-003 with its output
- waiting on CI or merging: push, open the PR, write the result, leave (ORD-0542 O2)
- any file not named under In: stop with DESIGN-GAP and hand it back to infra-design (ORD-0548, item 30)

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [x] `AC-H1` *(human)* every case of the plan prints its expected result (proof: the run output pasted by work-order.sh evidence)
  - observed `2026-10-16` TP-1: count 4, exit 0. TP-2: 'WARN bus unreachable, start of probe not published', 'WARN bus unreachable, end of probe not published', rc=0
- [x] `AC-H2` *(human)* the run output is written by script to ~/.local/state/zenith/log/YYYY/MM/ with frontmatter (proof: the path)
  - observed `2026-10-16` /home/luna/.local/state/zenith/log/2026/10/20261016-124500-wo8590-timedrun-tests.md

## Test plan

_Test plan from claude/workflow/templates/test-plan.md, shaped by claude/workflow/schemas/test-plan.schema.json. The tester runs exactly these cases and nothing else._

**Scope under test**

claude/workflow/mk/resources.mk recipes routed through timed-run.sh

**Cases**

- `TP-1`
  - intent: an untimed target is an invisible bottleneck (item 37)
  - command: `grep -cE '^[[:space:]]+@?[$][(]TIMED[)] ' claude/workflow/mk/resources.mk`
  - expected: exit 0; prints the wrapped-target count listed in the PR body
- `TP-2`
  - intent: the bus must never be a build dependency
  - command: `make -C claude/workflow image && podman run --rm --network=none --userns=keep-id -v "$PWD:/work:Z" -w /work -e HOME=/tmp localhost/dotfiles-workflow-test:1 bash -c 'SW_NATS_URL=127.0.0.1:1 bash claude/workflow/bin/timed-run.sh --node probe --kind make -- true; echo rc=$?'`
  - expected: prints a `WARN bus unreachable` line and rc=0

**Isolation**

- runtime: podman
- image: `docker.io/library/debian:bookworm-slim@sha256:3783cc01769c7b2b1b83a5c5ad96c815348e28ed7da68e2e3687004faa906251` (debian:bookworm-slim, base of localhost/dotfiles-workflow-test:1)

**Out of scope - CI covers**

- the owner's full suite

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
