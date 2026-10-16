---
{
  "id": "WO-20261016-efb2",
  "slug": "dag-state-t6-intake-node-declarations-n1-to-n10",
  "title": "dag-state T6 - Intake node declarations N1 to N10",
  "type": "feature",
  "status": "done",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T09:07:38+00:00",
  "parent": "WO-20261016-41d0",
  "branch": "feat/dag-state-t6-intake-node-declarations-n1-to-n10",
  "pr": 297,
  "closed": "2026-10-16",
  "approval": {
    "via": "override",
    "reason": "infra-design8 cut for ORD-0837 RR-orch-18, ORD-0848 Y3 and the ORD-0830 RR-orch-14 DESIGN-GAPs; design approvals ruled done, ORD-0550 O4",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [
    "WO-20261016-acde",
    "WO-20261016-f052"
  ],
  "blocks": [
    "WO-20261016-e118",
    "WO-20261016-709f"
  ],
  "ac_checks": [
    {
      "index": 1,
      "command": "make -C claude/workflow image && podman run --rm --network=none --userns=keep-id -v \"$PWD:/work:Z\" -w /work -e HOME=/tmp localhost/dotfiles-workflow-test:1 bash -c 'for f in claude/workflow/dag/nodes/N*.node.json; do bash claude/workflow/tools/validate-schema.sh claude/workflow/dag/schemas/node.schema.json $f || exit 1; done; echo ok-nodes'",
      "exit": 0,
      "expect": "ok-nodes"
    },
    {
      "index": 2,
      "command": "make spec-check",
      "exit": 0,
      "expect": null
    },
    {
      "index": 3,
      "command": "bash -c '! git diff --name-only origin/main...HEAD | grep -vE \"^(work-orders/|claude/workflow/dag/nodes/N([1-9]|10)[.]node[.]json$)\"'",
      "exit": 0,
      "expect": null
    }
  ],
  "provides": []
}
---

# WO-20261016-efb2 - dag-state T6 - Intake node declarations N1 to N10

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

Owner, 2026-10-16 UTC: "DAG SHOULD BE EFFORTLESS WITH EASY MIGRATION PLANS FOR UPDATED CREATING DELETING MOVING NODES AND ADDING STEPS OR WHATEVER RUNBOOKS DOCS THE WHOLE NINE YARDS" and "nodes can move around and be shifted and reprioritized". Evidence: dotfiles #140 merged the dag-state design; no dag-plan/apply/migrate script exists on main at 06:15Z. Build exactly to docs/design/dag-state.spec.xml and docs/design/dag-state-nodes.spec.xml (design docs/design/dag-state.md); never redesign.

## Owner words

> see a bug, isolate it, and get it fixed as asap (Design principles 101 item 22)

> DAG SHOULD BE EFFORTLESS WITH EASY MIGRATION PLANS FOR UPDATED CREATING DELETING MOVING NODES AND ADDING STEPS OR WHATEVER RUNBOOKS DOCS THE WHOLE NINE YARDS (item 40)

## Context

DESIGN-GAP 2026-10-16T08:58Z from seat dag-t6 (seats/dag-t6.result.json): AC-H1, TP-1 and the image step named claude/workflow/bin/tools/validate-schema.sh, absent on main (git cat-file -e origin/main:claude/workflow/bin/tools/validate-schema.sh exits 128); the script is claude/workflow/tools/validate-schema.sh (usage: validate-schema.sh <schema> <instance>). infra-design8 (ORD-0830 RR-orch-14) cancelled the ready ticket and recut it with only that path corrected; nothing else changed.

## Scope

**In**

- touches: claude/workflow/dag/nodes/N1.node.json
- touches: claude/workflow/dag/nodes/N2.node.json
- touches: claude/workflow/dag/nodes/N3.node.json
- touches: claude/workflow/dag/nodes/N4.node.json
- touches: claude/workflow/dag/nodes/N5.node.json
- touches: claude/workflow/dag/nodes/N6.node.json
- touches: claude/workflow/dag/nodes/N7.node.json
- touches: claude/workflow/dag/nodes/N8.node.json
- touches: claude/workflow/dag/nodes/N9.node.json
- touches: claude/workflow/dag/nodes/N10.node.json
- step: build to <nodes> N1..N10 of dag-state-nodes.spec.xml: input, output, script, serial, retry, idempotent, checks, after; each valid against claude/workflow/dag/schemas/node.schema.json; each declares checklist_doc, runbook, playbook, docs per <bundles>
- step: every script: rolodex header (name, purpose, inputs, outputs, writes-to, cleanup), inputs by flag or config, idempotent, retries 3 where the spec says retry=3
- step: run `make -C claude/workflow image && podman run --rm --network=none --userns=keep-id -v "$PWD:/work:Z" -w /work -e HOME=/tmp localhost/dotfiles-workflow-test:1 bash -c 'for f in claude/workflow/dag/nodes/N*.node.json; do bash claude/workflow/tools/validate-schema.sh claude/workflow/dag/schemas/node.schema.json $f || exit 1; done; echo ok-nodes'`
- tool: path:claude/workflow/tests/container/Containerfile - on main; fallback: no fallback permitted (dotfiles Rule 14, never the host): podman or the image missing stops the node with ENV-MISSING podman
- tool: make:Makefile:spec-check - on main; fallback: target missing or failing to parse: stop with DESIGN-GAP naming the target; no hand-run substitute
- touches (generated, written only by work-order.sh start/submit/done, never by hand or git add): this ticket file and its archive path; work-orders/INDEX.md and the parent epic README.md are ignored generated views
- tool: cmd:git, cmd:jq, cmd:make, cmd:podman, cmd:gh - fallback: missing on the host: stop with ENV-MISSING naming it; gh or GitHub down: retry 3 times, then stop with A2A-003 and its output

**Out - non-goals**

- work-orders/INDEX.md by hand: work-order.sh writes it, and the reindex Action is owned by merge-port-build (F11, ORD-0545 O1)
- waiting on CI or merging: push, open the PR, write the result, leave (ORD-0542 O2)
- any file not named under In: stop with DESIGN-GAP and hand it back to infra-design (ORD-0548, item 30)

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [x] `AC-H1` *(human)* every node declaration N1..N10 is valid against node.schema.json
  - observed `2026-10-16` ok-nodes, exit 0 in podman --network=none
  - check: `make -C claude/workflow image && podman run --rm --network=none --userns=keep-id -v "$PWD:/work:Z" -w /work -e HOME=/tmp localhost/dotfiles-workflow-test:1 bash -c 'for f in claude/workflow/dag/nodes/N*.node.json; do bash claude/workflow/tools/validate-schema.sh claude/workflow/dag/schemas/node.schema.json $f || exit 1; done; echo ok-nodes'` exit 0 expect /ok-nodes/
- [x] `AC-H2` *(human)* the specs were read, not edited
  - observed `2026-10-16` make spec-check exit 0
  - check: `make spec-check` exit 0
- [x] `AC-H3` *(human)* the diff holds only the ten node files and generated work-orders files
  - observed `2026-10-16` diff holds only N1..N10 node files
  - check: `bash -c '! git diff --name-only origin/main...HEAD | grep -vE "^(work-orders/|claude/workflow/dag/nodes/N([1-9]|10)[.]node[.]json$)"'` exit 0

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

- `2026-10-16` infra-design10 (ORD-0921 E3): depends on WO-20261016-f052 - validate-schema.sh resolves $ref offline; seat dag-t6b DESIGN-GAP RefResolutionError under --network=none (seats/dag-t6b.result.json)

## Outcome

_Written by `work-order done`. Empty until then._
