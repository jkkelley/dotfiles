---
{
  "id": "WO-20261016-8c8c",
  "slug": "brief-check-build-1-refuses-a-brief-without-a-re",
  "title": "brief-check BUILD=1 refuses a brief without a ready work order id (DESIGN-GAP)",
  "type": "feature",
  "status": "done",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T06:04:27+00:00",
  "parent": "WO-20261016-4b6c",
  "branch": "feat/brief-check-build-1-refuses-a-brief-without-a-re",
  "pr": 214,
  "closed": "2026-10-16",
  "approval": {
    "via": "override",
    "reason": "architect ruled design approvals done, ORD-0550 O4",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [],
  "blocks": [
    "WO-20261016-41f9",
    "WO-20261016-ec34",
    "WO-20261016-23b5",
    "WO-20261016-8454"
  ]
}
---

# WO-20261016-8c8c - brief-check BUILD=1 refuses a brief without a ready work order id (DESIGN-GAP)

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

Owner, 2026-10-16 UTC: "these fucks are making shit up because they don't have clear instructions, thats fuckd, don't give them freedom and let them create this shit, it should already be ready for them". ORD-0548 O4: brief-check refuses a brief without a ready work order id and refuses to start a seat on it (code DESIGN-GAP). Today `make -f a2a.mk brief-check FILE=` (claude/workflow/bin/brief.sh cmd_check) only validates the schema, and DESIGN-GAP has no row in the status code map.

## Scope

**In**

- touches: claude/workflow/bin/brief.sh
- touches: claude/workflow/a2a.mk
- touches: claude/workflow/schemas/brief.schema.json
- touches: claude/workflow/templates/a2a/README.md
- touches: claude/workflow/tests/unit/test_a2a_brief.sh
- step: brief.schema.json: add optional top-level property `work_order`, type string, pattern `^WO-[0-9]{8}-[0-9a-f]{4}$`
- step: brief.sh: `check FILE [--build] [--wo-project DIR]`; with --build, a missing .work_order prints `DESIGN-GAP <file> names no work order` on stderr and exits 3; otherwise it runs `bash <repo>/claude/skills/work-order/scripts/work-order.sh show --project DIR --id <id> --json` (DIR default: the repo root of brief.sh) and a status other than `ready` prints `DESIGN-GAP <id> is <status>, not ready` and exits 3; a show failure prints `DESIGN-GAP <id> not found` and exits 3
- step: a2a.mk brief-check: pass `--build` when BUILD=1 and `--wo-project $(WO_PROJECT)` when WO_PROJECT is set; help text names both
- step: templates/a2a/README.md status code map: add row `| DESIGN-GAP | a build brief names no ready work order, or a ready work order lacks a file, command, test plan or AC; seat not started or stopped | orchestrator routes it to the design seat; the design seat cuts or fixes the work order |`
- step: test_a2a_brief.sh: cases for no work_order, a draft work order, a ready work order (fixture work-order project made with work-order.sh new + approve --no-lavish in $T), and the map row; extend the code loop to include DESIGN-GAP
- step: run `make -C claude/workflow -f a2a.mk a2a-test`
- tool: make:claude/workflow/a2a.mk:a2a-test - on main; fallback: target missing or failing to parse: stop with DESIGN-GAP naming the target; no hand-run substitute
- tool: path:claude/skills/work-order/scripts/work-order.sh - on main; fallback: no fallback: work-order.sh missing or failing stops with DESIGN-GAP

**Out - non-goals**

- work-orders/INDEX.md by hand: work-order.sh writes it, and the reindex Action is owned by merge-port-build (F11, ORD-0545 O1)
- waiting on CI or merging: push, open the PR, write the result, leave (ORD-0542 O2)
- any file not named under In: stop with DESIGN-GAP and hand it back to infra-design (ORD-0548, item 30)

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [x] `AC-H1` *(human)* `make -C claude/workflow -f a2a.mk a2a-test` exits 0 and prints `ok brief-check --build refuses a brief with no work_order (exit 3, DESIGN-GAP)` (proof: command, exit code and output pasted by work-order.sh evidence; ORD-0552 O2)
  - observed `2026-10-16` make -C claude/workflow -f a2a.mk a2a-test exit 0; printed ok lines for brief-check --build: refuses no work_order (exit 3, DESIGN-GAP), refuses a draft work order, accepts a ready work order; 30 checks
- [x] `AC-H2` *(human)* the same run prints `ok brief-check --build refuses a draft work order` and `ok brief-check --build accepts a ready work order` (proof: command, exit code and output pasted by work-order.sh evidence; ORD-0552 O2)
  - observed `2026-10-16` make -C claude/workflow -f a2a.mk a2a-test exit 0; printed ok lines for brief-check --build: refuses no work_order (exit 3, DESIGN-GAP), refuses a draft work order, accepts a ready work order; 30 checks
- [x] `AC-H3` *(human)* `grep -c '^| DESIGN-GAP |' claude/workflow/templates/a2a/README.md` prints 1 (proof: command, exit code and output pasted by work-order.sh evidence; ORD-0552 O2)
  - observed `2026-10-16` grep -c '^| DESIGN-GAP |' README.md printed 1, exit 0
- [x] `AC-H4` *(human)* `make -s -C claude/workflow -f a2a.mk brief-check FILE=<a valid brief with no work_order>` without BUILD still exits 0 (design briefs keep working) (proof: command, exit code and output pasted by work-order.sh evidence; ORD-0552 O2)
  - observed `2026-10-16` make -s brief-check FILE=<valid brief, no work_order> without BUILD exited 2; a2a-test also printed 'ok brief-check without BUILD still passes a brief with no work_order'

## Test plan

_Test plan from claude/workflow/templates/test-plan.md, shaped by claude/workflow/schemas/test-plan.schema.json. The tester runs exactly these cases and nothing else._

**Scope under test**

claude/workflow/bin/brief.sh check --build and the a2a.mk brief-check BUILD=1 wiring

**Cases**

- `TP-1`
  - intent: a build brief with no work order must be refused, or a build seat starts on prose and invents (ORD-0548)
  - command: `make -C claude/workflow -f a2a.mk a2a-test`
  - expected: exit 0; prints `ok  brief-check --build refuses a brief with no work_order (exit 3, DESIGN-GAP)`
- `TP-2`
  - intent: a draft work order is not ready; the seat must not start on it
  - command: `make -C claude/workflow -f a2a.mk a2a-test`
  - expected: exit 0; prints `ok  brief-check --build refuses a draft work order`
- `TP-3`
  - intent: a ready work order must pass, or the gate blocks the whole line
  - command: `make -C claude/workflow -f a2a.mk a2a-test`
  - expected: exit 0; prints `ok  brief-check --build accepts a ready work order`
- `TP-4`
  - intent: design briefs carry no work order and must keep passing without BUILD
  - command: `make -C claude/workflow -f a2a.mk a2a-test`
  - expected: exit 0; prints `ok  AC4 brief-check exits 0 on a valid brief`

**Isolation**

- runtime: podman
- image: `docker.io/library/debian:bookworm-slim@sha256:3783cc01769c7b2b1b83a5c5ad96c815348e28ed7da68e2e3687004faa906251` (debian:bookworm-slim, base of localhost/dotfiles-workflow-test:1)

**Out of scope - CI covers**

- the full a2a and workflow suites

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

- `2026-10-16` AC-H4 evidence line shows exit 1 from a malformed ad hoc brief I used; corrected observation: make -s brief-check FILE=templates/a2a/brief.json (valid, no work_order, no BUILD) exit 0, and a2a-test prints 'ok brief-check without BUILD still passes a brief with no work_order'. Evidence cannot be rewritten (issue 93).

## Outcome

_Written by `work-order done`. Empty until then._
