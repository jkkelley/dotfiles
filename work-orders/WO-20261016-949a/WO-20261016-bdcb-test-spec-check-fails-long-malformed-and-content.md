---
{
  "id": "WO-20261016-bdcb",
  "slug": "test-spec-check-fails-long-malformed-and-content",
  "title": "Test spec-check - fails long, malformed and contents-less specs",
  "type": "test",
  "status": "in-progress",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T04:43:27+00:00",
  "parent": "WO-20261016-949a",
  "branch": "feat/test-spec-check-fails-long-malformed-and-content",
  "pr": null,
  "closed": null,
  "approval": {
    "via": "override",
    "reason": "owner: i approved of everything (brief BR-20261016-spec-check)",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [
    "WO-20261016-04d3"
  ],
  "blocks": []
}
---

# WO-20261016-bdcb - Test spec-check - fails long, malformed and contents-less specs

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

spec-check needs a scripted test plan run in podman.

## Scope

**In**

- files: scripts/tests/test_spec_check.sh (new)
- commands: make spec-check-test
- docs: claude/workflow/templates/test-plan.md; CLAUDE.md Rule 14

**Out - non-goals**

- full suite (CI owns it)

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [ ] `AC-H1` *(human)* make spec-check-test prints 12 ok lines and no not ok line
- [ ] `AC-H2` *(human)* evidence: repro command and output written by claude/tools/artifact/artifact.sh new --key log to the artifact store, path in the PR body

## Test plan

_Test plan from claude/workflow/templates/test-plan.md, shaped by claude/workflow/schemas/test-plan.schema.json. The tester runs exactly these cases and nothing else._

**Scope under test**

scripts/spec-check.sh, behind make spec-check

**Cases**

- `TP-1`
  - intent: a spec over the 1000-line cap merges and no agent reads it whole
  - command: `bash scripts/tests/test_spec_check.sh`
  - expected: exit 0; line `ok - 1001 lines exits 3`
- `TP-2`
  - intent: a malformed spec merges and every seat reading it fails
  - command: `bash scripts/tests/test_spec_check.sh`
  - expected: exit 0; line `ok - malformed exits 3`
- `TP-3`
  - intent: a spec with no contents element forces agents to read it whole to find a section
  - command: `bash scripts/tests/test_spec_check.sh`
  - expected: exit 0; line `ok - no contents element exits 3`
- `TP-4`
  - intent: a good spec is refused and the gate blocks the line
  - command: `bash scripts/tests/test_spec_check.sh`
  - expected: exit 0; lines `ok - good spec exits 0` and `ok - 1000 lines exits 0`
- `TP-5`
  - intent: a check that writes or drifts between runs is not idempotent
  - command: `bash scripts/tests/test_spec_check.sh`
  - expected: exit 0; line `ok - two runs same output, nothing written`
- `TP-6`
  - intent: bad usage must be told apart from a violation
  - command: `bash scripts/tests/test_spec_check.sh`
  - expected: exit 0; line `ok - bad usage exits 2`

**Isolation**

- runtime: podman
- image: `localhost/dotfiles-workflow-test:1` built FROM `docker.io/library/debian@sha256:3783cc01769c7b2b1b83a5c5ad96c815348e28ed7da68e2e3687004faa906251` (debian:bookworm-slim)

**Out of scope - CI covers**

- the md-contents job in .github/workflows/skill-pr-gate.yml runs make spec-check on the changed files

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
