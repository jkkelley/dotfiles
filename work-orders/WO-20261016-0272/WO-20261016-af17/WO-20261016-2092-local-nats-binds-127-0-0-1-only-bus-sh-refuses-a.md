---
{
  "id": "WO-20261016-2092",
  "slug": "local-nats-binds-127-0-0-1-only-bus-sh-refuses-a",
  "title": "Local NATS binds 127.0.0.1 only: bus.sh refuses any other bind host",
  "type": "feature",
  "status": "ready",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T06:08:32+00:00",
  "parent": "WO-20261016-af17",
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
  "depends_on": [],
  "blocks": [
    "WO-20261016-9f87"
  ]
}
---

# WO-20261016-2092 - Local NATS binds 127.0.0.1 only: bus.sh refuses any other bind host

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

ORD-0553 R1 ruling, bus security: "local NATS binds 127.0.0.1 only, never the LAN". claude/workflow/bin/bus.sh:78 already publishes `-p 127.0.0.1:$PORT:4222`; nothing stops a config change from widening it.

## Scope

**In**

- touches: claude/workflow/bin/bus.sh
- touches: claude/workflow/config/line-watch.json
- touches: claude/workflow/tests/unit/test_bus_bind.sh
- step: line-watch.json bus block: add `"bind": "127.0.0.1"`
- step: bus.sh: read bind from the config; a value other than 127.0.0.1 prints `BUS-BIND-REFUSED <value>` and exits 3 before podman runs; the podman -p flags use the value
- step: test with a stub podman on PATH recording its args; run `make -C claude/workflow image && podman run --rm --network=none --userns=keep-id -v "$PWD:/work:Z" -w /work -e HOME=/tmp localhost/dotfiles-workflow-test:1 bash -c 'bash claude/workflow/tests/unit/test_bus_bind.sh'`
- tool: path:claude/workflow/tests/container/Containerfile - on main; fallback: no fallback permitted (dotfiles Rule 14, never the host): podman or the image missing stops the node with ENV-MISSING podman
- tool: path:claude/workflow/bin/bus.sh - on main; fallback: missing: stop with ENV-MISSING naming it

**Out - non-goals**

- work-orders/INDEX.md by hand: work-order.sh writes it, and the reindex Action is owned by merge-port-build (F11, ORD-0545 O1)
- waiting on CI or merging: push, open the PR, write the result, leave (ORD-0542 O2)
- any file not named under In: stop with DESIGN-GAP and hand it back to infra-design (ORD-0548, item 30)

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [ ] `AC-H1` *(human)* `make -C claude/workflow image && podman run --rm --network=none --userns=keep-id -v "$PWD:/work:Z" -w /work -e HOME=/tmp localhost/dotfiles-workflow-test:1 bash -c 'bash claude/workflow/tests/unit/test_bus_bind.sh'` exits 0 and its output matches /ok bus-up publishes only on 127.0.0.1/ (proof: command, exit code and output pasted by work-order.sh evidence; ORD-0552 O2)
- [ ] `AC-H2` *(human)* `make -C claude/workflow image && podman run --rm --network=none --userns=keep-id -v "$PWD:/work:Z" -w /work -e HOME=/tmp localhost/dotfiles-workflow-test:1 bash -c 'bash claude/workflow/tests/unit/test_bus_bind.sh'` exits 0 and its output matches /ok bind 0.0.0.0 is BUS-BIND-REFUSED/ (proof: command, exit code and output pasted by work-order.sh evidence; ORD-0552 O2)

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
