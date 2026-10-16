---
{
  "id": "WO-20261016-1ca6",
  "slug": "test-seat-up-waits-for-the-agent-to-be-idle-or-w",
  "title": "Test - seat-up waits for the agent to be idle or working, never idle only (recut of WO-20261016-38a6, TP-2 on the WO-20261016-7e48 case)",
  "type": "test",
  "status": "ready",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T12:49:33+00:00",
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
  "depends_on": [
    "WO-20261016-7e48"
  ],
  "blocks": [],
  "ac_checks": [
    {
      "index": 1,
      "command": "make -C claude/workflow grid 2>&1 | grep -F 'seat-up with a prompted seat that is working exits 0 and writes agent-seen'",
      "exit": 0,
      "expect": "^ok  seat-up with a prompted seat"
    },
    {
      "index": 2,
      "command": "make -C claude/workflow grid 2>&1 | grep -F 'seat-up exits 1 when the agent never reached idle or working and writes no agent-seen'",
      "exit": 0,
      "expect": "^ok  seat-up exits 1"
    },
    {
      "index": 3,
      "command": "git diff --name-only origin/main...HEAD | grep -vE '^(work-orders/.*)$'",
      "exit": 1,
      "expect": null
    }
  ],
  "provides": [],
  "labels": [
    "line:inbox-triage"
  ]
}
---

# WO-20261016-1ca6 - Test - seat-up waits for the agent to be idle or working, never idle only (recut of WO-20261016-38a6, TP-2 on the WO-20261016-7e48 case)

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

Run the filled test plan below for WO-20261016-5569 - seat-up waits for the agent to be idle or working, never idle only, exactly as written; dev gate (item 34), no owner notification (item 35). Recut of WO-20261016-38a6, whose TP-2 named an 'agent never reached idle' case that did not exist (DESIGN-GAP); WO-20261016-7e48 adds that case and TP-2 now expects its exact ok line.

## Owner words

> Ensure that your testing is dev uat stable. (Design principles 101 item 34)

> i want work scoped so small a fuck ape could do, testing the same way with test plans and scripts (Design principles 101 item 30)

## Context

Code under test: claude/workflow/bin/herdr-grid.sh cmd_seat_up waits on 'hj agent wait <pane> --until idle --until working' (WO-20261016-5569, merged). The stub herdr in claude/workflow/tests/unit/test_herdr_grid.sh fails agent wait without --until working when fx/working exists (TP-1), and fails every agent wait when fx/nostart exists (TP-2, added by WO-20261016-7e48).

## Scope

**In**

- touches: none; the tester runs the plan and records evidence only
- touches (generated, written only by work-order.sh start/submit/evidence/done, never by hand or git add): this ticket file and its archive path; work-orders/INDEX.md and the parent epic README.md are ignored generated views
- step: branch from origin/main in your own git worktree (fallback: treehouse fails, use git worktree add), never the ~/dotfiles primary clone; bash claude/skills/work-order/scripts/work-order.sh start --id THIS-TICKET-ID
- step: run TP-1 and TP-2 in order; any red case: stop with A2A-003 and its output, never edit code; write the run output by script to ~/.local/state/zenith/log/YYYY/MM/ with frontmatter; then bash claude/skills/work-order/scripts/work-order.sh check --id THIS-TICKET-ID
- step: commit 'test(work-orders): seat-up idle-or-working test run' with this ticket id; no Bump trailer; push, gh pr create, submit --pr <N>, done on the branch, push, leave
- tool: make:claude/workflow/Makefile:grid - on main; fallback: the image fails to build: stop with ENV-MISSING podman
- tool: cmd:git, cmd:gh, cmd:make, cmd:podman - fallback: missing on the host: stop with ENV-MISSING naming it; gh or GitHub down: retry 3 times, then stop with A2A-003 and its output

**Out - non-goals**

- writing or changing code: a failing case goes back as A2A-003 with its output
- any file not named under In: stop with DESIGN-GAP and hand it back to infra-design (ORD-0548, item 30)
- work-orders/INDEX.md and epic READMEs by hand or by git add; waiting on CI or merging: push, open the PR, write the result, leave (ORD-0542 O2)

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [ ] `AC-H1` *(human)* TP-1: a prompted working seat exits 0 and writes agent-seen
  - check: `make -C claude/workflow grid 2>&1 | grep -F 'seat-up with a prompted seat that is working exits 0 and writes agent-seen'` exit 0 expect /^ok seat-up with a prompted seat/
- [ ] `AC-H2` *(human)* TP-2: a seat that never starts exits 1 and writes no agent-seen
  - check: `make -C claude/workflow grid 2>&1 | grep -F 'seat-up exits 1 when the agent never reached idle or working and writes no agent-seen'` exit 0 expect /^ok seat-up exits 1/
- [ ] `AC-H3` *(human)* the diff holds only work-orders files
  - check: `git diff --name-only origin/main...HEAD | grep -vE '^(work-orders/.*)$'` exit 1

## Test plan

_Test plan from claude/workflow/templates/test-plan.md, shaped by claude/workflow/schemas/test-plan.schema.json. The tester runs exactly these cases and nothing else._

**Scope under test**

claude/workflow/bin/herdr-grid.sh cmd_seat_up against the stub herdr in tests/unit/test_herdr_grid.sh

**Cases**

- `TP-1`
  - intent: a prompted seat is working at once; seat-up must exit 0 or every new seat reads as a failed spawn (05:42Z)
  - command: `make -C claude/workflow grid`
  - expected: exit 0; prints `ok  seat-up with a prompted seat that is working exits 0 and writes agent-seen`
- `TP-2`
  - intent: a seat that never starts must still fail, or a dead spawn reads as a live seat; the case is added by WO-20261016-7e48 (DESIGN-GAP fix, infra-design23)
  - command: `make -C claude/workflow grid`
  - expected: exit 0; prints `ok  seat-up exits 1 when the agent never reached idle or working and writes no agent-seen`

**Isolation**

_A locally built image uses `- image: localhost/<name>:<tag>` plus `- build: <command>` and `- containerfile: <path>` lines, never a localhost digest (RR-orch-18)._

- runtime: podman
- image: `localhost/dotfiles-workflow-test:1`
- build: `make -C claude/workflow image`
- containerfile: claude/workflow/tests/container/Containerfile

**Out of scope - CI covers**

- shellcheck of the workflow tree and the full workflow suite

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
