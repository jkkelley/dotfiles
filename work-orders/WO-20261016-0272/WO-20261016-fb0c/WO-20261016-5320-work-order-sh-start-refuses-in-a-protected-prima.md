---
{
  "id": "WO-20261016-5320",
  "slug": "work-order-sh-start-refuses-in-a-protected-prima",
  "title": "work-order.sh start refuses in a protected primary clone (WO_PROTECTED_CLONES, default ~/dotfiles) with exit 3 primary_clone",
  "type": "feature",
  "status": "ready",
  "priority": "p0",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T10:07:47+00:00",
  "parent": "WO-20261016-fb0c",
  "branch": null,
  "pr": null,
  "closed": null,
  "approval": {
    "via": "override",
    "reason": "infra-design13 cut for ORD-0830 RR-orch-14; design approvals ruled done, ORD-0550 O4",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [
    "WO-20261016-5afd"
  ],
  "blocks": [
    "WO-20261016-231a"
  ],
  "ac_checks": [
    {
      "index": 1,
      "command": "bash claude/skills/work-order/testing/run-tests.sh",
      "exit": 0,
      "expect": "400-start-primary-clone"
    },
    {
      "index": 2,
      "command": "make rolodex-check BASE=origin/main",
      "exit": 0,
      "expect": null
    },
    {
      "index": 3,
      "command": "git diff --name-only origin/main...HEAD | grep -vE '^(work-orders/.*|claude/skills/work-order/(SKILL\\.md|scripts/work-order\\.sh|testing/SOP\\.md|testing/cases/400-start-primary-clone\\.sh))$'",
      "exit": 1,
      "expect": null
    }
  ],
  "provides": [
    "path:claude/skills/work-order/testing/cases/400-start-primary-clone.sh"
  ],
  "labels": [
    "line:inbox-triage"
  ]
}
---

# WO-20261016-5320 - work-order.sh start refuses in a protected primary clone (WO_PROTECTED_CLONES, default ~/dotfiles) with exit 3 primary_clone

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

work-order.sh start creates and checks out the feature branch in whatever checkout it runs in. Seat dag-t6b ran it for WO-20261016-efb2 inside the ~/dotfiles primary clone and every seat ran stale tools for 40+ minutes.

## Owner words

> seat dag-t6b ran work-order.sh start inside the ~/dotfiles main clone ... every seat calling ~/dotfiles tools ran stale code (brief BR-20261016-infra-design13, ORD-0830 RR-orch-14)

> worktrees and feature branches with the whole process DAG when getting work (Design principles 101 item 20)

## Context

Order ORD-0830 RR-orch-14, brief BR-20261016-infra-design13 item DESIGN-GAP main clone drift ('work-order.sh start refuses in the primary worktree'). Evidence: ~/.local/state/zenith/breakglass/2026/10/20261016-095436-main-clone-efb2-start-stamp.patch and seats/wr2-feed.result.json (ENV-MISSING on claude/tools/shot while ~/dotfiles sat on feat/dag-state-t6 at c7bd763 for 40+ min). Chain on work-order.sh: ... -> 3a66 -> WO-20261016-5afd -> this ticket.

Behaviour, fixed. In cmd_start, before any branch is created: top = git -C project rev-parse --show-toplevel. Refuse when realpath of --git-dir equals realpath of --git-common-dir (a primary clone, not a linked worktree) and realpath of top is one of the colon-separated paths in WO_PROTECTED_CLONES (unset: $HOME/dotfiles; set to empty: nothing protected). Refusal: ps_die PS_VALIDATION (exit 3) error primary_clone, message 'primary_clone TOP: start runs only in a git worktree (git worktree add); this clone stays on main', nothing written, branch unchanged. A linked worktree of the same repo starts as today. Breadcrumb at the change names this ticket and the breakglass patch path. SKILL.md: one sentence in the Lifecycle section after the table naming the refusal and WO_PROTECTED_CLONES.

Test case claude/skills/work-order/testing/cases/400-start-primary-clone.sh, with HOME set to a mktemp dir and a ready ticket fixture: (a) project at HOME/dotfiles (primary clone): start exit 3 primary_clone, current branch still main, ticket still ready; (b) git worktree add HOME/wt from it: start in HOME/wt exit 0, in-progress; (c) WO_PROTECTED_CLONES= (empty) and project HOME/dotfiles: start exit 0; (d) a primary clone at HOME/other with WO_PROTECTED_CLONES unset: start exit 0.

## Scope

**In**

- touches: claude/skills/work-order/scripts/work-order.sh (cmd_start refusal only, plus breadcrumb)
- touches: claude/skills/work-order/testing/cases/400-start-primary-clone.sh (new, cases a to d in Context)
- touches: claude/skills/work-order/testing/SOP.md (one entry for 400)
- touches: claude/skills/work-order/SKILL.md (the one sentence in Context)
- touches (generated, written only by work-order.sh start/submit/done, never by hand or git add): this ticket file and its archive path; work-orders/INDEX.md and the parent epic README.md are ignored generated views
- step: branch from origin/main in your own git worktree after WO-20261016-5afd merged; make exactly the four edits in Context
- step: run `bash claude/skills/work-order/testing/run-tests.sh` and the AC checks only; CI runs the rest
- step: commit 'feat(work-order): start refuses in a protected primary clone' with the ticket id; the PR body ends with 'Bump: work-order=minor'
- tool: script:claude/skills/work-order/testing/run-tests.sh - on main; fallback: missing: stop with DESIGN-GAP naming it; its image fails to build: stop with ENV-MISSING podman
- tool: make:Makefile:rolodex-check - on main; fallback: missing: stop with DESIGN-GAP naming it
- tool: cmd:git, cmd:jq, cmd:make, cmd:podman, cmd:gh - fallback: missing on the host: stop with ENV-MISSING naming it; gh or GitHub down: retry 3 times, then stop with A2A-003 and its output

**Out - non-goals**

- any other start behaviour (branch naming, test-plan gate)
- a guard on submit or done
- work-orders/INDEX.md and epic READMEs by hand or by git add; waiting on CI or merging: push, open the PR, write the result, leave
- any file not named under In: stop with DESIGN-GAP

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [ ] `AC-H1` *(human)* the work-order suite passes with the new case
  - check: `bash claude/skills/work-order/testing/run-tests.sh` exit 0 expect /400-start-primary-clone/
- [ ] `AC-H2` *(human)* every changed script has a rolodex header
  - check: `make rolodex-check BASE=origin/main` exit 0
- [ ] `AC-H3` *(human)* the diff holds only In files and generated work-orders files
  - check: `git diff --name-only origin/main...HEAD | grep -vE '^(work-orders/.*|claude/skills/work-order/(SKILL\.md|scripts/work-order\.sh|testing/SOP\.md|testing/cases/400-start-primary-clone\.sh))$'` exit 1

## Test plan

```sh
{"scope":"start refuses in a protected primary clone and runs in a linked worktree","cases":[{"id":"TP-1","intent":"start in ~/dotfiles left it on a feature branch for 40+ min; start must refuse there and still work in a worktree","command":"bash claude/skills/work-order/testing/run-tests.sh","expected":"exit 0; 400-start-primary-clone prints only ok lines"},{"id":"TP-2","intent":"rolodex header kept","command":"make rolodex-check BASE=origin/main","expected":"exit 0"}],"isolation":{"runtime":"podman","image":"docker.io/library/debian@sha256:328d16499860ae6cb9b345e2e4cebca08c2a36e4f7278482c7bd1f39d71e5bfd"},"out_of_scope":["the skill gates: CI runs them"]}
```

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
