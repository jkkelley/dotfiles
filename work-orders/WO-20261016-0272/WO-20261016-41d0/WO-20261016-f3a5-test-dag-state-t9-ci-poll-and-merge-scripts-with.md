---
{
  "id": "WO-20261016-f3a5",
  "slug": "test-dag-state-t9-ci-poll-and-merge-scripts-with",
  "title": "Test - dag-state T9 - CI poll and merge scripts with approval check",
  "type": "test",
  "status": "in-review",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T06:07:39+00:00",
  "parent": "WO-20261016-41d0",
  "branch": "feat/test-dag-state-t9-ci-poll-and-merge-scripts-with",
  "pr": 267,
  "closed": null,
  "approval": {
    "via": "override",
    "reason": "architect ruled design approvals done, ORD-0550 O4",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [
    "WO-20261016-0797"
  ],
  "blocks": []
}
---

# WO-20261016-f3a5 - Test - dag-state T9 - CI poll and merge scripts with approval check

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

Run the filled test plan of WO-20261016-0797 - dag-state T9 - CI poll and merge scripts with approval check exactly as written; dev gate (item 34), no owner notification (item 35).

## Scope

**In**

_none_

**Out - non-goals**

- writing or changing code: a failing case goes back as A2A-003 with its output
- waiting on CI or merging: push, open the PR, write the result, leave (ORD-0542 O2)
- any file not named under In: stop with DESIGN-GAP and hand it back to infra-design (ORD-0548, item 30)

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [x] `AC-H1` *(human)* every case of the plan prints its expected result (proof: the run output pasted by work-order.sh evidence)
  - observed `2026-10-16` TP-1 exit 0, 30 ok lines, last line pass=30 fail=0
- [x] `AC-H2` *(human)* the run output is written by script to ~/.local/state/zenith/log/YYYY/MM/ with frontmatter (proof: the path)
  - observed `2026-10-16` log written to /home/luna/.local/state/zenith/log/2026/10/20261016-091000-t9-test-run.md with frontmatter

## Test plan

_Test plan from claude/workflow/templates/test-plan.md, shaped by claude/workflow/schemas/test-plan.schema.json. The tester runs exactly these cases and nothing else._

**Scope under test**

claude/workflow/dag/bin/dag-ci.sh, claude/workflow/dag/bin/dag-merge.sh, claude/workflow/dag/tests/unit/test_dag_merge.sh built to nodes N8 and N9; merge by script the moment CI is green with no review gate (one PR process, owner 2026-10-16 UTC

**Cases**

- `TP-1`
  - intent: the DAG is the source; a build that drifts from docs/design/dag-state.spec.xml is rejected (item 20)
  - command: `make -C claude/workflow image && podman run --rm --network=none --userns=keep-id -v "$PWD:/work:Z" -w /work -e HOME=/tmp localhost/dotfiles-workflow-test:1 bash -c 'bash claude/workflow/dag/tests/unit/test_dag_merge.sh'`
  - expected: exit 0; every case prints ok and the last line is the pass count with fail=0

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
