---
{
  "id": "WO-20261016-6082",
  "slug": "dag-author-edit-move-rm-step-add-and-prio-the-re",
  "title": "dag-author edit, move, rm, step-add and prio: the rest of the authoring verbs",
  "type": "feature",
  "status": "draft",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T06:08:16+00:00",
  "parent": "WO-20261016-41d0",
  "branch": null,
  "pr": null,
  "closed": null,
  "approval": null,
  "evidence": null,
  "surfaces": [],
  "depends_on": [
    "WO-20261016-a215",
    "WO-20261016-acde"
  ],
  "blocks": [
    "WO-20261016-2342",
    "WO-20261016-42cb"
  ]
}
---

# WO-20261016-6082 - dag-author edit, move, rm, step-add and prio: the rest of the authoring verbs

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

Owner, 2026-10-16 UTC: "DAG SHOULD BE EFFORTLESS WITH EASY MIGRATION PLANS FOR UPDATED CREATING DELETING MOVING NODES AND ADDING STEPS OR WHATEVER RUNBOOKS DOCS THE WHOLE NINE YARDS" and "nodes can move around and be shifted and reprioritized". Evidence: dotfiles #140 merged the dag-state design; no dag-plan/apply/migrate script exists on main at 06:15Z. Build exactly to docs/design/dag-state.spec.xml and docs/design/dag-state-nodes.spec.xml (design docs/design/dag-state.md); never redesign. Item 40 amended: "nodes can move around and be shifted and reprioritized". A node's place and priority change by one verb at any time, live runs follow by migration.

## Scope

**In**

- touches: claude/workflow/dag/bin/dag-author.sh
- touches: claude/workflow/dag/tests/unit/test_dag_author.sh
- touches: claude/workflow/dag/dag.mk
- step: verbs on the same plan/--apply/regenerate/manifest/migration-plan path as node-new: node-edit --id --field --value (patch bump; refuses a field not in node.schema.json), node-move --id --after (minor; refuses a cycle with DG-CYCLE exit 3), node-rm --id (minor; downstream after edges rewired to the removed node's after; live runs get DG-SKIPPED per <migration>), step-add --id --step TEXT (minor; appends to the node's checks and its runbook section), node-prio --id --prio p0|p1|p2|p3 (patch; plan orders the ready set by it, T2)
- step: dag.mk: dag-node-edit ID= FIELD= VALUE=, dag-node-move ID= AFTER=, dag-node-rm ID=, dag-step-add ID= STEP=, dag-node-prio ID= PRIO=, each [APPLY=1], through $(TIMED)
- step: run `make -C claude/workflow dag-test CASE=author-verbs`
- tool: make:claude/workflow/dag/dag.mk:dag-test - NOT on main: ticket stays draft until it lands; fallback: target missing or failing to parse: stop with DESIGN-GAP naming the target; no hand-run substitute

**Out - non-goals**

- work-orders/INDEX.md by hand: work-order.sh writes it, and the reindex Action is owned by merge-port-build (F11, ORD-0545 O1)
- waiting on CI or merging: push, open the PR, write the result, leave (ORD-0542 O2)
- any file not named under In: stop with DESIGN-GAP and hand it back to infra-design (ORD-0548, item 30)

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [ ] `AC-H1` *(human)* `make -C claude/workflow dag-test CASE=author-verbs` exits 0 and prints one `ok <verb> plan, apply, migrate and rollback` line for each of node-edit node-move node-rm step-add node-prio (proof: command, exit code and output pasted by work-order.sh evidence; ORD-0552 O2)
- [ ] `AC-H2` *(human)* the same run prints `ok node-move into a cycle is refused DG-CYCLE` and `ok node-prio reorders the ready set from dag-plan` (proof: command, exit code and output pasted by work-order.sh evidence; ORD-0552 O2)

## Test plan

_Test plan from claude/workflow/templates/test-plan.md, shaped by claude/workflow/schemas/test-plan.schema.json. The tester runs exactly these cases and nothing else._

**Scope under test**

dag-author.sh node-edit node-move node-rm step-add node-prio on a temp copy

**Cases**

- `TP-1`
  - intent: every authoring change migrates live runs and rolls back (item 40)
  - command: `make -C claude/workflow dag-test CASE=author-verbs`
  - expected: exit 0; five `ok  <verb> plan, apply, migrate and rollback` lines
- `TP-2`
  - intent: a cycle makes next permanently empty
  - command: `make -C claude/workflow dag-test CASE=author-verbs`
  - expected: exit 0; prints `ok  node-move into a cycle is refused DG-CYCLE`
- `TP-3`
  - intent: reprioritised nodes must run first
  - command: `make -C claude/workflow dag-test CASE=author-verbs`
  - expected: exit 0; prints `ok  node-prio reorders the ready set from dag-plan`

**Isolation**

- runtime: podman
- image: `docker.io/library/debian:bookworm-slim@sha256:3783cc01769c7b2b1b83a5c5ad96c815348e28ed7da68e2e3687004faa906251` (debian:bookworm-slim, base of localhost/dotfiles-workflow-test:1)

**Out of scope - CI covers**

- the full dag suite

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
