---
{
  "id": "WO-20261016-ad18",
  "slug": "close-wo-20261016-3327-main-clone-guard-pr-304-m",
  "title": "Close WO-20261016-3327 (main-clone-guard, PR 304 merged): re-run its checks with check 1 expecting 'ok +main-clone-guard: 8 cases', move its edges here and cancel 3327 as superseded",
  "type": "chore",
  "status": "in-progress",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T10:38:41+00:00",
  "parent": "WO-20261016-4b6c",
  "branch": "feat/close-wo-20261016-3327-main-clone-guard-pr-304-m",
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
    "WO-20261016-c2b3",
    "WO-20261016-5ee5"
  ],
  "ac_checks": [
    {
      "index": 1,
      "command": "make -C claude/workflow -f main-clone.mk main-clone-test",
      "exit": 0,
      "expect": "^ok +main-clone-guard: 8 cases"
    },
    {
      "index": 2,
      "command": "make rolodex-check BASE=origin/main",
      "exit": 0,
      "expect": null
    },
    {
      "index": 3,
      "command": "grep -cE '^\\| (LW-)?MAIN-DRIFT \\|' claude/workflow/templates/a2a/README.md",
      "exit": 0,
      "expect": "^2$"
    },
    {
      "index": 4,
      "command": "git diff --name-only origin/main...HEAD | grep -vE '^(work-orders/.*|claude/workflow/(bin/main-clone-guard\\.sh|main-clone\\.mk|tests/unit/test_main_clone_guard\\.sh|templates/a2a/README\\.md))$'",
      "exit": 1,
      "expect": null
    },
    {
      "index": 5,
      "command": "bash claude/skills/work-order/scripts/work-order.sh show --id WO-20261016-3327 --json | jq -r '.status + \" \" + (.superseded_by // \"-\")'",
      "exit": 0,
      "expect": "^cancelled WO-"
    },
    {
      "index": 6,
      "command": "git diff --name-only origin/main...HEAD | grep -vE '^(work-orders/.*)$'",
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

# WO-20261016-ad18 - Close WO-20261016-3327 (main-clone-guard, PR 304 merged): re-run its checks with check 1 expecting 'ok +main-clone-guard: 8 cases', move its edges here and cancel 3327 as superseded

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

WO-20261016-3327 shipped in PR 304 (merged) but its ticket is still ready on main and cannot close: its check 1 expects two spaces after ok while the test prints one (seats/main-guard.result.json), and amend refuses a non-draft; its branch feat/main-clone-guard-sh-check-and-ff-a-primary-clone is held by /home/luna/.cache/wt-main-guard

## Owner words

> close-outs fb99 3327 168d (F45-F47) (orchestrator brief BR-20261016-infra-design15)

> get this code merged the fuck in, dead code is shit, it sitting under agents is stupid (Design principles 101 item 21)

## Context

Order brief BR-20261016-infra-design15, ORD-0830 RR-orch-14; F35. Pattern: WO-20261016-bcb4 (A2A-ST close). The original ticket's checks are copied here verbatim as this ticket's checks, so done re-proves the merged code on main. THIS-TICKET-ID is this ticket's own id, the .id in its frontmatter. Steps on the branch, after start: for id in $(bash claude/skills/work-order/scripts/work-order.sh show --id WO-20261016-3327 --json | jq -r '.blocks[]'): bash claude/skills/work-order/scripts/work-order.sh link --id $id --depends-on THIS-TICKET-ID --no-depends-on WO-20261016-3327; then bash claude/skills/work-order/scripts/work-order.sh cancel --id WO-20261016-3327 --reason 'code merged in PR 304; close-out blocked (its check 1 expects two spaces after ok while the test prints one (seats/main-guard.result.json), and amend refuses a non-draft; its branch feat/main-clone-guard-sh-check-and-ff-a-primary-clone is held by /home/luna/.cache/wt-main-guard); checks re-run under THIS-TICKET-ID' --superseded-by THIS-TICKET-ID; then bash claude/skills/work-order/scripts/work-order.sh check --id THIS-TICKET-ID (check ticks every passing criterion; never tick by hand with evidence); commit those generated moves.

## Scope

**In**

- touches (generated, by work-order.sh link and cancel only): the WO-20261016-3327 ticket file and its archive path, the ticket files of every id in its blocks list
- touches (generated, written only by work-order.sh start/submit/done, never by hand or git add): this ticket file and its archive path; work-orders/INDEX.md and the parent epic README.md are ignored generated views
- step: branch from origin/main in your own git worktree, never the ~/dotfiles primary clone
- step: run the link loop and the cancel exactly as in Context, then work-order.sh check --id THIS-TICKET-ID, submit --pr <this PR>, done
- step: commit 'chore(work-orders): close WO-20261016-3327 under its re-checked successor' with the ticket id; no Bump trailer
- tool: make:Makefile:rolodex-check - on main; fallback: missing: stop with DESIGN-GAP naming it
- tool: cmd:git, cmd:jq, cmd:make, cmd:podman, cmd:gh - fallback: missing on the host: stop with ENV-MISSING naming it; gh or GitHub down: retry 3 times, then stop with A2A-003 and its output

**Out - non-goals**

- any code, test or doc file: PR 304 shipped them
- the stale seat worktree and branch named in Problem: the orchestrator retires them (line operation)
- any file not named under In: stop with DESIGN-GAP
- work-orders/INDEX.md and epic READMEs by hand or by git add; waiting on CI or merging: push, open the PR, write the result, leave
- a Bump trailer: no skill under claude/skills changes

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [x] `AC-H1` *(human)* WO-20261016-3327 check 1 passes on main
  - observed `2026-10-16` check: make -C claude/workflow -f main-clone.mk main-clone-test exit 0 output: make: Entering directory '/home/luna/.cache/wt-close-3327/claude/workflow' ok (1) up to date check ok (2) behind check ok (3) ff then ff again then check ok (4) on feat check ok (5) on feat ff ok (6) ff left HEAD on feat ok (7) dirty ff ok (8) diverged ff ok (9) remote gone warns and answers ok (10) non-git dir skips ok (11) no arguments ok main-clone-guard: 8 cases make: Leaving directory '/home/luna/.cache/wt-close-3327/claude/workflow'
  - check: `make -C claude/workflow -f main-clone.mk main-clone-test` exit 0 expect /^ok +main-clone-guard: 8 cases/
- [x] `AC-H2` *(human)* WO-20261016-3327 check 2 passes on main
  - observed `2026-10-16` check: make rolodex-check BASE=origin/main exit 0 output: python3 scripts/rolodex.py check --root . --base origin/main rolodex-check: 0 script(s) checked, all have headers
  - check: `make rolodex-check BASE=origin/main` exit 0
- [x] `AC-H3` *(human)* WO-20261016-3327 check 3 passes on main
  - observed `2026-10-16` check: grep -cE '^| (LW-)?MAIN-DRIFT |' claude/workflow/templates/a2a/README.md exit 0 output: 2
  - check: `grep -cE '^\| (LW-)?MAIN-DRIFT \|' claude/workflow/templates/a2a/README.md` exit 0 expect /^2$/
- [x] `AC-H4` *(human)* WO-20261016-3327 check 4 passes on main
  - observed `2026-10-16` check: git diff --name-only origin/main...HEAD | grep -vE '^(work-orders/.*|claude/workflow/(bin/main-clone-guard.sh|main-clone.mk|tests/unit/test_main_clone_guard.sh|templates/a2a/README.md))$' exit 1 output:
  - check: `git diff --name-only origin/main...HEAD | grep -vE '^(work-orders/.*|claude/workflow/(bin/main-clone-guard\.sh|main-clone\.mk|tests/unit/test_main_clone_guard\.sh|templates/a2a/README\.md))$'` exit 1
- [x] `AC-H5` *(human)* WO-20261016-3327 is cancelled and superseded by this ticket
  - observed `2026-10-16` check: bash claude/skills/work-order/scripts/work-order.sh show --id WO-20261016-3327 --json | jq -r '.status + " " + (.superseded_by // "-")' exit 0 output: cancelled WO-20261016-ad18
  - check: `bash claude/skills/work-order/scripts/work-order.sh show --id WO-20261016-3327 --json | jq -r '.status + " " + (.superseded_by // "-")'` exit 0 expect /^cancelled WO-/
- [x] `AC-H6` *(human)* the diff holds only generated work-orders files
  - observed `2026-10-16` check: git diff --name-only origin/main...HEAD | grep -vE '^(work-orders/.*)$' exit 1 output:
  - check: `git diff --name-only origin/main...HEAD | grep -vE '^(work-orders/.*)$'` exit 1

## Test plan

```sh
{"scope":"WO-20261016-3327 checks re-run on main","cases":[{"id":"TP-1","intent":"merged code still meets every criterion of WO-20261016-3327","command":"bash claude/skills/work-order/scripts/work-order.sh check --id THIS-TICKET-ID","expected":"exit 0; one AC-PASS line per criterion"}],"isolation":{"runtime":"podman","image":"as each copied check names"},"out_of_scope":["full suites: CI runs them"]}
```

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
