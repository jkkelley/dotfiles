---
{
  "id": "WO-20261016-9d20",
  "slug": "work-order-sh-next-line-reports-unlabeled-ready-",
  "title": "work-order.sh next --line reports UNLABELED-READY with a count on stderr, and new refuses a ticket with no line label unless --line NAME or the parent's line label gives it one (ORD-1224 U2)",
  "type": "feature",
  "status": "ready",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T12:34:40+00:00",
  "parent": "WO-20261016-fb0c",
  "branch": null,
  "pr": null,
  "closed": null,
  "approval": {
    "via": "override",
    "reason": "infra-design22 cut for BR-20261016-infra-design22; design approvals ruled done, ORD-0550 O4",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [
    "WO-20261016-3d4d"
  ],
  "blocks": [],
  "ac_checks": [
    {
      "index": 1,
      "command": "bash claude/skills/work-order/testing/run-tests.sh",
      "exit": 0,
      "expect": "all cases passed"
    },
    {
      "index": 2,
      "command": "grep -cE 'UNLABELED-READY|ps_die .*no_line' claude/skills/work-order/scripts/work-order.sh",
      "exit": 0,
      "expect": "^[2-9]"
    },
    {
      "index": 3,
      "command": "grep -c '^export WO_LINE_REQUIRED=0' claude/skills/work-order/testing/assert.sh",
      "exit": 0,
      "expect": "^1$"
    },
    {
      "index": 4,
      "command": "git diff --name-only origin/main...HEAD | grep -vE '^(work-orders/.*|claude/skills/work-order/(scripts/work-order\\.sh|testing/assert\\.sh|testing/SOP\\.md|testing/cases/470-line-label-required\\.sh))$'",
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

# WO-20261016-9d20 - work-order.sh next --line reports UNLABELED-READY with a count on stderr, and new refuses a ticket with no line label unless --line NAME or the parent's line label gives it one (ORD-1224 U2)

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

A ready leaf with no line:* label never appears in next --line, so the line's ready buffer reads short while startable work sits unseen, and nothing stops new from minting more such tickets.

## Owner words

> ORD-1224 U2 prevention leaf: work-order.sh next --line prints a stderr count and status code UNLABELED-READY when ready leaves exist without any line label, and new requires --line or inherits the parent line label; test case for both (orchestrator brief BR-20261016-infra-design22)

> automate the fuck out of shit (Design principles 101 item 30); fucking status codes i hate agent prose (Design principles 101 item 29)

## Context

Inventory on main 575b196: new already copies the parent's labels first (new_labels_json, ORD-0932 Q2) and takes --label; next --line filters on line:<name> in cmd_next and drops every other leaf silently. What is missing is the count of what was dropped for having no line label at all, and a refusal at new.

Fixed shape. next: in cmd_next, when --line is given, count the seat-ready leaves that pass every other filter (archived, startable, no children, not merged) but whose labels hold no entry starting line:; when the count is above 0, ps_info "UNLABELED-READY <count>: ready leaves with no line label; label them with work-order.sh set --tree <root> --add-label line:<name>" (stderr); exit code and stdout, text and --json, unchanged. new: accept --line NAME (validated by label_valid line:NAME, added to label_items); after new_labels_json, when WO_LINE_REQUIRED is not 0 and the labels hold no line:* entry, ps_die "$PS_VALIDATION" no_line "a ticket needs a line: pass --line NAME, --label line:NAME, or a --parent that carries one" before any file is written. The usage text gains the --line line under new.

Why the WO_LINE_REQUIRED switch: 33 existing cases mint top-level tickets through wo() with no label, and case 350 asserts exact label arrays, so a default label in wo() would break them. testing/assert.sh exports WO_LINE_REQUIRED=0 once, next to set -uo pipefail; case 470 sets WO_LINE_REQUIRED=1 on its own calls. Production never sets it, so the default is on. Breadcrumb comments at both edits per the global breadcrumb rule (rejected alternative: a default --line test in wo(), because it changes labels case 350 asserts).

## Scope

**In**

- touches: claude/skills/work-order/scripts/work-order.sh (cmd_next unlabeled count and ps_info line; --line accepted on new; the no_line refusal in cmd_new; the new usage line; breadcrumbs only)
- touches: claude/skills/work-order/testing/assert.sh (one line: export WO_LINE_REQUIRED=0, with its breadcrumb)
- touches: claude/skills/work-order/testing/cases/470-line-label-required.sh (new): the TP-1 and TP-2 sub-cases exactly, next stderr read with 2>&1 >/dev/null, refusals by calling work-order.sh directly with WO_LINE_REQUIRED=1
- touches: claude/skills/work-order/testing/SOP.md (one ## 470-line-label-required entry, after the last entry)
- touches (generated, written only by work-order.sh start/submit/done, never by hand or git add): this ticket file and its archive path; work-orders/INDEX.md and the parent epic README.md are ignored generated views
- step: start only after WO-20261016-3d4d is done on main (same files); branch from origin/main in your own git worktree (fallback: treehouse fails, use git worktree add), never the ~/dotfiles primary clone; bash claude/skills/work-order/scripts/work-order.sh start --id <this ticket>
- step: make exactly the edits in Context and the In lines
- step: run the AC checks with bash claude/skills/work-order/scripts/work-order.sh check --id <this ticket>; CI runs the rest
- step: commit 'feat(work-order): next --line reports UNLABELED-READY, new refuses a ticket with no line label' with the ticket id; the PR body ends with 'Bump: work-order=minor'; push, gh pr create, submit --pr <N>, done on the branch, push, leave
- tool: script:claude/skills/work-order/testing/run-tests.sh - on main; fallback: missing: stop with DESIGN-GAP naming it; its image fails to build: stop with ENV-MISSING podman
- tool: cmd:git, cmd:jq, cmd:podman, cmd:gh - fallback: missing on the host: stop with ENV-MISSING naming it; gh or GitHub down: retry 3 times, then stop with A2A-003 and its output

**Out - non-goals**

- labelling existing tickets: WO-20261016-8a35 does that
- next without --line, set, stale-merged, lib/wo.sh, SKILL.md
- changing next's exit code or stdout
- any file not named under In: stop with DESIGN-GAP
- work-orders/INDEX.md and epic READMEs by hand or by git add; waiting on CI or merging: push, open the PR, write the result, leave

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [ ] `AC-H1` *(human)* the skill suite passes with case 470
  - check: `bash claude/skills/work-order/testing/run-tests.sh` exit 0 expect /all cases passed/
- [ ] `AC-H2` *(human)* next carries the UNLABELED-READY code and new the no_line refusal
  - check: `grep -cE 'UNLABELED-READY|ps_die .*no_line' claude/skills/work-order/scripts/work-order.sh` exit 0 expect /^[2-9]/
- [ ] `AC-H3` *(human)* the test harness opts out once
  - check: `grep -c '^export WO_LINE_REQUIRED=0' claude/skills/work-order/testing/assert.sh` exit 0 expect /^1$/
- [ ] `AC-H4` *(human)* the diff holds only In files
  - check: `git diff --name-only origin/main...HEAD | grep -vE '^(work-orders/.*|claude/skills/work-order/(scripts/work-order\.sh|testing/assert\.sh|testing/SOP\.md|testing/cases/470-line-label-required\.sh))$'` exit 1

## Test plan

_Test plan from claude/workflow/templates/test-plan.md, shaped by claude/workflow/schemas/test-plan.schema.json. The tester runs exactly these cases and nothing else._

**Scope under test**

work-order.sh next --line (UNLABELED-READY stderr count) and new (--line, the no_line refusal)

**Cases**

- `TP-1`
  - intent: a ready leaf with no line label is invisible to next --line, so the line reads an empty or short buffer while startable work sits unseen (ORD-1224); next --line must say how many and with which code
  - command: `bash claude/skills/work-order/testing/run-tests.sh`
  - expected: exit 0 and all cases passed; case 470-line-label-required.sh prints PASS for: next --line x with one unlabeled ready leaf writes UNLABELED-READY 1 to stderr and exits 0 with the stdout list unchanged; with none unlabeled no UNLABELED-READY line
- `TP-2`
  - intent: the leak is closed at the source: new refuses a ticket that would carry no line label, accepts --line NAME, and a child inherits its parent's line label with no flag
  - command: `bash claude/skills/work-order/testing/run-tests.sh`
  - expected: exit 0 and all cases passed; case 470 prints PASS for: WO_LINE_REQUIRED=1 new --top-level with no line exits 3 with error no_line and writes no file; new --top-level --line x writes labels ["line:x"]; new --parent <that one> with no flag inherits line:x

**Isolation**

_A locally built image uses `- image: localhost/<name>:<tag>` plus `- build: <command>` and `- containerfile: <path>` lines, never a localhost digest (RR-orch-18)._

- runtime: podman
- image: `localhost/work-order-test:1`
- build: `bash claude/skills/work-order/testing/run-tests.sh`
- containerfile: `claude/skills/work-order/testing/Containerfile`

**Out of scope - CI covers**

- lint and the full work-order suite: CI runs them (Design principles 101 item 6)

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
