---
{
  "id": "WO-20261016-2eb1",
  "slug": "work-order-docs-skill-md-sop-md-and-test-plan-fi",
  "title": "work-order docs: SKILL.md, SOP.md and --test-plan-file help name the local-image plan form and stale-merged (RR-orch-18, ORD-0848 Y3)",
  "type": "chore",
  "status": "ready",
  "priority": "p2",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T09:09:08+00:00",
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
    "WO-20261016-86b9",
    "WO-20261016-2d5b",
    "WO-20261016-e297",
    "WO-20261016-3d4d"
  ],
  "blocks": [],
  "ac_checks": [
    {
      "index": 1,
      "command": "grep -c stale-merged claude/skills/work-order/SKILL.md",
      "exit": 0,
      "expect": "^[1-9]"
    },
    {
      "index": 2,
      "command": "bash -c 'grep -q 310-local-image-plan claude/skills/work-order/testing/SOP.md && grep -q 320-stale-merged claude/skills/work-order/testing/SOP.md'",
      "exit": 0,
      "expect": null
    },
    {
      "index": 3,
      "command": "bash claude/skills/work-order/testing/run-tests.sh",
      "exit": 0,
      "expect": "all cases passed"
    },
    {
      "index": 4,
      "command": "bash -c '! git diff --name-only origin/main...HEAD | grep -vE \"^(work-orders/|claude/skills/work-order/(SKILL[.]md|scripts/work-order[.]sh|testing/SOP[.]md))$\"'",
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

# WO-20261016-2eb1 - work-order docs: SKILL.md, SOP.md and --test-plan-file help name the local-image plan form and stale-merged (RR-orch-18, ORD-0848 Y3)

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

After WO-20261016-86b9 and WO-20261016-2d5b merge, the skill's own docs still say every test plan is pinned by digest and do not list stale-merged; the cases 310 and 320 have no SOP entry.

## Owner words

> i want work scoped so small a fuck ape could do, testing the same way with test plans and scripts, every node has what it fucking needs up front, not later (Design principles 101 item 30)

## Context

Waits on WO-20261016-377c - work-order ticket template: a Before submit section whose one box is make pre-push, the last box before submit, which holds SKILL.md and testing/SOP.md, and on WO-20261016-86b9 and WO-20261016-2d5b (item 19).

## Scope

**In**

- step: precondition, before branching: `bash -c 'git fetch -q origin && git ls-tree -r --name-only origin/main work-orders/archive | grep -q WO-20261016-377c-'` exits 0 (that ticket is done on main); else stop with BLOCKED naming it
- touches: claude/skills/work-order/SKILL.md (the test-ticket comment in Usage names both isolation forms; a stale-merged usage line)
- touches: claude/skills/work-order/scripts/work-order.sh (the --test-plan-file help text: 'an image pinned by digest, or a locally built localhost/<name>:<tag> with build: and containerfile:')
- touches: claude/skills/work-order/testing/SOP.md (entries for 310-local-image-plan.sh and 320-stale-merged.sh: what runs, what is asserted, why)
- touches (generated, written only by work-order.sh start/submit/done, never by hand or git add): this ticket file and its archive path; work-orders/INDEX.md and the parent epic README.md are ignored generated views
- step: branch from origin/main in your own worktree after the three dependencies merged; edit exactly the three files
- step: run `bash claude/skills/work-order/testing/run-tests.sh` and the AC checks; commit 'docs(work-order): local-image plans and stale-merged'; the PR body ends with 'Bump: work-order=patch'
- tool: cmd:git, cmd:jq, cmd:make, cmd:podman, cmd:gh - fallback: missing on the host: stop with ENV-MISSING naming it; gh or GitHub down: retry 3 times, then stop with A2A-003 and its output

**Out - non-goals**

- any behaviour change
- work-orders/INDEX.md and epic READMEs by hand or by git add: they are ignored generated views
- waiting on CI or merging: push, open the PR, write the result, leave (ORD-0542 O2)
- any file not named under In: stop with DESIGN-GAP and hand it back to infra-design (ORD-0548, item 30)

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [ ] `AC-H1` *(human)* SKILL.md names stale-merged
  - check: `grep -c stale-merged claude/skills/work-order/SKILL.md` exit 0 expect /^[1-9]/
- [ ] `AC-H2` *(human)* SOP.md names both cases
  - check: `bash -c 'grep -q 310-local-image-plan claude/skills/work-order/testing/SOP.md && grep -q 320-stale-merged claude/skills/work-order/testing/SOP.md'` exit 0
- [ ] `AC-H3` *(human)* the suite still passes
  - check: `bash claude/skills/work-order/testing/run-tests.sh` exit 0 expect /all cases passed/
- [ ] `AC-H4` *(human)* the diff holds only In files and generated work-orders files
  - check: `bash -c '! git diff --name-only origin/main...HEAD | grep -vE "^(work-orders/|claude/skills/work-order/(SKILL[.]md|scripts/work-order[.]sh|testing/SOP[.]md))$"'` exit 0

## Test plan

```sh
bash claude/skills/work-order/testing/run-tests.sh | tail -1 # all cases passed
```

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
