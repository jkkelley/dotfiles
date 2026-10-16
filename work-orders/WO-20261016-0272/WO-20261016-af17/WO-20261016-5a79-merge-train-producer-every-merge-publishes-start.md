---
{
  "id": "WO-20261016-5a79",
  "slug": "merge-train-producer-every-merge-publishes-start",
  "title": "merge-train producer: every merge publishes start and end through timed-run",
  "type": "feature",
  "status": "ready",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T06:04:56+00:00",
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
    "WO-20261016-fb0c"
  ],
  "blocks": [
    "WO-20261016-e375"
  ],
  "labels": [
    "line:inbox-triage"
  ]
}
---

# WO-20261016-5a79 - merge-train producer: every merge publishes start and end through timed-run

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

Item 37, owner: "Every DAG node, seat, job, CI run and merge records its start and end in UTC on the bus by script". stuck-watch result A2A-003: producer work orders for merge-train, filed against its owner seat (merge-port-build), never patched by stuck-watch. tools/merge-train/merge-train.sh merges with no event.

## Scope

**In**

- touches: tools/merge-train/merge-train.sh
- touches: tools/merge-train/tests/test_merge_train.sh
- step: wrap the one `gh pr merge` call in merge-train.sh as `bash "$DOTFILES/claude/workflow/bin/timed-run.sh" --node pr-<repo-name>-<number> --kind merge --line "${LINE:-all}" -- gh pr merge ...`, $DOTFILES resolved from the script's own path
- step: test: SW_PUB_CMD stub records subjects; case `a merge publishes line.all.event.node.start and .end with kind merge`; case `a down bus still merges`
- step: run `bash tools/merge-train/tests/test_merge_train.sh` inside `make -C claude/workflow image && podman run --rm --network=none --userns=keep-id -v "$PWD:/work:Z" -w /work -e HOME=/tmp localhost/dotfiles-workflow-test:1 bash -c '<that command>'`
- tool: path:claude/workflow/tests/container/Containerfile - on main; fallback: no fallback permitted (dotfiles Rule 14, never the host): podman or the image missing stops the node with ENV-MISSING podman
- tool: path:tools/merge-train/merge-train.sh - on main; fallback: missing: stop with ENV-MISSING naming it
- tool: path:claude/workflow/bin/timed-run.sh - on main; fallback: bus down: timed-run warns `WARN bus unreachable` and the step runs with its own exit code (tm_event); covered by the bus-down case

**Out - non-goals**

- work-orders/INDEX.md by hand: work-order.sh writes it, and the reindex Action is owned by merge-port-build (F11, ORD-0545 O1)
- waiting on CI or merging: push, open the PR, write the result, leave (ORD-0542 O2)
- any file not named under In: stop with DESIGN-GAP and hand it back to infra-design (ORD-0548, item 30)

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [ ] `AC-H1` *(human)* the merge-train test exits 0 and prints `ok a merge publishes start and end with kind merge` (proof: command, exit code and output pasted by work-order.sh evidence; ORD-0552 O2)
- [ ] `AC-H2` *(human)* the same run prints `ok a down bus still merges` (proof: command, exit code and output pasted by work-order.sh evidence; ORD-0552 O2)

## Test plan

_Test plan from claude/workflow/templates/test-plan.md, shaped by claude/workflow/schemas/test-plan.schema.json. The tester runs exactly these cases and nothing else._

**Scope under test**

tools/merge-train/merge-train.sh merge timing via timed-run, gh and bus stubbed

**Cases**

- `TP-1`
  - intent: merge durations are the justification for merge fixes (item 37)
  - command: `make -C claude/workflow image && podman run --rm --network=none --userns=keep-id -v "$PWD:/work:Z" -w /work -e HOME=/tmp localhost/dotfiles-workflow-test:1 bash -c 'bash tools/merge-train/tests/test_merge_train.sh'`
  - expected: exit 0; prints `ok  a merge publishes start and end with kind merge`
- `TP-2`
  - intent: the bus is not a merge dependency
  - command: `make -C claude/workflow image && podman run --rm --network=none --userns=keep-id -v "$PWD:/work:Z" -w /work -e HOME=/tmp localhost/dotfiles-workflow-test:1 bash -c 'bash tools/merge-train/tests/test_merge_train.sh'`
  - expected: exit 0; prints `ok  a down bus still merges`

**Isolation**

- runtime: podman
- image: `docker.io/library/debian:bookworm-slim@sha256:3783cc01769c7b2b1b83a5c5ad96c815348e28ed7da68e2e3687004faa906251` (debian:bookworm-slim, base of localhost/dotfiles-workflow-test:1)

**Out of scope - CI covers**

- the full merge-train suite

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
