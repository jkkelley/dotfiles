---
{
  "id": "WO-20261016-1e26",
  "slug": "dag-state-t7-runbooks-and-playbooks-for-n1-to-n1",
  "title": "dag-state T7 - Runbooks and playbooks for N1 to N10",
  "type": "feature",
  "status": "done",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T06:07:19+00:00",
  "parent": "WO-20261016-41d0",
  "branch": "feat/dag-state-t7-runbooks-and-playbooks-for-n1-to-n1",
  "pr": 212,
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
    "WO-20261016-bb80",
    "WO-20261016-a215"
  ],
  "labels": [
    "line:inbox-triage"
  ]
}
---

# WO-20261016-1e26 - dag-state T7 - Runbooks and playbooks for N1 to N10

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

- touches: claude/workflow/runbooks/RB-dag-intake.md
- touches: claude/workflow/dag/playbooks/PB-intake.md
- step: build to <bundles>: runbook sections Who does what / State / Steps / Check / Failure modes; playbook sections Input / Steps / Output / Proofs, one H3 per node N1..N10 wrapped in `&lt;!-- dag:node:N<i>:begin --&gt;`/`end` markers; each file opens with a contents list (make md-contents FILES=<file>)
- step: every script: rolodex header (name, purpose, inputs, outputs, writes-to, cleanup), inputs by flag or config, idempotent, retries 3 where the spec says retry=3
- step: run `make md-contents-check`
- tool: make:Makefile:md-contents-check - on main; fallback: target missing or failing to parse: stop with DESIGN-GAP naming the target; no hand-run substitute

**Out - non-goals**

- work-orders/INDEX.md by hand: work-order.sh writes it, and the reindex Action is owned by merge-port-build (F11, ORD-0545 O1)
- waiting on CI or merging: push, open the PR, write the result, leave (ORD-0542 O2)
- any file not named under In: stop with DESIGN-GAP and hand it back to infra-design (ORD-0548, item 30)

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [x] `AC-H1` *(human)* `make md-contents-check` exit 0 (proof: command, exit code and output pasted by work-order.sh evidence; ORD-0552 O2)
  - observed `2026-10-16` make md-contents-check exit 0: md-contents: nothing in scope
- [x] `AC-H2` *(human)* `make spec-check` exits 0 (the specs were read, not edited) (proof: command, exit code and output pasted by work-order.sh evidence; ORD-0552 O2)
  - observed `2026-10-16` make spec-check exit 0: spec-check: nothing in scope (specs unedited, diff touches no *.spec.xml)
- [x] `AC-H3` *(human)* `git diff --name-only origin/main` lists only the files under In (proof: command, exit code and output pasted by work-order.sh evidence; ORD-0552 O2)
  - observed `2026-10-16` git diff --name-only origin/main (HEAD incl. staged): claude/workflow/dag/playbooks/PB-intake.md claude/workflow/runbooks/RB-dag-intake.md - only the two In files plus generated work-orders files

## Test plan

_Test plan from claude/workflow/templates/test-plan.md, shaped by claude/workflow/schemas/test-plan.schema.json. The tester runs exactly these cases and nothing else._

**Scope under test**

claude/workflow/runbooks/RB-dag-intake.md, claude/workflow/dag/playbooks/PB-intake.md built to <bundles>

**Cases**

- `TP-1`
  - intent: the DAG is the source; a build that drifts from docs/design/dag-state.spec.xml is rejected (item 20)
  - command: `make md-contents-check`
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
