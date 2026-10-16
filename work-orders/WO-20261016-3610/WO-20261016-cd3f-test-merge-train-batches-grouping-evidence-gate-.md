---
{
  "id": "WO-20261016-cd3f",
  "slug": "test-merge-train-batches-grouping-evidence-gate-",
  "title": "Test merge-train batches - grouping, evidence gate, cadence, rollback",
  "type": "test",
  "status": "draft",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T04:58:42+00:00",
  "parent": "WO-20261016-3610",
  "branch": null,
  "pr": null,
  "closed": null,
  "approval": null,
  "evidence": null,
  "surfaces": [],
  "depends_on": [
    "WO-20261016-3efc"
  ],
  "blocks": [],
  "labels": [
    "line:inbox-triage"
  ]
}
---

# WO-20261016-cd3f - Test merge-train batches - grouping, evidence gate, cadence, rollback

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

Batch mode needs a plan a tester can run without judgement

## Scope

**In**

_none_

**Out - non-goals**

- live merges on real repositories - UAT covers it

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [ ] `AC-H1` *(human)* every case in the plan passes

## Test plan

_Test plan from claude/workflow/templates/test-plan.md, shaped by claude/workflow/schemas/test-plan.schema.json. The tester runs exactly these cases and nothing else._

**Scope under test**

tools/merge-train/merge-train.sh batch mode (BATCH=1): grouping, evidence gate, cadence, rollback.

**Cases**

- `TP-1`
  - intent: two PRs touching the same file in one concurrent batch would race and re-create the conflict storm seen on ypconsult-01-src
  - command: `make -C tools/merge-train test CASE=batch-grouping`
  - expected: exit 0; the JSON plan puts PRs sharing a file in different batches and orders them by DAG layer
- `TP-2`
  - intent: a PR merging without dev and UAT evidence breaks item 34 and ships untested code
  - command: `make -C tools/merge-train test CASE=evidence-gate`
  - expected: exit 0; the stub PR with no evidence is skipped with reason no-evidence and the stub gh records no merge call for it
- `TP-3`
  - intent: a hard-coded interval breaks item 17 and cannot be tuned per line
  - command: `make -C tools/merge-train test CASE=cadence`
  - expected: exit 0; CADENCE=5 and config default 30 both produce the stated interval in the plan JSON
- `TP-4`
  - intent: a stable failure with no rollback leaves main broken overnight
  - command: `make -C tools/merge-train test CASE=stable-rollback`
  - expected: exit 0; a stubbed failing stable gate triggers the rollback script and the summary reports rolled-back

**Isolation**

- runtime: podman
- image: `docker.io/library/debian@sha256:3783cc01769c7b2b1b83a5c5ad96c815348e28ed7da68e2e3687004faa906251` (bookworm-slim, base of localhost/dotfiles-workflow-test:1)

**Out of scope - CI covers**

- lint and the full merge-train suite run in the PR gate

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
