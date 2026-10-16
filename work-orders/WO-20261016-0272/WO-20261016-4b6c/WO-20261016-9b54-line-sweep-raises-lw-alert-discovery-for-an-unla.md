---
{
  "id": "WO-20261016-9b54",
  "slug": "line-sweep-raises-lw-alert-discovery-for-an-unla",
  "title": "line-sweep raises LW-ALERT-DISCOVERY for an unlabelled claude pane in a line workspace",
  "type": "feature",
  "status": "ready",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T06:23:11+00:00",
  "parent": "WO-20261016-4b6c",
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
  "depends_on": [],
  "blocks": [
    "WO-20261016-e77c"
  ]
}
---

# WO-20261016-9b54 - line-sweep raises LW-ALERT-DISCOVERY for an unlabelled claude pane in a line workspace

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

ORD-0606 D4 (relayed 2026-10-16T06:17Z): "Prevention: line-sweep raises LW-ALERT-DISCOVERY for any claude pane in a line workspace without a label, and yp-line spawns only through seat-up." Evidence: wDD:pD and wDD:pE ran as unlabelled seats outside the grid. adopt_named (claude/workflow/bin/line-watch.sh:209) adopts named panes only; an unnamed claude pane is invisible.

## Scope

**In**

- touches: claude/workflow/bin/line-watch.sh
- touches: claude/workflow/tests/unit/test_line_watch.sh
- touches: claude/workflow/config/line-watch.json
- step: after adopt_named each tick: for every `herdr agent list` entry in WS whose agent is claude and whose pane has no label (or label `free R.C`) and no name, publish and log `LW-ALERT-DISCOVERY\t<pane> unlabelled claude pane (cwd <cwd>)` once per pane (dedupe in the sweep state)
- step: config/line-watch.json: add LW-ALERT-DISCOVERY to the alert codes list beside LW-PERM-MISSING
- step: test with the existing stub herdr of test_line_watch.sh; run `make -C claude/workflow test` is not needed: run `make -C claude/workflow image && podman run --rm --network=none --userns=keep-id -v "$PWD:/work:Z" -w /work -e HOME=/tmp localhost/dotfiles-workflow-test:1 bash -c 'bash claude/workflow/tests/unit/test_line_watch.sh'`
- tool: path:claude/workflow/tests/container/Containerfile - on main; fallback: no fallback permitted (dotfiles Rule 14, never the host): podman or the image missing stops the node with ENV-MISSING podman
- tool: path:claude/workflow/bin/line-watch.sh - on main; fallback: missing: stop with ENV-MISSING naming it

**Out - non-goals**

- work-orders/INDEX.md by hand: work-order.sh writes it, and the reindex Action is owned by merge-port-build (F11, ORD-0545 O1)
- waiting on CI or merging: push, open the PR, write the result, leave (ORD-0542 O2)
- any file not named under In: stop with DESIGN-GAP and hand it back to infra-design (ORD-0548, item 30)

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [ ] `AC-H1` *(human)* `make -C claude/workflow image && podman run --rm --network=none --userns=keep-id -v "$PWD:/work:Z" -w /work -e HOME=/tmp localhost/dotfiles-workflow-test:1 bash -c 'bash claude/workflow/tests/unit/test_line_watch.sh'` exits 0 and its output matches /ok an unlabelled claude pane raises LW-ALERT-DISCOVERY once/ (proof: command, exit code and output pasted by work-order.sh evidence; ORD-0552 O2)

## Test plan

_Test plan from claude/workflow/templates/test-plan.md, shaped by claude/workflow/schemas/test-plan.schema.json. The tester runs exactly these cases and nothing else._

**Scope under test**

line-watch.sh discovery alert against the stub herdr

**Cases**

- `TP-1`
  - intent: a seat outside the grid is unwatched and unpaid-for (ORD-0606 D4)
  - command: `make -C claude/workflow image && podman run --rm --network=none --userns=keep-id -v "$PWD:/work:Z" -w /work -e HOME=/tmp localhost/dotfiles-workflow-test:1 bash -c 'bash claude/workflow/tests/unit/test_line_watch.sh'`
  - expected: exit 0; prints `ok  an unlabelled claude pane raises LW-ALERT-DISCOVERY once`
- `TP-2`
  - intent: fallback path: a labelled or named pane raises nothing
  - command: `make -C claude/workflow image && podman run --rm --network=none --userns=keep-id -v "$PWD:/work:Z" -w /work -e HOME=/tmp localhost/dotfiles-workflow-test:1 bash -c 'bash claude/workflow/tests/unit/test_line_watch.sh'`
  - expected: exit 0; prints `ok  a labelled seat raises no discovery alert`

**Isolation**

- runtime: podman
- image: `docker.io/library/debian:bookworm-slim@sha256:3783cc01769c7b2b1b83a5c5ad96c815348e28ed7da68e2e3687004faa906251` (debian:bookworm-slim, base of localhost/dotfiles-workflow-test:1)

**Out of scope - CI covers**

- the full workflow suite

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
