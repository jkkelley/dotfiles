---
{
  "id": "WO-20261016-2299",
  "slug": "pr-flow-records-sh-posts-through-bash-bus-sh-so-",
  "title": "pr-flow records.sh posts through bash bus.sh, so pr-flow records reach the bus when bus.sh is not executable",
  "type": "bug",
  "status": "ready",
  "priority": "p2",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T10:26:45+00:00",
  "parent": "WO-20261016-af17",
  "branch": null,
  "pr": null,
  "closed": null,
  "approval": {
    "via": "override",
    "reason": "infra-design14 cut for ORD-0830 RR-orch-14 F35; design approvals ruled done, ORD-0550 O4",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [
    "WO-20261016-73f2"
  ],
  "blocks": [],
  "ac_checks": [
    {
      "index": 1,
      "command": "make -C claude/workflow pr-flow-test CASES=records",
      "exit": 0,
      "expect": "ok  records"
    },
    {
      "index": 2,
      "command": "make -C claude/workflow pr-flow-lint",
      "exit": 0,
      "expect": null
    },
    {
      "index": 3,
      "command": "grep -c 'PR_FLOW_PUB:-bash $HERE/../../bin/bus.sh pub' claude/workflow/pr-flow/bin/records.sh",
      "exit": 0,
      "expect": "^1$"
    },
    {
      "index": 4,
      "command": "git diff --name-only origin/main...HEAD | grep -vE '^(work-orders/.*|claude/workflow/pr-flow/(bin/records\\.sh|tests/records\\.test\\.sh))$'",
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

# WO-20261016-2299 - pr-flow records.sh posts through bash bus.sh, so pr-flow records reach the bus when bus.sh is not executable

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

claude/workflow/pr-flow/bin/records.sh line 57 runs $HERE/../../bin/bus.sh pub directly; bus.sh is mode 100644, so every bus post of a pr-flow record fails with exit 126, the same defect as step-time.sh.

## Owner words

> make pr-autofix (fb99) publishes to line.pr-flow.event.ci.autofix ... and fails 3 times (orchestrator brief BR-20261016-infra-design14)

> Every DAG node, seat, job, CI run and merge records its start and end in UTC on the bus by script (Design principles 101 item 37)

## Context

Same root cause as the step-time ticket, brief BR-20261016-infra-design14, ORD-0830 RR-orch-14; F35; evidence ~/.local/state/zenith/evidence/2026/10/20261016-101833-step-time-bus-sh-noexec.txt. Ordered after WO-20261016-fb99 and WO-20261016-73f2 because both touch records.sh and records.test.sh (item 19, disjoint files at once). Fix, exactly: the default in line 57 (its line number may move after fb99 and 73f2; it is the one read -r -a PUB line) becomes "bash $HERE/../../bin/bus.sh pub" with PR_FLOW_PUB unchanged as the override, and a breadcrumb naming this ticket and the evidence. Test: one appended case in pr-flow/tests/records.test.sh: a mktemp tree with records.sh at a/b/bin/ and a 0644 stub at a/bin/bus.sh that logs its args, PR_FLOW_PUB unset, records.sh post with a fixture record and the bus sink; assert the stub log holds the subject line.<line>.event. and records.sh exits 0.

## Scope

**In**

- touches: claude/workflow/pr-flow/bin/records.sh (the PUB default line and its breadcrumb only)
- touches: claude/workflow/pr-flow/tests/records.test.sh (one appended case)
- touches (generated, written only by work-order.sh start/submit/done, never by hand or git add): this ticket file and its archive path; work-orders/INDEX.md and the parent epic README.md are ignored generated views
- step: branch from origin/main in your own git worktree, never the ~/dotfiles primary clone
- step: rebase on origin/main after fb99 and 73f2 merged; make the edit and the case; run make -C claude/workflow pr-flow-test CASES=records and pr-flow-lint and make rolodex-check BASE=origin/main and the AC checks only
- step: commit 'fix(workflow): pr-flow records post through bash bus.sh' with the ticket id; no Bump trailer
- tool: make:claude/workflow/pr-flow/pr-flow.mk:pr-flow-test - on main; tool: image localhost/dotfiles-workflow-test:1 - fallback: missing: make -C claude/workflow image, then retry once; build fails: stop with ENV-MISSING podman
- tool: cmd:git, cmd:jq, cmd:make, cmd:podman, cmd:gh - fallback: missing on the host: stop with ENV-MISSING naming it; gh or GitHub down: retry 3 times, then stop with A2A-003 and its output

**Out - non-goals**

- claude/workflow/bin/bus.sh and its mode: WO-20261016-2092 owns it
- any other records.sh behaviour
- any file not named under In: stop with DESIGN-GAP
- work-orders/INDEX.md and epic READMEs by hand or by git add; waiting on CI or merging: push, open the PR, write the result, leave
- a Bump trailer: no skill under claude/skills changes

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [ ] `AC-H1` *(human)* the records cases pass, including the non-executable bus.sh case
  - check: `make -C claude/workflow pr-flow-test CASES=records` exit 0 expect /ok records/
- [ ] `AC-H2` *(human)* pr-flow scripts lint clean
  - check: `make -C claude/workflow pr-flow-lint` exit 0
- [ ] `AC-H3` *(human)* the default publisher runs bus.sh through bash
  - check: `grep -c 'PR_FLOW_PUB:-bash $HERE/../../bin/bus.sh pub' claude/workflow/pr-flow/bin/records.sh` exit 0 expect /^1$/
- [ ] `AC-H4` *(human)* the diff holds only In files and generated work-orders files
  - check: `git diff --name-only origin/main...HEAD | grep -vE '^(work-orders/.*|claude/workflow/pr-flow/(bin/records\.sh|tests/records\.test\.sh))$'` exit 1

## Test plan

```sh
{"scope":"records.sh default bus publisher","cases":[{"id":"TP-1","intent":"pr-flow records never reach the bus while bus.sh is not executable, so the sweep and merge events are invisible","command":"make -C claude/workflow pr-flow-test CASES=records","expected":"exit 0; ok records"}],"isolation":{"runtime":"podman","image":"localhost/dotfiles-workflow-test:1"},"out_of_scope":["the full pr-flow suite: CI runs it"]}
```

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
