---
{
  "id": "WO-20261016-193d",
  "slug": "test-ord-0832-b1-the-live-line-s-bearings-server",
  "title": "Test - ORD-0832 B1: the live line's Bearings server as a systemd user unit, restarted always, and the deadman paging STK-092 on probe 000",
  "type": "test",
  "status": "draft",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T08:50:28+00:00",
  "parent": "WO-20261016-af17",
  "branch": null,
  "pr": null,
  "closed": null,
  "approval": null,
  "evidence": null,
  "surfaces": [],
  "depends_on": [
    "WO-20261016-f4a0",
    "WO-20261016-e8f2"
  ],
  "blocks": [],
  "ac_checks": [
    {
      "index": 1,
      "command": "make -C claude/workflow bearings-test",
      "exit": 0,
      "expect": "ok  bearings"
    },
    {
      "index": 2,
      "command": "grep -c STK-092\\ line=b1-uat /home/luna/.local/state/zenith/stuck-watch/deadman.log",
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

# WO-20261016-193d - Test - ORD-0832 B1: the live line's Bearings server as a systemd user unit, restarted always, and the deadman paging STK-092 on probe 000

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

Run the filled test plan of ORD-0832 B1 exactly as written: dev gate then UAT on test line b1-uat (item 34), no owner notification (item 35).

## Owner words

> ORD-0832 B1: the Bearings server for a live line runs as a local systemd user unit (Restart=always, idle stop off), brought up by the line-up Make target with the line; its deadman is the stuck-watch monitor, which pages on page 000. The 240-minute idle default stays for ad hoc sessions only.

> Ensure that your testing is dev uat stable. (item 34)

## Context

Builds under test: the Bearings unit ticket and the deadman probe ticket cut beside this one (parent WO-20261016-af17). TP-1 runs in the pinned image; TP-2 and TP-3 are the UAT gate on the host's systemd user manager with test line b1-uat, never inbox-triage, and the deadman posts only to YPC_NTFY_TEST_TOPIC.

## Scope

**In**

- touches: none in the repository; the tester writes evidence by script to the artifact store only
- touches (generated, written only by work-order.sh start/submit/done, never by hand): work-orders/INDEX.md, this ticket file and its archive path, the parent epic README.md
- step: start only after both builds are done and merged; run from a worktree of origin/main
- step: run TP-1 to TP-3 exactly; write each command and its output with bash claude/tools/artifact/artifact.sh new --key log, then work-order.sh check ticks the criteria
- step: clean up (item 11): make -C claude/workflow bearings-down LINE=b1-uat and rm -rf ~/.bearings/b1-uat
- tool: make:claude/workflow/Makefile:bearings-test, bearings-up, bearings-down and stuck-watch-test - land with the builds; fallback: missing on main: stop with DESIGN-GAP naming it
- tool: path:claude/tools/artifact/artifact.sh - on main; fallback: missing: stop with DESIGN-GAP
- tool: cmd:git, cmd:jq, cmd:make, cmd:podman, cmd:gh - fallback: missing on the host: stop with ENV-MISSING naming it; gh or GitHub down: retry 3 times, then stop with A2A-003 and its output

**Out - non-goals**

- changing any file: a failing case is a bug ticket with its reproduction, handed to infra-design (item 22)
- the live inbox-triage page: the stable gate is make line-up on the live line after merge
- any owner notification (item 35)
- waiting on CI or merging: push, open the PR, write the result, leave (ORD-0542 O2)

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [ ] `AC-H1` *(human)* the dev gate passes
  - check: `make -C claude/workflow bearings-test` exit 0 expect /ok bearings/
- [ ] `AC-H2` *(human)* the deadman logged STK-092 for the downed test line
  - check: `grep -c STK-092\ line=b1-uat /home/luna/.local/state/zenith/stuck-watch/deadman.log` exit 0 expect /^[1-9]/

## Test plan

_Test plan from claude/workflow/templates/test-plan.md, shaped by claude/workflow/schemas/test-plan.schema.json. The tester runs exactly these cases and nothing else._

**Scope under test**

ORD-0832 B1 end to end: the live line's Bearings server as a systemd user unit brought up by line-up, and the deadman paging STK-092 on probe 000

**Cases**

- `TP-1`
  - intent: dev gate (item 34): both builds pass their suites on main
  - command: `bash -c 'make -C claude/workflow bearings-test && make -C claude/workflow stuck-watch-test'`
  - expected: exit 0; prints `ok  bearings`
- `TP-2`
  - intent: UAT gate (item 34) on a test line, never the live one: the unit runs and restarts after a kill
  - command: `bash -c 'make -C claude/workflow bearings-up LINE=b1-uat && sleep 3 && systemctl --user kill bearings-line@b1-uat.service && sleep 8 && systemctl --user is-active bearings-line@b1-uat.service; make -C claude/workflow bearings-down LINE=b1-uat'`
  - expected: exit 0; prints `active` after the kill (Restart=always)
- `TP-3`
  - intent: UAT gate: the deadman probe sees the test line down and pages the test topic only (item 35)
  - command: `bash -c 'SW_LINES=b1-uat NTFY_TOPIC_VAR=YPC_NTFY_TEST_TOPIC bash claude/workflow/stuck-watch/deadman.sh; grep -c "STK-092 line=b1-uat" ~/.local/state/zenith/stuck-watch/deadman.log'`
  - expected: prints a count of 1 or more, with the b1-uat unit down after TP-2

**Isolation**

- runtime: podman
- image: `docker.io/library/debian:bookworm-slim@sha256:3783cc01769c7b2b1b83a5c5ad96c815348e28ed7da68e2e3687004faa906251` (debian:bookworm-slim, base of localhost/dotfiles-workflow-test:1)

**Out of scope - CI covers**

- the stable gate on the live inbox-triage line: the line runs make line-up after this merges
- the full claude/workflow suite: CI runs it

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
