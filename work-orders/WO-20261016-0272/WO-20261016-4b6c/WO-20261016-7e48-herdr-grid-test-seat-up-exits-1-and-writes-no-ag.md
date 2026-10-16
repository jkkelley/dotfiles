---
{
  "id": "WO-20261016-7e48",
  "slug": "herdr-grid-test-seat-up-exits-1-and-writes-no-ag",
  "title": "herdr-grid test: seat-up exits 1 and writes no agent-seen when the agent never reaches idle or working (case for WO-20261016-38a6 TP-2)",
  "type": "chore",
  "status": "ready",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T12:48:04+00:00",
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
    "WO-20261016-2ca4",
    "WO-20261016-1ca6"
  ],
  "ac_checks": [
    {
      "index": 1,
      "command": "make -C claude/workflow grid 2>&1 | grep -F 'seat-up exits 1 when the agent never reached idle or working and writes no agent-seen'",
      "exit": 0,
      "expect": "^ok  seat-up exits 1"
    },
    {
      "index": 2,
      "command": "make -C claude/workflow grid 2>&1 | tail -1",
      "exit": 0,
      "expect": "^ok  herdr-grid$"
    },
    {
      "index": 3,
      "command": "grep -c 'fx/nostart' claude/workflow/tests/unit/test_herdr_grid.sh",
      "exit": 0,
      "expect": "^3$"
    },
    {
      "index": 4,
      "command": "git diff --name-only origin/main...HEAD | grep -vE '^(work-orders/.*|claude/workflow/tests/unit/test_herdr_grid\\.sh)$'",
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

# WO-20261016-7e48 - herdr-grid test: seat-up exits 1 and writes no agent-seen when the agent never reaches idle or working (case for WO-20261016-38a6 TP-2)

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

WO-20261016-38a6 TP-2 expects an existing ok line for the case 'agent never reached idle' in claude/workflow/tests/unit/test_herdr_grid.sh; no such case exists (grep 'never reached' in the test: none), so the tester stopped with DESIGN-GAP. The failure path of cmd_seat_up (herdr-grid.sh: hj agent wait ... || { log 'agent never reached idle'; return 1; }) has no test, so a regression that turns it into || true would pass CI and a dead spawn would read as a live seat.

## Owner words

> see a bug, isolate it, and get it fixed as asap (Design principles 101 item 22)

> if the task or job needs tools, the architect has a design agent build that shit out before the ticket goes in, thats a prereq for the ticket ready then (Design principles 101 item 30)

> ORD-1150-tmpdir T1, ORD-1140-seat S3, ORD-1114 (orchestrator brief BR-20261016-infra-design23: DESIGN-GAP 38a6 TP-2 case, add the case by a tooling leaf or correct the plan)

## Context

Proven by infra-design23 in its worktree on origin/main 93dcff5: with exactly the two edits below, make -C claude/workflow grid exits 0 and prints the new ok line; with herdr-grid.sh's wait line mutated to '|| true' it prints 'FAIL seat-up exits 1 when the agent never reached idle or working and writes no agent-seen' and 'FAIL herdr-grid' (mutation reverted).

Edit 1, the stub in the heredoc STUB: replace the line starting ' "agent wait") [ -f "$fx/working" ]' so it starts ' "agent wait") [ -f "$fx/nostart" ] && exit 1; [ -f "$fx/working" ]' and keep the rest of that line unchanged.

Edit 2, insert these 4 lines plus one blank line directly above the line '# ---- seat-up: slot order, no double claim, overflow':

L1: # ---- a seat that never starts still fails (DESIGN-GAP of WO-20261016-38a6): agent wait never sees idle or working, so seat-up exits 1 and writes no agent-seen

L2: mk_tab1 free free free free free free

L3: touch "$T/fx/nostart"; rm -f "$T/state/L/ns.agent-seen"; : > "$T/log"; out="$($G seat-up L ns "claude -p go" 2>&1)"; rc=$?; rm -f "$T/fx/nostart"

L4: [ "$rc" = 1 ] && grep -qF 'agent never reached idle' <<<"$out" && [ ! -f "$T/state/L/ns.agent-seen" ] && ok "seat-up exits 1 when the agent never reached idle or working and writes no agent-seen" || bad "seat-up exits 1 when the agent never reached idle or working and writes no agent-seen" "rc=$rc out=$out"

## Scope

**In**

- touches: claude/workflow/tests/unit/test_herdr_grid.sh (the agent wait line of the stub, and the new case above '# ---- seat-up: slot order' only)
- touches (generated, written only by work-order.sh start/submit/done, never by hand or git add): this ticket file and its archive path; work-orders/INDEX.md and the parent epic README.md are ignored generated views
- step: branch from origin/main in your own git worktree (fallback: treehouse fails, use git worktree add), never the ~/dotfiles primary clone; bash claude/skills/work-order/scripts/work-order.sh start --id THIS-TICKET-ID
- step: apply Edit 1 and Edit 2 from Context verbatim; run TP-1 and TP-2; then bash claude/skills/work-order/scripts/work-order.sh check --id THIS-TICKET-ID
- step: commit 'test(workflow): seat-up never-reached-idle case' with this ticket id; no Bump trailer; push, gh pr create, submit --pr <N>, done on the branch, push, leave
- tool: make:claude/workflow/Makefile:grid - on main; fallback: the image fails to build: stop with ENV-MISSING podman
- tool: cmd:git, cmd:gh, cmd:make, cmd:podman - fallback: missing on the host: stop with ENV-MISSING naming it; gh or GitHub down: retry 3 times, then stop with A2A-003 and its output

**Out - non-goals**

- any change to claude/workflow/bin/herdr-grid.sh: the code is correct, only its test is missing
- any other case of test_herdr_grid.sh, or any file not under In: stop with DESIGN-GAP
- work-orders/INDEX.md and epic READMEs by hand or by git add; waiting on CI or merging: push, open the PR, write the result, leave

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [ ] `AC-H1` *(human)* the new case passes on the branch
  - check: `make -C claude/workflow grid 2>&1 | grep -F 'seat-up exits 1 when the agent never reached idle or working and writes no agent-seen'` exit 0 expect /^ok seat-up exits 1/
- [ ] `AC-H2` *(human)* the whole grid test is green
  - check: `make -C claude/workflow grid 2>&1 | tail -1` exit 0 expect /^ok herdr-grid$/
- [ ] `AC-H3` *(human)* the stub fails agent wait on the nostart fixture
  - check: `grep -c 'fx/nostart' claude/workflow/tests/unit/test_herdr_grid.sh` exit 0 expect /^3$/
- [ ] `AC-H4` *(human)* the diff holds only the test file and work-orders files
  - check: `git diff --name-only origin/main...HEAD | grep -vE '^(work-orders/.*|claude/workflow/tests/unit/test_herdr_grid\.sh)$'` exit 1

## Test plan

_Test plan from claude/workflow/templates/test-plan.md, shaped by claude/workflow/schemas/test-plan.schema.json. The tester runs exactly these cases and nothing else._

**Scope under test**

the new "agent never reached idle" case in claude/workflow/tests/unit/test_herdr_grid.sh against cmd_seat_up of claude/workflow/bin/herdr-grid.sh

**Cases**

- `TP-1`
  - intent: a seat whose agent never starts must fail seat-up, or a dead spawn reads as a live seat (DESIGN-GAP of WO-20261016-38a6 TP-2)
  - command: `make -C claude/workflow grid`
  - expected: exit 0; prints `ok  seat-up exits 1 when the agent never reached idle or working and writes no agent-seen` and `ok  herdr-grid`
- `TP-2`
  - intent: the prompted-seat fix of WO-20261016-5569 still holds next to the new case
  - command: `make -C claude/workflow grid`
  - expected: exit 0; prints `ok  seat-up with a prompted seat that is working exits 0 and writes agent-seen`

**Isolation**

_A locally built image uses `- image: localhost/<name>:<tag>` plus `- build: <command>` and `- containerfile: <path>` lines, never a localhost digest (RR-orch-18)._

- runtime: podman
- image: `localhost/dotfiles-workflow-test:1`
- build: `make -C claude/workflow image`
- containerfile: claude/workflow/tests/container/Containerfile

**Out of scope - CI covers**

- shellcheck of the workflow tree and the full workflow suite (Design principles 101 item 6)

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
