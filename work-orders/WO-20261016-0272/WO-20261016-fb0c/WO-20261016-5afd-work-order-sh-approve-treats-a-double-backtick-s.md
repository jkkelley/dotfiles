---
{
  "id": "WO-20261016-5afd",
  "slug": "work-order-sh-approve-treats-a-double-backtick-s",
  "title": "work-order.sh approve treats a double-backtick span in a step line as a literal and never resolves it as a command",
  "type": "bug",
  "status": "ready",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T10:07:41+00:00",
  "parent": "WO-20261016-fb0c",
  "branch": null,
  "pr": null,
  "closed": null,
  "approval": {
    "via": "override",
    "reason": "infra-design13 cut for ORD-0830 RR-orch-14; design approvals ruled done, ORD-0550 O4",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [
    "WO-20261016-3a66"
  ],
  "blocks": [
    "WO-20261016-5320"
  ],
  "ac_checks": [
    {
      "index": 1,
      "command": "bash claude/skills/work-order/testing/run-tests.sh",
      "exit": 0,
      "expect": "390-approve-literal-spans"
    },
    {
      "index": 2,
      "command": "make rolodex-check BASE=origin/main",
      "exit": 0,
      "expect": null
    },
    {
      "index": 3,
      "command": "git diff --name-only origin/main...HEAD | grep -vE '^(work-orders/.*|claude/skills/work-order/(SKILL\\.md|scripts/work-order\\.sh|testing/SOP\\.md|testing/cases/390-approve-literal-spans\\.sh))$'",
      "exit": 1,
      "expect": null
    }
  ],
  "provides": [
    "path:claude/skills/work-order/testing/cases/390-approve-literal-spans.sh"
  ],
  "labels": [
    "line:inbox-triage"
  ]
}
---

# WO-20261016-5afd - work-order.sh approve treats a double-backtick span in a step line as a literal and never resolves it as a command

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

approve (require_tools_resolve in claude/skills/work-order/scripts/work-order.sh) resolves every single-backtick span in an In step line as a command, so a regex or literal written in backticks is refused as tool_missing; the 8454 step text had its backticks converted to quotes to get past approve.

## Owner words

> see a bug, isolate it, and get it fixed as asap (Design principles 101 item 22)

> if the task or job needs tools, the architect has a design agent build that shit out before the ticket goes in, thats a prereq for the ticket ready then (Design principles 101 item 30)

## Context

Order ORD-0830 RR-orch-14, brief BR-20261016-infra-design13 item DESIGN-GAP approve backticks; evidence seats/infra-design12.result.json facts.tool_gap_2. Folded into the approve tooling chain on resolve_tool: 67c7 -> f57d -> e297 -> 2eb1 -> 25f7 -> 4710 -> 3a66 -> this ticket.

Behaviour, fixed. In require_tools_resolve, on each In step line, delete every span that opens and closes with two backticks and holds no backtick (sed -E with the pattern two backticks, [^backtick]*, two backticks) before the single-backtick grep; what is left resolves exactly as today. So a step reads: run the single-backticked command and check its output matches the double-backticked literal. Update the comment block above tool_ref (the 'approve resolves tools (ORD-0555)' block) with one line naming the literal form and this ticket. SKILL.md: one sentence after the Degrees of freedom table: a literal in a step line is wrapped in double backticks; a single-backtick span is a command approve resolves. ac_checks are unchanged.

Test case claude/skills/work-order/testing/cases/390-approve-literal-spans.sh, modelled on 280-approve-resolves-tools.sh with tool.sh committed and pushed: (a) a step with single-backtick bash tool.sh and a double-backtick ^ok [0-9]+$ literal: approve exit 0, ready; (b) a step whose only span is the single-backtick ^ok$: exit 3 tool_missing (today's behaviour kept); (c) a step whose only span is double-backtick nosuchcmd: exit 0; (d) a step with single-backtick nosuchcmd beside a double-backtick literal: exit 3 tool_missing nosuchcmd.

## Scope

**In**

- touches: claude/skills/work-order/scripts/work-order.sh (require_tools_resolve and its comment block only)
- touches: claude/skills/work-order/testing/cases/390-approve-literal-spans.sh (new, cases a to d in Context)
- touches: claude/skills/work-order/testing/SOP.md (one entry for 390)
- touches: claude/skills/work-order/SKILL.md (the one sentence in Context)
- touches (generated, written only by work-order.sh start/submit/done, never by hand or git add): this ticket file and its archive path; work-orders/INDEX.md and the parent epic README.md are ignored generated views
- step: branch from origin/main in your own git worktree after WO-20261016-3a66 merged; make exactly the four edits in Context
- step: run `bash claude/skills/work-order/testing/run-tests.sh` and the AC checks only; CI runs the rest
- step: commit 'fix(work-order): approve leaves double-backtick literals unresolved' with the ticket id; the PR body ends with 'Bump: work-order=patch'
- tool: script:claude/skills/work-order/testing/run-tests.sh - on main; fallback: missing: stop with DESIGN-GAP naming it; its image fails to build: stop with ENV-MISSING podman
- tool: make:Makefile:rolodex-check - on main; fallback: missing: stop with DESIGN-GAP naming it
- tool: cmd:git, cmd:jq, cmd:make, cmd:podman, cmd:gh - fallback: missing on the host: stop with ENV-MISSING naming it; gh or GitHub down: retry 3 times, then stop with A2A-003 and its output

**Out - non-goals**

- ac_checks resolution, resolve_tool itself, the env-prefix skip of WO-20261016-3a66
- rewriting existing tickets' quoted literals
- work-orders/INDEX.md and epic READMEs by hand or by git add; waiting on CI or merging: push, open the PR, write the result, leave
- any file not named under In: stop with DESIGN-GAP

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [ ] `AC-H1` *(human)* the work-order suite passes with the new case
  - check: `bash claude/skills/work-order/testing/run-tests.sh` exit 0 expect /390-approve-literal-spans/
- [ ] `AC-H2` *(human)* every changed script has a rolodex header
  - check: `make rolodex-check BASE=origin/main` exit 0
- [ ] `AC-H3` *(human)* the diff holds only In files and generated work-orders files
  - check: `git diff --name-only origin/main...HEAD | grep -vE '^(work-orders/.*|claude/skills/work-order/(SKILL\.md|scripts/work-order\.sh|testing/SOP\.md|testing/cases/390-approve-literal-spans\.sh))$'` exit 1

## Test plan

```sh
{"scope":"approve leaves double-backtick literals in step lines unresolved","cases":[{"id":"TP-1","intent":"a regex in backticks was refused tool_missing (seats/infra-design12.result.json tool_gap_2); a literal must have a form approve skips while commands stay checked","command":"bash claude/skills/work-order/testing/run-tests.sh","expected":"exit 0; 390-approve-literal-spans prints only ok lines and 280 still passes"},{"id":"TP-2","intent":"rolodex header kept","command":"make rolodex-check BASE=origin/main","expected":"exit 0"}],"isolation":{"runtime":"podman","image":"docker.io/library/debian@sha256:328d16499860ae6cb9b345e2e4cebca08c2a36e4f7278482c7bd1f39d71e5bfd"},"out_of_scope":["the skill gates: CI runs them"]}
```

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
