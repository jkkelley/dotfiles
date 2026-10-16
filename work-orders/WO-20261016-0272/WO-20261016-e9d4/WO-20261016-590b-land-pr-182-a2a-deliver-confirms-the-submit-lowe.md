---
{
  "id": "WO-20261016-590b",
  "slug": "land-pr-182-a2a-deliver-confirms-the-submit-lowe",
  "title": "Land PR 182: a2a-deliver confirms the submit, lowercase enter retried once",
  "type": "chore",
  "status": "ready",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T06:04:43+00:00",
  "parent": "WO-20261016-e9d4",
  "branch": null,
  "pr": null,
  "closed": null,
  "approval": {
    "via": "override",
    "reason": "architect ruled design approvals done, ORD-0550 O4",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [],
  "blocks": [
    "WO-20261016-dd1f",
    "WO-20261016-39e6",
    "WO-20261016-24b5",
    "WO-20261016-1cd0"
  ]
}
---

# WO-20261016-590b - Land PR 182: a2a-deliver confirms the submit, lowercase enter retried once

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

ORD-0615 O2, evidence 06:12Z: orchestrator input sat unsubmitted after Enter twice; lowercase enter submitted it. Branch fix/a2a-send-confirm-submit (PR 182, commit 06eff91) carries the fix and its fake-herdr test; its `bump intent` check is red (run 38857069784) although the PR touches no skill, and the branch predates main 6c2fbf9.

## Scope

**In**

- touches: claude/workflow/a2a-guard/a2a-deliver.sh
- touches: claude/workflow/a2a-guard/README.md
- touches: claude/workflow/a2a-guard/config.json
- touches: claude/workflow/a2a-guard/tests/fake-herdr
- touches: claude/workflow/a2a-guard/tests/test_a2a_guard.sh
- step: `git fetch origin && git switch fix/a2a-send-confirm-submit && git rebase origin/main` (conflicts only in work-orders/: resolve with `bash claude/skills/work-order/scripts/work-order.sh reindex`)
- step: run `make -C claude/workflow a2a-guard-test`
- step: `git push --force-with-lease origin fix/a2a-send-confirm-submit`
- step: `gh pr view 182 --json statusCheckRollup` after the rerun; if `bump intent` is still FAILURE, write its log tail to the result blockers with status code A2A-003 and stop; edit nothing else
- tool: make:claude/workflow/a2a-guard/a2a-guard.mk:a2a-guard-test - on main; fallback: target missing or failing to parse: stop with DESIGN-GAP naming the target; no hand-run substitute
- tool: cmd:gh - on main; fallback: gh or GitHub down: retry 3 times, then stop with A2A-003 and the gh error in the result blockers

**Out - non-goals**

- changing a2a-deliver.sh behaviour: the fix is already on the branch
- work-orders/INDEX.md by hand: work-order.sh writes it, and the reindex Action is owned by merge-port-build (F11, ORD-0545 O1)
- waiting on CI or merging: push, open the PR, write the result, leave (ORD-0542 O2)
- any file not named under In: stop with DESIGN-GAP and hand it back to infra-design (ORD-0548, item 30)

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [ ] `AC-H1` *(human)* `make -C claude/workflow a2a-guard-test` exits 0 and prints the A2A-DELIVERED-RETRIED case as ok (proof: command, exit code and output pasted by work-order.sh evidence; ORD-0552 O2)
- [ ] `AC-H2` *(human)* `git log --oneline origin/main..origin/fix/a2a-send-confirm-submit` lists 06eff91's change rebased, one commit (proof: command, exit code and output pasted by work-order.sh evidence; ORD-0552 O2)
- [ ] `AC-H3` *(human)* `gh pr view 182 --json mergeable -q .mergeable` prints MERGEABLE (proof: command, exit code and output pasted by work-order.sh evidence; ORD-0552 O2)

## Test plan

_Test plan from claude/workflow/templates/test-plan.md, shaped by claude/workflow/schemas/test-plan.schema.json. The tester runs exactly these cases and nothing else._

**Scope under test**

claude/workflow/a2a-guard/a2a-deliver.sh submit confirmation against tests/fake-herdr

**Cases**

- `TP-1`
  - intent: an Enter that is not taken leaves the order unsubmitted forever (06:12Z)
  - command: `make -C claude/workflow a2a-guard-test`
  - expected: exit 0; the case where the first Enter is not taken prints ok with code A2A-DELIVERED-RETRIED
- `TP-2`
  - intent: an input box that stays full after the retry must report, never claim delivery
  - command: `make -C claude/workflow a2a-guard-test`
  - expected: exit 0; the case printing A2A-UNCONFIRMED is ok

**Isolation**

- runtime: podman
- image: `docker.io/library/debian:bookworm-slim@sha256:3783cc01769c7b2b1b83a5c5ad96c815348e28ed7da68e2e3687004faa906251` (debian:bookworm-slim, base of localhost/dotfiles-workflow-test:1)

**Out of scope - CI covers**

- a2a-lint and the full workflow suite

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
