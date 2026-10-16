---
{
  "id": "WO-20261016-f82b",
  "slug": "claude-workflow-makefile-run-runs-the-locally-bu",
  "title": "claude/workflow Makefile RUN runs the locally built test image with --pull=never (RR-orch-18)",
  "type": "chore",
  "status": "ready",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T09:07:16+00:00",
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
  "depends_on": [],
  "blocks": [],
  "ac_checks": [
    {
      "index": 1,
      "command": "grep -c -- --pull=never claude/workflow/Makefile",
      "exit": 0,
      "expect": "^[1-9]"
    },
    {
      "index": 2,
      "command": "make -C claude/workflow test-plan",
      "exit": 0,
      "expect": null
    },
    {
      "index": 3,
      "command": "bash -c '! git diff --name-only origin/main...HEAD | grep -vE \"^(work-orders/|claude/workflow/Makefile)$\"'",
      "exit": 0,
      "expect": null
    }
  ],
  "provides": []
}
---

# WO-20261016-f82b - claude/workflow Makefile RUN runs the locally built test image with --pull=never (RR-orch-18)

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

claude/workflow/Makefile line 8 RUN starts localhost/dotfiles-workflow-test:1 with podman's default pull policy (missing), so an absent image triggers a registry lookup for a name only this machine builds. The ruling says the Make target builds the image from the digest-pinned FROM and runs it with --pull=never.

## Owner words

> Pin every version. No floating tags. (dotfiles CLAUDE.md Rule 15)

## Context

Architect ruling RR-orch-18, 2026-10-16: a locally built image is never pinned by digest. Evidence: ~/.local/state/zenith/log/2026/10/20261016-080957-t21e-cards-uat-digest.txt (UAT cards suite run on pinned image 0a6832bb, image id f4d2d4c03c76): a localhost digest names one build on one machine; every rebuild of claude/workflow/tests/container/Containerfile mints a new digest, so a plan pinned to it stops resolving (11 plans pinned 0a6832bb, 2 still live as drafts). What Rule 15 protects is the base: the Containerfile FROM is pinned by digest, so the tag plus the build target plus the pinned FROM is reproducible, and --pull=never makes a missing image a loud error instead of a registry lookup.

Depends on WO-20261016-f4a0 - Bearings server for a live line runs as systemd user unit bearings-line@<line>, Restart=always, idle stop off, brought up by make line-up (ORD-0832 B1), which also touches claude/workflow/Makefile (item 19: no two concurrent tickets on one file).

## Scope

**In**

- step: precondition, before branching: `bash -c 'git fetch -q origin && git ls-tree -r --name-only origin/main work-orders/archive | grep -q WO-20261016-f4a0-'` exits 0 (that ticket is done on main); else stop with BLOCKED naming it
- touches: claude/workflow/Makefile (line 8 RUN: insert --pull=never after 'podman run --rm'; a breadcrumb comment above it citing RR-orch-18)
- touches (generated, written only by work-order.sh start/submit/done, never by hand or git add): this ticket file and its archive path; work-orders/INDEX.md and the parent epic README.md are ignored generated views
- step: branch from origin/main in your own worktree after WO-20261016-f4a0 merged; make the one-line edit
- step: run `make -C claude/workflow test-plan` and the AC checks; commit 'chore(workflow): run the local test image with --pull=never (RR-orch-18)'; no Bump trailer (no file under claude/skills changes)
- tool: cmd:git, cmd:jq, cmd:make, cmd:podman, cmd:gh - fallback: missing on the host: stop with ENV-MISSING naming it; gh or GitHub down: retry 3 times, then stop with A2A-003 and its output
- tool: make:claude/workflow/Makefile:test-plan - on main; fallback: missing: stop with DESIGN-GAP naming it

**Out - non-goals**

- any other mk file under claude/workflow: pr-flow.mk is held by WO-20261016-fb99, WO-20261016-448e and WO-20261016-73f2
- work-orders/INDEX.md and epic READMEs by hand or by git add: they are ignored generated views
- waiting on CI or merging: push, open the PR, write the result, leave (ORD-0542 O2)
- any file not named under In: stop with DESIGN-GAP and hand it back to infra-design (ORD-0548, item 30)

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [ ] `AC-H1` *(human)* RUN carries --pull=never
  - check: `grep -c -- --pull=never claude/workflow/Makefile` exit 0 expect /^[1-9]/
- [ ] `AC-H2` *(human)* the targets still run
  - check: `make -C claude/workflow test-plan` exit 0
- [ ] `AC-H3` *(human)* the diff holds only In files and generated work-orders files
  - check: `bash -c '! git diff --name-only origin/main...HEAD | grep -vE "^(work-orders/|claude/workflow/Makefile)$"'` exit 0

## Test plan

_Test plan from claude/workflow/templates/test-plan.md, shaped by claude/workflow/schemas/test-plan.schema.json. The tester runs exactly these cases and nothing else._

**Scope under test**

claude/workflow/Makefile RUN: every claude/workflow test target runs localhost/dotfiles-workflow-test:1 with --pull=never

**Cases**

- `TP-1`
  - intent: a locally built image is never pulled; --pull=never makes a missing image a loud error instead of a registry lookup (RR-orch-18 ruling)
  - command: `grep -c -- '--pull=never' claude/workflow/Makefile`
  - expected: exit 0; prints 1 or more
- `TP-2`
  - intent: the targets still run through RUN after the flag is added
  - command: `make -C claude/workflow test-plan`
  - expected: exit 0
- `TP-3`
  - intent: with the image absent the run fails loud instead of pulling
  - command: `bash -c 'podman image exists localhost/no-such-image:1 && exit 9; podman run --rm --pull=never localhost/no-such-image:1 true; test $? -ne 0'`
  - expected: exit 0

**Isolation**

- runtime: podman
- image: `localhost/dotfiles-workflow-test:1`
- build: `make -C claude/workflow image`
- containerfile: `claude/workflow/tests/container/Containerfile`

**Out of scope - CI covers**

- the full claude/workflow suite: CI runs make -C claude/workflow test

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
