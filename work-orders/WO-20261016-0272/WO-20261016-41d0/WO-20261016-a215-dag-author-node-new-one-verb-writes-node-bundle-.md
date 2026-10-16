---
{
  "id": "WO-20261016-a215",
  "slug": "dag-author-node-new-one-verb-writes-node-bundle-",
  "title": "dag-author node-new: one verb writes node, bundle stubs, mermaid, spec node list and a migration plan",
  "type": "feature",
  "status": "draft",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T06:08:08+00:00",
  "parent": "WO-20261016-41d0",
  "branch": null,
  "pr": null,
  "closed": null,
  "approval": null,
  "evidence": null,
  "surfaces": [],
  "depends_on": [
    "WO-20261016-1e26",
    "WO-20261016-3f4f",
    "WO-20261016-e271"
  ],
  "blocks": [
    "WO-20261016-c399",
    "WO-20261016-6082"
  ],
  "labels": [
    "line:inbox-triage"
  ]
}
---

# WO-20261016-a215 - dag-author node-new: one verb writes node, bundle stubs, mermaid, spec node list and a migration plan

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

Owner, 2026-10-16 UTC: "DAG SHOULD BE EFFORTLESS WITH EASY MIGRATION PLANS FOR UPDATED CREATING DELETING MOVING NODES AND ADDING STEPS OR WHATEVER RUNBOOKS DOCS THE WHOLE NINE YARDS" and "nodes can move around and be shifted and reprioritized". Evidence: dotfiles #140 merged the dag-state design; no dag-plan/apply/migrate script exists on main at 06:15Z. Build exactly to docs/design/dag-state.spec.xml and docs/design/dag-state-nodes.spec.xml (design docs/design/dag-state.md); never redesign. Item 40: "Creating, updating, deleting and moving a node, and adding a step, are each one Make verb that writes the node, its checklist, runbook, playbook and docs, regenerates the mermaid DAG, the XML spec and the index, and writes the migration plan that moves every live run onto the change, with a plan shown before apply and a scripted rollback. Nothing in a DAG is edited by hand."

## Scope

**In**

- touches: claude/workflow/dag/bin/dag-author.sh
- touches: claude/workflow/dag/tests/unit/test_dag_author.sh
- touches: claude/workflow/dag/dag.mk
- touches: docs/design/dag-state.md
- touches: docs/design/dag-state-nodes.spec.xml
- touches: claude/workflow/dag/generated.sha256
- step: docs/design/dag-state.md: wrap the intake mermaid block in `&lt;!-- dag:mermaid:begin --&gt;`/`&lt;!-- dag:mermaid:end --&gt;`; dag-state-nodes.spec.xml: wrap <nodes> children in `&lt;!-- dag:nodes:begin --&gt;`/`&lt;!-- dag:nodes:end --&gt;` (one-time marker insert, content unchanged)
- step: dag-author.sh node-new --id ID --kind KIND --after ID[,ID] [--dag DIR] [--apply]: without --apply print the plan (files to write, version from -> to, live runs under the run root of dag.json) and write nothing; with --apply write nodes/ID.node.json from a template valid against node.schema.json, append `&lt;!-- dag:node:ID:begin --&gt;` stub sections to RB-dag-intake.md and PB-intake.md, regenerate the mermaid block (graph TD from every node's after) and the spec node list from nodes/*.node.json, bump dag.json design_version minor, write the migration plan JSON to `~/.local/state/zenith/dag-migration/YYYY/MM/YYYYMMDD-HHMMSS-node-new-<ID>.json` {what, by, repo, branch, created, from_version, to_version, changes, live_runs, apply: "make dag-migrate RUN=<run>", rollback: "make dag-migrate-rollback RUN=<run>"}, and rewrite generated.sha256 over every generated file
- step: a repeat of the same node-new --apply prints DG-NOCHANGE and writes nothing (idempotent)
- step: dag.mk: `dag-node-new ID= KIND= AFTER= [APPLY=1]` through $(TIMED)
- step: test: a temp copy of the dag dir and docs; fixture run at 1.0.0 reaches 1.1.0 by node-new plus dag-migrate and rolls back
- step: run `make -C claude/workflow dag-test CASE=author-new`
- tool: make:claude/workflow/dag/dag.mk:dag-test - NOT on main: ticket stays draft until it lands; fallback: target missing or failing to parse: stop with DESIGN-GAP naming the target; no hand-run substitute

**Out - non-goals**

- work-orders/INDEX.md by hand: work-order.sh writes it, and the reindex Action is owned by merge-port-build (F11, ORD-0545 O1)
- waiting on CI or merging: push, open the PR, write the result, leave (ORD-0542 O2)
- any file not named under In: stop with DESIGN-GAP and hand it back to infra-design (ORD-0548, item 30)

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [ ] `AC-H1` *(human)* `make -C claude/workflow dag-test CASE=author-new` exits 0 and prints `ok node-new without APPLY writes nothing and prints the plan` (proof: command, exit code and output pasted by work-order.sh evidence; ORD-0552 O2)
- [ ] `AC-H2` *(human)* the same run prints `ok node-new APPLY writes node, bundle stubs, mermaid, spec list, manifest and migration plan in one run`, `ok a repeat is DG-NOCHANGE` and `ok a 1.0.0 run reaches 1.1.0 by dag-migrate and back by rollback` (proof: command, exit code and output pasted by work-order.sh evidence; ORD-0552 O2)
- [ ] `AC-H3` *(human)* `make spec-check` exits 0 (proof: command, exit code and output pasted by work-order.sh evidence; ORD-0552 O2)

## Test plan

_Test plan from claude/workflow/templates/test-plan.md, shaped by claude/workflow/schemas/test-plan.schema.json. The tester runs exactly these cases and nothing else._

**Scope under test**

claude/workflow/dag/bin/dag-author.sh node-new and its regeneration, on a temp copy

**Cases**

- `TP-1`
  - intent: a plan must be shown before apply (item 40)
  - command: `make -C claude/workflow dag-test CASE=author-new`
  - expected: exit 0; prints `ok  node-new without APPLY writes nothing and prints the plan`
- `TP-2`
  - intent: one verb, the whole nine yards
  - command: `make -C claude/workflow dag-test CASE=author-new`
  - expected: exit 0; prints `ok  node-new APPLY writes node, bundle stubs, mermaid, spec list, manifest and migration plan in one run`
- `TP-3`
  - intent: migration is the test of the design (item 16)
  - command: `make -C claude/workflow dag-test CASE=author-new`
  - expected: exit 0; prints `ok  a 1.0.0 run reaches 1.1.0 by dag-migrate and back by rollback`

**Isolation**

- runtime: podman
- image: `docker.io/library/debian:bookworm-slim@sha256:3783cc01769c7b2b1b83a5c5ad96c815348e28ed7da68e2e3687004faa906251` (debian:bookworm-slim, base of localhost/dotfiles-workflow-test:1)

**Out of scope - CI covers**

- the full dag suite and spec-check

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
