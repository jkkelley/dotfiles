---
{
  "id": "WO-20261016-1c04",
  "slug": "make-wo-untrack-generated-repo-untrack-the-gener",
  "title": "make wo-untrack-generated REPO=: untrack the generated work-order views, plan before apply",
  "type": "feature",
  "status": "in-progress",
  "priority": "p0",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T06:05:19+00:00",
  "parent": "WO-20261016-0272",
  "branch": "feat/make-wo-untrack-generated-repo-untrack-the-gener",
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
    "WO-20261016-565d"
  ],
  "blocks": [
    "WO-20261016-de15",
    "WO-20261016-2ffe"
  ]
}
---

# WO-20261016-1c04 - make wo-untrack-generated REPO=: untrack the generated work-order views, plan before apply

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

ORD-0554 U2: "migration verb make wo-untrack-generated REPO=<dir>: git rm --cached the generated files, add the .gitignore lines, run reindex, open the PR; idempotent; run for dotfiles and business (ypconsult has none). Plan shown before apply, rollback is git revert." ORD-0556 O1: generic, config-driven, callable from any repo by Make with VAR=value.

## Scope

**In**

- touches: scripts/wo-untrack-generated.sh
- touches: scripts/tests/test_wo_untrack_generated.sh
- touches: Makefile
- step: wo-untrack-generated.sh --repo DIR [--apply] [--branch chore/wo-untrack-generated]: plan prints one line per tracked generated file (`git -C DIR ls-files work-orders/INDEX.md` and every `work-orders/**/README.md`) as `UNTRACK <path>` and each missing .gitignore line (`/work-orders/INDEX.md`, `/work-orders/**/README.md`) as `IGNORE <line>`; nothing to do prints `WO-UNTRACK-NOCHANGE` and exits 0
- step: --apply: `git -C DIR switch -c <branch> origin/main`, `git rm --cached -q` each file, append the missing lines, `bash <dotfiles>/claude/skills/work-order/scripts/work-order.sh reindex --project DIR`, commit `chore(work-orders): untrack generated views (ORD-0554)`, push, `gh pr create --fill`; print `ROLLBACK git -C DIR revert <sha>`
- step: root Makefile: `wo-untrack-generated: ## make wo-untrack-generated REPO=<dir> [APPLY=1]`
- step: test: temp repo with a bare remote and a stub gh; run `make -C claude/workflow image && podman run --rm --network=none --userns=keep-id -v "$PWD:/work:Z" -w /work -e HOME=/tmp localhost/dotfiles-workflow-test:1 bash -c 'bash scripts/tests/test_wo_untrack_generated.sh'`
- step: UAT after merge of w2: `make wo-untrack-generated REPO=$HOME/dotfiles` (plan), then `APPLY=1`; the same for `REPO=$HOME/projects/business-yp-consulting`
- tool: path:claude/workflow/tests/container/Containerfile - on main; fallback: no fallback permitted (dotfiles Rule 14, never the host): podman or the image missing stops the node with ENV-MISSING podman
- tool: path:claude/skills/work-order/scripts/work-order.sh - on main; fallback: no fallback: work-order.sh missing or failing stops with DESIGN-GAP
- tool: cmd:gh - on main; fallback: gh or GitHub down: retry 3 times, then stop with A2A-003 and the gh error in the result blockers

**Out - non-goals**

- work-orders/INDEX.md by hand: work-order.sh writes it, and the reindex Action is owned by merge-port-build (F11, ORD-0545 O1)
- waiting on CI or merging: push, open the PR, write the result, leave (ORD-0542 O2)
- any file not named under In: stop with DESIGN-GAP and hand it back to infra-design (ORD-0548, item 30)

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [x] `AC-H1` *(human)* `make -C claude/workflow image && podman run --rm --network=none --userns=keep-id -v "$PWD:/work:Z" -w /work -e HOME=/tmp localhost/dotfiles-workflow-test:1 bash -c 'bash scripts/tests/test_wo_untrack_generated.sh'` exits 0 and its output matches /ok plan writes nothing/ (proof: command, exit code and output pasted by work-order.sh evidence; ORD-0552 O2)
  - observed `2026-10-16` command: make -C claude/workflow image && podman run ... bash scripts/tests/test_wo_untrack_generated.sh; exit 0; output: ok plan writes nothing / ok apply untracks INDEX.md and READMEs and adds the ignore lines / ok a second apply is WO-UNTRACK-NOCHANGE
- [x] `AC-H2` *(human)* `make -C claude/workflow image && podman run --rm --network=none --userns=keep-id -v "$PWD:/work:Z" -w /work -e HOME=/tmp localhost/dotfiles-workflow-test:1 bash -c 'bash scripts/tests/test_wo_untrack_generated.sh'` exits 0 and its output matches /ok a second apply is WO-UNTRACK-NOCHANGE/ (proof: command, exit code and output pasted by work-order.sh evidence; ORD-0552 O2)
  - observed `2026-10-16` command: make -C claude/workflow image && podman run ... bash scripts/tests/test_wo_untrack_generated.sh; exit 0; output: ok plan writes nothing / ok apply untracks INDEX.md and READMEs and adds the ignore lines / ok a second apply is WO-UNTRACK-NOCHANGE

## Test plan

_Test plan from claude/workflow/templates/test-plan.md, shaped by claude/workflow/schemas/test-plan.schema.json. The tester runs exactly these cases and nothing else._

**Scope under test**

scripts/wo-untrack-generated.sh plan, apply and idempotence on a temp repo

**Cases**

- `TP-1`
  - intent: a plan must be shown before apply (item 40)
  - command: `make -C claude/workflow image && podman run --rm --network=none --userns=keep-id -v "$PWD:/work:Z" -w /work -e HOME=/tmp localhost/dotfiles-workflow-test:1 bash -c 'bash scripts/tests/test_wo_untrack_generated.sh'`
  - expected: exit 0; prints `ok  plan writes nothing`
- `TP-2`
  - intent: the migration lands the end state in one run
  - command: `make -C claude/workflow image && podman run --rm --network=none --userns=keep-id -v "$PWD:/work:Z" -w /work -e HOME=/tmp localhost/dotfiles-workflow-test:1 bash -c 'bash scripts/tests/test_wo_untrack_generated.sh'`
  - expected: exit 0; prints `ok  apply untracks INDEX.md and READMEs and adds the ignore lines`
- `TP-3`
  - intent: idempotent from any state (item 28)
  - command: `make -C claude/workflow image && podman run --rm --network=none --userns=keep-id -v "$PWD:/work:Z" -w /work -e HOME=/tmp localhost/dotfiles-workflow-test:1 bash -c 'bash scripts/tests/test_wo_untrack_generated.sh'`
  - expected: exit 0; prints `ok  a second apply is WO-UNTRACK-NOCHANGE`

**Isolation**

- runtime: podman
- image: `docker.io/library/debian:bookworm-slim@sha256:3783cc01769c7b2b1b83a5c5ad96c815348e28ed7da68e2e3687004faa906251` (debian:bookworm-slim, base of localhost/dotfiles-workflow-test:1)

**Out of scope - CI covers**

- the full scripts suite

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
