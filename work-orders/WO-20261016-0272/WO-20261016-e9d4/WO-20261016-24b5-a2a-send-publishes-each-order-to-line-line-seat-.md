---
{
  "id": "WO-20261016-24b5",
  "slug": "a2a-send-publishes-each-order-to-line-line-seat-",
  "title": "a2a-send publishes each order to line.<line>.seat.<name>; the pane queue becomes the bus-down fallback",
  "type": "feature",
  "status": "ready",
  "priority": "p0",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T06:19:47+00:00",
  "parent": "WO-20261016-e9d4",
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
    "WO-20261016-590b"
  ],
  "blocks": [
    "WO-20261016-346e",
    "WO-20261016-1cd0"
  ]
}
---

# WO-20261016-24b5 - a2a-send publishes each order to line.<line>.seat.<name>; the pane queue becomes the bus-down fallback

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

ORD-0606 D1 (relayed 2026-10-16T06:17Z): "seats pull their own orders. Each seat gets a durable bus consumer line.<line>.seat.<name>; a Claude Code hook in the seat settings (UserPromptSubmit and Stop) pulls pending orders, dedups by order id, acks, and adds them as context. The spawner (seat-up) installs it by default. Nothing is ever typed into a pane again; deliver.sh and a2a-deliver become the fallback only when the bus is down (rule 28), and then dedup by order id and never type into a pane whose spinner is active." Owner, item 26: "No event is ever typed into an agent's pane." Inventory: stream LINE (subjects line.>) in claude/workflow/config/line-watch.json bus; the nats CLI runs as nats-box through podman the way claude/workflow/herdr-bus/herdr-bus.sh natscli does (consumer add --pull, consumer next --raw).

## Scope

**In**

- touches: claude/workflow/a2a-guard/a2a-send.sh
- touches: claude/workflow/a2a-guard/tests/test_a2a_send_bus.sh
- step: after validation, publish the order JSON with `sw_pub line.<line>.seat.<to> <json>` (claude/workflow/stuck-watch/lib.sh); on success print `A2A-PUBLISHED <id>` and do not queue a pane pointer
- step: publish failure: queue the pointer exactly as today and print `A2A-QUEUED-FALLBACK <id> bus down`
- step: test: SW_PUB_CMD stub ok and failing; run `make -C claude/workflow image && podman run --rm --network=none --userns=keep-id -v "$PWD:/work:Z" -w /work -e HOME=/tmp localhost/dotfiles-workflow-test:1 bash -c 'bash claude/workflow/a2a-guard/tests/test_a2a_send_bus.sh'`
- tool: path:claude/workflow/tests/container/Containerfile - on main; fallback: no fallback permitted (dotfiles Rule 14, never the host): podman or the image missing stops the node with ENV-MISSING podman
- tool: path:claude/workflow/stuck-watch/lib.sh - on main; fallback: bus down: sw_pub returns 1 and the caller warns; the snapshot still lands in the artifact store

**Out - non-goals**

- work-orders/INDEX.md by hand: work-order.sh writes it, and the reindex Action is owned by merge-port-build (F11, ORD-0545 O1)
- waiting on CI or merging: push, open the PR, write the result, leave (ORD-0542 O2)
- any file not named under In: stop with DESIGN-GAP and hand it back to infra-design (ORD-0548, item 30)

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [ ] `AC-H1` *(human)* `make -C claude/workflow image && podman run --rm --network=none --userns=keep-id -v "$PWD:/work:Z" -w /work -e HOME=/tmp localhost/dotfiles-workflow-test:1 bash -c 'bash claude/workflow/a2a-guard/tests/test_a2a_send_bus.sh'` exits 0 and its output matches /ok bus up publishes and queues nothing/ (proof: command, exit code and output pasted by work-order.sh evidence; ORD-0552 O2)
- [ ] `AC-H2` *(human)* `make -C claude/workflow image && podman run --rm --network=none --userns=keep-id -v "$PWD:/work:Z" -w /work -e HOME=/tmp localhost/dotfiles-workflow-test:1 bash -c 'bash claude/workflow/a2a-guard/tests/test_a2a_send_bus.sh'` exits 0 and its output matches /ok bus down queues the fallback pointer/ (proof: command, exit code and output pasted by work-order.sh evidence; ORD-0552 O2)

## Test plan

_Test plan from claude/workflow/templates/test-plan.md, shaped by claude/workflow/schemas/test-plan.schema.json. The tester runs exactly these cases and nothing else._

**Scope under test**

a2a-send.sh bus publish and pane-queue fallback

**Cases**

- `TP-1`
  - intent: orders reach the seat's consumer, never a pane
  - command: `make -C claude/workflow image && podman run --rm --network=none --userns=keep-id -v "$PWD:/work:Z" -w /work -e HOME=/tmp localhost/dotfiles-workflow-test:1 bash -c 'bash claude/workflow/a2a-guard/tests/test_a2a_send_bus.sh'`
  - expected: exit 0; prints `ok  bus up publishes and queues nothing`
- `TP-2`
  - intent: fallback path when the bus is down (rule 28)
  - command: `make -C claude/workflow image && podman run --rm --network=none --userns=keep-id -v "$PWD:/work:Z" -w /work -e HOME=/tmp localhost/dotfiles-workflow-test:1 bash -c 'bash claude/workflow/a2a-guard/tests/test_a2a_send_bus.sh'`
  - expected: exit 0; prints `ok  bus down queues the fallback pointer`

**Isolation**

- runtime: podman
- image: `docker.io/library/debian:bookworm-slim@sha256:3783cc01769c7b2b1b83a5c5ad96c815348e28ed7da68e2e3687004faa906251` (debian:bookworm-slim, base of localhost/dotfiles-workflow-test:1)

**Out of scope - CI covers**

- a2a-lint and the full workflow suite

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
