---
{
  "id": "WO-20261016-5504",
  "slug": "pr-index-sh-every-open-pr-of-the-account-in-one-",
  "title": "pr-index.sh: every open PR of the account in one generated index outside git",
  "type": "feature",
  "status": "ready",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T06:06:14+00:00",
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
    "WO-20261016-fb0c"
  ],
  "blocks": [
    "WO-20261016-7d47",
    "WO-20261016-df39",
    "WO-20261016-6cff"
  ]
}
---

# WO-20261016-5504 - pr-index.sh: every open PR of the account in one generated index outside git

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

Owner, 2026-10-16 UTC: "WE HAVE BUSINESS PRS EVERYWHERE", "WE NEED THINGS INDEXED". Evidence 05:55Z: 75 open PRs across 38 repos of jkkelley; 28 are 'docs: golden system design rules' from make golden-rules-repos; generic-agents-auto-workflow holds 16; nothing lists them in one place. Item 23: the index changes every run, so it lives in the artifact store, never in a repo.

## Scope

**In**

- touches: scripts/pr-index.sh
- touches: scripts/tests/test_pr_index.sh
- touches: scripts/tests/fixtures/pr-search.json
- touches: scripts/tests/fixtures/pr-view-182.json
- touches: config/pr-index.json
- step: config/pr-index.json: `{owner: "jkkelley", store: "~/.local/state/zenith/pr-index", golden_title_prefix: "docs: golden system design rules", limit: 300}`
- step: pr-index.sh [--config F] [--owner O] [--out-dir D]: `gh search prs --owner O --state open --limit <limit> --json repository,number,title,url,createdAt,isDraft,author`, then per PR `gh pr view -R <repo> <n> --json mergeable,statusCheckRollup,headRefName,body,reviewDecision`
- step: per PR fields: repo, number, title, url, age_h, draft, ticket (first `WO-[0-9]{8}-[0-9a-f]{4}` in title or body, else null), ticket_title (text after `<ticket> - ` on the same body line, else null), ci (fail if any conclusion FAILURE, pending if any status not COMPLETED, pass if any, else none), mergeable, source (golden-rules when title starts with golden_title_prefix; seat when ticket is non-null; other), waits_on (first of: draft, conflict when mergeable is CONFLICTING, ci-failing, ci-pending, changes-requested, none)
- step: write `<store>/YYYY/MM/YYYYMMDD-HHMMSS-pr-index.json` and `...-pr-index.md` (frontmatter what/by/repo/branch/created UTC, a contents list, one H2 per repo, a table per repo), then point `<store>/latest.json` and `<store>/latest.md` symlinks at them; idempotent
- step: root Makefile is not touched here (tr-root and p2 own it); run as `bash scripts/pr-index.sh`
- step: test with a stub gh on PATH serving the two fixtures
- step: run `make -C claude/workflow image && podman run --rm --network=none --userns=keep-id -v "$PWD:/work:Z" -w /work -e HOME=/tmp localhost/dotfiles-workflow-test:1 bash -c 'bash scripts/tests/test_pr_index.sh'`
- tool: path:claude/workflow/tests/container/Containerfile - on main; fallback: no fallback permitted (dotfiles Rule 14, never the host): podman or the image missing stops the node with ENV-MISSING podman
- tool: cmd:gh - on main; fallback: gh or GitHub down: retry 3 times, then stop with A2A-003 and the gh error in the result blockers

**Out - non-goals**

- work-orders/INDEX.md by hand: work-order.sh writes it, and the reindex Action is owned by merge-port-build (F11, ORD-0545 O1)
- waiting on CI or merging: push, open the PR, write the result, leave (ORD-0542 O2)
- any file not named under In: stop with DESIGN-GAP and hand it back to infra-design (ORD-0548, item 30)

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [ ] `AC-H1` *(human)* the test exits 0 and prints `ok every PR of gh search prs appears once in pr-index.json` (proof: command, exit code and output pasted by work-order.sh evidence; ORD-0552 O2)
- [ ] `AC-H2` *(human)* the same run prints `ok golden-rules source and waits_on conflict are derived` and `ok latest.md links the newest index and opens with a contents list` (proof: command, exit code and output pasted by work-order.sh evidence; ORD-0552 O2)
- [ ] `AC-H3` *(human)* UAT: `bash scripts/pr-index.sh` on the real account writes latest.json whose length equals `gh search prs --owner jkkelley --state open --limit 300 --json number -q length` (proof: command, exit code and output pasted by work-order.sh evidence; ORD-0552 O2)

## Test plan

_Test plan from claude/workflow/templates/test-plan.md, shaped by claude/workflow/schemas/test-plan.schema.json. The tester runs exactly these cases and nothing else._

**Scope under test**

scripts/pr-index.sh against a stub gh and fixtures

**Cases**

- `TP-1`
  - intent: an index that misses a PR is the problem it exists to fix (owner: WE NEED THINGS INDEXED)
  - command: `make -C claude/workflow image && podman run --rm --network=none --userns=keep-id -v "$PWD:/work:Z" -w /work -e HOME=/tmp localhost/dotfiles-workflow-test:1 bash -c 'bash scripts/tests/test_pr_index.sh'`
  - expected: exit 0; prints `ok  every PR of gh search prs appears once in pr-index.json`
- `TP-2`
  - intent: source and waits_on drive pr-sweep; wrong ones merge the wrong PR
  - command: `make -C claude/workflow image && podman run --rm --network=none --userns=keep-id -v "$PWD:/work:Z" -w /work -e HOME=/tmp localhost/dotfiles-workflow-test:1 bash -c 'bash scripts/tests/test_pr_index.sh'`
  - expected: exit 0; prints `ok  golden-rules source and waits_on conflict are derived`
- `TP-3`
  - intent: the index is found by its pointer, never by searching (item 23)
  - command: `make -C claude/workflow image && podman run --rm --network=none --userns=keep-id -v "$PWD:/work:Z" -w /work -e HOME=/tmp localhost/dotfiles-workflow-test:1 bash -c 'bash scripts/tests/test_pr_index.sh'`
  - expected: exit 0; prints `ok  latest.md links the newest index and opens with a contents list`

**Isolation**

- runtime: podman
- image: `docker.io/library/debian:bookworm-slim@sha256:3783cc01769c7b2b1b83a5c5ad96c815348e28ed7da68e2e3687004faa906251` (debian:bookworm-slim, base of localhost/dotfiles-workflow-test:1)

**Out of scope - CI covers**

- shellcheck and the full scripts suite

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
