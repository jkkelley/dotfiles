---
{
  "id": "WO-20261016-e271",
  "slug": "dag-state-t11-config-config-schema-dag-mk-makefi",
  "title": "dag-state T11 - Config, config schema, dag.mk, Makefile include, dag-check",
  "type": "feature",
  "status": "ready",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T06:07:51+00:00",
  "parent": "WO-20261016-41d0",
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
    "WO-20261016-05db",
    "WO-20261016-599f"
  ],
  "blocks": [
    "WO-20261016-2f1e",
    "WO-20261016-a215"
  ]
}
---

# WO-20261016-e271 - dag-state T11 - Config, config schema, dag.mk, Makefile include, dag-check

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

Owner, 2026-10-16 UTC: "DAG SHOULD BE EFFORTLESS WITH EASY MIGRATION PLANS FOR UPDATED CREATING DELETING MOVING NODES AND ADDING STEPS OR WHATEVER RUNBOOKS DOCS THE WHOLE NINE YARDS" and "nodes can move around and be shifted and reprioritized". Evidence: dotfiles #140 merged the dag-state design; no dag-plan/apply/migrate script exists on main at 06:15Z. Build exactly to docs/design/dag-state.spec.xml and docs/design/dag-state-nodes.spec.xml (design docs/design/dag-state.md); never redesign.

## Scope

**In**

- touches: claude/workflow/dag/config/dag.json
- touches: claude/workflow/dag/schemas/config.schema.json
- touches: claude/workflow/dag/dag.mk
- touches: claude/workflow/Makefile
- touches: claude/workflow/dag/bin/dag-check.sh
- step: build to dag.mk targets dag-plan dag-apply dag-drift dag-recover dag-migrate dag-migrate-rollback dag-check and `dag-test [CASE=]` (podman, --network=none, the workflow test image; runs every tests/unit/test_dag_*.sh with env CASE passed, a test given CASE runs only that case), inputs VAR=value, every recipe through $(TIMED); claude/workflow/Makefile gains `include dag/dag.mk`; dag.json carries design_version 1.0.0
- step: every script: rolodex header (name, purpose, inputs, outputs, writes-to, cleanup), inputs by flag or config, idempotent, retries 3 where the spec says retry=3
- step: run `make -C claude/workflow image && podman run --rm --network=none --userns=keep-id -v "$PWD:/work:Z" -w /work -e HOME=/tmp localhost/dotfiles-workflow-test:1 bash -c 'for f in claude/workflow/dag/config/dag.json claude/workflow/dag/schemas/config.schema.json claude/workflow/dag/dag.mk claude/workflow/Makefile claude/workflow/dag/bin/dag-check.sh; do test -s $f || exit 1; done; echo ok-files'`
- tool: path:claude/workflow/tests/container/Containerfile - on main; fallback: no fallback permitted (dotfiles Rule 14, never the host): podman or the image missing stops the node with ENV-MISSING podman
- tool: path:claude/workflow/bin/timed-run.sh - on main; fallback: bus down: timed-run warns `WARN bus unreachable` and the step runs with its own exit code (tm_event); covered by the bus-down case
- tool: make:Makefile:spec-check - on main; fallback: target missing or failing to parse: stop with DESIGN-GAP naming the target; no hand-run substitute
- provides: make:claude/workflow/dag/dag.mk:dag-test (created by this ticket)

**Out - non-goals**

- work-orders/INDEX.md by hand: work-order.sh writes it, and the reindex Action is owned by merge-port-build (F11, ORD-0545 O1)
- waiting on CI or merging: push, open the PR, write the result, leave (ORD-0542 O2)
- any file not named under In: stop with DESIGN-GAP and hand it back to infra-design (ORD-0548, item 30)

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [ ] `AC-H1` *(human)* `make -C claude/workflow image && podman run --rm --network=none --userns=keep-id -v "$PWD:/work:Z" -w /work -e HOME=/tmp localhost/dotfiles-workflow-test:1 bash -c 'for f in claude/workflow/dag/config/dag.json claude/workflow/dag/schemas/config.schema.json claude/workflow/dag/dag.mk claude/workflow/Makefile claude/workflow/dag/bin/dag-check.sh; do test -s $f || exit 1; done; echo ok-files'` exit 0 (proof: command, exit code and output pasted by work-order.sh evidence; ORD-0552 O2)
- [ ] `AC-H2` *(human)* `make spec-check` exits 0 (the specs were read, not edited) (proof: command, exit code and output pasted by work-order.sh evidence; ORD-0552 O2)
- [ ] `AC-H3` *(human)* `git diff --name-only origin/main` lists only the files under In (proof: command, exit code and output pasted by work-order.sh evidence; ORD-0552 O2)

## Test plan

_Test plan from claude/workflow/templates/test-plan.md, shaped by claude/workflow/schemas/test-plan.schema.json. The tester runs exactly these cases and nothing else._

**Scope under test**

claude/workflow/dag/config/dag.json, claude/workflow/dag/schemas/config.schema.json, claude/workflow/dag/dag.mk, claude/workflow/Makefile, claude/workflow/dag/bin/dag-check.sh built to dag.mk targets dag-plan dag-apply dag-drift dag-recover dag-migrate dag-migrate-rollback dag-check and `dag-test [CASE=]` (podman, --network=none, the workflow test image; runs every tests/unit/test_dag_*.sh with env CASE passed, a test given CASE runs only that case), inputs VAR=value, every recipe through $(TIMED); claude/workflow/Makefile gains `include dag/dag.mk`; dag.json carries design_version 1.0.0

**Cases**

- `TP-1`
  - intent: the DAG is the source; a build that drifts from docs/design/dag-state.spec.xml is rejected (item 20)
  - command: `make -C claude/workflow image && podman run --rm --network=none --userns=keep-id -v "$PWD:/work:Z" -w /work -e HOME=/tmp localhost/dotfiles-workflow-test:1 bash -c 'for f in claude/workflow/dag/config/dag.json claude/workflow/dag/schemas/config.schema.json claude/workflow/dag/dag.mk claude/workflow/Makefile claude/workflow/dag/bin/dag-check.sh; do test -s $f || exit 1; done; echo ok-files'`
  - expected: exit 0

**Isolation**

- runtime: podman
- image: `docker.io/library/debian:bookworm-slim@sha256:3783cc01769c7b2b1b83a5c5ad96c815348e28ed7da68e2e3687004faa906251` (debian:bookworm-slim, base of localhost/dotfiles-workflow-test:1)

**Out of scope - CI covers**

- the full dag and workflow suites

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
