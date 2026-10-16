---
{
  "id": "WO-20261016-7f26",
  "slug": "test-rr-orch-15-merge-on-green-holds-a-stale-bas",
  "title": "Test - RR-orch-15: merge-on-green holds a stale-base PR, the sweep refreshes it once and posts STALE-BASE, the fresh run merges",
  "type": "test",
  "status": "ready",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T08:49:58+00:00",
  "parent": "WO-20261016-fb0c",
  "branch": null,
  "pr": null,
  "closed": null,
  "approval": {
    "via": "override",
    "reason": "infra-design7 cut for ORD-0830 RR-orch-15 and ORD-0832 B1; design approvals ruled done, ORD-0550 O4",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [
    "WO-20261016-39da",
    "WO-20261016-73f2"
  ],
  "blocks": [],
  "ac_checks": [
    {
      "index": 1,
      "command": "make -C claude/workflow pr-flow-test CASES=\"ci-template stale-base consume rerun-stale-red records\"",
      "exit": 0,
      "expect": "ok  stale-base"
    },
    {
      "index": 2,
      "command": "bash -c grep\\ -c\\ \\\"\\^STALE-BASE/jkkelley/dotfiles/\\\"\\ \\\"\\$\\{PR_FLOW_STATE:-\\$HOME/.local/state/zenith/pr-flow\\}/posted.keys\\\"",
      "exit": 0,
      "expect": "^[1-9]"
    }
  ],
  "provides": [],
  "labels": [
    "line:inbox-triage"
  ]
}
---

# WO-20261016-7f26 - Test - RR-orch-15: merge-on-green holds a stale-base PR, the sweep refreshes it once and posts STALE-BASE, the fresh run merges

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

Run the filled test plan of RR-orch-15 exactly as written: dev gate then UAT (item 34), no owner notification (item 35).

## Owner words

> RR-orch-15: no branch protection gate. The merge-on-green Action refuses a PR whose last green run tested a base older than main head and runs gh pr update-branch instead, which starts a fresh run; code STALE-BASE on the bus.

> Ensure that your testing is dev uat stable. (item 34)

## Context

Builds under test: the merge-on-green Action ticket and the pr-flow sweep stale-base ticket cut beside this one (parent WO-20261016-fb0c). TP-2 and TP-3 are the UAT gate: they read the real repository and the sweep's ledger on the host, outside podman; TP-1 runs in the pinned image.

## Scope

**In**

- touches: none in the repository; the tester writes evidence by script to the artifact store only
- touches (generated, written only by work-order.sh start/submit/done, never by hand): work-orders/INDEX.md, this ticket file and its archive path, the parent epic README.md
- step: start only after both builds are done and merged; run from a worktree of origin/main
- step: run TP-1 to TP-3 exactly; write each command and its output with bash claude/tools/artifact/artifact.sh new --key log, then work-order.sh check ticks the criteria
- tool: make:claude/workflow/Makefile:pr-flow-test and pr-flow-lint - on main; fallback: missing: stop with DESIGN-GAP naming it
- tool: cmd:git, cmd:jq, cmd:make, cmd:podman, cmd:gh - fallback: missing on the host: stop with ENV-MISSING naming it; gh or GitHub down: retry 3 times, then stop with A2A-003 and its output
- tool: path:claude/tools/artifact/artifact.sh - on main; fallback: missing: stop with DESIGN-GAP

**Out - non-goals**

- changing any file: a failing case is a bug ticket with its reproduction, handed to infra-design (item 22)
- opening a PR only to make one stale: TP-2 reads the first real hold on the line
- any owner notification (item 35)
- waiting on CI or merging: push, open the PR, write the result, leave (ORD-0542 O2)

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [ ] `AC-H1` *(human)* the dev gate passes
  - check: `make -C claude/workflow pr-flow-test CASES="ci-template stale-base consume rerun-stale-red records"` exit 0 expect /ok stale-base/
- [ ] `AC-H2` *(human)* the sweep posted STALE-BASE on the real repository
  - check: `bash -c grep\ -c\ \"\^STALE-BASE/jkkelley/dotfiles/\"\ \"\$\{PR_FLOW_STATE:-\$HOME/.local/state/zenith/pr-flow\}/posted.keys\"` exit 0 expect /^[1-9]/

## Test plan

_Test plan from claude/workflow/templates/test-plan.md, shaped by claude/workflow/schemas/test-plan.schema.json. The tester runs exactly these cases and nothing else._

**Scope under test**

RR-orch-15 end to end: merge-on-green holds a stale-base PR, the sweep refreshes it once and posts STALE-BASE, the fresh run merges it

**Cases**

- `TP-1`
  - intent: dev gate (item 34): the Action hold and the sweep verb pass their suites on main
  - command: `make -C claude/workflow pr-flow-test CASES="ci-template stale-base consume rerun-stale-red records"`
  - expected: exit 0; prints `ok  ci-template` and `ok  stale-base`
- `TP-2`
  - intent: UAT gate (item 34): on the real repository a green PR opened before main moved is held, refreshed once by the sweep and merged on its fresh run; no owner notification (item 35)
  - command: `bash -c 'gh run list -R jkkelley/dotfiles --workflow "merge on green" --limit 50 --json databaseId --jq ".[].databaseId" | while read -r id; do gh run view "$id" -R jkkelley/dotfiles --log 2>/dev/null | grep -m1 -o "STALE-BASE pr=[0-9]*"; done | head -1'`
  - expected: exit 0; prints one `STALE-BASE pr=<N>`; for that N, `gh pr view <N> -R jkkelley/dotfiles --json state,commits` shows state MERGED and an update-branch merge commit after the hold
- `TP-3`
  - intent: the STALE-BASE record was posted once by the sweep (bus, or the records.sh dir fallback)
  - command: `bash -c 'grep -c "^STALE-BASE/jkkelley/dotfiles/" "${PR_FLOW_STATE:-$HOME/.local/state/zenith/pr-flow}/posted.keys"'`
  - expected: exit 0; prints a count of 1 or more, one key per held PR and base sha

**Isolation**

- runtime: podman
- image: `docker.io/library/debian:bookworm-slim@sha256:3783cc01769c7b2b1b83a5c5ad96c815348e28ed7da68e2e3687004faa906251` (debian:bookworm-slim, base of localhost/dotfiles-workflow-test:1)

**Out of scope - CI covers**

- the full claude/workflow suite: CI runs it

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
