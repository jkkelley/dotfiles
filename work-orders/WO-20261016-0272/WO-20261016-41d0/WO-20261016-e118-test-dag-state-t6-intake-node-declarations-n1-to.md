---
{
  "id": "WO-20261016-e118",
  "slug": "test-dag-state-t6-intake-node-declarations-n1-to",
  "title": "Test - dag-state T6 - Intake node declarations N1 to N10",
  "type": "test",
  "status": "in-progress",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T09:07:51+00:00",
  "parent": "WO-20261016-41d0",
  "branch": "feat/test-dag-state-t6-intake-node-declarations-n1-to",
  "pr": null,
  "closed": null,
  "approval": {
    "via": "override",
    "reason": "infra-design8 cut for ORD-0837 RR-orch-18, ORD-0848 Y3 and the ORD-0830 RR-orch-14 DESIGN-GAPs; design approvals ruled done, ORD-0550 O4",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [
    "WO-20261016-efb2"
  ],
  "blocks": [],
  "ac_checks": [
    {
      "index": 1,
      "command": "make -C claude/workflow image && podman run --rm --network=none --userns=keep-id -v \"$PWD:/work:Z\" -w /work -e HOME=/tmp localhost/dotfiles-workflow-test:1 bash -c 'for f in claude/workflow/dag/nodes/N*.node.json; do bash claude/workflow/tools/validate-schema.sh claude/workflow/dag/schemas/node.schema.json $f || exit 1; done; echo ok-nodes'",
      "exit": 0,
      "expect": "ok-nodes"
    },
    {
      "index": 2,
      "command": "bash -c 'ls ~/.local/state/zenith/log/$(date -u +%Y/%m)/ | grep -q dag-t6-test'",
      "exit": 0,
      "expect": null
    }
  ],
  "provides": []
}
---

# WO-20261016-e118 - Test - dag-state T6 - Intake node declarations N1 to N10

## Contents

- Problem
- Owner words
- Context
- Scope
- Degrees of freedom
- Acceptance criteria
- Test plan
- Assumptions
- Open questions
- Notes
- Outcome

## Problem

Run the filled test plan of WO-20261016-2397 - dag-state T6 - Intake node declarations N1 to N10 exactly as written; dev gate (item 34), no owner notification (item 35).

## Owner words

> i want work scoped so small a fuck ape could do, testing the same way with test plans and scripts (Design principles 101 item 30)

> Ensure that your testing is dev uat stable. (item 34)

## Context

DESIGN-GAP 2026-10-16T08:58Z from seat dag-t6 (seats/dag-t6.result.json): AC-H1, TP-1 and the image step named claude/workflow/bin/tools/validate-schema.sh, absent on main (git cat-file -e origin/main:claude/workflow/bin/tools/validate-schema.sh exits 128); the script is claude/workflow/tools/validate-schema.sh (usage: validate-schema.sh <schema> <instance>). infra-design8 (ORD-0830 RR-orch-14) cancelled the ready ticket and recut it with only that path corrected; nothing else changed.

This test ticket runs the plan of the recut T6 build ticket; it was recut with it because its TP-1 named the same missing path.

## Scope

**In**

- touches: none (read-only run on origin/main; the run output goes by script to ~/.local/state/zenith/log/YYYY/MM/ named *-dag-t6-test.txt with frontmatter)
- touches (generated, written only by work-order.sh start/submit/done, never by hand or git add): this ticket file and its archive path; work-orders/INDEX.md and the parent epic README.md are ignored generated views
- step: in your own detached worktree of origin/main after WO-20261016-efb2 merged, run TP-1 exactly as written; record it with work-order.sh evidence
- tool: cmd:git, cmd:jq, cmd:make, cmd:podman, cmd:gh - fallback: missing on the host: stop with ENV-MISSING naming it; gh or GitHub down: retry 3 times, then stop with A2A-003 and its output

**Out - non-goals**

- writing or changing code: a failing case goes back as A2A-003 with its output
- waiting on CI or merging: push, open the PR, write the result, leave (ORD-0542 O2)
- any file not named under In: stop with DESIGN-GAP and hand it back to infra-design (ORD-0548, item 30)

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [x] `AC-H1` *(human)* TP-1 prints ok-nodes and exits 0
  - observed `2026-10-16` TP-1 exit 0, printed ok-nodes; log ~/.local/state/zenith/log/2026/10/20261016-102504-dag-t6-test.txt
  - check: `make -C claude/workflow image && podman run --rm --network=none --userns=keep-id -v "$PWD:/work:Z" -w /work -e HOME=/tmp localhost/dotfiles-workflow-test:1 bash -c 'for f in claude/workflow/dag/nodes/N*.node.json; do bash claude/workflow/tools/validate-schema.sh claude/workflow/dag/schemas/node.schema.json $f || exit 1; done; echo ok-nodes'` exit 0 expect /ok-nodes/
- [x] `AC-H2` *(human)* the run output is written by script to the artifact store with frontmatter
  - observed `2026-10-16` ls of log dir greps dag-t6-test, exit 0: 20261016-102504-dag-t6-test.txt with frontmatter
  - check: `bash -c 'ls ~/.local/state/zenith/log/$(date -u +%Y/%m)/ | grep -q dag-t6-test'` exit 0

## Test plan

_Test plan from claude/workflow/templates/test-plan.md, shaped by claude/workflow/schemas/test-plan.schema.json. The tester runs exactly these cases and nothing else._

**Scope under test**

claude/workflow/dag/nodes/N1.node.json, claude/workflow/dag/nodes/N2.node.json, claude/workflow/dag/nodes/N3.node.json, claude/workflow/dag/nodes/N4.node.json, claude/workflow/dag/nodes/N5.node.json, claude/workflow/dag/nodes/N6.node.json, claude/workflow/dag/nodes/N7.node.json, claude/workflow/dag/nodes/N8.node.json, claude/workflow/dag/nodes/N9.node.json, claude/workflow/dag/nodes/N10.node.json built to <nodes> N1..N10 of dag-state-nodes.spec.xml

**Cases**

- `TP-1`
  - intent: the DAG is the source; a build that drifts from docs/design/dag-state.spec.xml is rejected (item 20)
  - command: `make -C claude/workflow image && podman run --rm --network=none --userns=keep-id -v "$PWD:/work:Z" -w /work -e HOME=/tmp localhost/dotfiles-workflow-test:1 bash -c 'for f in claude/workflow/dag/nodes/N*.node.json; do bash claude/workflow/tools/validate-schema.sh claude/workflow/dag/schemas/node.schema.json $f || exit 1; done; echo ok-nodes'`
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
