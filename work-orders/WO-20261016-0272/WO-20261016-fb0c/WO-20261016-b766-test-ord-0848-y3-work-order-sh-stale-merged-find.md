---
{
  "id": "WO-20261016-b766",
  "slug": "test-ord-0848-y3-work-order-sh-stale-merged-find",
  "title": "Test - ORD-0848 Y3: work-order.sh stale-merged finds the merged S02 tickets and writes nothing",
  "type": "test",
  "status": "ready",
  "priority": "p0",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T09:08:20+00:00",
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
    "WO-20261016-2d5b"
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
      "command": "bash -c 'git -C ~/projects/business-80d3 fetch -q origin && d=$(mktemp -d) && git -C ~/projects/business-80d3 worktree add -q --detach $d origin/venture/yieldpoint-consulting && bash claude/skills/work-order/scripts/work-order.sh stale-merged --project $d --pr-repo jkkelley/ypconsult-01-src --json | jq -e \"type == \\\"array\\\"\" && test -z \"$(git -C $d status --porcelain)\"; r=$?; git -C ~/projects/business-80d3 worktree remove --force $d; exit $r'",
      "exit": 0,
      "expect": null
    }
  ],
  "provides": [],
  "labels": [
    "line:inbox-triage"
  ]
}
---

# WO-20261016-b766 - Test - ORD-0848 Y3: work-order.sh stale-merged finds the merged S02 tickets and writes nothing

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

Run the filled test plan of WO-20261016-2d5b exactly as written on its merged main; dev gate on fixtures, then a read-only run on the real business tickets (item 34), no owner notification (item 35).

## Owner words

> i want work scoped so small a fuck ape could do, testing the same way with test plans and scripts, every node has what it fucking needs up front, not later (Design principles 101 item 30)

> Ensure that your testing is dev uat stable. (item 34)

## Context

TP-3 runs the verb against a detached worktree of business origin/venture/yieldpoint-consulting, where c770, eb12 and f58e are in-review, and against ypconsult-01-src PRs; it removes the worktree at the end.

## Scope

**In**

- touches: none (read-only; the temporary business worktree is removed by TP-3 itself; the run output goes by script to ~/.local/state/zenith/log/YYYY/MM/ with frontmatter)
- touches (generated, written only by work-order.sh start/submit/done, never by hand or git add): this ticket file and its archive path; work-orders/INDEX.md and the parent epic README.md are ignored generated views
- step: in your own detached worktree of dotfiles origin/main run TP-1, TP-2, TP-3 exactly as written; record each with work-order.sh evidence
- tool: cmd:git, cmd:jq, cmd:make, cmd:podman, cmd:gh - fallback: missing on the host: stop with ENV-MISSING naming it; gh or GitHub down: retry 3 times, then stop with A2A-003 and its output

**Out - non-goals**

- writing or changing code: a failing case goes back as A2A-003 with its output
- closing c770, eb12 or f58e: the batch close ticket does that
- waiting on CI or merging: push, open the PR, write the result, leave (ORD-0542 O2)
- any file not named under In: stop with DESIGN-GAP and hand it back to infra-design (ORD-0548, item 30)

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [ ] `AC-H1` *(human)* TP-1 and TP-2: the skill suite passes with case 320
  - check: `bash claude/skills/work-order/testing/run-tests.sh` exit 0 expect /all cases passed/
- [ ] `AC-H2` *(human)* TP-3: the real run lists the merged tickets and leaves the tree clean
  - check: `bash -c 'git -C ~/projects/business-80d3 fetch -q origin && d=$(mktemp -d) && git -C ~/projects/business-80d3 worktree add -q --detach $d origin/venture/yieldpoint-consulting && bash claude/skills/work-order/scripts/work-order.sh stale-merged --project $d --pr-repo jkkelley/ypconsult-01-src --json | jq -e "type == \"array\"" && test -z "$(git -C $d status --porcelain)"; r=$?; git -C ~/projects/business-80d3 worktree remove --force $d; exit $r'` exit 0

## Test plan

_Test plan from claude/workflow/templates/test-plan.md, shaped by claude/workflow/schemas/test-plan.schema.json. The tester runs exactly these cases and nothing else._

**Scope under test**

work-order.sh stale-merged: lists ready, in-progress and in-review tickets whose recorded PR, or a PR from whose recorded branch, is MERGED; writes nothing

**Cases**

- `TP-1`
  - intent: a ticket whose PR merged but was never closed out sits ready forever and the line reads it as open work (c770, eb12, f58e: ypconsult-01-src PRs 52, 51, 53 merged, tickets still in-review)
  - command: `bash claude/skills/work-order/testing/run-tests.sh 2>&1 | sed -n '/320-stale-merged.sh/,/checks, [0-9]* failed/p'`
  - expected: exit 0; the block ends with `0 failed`
- `TP-2`
  - intent: the new verb must not break any other verb
  - command: `bash claude/skills/work-order/testing/run-tests.sh | tail -1`
  - expected: exit 0; the last line starts with `all cases passed:`
- `TP-3`
  - intent: the verb is read-only against the real tickets of a live repo (dev gate on real data, nothing written)
  - command: `bash -c 'git -C ~/projects/business-80d3 fetch -q origin && d=$(mktemp -d) && git -C ~/projects/business-80d3 worktree add -q --detach $d origin/venture/yieldpoint-consulting && bash claude/skills/work-order/scripts/work-order.sh stale-merged --project $d --pr-repo jkkelley/ypconsult-01-src --json | jq -r ".[].id" | sort | tr "\n" " "; git -C $d status --porcelain | wc -l; git -C ~/projects/business-80d3 worktree remove --force $d'`
  - expected: exit 0; prints `WO-20261016-c770 WO-20261016-eb12 WO-20261016-f58e ` then `0` (unless those three were closed meanwhile, then the ids are absent)

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
