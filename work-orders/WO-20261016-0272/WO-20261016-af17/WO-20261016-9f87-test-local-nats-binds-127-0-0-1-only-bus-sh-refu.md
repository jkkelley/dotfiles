---
{
  "id": "WO-20261016-9f87",
  "slug": "test-local-nats-binds-127-0-0-1-only-bus-sh-refu",
  "title": "Test - Local NATS binds 127.0.0.1 only: bus.sh refuses any other bind host",
  "type": "test",
  "status": "in-progress",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T06:08:37+00:00",
  "parent": "WO-20261016-af17",
  "branch": "feat/9f87-test-local-nats-binds-127-0-0-1-only-bus-sh-refu",
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
    "WO-20261016-2092"
  ],
  "blocks": [],
  "labels": [
    "line:inbox-triage"
  ]
}
---

# WO-20261016-9f87 - Test - Local NATS binds 127.0.0.1 only: bus.sh refuses any other bind host

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

Run the filled test plan of WO-20261016-2092 - Local NATS binds 127.0.0.1 only: bus.sh refuses any other bind host exactly as written; dev gate (item 34), no owner notification (item 35).

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
  - observed `2026-10-16` exit 0; 'ok bus-up publishes only on 127.0.0.1' and 'ok bind 0.0.0.0 is BUS-BIND-REFUSED' printed (TP-1, TP-2); log /home/luna/.local/state/zenith/log/2026/10/20261016-124106-wo-9f87-bus-bind-test.md
- [x] `AC-H2` *(human)* the run output is written by script to ~/.local/state/zenith/log/YYYY/MM/ with frontmatter (proof: the path)
  - observed `2026-10-16` run output with frontmatter at /home/luna/.local/state/zenith/log/2026/10/20261016-124106-wo-9f87-bus-bind-test.md

## Test plan

_Test plan from claude/workflow/templates/test-plan.md, shaped by claude/workflow/schemas/test-plan.schema.json. The tester runs exactly these cases and nothing else._

**Scope under test**

claude/workflow/bin/bus.sh bind guard with a stub podman

**Cases**

- `TP-1`
  - intent: the bus must never listen on the LAN (ORD-0553 R1)
  - command: `make -C claude/workflow image && podman run --rm --network=none --userns=keep-id -v "$PWD:/work:Z" -w /work -e HOME=/tmp localhost/dotfiles-workflow-test:1 bash -c 'bash claude/workflow/tests/unit/test_bus_bind.sh'`
  - expected: exit 0; prints `ok  bus-up publishes only on 127.0.0.1`
- `TP-2`
  - intent: a widened config is refused, never applied
  - command: `make -C claude/workflow image && podman run --rm --network=none --userns=keep-id -v "$PWD:/work:Z" -w /work -e HOME=/tmp localhost/dotfiles-workflow-test:1 bash -c 'bash claude/workflow/tests/unit/test_bus_bind.sh'`
  - expected: exit 0; prints `ok  bind 0.0.0.0 is BUS-BIND-REFUSED`

**Isolation**

- runtime: podman
- image: `docker.io/library/debian:bookworm-slim@sha256:3783cc01769c7b2b1b83a5c5ad96c815348e28ed7da68e2e3687004faa906251` (debian:bookworm-slim, base of localhost/dotfiles-workflow-test:1)

**Out of scope - CI covers**

- the full workflow suite

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
