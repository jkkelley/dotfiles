---
{
  "id": "WO-20261016-9fc7",
  "slug": "work-order-sh-start-names-the-branch-feat-id-hex",
  "title": "work-order.sh start names the branch feat/<id hex>-<slug>, so a ticket whose slug matches a merged ticket's branch can still start",
  "type": "feature",
  "status": "ready",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T10:39:15+00:00",
  "parent": "WO-20261016-fb0c",
  "branch": null,
  "pr": null,
  "closed": null,
  "approval": {
    "via": "override",
    "reason": "infra-design15 cut for ORD-0830 RR-orch-14 F35; design approvals ruled done, ORD-0550 O4",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [],
  "blocks": [
    "WO-20261016-94e2",
    "WO-20261016-3d4d"
  ],
  "ac_checks": [
    {
      "index": 1,
      "command": "bash claude/skills/work-order/testing/run-tests.sh",
      "exit": 0,
      "expect": "410-start-branch-id"
    },
    {
      "index": 2,
      "command": "grep -c 'branch=\"feat/${id##\\*-}-${slug}\"' claude/skills/work-order/scripts/work-order.sh",
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
      "command": "git diff --name-only origin/main...HEAD | grep -vE '^(work-orders/.*|claude/skills/work-order/(SKILL\\.md|scripts/work-order\\.sh|references/lifecycle\\.md|testing/SOP\\.md|testing/cases/(070-cleanup-refuses-unmerged|410-start-branch-id)\\.sh))$'",
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

# WO-20261016-9fc7 - work-order.sh start names the branch feat/<id hex>-<slug>, so a ticket whose slug matches a merged ticket's branch can still start

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

start derives feat/<slug> from a slug truncated to 48 chars, so two tickets with the same title prefix get the same branch: WO-20261016-94e2 refuses branch_exists on feat/test-timed-run-every-target-of-claude-workflow-a, the branch of merged WO-20261016-6e55 (PR 268) still checked out in /home/luna/.cache/wt-test-tra2a (seats/timed-test.result.json)

## Owner words

> DESIGN-GAP start branch collision ... Make start collision-safe (id in branch) or retire the stale branch (orchestrator brief BR-20261016-infra-design15)

> see a bug, isolate it, and get it fixed as asap (Design principles 101 item 22)

## Context

Order brief BR-20261016-infra-design15. Repro: on origin/main, bash claude/skills/work-order/scripts/work-order.sh start --id WO-20261016-94e2 -> branch feat/test-timed-run-every-target-of-claude-workflow-a already exists. The four hex chars after the date in the id are unique per ticket, so branch=feat/${id##*-}-${slug} can never equal another ticket's branch. Edit 1, work-order.sh cmd_start line 'branch="feat/${slug}"' (line 1110 on main 6b1af2d) becomes 'branch="feat/${id##*-}-${slug}"', with a breadcrumb comment above it naming the 94e2/6e55 collision, the rejected alternative (retire the stale branch: deletes a seat's work and recurs on the next shared prefix) and the cost (branch names 5 chars longer). Edit 2, testing/cases/070-cleanup-refuses-unmerged.sh line 23: the expected branch becomes feat/<hex>-cart-empty, the hex read from the minted id. Edit 3, new testing/cases/410-start-branch-id.sh: mint two tickets with the same 60-char title, start the first, merge nothing, check out the base, start the second: both exit 0 and the branches differ and each ends with its own id hex prefix; source assert.sh like 070. Edit 4, testing/SOP.md: one entry for 410 in the shape of the 070 entry. Edit 5, references/lifecycle.md line 65 and SKILL.md line 247: feat/<slug> becomes feat/<id hex>-<slug>. dag-take.sh builds its own feat/<slug> for dag run state and is out (follow-up after this merges).

## Scope

**In**

- touches: claude/skills/work-order/scripts/work-order.sh (cmd_start branch line and its breadcrumb only)
- touches: claude/skills/work-order/testing/cases/070-cleanup-refuses-unmerged.sh (line 23 only)
- touches: claude/skills/work-order/testing/cases/410-start-branch-id.sh (new)
- touches: claude/skills/work-order/testing/SOP.md (one entry for 410)
- touches: claude/skills/work-order/references/lifecycle.md (line 65 only)
- touches: claude/skills/work-order/SKILL.md (line 247 only)
- touches (generated, written only by work-order.sh start/submit/done, never by hand or git add): this ticket file and its archive path; work-orders/INDEX.md and the parent epic README.md are ignored generated views
- step: branch from origin/main in your own git worktree, never the ~/dotfiles primary clone
- step: make exactly the five edits in Context
- step: run the AC checks only; CI runs the rest
- step: commit 'feat(work-order): start puts the ticket id in the branch' with the ticket id; the PR body ends with 'Bump: work-order=minor'
- tool: script:claude/skills/work-order/testing/run-tests.sh - on main; fallback: missing: stop with DESIGN-GAP naming it; its image fails to build: stop with ENV-MISSING podman
- tool: make:Makefile:rolodex-check - on main; fallback: missing: stop with DESIGN-GAP naming it
- tool: cmd:git, cmd:jq, cmd:make, cmd:podman, cmd:gh - fallback: missing on the host: stop with ENV-MISSING naming it; gh or GitHub down: retry 3 times, then stop with A2A-003 and its output

**Out - non-goals**

- claude/workflow/dag/bin/dag-take.sh branch naming: follow-up ticket after this merges
- renaming or deleting any existing branch; retiring stale seat worktrees (orchestrator line operation)
- any file not named under In: stop with DESIGN-GAP
- work-orders/INDEX.md and epic READMEs by hand or by git add; waiting on CI or merging: push, open the PR, write the result, leave

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [ ] `AC-H1` *(human)* two tickets with one slug start on two branches, each carrying its id
  - check: `bash claude/skills/work-order/testing/run-tests.sh` exit 0 expect /410-start-branch-id/
- [ ] `AC-H2` *(human)* start's branch line carries the id hex
  - check: `grep -c 'branch="feat/${id##\*-}-${slug}"' claude/skills/work-order/scripts/work-order.sh` exit 0 expect /^1$/
- [ ] `AC-H3` *(human)* rolodex pointers hold
  - check: `make rolodex-check BASE=origin/main` exit 0
- [ ] `AC-H4` *(human)* the diff holds only the In files
  - check: `git diff --name-only origin/main...HEAD | grep -vE '^(work-orders/.*|claude/skills/work-order/(SKILL\.md|scripts/work-order\.sh|references/lifecycle\.md|testing/SOP\.md|testing/cases/(070-cleanup-refuses-unmerged|410-start-branch-id)\.sh))$'` exit 1

## Test plan

```sh
{"scope":"start branch naming","cases":[{"id":"TP-1","intent":"a shared slug prefix never blocks start","command":"bash claude/skills/work-order/testing/run-tests.sh","expected":"exit 0; 410-start-branch-id and 070 listed as passed"}],"isolation":{"runtime":"podman","image":"the digest-pinned image run-tests.sh builds"},"out_of_scope":["other skills' suites: CI runs them"]}
```

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
