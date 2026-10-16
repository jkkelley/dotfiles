---
{
  "id": "WO-20261016-1099",
  "slug": "work-order-sh-check-and-done-code-dir-dir-run-a-",
  "title": "work-order.sh check and done --code-dir DIR run a cross-repo ticket's checks in the checkout of its repo, and refuse code_dir_required without it",
  "type": "feature",
  "status": "in-progress",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T10:39:34+00:00",
  "parent": "WO-20261016-fb0c",
  "branch": "feat/1099-work-order-sh-check-and-done-code-dir-dir-run-a-",
  "pr": null,
  "closed": null,
  "approval": {
    "via": "override",
    "reason": "infra-design15 cut for ORD-0830 RR-orch-14 F35; design approvals ruled done, ORD-0550 O4",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [
    "WO-20261016-e297"
  ],
  "blocks": [
    "WO-20261016-3d4d",
    "WO-20261016-ef1b",
    "WO-20261016-64f2",
    "WO-20261016-a1ca"
  ],
  "ac_checks": [
    {
      "index": 1,
      "command": "bash claude/skills/work-order/testing/run-tests.sh",
      "exit": 0,
      "expect": "420-code-dir-checks"
    },
    {
      "index": 2,
      "command": "grep -c 'cd \"${code_dir:-$project}\"' claude/skills/work-order/scripts/work-order.sh",
      "exit": 0,
      "expect": "^1$"
    },
    {
      "index": 3,
      "command": "make rolodex-check BASE=origin/main",
      "exit": 0,
      "expect": null
    },
    {
      "index": 4,
      "command": "git diff --name-only origin/main...HEAD | grep -vE '^(work-orders/.*|claude/skills/work-order/(scripts/work-order\\.sh|testing/SOP\\.md|testing/cases/420-code-dir-checks\\.sh))$'",
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

# WO-20261016-1099 - work-order.sh check and done --code-dir DIR run a cross-repo ticket's checks in the checkout of its repo, and refuse code_dir_required without it

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

run_checks runs every ac_check with cwd = the ticket project (work-order.sh:1859 'cd "$project"'), so a ticket whose .repo names another repo runs git diff and make checks in the wrong tree: WO-20261016-2d63 (business ticket, code in ypconsult-01-src PR 63) passed AC-H1..H5 in the src worktree but done failed in business and the ticket sits in-review (seats/ypc-2d63.result.json)

## Owner words

> DESIGN-GAP cross-repo done cwd ... Needs done to run checks in the ticket repo field's worktree (orchestrator brief BR-20261016-infra-design15)

> if the task or job needs tools, the architect has a design agent build that shit out before the ticket goes in (Design principles 101 item 30)

## Context

Order brief BR-20261016-infra-design15. f57d (merged #295 code path) gives a ticket .repo OWNER/NAME; WO-20261016-e297 adds --code-dir DIR to approve and its flag parsing. This ticket reuses that same --code-dir variable for check and done. Edit 1, run_checks: 'cd "$project"' becomes 'cd "${code_dir:-$project}"'. Edit 2, cmd_check and cmd_done, before run_checks: when .repo is non-null and --code-dir is empty, ps_die "$PS_USAGE" code_dir_required '<id> names repo <repo>; pass --code-dir <checkout of that repo>'; when --code-dir is given it must be a git work tree whose 'git -C DIR remote get-url origin' ends with <repo> or <repo>.git, else ps_die "$PS_VALIDATION" code_dir_mismatch. Edit 3, usage: check and done lines gain [--code-dir DIR]. Breadcrumb comment above Edit 1 naming 2d63, the rejected alternative (guess the checkout from treehouse or ~/projects: nondeterministic) and the cost (a cross-repo close-out names one more flag). Edit 4, new testing/cases/420-code-dir-checks.sh: a ticket with .repo set and a check 'test -f marker' where marker exists only in a second git repo whose origin url ends with the repo name: check without --code-dir exits 2 code_dir_required; with --code-dir of an unrelated repo exits 3 code_dir_mismatch; with the right dir AC-PASS 1 and exit 0; a ticket without .repo behaves as before. Edit 5, testing/SOP.md: one entry for 420. After merge the 2d63 seat runs done --code-dir <its src worktree> (business repo; out of this ticket).

## Scope

**In**

- touches: claude/skills/work-order/scripts/work-order.sh (run_checks cd line, cmd_check and cmd_done guard, usage lines for check and done, breadcrumb)
- touches: claude/skills/work-order/testing/cases/420-code-dir-checks.sh (new)
- touches: claude/skills/work-order/testing/SOP.md (one entry for 420)
- touches (generated, written only by work-order.sh start/submit/done, never by hand or git add): this ticket file and its archive path; work-orders/INDEX.md and the parent epic README.md are ignored generated views
- step: branch from origin/main in your own git worktree after WO-20261016-e297 merged, never the ~/dotfiles primary clone
- step: make exactly the five edits in Context
- step: run the AC checks only; CI runs the rest
- step: commit 'feat(work-order): check and done --code-dir run cross-repo checks in the code checkout' with the ticket id; the PR body ends with 'Bump: work-order=minor'
- tool: script:claude/skills/work-order/testing/run-tests.sh - on main; fallback: missing: stop with DESIGN-GAP naming it; its image fails to build: stop with ENV-MISSING podman
- tool: make:Makefile:rolodex-check - on main; fallback: missing: stop with DESIGN-GAP naming it
- tool: cmd:git, cmd:jq, cmd:make, cmd:podman, cmd:gh - fallback: missing on the host: stop with ENV-MISSING naming it; gh or GitHub down: retry 3 times, then stop with A2A-003 and its output

**Out - non-goals**

- closing WO-20261016-2d63 or any business or ypconsult file: its seat reruns done after this merges
- approve --code-dir behaviour: WO-20261016-e297 owns it
- any file not named under In: stop with DESIGN-GAP
- work-orders/INDEX.md and epic READMEs by hand or by git add; waiting on CI or merging: push, open the PR, write the result, leave

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [ ] `AC-H1` *(human)* check and done run a cross-repo ticket's checks in --code-dir, and refuse without it or with the wrong repo
  - check: `bash claude/skills/work-order/testing/run-tests.sh` exit 0 expect /420-code-dir-checks/
- [ ] `AC-H2` *(human)* run_checks cds into code_dir when given
  - check: `grep -c 'cd "${code_dir:-$project}"' claude/skills/work-order/scripts/work-order.sh` exit 0 expect /^1$/
- [ ] `AC-H3` *(human)* rolodex pointers hold
  - check: `make rolodex-check BASE=origin/main` exit 0
- [ ] `AC-H4` *(human)* the diff holds only the In files
  - check: `git diff --name-only origin/main...HEAD | grep -vE '^(work-orders/.*|claude/skills/work-order/(scripts/work-order\.sh|testing/SOP\.md|testing/cases/420-code-dir-checks\.sh))$'` exit 1

## Test plan

```sh
{"scope":"check and done cwd for a cross-repo ticket","cases":[{"id":"TP-1","intent":"a cross-repo ticket's checks run where its code is","command":"bash claude/skills/work-order/testing/run-tests.sh","expected":"exit 0; 420-code-dir-checks listed as passed"}],"isolation":{"runtime":"podman","image":"the digest-pinned image run-tests.sh builds"},"out_of_scope":["a real business close-out: the 2d63 seat runs it"]}
```

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
