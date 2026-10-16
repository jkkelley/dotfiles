---
{
  "id": "WO-20261016-3d4d",
  "slug": "work-order-sh-new-amend-and-approve-refuse-a-tes",
  "title": "work-order.sh new, amend and approve refuse a test ticket whose plan is the one-line --test-plan fence (test_plan_one_line), so no test ticket reaches ready with a plan start refuses",
  "type": "feature",
  "status": "ready",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T10:55:16+00:00",
  "parent": "WO-20261016-fb0c",
  "branch": null,
  "pr": null,
  "closed": null,
  "approval": {
    "via": "override",
    "reason": "infra-design16 cut for ORD-0830 RR-orch-14 F35; design approvals ruled done, ORD-0550 O4",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [
    "WO-20261016-1099",
    "WO-20261016-0f38",
    "WO-20261016-ef1b",
    "WO-20261016-e03c"
  ],
  "blocks": [
    "WO-20261016-138a",
    "WO-20261016-2eb1"
  ],
  "ac_checks": [
    {
      "index": 1,
      "command": "bash claude/skills/work-order/testing/run-tests.sh",
      "exit": 0,
      "expect": "all cases passed"
    },
    {
      "index": 2,
      "command": "grep -cE 'ps_die .*test_plan_one_line' claude/skills/work-order/scripts/work-order.sh",
      "exit": 0,
      "expect": "^3$"
    },
    {
      "index": 3,
      "command": "make rolodex-check BASE=origin/main",
      "exit": 0,
      "expect": null
    },
    {
      "index": 4,
      "command": "git diff --name-only origin/main...HEAD | grep -vE '^(work-orders/.*|claude/skills/work-order/(scripts/work-order\\.sh|testing/SOP\\.md|testing/cases/440-test-plan-one-line\\.sh))$'",
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

# WO-20261016-3d4d - work-order.sh new, amend and approve refuse a test ticket whose plan is the one-line --test-plan fence (test_plan_one_line), so no test ticket reaches ready with a plan start refuses

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

The generator lets a design seat write a --type test ticket whose ## Test plan is one fenced line (new --test-plan T renders ```sh T ```, work-order.sh:466-467). approve accepts it, so the ticket goes ready; start then refuses it test_plan_missing (wo_require_test_plan, lib/wo.sh:377), and amend refuses a ready ticket. Four tickets hit this at once (WO-20261016-d6b3, 712e, b335, a4da, recut by infra-design16 as 5fd3, 3475, f675, 6edb) and each cost a seat start, a DESIGN-GAP and a recut.

## Owner words

> DESIGN-GAP WKt test plan shape: start refuses, Test plan is a one-line JSON in a sh fence, not the claude/workflow/templates/test-plan.md shape; ticket is ready so amend refuses ... cut every item as ready work orders with work-order.sh, fixing the generator or template that writes the scope AC (orchestrator brief BR-20261016-infra-design16)

> every node has what it fucking needs up front, not later, design it that way (Design principles 101 item 30)

## Context

Evidence: /home/luna/.local/state/zenith/inbox-triage/20261015/seats/wk0t.result.json (start output: is a test ticket with no test plan block). Root cause: the refusal lives only at start; new and approve let the shape through, so it is found by the tester instead of the designer.

Exact edits in claude/skills/work-order/scripts/work-order.sh: (1) cmd_new, right after require_test_plan_file (line ~634): if type is test and test_plan is non-empty: ps_die "$PS_VALIDATION" test_plan_one_line "a test ticket's plan is a filled copy of claude/workflow/templates/test-plan.md passed with --test-plan-file; --test-plan writes one fenced line that start refuses"; nothing is written. (2) cmd_amend, right after its require_test_plan_file (line ~805): the same refusal when the ticket's .type is test and --test-plan is given. (3) cmd_approve, right after require_tools_resolve: if the ticket's .type is test and its ## Test plan section has a line starting with three backticks: ps_die "$PS_VALIDATION" test_plan_one_line "$id test plan is a fenced one-line block, not the claude/workflow/templates/test-plan.md shape that start reads - amend --test-plan-file while it is a draft". A test ticket with no plan (_none recorded_) still approves, as case 240 relies on. (4) usage line for --test-plan (line ~121): append 'Refused on --type test: use --test-plan-file.' Each edit carries a breadcrumb naming this ticket and wk0t.result.json.

New case claude/skills/work-order/testing/cases/440-test-plan-one-line.sh, in the style of 240-test-plan-gate.sh: (a) new --type test --test-plan 'x' exits 3, .error test_plan_one_line, no ticket file written; (b) new --type feature --test-plan 'x' exits 0; (c) a draft --type test ticket whose ## Test plan section the case rewrites with sed to a three-backtick fenced line: approve exits 3 with .error test_plan_one_line and status stays draft; amend --test-plan 'y' on it exits 3 test_plan_one_line; (d) a draft test ticket given a template-shaped --test-plan-file approves exit 0. testing/SOP.md gains a '## 440-test-plan-one-line' entry after the last numbered entry, one what line and one Why line, like 240.

Order: depends on WO-20261016-1099 (after e297, both edit cmd_approve and testing/SOP.md), WO-20261016-0f38 and WO-20261016-9fc7 (both append to testing/SOP.md), so no two concurrent tickets touch the same file (Design principles 101 item 19).

## Scope

**In**

- touches: claude/skills/work-order/scripts/work-order.sh (cmd_new guard, cmd_amend guard, cmd_approve guard, the --test-plan usage line, breadcrumbs only)
- touches: claude/skills/work-order/testing/cases/440-test-plan-one-line.sh (new)
- touches: claude/skills/work-order/testing/SOP.md (one entry for 440)
- touches (generated, written only by work-order.sh start/submit/done, never by hand or git add): this ticket file and its archive path; work-orders/INDEX.md and the parent epic README.md are ignored generated views
- step: branch from origin/main in your own git worktree, never the ~/dotfiles primary clone
- step: make exactly the edits in Context
- step: run the AC checks only; CI runs the rest
- step: commit 'feat(work-order): new, amend and approve refuse a one-line test plan on a test ticket' with the ticket id; the PR body ends with 'Bump: work-order=minor'
- tool: script:claude/skills/work-order/testing/run-tests.sh - on main; fallback: missing: stop with DESIGN-GAP naming it; its image fails to build: stop with ENV-MISSING podman
- tool: make:Makefile:rolodex-check - on main; fallback: missing: stop with DESIGN-GAP naming it
- tool: cmd:git, cmd:jq, cmd:make, cmd:podman, cmd:gh - fallback: missing on the host: stop with ENV-MISSING naming it; gh or GitHub down: retry 3 times, then stop with A2A-003 and its output

**Out - non-goals**

- start's wo_require_test_plan and lib/wo.sh: unchanged, start stays the full runnable check
- migrating other tickets' plans: recuts are design work orders, not this ticket
- the template claude/workflow/templates/test-plan.md: unchanged
- any file not named under In: stop with DESIGN-GAP
- work-orders/INDEX.md and epic READMEs by hand or by git add; waiting on CI or merging: push, open the PR, write the result, leave

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [ ] `AC-H1` *(human)* case 440 and the work-order skill suite pass
  - check: `bash claude/skills/work-order/testing/run-tests.sh` exit 0 expect /all cases passed/
- [ ] `AC-H2` *(human)* work-order.sh refuses test_plan_one_line at new, amend and approve
  - check: `grep -cE 'ps_die .*test_plan_one_line' claude/skills/work-order/scripts/work-order.sh` exit 0 expect /^3$/
- [ ] `AC-H3` *(human)* every changed script has a rolodex header
  - check: `make rolodex-check BASE=origin/main` exit 0
- [ ] `AC-H4` *(human)* the diff holds only In files and generated work-orders files
  - check: `git diff --name-only origin/main...HEAD | grep -vE '^(work-orders/.*|claude/skills/work-order/(scripts/work-order\.sh|testing/SOP\.md|testing/cases/440-test-plan-one-line\.sh))$'` exit 1

## Test plan

_Test plan from claude/workflow/templates/test-plan.md, shaped by claude/workflow/schemas/test-plan.schema.json. The tester runs exactly these cases and nothing else._

**Scope under test**

work-order.sh new, amend and approve refusing a one-line fenced test plan on a test ticket (case 440)

**Cases**

- `TP-1`
  - intent: four WK test tickets (d6b3, 712e, b335, a4da) reached ready with a one-line JSON plan that start refuses, and a ready ticket cannot be amended; the refusal must come at new, amend and approve, before ready
  - command: `bash claude/skills/work-order/testing/run-tests.sh`
  - expected: exit 0; last line all cases passed, case 440 among them

**Isolation**

_A locally built image uses `- image: localhost/<name>:<tag>` plus `- build: <command>` and `- containerfile: <path>` lines, never a localhost digest (RR-orch-18)._

- runtime: podman
- image: `localhost/work-order-test:1`
- build: `bash claude/skills/work-order/testing/run-tests.sh`
- containerfile: `claude/skills/work-order/testing/Containerfile`

**Out of scope - CI covers**

- lint and the workflow suite: CI runs them

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
