---
{
  "id": "WO-20261016-1cd0",
  "slug": "a2a-deliver-as-fallback-only-dedup-by-order-id-n",
  "title": "a2a-deliver as fallback only: dedup by order id, never type into a pane whose spinner is active",
  "type": "feature",
  "status": "ready",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T06:19:56+00:00",
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
    "WO-20261016-24b5",
    "WO-20261016-590b"
  ],
  "blocks": [
    "WO-20261016-d572"
  ]
}
---

# WO-20261016-1cd0 - a2a-deliver as fallback only: dedup by order id, never type into a pane whose spinner is active

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

- touches: claude/workflow/a2a-guard/a2a-deliver.sh
- touches: claude/workflow/a2a-guard/tests/test_a2a_guard.sh
- touches: claude/workflow/a2a-guard/tests/fake-herdr
- step: before typing, read the pane (`herdr pane read <pane> --source recent-unwrapped --lines 40`); a line matching the spinner regex of claude/workflow/stuck-watch/config.json pane_look.spinner_re (or `^[^[:alnum:][:space:]] [A-Z][a-z]+… \(` if that key is absent) holds the delivery with `A2A-HELD <seat> spinner-active`
- step: dedup: an order id already in `<queue>/delivered.ids` is moved to delivered/ untyped with `A2A-DUP <seat> <id>`; each delivery appends its id
- step: fake-herdr: a fixture pane with a spinner line; run `make -C claude/workflow a2a-guard-test`
- tool: make:claude/workflow/a2a-guard/a2a-guard.mk:a2a-guard-test - on main; fallback: target missing or failing to parse: stop with DESIGN-GAP naming the target; no hand-run substitute

**Out - non-goals**

- work-orders/INDEX.md by hand: work-order.sh writes it, and the reindex Action is owned by merge-port-build (F11, ORD-0545 O1)
- waiting on CI or merging: push, open the PR, write the result, leave (ORD-0542 O2)
- any file not named under In: stop with DESIGN-GAP and hand it back to infra-design (ORD-0548, item 30)

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [ ] `AC-H1` *(human)* `make -C claude/workflow a2a-guard-test` exits 0 and its output matches /ok a pane with an active spinner is held/ (proof: command, exit code and output pasted by work-order.sh evidence; ORD-0552 O2)
- [ ] `AC-H2` *(human)* `make -C claude/workflow a2a-guard-test` exits 0 and its output matches /ok a duplicate order id is never typed/ (proof: command, exit code and output pasted by work-order.sh evidence; ORD-0552 O2)

## Test plan

_Test plan from claude/workflow/templates/test-plan.md, shaped by claude/workflow/schemas/test-plan.schema.json. The tester runs exactly these cases and nothing else._

**Scope under test**

a2a-deliver.sh spinner hold and order-id dedup against fake-herdr

**Cases**

- `TP-1`
  - intent: typing into a working seat interrupts its turn (ORD-0606 D1)
  - command: `make -C claude/workflow a2a-guard-test`
  - expected: exit 0; prints `ok  a pane with an active spinner is held`
- `TP-2`
  - intent: an order delivered by bus and by fallback must run once
  - command: `make -C claude/workflow a2a-guard-test`
  - expected: exit 0; prints `ok  a duplicate order id is never typed`

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
