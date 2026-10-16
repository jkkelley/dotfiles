---
{
  "id": "WO-20261016-df39",
  "slug": "pr-sweep-sh-merge-every-clean-approved-pr-one-fi",
  "title": "pr-sweep.sh: merge every clean approved PR, one fix work order per red one",
  "type": "feature",
  "status": "ready",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T06:06:22+00:00",
  "parent": "WO-20261016-f69a",
  "branch": null,
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
    "WO-20261016-5504",
    "WO-20261016-f5dd"
  ],
  "blocks": [
    "WO-20261016-1256",
    "WO-20261016-ca8c"
  ]
}
---

# WO-20261016-df39 - pr-sweep.sh: merge every clean approved PR, one fix work order per red one

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

Owner, 2026-10-16 UTC: "WE HAVE BUSINESS PRS EVERYWHERE", "WE NEED THINGS INDEXED". Evidence 05:55Z: 75 open PRs across 38 repos of jkkelley; 28 are 'docs: golden system design rules' from make golden-rules-repos; generic-agents-auto-workflow holds 16; nothing lists them in one place. Brief BR-20261016-pr-index: "make pr-sweep OWNER= DRY=1: merges every PR that is mergeable with no failing or pending check and whose source is approved work (golden-rules, seat PRs); a red or conflicted PR becomes one fix work order for its repo's seat; idempotent; times every merge to the bus". Reuse: the architect's merge1.sh rule (MERGEABLE, 0 failing, 0 pending).

## Scope

**In**

- touches: scripts/pr-sweep.sh
- touches: scripts/tests/test_pr_sweep.sh
- touches: Makefile
- step: pr-sweep.sh [--config config/pr-index.json] [--dry-run]: read `<store>/latest.json` (run pr-index.sh first when older than 5 min)
- step: merge when waits_on is none and source is golden-rules or seat: dry-run prints `MERGE <repo>#<n>`; else `bash claude/workflow/bin/timed-run.sh --node pr-<repo name>-<n> --kind merge -- gh pr merge -R <repo> <n> --squash --delete-branch` and prints `MERGED <repo>#<n>` or `MERGE-FAILED <repo>#<n>`
- step: red (waits_on conflict or ci-failing): ensure one ticket titled `PR fix: <repo>#<n> <waits_on>` in the work-order project `~/.local/state/zenith/pr-fix` (git-initialised once, one top-level epic `PR fixes from pr-sweep`, the same pattern as timing/lib.sh wo_project); an existing open ticket with that title is left alone; prints `FILED` or `HAS-WO`
- step: everything else prints `SKIP <repo>#<n> <waits_on>`
- step: root Makefile: targets `pr-index: ## make pr-index OWNER=` and `pr-sweep: ## make pr-sweep OWNER= DRY=1` and `pr-index-test`, each recipe through $(TIMED)
- step: run `make -C claude/workflow image && podman run --rm --network=none --userns=keep-id -v "$PWD:/work:Z" -w /work -e HOME=/tmp localhost/dotfiles-workflow-test:1 bash -c 'bash scripts/tests/test_pr_sweep.sh'`
- tool: path:claude/workflow/tests/container/Containerfile - on main; fallback: no fallback permitted (dotfiles Rule 14, never the host): podman or the image missing stops the node with ENV-MISSING podman
- tool: path:claude/workflow/bin/timed-run.sh - on main; fallback: bus down: timed-run warns `WARN bus unreachable` and the step runs with its own exit code (tm_event); covered by the bus-down case
- tool: cmd:gh - on main; fallback: gh or GitHub down: retry 3 times, then stop with A2A-003 and the gh error in the result blockers

**Out - non-goals**

- work-orders/INDEX.md by hand: work-order.sh writes it, and the reindex Action is owned by merge-port-build (F11, ORD-0545 O1)
- waiting on CI or merging: push, open the PR, write the result, leave (ORD-0542 O2)
- any file not named under In: stop with DESIGN-GAP and hand it back to infra-design (ORD-0548, item 30)

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [ ] `AC-H1` *(human)* the test exits 0 and prints `ok a clean seat PR is merged once through timed-run` (proof: command, exit code and output pasted by work-order.sh evidence; ORD-0552 O2)
- [ ] `AC-H2` *(human)* the same run prints `ok a conflicted PR files one fix work order and a rerun files none` and `ok DRY=1 merges nothing` (proof: command, exit code and output pasted by work-order.sh evidence; ORD-0552 O2)
- [ ] `AC-H3` *(human)* UAT: `make pr-sweep OWNER=jkkelley DRY=1` prints one status line per open PR and exits 0 (proof: command, exit code and output pasted by work-order.sh evidence; ORD-0552 O2)

## Test plan

_Test plan from claude/workflow/templates/test-plan.md, shaped by claude/workflow/schemas/test-plan.schema.json. The tester runs exactly these cases and nothing else._

**Scope under test**

scripts/pr-sweep.sh against a fixture latest.json, stub gh and a temp work-order project

**Cases**

- `TP-1`
  - intent: green approved PRs parked under agents are dead code (item 21)
  - command: `make -C claude/workflow image && podman run --rm --network=none --userns=keep-id -v "$PWD:/work:Z" -w /work -e HOME=/tmp localhost/dotfiles-workflow-test:1 bash -c 'bash scripts/tests/test_pr_sweep.sh'`
  - expected: exit 0; prints `ok  a clean seat PR is merged once through timed-run`
- `TP-2`
  - intent: a red PR needs exactly one owner, never a pile of duplicates
  - command: `make -C claude/workflow image && podman run --rm --network=none --userns=keep-id -v "$PWD:/work:Z" -w /work -e HOME=/tmp localhost/dotfiles-workflow-test:1 bash -c 'bash scripts/tests/test_pr_sweep.sh'`
  - expected: exit 0; prints `ok  a conflicted PR files one fix work order and a rerun files none`
- `TP-3`
  - intent: UAT starts with a dry run on the real account
  - command: `make -C claude/workflow image && podman run --rm --network=none --userns=keep-id -v "$PWD:/work:Z" -w /work -e HOME=/tmp localhost/dotfiles-workflow-test:1 bash -c 'bash scripts/tests/test_pr_sweep.sh'`
  - expected: exit 0; prints `ok  DRY=1 merges nothing`

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
