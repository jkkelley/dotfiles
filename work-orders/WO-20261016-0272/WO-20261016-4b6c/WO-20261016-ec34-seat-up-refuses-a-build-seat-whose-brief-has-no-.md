---
{
  "id": "WO-20261016-ec34",
  "slug": "seat-up-refuses-a-build-seat-whose-brief-has-no-",
  "title": "seat-up refuses a build seat whose brief has no ready work order (DESIGN-GAP)",
  "type": "feature",
  "status": "ready",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T06:04:32+00:00",
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
    "WO-20261016-5569",
    "WO-20261016-8c8c"
  ],
  "blocks": [
    "WO-20261016-52ea",
    "WO-20261016-2ca4"
  ]
}
---

# WO-20261016-ec34 - seat-up refuses a build seat whose brief has no ready work order (DESIGN-GAP)

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

ORD-0548 O1/O4: new build seats start only on a ready work order id, and the spawner refuses to start a seat on a brief without one (code DESIGN-GAP). cmd_seat_up in claude/workflow/bin/herdr-grid.sh claims a slot and starts the CMD with no brief check. make passes command-line VAR=value into the recipe environment, so BRIEF= and BUILD= reach herdr-grid.sh without a Makefile edit.

## Scope

**In**

- touches: claude/workflow/bin/herdr-grid.sh
- touches: claude/workflow/tests/unit/test_herdr_grid.sh
- touches: docs/design/herdr-grid.md
- step: cmd_seat_up: when env BUILD=1, require env BRIEF (else print `DESIGN-GAP seat <seat>: BUILD=1 needs BRIEF=` and return 3); run `make -s -C "$WF" -f a2a.mk brief-check FILE="$BRIEF" BUILD=1` before cmd_claim, where $WF is the claude/workflow dir the script already resolves; on non-zero print its stderr plus `DESIGN-GAP seat <seat> not started` and return 3 with no slot claimed and no pane renamed
- step: breadcrumb comment at the check: ORD-0548 O4, why before the claim (a refused seat holds no slot), rejected: checking after the start (a seat would already be inventing)
- step: test_herdr_grid.sh: stub `make` on PATH for this case that exits 3 for a brief named no-wo.json; cases: BUILD=1 with no-wo.json exits 3, prints DESIGN-GAP and the herdr log shows no `pane rename`; BUILD unset behaves as today
- step: docs/design/herdr-grid.md: one line under seat-up: `BUILD=1 BRIEF=<file>: refuses with DESIGN-GAP unless brief-check BUILD=1 passes`
- step: run `make -C claude/workflow grid`
- tool: make:claude/workflow/Makefile:grid - on main; fallback: target missing or failing to parse: stop with DESIGN-GAP naming the target; no hand-run substitute

**Out - non-goals**

- work-orders/INDEX.md by hand: work-order.sh writes it, and the reindex Action is owned by merge-port-build (F11, ORD-0545 O1)
- waiting on CI or merging: push, open the PR, write the result, leave (ORD-0542 O2)
- any file not named under In: stop with DESIGN-GAP and hand it back to infra-design (ORD-0548, item 30)

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [ ] `AC-H1` *(human)* `make -C claude/workflow grid` exits 0 and prints `ok seat-up BUILD=1 with a brief that names no ready work order exits 3 with DESIGN-GAP and claims no slot` (proof: command, exit code and output pasted by work-order.sh evidence; ORD-0552 O2)
- [ ] `AC-H2` *(human)* the same run prints `ok seat-up without BUILD starts as before` (proof: command, exit code and output pasted by work-order.sh evidence; ORD-0552 O2)
- [ ] `AC-H3` *(human)* `git diff --name-only origin/main` lists only the three files under In (proof: command, exit code and output pasted by work-order.sh evidence; ORD-0552 O2)

## Test plan

_Test plan from claude/workflow/templates/test-plan.md, shaped by claude/workflow/schemas/test-plan.schema.json. The tester runs exactly these cases and nothing else._

**Scope under test**

claude/workflow/bin/herdr-grid.sh cmd_seat_up BUILD=1 brief gate against the stub herdr and a stub make

**Cases**

- `TP-1`
  - intent: a build seat with no ready work order must not start or hold a slot (ORD-0548 O4)
  - command: `make -C claude/workflow grid`
  - expected: exit 0; prints `ok  seat-up BUILD=1 with a brief that names no ready work order exits 3 with DESIGN-GAP and claims no slot`
- `TP-2`
  - intent: design seats and old callers must start unchanged
  - command: `make -C claude/workflow grid`
  - expected: exit 0; prints `ok  seat-up without BUILD starts as before`

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
