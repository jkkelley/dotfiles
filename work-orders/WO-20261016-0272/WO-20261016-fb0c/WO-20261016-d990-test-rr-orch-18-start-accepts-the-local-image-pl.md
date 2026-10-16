---
{
  "id": "WO-20261016-d990",
  "slug": "test-rr-orch-18-start-accepts-the-local-image-pl",
  "title": "Test - RR-orch-18: start accepts the local-image plan form and refuses a localhost digest",
  "type": "test",
  "status": "ready",
  "priority": "p0",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T09:05:53+00:00",
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
    "WO-20261016-86b9"
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
      "command": "make -C claude/workflow test-plan",
      "exit": 0,
      "expect": "ok  local image form valid"
    }
  ],
  "provides": [],
  "labels": [
    "line:inbox-triage"
  ]
}
---

# WO-20261016-d990 - Test - RR-orch-18: start accepts the local-image plan form and refuses a localhost digest

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

Run the filled test plan of WO-20261016-86b9 exactly as written, on its merged main; dev gate (item 34), no owner notification (item 35).

## Owner words

> i want work scoped so small a fuck ape could do, testing the same way with test plans and scripts, every node has what it fucking needs up front, not later (Design principles 101 item 30)

> Ensure that your testing is dev uat stable. (item 34)

## Context

Architect ruling RR-orch-18, 2026-10-16: a locally built image is never pinned by digest. Evidence: ~/.local/state/zenith/log/2026/10/20261016-080957-t21e-cards-uat-digest.txt (UAT cards suite run on pinned image 0a6832bb, image id f4d2d4c03c76): a localhost digest names one build on one machine; every rebuild of claude/workflow/tests/container/Containerfile mints a new digest, so a plan pinned to it stops resolving (11 plans pinned 0a6832bb, 2 still live as drafts). What Rule 15 protects is the base: the Containerfile FROM is pinned by digest, so the tag plus the build target plus the pinned FROM is reproducible, and --pull=never makes a missing image a loud error instead of a registry lookup.

This ticket runs the build ticket's plan after it merges; a failing case goes back as A2A-003 with its output, never fixed here.

## Scope

**In**

- touches: none (read-only run on origin/main; the run output goes by script to ~/.local/state/zenith/log/YYYY/MM/ with frontmatter)
- touches (generated, written only by work-order.sh start/submit/done, never by hand or git add): this ticket file and its archive path; work-orders/INDEX.md and the parent epic README.md are ignored generated views
- step: in your own detached worktree of origin/main run TP-1, TP-2, TP-3 of the plan exactly as written; record each with work-order.sh evidence
- tool: cmd:git, cmd:jq, cmd:make, cmd:podman, cmd:gh - fallback: missing on the host: stop with ENV-MISSING naming it; gh or GitHub down: retry 3 times, then stop with A2A-003 and its output

**Out - non-goals**

- writing or changing code: a failing case goes back as A2A-003 with its output
- waiting on CI or merging: push, open the PR, write the result, leave (ORD-0542 O2)
- any file not named under In: stop with DESIGN-GAP and hand it back to infra-design (ORD-0548, item 30)

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [ ] `AC-H1` *(human)* TP-1 and TP-2: the skill suite passes with case 310
  - check: `bash claude/skills/work-order/testing/run-tests.sh` exit 0 expect /all cases passed/
- [ ] `AC-H2` *(human)* TP-3: template, parser and schema agree
  - check: `make -C claude/workflow test-plan` exit 0 expect /ok local image form valid/

## Test plan

_Test plan from claude/workflow/templates/test-plan.md, shaped by claude/workflow/schemas/test-plan.schema.json. The tester runs exactly these cases and nothing else._

**Scope under test**

work-order.sh start's test-plan gate (wo_require_test_plan in claude/skills/work-order/scripts/lib/wo.sh) and the test-plan schema and template, for the local-image isolation form of RR-orch-18

**Cases**

- `TP-1`
  - intent: a plan on a locally built image by tag, with its build target and a digest-pinned Containerfile FROM, must start; a raw localhost digest, a missing build or containerfile, an unpinned FROM, and a podman run without --pull=never must each be refused by name, or plans keep breaking every time the image is rebuilt (log 20261016-080957-t21e-cards-uat-digest.txt)
  - command: `bash claude/skills/work-order/testing/run-tests.sh 2>&1 | sed -n '/310-local-image-plan.sh/,/checks, [0-9]* failed/p'`
  - expected: exit 0; the block ends with `0 failed` and contains the error codes test_plan_local_digest, test_plan_local_no_build, test_plan_local_from_unpinned and test_plan_local_pull
- `TP-2`
  - intent: the case is only proved if the whole skill suite still passes with it, since the gate change touches every test ticket
  - command: `bash claude/skills/work-order/testing/run-tests.sh | tail -1`
  - expected: exit 0; the last line starts with `all cases passed:`
- `TP-3`
  - intent: the template, work-order's parser and the schema must agree on both isolation forms (O-10)
  - command: `make -C claude/workflow test-plan`
  - expected: exit 0; prints `ok  local image form valid`, `ok  rejects a localhost digest` and `ok  rejects a localhost image with no build`

**Isolation**

- runtime: podman
- image: `localhost/work-order-test:1`
- build: `bash claude/skills/work-order/testing/run-tests.sh`
- containerfile: `claude/skills/work-order/testing/Containerfile`

**Out of scope - CI covers**

- the full claude/workflow suite and the skill gates: CI runs them

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
