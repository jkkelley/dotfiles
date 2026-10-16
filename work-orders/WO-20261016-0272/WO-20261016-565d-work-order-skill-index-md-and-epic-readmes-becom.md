---
{
  "id": "WO-20261016-565d",
  "slug": "work-order-skill-index-md-and-epic-readmes-becom",
  "title": "work-order skill: INDEX.md and epic READMEs become untracked build outputs, regenerated on demand",
  "type": "feature",
  "status": "in-progress",
  "priority": "p0",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T06:05:12+00:00",
  "parent": "WO-20261016-0272",
  "branch": "feat/work-order-skill-index-md-and-epic-readmes-becom",
  "pr": null,
  "closed": null,
  "approval": {
    "via": "override",
    "reason": "architect ruled design approvals done, ORD-0550 O4",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [
    "WO-20261016-6ef4"
  ],
  "blocks": [
    "WO-20261016-1844",
    "WO-20261016-1c04"
  ]
}
---

# WO-20261016-565d - work-order skill: INDEX.md and epic READMEs become untracked build outputs, regenerated on demand

## Contents

- Problem
- Scope
- Degrees of freedom
- Acceptance criteria
- Test plan
- Assumptions
- Open questions
- Notes
- Outcome

## Problem

ORD-0554 U1: "generated work-order views stop being tracked. work-order.sh writes INDEX.md and epic README.md as build outputs, gitignored; every verb that reads them (next, tree, reindex, any reader) regenerates on demand, so a fresh clone works with no step. reindex --check stays in CI as a generate-and-validate check (layout, cycles, loose top-level WO files). Ticket PRs then touch only their own ticket file, so two parallel tickets can never conflict on a shared file (rule 19)." ORD-0554 U3: "Update SKILL.md where it calls INDEX.md committed or says it rides the ticket PR." Evidence: F11 and ORD-0553 R7 - dotfiles #170 #178 #185 conflicted only on work-orders/INDEX.md and were cleared by break glass (log/2026/10/20261016-055223-breakglass-index-regen.md).

## Scope

**In**

- touches: claude/skills/work-order/scripts/work-order.sh
- touches: claude/skills/work-order/scripts/lib/wo.sh
- touches: claude/skills/work-order/SKILL.md
- touches: claude/skills/work-order/references/lifecycle.md
- touches: claude/skills/work-order/testing/SOP.md
- touches: claude/skills/work-order/testing/cases/290-generated-views-untracked.sh
- step: next, tree, show and every reader regenerate INDEX.md and epic README.md before reading when either is missing or older than any ticket file
- step: reindex --check: generate into a temp dir and validate layout, cycles and loose top-level WO files; it no longer fails because the committed INDEX.md differs or is absent
- step: done, cancel, link: stop staging INDEX.md and README.md (`git add` only the ticket files they move)
- step: SKILL.md and lifecycle.md: replace every statement that INDEX.md is committed or rides the ticket PR with: generated, gitignored, rebuilt on demand
- step: case 290: a fresh clone with no INDEX.md answers `next` and `tree`; `reindex --check` passes with INDEX.md absent and fails on a loose top-level ticket
- step: run `bash claude/skills/work-order/testing/run-tests.sh`
- step: PR body ends with `Bump: work-order=minor`
- tool: path:claude/skills/work-order/testing/run-tests.sh - on main; fallback: missing: stop with ENV-MISSING naming it
- tool: cmd:git - on main; fallback: missing: stop with ENV-MISSING naming it

**Out - non-goals**

- work-orders/INDEX.md by hand: work-order.sh writes it, and the reindex Action is owned by merge-port-build (F11, ORD-0545 O1)
- waiting on CI or merging: push, open the PR, write the result, leave (ORD-0542 O2)
- any file not named under In: stop with DESIGN-GAP and hand it back to infra-design (ORD-0548, item 30)

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [x] `AC-H1` *(human)* `bash claude/skills/work-order/testing/run-tests.sh` exits 0 and its output matches /290-generated-views-untracked.*ok/ (proof: command, exit code and output pasted by work-order.sh evidence; ORD-0552 O2)
  - observed `2026-10-16` bash claude/skills/work-order/testing/run-tests.sh exit 0; output: '290-generated-views-untracked.sh ... ok reindex --check fails on a loose top-level ticket'; all cases passed: 325 checks across 25 case files
- [x] `AC-H2` *(human)* `grep -c 'INDEX.md.*committed' claude/skills/work-order/SKILL.md` exits 1 and its output matches /^0$/ (proof: command, exit code and output pasted by work-order.sh evidence; ORD-0552 O2)
  - observed `2026-10-16` grep -c 'INDEX.md.*committed' claude/skills/work-order/SKILL.md exit 1; output: 0

## Test plan

_Test plan from claude/workflow/templates/test-plan.md, shaped by claude/workflow/schemas/test-plan.schema.json. The tester runs exactly these cases and nothing else._

**Scope under test**

claude/skills/work-order generated views: on-demand regeneration and reindex --check

**Cases**

- `TP-1`
  - intent: a fresh clone must work with no step (ORD-0554 U1)
  - command: `bash claude/skills/work-order/testing/run-tests.sh`
  - expected: exit 0; case 290 prints ok: next and tree work with INDEX.md absent
- `TP-2`
  - intent: CI still catches a broken layout
  - command: `bash claude/skills/work-order/testing/run-tests.sh`
  - expected: exit 0; case 290 prints ok: reindex --check fails on a loose top-level ticket

**Isolation**

- runtime: podman
- image: `docker.io/library/debian:bookworm-slim@sha256:3783cc01769c7b2b1b83a5c5ad96c815348e28ed7da68e2e3687004faa906251` (debian:bookworm-slim, base of localhost/dotfiles-workflow-test:1)

**Out of scope - CI covers**

- skill-pr-gate runs the full work-order suite

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
