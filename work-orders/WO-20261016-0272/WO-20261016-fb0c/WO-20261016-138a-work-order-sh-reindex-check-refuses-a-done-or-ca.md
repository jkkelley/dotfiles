---
{
  "id": "WO-20261016-138a",
  "slug": "work-order-sh-reindex-check-refuses-a-done-or-ca",
  "title": "work-order.sh reindex --check refuses a done or cancelled ticket outside archive/ (unarchived_terminal), and reflow moves it to archive/<year>",
  "type": "bug",
  "status": "ready",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T11:08:40+00:00",
  "parent": "WO-20261016-fb0c",
  "branch": null,
  "pr": null,
  "closed": null,
  "approval": {
    "via": "override",
    "reason": "infra-design17 cut for ORD-1053 / ORD-0830 RR-orch-14; design approvals ruled done, ORD-0550 O4; Lavish prohibited for Claude seats (global rule)",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [
    "WO-20261016-231a",
    "WO-20261016-3d4d",
    "WO-20261016-377c"
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
      "command": "grep -c unarchived_terminal claude/skills/work-order/scripts/work-order.sh",
      "exit": 0,
      "expect": "^[1-9]"
    },
    {
      "index": 3,
      "command": "grep -c 440-unarchived-terminal claude/skills/work-order/testing/SOP.md",
      "exit": 0,
      "expect": "^[1-9]"
    },
    {
      "index": 4,
      "command": "make rolodex-check BASE=origin/main",
      "exit": 0,
      "expect": null
    },
    {
      "index": 5,
      "command": "bash -c '! git diff --name-only origin/main...HEAD | grep -vE \"^(work-orders/.*|claude/skills/work-order/scripts/work-order[.]sh|claude/skills/work-order/testing/(SOP[.]md|cases/440-unarchived-terminal[.]sh))$\"'",
      "exit": 0,
      "expect": null
    }
  ],
  "provides": [
    "claude/skills/work-order/testing/cases/440-unarchived-terminal.sh"
  ],
  "labels": [
    "line:inbox-triage"
  ]
}
---

# WO-20261016-138a - work-order.sh reindex --check refuses a done or cancelled ticket outside archive/ (unarchived_terminal), and reflow moves it to archive/<year>

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

22 tickets on jkkelley/business origin/main have status done but sit in their epic directories, not in work-orders/archive/<year>/ (the skill contract), and reindex --check passes, so nothing catches it. Repro: git -C ~/projects/business archive origin/main work-orders | tar -x -C <scratch>; in podman localhost/work-order-test:1 with dotfiles main work-order.sh: reindex --check -> 'INDEX.md and every child README generate cleanly' rc 0, while 22 status-done files lie outside archive/ (WO-20261016-2d63, 89aa, 9391, 61e0, 0bff, 0352, c770, eb12, f58e, WO-20260812-87dc ...). Evidence: /home/luna/.local/state/zenith/trace/2026/10/20261016-110922-a3-unarchived-done-repro.txt (repro script and both outputs); yp-design11 result design_gap[2]; business commit 4a71e0d changed only status in-review -> done on 2d63 (closed stays null, no move), which no done of dotfiles main or of zwo writes: the same podman repro of done on a 3-deep leaf archives it with closed set on both copies (same trace file).

## Owner words

> ORD-1053 A3: bug ticket: work-order.sh done must move the ticket to work-orders/archive/<year>/ (the skill contract); test case included. (orchestrator brief BR-20261016-infra-design17)

> see a bug, isolate it, and get it fixed as asap (Design principles 101 item 22)

> Have fallbacks too (Design principles 101 item 28)

## Context

Order ORD-1053 A3, brief BR-20261016-infra-design17. Isolated: done on dotfiles main already archives (cmd_done moves to archive/<year>, case 090), so the defect is that a terminal ticket can reach main outside archive/ by any other path and reindex --check stays green. Behaviour, fixed. (1) reindex --check: every ticket whose status is done or cancelled and whose path is not under work-orders/archive/ is reported on stderr as 'unarchived_terminal <id> <path>', one line each, and --check exits 3 (PS_VALIDATION) after listing all of them; plain reindex (no --check) is unchanged. (2) reflow: such a ticket's home is work-orders/archive/<YYYY>/<basename>, YYYY the first 4 chars of .closed, else .updated, else .created; reflow moves it with git mv (plain mv outside git), prunes an emptied epic directory exactly as done does (prune_dir), regenerates the views, and writes no frontmatter; --dry-run lists 'archive <id> <from> -> <to>' and writes nothing; a destination that already exists and is another file: exit 3 path_collision, nothing moved. (3) done is unchanged; case 440 asserts its contract on a nested leaf. Breadcrumb at the reindex --check change naming this ticket and the business repro. Fallback: a repo that cannot run reflow yet keeps working, since only --check refuses. Rejected: making done the only fix, done already archives; rejected: reindex auto-moving files, reindex writes only generated views (SKILL.md). Cost: a repo with unarchived terminal tickets goes red on reindex --check until reflow runs there; business is reflowed by its own design seat after merge. Test case 440: (a) epic/epic/leaf in a git fixture; start, submit (stub gh), evidence, done -> leaf at work-orders/archive/2026/, closed set, prior dir pruned only when empty; (b) a ticket rewritten in place with jq to status done, closed null (the business shape) under its epic -> reindex --check exit 3, stderr has unarchived_terminal and its id; (c) reflow --dry-run lists it and git status is unchanged; (d) reflow moves it to archive/<year of .updated>/, frontmatter bytes identical, then reindex --check exit 0; (e) the same for status cancelled; (f) a collision fixture -> reflow exit 3 path_collision and nothing moved.

## Scope

**In**

- touches: claude/skills/work-order/scripts/work-order.sh (cmd_reindex --check terminal scan, cmd_reflow archive home and --dry-run line, usage lines for reindex and reflow, breadcrumb)
- touches: claude/skills/work-order/testing/cases/440-unarchived-terminal.sh (new: cases a-f in Context)
- touches: claude/skills/work-order/testing/SOP.md (one entry for case 440: what it runs, asserts and why)
- touches (generated, written only by work-order.sh start/submit/done, never by hand or git add): this ticket file and its archive path; work-orders/INDEX.md and the parent epic README.md are ignored generated views
- step: branch from origin/main in your own git worktree after WO-20261016-231a, WO-20261016-3d4d and WO-20261016-377c merged (same files, rule 19), never the ~/dotfiles primary clone; make exactly the three edits in Context
- step: run `bash claude/skills/work-order/testing/run-tests.sh` and the AC checks only; CI runs the rest
- step: commit 'fix(work-order): reindex --check refuses unarchived done tickets, reflow archives them' with the ticket id; the PR body ends with 'Bump: work-order=minor'
- tool: path:claude/skills/work-order/testing/run-tests.sh - on main; fallback: its image fails to build: stop with ENV-MISSING podman
- tool: make:Makefile:rolodex-check - on main; fallback: missing: stop with DESIGN-GAP naming it
- tool: cmd:git, cmd:jq, cmd:make, cmd:podman, cmd:gh - fallback: missing on the host: stop with ENV-MISSING naming it; gh or GitHub down: retry 3 times, then stop with A2A-003 and its output

**Out - non-goals**

- reflowing jkkelley/business or any other repo: that repo's design seat runs reflow after this merges
- cmd_done: it already archives; only case 440 covers it
- SKILL.md and references/lifecycle.md wording
- work-orders/INDEX.md and epic READMEs by hand or by git add; waiting on CI or merging: push, open the PR, write the result, leave (ORD-0542 O2)
- any file not named under In: stop with DESIGN-GAP and hand it back to infra-design (ORD-0548, item 30)

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [ ] `AC-H1` *(human)* the work-order suite passes with case 440
  - check: `bash claude/skills/work-order/testing/run-tests.sh` exit 0 expect /all cases passed/
- [ ] `AC-H2` *(human)* reindex --check names the unarchived terminal ticket
  - check: `grep -c unarchived_terminal claude/skills/work-order/scripts/work-order.sh` exit 0 expect /^[1-9]/
- [ ] `AC-H3` *(human)* SOP.md carries the case 440 entry
  - check: `grep -c 440-unarchived-terminal claude/skills/work-order/testing/SOP.md` exit 0 expect /^[1-9]/
- [ ] `AC-H4` *(human)* every changed script has a rolodex header
  - check: `make rolodex-check BASE=origin/main` exit 0
- [ ] `AC-H5` *(human)* the diff holds only In files and generated work-orders files
  - check: `bash -c '! git diff --name-only origin/main...HEAD | grep -vE "^(work-orders/.*|claude/skills/work-order/scripts/work-order[.]sh|claude/skills/work-order/testing/(SOP[.]md|cases/440-unarchived-terminal[.]sh))$"'` exit 0

## Test plan

```sh
{"scope":"done archives a nested leaf; reindex --check refuses and reflow archives a terminal ticket outside archive/","cases":[{"id":"TP-1","intent":"22 done tickets sat outside archive on business main while reindex --check passed; the check must refuse and reflow must fix it, and done must keep archiving","command":"bash claude/skills/work-order/testing/run-tests.sh","expected":"exit 0; case 440 prints ok for a-f and the existing cases still pass"},{"id":"TP-2","intent":"rolodex header kept","command":"make rolodex-check BASE=origin/main","expected":"exit 0"}],"isolation":{"runtime":"podman","image":"localhost/work-order-test:1"},"out_of_scope":["reflowing other repos"]}
```

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
