---
{
  "id": "WO-20261016-9ba7",
  "slug": "model-roles-json-in-dotfiles-seat-up-seat-role-p",
  "title": "model-roles.json in dotfiles: seat-up SEAT_ROLE= picks the seat's model",
  "type": "feature",
  "status": "ready",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T06:20:16+00:00",
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
    "WO-20261016-aafc"
  ],
  "blocks": [
    "WO-20261016-909f"
  ]
}
---

# WO-20261016-9ba7 - model-roles.json in dotfiles: seat-up SEAT_ROLE= picks the seat's model

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

ORD-0616 G1: "model-role table source of truth is /home/luna/.local/state/zenith/context/2026/10/20261016-061547-model-role-table.json; cut the ticket that moves it into dotfiles as config read by seat-up (SEAT_ROLE= picks the model)." Table (ORD-0542-models): architect opus, orchestrator opus, design opus, build sonnet, fix sonnet, test sonnet, mechanical haiku, watcher none (script, no model).

## Scope

**In**

- touches: claude/workflow/config/model-roles.json
- touches: claude/workflow/bin/herdr-grid.sh
- touches: claude/workflow/tests/unit/test_herdr_grid.sh
- step: copy the table file verbatim into claude/workflow/config/model-roles.json and add `$comment` naming its source path and ORD-0616 G1
- step: seat_cmd: with env SEAT_ROLE set and a claude command, add `--model <roles[SEAT_ROLE]>` after the claude word unless the command already has --model; role watcher prints `SEAT-ROLE-NO-MODEL watcher runs as a script` and returns 3; an unknown role prints `SEAT-ROLE-UNKNOWN <role>` and returns 3
- step: run `make -C claude/workflow grid`
- tool: make:claude/workflow/Makefile:grid - on main; fallback: target missing or failing to parse: stop with DESIGN-GAP naming the target; no hand-run substitute

**Out - non-goals**

- work-orders/INDEX.md by hand: work-order.sh writes it, and the reindex Action is owned by merge-port-build (F11, ORD-0545 O1)
- waiting on CI or merging: push, open the PR, write the result, leave (ORD-0542 O2)
- any file not named under In: stop with DESIGN-GAP and hand it back to infra-design (ORD-0548, item 30)

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [ ] `AC-H1` *(human)* `make -C claude/workflow grid` exits 0 and its output matches /ok SEAT_ROLE=build starts claude --model sonnet/ (proof: command, exit code and output pasted by work-order.sh evidence; ORD-0552 O2)
- [ ] `AC-H2` *(human)* `make -C claude/workflow grid` exits 0 and its output matches /ok SEAT_ROLE=watcher is refused/ (proof: command, exit code and output pasted by work-order.sh evidence; ORD-0552 O2)

## Test plan

_Test plan from claude/workflow/templates/test-plan.md, shaped by claude/workflow/schemas/test-plan.schema.json. The tester runs exactly these cases and nothing else._

**Scope under test**

herdr-grid.sh SEAT_ROLE model selection

**Cases**

- `TP-1`
  - intent: a seat on the wrong model wastes money or quality (ORD-0542)
  - command: `make -C claude/workflow grid`
  - expected: exit 0; prints `ok  SEAT_ROLE=build starts claude --model sonnet`
- `TP-2`
  - intent: a loop needs no model (rule 39)
  - command: `make -C claude/workflow grid`
  - expected: exit 0; prints `ok  SEAT_ROLE=watcher is refused`
- `TP-3`
  - intent: fallback path: no SEAT_ROLE keeps today's command
  - command: `make -C claude/workflow grid`
  - expected: exit 0; prints `ok  no SEAT_ROLE leaves the command unchanged`

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
