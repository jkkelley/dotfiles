---
{
  "id": "WO-20261016-e297",
  "slug": "work-order-sh-approve-code-dir-dir-resolves-step",
  "title": "work-order.sh approve --code-dir DIR resolves step and AC tools in the checkout of the ticket repo, not the ticket project",
  "type": "feature",
  "status": "ready",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T09:43:31+00:00",
  "parent": "WO-20261016-fb0c",
  "branch": null,
  "pr": null,
  "closed": null,
  "approval": {
    "via": "override",
    "reason": "infra-design11 cut for ORD-0932-next Q2 and the ORD-0830 RR-orch-14 DESIGN-GAPs; design approvals ruled done, ORD-0550 O4",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [
    "WO-20261016-9c09"
  ],
  "blocks": [
    "WO-20261016-2eb1",
    "WO-20261016-1099"
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
      "command": "grep -c -- '--code-dir) ' claude/skills/work-order/scripts/work-order.sh",
      "exit": 0,
      "expect": "^1$"
    },
    {
      "index": 3,
      "command": "bash -c '! git diff --name-only origin/main...HEAD | grep -vE \"^(work-orders/.*|claude/skills/work-order/scripts/work-order[.]sh|claude/skills/work-order/testing/cases/370-approve-code-dir[.]sh)$\"'",
      "exit": 0,
      "expect": null
    }
  ],
  "provides": [
    "claude/skills/work-order/testing/cases/370-approve-code-dir.sh"
  ]
}
---

# WO-20261016-e297 - work-order.sh approve --code-dir DIR resolves step and AC tools in the checkout of the ticket repo, not the ticket project

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

approve resolves make targets and scripts against the ticket project. A business ticket whose code lives in ypli-01-src or ypconsult-01-src names targets of that repo Makefile, so every such ticket refuses: bash ~/dotfiles/claude/skills/work-order/scripts/work-order.sh approve --project <business worktree> --id WO-20261016-e351 --no-lavish --reason x -> error: tool_missing lint (evidence seats/yp-design6.result.json tool_gap). Design seats work around it with an old pinned copy that has no tool check, which is the gate silently off.

## Owner words

> if the task or job needs tools, the architect has a design agent build that shit out before the ticket goes in, thats a prereq for the ticket ready then, you feel me? (item 30)

> so its re-usable, add to it, makefiles, dont' be a crackhead and one off shit all the time, if we need to do so (item 30)

## Context

DESIGN-GAP work-order.sh approve cross-repo: dotfiles work-order.sh 2.3.0 approve resolves make targets against the ticket project (business), not the code repo, so every ypli/ypconsult code ticket refuses. Cut a tooling ticket so approve resolves tools in the code repo named by the ticket (repo field), ordered after 2d5b and 86b9 (same file).

Fixed by this design: approve gains --code-dir DIR. When the ticket .repo (from the ticket repo field ticket this depends on) is set: --code-dir is required, else exit 2 code_dir_required naming the repo; DIR must be a git checkout whose origin remote, normalized from git@github.com:O/R(.git) or https://github.com/O/R(.git) to O/R, equals .repo, else exit 3 code_dir_mismatch printing both. Tools then resolve in DIR exactly as today in the project: origin/main when DIR has it, else HEAD, else the working tree (tool_ref, tool_cat, make_has_target and the bash path check take the tool root instead of $project). When .repo is null: --code-dir is refused with exit 2 code_dir_without_repo, and resolution is unchanged. Breadcrumb at require_tools_resolve citing the yp-design6 repro.

Rejected: guessing ~/projects/<name> from .repo, because a guessed checkout can be stale or another clone and the gate would pass on the wrong tree; rejected: skipping the tool check for cross-repo tickets, because it is the gate silently off (ORD-0555).

## Scope

**In**

- touches: claude/skills/work-order/scripts/work-order.sh (approve --code-dir; tool root in tool_ref, tool_cat, make_has_target, resolve_tool; usage line; breadcrumb)
- touches: claude/skills/work-order/testing/cases/370-approve-code-dir.sh (new: a project with no Makefile and a code repo fixture whose origin is a fake github URL and whose Makefile has target lint; ticket with .repo and AC check make lint: approve without --code-dir exit 2 code_dir_required; with a checkout whose origin differs exit 3 code_dir_mismatch; with the right checkout -> ready; ssh and https origin forms both match; .repo null with --code-dir exit 2 code_dir_without_repo; .repo null without --code-dir behaves as case 280)
- touches (generated, written only by work-order.sh start/submit/done, never by hand or git add): this ticket file and its archive path; work-orders/INDEX.md and the parent epic README.md are ignored generated views
- step: branch from origin/main in your own worktree after the ticket it depends on merged; write exactly the two files above to the design in Context
- step: run `bash claude/skills/work-order/testing/run-tests.sh` and the AC checks; commit 'feat(work-order): approve --code-dir resolves tools in the ticket code repo' with the ticket id; the PR body ends with 'Bump: work-order=minor'
- tool: cmd:git, cmd:jq, cmd:podman, cmd:gh - fallback: missing on the host: stop with ENV-MISSING naming it; gh or GitHub down: retry 3 times, then FB-003 (push with git, park the PR step with a note) and A2A-003 with the output
- tool: path:claude/skills/work-order/testing/run-tests.sh - on main; fallback: its image fails to build: stop with ENV-MISSING podman

**Out - non-goals**

- re-approving business tickets: business design seats do that with --code-dir after merge
- SKILL.md, references/lifecycle.md and testing/SOP.md: WO-20261016-2eb1 owns them and runs after this ticket; no doc edits here
- work-orders/INDEX.md and epic READMEs by hand or by git add: they are ignored generated views
- waiting on CI or merging: push, open the PR, write the result, leave (ORD-0542 O2)
- any file not named under In: stop with DESIGN-GAP and hand it back to infra-design (ORD-0548, item 30)

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [ ] `AC-H1` *(human)* case 370 and the whole skill suite pass
  - check: `bash claude/skills/work-order/testing/run-tests.sh` exit 0 expect /all cases passed/
- [ ] `AC-H2` *(human)* approve takes --code-dir
  - check: `grep -c -- '--code-dir) ' claude/skills/work-order/scripts/work-order.sh` exit 0 expect /^1$/
- [ ] `AC-H3` *(human)* the diff holds only In files and generated work-orders files
  - check: `bash -c '! git diff --name-only origin/main...HEAD | grep -vE "^(work-orders/.*|claude/skills/work-order/scripts/work-order[.]sh|claude/skills/work-order/testing/cases/370-approve-code-dir[.]sh)$"'` exit 0

## Test plan

_Test plan from claude/workflow/templates/test-plan.md, shaped by claude/workflow/schemas/test-plan.schema.json. The tester runs exactly these cases and nothing else._

**Scope under test**

work-order.sh approve --code-dir: tools resolve in the code checkout named by the ticket repo field

**Cases**

- `TP-1`
  - intent: the new case proves the change; a red block means the verb ships broken to every seat that calls it
  - command: `bash claude/skills/work-order/testing/run-tests.sh 2>&1 | sed -n '/370-approve-code-dir.sh/,/checks, [0-9]* failed/p'`
  - expected: exit 0; the block ends with `0 failed`
- `TP-2`
  - intent: the change must not break any other work-order verb
  - command: `bash claude/skills/work-order/testing/run-tests.sh | tail -1`
  - expected: exit 0; the last line starts with `all cases passed:`
- `TP-3`
  - intent: dev gate on real data: a ticket whose project has no Makefile names its code repo (this dotfiles checkout) and approve resolves make spec-check there; without --code-dir it refuses code_dir_required instead of the misleading tool_missing (yp-design6 repro: tool_missing lint)
  - command: `bash -c 'd=$(mktemp -d) && git -C $d init -q && id=$(bash claude/skills/work-order/scripts/work-order.sh new --project $d --top-level --title t --type chore --problem p --out o --owner-words w --context c --repo jkkelley/dotfiles --ac a --ac-check "make spec-check" --ac-exit 0 --json | jq -r .id) && { bash claude/skills/work-order/scripts/work-order.sh approve --project $d --id $id --no-lavish --reason tp3 2>&1 | grep -o code_dir_required; bash claude/skills/work-order/scripts/work-order.sh approve --project $d --id $id --code-dir "$PWD" --no-lavish --reason tp3 --json | jq -r .status; }; rm -rf $d'`
  - expected: exit 0; prints `code_dir_required` then `ready`

**Isolation**

- runtime: podman
- image: `localhost/work-order-test:1`
- build: `bash claude/skills/work-order/testing/run-tests.sh`
- containerfile: `claude/skills/work-order/testing/Containerfile`

**Out of scope - CI covers**

- the full skill suite in skill-pr-gate

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
