---
{
  "id": "WO-20261016-0797",
  "slug": "dag-state-t9-ci-poll-and-merge-scripts-with-appr",
  "title": "dag-state T9 - CI poll and merge scripts with approval check",
  "type": "feature",
  "status": "done",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T06:07:35+00:00",
  "parent": "WO-20261016-41d0",
  "branch": "feat/dag-state-t9-ci-poll-and-merge-scripts-with-appr",
  "pr": 258,
  "closed": "2026-10-16",
  "approval": {
    "via": "override",
    "reason": "architect ruled design approvals done, ORD-0550 O4",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [
    "WO-20261016-05db"
  ],
  "blocks": [
    "WO-20261016-f3a5"
  ]
}
---

# WO-20261016-0797 - dag-state T9 - CI poll and merge scripts with approval check

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

- touches: claude/workflow/dag/bin/dag-ci.sh
- touches: claude/workflow/dag/bin/dag-merge.sh
- touches: claude/workflow/dag/tests/unit/test_dag_merge.sh
- step: build to nodes N8 and N9; merge by script the moment CI is green with no review gate (one PR process, owner 2026-10-16 UTC: "automate that process, we dont need gates we need speed")
- step: every script: rolodex header (name, purpose, inputs, outputs, writes-to, cleanup), inputs by flag or config, idempotent, retries 3 where the spec says retry=3
- step: run `make -C claude/workflow image && podman run --rm --network=none --userns=keep-id -v "$PWD:/work:Z" -w /work -e HOME=/tmp localhost/dotfiles-workflow-test:1 bash -c 'bash claude/workflow/dag/tests/unit/test_dag_merge.sh'`
- tool: path:claude/workflow/tests/container/Containerfile - on main; fallback: no fallback permitted (dotfiles Rule 14, never the host): podman or the image missing stops the node with ENV-MISSING podman
- tool: make:Makefile:spec-check - on main; fallback: target missing or failing to parse: stop with DESIGN-GAP naming the target; no hand-run substitute

**Out - non-goals**

- work-orders/INDEX.md by hand: work-order.sh writes it, and the reindex Action is owned by merge-port-build (F11, ORD-0545 O1)
- waiting on CI or merging: push, open the PR, write the result, leave (ORD-0542 O2)
- any file not named under In: stop with DESIGN-GAP and hand it back to infra-design (ORD-0548, item 30)

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [x] `AC-H1` *(human)* `make -C claude/workflow image && podman run --rm --network=none --userns=keep-id -v "$PWD:/work:Z" -w /work -e HOME=/tmp localhost/dotfiles-workflow-test:1 bash -c 'bash claude/workflow/dag/tests/unit/test_dag_merge.sh'` exit 0; every case prints ok and the last line is the pass count with fail=0 (proof: command, exit code and output pasted by work-order.sh evidence; ORD-0552 O2)
  - observed `2026-10-16` exit=0; last lines: ok merge: state.json untouched pass=30 fail=0 exit=0
- [x] `AC-H2` *(human)* `make spec-check` exits 0 (the specs were read, not edited) (proof: command, exit code and output pasted by work-order.sh evidence; ORD-0552 O2)
  - observed `2026-10-16` BASE=origin/main LIMIT=1000 PATTERN='*.spec.xml' bash scripts/spec-check.sh spec-check: nothing in scope exit=0
- [x] `AC-H3` *(human)* `git diff --name-only origin/main` lists only the files under In (proof: command, exit code and output pasted by work-order.sh evidence; ORD-0552 O2)
  - observed `2026-10-16` claude/workflow/dag/bin/dag-ci.sh claude/workflow/dag/bin/dag-merge.sh claude/workflow/dag/tests/unit/test_dag_merge.sh work-orders/WO-20261016-0272/WO-20261016-1844-test-work-order-skill-index-md-and-epic-readmes-.md work-orders/WO-20261016-0272/WO-20261016-41d0/WO-20261016-0797-dag-state-t9-ci-poll-and-merge-scripts-with-appr.md work-orders/WO-20261016-0272/WO-20261016-41d0/WO-20261016-e271-dag-state-t11-config-config-schema-dag-mk-makefi.md work-orders/WO-20261016-0272/WO-20261016-824e-line-build-l1-design-drift-check.md work-orders/WO-20261016-0272/WO-20261016-af17/WO-20261016-193d-test-ord-0832-b1-the-live-line-s-bearings-server.md work-orders/WO-20261016-0272/WO-20261016-af17/WO-20261016-599f-timed-run-every-target-of-claude-workflow-makefi.md work-orders/WO-20261016-0272/WO-20261016-af17/WO-20261016-cc95-pane-look-monitor-queued-stale-and-idle-stale-ju.md work-orders/WO-20261016-0272/WO-20261016-af17/WO-20261016-e8f2-stuck-watch-deadman-probes-each-live-line-s-bear.md work-orders/WO-20261016-0272/WO-20261016-af17/WO-20261016-f4a0-bearings-server-for-a-live-line-runs-as-systemd-.md work-orders/WO-20261016-0272/WO-20261016-fb0c/WO-20261016-39da-merge-on-green-holds-a-green-pr-whose-head-is-be.md work-orders/WO-20261016-0272/WO-20261016-fb0c/WO-20261016-448e-restore-pr-242-rerun-stale-red-on-main-commit-48.md work-orders/WO-20261016-0272/WO-20261016-fb0c/WO-20261016-73f2-pr-flow-sweep-refreshes-a-green-pr-behind-its-ba.md work-orders/WO-20261016-0272/WO-20261016-fb0c/WO-20261016-7f26-test-rr-orch-15-merge-on-green-holds-a-stale-bas.md exit=0

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
