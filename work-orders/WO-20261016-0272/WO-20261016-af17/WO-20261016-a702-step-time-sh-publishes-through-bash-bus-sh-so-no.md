---
{
  "id": "WO-20261016-a702",
  "slug": "step-time-sh-publishes-through-bash-bus-sh-so-no",
  "title": "step-time.sh publishes through bash bus.sh, so no timed step loses its bus events to a non-executable bus.sh (exit 126)",
  "type": "bug",
  "status": "ready",
  "priority": "p2",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T10:26:33+00:00",
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
  "depends_on": [],
  "blocks": [],
  "ac_checks": [
    {
      "index": 1,
      "command": "make -C claude/workflow step-time",
      "exit": 0,
      "expect": null
    },
    {
      "index": 2,
      "command": "grep -c 'STEP_TIME_PUB:-bash $HERE/bus.sh pub' claude/workflow/bin/step-time.sh",
      "exit": 0,
      "expect": "^1$"
    },
    {
      "index": 3,
      "command": "make rolodex-check BASE=origin/main",
      "exit": 0,
      "expect": null
    },
    {
      "index": 4,
      "command": "git diff --name-only origin/main...HEAD | grep -vE '^(work-orders/.*|claude/workflow/(bin/step-time\\.sh|tests/unit/test_step_time\\.sh))$'",
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

# WO-20261016-a702 - step-time.sh publishes through bash bus.sh, so no timed step loses its bus events to a non-executable bus.sh (exit 126)

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

Every make target timed by bin/step-time.sh prints 'step-time: publish to line.<L>.time.<node> failed' and nothing reaches the bus: step-time.sh line 39 runs $HERE/bus.sh pub directly and bus.sh is mode 100644 in git, so the exec fails with Permission denied (126). The brief read it as a missing stream; the LINE stream binds line.> and a direct bash bin/bus.sh pub succeeds.

## Owner words

> make pr-autofix (fb99) publishes to line.pr-flow.event.ci.autofix and line.pr-flow.time.autofix and fails 3 times (orchestrator brief BR-20261016-infra-design14)

> Every DAG node, seat, job, CI run and merge records its start and end in UTC on the bus by script (Design principles 101 item 37)

## Context

Reproduction, brief BR-20261016-infra-design14, ORD-0830 RR-orch-14; F35: evidence ~/.local/state/zenith/evidence/2026/10/20261016-101833-step-time-bus-sh-noexec.txt. make -C claude/workflow pr-autofix REPO=jkkelley/dotfiles PR=300 prints the publish failed line twice; bash bin/step-time.sh --line inbox-triage --node probe --budget 60 --timeout 60 --retries 1 -- true fails the same way for any line; a wrapper around the same call shows 'bin/bus.sh: Permission denied' rc 126; git ls-files -s claude/workflow/bin/bus.sh shows 100644; make bus-status shows stream LINE subjects line.>; bash bin/bus.sh pub line.pr-flow.time.autofix '{}' exits 0. So no bus config change is needed.

Fix, exactly: step-time.sh line 39 default becomes "bash $HERE/bus.sh pub" (STEP_TIME_PUB unchanged as the override), with a breadcrumb comment above it naming this ticket, the evidence path and the rejected alternative (chmod +x bus.sh: bus.sh is in WO-20261016-2092's In list, and a mode bit is lost on copy to Windows Git Bash, Rule 17). Test, appended to tests/unit/test_step_time.sh as one more case: copy step-time.sh into a mktemp bin dir beside a stub bus.sh with mode 0644 that appends its arguments to a log, unset STEP_TIME_PUB, run it with --retries 1 -- true; assert the log has a line starting 'pub line.t.time.n' and stderr has no 'publish to' line.

## Scope

**In**

- touches: claude/workflow/bin/step-time.sh (line 39 default and its breadcrumb only)
- touches: claude/workflow/tests/unit/test_step_time.sh (one appended case, as in Context)
- touches (generated, written only by work-order.sh start/submit/done, never by hand or git add): this ticket file and its archive path; work-orders/INDEX.md and the parent epic README.md are ignored generated views
- step: branch from origin/main in your own git worktree, never the ~/dotfiles primary clone
- step: make the edit and the case; run make -C claude/workflow step-time and make rolodex-check BASE=origin/main and the AC checks only
- step: UAT: make -C claude/workflow pr-autofix REPO=jkkelley/dotfiles PR=<any open PR> 2>&1 | grep -c 'publish to' prints 0; save the output to the artifact store (key evidence) and name it in your result
- step: commit 'fix(workflow): step-time publishes through bash bus.sh' with the ticket id; no Bump trailer
- tool: make:claude/workflow/Makefile:step-time - on main; tool: image localhost/dotfiles-workflow-test:1 - fallback: missing: make -C claude/workflow image, then retry once; build fails: stop with ENV-MISSING podman
- tool: bus (make -C claude/workflow bus-up) for the UAT step - fallback: bus down: make bus-up once, still down: skip UAT, report BUS-DOWN with make bus-status output
- tool: cmd:git, cmd:jq, cmd:make, cmd:podman, cmd:gh - fallback: missing on the host: stop with ENV-MISSING naming it; gh or GitHub down: retry 3 times, then stop with A2A-003 and its output

**Out - non-goals**

- claude/workflow/bin/bus.sh and its mode: WO-20261016-2092 owns it
- pr-flow/bin/records.sh: same defect, its own ticket after fb99 and 73f2
- claude/workflow/config/line-watch.json: the stream already binds line.>
- any file not named under In: stop with DESIGN-GAP
- work-orders/INDEX.md and epic READMEs by hand or by git add; waiting on CI or merging: push, open the PR, write the result, leave
- a Bump trailer: no skill under claude/skills changes

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [ ] `AC-H1` *(human)* step-time unit cases pass, including the non-executable bus.sh case
  - check: `make -C claude/workflow step-time` exit 0
- [ ] `AC-H2` *(human)* the default publisher runs bus.sh through bash
  - check: `grep -c 'STEP_TIME_PUB:-bash $HERE/bus.sh pub' claude/workflow/bin/step-time.sh` exit 0 expect /^1$/
- [ ] `AC-H3` *(human)* every changed script has a rolodex header
  - check: `make rolodex-check BASE=origin/main` exit 0
- [ ] `AC-H4` *(human)* the diff holds only In files and generated work-orders files
  - check: `git diff --name-only origin/main...HEAD | grep -vE '^(work-orders/.*|claude/workflow/(bin/step-time\.sh|tests/unit/test_step_time\.sh))$'` exit 1

## Test plan

```sh
{"scope":"step-time.sh default publisher","cases":[{"id":"TP-1","intent":"timing events vanish from the bus for every timed target when bus.sh is not executable; item 37 needs them","command":"make -C claude/workflow step-time","expected":"exit 0; the new non-executable bus.sh case prints ok"},{"id":"TP-2","intent":"UAT: a real timed target publishes","command":"make -C claude/workflow pr-autofix REPO=jkkelley/dotfiles PR=300 2>&1 | grep -c \"publish to\"","expected":"prints 0"}],"isolation":{"runtime":"podman","image":"localhost/dotfiles-workflow-test:1"},"out_of_scope":["records.sh: its own ticket","the full workflow suite: CI runs it"]}
```

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
