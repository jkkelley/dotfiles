---
{
  "id": "WO-20261016-2ffe",
  "slug": "make-pr-regen-index-repo-branches-regen-merge-sh",
  "title": "make pr-regen-index REPO= BRANCHES=: regen-merge.sh ported as the index-regen fallback",
  "type": "feature",
  "status": "in-progress",
  "priority": "p0",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T06:05:25+00:00",
  "parent": "WO-20261016-0272",
  "branch": "feat/2ffe-make-pr-regen-index-repo-branches-regen-merge-sh",
  "pr": null,
  "closed": null,
  "approval": {
    "via": "override",
    "reason": "architect ruled design approvals done, ORD-0550 O4",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [
    "WO-20261016-1c04"
  ],
  "blocks": [
    "WO-20261016-fa85",
    "WO-20261016-6630"
  ],
  "labels": [
    "line:inbox-triage"
  ]
}
---

# WO-20261016-2ffe - make pr-regen-index REPO= BRANCHES=: regen-merge.sh ported as the index-regen fallback

## Contents

- Problem
- Scope
- Degrees of freedom
- Acceptance criteria
- Test plan
- Assumptions
- Open questions
- Notes
- Outcome

## Problem

ORD-0553 R7: "dotfiles #170 #178 #185 index conflicts cleared by architect break glass (log/2026/10/20261016-055223-breakglass-index-regen.md). Raise the index-regen Action to L0 top. Port ~/.local/share/zenith-architect/regen-merge.sh into dotfiles as make pr-regen-index REPO= BRANCHES= as its declared fallback." ORD-0554 U4: "fallback until it lands: regen-merge.sh".

## Scope

**In**

- touches: scripts/pr-regen-index.sh
- touches: scripts/tests/test_pr_regen_index.sh
- touches: Makefile
- step: copy ~/.local/share/zenith-architect/regen-merge.sh to scripts/pr-regen-index.sh with: flags `--repo DIR --branches "a b"`, `zwo` replaced by `bash <dotfiles>/claude/skills/work-order/scripts/work-order.sh`, worktrees under `${TMPDIR:-/tmp}`, a rolodex header, the status codes kept (CLEAN-MERGE REGEN CONFLICT-REAL WT-FAIL PUSH-FAIL), and a breadcrumb naming the break glass log
- step: root Makefile: `pr-regen-index: ## make pr-regen-index REPO=<dir> BRANCHES="<b> ..."`
- step: test: a bare remote, main and a branch both changing work-orders/INDEX.md (REGEN), and a branch changing a real file both sides (CONFLICT-REAL); run `make -C claude/workflow image && podman run --rm --network=none --userns=keep-id -v "$PWD:/work:Z" -w /work -e HOME=/tmp localhost/dotfiles-workflow-test:1 bash -c 'bash scripts/tests/test_pr_regen_index.sh'`
- tool: path:claude/workflow/tests/container/Containerfile - on main; fallback: no fallback permitted (dotfiles Rule 14, never the host): podman or the image missing stops the node with ENV-MISSING podman
- tool: path:claude/skills/work-order/scripts/work-order.sh - on main; fallback: no fallback: work-order.sh missing or failing stops with DESIGN-GAP

**Out - non-goals**

- work-orders/INDEX.md by hand: work-order.sh writes it, and the reindex Action is owned by merge-port-build (F11, ORD-0545 O1)
- waiting on CI or merging: push, open the PR, write the result, leave (ORD-0542 O2)
- any file not named under In: stop with DESIGN-GAP and hand it back to infra-design (ORD-0548, item 30)

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [x] `AC-H1` *(human)* `make -C claude/workflow image && podman run --rm --network=none --userns=keep-id -v "$PWD:/work:Z" -w /work -e HOME=/tmp localhost/dotfiles-workflow-test:1 bash -c 'bash scripts/tests/test_pr_regen_index.sh'` exits 0 and its output matches /ok index-only conflict is REGEN and pushed/ (proof: command, exit code and output pasted by work-order.sh evidence; ORD-0552 O2)
  - observed `2026-10-16` run in podman: exit 0, output matched; see test_pr_regen_index.sh ok lines
- [x] `AC-H2` *(human)* `make -C claude/workflow image && podman run --rm --network=none --userns=keep-id -v "$PWD:/work:Z" -w /work -e HOME=/tmp localhost/dotfiles-workflow-test:1 bash -c 'bash scripts/tests/test_pr_regen_index.sh'` exits 0 and its output matches /ok a real conflict aborts with CONFLICT-REAL/ (proof: command, exit code and output pasted by work-order.sh evidence; ORD-0552 O2)
  - observed `2026-10-16` run in podman: exit 0, output matched; see test_pr_regen_index.sh ok lines

## Test plan

_Test plan from claude/workflow/templates/test-plan.md, shaped by claude/workflow/schemas/test-plan.schema.json. The tester runs exactly these cases and nothing else._

**Scope under test**

scripts/pr-regen-index.sh against a bare remote

**Cases**

- `TP-1`
  - intent: index-only conflicts stall every ticket PR (F11)
  - command: `make -C claude/workflow image && podman run --rm --network=none --userns=keep-id -v "$PWD:/work:Z" -w /work -e HOME=/tmp localhost/dotfiles-workflow-test:1 bash -c 'bash scripts/tests/test_pr_regen_index.sh'`
  - expected: exit 0; prints `ok  index-only conflict is REGEN and pushed`
- `TP-2`
  - intent: a real conflict must never be auto-resolved
  - command: `make -C claude/workflow image && podman run --rm --network=none --userns=keep-id -v "$PWD:/work:Z" -w /work -e HOME=/tmp localhost/dotfiles-workflow-test:1 bash -c 'bash scripts/tests/test_pr_regen_index.sh'`
  - expected: exit 0; prints `ok  a real conflict aborts with CONFLICT-REAL`

**Isolation**

- runtime: podman
- image: `docker.io/library/debian:bookworm-slim@sha256:3783cc01769c7b2b1b83a5c5ad96c815348e28ed7da68e2e3687004faa906251` (debian:bookworm-slim, base of localhost/dotfiles-workflow-test:1)

**Out of scope - CI covers**

- the full scripts suite

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
