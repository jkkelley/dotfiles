---
{
  "id": "WO-20261016-8cce",
  "slug": "test-ord-0806-r3-business-tracked-ignored-check-",
  "title": "Test - ORD-0806 R3: business tracked-ignored-check passes clean, fails on a tracked ignored path, runs in the rendered CI, on business origin/main",
  "type": "test",
  "status": "ready",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T09:07:27+00:00",
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
  "depends_on": [
    "WO-20261016-86b9"
  ],
  "blocks": [],
  "ac_checks": [
    {
      "index": 1,
      "command": "podman run --rm --pull=never --network=none --userns=keep-id -v /home/luna/.cache/wt-business-tracked-ignored-test:/work:ro,Z -w /work -e HOME=/tmp localhost/dotfiles-workflow-test:1 make tracked-ignored-check",
      "exit": 0,
      "expect": "^tracked-ignored-check: ok$"
    },
    {
      "index": 2,
      "command": "podman run --rm --pull=never --network=none --userns=keep-id -v /home/luna/.cache/wt-business-tracked-ignored-test:/src:ro,Z -e HOME=/tmp localhost/dotfiles-workflow-test:1 bash -c 'git clone -q /src /tmp/r && cd /tmp/r && mkdir -p .lavish && touch .lavish/x && git add -f .lavish/x && make tracked-ignored-check'",
      "exit": 2,
      "expect": "\\.lavish/x"
    },
    {
      "index": 3,
      "command": "podman run --rm --pull=never --network=none --userns=keep-id -v /home/luna/.cache/wt-business-tracked-ignored-test:/work:ro,Z -w /work -e HOME=/tmp localhost/dotfiles-workflow-test:1 python3 -c 'import yaml,sys; d=yaml.safe_load(open(\".github/workflows/ci.yml\")); m=d[\"jobs\"][\"check\"][\"strategy\"][\"matrix\"][\"target\"]; sys.exit(0 if m.count(\"tracked-ignored-check\")==2 else 1)'",
      "exit": 0,
      "expect": null
    }
  ],
  "provides": [],
  "labels": [
    "line:inbox-triage"
  ]
}
---

# WO-20261016-8cce - Test - ORD-0806 R3: business tracked-ignored-check passes clean, fails on a tracked ignored path, runs in the rendered CI, on business origin/main

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

Order ORD-0806 R3 verbatim: "port tracked-ignored-check to business (after business #76, merged) through the same rolodex or lint job; one config entry if the check is generic enough to live in the shared CI template." This ticket runs the plan below against business origin/main, where business #77 'ci: tracked-ignored-check in the smart CI matrix' merged the target.

## Owner words

> i want work scoped so small a fuck ape could do, testing the same way with test plans and scripts, every node has what it fucking needs up front, not later (Design principles 101 item 30)

> see a bug, isolate it, and get it fixed as asap (item 22)

## Context

DESIGN-GAP 2026-10-16T08:45Z from seat biz-7012 (seats/biz-7012.result.json): WO-20261016-7012's setup checked out origin/chore/tracked-ignored-check in jkkelley/business, deleted when #77 merged (gh api .../branches/chore/tracked-ignored-check -> 404). infra-design8 cancelled the ready ticket and recut it against origin/main; WO-20261016-b211 - ORD-0806 R3: business CI runs tracked-ignored-check is done (dotfiles PR 244 merged).

Checked at cut time on business origin/main: Makefile line 6 'tracked-ignored-check:'; .github/workflows/ci.yml line 40 names tracked-ignored-check in both arms of the matrix expression. Isolation moved to the RR-orch-18 local-image form (the old plan pinned localhost digest f621e44c), so this ticket waits for WO-20261016-86b9.

Architect ruling RR-orch-18, 2026-10-16: a locally built image is never pinned by digest. Evidence: ~/.local/state/zenith/log/2026/10/20261016-080957-t21e-cards-uat-digest.txt (UAT cards suite run on pinned image 0a6832bb, image id f4d2d4c03c76): a localhost digest names one build on one machine; every rebuild of claude/workflow/tests/container/Containerfile mints a new digest, so a plan pinned to it stops resolving (11 plans pinned 0a6832bb, 2 still live as drafts). What Rule 15 protects is the base: the Containerfile FROM is pinned by digest, so the tag plus the build target plus the pinned FROM is reproducible, and --pull=never makes a missing image a loud error instead of a registry lookup.

## Scope

**In**

- touches: none in either repository (read-only; the clone at /home/luna/.cache/wt-business-tracked-ignored-test is removed at the end)
- touches (generated, written only by work-order.sh start/submit/done, never by hand or git add): this ticket file and its archive path; work-orders/INDEX.md and the parent epic README.md are ignored generated views
- step: run the setup line of the plan, then TP-1, TP-2, TP-3 exactly as written, then the cleanup line
- step: record each case's exit code and output with work-order.sh evidence
- tool: cmd:podman with localhost/dotfiles-workflow-test:1 built by make -C claude/workflow image - fallback: build fails: stop with ENV-MISSING podman and its output
- tool: cmd:gh - fallback: gh or GitHub down: retry 3 times, then stop with A2A-003 and the gh error in the result blockers
- tool: cmd:git - fallback: fetch refused: retry 3 times, then stop with A2A-003 and its output

**Out - non-goals**

- editing any file in business or dotfiles: a failing case goes back as DESIGN-GAP with its output, never fixed by the tester
- running any other suite: CI owns the full suite (item 6)
- waiting on CI or merging: push, open the PR, write the result, leave (ORD-0542 O2)

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [ ] `AC-H1` *(human)* TP-1 on the clean clone exits 0 and prints tracked-ignored-check: ok
  - check: `podman run --rm --pull=never --network=none --userns=keep-id -v /home/luna/.cache/wt-business-tracked-ignored-test:/work:ro,Z -w /work -e HOME=/tmp localhost/dotfiles-workflow-test:1 make tracked-ignored-check` exit 0 expect /^tracked-ignored-check: ok$/
- [ ] `AC-H2` *(human)* TP-2 the force-added .lavish/x case exits 2 and names the path
  - check: `podman run --rm --pull=never --network=none --userns=keep-id -v /home/luna/.cache/wt-business-tracked-ignored-test:/src:ro,Z -e HOME=/tmp localhost/dotfiles-workflow-test:1 bash -c 'git clone -q /src /tmp/r && cd /tmp/r && mkdir -p .lavish && touch .lavish/x && git add -f .lavish/x && make tracked-ignored-check'` exit 2 expect /\.lavish/x/
- [ ] `AC-H3` *(human)* TP-3 the matrix check on .github/workflows/ci.yml exits 0
  - check: `podman run --rm --pull=never --network=none --userns=keep-id -v /home/luna/.cache/wt-business-tracked-ignored-test:/work:ro,Z -w /work -e HOME=/tmp localhost/dotfiles-workflow-test:1 python3 -c 'import yaml,sys; d=yaml.safe_load(open(".github/workflows/ci.yml")); m=d["jobs"]["check"]["strategy"]["matrix"]["target"]; sys.exit(0 if m.count("tracked-ignored-check")==2 else 1)'` exit 0

## Test plan

_Test plan from claude/workflow/templates/test-plan.md, shaped by claude/workflow/schemas/test-plan.schema.json. The tester runs exactly these cases and nothing else._

**Scope under test**

business Makefile target tracked-ignored-check on business origin/main, where #77 merged it (setup: `test -d /home/luna/.cache/wt-business-tracked-ignored-test || gh repo clone jkkelley/business /home/luna/.cache/wt-business-tracked-ignored-test`, `git -C /home/luna/.cache/wt-business-tracked-ignored-test fetch origin`, `git -C /home/luna/.cache/wt-business-tracked-ignored-test checkout -B tracked-ignored-test origin/main`, `make -C claude/workflow image` from the dotfiles root; cleanup: `rm -rf /home/luna/.cache/wt-business-tracked-ignored-test`)

**Cases**

- `TP-1`
  - intent: a clean business tree must pass, or every business PR goes red the moment the check lands
  - command: `podman run --rm --pull=never --network=none --userns=keep-id -v "/home/luna/.cache/wt-business-tracked-ignored-test:/work:ro,Z" -w /work -e HOME=/tmp localhost/dotfiles-workflow-test:1 make tracked-ignored-check`
  - expected: exit 0; output is exactly `tracked-ignored-check: ok`
- `TP-2`
  - intent: a branch cut before business #76 re-adds an ignored generated view; the check must fail and name the path, or the regression lands silently
  - command: `podman run --rm --pull=never --network=none --userns=keep-id -v "/home/luna/.cache/wt-business-tracked-ignored-test:/src:ro,Z" -e HOME=/tmp localhost/dotfiles-workflow-test:1 bash -c 'git clone -q /src /tmp/r && cd /tmp/r && mkdir -p .lavish && touch .lavish/x && git add -f .lavish/x && make tracked-ignored-check'`
  - expected: exit 2 (make's code for a failed recipe); output contains `tracked-ignored-check: tracked but ignored:` and the line `.lavish/x`
- `TP-3`
  - intent: the rendered CI must run the target, or the Makefile check never gates a PR
  - command: `podman run --rm --pull=never --network=none --userns=keep-id -v "/home/luna/.cache/wt-business-tracked-ignored-test:/work:ro,Z" -w /work -e HOME=/tmp localhost/dotfiles-workflow-test:1 python3 -c 'import yaml,sys; d=yaml.safe_load(open(".github/workflows/ci.yml")); m=d["jobs"]["check"]["strategy"]["matrix"]["target"]; sys.exit(0 if m.count("tracked-ignored-check")==2 else 1)'`
  - expected: exit 0; no output (both the push and the pull_request arm of the matrix expression name tracked-ignored-check)

**Isolation**

- runtime: podman
- image: `localhost/dotfiles-workflow-test:1`
- build: `make -C claude/workflow image`
- containerfile: `claude/workflow/tests/container/Containerfile`

**Out of scope - CI covers**

- the business PR's own ci-ok run on GitHub Actions (ubuntu-24.04), which runs make tracked-ignored-check for real

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
