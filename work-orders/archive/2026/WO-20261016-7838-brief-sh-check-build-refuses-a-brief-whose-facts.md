---
{
  "id": "WO-20261016-7838",
  "slug": "brief-sh-check-build-refuses-a-brief-whose-facts",
  "title": "brief.sh check --build refuses a brief whose facts.worktree is a primary clone; the brief template carries facts.worktree_rule",
  "type": "feature",
  "status": "done",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T10:07:34+00:00",
  "parent": "WO-20261016-4b6c",
  "branch": "feat/brief-sh-check-build-refuses-a-brief-whose-facts",
  "pr": 315,
  "closed": "2026-10-16",
  "approval": {
    "via": "override",
    "reason": "infra-design13 cut for ORD-0830 RR-orch-14; design approvals ruled done, ORD-0550 O4",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [
    "WO-20261016-bcb4"
  ],
  "blocks": [],
  "ac_checks": [
    {
      "index": 1,
      "command": "make -C claude/workflow -f a2a.mk a2a-test",
      "exit": 0,
      "expect": null
    },
    {
      "index": 2,
      "command": "make rolodex-check BASE=origin/main",
      "exit": 0,
      "expect": null
    },
    {
      "index": 3,
      "command": "jq -e '.facts.worktree_rule | test(\"primary clone\")' claude/workflow/templates/a2a/brief.json",
      "exit": 0,
      "expect": null
    },
    {
      "index": 4,
      "command": "git diff --name-only origin/main...HEAD | grep -vE '^(work-orders/.*|claude/workflow/(bin/brief\\.sh|templates/a2a/brief\\.json|tests/unit/test_a2a_brief\\.sh))$'",
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

# WO-20261016-7838 - brief.sh check --build refuses a brief whose facts.worktree is a primary clone; the brief template carries facts.worktree_rule

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

A seat brief names a worktree but nothing stops it naming, or the seat using, the ~/dotfiles primary clone, which is how WO-20261016-efb2 got started there.

## Owner words

> seat dag-t6b ran work-order.sh start inside the ~/dotfiles main clone ... every seat calling ~/dotfiles tools ran stale code (brief BR-20261016-infra-design13, ORD-0830 RR-orch-14)

> worktrees and feature branches with the whole process DAG when getting work (Design principles 101 item 20)

## Context

Order ORD-0830 RR-orch-14, brief BR-20261016-infra-design13 item DESIGN-GAP main clone drift ('a seat brief forbids start in the main clone'). Evidence: ~/.local/state/zenith/breakglass/2026/10/20261016-095436-main-clone-efb2-start-stamp.patch and seats/wr2-feed.result.json (ENV-MISSING on claude/tools/shot while ~/dotfiles sat on feat/dag-state-t6 at c7bd763 for 40+ min). Depends on WO-20261016-8454 (A2A-ST) for file order on brief.sh and brief.json.

Behaviour, fixed. In check_build of claude/workflow/bin/brief.sh, after the ready check: wt = jq -r '.facts.worktree // empty'. When wt is non-empty, is a directory, and git -C wt rev-parse succeeds with realpath of --git-dir equal to realpath of --git-common-dir (a primary clone, not a linked worktree): stderr 'DESIGN-GAP BRIEF facts.worktree WT is a primary clone; a build seat works only in its own git worktree' and exit 3. A path that does not exist yet passes (the seat creates it). claude/workflow/templates/a2a/brief.json: facts gains "worktree_rule": "work only in facts.worktree, a git worktree of your own; never run work-order.sh start, git checkout or git switch in a primary clone such as ~/dotfiles". Breadcrumb at the change names this ticket.

Test cases added to claude/workflow/tests/unit/test_a2a_brief.sh, reusing its ready work-order fixture: (a) facts.worktree = a fixture primary clone: check --build exit 3, stderr has 'is a primary clone'; (b) facts.worktree = a linked worktree of that clone (git worktree add): exit 0; (c) facts.worktree a path that does not exist: exit 0; (d) the template brief.json still validates against brief.schema.json.

## Scope

**In**

- touches: claude/workflow/bin/brief.sh (check_build only, plus breadcrumb)
- touches: claude/workflow/templates/a2a/brief.json (facts.worktree_rule only)
- touches: claude/workflow/tests/unit/test_a2a_brief.sh (cases a to d in Context)
- touches (generated, written only by work-order.sh start/submit/done, never by hand or git add): this ticket file and its archive path; work-orders/INDEX.md and the parent epic README.md are ignored generated views
- step: branch from origin/main in your own git worktree after WO-20261016-8454 merged; make exactly the three edits in Context
- step: run `make -C claude/workflow -f a2a.mk a2a-test` and `make rolodex-check BASE=origin/main` and the AC checks only
- step: commit 'feat(workflow): brief check refuses a primary clone worktree' with the ticket id; no Bump trailer
- tool: make:claude/workflow/a2a.mk:a2a-test - on main; fallback: missing: stop with DESIGN-GAP naming it; image build fails: stop with ENV-MISSING podman
- tool: make:Makefile:rolodex-check - on main; fallback: missing: stop with DESIGN-GAP naming it
- tool: cmd:git, cmd:jq, cmd:make, cmd:podman, cmd:gh - fallback: missing on the host: stop with ENV-MISSING naming it; gh or GitHub down: retry 3 times, then stop with A2A-003 and its output

**Out - non-goals**

- brief.schema.json: facts stays a free object
- any other brief.sh verb
- work-orders/INDEX.md and epic READMEs by hand or by git add; waiting on CI or merging: push, open the PR, write the result, leave
- any file not named under In: stop with DESIGN-GAP

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [x] `AC-H1` *(human)* the a2a suite passes with the worktree cases
  - observed `2026-10-16` check: make -C claude/workflow -f a2a.mk a2a-test exit 0 output: make: Entering directory '/home/luna/worktrees/dotfiles-worktree-rule/claude/workflow' ok template brief is valid ok template result is valid ok result matches its brief ok AC2 brief with no acceptance_criteria is rejected ok brief with an empty acceptance_criteria is rejected ok an AC with no proof_kind is rejected ok an AC with an unknown proof_kind is rejected ok a prose brief is rejected ok AC3 done result with an unticked AC is rejected ok a ticked AC with empty proof is rejected ok a blocked result is not a finished result ok a result that skips a brief AC is rejected against its brief ok the status code map lists A2A-001 to A2A-004, PERM-MISSING and DESIGN-GAP ok a brief carrying A2A-004 is valid ok a draft-0 brief is not valid before migration ok AC1 draft-0 brief migrates and validates ok migration keeps the done token ok an unknown schema has no migration and fails loudly ok brief new from arguments
  - check: `make -C claude/workflow -f a2a.mk a2a-test` exit 0
- [x] `AC-H2` *(human)* every changed script has a rolodex header
  - observed `2026-10-16` check: make rolodex-check BASE=origin/main exit 0 output: python3 scripts/rolodex.py check --root . --base origin/main rolodex-check: 0 script(s) checked, all have headers
  - check: `make rolodex-check BASE=origin/main` exit 0
- [x] `AC-H3` *(human)* the template carries the worktree rule
  - observed `2026-10-16` check: jq -e '.facts.worktree_rule | test("primary clone")' claude/workflow/templates/a2a/brief.json exit 0 output: true
  - check: `jq -e '.facts.worktree_rule | test("primary clone")' claude/workflow/templates/a2a/brief.json` exit 0
- [x] `AC-H4` *(human)* the diff holds only In files and generated work-orders files
  - observed `2026-10-16` check: git diff --name-only origin/main...HEAD | grep -vE '^(work-orders/.*|claude/workflow/(bin/brief.sh|templates/a2a/brief.json|tests/unit/test_a2a_brief.sh))$' exit 1 output:
  - check: `git diff --name-only origin/main...HEAD | grep -vE '^(work-orders/.*|claude/workflow/(bin/brief\.sh|templates/a2a/brief\.json|tests/unit/test_a2a_brief\.sh))$'` exit 1

## Test plan

```sh
{"scope":"brief.sh check --build refuses a primary clone worktree","cases":[{"id":"TP-1","intent":"efb2 was started in the ~/dotfiles primary clone; a build brief naming a primary clone must be a DESIGN-GAP before the seat starts","command":"make -C claude/workflow -f a2a.mk a2a-test","expected":"exit 0; cases a to d print ok and existing cases still pass"},{"id":"TP-2","intent":"rolodex header kept","command":"make rolodex-check BASE=origin/main","expected":"exit 0"}],"isolation":{"runtime":"podman","image":"localhost/dotfiles-workflow-test:1"},"out_of_scope":["the full workflow suite: CI runs it"]}
```

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
