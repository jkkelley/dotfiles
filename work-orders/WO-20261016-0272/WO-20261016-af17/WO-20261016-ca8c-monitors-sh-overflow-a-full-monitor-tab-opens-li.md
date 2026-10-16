---
{
  "id": "WO-20261016-ca8c",
  "slug": "monitors-sh-overflow-a-full-monitor-tab-opens-li",
  "title": "monitors.sh overflow: a full monitor tab opens <line> monitor 2; pr-index takes its first slot",
  "type": "feature",
  "status": "ready",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T06:20:27+00:00",
  "parent": "WO-20261016-af17",
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
    "WO-20261016-cc95",
    "WO-20261016-df39"
  ],
  "blocks": [
    "WO-20261016-ea8f"
  ]
}
---

# WO-20261016-ca8c - monitors.sh overflow: a full monitor tab opens <line> monitor 2; pr-index takes its first slot

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

ORD-0616 G3 ruling: "monitor tab full -> monitors overflow into tab inbox-triage monitor 2, opened by the monitors script; pr-index takes its first slot. ORD-0532-watchers still moves the compaction watchers to their own tab. Cut the monitors-script overflow ticket." claude/workflow/bin/monitors.sh refuses a taken slot (exit 3) and has no second monitor tab.

## Scope

**In**

- touches: claude/workflow/bin/monitors.sh
- touches: claude/workflow/tests/unit/test_monitors_overflow.sh
- touches: claude/workflow/config/monitors.json
- step: monitors.json slot grammar gains an optional tab number: `T:R.C` (`2:1.1`); a bare `R.C` is tab 1
- step: monitors.sh up: tab 1 is `<line> monitor`, tab N>=2 is `<line> monitor N`, each built with the existing grid code when the first entry needs it; down closes every `<line> monitor*` tab as today; status prints the tab number
- step: monitors.json: entry `{"name":"pr-index","owner":"pr-index","slot":"2:1.1","interval":0,"command":"while :; do make -C ${repo} pr-index OWNER=jkkelley && make -C ${repo} pr-sweep OWNER=jkkelley; sleep 300; done","publishes":"line.all.event.node.* (merges)"}`
- step: test with the stub herdr pattern of tests/unit/test_herdr_grid.sh; run `make -C claude/workflow image && podman run --rm --network=none --userns=keep-id -v "$PWD:/work:Z" -w /work -e HOME=/tmp localhost/dotfiles-workflow-test:1 bash -c 'bash claude/workflow/tests/unit/test_monitors_overflow.sh'`
- tool: path:claude/workflow/tests/container/Containerfile - on main; fallback: no fallback permitted (dotfiles Rule 14, never the host): podman or the image missing stops the node with ENV-MISSING podman
- tool: path:claude/workflow/bin/monitors.sh - on main; fallback: missing: stop with ENV-MISSING naming it

**Out - non-goals**

- work-orders/INDEX.md by hand: work-order.sh writes it, and the reindex Action is owned by merge-port-build (F11, ORD-0545 O1)
- waiting on CI or merging: push, open the PR, write the result, leave (ORD-0542 O2)
- any file not named under In: stop with DESIGN-GAP and hand it back to infra-design (ORD-0548, item 30)

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [ ] `AC-H1` *(human)* `make -C claude/workflow image && podman run --rm --network=none --userns=keep-id -v "$PWD:/work:Z" -w /work -e HOME=/tmp localhost/dotfiles-workflow-test:1 bash -c 'bash claude/workflow/tests/unit/test_monitors_overflow.sh'` exits 0 and its output matches /ok slot 2:1.1 opens tab "<line> monitor 2"/ (proof: command, exit code and output pasted by work-order.sh evidence; ORD-0552 O2)
- [ ] `AC-H2` *(human)* `make -C claude/workflow image && podman run --rm --network=none --userns=keep-id -v "$PWD:/work:Z" -w /work -e HOME=/tmp localhost/dotfiles-workflow-test:1 bash -c 'bash claude/workflow/tests/unit/test_monitors_overflow.sh'` exits 0 and its output matches /ok down closes both monitor tabs/ (proof: command, exit code and output pasted by work-order.sh evidence; ORD-0552 O2)

## Test plan

_Test plan from claude/workflow/templates/test-plan.md, shaped by claude/workflow/schemas/test-plan.schema.json. The tester runs exactly these cases and nothing else._

**Scope under test**

monitors.sh tab overflow against a stub herdr

**Cases**

- `TP-1`
  - intent: a full tab must not refuse a new monitor (ORD-0616 G3)
  - command: `make -C claude/workflow image && podman run --rm --network=none --userns=keep-id -v "$PWD:/work:Z" -w /work -e HOME=/tmp localhost/dotfiles-workflow-test:1 bash -c 'bash claude/workflow/tests/unit/test_monitors_overflow.sh'`
  - expected: exit 0; prints `ok  slot 2:1.1 opens tab "<line> monitor 2"`
- `TP-2`
  - intent: cleanup closes every monitor tab (item 11)
  - command: `make -C claude/workflow image && podman run --rm --network=none --userns=keep-id -v "$PWD:/work:Z" -w /work -e HOME=/tmp localhost/dotfiles-workflow-test:1 bash -c 'bash claude/workflow/tests/unit/test_monitors_overflow.sh'`
  - expected: exit 0; prints `ok  down closes both monitor tabs`
- `TP-3`
  - intent: fallback path: bare R.C slots keep landing in tab 1
  - command: `make -C claude/workflow image && podman run --rm --network=none --userns=keep-id -v "$PWD:/work:Z" -w /work -e HOME=/tmp localhost/dotfiles-workflow-test:1 bash -c 'bash claude/workflow/tests/unit/test_monitors_overflow.sh'`
  - expected: exit 0; prints `ok  bare slots stay in tab 1`

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
