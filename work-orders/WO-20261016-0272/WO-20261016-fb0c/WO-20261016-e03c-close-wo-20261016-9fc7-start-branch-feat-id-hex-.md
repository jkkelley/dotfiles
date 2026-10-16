---
{
  "id": "WO-20261016-e03c",
  "slug": "close-wo-20261016-9fc7-start-branch-feat-id-hex-",
  "title": "Close WO-20261016-9fc7 (start branch feat/<id hex>-<slug>, PR 318 merged): re-run its checks 1,2,3 on main under this ticket, move its 94e2, 3d4d edges here and cancel 9fc7 as superseded",
  "type": "chore",
  "status": "ready",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T11:31:05+00:00",
  "parent": "WO-20261016-fb0c",
  "branch": null,
  "pr": null,
  "closed": null,
  "approval": {
    "via": "override",
    "reason": "infra-design18 cut for ORD-1114 close-outs; design approvals ruled done, ORD-0550 O4",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [],
  "blocks": [
    "WO-20261016-94e2",
    "WO-20261016-3d4d",
    "WO-20261016-9fc7"
  ],
  "ac_checks": [
    {
      "index": 1,
      "command": "bash claude/skills/work-order/testing/run-tests.sh",
      "exit": 0,
      "expect": "410-start-branch-id"
    },
    {
      "index": 2,
      "command": "grep -c 'branch=\"feat/${id##\\*-}-${slug}\"' claude/skills/work-order/scripts/work-order.sh",
      "exit": 0,
      "expect": "^1$"
    },
    {
      "index": 3,
      "command": "make rolodex-check BASE=origin/main",
      "exit": 0,
      "expect": null
    },
    {
      "index": 4,
      "command": "bash claude/skills/work-order/scripts/work-order.sh show --id WO-20261016-9fc7 --json | jq -r '.status + \" \" + (.superseded_by // \"-\")'",
      "exit": 0,
      "expect": "^cancelled WO-"
    },
    {
      "index": 5,
      "command": "grep -rlE '\"WO-20261016-9fc7\"' work-orders --include='WO-*.md' | xargs -r grep -L -E '\"status\": \"(done|cancelled)\"' | grep -v -- '-9fc7-'",
      "exit": 1,
      "expect": null
    },
    {
      "index": 6,
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

# WO-20261016-e03c - Close WO-20261016-9fc7 (start branch feat/<id hex>-<slug>, PR 318 merged): re-run its checks 1,2,3 on main under this ticket, move its 94e2, 3d4d edges here and cancel 9fc7 as superseded

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

WO-20261016-9fc7 is still ready on main although its code PR 318 merged with no work-orders change (F36 recurrence: seat start-branch-id reported done, never closed). WO-20261016-94e2 and WO-20261016-3d4d depend on it and never reach next.

## Owner words

> design seat infra-design: ORD-1114 code_repo for every verb (reconcile 1b46 with e297 and 1099), stranded close-outs 9fc7 and 168d, DESIGN-GAP 168e test plan, F44 close-outs; keep the 6-leaf buffer (orchestrator brief BR-20261016-infra-design18)

> get this code merged the fuck in, dead code is shit, it sitting under agents is stupid (Design principles 101 item 21)

## Context

Order brief BR-20261016-infra-design18; pattern WO-20261016-bcb4 and WO-20261016-aa46 (close successor). The scope check of WO-20261016-9fc7 is dropped, not copied: on a close branch the diff is work-orders files only, which the last criterion asserts. This ticket already blocks WO-20261016-94e2, WO-20261016-3d4d, so they wait on it from the moment it merges as ready.

Steps on the branch, after start, each exactly as written: bash claude/skills/work-order/scripts/work-order.sh link --id WO-20261016-94e2 --no-depends-on WO-20261016-9fc7; bash claude/skills/work-order/scripts/work-order.sh link --id WO-20261016-3d4d --no-depends-on WO-20261016-9fc7; bash claude/skills/work-order/scripts/work-order.sh cancel --id WO-20261016-9fc7 --reason 'start branch feat/<id hex>-<slug>, PR 318 merged; re-checked under THIS-TICKET-ID' --superseded-by THIS-TICKET-ID; bash claude/skills/work-order/scripts/work-order.sh check --id THIS-TICKET-ID (check ticks every passing criterion; never tick by hand with evidence); commit those generated moves; open the PR; submit --pr <N>; done; commit and push. THIS-TICKET-ID is this ticket's own id, the .id in its frontmatter.

## Scope

**In**

- touches (generated, by work-order.sh link and cancel only): the WO-20261016-9fc7 ticket file and its archive path, and the ticket files of WO-20261016-94e2, WO-20261016-3d4d
- touches (generated, written only by work-order.sh start/submit/done, never by hand or git add): this ticket file and its archive path; work-orders/INDEX.md and the parent epic README.md are ignored generated views
- step: branch from origin/main in your own git worktree (fallback: treehouse fails, use git worktree add), never the ~/dotfiles primary clone
- step: run the links, the cancel and the check exactly as in Context, then submit --pr <this PR> and done
- step: commit 'chore(work-orders): close WO-20261016-9fc7 under its re-checked successor' with the ticket id; no Bump trailer
- tool: script:claude/skills/work-order/testing/run-tests.sh - on main; fallback: missing: stop with DESIGN-GAP naming it; its image fails to build: stop with ENV-MISSING podman
- tool: make:Makefile:rolodex-check - on main; fallback: missing: stop with DESIGN-GAP naming it
- tool: script:claude/skills/work-order/scripts/work-order.sh - on main; fallback: a verb refuses: stop with its status code and output, never edit a ticket by hand
- tool: cmd:git, cmd:jq, cmd:make, cmd:podman, cmd:gh - fallback: missing on the host: stop with ENV-MISSING naming it; gh or GitHub down: retry 3 times, then stop with A2A-003 and its output

**Out - non-goals**

- any code, test or doc file: the merged PR shipped them
- any file not named under In: stop with DESIGN-GAP and hand it back to the design seat (item 30)
- work-orders/INDEX.md and epic READMEs by hand or by git add; waiting on CI or merging: push, open the PR, write the result, leave
- a Bump trailer: no skill under claude/skills changes

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [ ] `AC-H1` *(human)* WO-20261016-9fc7 check 1 passes on main (copied from WO-20261016-9fc7 check 1)
  - check: `bash claude/skills/work-order/testing/run-tests.sh` exit 0 expect /410-start-branch-id/
- [ ] `AC-H2` *(human)* WO-20261016-9fc7 check 2 passes on main (copied from WO-20261016-9fc7 check 2)
  - check: `grep -c 'branch="feat/${id##\*-}-${slug}"' claude/skills/work-order/scripts/work-order.sh` exit 0 expect /^1$/
- [ ] `AC-H3` *(human)* WO-20261016-9fc7 check 3 passes on main (copied from WO-20261016-9fc7 check 3)
  - check: `make rolodex-check BASE=origin/main` exit 0
- [ ] `AC-H4` *(human)* WO-20261016-9fc7 is cancelled and superseded
  - check: `bash claude/skills/work-order/scripts/work-order.sh show --id WO-20261016-9fc7 --json | jq -r '.status + " " + (.superseded_by // "-")'` exit 0 expect /^cancelled WO-/
- [ ] `AC-H5` *(human)* no open ticket still depends on WO-20261016-9fc7
  - check: `grep -rlE '"WO-20261016-9fc7"' work-orders --include='WO-*.md' | xargs -r grep -L -E '"status": "(done|cancelled)"' | grep -v -- '-9fc7-'` exit 1
- [ ] `AC-H6` *(human)* the diff holds only generated work-orders files
  - check: `git diff --name-only origin/main...HEAD | grep -vE '^(work-orders/.*)$'` exit 1

## Test plan

_Test plan from claude/workflow/templates/test-plan.md, shaped by claude/workflow/schemas/test-plan.schema.json. The tester runs exactly these cases and nothing else._

**Scope under test**

WO-20261016-9fc7 checks 1-3 re-run on main under its close successor

**Cases**

- `TP-1`
  - intent: merged PR 318 still meets every criterion of WO-20261016-9fc7, and 94e2 and 3d4d stop waiting on a ticket that will never close
  - command: `bash claude/skills/work-order/scripts/work-order.sh check --id THIS-TICKET-ID`
  - expected: exit 0; one AC-PASS line per criterion

**Isolation**

- runtime: podman
- image: `localhost/work-order-test:1`
- build: `podman build -t localhost/work-order-test:1 -f claude/skills/work-order/testing/Containerfile claude/skills/work-order/testing`
- containerfile: claude/skills/work-order/testing/Containerfile

**Out of scope - CI covers**

- lint and the full suite: CI runs them (Design principles 101 item 6)

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
