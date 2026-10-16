---
{
  "id": "WO-20261016-3327",
  "slug": "main-clone-guard-sh-check-and-ff-a-primary-clone",
  "title": "main-clone-guard.sh check and ff: a primary clone is on main and fast-forwarded, else MAIN-DRIFT exit 3 (make -f main-clone.mk)",
  "type": "feature",
  "status": "ready",
  "priority": "p0",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T10:07:12+00:00",
  "parent": "WO-20261016-4b6c",
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
      "expect": "ok  main-clone-guard: 8 cases"
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
    }
  ],
  "provides": [
    "make:main-clone-test",
    "path:claude/workflow/bin/main-clone-guard.sh",
    "path:claude/workflow/tests/unit/test_main_clone_guard.sh"
  ],
  "labels": [
    "line:inbox-triage"
  ]
}
---

# WO-20261016-3327 - main-clone-guard.sh check and ff: a primary clone is on main and fast-forwarded, else MAIN-DRIFT exit 3 (make -f main-clone.mk)

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

Nothing checks that the ~/dotfiles primary clone stays on main. Seat dag-t6b ran work-order.sh start for WO-20261016-efb2 inside it and left it on feat/dag-state-t6 at c7bd763 for 40+ minutes; every seat calling ~/dotfiles tools ran stale code (wr2-feed ENV-MISSING on claude/tools/shot). seat-up, the line sweep and brief checks need one generic, config-driven tool that says whether a clone is on its branch and current, and fast-forwards it when that is safe.

## Owner words

> seat dag-t6b ran work-order.sh start inside the ~/dotfiles main clone ... every seat calling ~/dotfiles tools ran stale code (brief BR-20261016-infra-design13, ORD-0830 RR-orch-14)

> if the task or job needs tools, the architect has a design agent build that shit out before the ticket goes in, thats a prereq for the ticket ready then (Design principles 101 item 30)

> Have fallbacks too (Design principles 101 item 28)

## Context

Order ORD-0830 RR-orch-14, brief BR-20261016-infra-design13 item DESIGN-GAP main clone drift. Evidence: ~/.local/state/zenith/breakglass/2026/10/20261016-095436-main-clone-efb2-start-stamp.patch and seats/wr2-feed.result.json (ENV-MISSING on claude/tools/shot while ~/dotfiles sat on feat/dag-state-t6 at c7bd763 for 40+ min). This is the tooling ticket the seat-up, line-sweep and brief tickets depend on (item 30: tools on main first).

Behaviour, fixed. main-clone-guard.sh VERB CLONE [BRANCH] [REMOTE]; VERB is check or ff, BRANCH defaults to main, REMOTE to origin; no other inputs. (1) CLONE is not a git work tree: stdout 'skip main-clone CLONE: not a git clone', exit 0. (2) git -C CLONE fetch -q REMOTE BRANCH under timeout 30; on failure stderr 'warn main-clone fetch failed, using last fetched REMOTE/BRANCH' and continue. (3) current branch is not BRANCH (detached counts): stdout 'MAIN-DRIFT CLONE on CUR at SHORTSHA, want BRANCH' (CUR is the branch name or detached), exit 3; ff never switches branches. (4) N = git rev-list --count HEAD..REMOTE/BRANCH. check: N>0 prints 'MAIN-DRIFT CLONE behind REMOTE/BRANCH by N' exit 3, else 'ok main-clone CLONE BRANCH SHORTSHA' exit 0. (5) ff: N=0 prints the same ok line, exit 0 (idempotent); N>0 with tracked changes (git status --porcelain --untracked-files=no not empty) prints 'MAIN-DRIFT CLONE dirty, cannot fast-forward' exit 3; N>0 clean runs git merge --ff-only -q REMOTE/BRANCH and prints 'ok main-clone CLONE fast-forwarded OLD..NEW' exit 0, or on failure 'MAIN-DRIFT CLONE diverged from REMOTE/BRANCH' exit 3. (6) wrong arguments: usage on stderr, exit 2. The script carries the repo's rolodex header and a breadcrumb naming this ticket and the breakglass patch path.

main-clone.mk is standalone like claude/workflow/a2a.mk (run as make -C claude/workflow -f main-clone.mk TARGET), copies a2a.mk's TIMED line and podman line: main-clone-check CLONE= [BRANCH=main] [REMOTE=origin] and main-clone-ff (same vars) run the script on the host (they are the tool); main-clone-test runs shellcheck -x on the script and the test, then the test, in localhost/dotfiles-workflow-test:1 with --network=none. The test builds a bare remote and clones in mktemp, prints 'ok (N) ...' per case and ends with exactly 'ok main-clone-guard: 8 cases'. Cases: 1 up to date check 0 ok; 2 behind by 1: check 3 'behind origin/main by 1', ff 0 'fast-forwarded', ff again 0 ok, check 0; 3 on branch feat: check 3 'on feat', ff 3 and HEAD still feat; 4 behind with a modified tracked file: ff 3 'dirty'; 5 diverged: ff 3 'diverged'; 6 remote path removed: check prints the fetch warn on stderr and still answers from the local ref; 7 non-git dir: 0 'skip main-clone'; 8 no arguments: exit 2.

README rows, appended to the status map table in claude/workflow/templates/a2a/README.md: '| MAIN-DRIFT | main-clone-guard.sh: a primary clone is off its branch, behind, dirty or diverged, so every seat calling its tools runs stale code | orchestrator breaks glass back to main (item 33) and finds the seat that ran start there; seat-up refuses until it clears |' and '| LW-MAIN-DRIFT | the line sweep saw MAIN-DRIFT on the primary clone (one event per new drift line) | orchestrator, as MAIN-DRIFT |'.

## Scope

**In**

- touches: claude/workflow/bin/main-clone-guard.sh (new, behaviour in Context)
- touches: claude/workflow/main-clone.mk (new, standalone; targets main-clone-check, main-clone-ff, main-clone-test)
- touches: claude/workflow/tests/unit/test_main_clone_guard.sh (new, the 8 cases in Context)
- touches: claude/workflow/templates/a2a/README.md (the two status map rows in Context, nothing else)
- touches (generated, written only by work-order.sh start/submit/done, never by hand or git add): this ticket file and its archive path; work-orders/INDEX.md and the parent epic README.md are ignored generated views
- step: branch from origin/main in your own git worktree, never the ~/dotfiles primary clone; write the three new files and the two rows exactly as in Context
- step: run `make -C claude/workflow -f main-clone.mk main-clone-test` and `make rolodex-check BASE=origin/main` and the AC checks only; CI runs the rest
- step: commit 'feat(workflow): main-clone-guard.sh keeps a primary clone on main' with the ticket id; no Bump trailer (no skill changed)
- tool: make:claude/workflow/main-clone.mk:main-clone-test - built by this ticket; fallback: image localhost/dotfiles-workflow-test:1 missing: make -C claude/workflow image, then retry; build fails: stop with ENV-MISSING podman
- tool: make:Makefile:rolodex-check - on main; fallback: missing: stop with DESIGN-GAP naming it
- tool: cmd:git, cmd:jq, cmd:make, cmd:podman, cmd:gh - fallback: missing on the host: stop with ENV-MISSING naming it; gh or GitHub down: retry 3 times, then stop with A2A-003 and its output

**Out - non-goals**

- calling the guard from seat-up, the sweep, brief.sh or work-order.sh: separate tickets
- switching, resetting or stashing a clone: the guard only reports and fast-forwards
- claude/workflow/Makefile: no include, the .mk is standalone
- work-orders/INDEX.md and epic READMEs by hand or by git add; waiting on CI or merging: push, open the PR, write the result, leave
- any file not named under In: stop with DESIGN-GAP

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [ ] `AC-H1` *(human)* the guard's 8 cases pass in podman
  - check: `make -C claude/workflow -f main-clone.mk main-clone-test` exit 0 expect /ok main-clone-guard: 8 cases/
- [ ] `AC-H2` *(human)* every changed script has a rolodex header
  - check: `make rolodex-check BASE=origin/main` exit 0
- [ ] `AC-H3` *(human)* the status map carries MAIN-DRIFT and LW-MAIN-DRIFT
  - check: `grep -cE '^\| (LW-)?MAIN-DRIFT \|' claude/workflow/templates/a2a/README.md` exit 0 expect /^2$/
- [ ] `AC-H4` *(human)* the diff holds only In files and generated work-orders files
  - check: `git diff --name-only origin/main...HEAD | grep -vE '^(work-orders/.*|claude/workflow/(bin/main-clone-guard\.sh|main-clone\.mk|tests/unit/test_main_clone_guard\.sh|templates/a2a/README\.md))$'` exit 1

## Test plan

```sh
{"scope":"main-clone-guard.sh check and ff against a fixture bare remote","cases":[{"id":"TP-1","intent":"~/dotfiles sat on feat/dag-state-t6 for 40+ min and nothing noticed; the guard must say MAIN-DRIFT, fast-forward only when safe, and never switch a branch","command":"make -C claude/workflow -f main-clone.mk main-clone-test","expected":"exit 0; 8 ok lines, last 'ok main-clone-guard: 8 cases'"},{"id":"TP-2","intent":"the new script carries its rolodex header","command":"make rolodex-check BASE=origin/main","expected":"exit 0"}],"isolation":{"runtime":"podman","image":"localhost/dotfiles-workflow-test:1"},"out_of_scope":["seat-up, sweep and brief wiring: their own tickets","the full workflow suite: CI runs it"]}
```

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
