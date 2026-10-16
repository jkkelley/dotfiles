---
{
  "id": "WO-20261016-1933",
  "slug": "test-ord-0848-y3-pr-flow-sweep-posts-ready-merge",
  "title": "Test - ORD-0848 Y3: pr-flow sweep posts READY-MERGED once per ticket and PR",
  "type": "test",
  "status": "ready",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T09:08:44+00:00",
  "parent": "WO-20261016-fb0c",
  "branch": null,
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
    "WO-20261016-c6a5"
  ],
  "blocks": [],
  "ac_checks": [
    {
      "index": 1,
      "command": "make -C claude/workflow pr-flow-test CASES=\"stale-merged records\"",
      "exit": 0,
      "expect": "ok  stale-merged"
    },
    {
      "index": 2,
      "command": "make -C claude/workflow pr-flow-lint",
      "exit": 0,
      "expect": null
    }
  ],
  "provides": []
}
---

# WO-20261016-1933 - Test - ORD-0848 Y3: pr-flow sweep posts READY-MERGED once per ticket and PR

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

Run the filled test plan of WO-20261016-c6a5 exactly as written on its merged main; dev gate (item 34), no owner notification (item 35).

## Owner words

> i want work scoped so small a fuck ape could do, testing the same way with test plans and scripts, every node has what it fucking needs up front, not later (Design principles 101 item 30)

> Ensure that your testing is dev uat stable. (item 34)

## Context

The suite stubs the bus (PR_FLOW_PUB) and work-order.sh (PR_FLOW_WO); nothing reaches the live bus or a real ticket.

## Scope

**In**

- touches: none (read-only run on origin/main; output by script to ~/.local/state/zenith/log/YYYY/MM/ with frontmatter)
- touches (generated, written only by work-order.sh start/submit/done, never by hand or git add): this ticket file and its archive path; work-orders/INDEX.md and the parent epic README.md are ignored generated views
- step: in your own detached worktree of origin/main run TP-1, TP-2, TP-3 exactly as written; record each with work-order.sh evidence
- tool: cmd:git, cmd:jq, cmd:make, cmd:podman, cmd:gh - fallback: missing on the host: stop with ENV-MISSING naming it; gh or GitHub down: retry 3 times, then stop with A2A-003 and its output

**Out - non-goals**

- writing or changing code: a failing case goes back as A2A-003 with its output
- waiting on CI or merging: push, open the PR, write the result, leave (ORD-0542 O2)
- any file not named under In: stop with DESIGN-GAP and hand it back to infra-design (ORD-0548, item 30)

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [ ] `AC-H1` *(human)* TP-1: stale-merged and records pass
  - check: `make -C claude/workflow pr-flow-test CASES="stale-merged records"` exit 0 expect /ok stale-merged/
- [ ] `AC-H2` *(human)* TP-2: lint clean
  - check: `make -C claude/workflow pr-flow-lint` exit 0

## Test plan

_Test plan from claude/workflow/templates/test-plan.md, shaped by claude/workflow/schemas/test-plan.schema.json. The tester runs exactly these cases and nothing else._

**Scope under test**

pr-flow-consume.sh verb stale-merged, run by the sweep each tick: per configured repo, work-order.sh stale-merged against each stale_merged.pr_repos entry, one READY-MERGED record per ticket and PR, posted once

**Cases**

- `TP-1`
  - intent: the sweep must post READY-MERGED exactly once per ticket and merged PR, or the design seat never sees the stale tickets, or sees them every minute
  - command: `make -C claude/workflow pr-flow-test CASES="stale-merged records"`
  - expected: exit 0; prints `ok  stale-merged` and `ok  records`
- `TP-2`
  - intent: scripts stay shellcheck clean
  - command: `make -C claude/workflow pr-flow-lint`
  - expected: exit 0
- `TP-3`
  - intent: the record kind and code are in the record schema, or records.sh refuses the post
  - command: `jq -e '(.properties.kind.enum | index("ready.merged")) and (.properties.code.enum | index("READY-MERGED"))' claude/workflow/pr-flow/schemas/pr-flow-record.schema.json`
  - expected: exit 0; prints true

**Isolation**

- runtime: podman
- image: `localhost/dotfiles-workflow-test:1`
- build: `make -C claude/workflow image`
- containerfile: `claude/workflow/tests/container/Containerfile`

**Out of scope - CI covers**

- the full pr-flow and claude/workflow suites: CI runs them

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
