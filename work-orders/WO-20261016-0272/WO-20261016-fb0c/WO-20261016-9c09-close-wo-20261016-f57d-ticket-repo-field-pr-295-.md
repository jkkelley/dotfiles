---
{
  "id": "WO-20261016-9c09",
  "slug": "close-wo-20261016-f57d-ticket-repo-field-pr-295-",
  "title": "Close WO-20261016-f57d (ticket repo field, PR 295 merged): re-run its checks under this ticket, move its edge to e297 here and cancel f57d as superseded, so e297 starts",
  "type": "chore",
  "status": "in-progress",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T10:54:18+00:00",
  "parent": "WO-20261016-fb0c",
  "branch": "feat/9c09-close-wo-20261016-f57d-ticket-repo-field-pr-295-",
  "pr": null,
  "closed": null,
  "approval": {
    "via": "override",
    "reason": "infra-design16 cut for ORD-0830 RR-orch-14 F35; design approvals ruled done, ORD-0550 O4",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [],
  "blocks": [
    "WO-20261016-e297"
  ],
  "ac_checks": [
    {
      "index": 1,
      "command": "bash claude/skills/work-order/testing/run-tests.sh",
      "exit": 0,
      "expect": "all cases passed"
    },
    {
      "index": 2,
      "command": "grep -c -- '--repo) ' claude/skills/work-order/scripts/work-order.sh",
      "exit": 0,
      "expect": "^1$"
    },
    {
      "index": 3,
      "command": "bash claude/skills/work-order/scripts/work-order.sh show --id WO-20261016-f57d --json | jq -r '.status'",
      "exit": 0,
      "expect": "^cancelled$"
    },
    {
      "index": 4,
      "command": "bash claude/skills/work-order/scripts/work-order.sh show --id WO-20261016-e297 --json | jq -e '.depends_on | index(\"WO-20261016-f57d\") == null'",
      "exit": 0,
      "expect": null
    },
    {
      "index": 5,
      "command": "git diff --name-only origin/main...HEAD | grep -vE '^(work-orders/.*)$'",
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

# WO-20261016-9c09 - Close WO-20261016-f57d (ticket repo field, PR 295 merged): re-run its checks under this ticket, move its edge to e297 here and cancel f57d as superseded, so e297 starts

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

WO-20261016-f57d - Ticket repo field: new --repo and set --repo name the code repo OWNER/NAME; submit and stale-merged resolve a bare pr there (2d5b TP-3): its code merged in PR 295 (9974aa3) but the ticket is still ready on main (F36 class: no start stamp, no evidence), and it gates WO-20261016-e297 (approve --code-dir) and through it WO-20261016-1099 (check and done --code-dir), which the F44 close-outs of business tickets fce5 and 3197 wait on. amend refuses a ready ticket; starting the original would collide with its merged branch.

## Owner words

> CO f57d: code merged PR 295 but ticket still ready on main (F36 class), and it gates e297 and so 1099; close via successor in the bcb4 pattern (orchestrator brief BR-20261016-infra-design16)

> get this code merged the fuck in, dead code is shit, it sitting under agents is stupid (Design principles 101 item 21)

## Context

Order brief BR-20261016-infra-design16, ORD-0830 RR-orch-14; F35; pattern WO-20261016-bcb4 (PR 313) and WO-20261016-ad18 / 1b7e (PR 314): copied checks, edges moved, original cancelled superseded.

Precondition: gh pr view 295 --json state -q .state prints MERGED, else stop with DESIGN-GAP. THIS-TICKET-ID is this ticket's own id, the .id in its frontmatter. Steps on the branch: for each id in $(bash claude/skills/work-order/scripts/work-order.sh show --id WO-20261016-f57d --json | jq -r '.blocks[]'): work-order.sh link --id $id --depends-on THIS-TICKET-ID --no-depends-on WO-20261016-f57d; then work-order.sh cancel --id WO-20261016-f57d --reason 'code merged in PR 295; checks re-run under THIS-TICKET-ID' --superseded-by THIS-TICKET-ID; commit those generated moves.

AC-H2 expects exactly one '--repo) ' arm in work-order.sh as on main 10fd77b; if a later merged ticket legitimately adds a second arm, stop with DESIGN-GAP and the grep output, never edit the check.

## Scope

**In**

- touches (generated, by work-order.sh link and cancel only): the f57d ticket file and its archive path, the ticket file of every id in f57d's blocks list (today WO-20261016-e297)
- touches (generated, written only by work-order.sh start/submit/done, never by hand or git add): this ticket file and its archive path; work-orders/INDEX.md and the parent epic README.md are ignored generated views
- step: branch from origin/main in your own git worktree, never the ~/dotfiles primary clone
- step: check the precondition in Context, then run the link loop and the cancel exactly as in Context
- step: run the AC checks only
- step: commit 'chore(work-orders): close f57d under its re-checked successor' with the ticket id; no Bump trailer
- tool: script:claude/skills/work-order/testing/run-tests.sh with image localhost/work-order-test:1 - on main; fallback: image missing: run-tests.sh builds it, retry once; build fails: stop with ENV-MISSING podman
- tool: cmd:git, cmd:jq, cmd:podman, cmd:gh - fallback: missing on the host: stop with ENV-MISSING naming it; gh or GitHub down: retry 3 times, then stop with A2A-003 and its output

**Out - non-goals**

- claude/skills/work-order code or tests: PR 295 shipped them
- setting .repo on business tickets: their own close-out tickets do that
- any file not named under In: stop with DESIGN-GAP
- work-orders/INDEX.md and epic READMEs by hand or by git add; waiting on CI or merging: push, open the PR, write the result, leave
- a Bump trailer: no skill under claude/skills changes

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [x] `AC-H1` *(human)* f57d's case 360 and the work-order skill suite pass on main
  - observed `2026-10-16` check: bash claude/skills/work-order/testing/run-tests.sh exit 0 output: work-order test suite image: localhost/work-order-test:1 skill: /home/luna/.cache/wt-close-9c09/claude/skills/work-order (read-only) scratch: /tmp/work-order-test.aG5eQ3 (removed on exit) 010-new-happy.sh ok new exits 0 on the documented example (exit 0) ok INDEX.md is generated ok INDEX lists the new ticket ok starts in draft ok renders the non-goals section ok records the non-goal ok records the human criterion ok frontmatter parses as JSON (exit 0) created /work/proj.HNUhSx/work-orders/WO-20260805-f57b/WO-20260805-f57b-empty-cart-state.md (status: draft, evidence: human) ok same input and clock produce an identical ticket 010-new-happy: 9 checks, 0 failed 020-new-refuses.sh
  - check: `bash claude/skills/work-order/testing/run-tests.sh` exit 0 expect /all cases passed/
- [x] `AC-H2` *(human)* new and set take --repo
  - observed `2026-10-16` check: grep -c -- '--repo) ' claude/skills/work-order/scripts/work-order.sh exit 0 output: 1
  - check: `grep -c -- '--repo) ' claude/skills/work-order/scripts/work-order.sh` exit 0 expect /^1$/
- [x] `AC-H3` *(human)* f57d is cancelled and superseded by this ticket
  - observed `2026-10-16` check: bash claude/skills/work-order/scripts/work-order.sh show --id WO-20261016-f57d --json | jq -r '.status' exit 0 output: cancelled
  - check: `bash claude/skills/work-order/scripts/work-order.sh show --id WO-20261016-f57d --json | jq -r '.status'` exit 0 expect /^cancelled$/
- [x] `AC-H4` *(human)* e297 no longer depends on f57d
  - observed `2026-10-16` check: bash claude/skills/work-order/scripts/work-order.sh show --id WO-20261016-e297 --json | jq -e '.depends_on | index("WO-20261016-f57d") == null' exit 0 output: true
  - check: `bash claude/skills/work-order/scripts/work-order.sh show --id WO-20261016-e297 --json | jq -e '.depends_on | index("WO-20261016-f57d") == null'` exit 0
- [x] `AC-H5` *(human)* the diff holds only generated work-orders files
  - observed `2026-10-16` check: git diff --name-only origin/main...HEAD | grep -vE '^(work-orders/.*)$' exit 1 output:
  - check: `git diff --name-only origin/main...HEAD | grep -vE '^(work-orders/.*)$'` exit 1

## Test plan

_Test plan from claude/workflow/templates/test-plan.md, shaped by claude/workflow/schemas/test-plan.schema.json. The tester runs exactly these cases and nothing else._

**Scope under test**

WO-20261016-f57d's merged code (PR 295): work-order.sh new --repo and set --repo, case 360

**Cases**

- `TP-1`
  - intent: f57d's code is merged; its checks must pass on main before its edge to WO-20261016-e297 moves here, or e297 and 1099 build on a broken repo field
  - command: `bash claude/skills/work-order/testing/run-tests.sh`
  - expected: exit 0; last line all cases passed

**Isolation**

_A locally built image uses `- image: localhost/<name>:<tag>` plus `- build: <command>` and `- containerfile: <path>` lines, never a localhost digest (RR-orch-18)._

- runtime: podman
- image: `localhost/work-order-test:1`
- build: `bash claude/skills/work-order/testing/run-tests.sh`
- containerfile: `claude/skills/work-order/testing/Containerfile`

**Out of scope - CI covers**

- lint and the workflow suite: CI runs them

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
