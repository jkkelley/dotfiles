---
{
  "id": "WO-20261016-1eac",
  "slug": "seat-orders-sh-a-seat-pulls-its-own-orders-from-",
  "title": "seat-orders.sh: a seat pulls its own orders from line.<line>.seat.<name> in a Claude Code hook",
  "type": "feature",
  "status": "ready",
  "priority": "p0",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T06:19:36+00:00",
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
  "depends_on": [],
  "blocks": [
    "WO-20261016-905f",
    "WO-20261016-aafc"
  ]
}
---

# WO-20261016-1eac - seat-orders.sh: a seat pulls its own orders from line.<line>.seat.<name> in a Claude Code hook

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

- touches: claude/workflow/seat-orders/seat-orders.sh
- touches: claude/workflow/seat-orders/config.json
- touches: claude/workflow/seat-orders/hooks.json.tmpl
- touches: claude/workflow/seat-orders/README.md
- touches: claude/workflow/seat-orders/tests/test_seat_orders.sh
- touches: claude/workflow/seat-orders/tests/stub-natscli
- step: claude/workflow/seat-orders/config.json: `{stream: "LINE", subject: "line.${line}.seat.${seat}", consumer: "seat-${seat}", batch: 10, wait: "1s", state_dir: "~/.local/state/zenith/seat-orders", natscli: "podman run --rm --network=host <box_image of line-watch.json> nats --server nats://127.0.0.1:4222"}`; NATSCLI env overrides natscli
- step: seat-orders.sh --line L --seat S --event prompt|stop: ensure the durable pull consumer (`consumer info` else `consumer add <stream> seat-<S> --pull --filter line.<L>.seat.<S> --ack explicit --deliver all --defaults`, idempotent); `consumer next <stream> seat-<S> --count <batch> --wait <wait> --raw --ack`; drop any message whose `.id` is already in `<state_dir>/<L>/<S>.seen` (append new ids)
- step: event prompt: print `Pending orders for <S> (bus line.<L>.seat.<S>):` then one JSON per line on stdout (UserPromptSubmit stdout becomes context); event stop with new orders: print `{"decision":"block","reason":"Pending orders ..."}` so the seat takes them before stopping; nothing new: no output, exit 0
- step: bus down or natscli failing: print `SEAT-ORDERS-BUS-DOWN` on stderr and exit 0 (a hook must never break the seat); a2a-deliver stays the fallback
- step: hooks.json.tmpl: a settings file with hooks.UserPromptSubmit and hooks.Stop each running `bash <wf>/seat-orders/seat-orders.sh --line ${line} --seat ${seat} --event prompt|stop`, rendered with envsubst
- step: README.md (contents list first): subject, consumer, dedup, fallback, status codes SEAT-ORDERS-BUS-DOWN
- step: run `make -C claude/workflow image && podman run --rm --network=none --userns=keep-id -v "$PWD:/work:Z" -w /work -e HOME=/tmp localhost/dotfiles-workflow-test:1 bash -c 'bash claude/workflow/seat-orders/tests/test_seat_orders.sh'`
- tool: path:claude/workflow/tests/container/Containerfile - on main; fallback: no fallback permitted (dotfiles Rule 14, never the host): podman or the image missing stops the node with ENV-MISSING podman
- tool: path:claude/workflow/config/line-watch.json - on main; fallback: missing: stop with ENV-MISSING naming it

**Out - non-goals**

- work-orders/INDEX.md by hand: work-order.sh writes it, and the reindex Action is owned by merge-port-build (F11, ORD-0545 O1)
- waiting on CI or merging: push, open the PR, write the result, leave (ORD-0542 O2)
- any file not named under In: stop with DESIGN-GAP and hand it back to infra-design (ORD-0548, item 30)

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [ ] `AC-H1` *(human)* `make -C claude/workflow image && podman run --rm --network=none --userns=keep-id -v "$PWD:/work:Z" -w /work -e HOME=/tmp localhost/dotfiles-workflow-test:1 bash -c 'bash claude/workflow/seat-orders/tests/test_seat_orders.sh'` exits 0 and its output matches /ok prompt event prints each new order once/ (proof: command, exit code and output pasted by work-order.sh evidence; ORD-0552 O2)
- [ ] `AC-H2` *(human)* `make -C claude/workflow image && podman run --rm --network=none --userns=keep-id -v "$PWD:/work:Z" -w /work -e HOME=/tmp localhost/dotfiles-workflow-test:1 bash -c 'bash claude/workflow/seat-orders/tests/test_seat_orders.sh'` exits 0 and its output matches /ok a repeated order id is dropped/ (proof: command, exit code and output pasted by work-order.sh evidence; ORD-0552 O2)
- [ ] `AC-H3` *(human)* `make -C claude/workflow image && podman run --rm --network=none --userns=keep-id -v "$PWD:/work:Z" -w /work -e HOME=/tmp localhost/dotfiles-workflow-test:1 bash -c 'bash claude/workflow/seat-orders/tests/test_seat_orders.sh'` exits 0 and its output matches /ok stop event with a new order blocks with the order as reason/ (proof: command, exit code and output pasted by work-order.sh evidence; ORD-0552 O2)
- [ ] `AC-H4` *(human)* `make -C claude/workflow image && podman run --rm --network=none --userns=keep-id -v "$PWD:/work:Z" -w /work -e HOME=/tmp localhost/dotfiles-workflow-test:1 bash -c 'bash claude/workflow/seat-orders/tests/test_seat_orders.sh'` exits 0 and its output matches /ok bus down exits 0 with SEAT-ORDERS-BUS-DOWN/ (proof: command, exit code and output pasted by work-order.sh evidence; ORD-0552 O2)

## Test plan

_Test plan from claude/workflow/templates/test-plan.md, shaped by claude/workflow/schemas/test-plan.schema.json. The tester runs exactly these cases and nothing else._

**Scope under test**

claude/workflow/seat-orders/seat-orders.sh with a stub natscli

**Cases**

- `TP-1`
  - intent: orders typed into panes get lost or interrupt a turn (item 26)
  - command: `make -C claude/workflow image && podman run --rm --network=none --userns=keep-id -v "$PWD:/work:Z" -w /work -e HOME=/tmp localhost/dotfiles-workflow-test:1 bash -c 'bash claude/workflow/seat-orders/tests/test_seat_orders.sh'`
  - expected: exit 0; prints `ok  prompt event prints each new order once`
- `TP-2`
  - intent: a redelivered order must not run twice
  - command: `make -C claude/workflow image && podman run --rm --network=none --userns=keep-id -v "$PWD:/work:Z" -w /work -e HOME=/tmp localhost/dotfiles-workflow-test:1 bash -c 'bash claude/workflow/seat-orders/tests/test_seat_orders.sh'`
  - expected: exit 0; prints `ok  a repeated order id is dropped`
- `TP-3`
  - intent: a seat about to stop must take its pending orders first
  - command: `make -C claude/workflow image && podman run --rm --network=none --userns=keep-id -v "$PWD:/work:Z" -w /work -e HOME=/tmp localhost/dotfiles-workflow-test:1 bash -c 'bash claude/workflow/seat-orders/tests/test_seat_orders.sh'`
  - expected: exit 0; prints `ok  stop event with a new order blocks with the order as reason`
- `TP-4`
  - intent: fallback path: a down bus must never break the seat (ORD-0558)
  - command: `make -C claude/workflow image && podman run --rm --network=none --userns=keep-id -v "$PWD:/work:Z" -w /work -e HOME=/tmp localhost/dotfiles-workflow-test:1 bash -c 'bash claude/workflow/seat-orders/tests/test_seat_orders.sh'`
  - expected: exit 0; prints `ok  bus down exits 0 with SEAT-ORDERS-BUS-DOWN`

**Isolation**

- runtime: podman
- image: `docker.io/library/debian:bookworm-slim@sha256:3783cc01769c7b2b1b83a5c5ad96c815348e28ed7da68e2e3687004faa906251` (debian:bookworm-slim, base of localhost/dotfiles-workflow-test:1)

**Out of scope - CI covers**

- shellcheck and the full workflow suite

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
