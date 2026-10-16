---
{
  "id": "WO-20261016-25f7",
  "slug": "work-order-sh-new-and-amend-refuse-a-scope-check",
  "title": "work-order.sh new and amend refuse a scope check that anchors a bare work-orders/ alternative",
  "type": "feature",
  "status": "ready",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T09:18:46+00:00",
  "parent": "WO-20261016-fb0c",
  "branch": null,
  "pr": null,
  "closed": null,
  "approval": {
    "via": "override",
    "reason": "infra-design9 cut for ORD-0830 RR-orch-14; design approvals ruled done, ORD-0550 O4",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [
    "WO-20261016-2d5b",
    "WO-20261016-2eb1"
  ],
  "blocks": [
    "WO-20261016-4710"
  ],
  "ac_checks": [
    {
      "index": 1,
      "command": "bash claude/skills/work-order/testing/run-tests.sh",
      "exit": 0,
      "expect": "330-scope-regex-lint"
    },
    {
      "index": 2,
      "command": "grep -c scope_regex_bare_dir claude/skills/work-order/scripts/work-order.sh",
      "exit": 0,
      "expect": "^[2-9]"
    },
    {
      "index": 3,
      "command": "make rolodex-check BASE=origin/main",
      "exit": 0,
      "expect": null
    },
    {
      "index": 4,
      "command": "git diff --name-only origin/main...HEAD | grep -vE '^(work-orders/.*|claude/skills/work-order/(scripts/work-order\\.sh|testing/SOP\\.md|testing/cases/330-scope-regex-lint\\.sh))$'",
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

# WO-20261016-25f7 - work-order.sh new and amend refuse a scope check that anchors a bare work-orders/ alternative

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

A scope AC written ^(work-orders/|...)$ matches only the literal path work-orders/, so every ticket file the close-out writes is printed and the check exits wrong on an in-scope diff. It blocked done on WO-20261016-448e (PR 262) and WO-20261016-b0ed (PR 264), and earlier WO-20261016-88d3 (PR 219). claude/workflow/templates/scope-ac.md already names the right form; nothing stops a cut from copying the wrong one.

## Owner words

> see a bug, isolate it, and get it fixed as asap (Design principles 101 item 22)

> if the task or job needs tools, the architect has a design agent build that shit out before the ticket goes in (item 30)

## Context

Evidence 2026-10-16: seats/restore242.result.json and seats/prepush-hook.result.json, both DESIGN-GAP on AC5; the corrected regex with work-orders/.* run over gh pr view 262, 264 and 220 --json files prints nothing (rc 1). Still on main with the bare form: WO-20261016-75b7 (in-review, PR 220 merged), and the infra-design8 tickets WO-20261016-efb2, WO-20261016-2d5b, WO-20261016-2eb1, WO-20261016-86b9, WO-20261016-c6a5, WO-20261016-f82b (not touched here: owned by PR 272).

Detection rule, fixed: in require_ac_checks, for each --ac-check, the bash ERE stored in a local re='work-orders/\\?[|)]' (work-orders/ followed directly by | or ), optionally backslash-escaped as the bash -c form of WO-20261016-448e stores it). A match dies with PS_VALIDATION (exit 3), error code scope_regex_bare_dir and the message: --ac-check anchors a bare work-orders/ alternative; write work-orders/.* (claude/workflow/templates/scope-ac.md). work-orders/.*| and grep -v '^work-orders/' do not match.

## Scope

**In**

- touches: claude/skills/work-order/scripts/work-order.sh (require_ac_checks only: the re local, the [[ ${ac_cmd[i]} =~ $re ]] test after the --ac-exit test, the ps_die line; a breadcrumb comment above it naming WO-20261016-448e, WO-20261016-b0ed, WO-20261016-88d3, ORD-0830 RR-orch-14 and the template path. new and amend both call require_ac_checks, so no other function changes)
- touches: claude/skills/work-order/testing/cases/330-scope-regex-lint.sh (new, modelled on 270-ac-check.sh: new with --ac-check "git diff --name-only origin/main...HEAD | grep -vE '^(work-orders/|a\.sh)$'" exits 3 with .error scope_regex_bare_dir and writes no file; the same check ending (a\.sh|work-orders/)$ exits 3; the 448e bash -c escaped form \^\(work-orders/\|a\\.sh\)\$ exits 3; work-orders/.* exits 0; grep -v '^work-orders/' exits 0; amend --ac on a draft with the bare form exits 3)
- touches: claude/skills/work-order/testing/SOP.md (one entry for 330-scope-regex-lint.sh: what runs, what is asserted, why)
- touches (generated, written only by work-order.sh start/submit/done, never by hand or git add): this ticket file and its archive path; work-orders/INDEX.md and the parent epic README.md are ignored generated views
- step: branch from origin/main in your own worktree; make exactly the three edits above
- step: run TP-1 to TP-3 of the test plan and the AC checks only; CI runs the rest
- step: commit 'feat(work-order): new and amend refuse a scope check anchoring a bare work-orders/ (ORD-0830 RR-orch-14)' with the ticket id; the PR body ends with 'Bump: work-order=minor'
- tool: script:claude/skills/work-order/testing/run-tests.sh and make:Makefile:rolodex-check - on main; fallback: missing: stop with DESIGN-GAP naming it
- tool: cmd:git, cmd:jq, cmd:make, cmd:podman, cmd:gh - fallback: missing on the host: stop with ENV-MISSING naming it; gh or GitHub down: retry 3 times, then stop with A2A-003 and its output

**Out - non-goals**

- rewriting any existing ticket: the lint guards new cuts only; existing tickets close by WO done --at merge
- any other function in work-order.sh or lib/wo.sh
- work-orders/INDEX.md and epic READMEs by hand or by git add
- waiting on CI or merging: push, open the PR, write the result, leave
- any file not named under In: stop with DESIGN-GAP

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [ ] `AC-H1` *(human)* the work-order suite passes with the new case
  - check: `bash claude/skills/work-order/testing/run-tests.sh` exit 0 expect /330-scope-regex-lint/
- [ ] `AC-H2` *(human)* the refusal code is in the script
  - check: `grep -c scope_regex_bare_dir claude/skills/work-order/scripts/work-order.sh` exit 0 expect /^[2-9]/
- [ ] `AC-H3` *(human)* every changed script has a rolodex header
  - check: `make rolodex-check BASE=origin/main` exit 0
- [ ] `AC-H4` *(human)* the diff holds only In files and generated work-orders files
  - check: `git diff --name-only origin/main...HEAD | grep -vE '^(work-orders/.*|claude/skills/work-order/(scripts/work-order\.sh|testing/SOP\.md|testing/cases/330-scope-regex-lint\.sh))$'` exit 1

## Test plan

{"scope":"work-order.sh require_ac_checks refuses a scope check whose anchored group carries a bare work-orders/ alternative","cases":[
{"id":"TP-1","intent":"the bare work-orders/ alternative inside ^(...)$ flags every ticket file and blocked done on WO-20261016-448e and WO-20261016-b0ed; new and amend must refuse it at cut time so it never reaches a seat","command":"bash claude/skills/work-order/testing/run-tests.sh","expected":"exit 0; the 330-scope-regex-lint.sh block prints only ok lines"},
{"id":"TP-2","intent":"the refusal code is wired in the script, not only in the test","command":"grep -c scope_regex_bare_dir claude/skills/work-order/scripts/work-order.sh","expected":"exit 0; prints 2 or more"},
{"id":"TP-3","intent":"the changed scripts keep their rolodex headers","command":"make rolodex-check BASE=origin/main","expected":"exit 0"}],
"isolation":{"runtime":"podman","image":"docker.io/library/debian@sha256:328d16499860ae6cb9b345e2e4cebca08c2a36e4f7278482c7bd1f39d71e5bfd"},
"out_of_scope":["the full work-order suite on CI and the skill gates: CI runs them"]}

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
