---
{
  "id": "WO-20261016-86b9",
  "slug": "work-order-start-accepts-a-test-plan-on-a-locall",
  "title": "work-order start accepts a test plan on a locally built image by tag, with its build command and a digest-pinned Containerfile FROM; refuses a raw localhost digest (RR-orch-18)",
  "type": "feature",
  "status": "ready",
  "priority": "p0",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T09:05:42+00:00",
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
  "depends_on": [],
  "blocks": [
    "WO-20261016-d990",
    "WO-20261016-8cce",
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
      "command": "grep -c test_plan_local_digest claude/skills/work-order/scripts/lib/wo.sh",
      "exit": 0,
      "expect": "^[1-9]"
    },
    {
      "index": 3,
      "command": "make -C claude/workflow test-plan",
      "exit": 0,
      "expect": "ok  rejects a localhost digest"
    },
    {
      "index": 4,
      "command": "bash -c '! git diff --name-only origin/main...HEAD | grep -vE \"^(work-orders/|claude/skills/work-order/scripts/lib/wo[.]sh|claude/skills/work-order/testing/cases/310-local-image-plan[.]sh|claude/workflow/schemas/test-plan[.]schema[.]json|claude/workflow/templates/test-plan[.]md|claude/workflow/tests/unit/test_test_plan[.]sh)$\"'",
      "exit": 0,
      "expect": null
    }
  ],
  "provides": [
    "claude/skills/work-order/testing/cases/310-local-image-plan.sh"
  ]
}
---

# WO-20261016-86b9 - work-order start accepts a test plan on a locally built image by tag, with its build command and a digest-pinned Containerfile FROM; refuses a raw localhost digest (RR-orch-18)

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

start's test-plan gate (wo_require_test_plan, claude/skills/work-order/scripts/lib/wo.sh line 389) accepts only image: <name>@sha256:<64 hex>. For the line's own image localhost/dotfiles-workflow-test:1 that forces a localhost digest into every plan, and the digest changes on every rebuild, so plans stop resolving (UAT cards run on 0a6832bb). The gate must accept the local-image form and refuse a raw localhost digest.

## Owner words

> Pin every version. No floating tags. (dotfiles CLAUDE.md Rule 15)

> i want work scoped so small a fuck ape could do, testing the same way with test plans and scripts, every node has what it fucking needs up front, not later (Design principles 101 item 30)

## Context

Architect ruling RR-orch-18, 2026-10-16: a locally built image is never pinned by digest. Evidence: ~/.local/state/zenith/log/2026/10/20261016-080957-t21e-cards-uat-digest.txt (UAT cards suite run on pinned image 0a6832bb, image id f4d2d4c03c76): a localhost digest names one build on one machine; every rebuild of claude/workflow/tests/container/Containerfile mints a new digest, so a plan pinned to it stops resolving (11 plans pinned 0a6832bb, 2 still live as drafts). What Rule 15 protects is the base: the Containerfile FROM is pinned by digest, so the tag plus the build target plus the pinned FROM is reproducible, and --pull=never makes a missing image a loud error instead of a registry lookup.

Local-image isolation form, fixed by this design (no freedom): the Isolation block carries four lines: '- runtime: podman', '- image: `localhost/<name>:<tag>`', '- build: `<command that builds that tag>`' (for example `make -C claude/workflow image`), '- containerfile: `<project-relative path>`'. The registry form is unchanged: '- image: `<registry>/<name>@sha256:<64 hex>` (<tag>)' where registry is not localhost.

Gate rules, in this order, each a ps_die $PS_VALIDATION with the named error: (1) image matches ^localhost/.*@sha256: -> test_plan_local_digest 'a locally built image is never pinned by digest: use the tag with build: and containerfile: (RR-orch-18)'; (2) image matches ^localhost/ and build or containerfile is empty -> test_plan_local_no_build; (3) containerfile missing under the project, or any FROM line in it not matching @sha256:[0-9a-f]{64} -> test_plan_local_from_unpinned; (4) any case command containing 'podman run' without '--pull=never' -> test_plan_local_pull; (5) otherwise the existing check: runtime podman and, for a non-localhost image, a digest -> test_plan_not_isolated. Commands that do not call podman run directly (make targets, run-tests.sh) are accepted as they are.

Schema: claude/workflow/schemas/test-plan.schema.json isolation gains optional build and containerfile (strings, minLength 1); image becomes: if it starts with localhost/ then pattern ^localhost/[a-z0-9._/-]+:[A-Za-z0-9._-]+$ and build and containerfile required; else the existing digest pattern and not ^localhost/. Parser: wo_test_plan_json's isolation line regex ^- (runtime|image): becomes ^- (runtime|image|build|containerfile):. Template: one italic line under **Isolation** naming the local form, so the parser ignores it.

Live plans pinned to 0a6832bb (WO-20261016-c065 - Test B24 - suite reply-jitter on main after the build merges and WO-20261016-dc6b - Test B25 - suite reply-look on main after the build merges, both draft) were amended to the local form by infra-design8 with work-order.sh amend --test-plan-file in the chore PR that cut this ticket; nothing for this ticket to amend. Done tickets keep their record. Out of reach of this ticket: SKILL.md, testing/SOP.md (WO-20261016-377c owns them now) and work-order.sh help text (the stale-merged ticket owns that file now); the docs follow-up ticket depends on all three.

## Scope

**In**

- touches: claude/skills/work-order/scripts/lib/wo.sh (wo_test_plan_json isolation regex; wo_require_test_plan rules 1 to 5; a breadcrumb comment at the change citing RR-orch-18 and the evidence log)
- touches: claude/skills/work-order/testing/cases/310-local-image-plan.sh (new, modelled on 240-test-plan-gate.sh: a fixture Containerfile with a pinned FROM and one with FROM debian:bookworm-slim; asserts start passes the local form, and refuses with exit 3 and .error test_plan_local_digest, test_plan_local_no_build, test_plan_local_from_unpinned, test_plan_local_pull)
- touches: claude/workflow/schemas/test-plan.schema.json (isolation build, containerfile, image if/then/else)
- touches: claude/workflow/templates/test-plan.md (one italic line under **Isolation**)
- touches: claude/workflow/tests/unit/test_test_plan.sh (three checks printing 'ok local image form valid', 'ok rejects a localhost digest', 'ok rejects a localhost image with no build')
- touches (generated, written only by work-order.sh start/submit/done, never by hand or git add): this ticket file and its archive path; work-orders/INDEX.md and the parent epic README.md are ignored generated views
- step: branch from origin/main in your own worktree; edit exactly the five files above to the rules in Context
- step: run `bash claude/skills/work-order/testing/run-tests.sh` and `make -C claude/workflow test-plan`, then the AC checks; CI runs the rest
- step: commit 'feat(work-order): start accepts a locally built test image by tag, refuses a localhost digest (RR-orch-18)' with the ticket id; the PR body ends with the line 'Bump: work-order=minor'
- tool: cmd:git, cmd:jq, cmd:make, cmd:podman, cmd:gh - fallback: missing on the host: stop with ENV-MISSING naming it; gh or GitHub down: retry 3 times, then stop with A2A-003 and its output
- tool: make:claude/workflow/Makefile:test-plan - on main; fallback: missing: stop with DESIGN-GAP naming it
- tool: path:claude/skills/work-order/testing/run-tests.sh - on main; fallback: its image fails to build: stop with ENV-MISSING podman

**Out - non-goals**

- amending any ticket: c065 and dc6b were amended in the chore PR; done tickets are never amended
- claude/skills/work-order/SKILL.md, testing/SOP.md and scripts/work-order.sh: other tickets own them now
- claude/workflow/Makefile --pull=never: its own ticket, after WO-20261016-f4a0
- work-orders/INDEX.md and epic READMEs by hand or by git add: they are ignored generated views
- waiting on CI or merging: push, open the PR, write the result, leave (ORD-0542 O2)
- any file not named under In: stop with DESIGN-GAP and hand it back to infra-design (ORD-0548, item 30)

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [ ] `AC-H1` *(human)* case 310 passes
  - check: `bash claude/skills/work-order/testing/run-tests.sh` exit 0 expect /all cases passed/
- [ ] `AC-H2` *(human)* the gate names a localhost digest by its own error
  - check: `grep -c test_plan_local_digest claude/skills/work-order/scripts/lib/wo.sh` exit 0 expect /^[1-9]/
- [ ] `AC-H3` *(human)* template, parser and schema agree on both forms
  - check: `make -C claude/workflow test-plan` exit 0 expect /ok rejects a localhost digest/
- [ ] `AC-H4` *(human)* the diff holds only In files and generated work-orders files
  - check: `bash -c '! git diff --name-only origin/main...HEAD | grep -vE "^(work-orders/|claude/skills/work-order/scripts/lib/wo[.]sh|claude/skills/work-order/testing/cases/310-local-image-plan[.]sh|claude/workflow/schemas/test-plan[.]schema[.]json|claude/workflow/templates/test-plan[.]md|claude/workflow/tests/unit/test_test_plan[.]sh)$"'` exit 0

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
