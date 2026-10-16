---
{
  "id": "WO-20261016-a428",
  "slug": "shot-mk-shot-test-and-shot-lint-run-podman-with-",
  "title": "shot.mk: shot-test and shot-lint run podman with --userns=keep-id like every other workflow container step",
  "type": "bug",
  "status": "done",
  "priority": "p2",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T10:26:20+00:00",
  "parent": "WO-20261016-35de",
  "branch": "feat/shot-mk-shot-test-and-shot-lint-run-podman-with-",
  "pr": 311,
  "closed": "2026-10-16",
  "approval": {
    "via": "override",
    "reason": "infra-design14 cut for ORD-0830 RR-orch-14 F35; design approvals ruled done, ORD-0550 O4",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [],
  "blocks": [],
  "ac_checks": [
    {
      "index": 1,
      "command": "grep -c 'podman run --rm --network=none --userns=keep-id' claude/tools/shot/shot.mk",
      "exit": 0,
      "expect": "^2$"
    },
    {
      "index": 2,
      "command": "make -f claude/tools/shot/shot.mk shot-test",
      "exit": 0,
      "expect": null
    },
    {
      "index": 3,
      "command": "git diff --name-only origin/main...HEAD | grep -vE '^(work-orders/.*|claude/tools/shot/shot\\.mk)$'",
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

# WO-20261016-a428 - shot.mk: shot-test and shot-lint run podman with --userns=keep-id like every other workflow container step

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

claude/tools/shot/shot.mk runs its two podman steps without --userns=keep-id (lines 8 and 10), unlike a2a.mk and every claude/workflow test target, so files the container writes into a mount come back owned by a subuid and the screenshot test path differs from the rest of the line.

## Owner words

> ORD-1012 W1: the podman chrome screenshot step uses --userns=keep-id (orchestrator brief BR-20261016-infra-design14)

## Context

Order ORD-1012 W1 via brief BR-20261016-infra-design14, ORD-0830 RR-orch-14; F35. Evidence: grep -n 'podman run' claude/tools/shot/shot.mk prints lines 8 and 10, neither with --userns=keep-id; claude/workflow/a2a.mk and the 8454 test command use --userns=keep-id. The change is exactly: on both lines, insert ' --userns=keep-id' right after 'podman run --rm --network=none'. Nothing else in the file changes.

## Scope

**In**

- touches: claude/tools/shot/shot.mk (lines 8 and 10 only, as in Context)
- touches (generated, written only by work-order.sh start/submit/done, never by hand or git add): this ticket file and its archive path; work-orders/INDEX.md and the parent epic README.md are ignored generated views
- step: branch from origin/main in your own git worktree, never the ~/dotfiles primary clone
- step: make the two-line edit; run make -f claude/tools/shot/shot.mk shot-test and shot-lint and the AC checks only
- step: commit 'fix(tools): shot podman steps run with --userns=keep-id' with the ticket id; no Bump trailer
- tool: make:claude/tools/shot/shot.mk:shot-test - on main; tool: image localhost/dotfiles-workflow-test:1 - fallback: missing: make -C claude/workflow image, then retry once; build fails: stop with ENV-MISSING podman
- tool: cmd:git, cmd:jq, cmd:make, cmd:podman, cmd:gh - fallback: missing on the host: stop with ENV-MISSING naming it; gh or GitHub down: retry 3 times, then stop with A2A-003 and its output

**Out - non-goals**

- shot.sh, its test, its README: unchanged
- any file not named under In: stop with DESIGN-GAP
- work-orders/INDEX.md and epic READMEs by hand or by git add; waiting on CI or merging: push, open the PR, write the result, leave
- a Bump trailer: no skill under claude/skills changes

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [x] `AC-H1` *(human)* both podman lines carry --userns=keep-id
  - observed `2026-10-16` grep -c prints 2, exit 0
  - check: `grep -c 'podman run --rm --network=none --userns=keep-id' claude/tools/shot/shot.mk` exit 0 expect /^2$/
- [x] `AC-H2` *(human)* the shot test passes under keep-id
  - observed `2026-10-16` make shot-test pass=8 fail=0, exit 0
  - check: `make -f claude/tools/shot/shot.mk shot-test` exit 0
- [x] `AC-H3` *(human)* the diff holds only In files and generated work-orders files
  - observed `2026-10-16` diff names only shot.mk plus work-orders; grep -v exit 1
  - check: `git diff --name-only origin/main...HEAD | grep -vE '^(work-orders/.*|claude/tools/shot/shot\.mk)$'` exit 1

## Test plan

```sh
{"scope":"shot.mk shot-test and shot-lint under --userns=keep-id","cases":[{"id":"TP-1","intent":"the screenshot step must run like every other container step or its mounts change owner","command":"make -f claude/tools/shot/shot.mk shot-test","expected":"exit 0"},{"id":"TP-2","intent":"lint still runs under keep-id","command":"make -f claude/tools/shot/shot.mk shot-lint","expected":"exit 0"}],"isolation":{"runtime":"podman","image":"localhost/dotfiles-workflow-test:1"},"out_of_scope":["chrome rendering itself: unchanged"]}
```

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
