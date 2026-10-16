---
{
  "id": "WO-20261016-7012",
  "slug": "test-ord-0806-r3-business-tracked-ignored-check-",
  "title": "Test - ORD-0806 R3: business tracked-ignored-check passes clean, fails on a tracked ignored path, runs in the rendered CI",
  "type": "test",
  "status": "cancelled",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T08:08:48+00:00",
  "parent": "WO-20261016-fb0c",
  "branch": null,
  "pr": null,
  "closed": "2026-10-16",
  "approval": {
    "via": "override",
    "reason": "biz-design1 cut for ORD-0806 R3; design approvals ruled done, ORD-0550 O4",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [
    "WO-20261016-b211"
  ],
  "blocks": [],
  "superseded_by": "WO-20261016-8cce"
}
---

# WO-20261016-7012 - Test - ORD-0806 R3: business tracked-ignored-check passes clean, fails on a tracked ignored path, runs in the rendered CI

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

Order ORD-0806 R3 verbatim: "port tracked-ignored-check to business (after business #76, merged) through the same rolodex or lint job; one config entry if the check is generic enough to live in the shared CI template." Owner item 30: testing is cut as a --type test work order with a filled test plan and the script that runs it. This ticket runs the plan below against the business branch chore/tracked-ignored-check that WO-20261016-b211 - ORD-0806 R3: business CI runs tracked-ignored-check - pr-flow.json business ci targets, Makefile target, ci.yml re-rendered opens. The design seat proved all three cases at cut time (TP-1 exit 0 ok, TP-2 exit 2 listing .lavish/x, TP-3 exit 0 on a render).

## Scope

**In**

- touches: none in either repository (read-only; the clone at /home/luna/.cache/wt-business-tracked-ignored-test is removed at the end)
- touches (generated, written only by work-order.sh start/submit/done in dotfiles, never by hand): work-orders/INDEX.md, this ticket file and its archive path, work-orders/WO-20261016-0272/WO-20261016-fb0c/README.md
- step: run the setup line of the plan, then TP-1, TP-2, TP-3 exactly as written, then the cleanup line
- step: record each case's exit code and output with `work-order.sh evidence`
- tool: cmd:podman with localhost/dotfiles-workflow-test:1 - fallback: image absent: `podman build -q -t localhost/dotfiles-workflow-test:1 -f claude/workflow/tests/container/Containerfile claude/workflow` from the dotfiles root, then rerun; podman down: stop with ENV-MISSING naming it
- tool: cmd:gh - fallback: gh or GitHub down: retry 3 times, then stop with A2A-003 and the gh error in the result blockers
- tool: cmd:git - fallback: fetch refused or branch missing: stop with DESIGN-GAP naming WO-20261016-b211 as not yet pushed

**Out - non-goals**

- editing any file in business or dotfiles: a failing case goes back as DESIGN-GAP with its output, never fixed by the tester
- running any other suite: CI owns the full suite (item 6)
- waiting on the business PR's CI or merging it

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [ ] `AC-H1` *(human)* TP-1 `podman run ... make tracked-ignored-check` on the clean clone exits 0 and its output matches /^tracked-ignored-check: ok$/
- [ ] `AC-H2` *(human)* TP-2 the force-added .lavish/x case exits 2 and its output matches /tracked-ignored-check: tracked but ignored:\n\.lavish\/x/
- [ ] `AC-H3` *(human)* TP-3 the matrix check on .github/workflows/ci.yml exits 0 and prints nothing

## Test plan

_Test plan from claude/workflow/templates/test-plan.md, shaped by claude/workflow/schemas/test-plan.schema.json. The tester runs exactly these cases and nothing else._

**Scope under test**

business Makefile target tracked-ignored-check on branch chore/tracked-ignored-check (setup: `test -d /home/luna/.cache/wt-business-tracked-ignored-test || gh repo clone jkkelley/business /home/luna/.cache/wt-business-tracked-ignored-test`, `git -C /home/luna/.cache/wt-business-tracked-ignored-test fetch origin`, `git -C /home/luna/.cache/wt-business-tracked-ignored-test checkout -B tracked-ignored-test origin/chore/tracked-ignored-check`; cleanup: `rm -rf /home/luna/.cache/wt-business-tracked-ignored-test`)

**Cases**

- `TP-1`
  - intent: a clean business tree must pass, or every business PR goes red the moment the check lands
  - command: `podman run --rm --network=none --userns=keep-id -v "/home/luna/.cache/wt-business-tracked-ignored-test:/work:ro,Z" -w /work -e HOME=/tmp localhost/dotfiles-workflow-test:1 make tracked-ignored-check`
  - expected: exit 0; output is exactly `tracked-ignored-check: ok`
- `TP-2`
  - intent: a branch cut before business #76 re-adds an ignored generated view; the check must fail and name the path, or the regression lands silently
  - command: `podman run --rm --network=none --userns=keep-id -v "/home/luna/.cache/wt-business-tracked-ignored-test:/src:ro,Z" -e HOME=/tmp localhost/dotfiles-workflow-test:1 bash -c 'git clone -q /src /tmp/r && cd /tmp/r && mkdir -p .lavish && touch .lavish/x && git add -f .lavish/x && make tracked-ignored-check'`
  - expected: exit 2 (make's code for a failed recipe); output contains `tracked-ignored-check: tracked but ignored:` and the line `.lavish/x`
- `TP-3`
  - intent: the rendered CI must run the target, or the Makefile check never gates a PR
  - command: `podman run --rm --network=none --userns=keep-id -v "/home/luna/.cache/wt-business-tracked-ignored-test:/work:ro,Z" -w /work -e HOME=/tmp localhost/dotfiles-workflow-test:1 python3 -c 'import yaml,sys; d=yaml.safe_load(open(".github/workflows/ci.yml")); m=d["jobs"]["check"]["strategy"]["matrix"]["target"]; sys.exit(0 if m.count("tracked-ignored-check")==2 else 1)'`
  - expected: exit 0; no output (both the push and the pull_request arm of the matrix expression name tracked-ignored-check)

**Isolation**

- runtime: podman
- image: `localhost/dotfiles-workflow-test@sha256:f621e44c0675790a7343274b4c99205da5b78b7c5bf94fde0d145b5d95ad7e7b` (localhost/dotfiles-workflow-test:1 at cut time, built from claude/workflow/tests/container/Containerfile; fallback when absent: `podman build -q -t localhost/dotfiles-workflow-test:1 -f claude/workflow/tests/container/Containerfile claude/workflow` from the dotfiles root, then rerun the case)

**Out of scope - CI covers**

- the business PR's own ci-ok run on GitHub Actions (ubuntu-24.04), which runs make tracked-ignored-check for real

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

Cancelled `2026-10-16` - nothing shipped.

- reason: DESIGN-GAP (seats/biz-7012.result.json): setup checked out business origin/chore/tracked-ignored-check, deleted when #77 merged; recut against business origin/main on the RR-orch-18 local-image form by infra-design8
- superseded by: `WO-20261016-8cce`

No branch, no PR and no merge commit exist for this work order.

