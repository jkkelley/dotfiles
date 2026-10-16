---
{
  "id": "WO-20261016-49e1",
  "slug": "work-order-sh-check-matches-an-ac-expect-regex-a",
  "title": "work-order.sh check matches an --ac-expect regex across lines when the per-line match misses, so the WO-20261016-64f2 multi-line expect passes (DESIGN-GAP a1ca)",
  "type": "bug",
  "status": "ready",
  "priority": "p0",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T12:32:55+00:00",
  "parent": "WO-20261016-fb0c",
  "branch": null,
  "pr": null,
  "closed": null,
  "approval": {
    "via": "override",
    "reason": "infra-design22 cut for BR-20261016-infra-design22; design approvals ruled done, ORD-0550 O4",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [],
  "blocks": [
    "WO-20261016-3d4d",
    "WO-20261016-a1ca"
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
      "command": "grep -cF 'grep -Pzq -- \"(?m)$expect\"' claude/skills/work-order/scripts/work-order.sh",
      "exit": 0,
      "expect": "^1$"
    },
    {
      "index": 3,
      "command": "test -f claude/skills/work-order/testing/cases/460-ac-expect-multiline.sh && grep -c '^## 460-ac-expect-multiline' claude/skills/work-order/testing/SOP.md",
      "exit": 0,
      "expect": "^1$"
    },
    {
      "index": 4,
      "command": "git diff --name-only origin/main...HEAD | grep -vE '^(work-orders/.*|claude/skills/work-order/(scripts/work-order\\.sh|testing/SOP\\.md|testing/cases/460-ac-expect-multiline\\.sh))$'",
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

# WO-20261016-49e1 - work-order.sh check matches an --ac-expect regex across lines when the per-line match misses, so the WO-20261016-64f2 multi-line expect passes (DESIGN-GAP a1ca)

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

WO-20261016-a1ca stalls: work-order.sh check --code-dir on WO-20261016-64f2 returns AC-FAIL 2 although the image is correct, because run_checks matches --ac-expect one output line at a time and the index 2 regex spans five lines.

## Owner words

> DESIGN-GAP a1ca: 64f2 check --code-dir returns AC-FAIL 2: its index 2 expect regex ends in ^1000$ and check matches it against multi-line output (gh 2.101.0, 0.5.0, jsonschema-ok, tools-ok, 1000) without multiline; indices 1,3,4 pass. Fix the 64f2 expect, or make work-order.sh check match ^$ per line (tooling leaf) (orchestrator brief BR-20261016-infra-design22)

> create generic tooling too fucker (Design principles 101 item 30); see a bug, isolate it, and get it fixed as asap (Design principles 101 item 22)

## Context

Root cause, reproduced by infra-design22 on the host: run_checks (work-order.sh, the line printf %s\\n "$out" | grep -Eq -- "$expect") hands the output to grep one line at a time, so no regex can span lines; [\s\S]* between gh version 2.101.0 and ^1000$ never matches. printf out | grep -Eq RE -> 1; printf out | grep -Pzq "(?m)RE" -> 0. The 64f2 expect cannot be amended (amend needs draft, 64f2 is ready), so the tooling fix is the path, and it is generic: every ticket with a multi-line expect gets it.

Fix shape (fixed, no freedom): keep the per-line grep -Eq as the first try, unchanged; when it does not match, try the whole output once as one record with PCRE multiline: printf %s\\n "$out" | grep -Pzq -- "(?m)$expect". ok stays 0 only when both miss. When grep -P is unsupported (grep exit 2, e.g. BusyBox), the per-line verdict stands: that is the fallback, and case 460 covers it with a PATH stub grep that exits 2 on -P. The change is additive: no check that passes today can fail after it. Breadcrumb comment at the line per the global breadcrumb rule (what broke, why, rejected alternative amend-64f2 because amend needs draft and the bug is generic, cost: one extra grep on a miss).

## Scope

**In**

- touches: claude/skills/work-order/scripts/work-order.sh (run_checks expect test line and its breadcrumb comment only)
- touches: claude/skills/work-order/testing/cases/460-ac-expect-multiline.sh (new): three tickets via wo new with --ac-check "printf 'gh version 2.101.0\n0.5.0\njsonschema-ok\ntools-ok\n1000\n'" --ac-exit 0: expect 'gh version 2\.101\.0[\s\S]*tools-ok[\s\S]*^1000$' gives AC-PASS, expect '^0\.5\.0$' gives AC-PASS, expect 'gh version 9[\s\S]*^1000$' gives AC-FAIL; fourth sub-case with a PATH grep stub that exits 2 on -P keeps the multi-line expect AC-FAIL and the single-line one AC-PASS
- touches: claude/skills/work-order/testing/SOP.md (one ## 460-ac-expect-multiline entry, after 450-code-dir-worktree)
- touches (generated, written only by work-order.sh start/submit/done, never by hand or git add): this ticket file and its archive path; work-orders/INDEX.md and the parent epic README.md are ignored generated views
- step: branch from origin/main in your own git worktree (fallback: treehouse fails, use git worktree add), never the ~/dotfiles primary clone; bash claude/skills/work-order/scripts/work-order.sh start --id <this ticket>
- step: make exactly the edits in Context and the In lines
- step: run the AC checks with bash claude/skills/work-order/scripts/work-order.sh check --id <this ticket>; CI runs the rest
- step: commit 'fix(work-order): check matches an expect across lines when the per-line match misses' with the ticket id; the PR body ends with 'Bump: work-order=patch'; push, gh pr create, submit --pr <N>, done on the branch, push, leave
- tool: script:claude/skills/work-order/testing/run-tests.sh - on main; fallback: missing: stop with DESIGN-GAP naming it; its image fails to build: stop with ENV-MISSING podman
- tool: cmd:grep -P (GNU grep in the test image) - fallback: unsupported (exit 2): the per-line verdict stands, coded in run_checks and proved by case 460
- tool: cmd:git, cmd:jq, cmd:podman, cmd:gh - fallback: missing on the host: stop with ENV-MISSING naming it; gh or GitHub down: retry 3 times, then stop with A2A-003 and its output

**Out - non-goals**

- amending WO-20261016-64f2 or any other ticket's expect
- changing exit-code matching, --ac-expect syntax or the AC-PASS/AC-FAIL output format
- lib/wo.sh, SKILL.md, the test Containerfile
- any file not named under In: stop with DESIGN-GAP
- work-orders/INDEX.md and epic READMEs by hand or by git add; waiting on CI or merging: push, open the PR, write the result, leave

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [ ] `AC-H1` *(human)* the skill suite passes with case 460
  - check: `bash claude/skills/work-order/testing/run-tests.sh` exit 0 expect /all cases passed/
- [ ] `AC-H2` *(human)* run_checks tries a PCRE multiline whole-output match
  - check: `grep -cF 'grep -Pzq -- "(?m)$expect"' claude/skills/work-order/scripts/work-order.sh` exit 0 expect /^1$/
- [ ] `AC-H3` *(human)* the new case file exists
  - check: `test -f claude/skills/work-order/testing/cases/460-ac-expect-multiline.sh && grep -c '^## 460-ac-expect-multiline' claude/skills/work-order/testing/SOP.md` exit 0 expect /^1$/
- [ ] `AC-H4` *(human)* the diff holds only In files
  - check: `git diff --name-only origin/main...HEAD | grep -vE '^(work-orders/.*|claude/skills/work-order/(scripts/work-order\.sh|testing/SOP\.md|testing/cases/460-ac-expect-multiline\.sh))$'` exit 1

## Test plan

_Test plan from claude/workflow/templates/test-plan.md, shaped by claude/workflow/schemas/test-plan.schema.json. The tester runs exactly these cases and nothing else._

**Scope under test**

run_checks in claude/skills/work-order/scripts/work-order.sh: how an --ac-expect regex is matched against a check's output

**Cases**

- `TP-1`
  - intent: an expect that spans lines (the WO-20261016-64f2 index 2 shape, [\s\S]* between lines and ^1000$ on the last line) fails today, so a green check reads AC-FAIL and strands the cross-repo close-out WO-20261016-a1ca
  - command: `bash claude/skills/work-order/testing/run-tests.sh`
  - expected: exit 0 and all cases passed; case 460-ac-expect-multiline.sh prints PASS for the multi-line expect returning AC-PASS, for a single-line expect still returning AC-PASS, and for a non-matching multi-line expect still returning AC-FAIL
- `TP-2`
  - intent: the widened match must not loosen any existing check gate
  - command: `bash claude/skills/work-order/testing/run-tests.sh`
  - expected: exit 0, all cases passed, cases 270-ac-check.sh and 420-code-dir-checks.sh unchanged and green

**Isolation**

_A locally built image uses `- image: localhost/<name>:<tag>` plus `- build: <command>` and `- containerfile: <path>` lines, never a localhost digest (RR-orch-18)._

- runtime: podman
- image: `localhost/work-order-test:1`
- build: `bash claude/skills/work-order/testing/run-tests.sh`
- containerfile: `claude/skills/work-order/testing/Containerfile`

**Out of scope - CI covers**

- lint and the full work-order suite: CI runs them (Design principles 101 item 6)

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
