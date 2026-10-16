---
{
  "id": "WO-20261016-42cb",
  "slug": "dag-check-generated-ci-fails-a-hand-edit-of-any-",
  "title": "dag-check --generated: CI fails a hand edit of any generated DAG file",
  "type": "feature",
  "status": "draft",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T06:08:24+00:00",
  "parent": "WO-20261016-41d0",
  "branch": null,
  "pr": null,
  "closed": null,
  "approval": null,
  "evidence": null,
  "surfaces": [],
  "depends_on": [
    "WO-20261016-6082"
  ],
  "blocks": [
    "WO-20261016-0d2a"
  ],
  "labels": [
    "line:inbox-triage"
  ]
}
---

# WO-20261016-42cb - dag-check --generated: CI fails a hand edit of any generated DAG file

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

Owner, 2026-10-16 UTC: "DAG SHOULD BE EFFORTLESS WITH EASY MIGRATION PLANS FOR UPDATED CREATING DELETING MOVING NODES AND ADDING STEPS OR WHATEVER RUNBOOKS DOCS THE WHOLE NINE YARDS" and "nodes can move around and be shifted and reprioritized". Evidence: dotfiles #140 merged the dag-state design; no dag-plan/apply/migrate script exists on main at 06:15Z. Build exactly to docs/design/dag-state.spec.xml and docs/design/dag-state-nodes.spec.xml (design docs/design/dag-state.md); never redesign. Brief: "a fast CI check fails a hand edit of any generated DAG file". Nothing in a DAG is edited by hand (item 40).

## Scope

**In**

- touches: claude/workflow/dag/bin/dag-check.sh
- touches: claude/workflow/dag/tests/unit/test_dag_check.sh
- touches: claude/workflow/dag/dag.mk
- step: dag-check.sh --generated: recompute sha256 of every path in claude/workflow/dag/generated.sha256 (and the marker-bounded regions of dag-state.md, dag-state-nodes.spec.xml, RB-dag-intake.md, PB-intake.md) and regenerate them into a temp dir from nodes/*.node.json; any mismatch prints `DG-HAND-EDIT <path>` and exits 1
- step: dag.mk: dag-check runs --generated; dag-test includes it
- step: run `make -C claude/workflow dag-test CASE=check-generated`
- tool: make:claude/workflow/dag/dag.mk:dag-test - NOT on main: ticket stays draft until it lands; fallback: target missing or failing to parse: stop with DESIGN-GAP naming the target; no hand-run substitute

**Out - non-goals**

- editing .github/workflows: the CI job already runs `make -C claude/workflow test`, which includes dag-test after t11
- work-orders/INDEX.md by hand: work-order.sh writes it, and the reindex Action is owned by merge-port-build (F11, ORD-0545 O1)
- waiting on CI or merging: push, open the PR, write the result, leave (ORD-0542 O2)
- any file not named under In: stop with DESIGN-GAP and hand it back to infra-design (ORD-0548, item 30)

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [ ] `AC-H1` *(human)* `make -C claude/workflow dag-test CASE=check-generated` exits 0 and prints `ok a hand-edited mermaid block fails with DG-HAND-EDIT` and `ok a regenerated tree passes` (proof: command, exit code and output pasted by work-order.sh evidence; ORD-0552 O2)

## Test plan

_Test plan from claude/workflow/templates/test-plan.md, shaped by claude/workflow/schemas/test-plan.schema.json. The tester runs exactly these cases and nothing else._

**Scope under test**

dag-check.sh --generated

**Cases**

- `TP-1`
  - intent: a hand edit is drift from the DAG source of truth (item 20, 40)
  - command: `make -C claude/workflow dag-test CASE=check-generated`
  - expected: exit 0; prints `ok  a hand-edited mermaid block fails with DG-HAND-EDIT`
- `TP-2`
  - intent: a clean tree must pass or CI blocks every PR
  - command: `make -C claude/workflow dag-test CASE=check-generated`
  - expected: exit 0; prints `ok  a regenerated tree passes`

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
