---
{
  "id": "WO-20261016-b0ed",
  "slug": "seat-up-workflow-spawn-sh-installs-the-pre-push-",
  "title": "seat-up: workflow-spawn.sh installs the pre-push hook in every seat worktree it leases or reuses",
  "type": "feature",
  "status": "in-review",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T08:28:20+00:00",
  "parent": "WO-20261016-ebe4",
  "branch": "feat/seat-up-workflow-spawn-sh-installs-the-pre-push-",
  "pr": 264,
  "closed": null,
  "approval": {
    "via": "override",
    "reason": "infra-design6 cut for ORD-0814 P1 P2; design approvals ruled done, ORD-0550 O4",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [
    "WO-20261016-5222"
  ],
  "blocks": [
    "WO-20261016-4814"
  ],
  "ac_checks": [
    {
      "index": 1,
      "command": "make -C claude/workflow lease",
      "exit": 0,
      "expect": "ok  treehouse-lease"
    },
    {
      "index": 2,
      "command": "make -C claude/workflow lint",
      "exit": 0,
      "expect": null
    },
    {
      "index": 3,
      "command": "grep -c pre-push/pre-push.sh claude/workflow/bin/workflow-spawn.sh",
      "exit": 0,
      "expect": "^1$"
    },
    {
      "index": 4,
      "command": "make rolodex-check BASE=origin/main",
      "exit": 0,
      "expect": null
    },
    {
      "index": 5,
      "command": "bash -c \\!\\ git\\ diff\\ --name-only\\ origin/main...HEAD\\ \\|\\ grep\\ -vE\\ \\'\\^\\(work-orders/\\|claude/workflow/\\(bin/workflow-spawn\\\\.sh\\|tests/unit/test_treehouse_lease\\\\.sh\\)\\)\\$\\'",
      "exit": 0,
      "expect": null
    }
  ],
  "provides": []
}
---

# WO-20261016-b0ed - seat-up: workflow-spawn.sh installs the pre-push hook in every seat worktree it leases or reuses

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

A seat worktree has no pre-push hook, so a seat pushes red to CI. This is the seat-up half of ORD-0814 P1.

## Owner words

> ORD-0814 P1: "cut the tooling ticket: make pre-push in dotfiles runs every fast gate on the changed files in under 30 s (rolodex-check, md-contents-check, tracked-ignored-check, bump-gate resolve against the PR body draft, a2a-lint, spec-check); seat-up installs it as a git pre-push hook in every seat worktree, and the work-order template adds it as the last checklist box before submit."

## Context

Evidence 2026-10-16 08:00-08:15Z: PRs 216, 219, 225, 234 red on headers or tracked-ignored-check; 213, 219, 210 red on bump intent. Each red costs a CI round and a seat; every one of those gates is local and fast.

Inventory: claude/workflow/Makefile seat-up only places a herdr pane (bin/herdr-grid.sh); the seat worktree is set in claude/workflow/bin/workflow-spawn.sh in the block from repo_root= down to the herdr section (a reused lease, an existing directory, or a fresh treehouse lease), so the install goes right after that block, through the spawner run wrapper so --dry-run prints it. claude/workflow/tests/unit/test_treehouse_lease.sh drives that block with a stub treehouse and herdr (make -C claude/workflow lease). No ready ticket touches either file.

Inserted code, exactly, directly before the line "# ---- herdr: rediscover every id": a BREADCRUMB 2026-10-16 comment (ORD-0814 P1: every seat worktree gets the dotfiles pre-push hook so a red gate fails in the seat, not in CI; evidence PRs 216, 219, 225, 234, 213, 210; rejected: a global core.hooksPath, which would hook every repository on the host; cost: one script call per spawn; fallback: a missing script prints PREPUSH-SKIP and the seat starts), then: pp="$(dirname "$(readlink -f "$0")")/../pre-push/pre-push.sh" and: if [ -f "$pp" ]; then run bash "$pp" install --repo "$worktree" || printf "seat %s: PREPUSH-HOOK-FAIL %s\n" "$name" "$worktree" >&2; else printf "seat %s: PREPUSH-SKIP NO-TOOL %s\n" "$name" "$pp" >&2; fi

## Scope

**In**

- touches: claude/workflow/bin/workflow-spawn.sh
- touches: claude/workflow/tests/unit/test_treehouse_lease.sh
- touches (generated, written only by work-order.sh start/submit/done, never by hand): work-orders/INDEX.md, this ticket file and its archive path, work-orders/WO-20261016-ebe4/README.md
- step: start only after the tooling ticket is done and merged; branch from origin/main
- step: workflow-spawn.sh: insert the code in Context; nothing else changes
- step: test_treehouse_lease.sh: after the first has block (fresh lease) add: has "the fresh slot gets the pre-push hook" "pre-push.sh install --repo \\<treehouse-slot\\>" "$out"; after the block that checks "a rerun reuses the slot" add: has "a reused slot gets the pre-push hook too" "pre-push.sh install --repo /pool/3/dotfiles" "$out"; nothing else changes
- step: run only TP-1, TP-2 and the AC checks; CI runs the rest
- tool: path:claude/workflow/pre-push/pre-push.sh install - lands with the tooling ticket; fallback: missing on main: stop with DESIGN-GAP naming it; at runtime a missing script prints PREPUSH-SKIP NO-TOOL and the seat still starts
- tool: make:claude/workflow/Makefile:lease and lint - on main; fallback: missing: stop with DESIGN-GAP naming it
- tool: cmd:git, cmd:jq, cmd:make, cmd:podman - fallback: missing on the host: stop with ENV-MISSING naming it
- tool: make:Makefile:rolodex-check - on main; fallback: missing: stop with DESIGN-GAP naming it

**Out - non-goals**

- claude/workflow/bin/herdr-grid.sh and the seat-up Make target: the pane is not the worktree
- removing the hook at seat-down: the hook lives in the clone common dir shared by every slot and is idempotent; make pre-push-uninstall REPO= is the cleanup verb
- any file not named under In: stop with DESIGN-GAP

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [x] `AC-H1` *(human)* the lease suite passes with the two new checks
  - observed `2026-10-16` check: make -C claude/workflow lease exit 0 output: make: Entering directory '/home/luna/.cache/wt-prepush-hook/claude/workflow' ok image: localhost/dotfiles-workflow-test:1 ok no slot and no directory: the seat leases one, as holder ok the lease asks for JSON so the path is read, not guessed ok git worktree add is gone ok the seat's gate watcher runs in the leased slot ok the fresh slot gets the pre-push hook ok a rerun reuses the slot the seat already leases ok and takes no second slot ok another holder's slot is never taken over ok a reused slot gets the pre-push hook too ok an existing configured directory is still used as is ok and no slot is leased beside it ok no treehouse refuses loudly, no fallback ok treehouse-lease: 12 checks make: Leaving directory '/home/luna/.cache/wt-prepush-hook/claude/workflow'
  - check: `make -C claude/workflow lease` exit 0 expect /ok treehouse-lease/
- [x] `AC-H2` *(human)* the spawner stays shellcheck clean
  - observed `2026-10-16` check: make -C claude/workflow lint exit 0 output: make: Entering directory '/home/luna/.cache/wt-prepush-hook/claude/workflow' ok image: localhost/dotfiles-workflow-test:1 make: Leaving directory '/home/luna/.cache/wt-prepush-hook/claude/workflow'
  - check: `make -C claude/workflow lint` exit 0
- [x] `AC-H3` *(human)* the spawner calls the install exactly once
  - observed `2026-10-16` check: grep -c pre-push/pre-push.sh claude/workflow/bin/workflow-spawn.sh exit 0 output: 1
  - check: `grep -c pre-push/pre-push.sh claude/workflow/bin/workflow-spawn.sh` exit 0 expect /^1$/
- [x] `AC-H4` *(human)* every changed script has a rolodex header
  - observed `2026-10-16` check: make rolodex-check BASE=origin/main exit 0 output: python3 scripts/rolodex.py check --root . --base origin/main rolodex-check: 0 script(s) checked, all have headers
  - check: `make rolodex-check BASE=origin/main` exit 0
- [ ] `AC-H5` *(human)* the diff holds only In files and generated work-orders files
  - check: `bash -c \!\ git\ diff\ --name-only\ origin/main...HEAD\ \|\ grep\ -vE\ \'\^\(work-orders/\|claude/workflow/\(bin/workflow-spawn\\.sh\|tests/unit/test_treehouse_lease\\.sh\)\)\$\'` exit 0

## Test plan

_Test plan from claude/workflow/templates/test-plan.md, shaped by claude/workflow/schemas/test-plan.schema.json. The tester runs exactly these cases and nothing else._

**Scope under test**

the pre-push hook install step in claude/workflow/bin/workflow-spawn.sh

**Cases**

- `TP-1`
  - intent: every seat worktree gets the hook at seat-up, so no seat pushes red to CI (order ORD-0814 P1)
  - command: `make -C claude/workflow lease`
  - expected: exit 0; prints `ok  treehouse-lease`; the new checks see `pre-push.sh install --repo \<treehouse-slot\>` on a fresh lease and `pre-push.sh install --repo /pool/3/dotfiles` on a reused one
- `TP-2`
  - intent: the spawner stays shellcheck clean
  - command: `make -C claude/workflow lint`
  - expected: exit 0

**Isolation**

- runtime: podman
- image: `docker.io/library/debian:bookworm-slim@sha256:3783cc01769c7b2b1b83a5c5ad96c815348e28ed7da68e2e3687004faa906251` (debian:bookworm-slim, base of localhost/dotfiles-workflow-test:1)

**Out of scope - CI covers**

- a real herdr seat start: the P1 test ticket covers it at UAT

## Assumptions

1. treehouse slots are worktrees or clones whose git-path hooks/pre-push resolves inside the slot common dir; install there covers every slot of that clone, which is the wanted scope

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
