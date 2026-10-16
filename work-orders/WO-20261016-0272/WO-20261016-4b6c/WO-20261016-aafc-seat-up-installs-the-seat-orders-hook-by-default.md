---
{
  "id": "WO-20261016-aafc",
  "slug": "seat-up-installs-the-seat-orders-hook-by-default",
  "title": "seat-up installs the seat-orders hook by default through claude --settings",
  "type": "feature",
  "status": "ready",
  "priority": "p0",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T06:20:06+00:00",
  "parent": "WO-20261016-4b6c",
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
    "WO-20261016-2ca4",
    "WO-20261016-1eac"
  ],
  "blocks": [
    "WO-20261016-24e9",
    "WO-20261016-9ba7"
  ]
}
---

# WO-20261016-aafc - seat-up installs the seat-orders hook by default through claude --settings

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

- touches: claude/workflow/bin/herdr-grid.sh
- touches: claude/workflow/tests/unit/test_herdr_grid.sh
- step: seat_cmd: when the command starts claude or claude.exe, render claude/workflow/seat-orders/hooks.json.tmpl with line and seat into `~/.local/state/zenith/seat-orders/<line>/<seat>.settings.json` and add `--settings <that file>` after the claude word (same sed pattern as SKIP_FLAG); SEAT_ORDERS=0 skips it
- step: test: seat-up with CMD=claude prints a pane run whose command contains `--settings` and the file exists with both hooks; run `make -C claude/workflow grid`
- tool: make:claude/workflow/Makefile:grid - on main; fallback: target missing or failing to parse: stop with DESIGN-GAP naming the target; no hand-run substitute

**Out - non-goals**

- work-orders/INDEX.md by hand: work-order.sh writes it, and the reindex Action is owned by merge-port-build (F11, ORD-0545 O1)
- waiting on CI or merging: push, open the PR, write the result, leave (ORD-0542 O2)
- any file not named under In: stop with DESIGN-GAP and hand it back to infra-design (ORD-0548, item 30)

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [ ] `AC-H1` *(human)* `make -C claude/workflow grid` exits 0 and its output matches /ok seat-up adds --settings with the seat-orders hooks/ (proof: command, exit code and output pasted by work-order.sh evidence; ORD-0552 O2)
- [ ] `AC-H2` *(human)* `make -C claude/workflow grid` exits 0 and its output matches /ok SEAT_ORDERS=0 starts without the hook/ (proof: command, exit code and output pasted by work-order.sh evidence; ORD-0552 O2)

## Test plan

_Test plan from claude/workflow/templates/test-plan.md, shaped by claude/workflow/schemas/test-plan.schema.json. The tester runs exactly these cases and nothing else._

**Scope under test**

herdr-grid.sh seat_cmd hook install

**Cases**

- `TP-1`
  - intent: every new seat pulls its orders with no step (ORD-0606 D1)
  - command: `make -C claude/workflow grid`
  - expected: exit 0; prints `ok  seat-up adds --settings with the seat-orders hooks`
- `TP-2`
  - intent: fallback path: a seat can still start without the hook
  - command: `make -C claude/workflow grid`
  - expected: exit 0; prints `ok  SEAT_ORDERS=0 starts without the hook`

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
