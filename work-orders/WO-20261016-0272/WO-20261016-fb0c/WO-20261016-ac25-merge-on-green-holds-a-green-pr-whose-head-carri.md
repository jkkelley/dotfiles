---
{
  "id": "WO-20261016-ac25",
  "slug": "merge-on-green-holds-a-green-pr-whose-head-carri",
  "title": "merge-on-green holds a green PR whose head carries an open work-order (gate.sh ticket-open, code TICKET-OPEN), and the worker playbook closes out before CI ends",
  "type": "feature",
  "status": "ready",
  "priority": "p2",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T10:27:10+00:00",
  "parent": "WO-20261016-fb0c",
  "branch": null,
  "pr": null,
  "closed": null,
  "approval": {
    "via": "override",
    "reason": "infra-design14 cut for ORD-0830 RR-orch-14 F35; design approvals ruled done, ORD-0550 O4",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [
    "WO-20261016-39da",
    "WO-20261016-0233"
  ],
  "blocks": [],
  "ac_checks": [
    {
      "index": 1,
      "command": "make -C claude/workflow pr-flow-test CASES=ci-template",
      "exit": 0,
      "expect": "ok  ci-template"
    },
    {
      "index": 2,
      "command": "grep -c 'gate.sh ticket-open' .github/workflows/merge-on-green.yml",
      "exit": 0,
      "expect": "^1$"
    },
    {
      "index": 3,
      "command": "grep -c '^| F36 |' claude/workflow/docs/pr-process/pr-process.md",
      "exit": 0,
      "expect": "^1$"
    },
    {
      "index": 4,
      "command": "git diff --name-only origin/main...HEAD | grep -vE '^(work-orders/.*|\\.github/workflows/merge-on-green\\.yml|claude/workflow/pr-flow/(templates/merge-on-green\\.yml|tests/ci-template\\.test\\.sh|playbooks/worker\\.md)|claude/workflow/docs/pr-process/pr-process\\.md)$'",
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

# WO-20261016-ac25 - merge-on-green holds a green PR whose head carries an open work-order (gate.sh ticket-open, code TICKET-OPEN), and the worker playbook closes out before CI ends

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

The merge-on-green Action merges on the first green head, so a seat's submit and done commit lands after the squash and the ticket is stranded (448e, PR 273, PR 285). With gate.sh ticket-open on main, the Action must run it and hold.

## Owner words

> F36 class: close-out after squash merge ... or the merge loop refuses a PR whose ticket is not done (orchestrator brief BR-20261016-infra-design14)

> automate that process, we dont need gates we need speed (owner, 2026-10-16 UTC, global PR process rule)

## Context

Order brief BR-20261016-infra-design14, ORD-0830 RR-orch-14; F35. Depends on the gate.sh ticket-open ticket (the verb) and WO-20261016-39da (it edits the same template, rendered workflow and docs first). Template change, exact: in claude/workflow/pr-flow/templates/merge-on-green.yml, after the 'head moved' check, add an actions/checkout step at the pinned sha the template already uses for any checkout (or 3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1 if none) with ref: HEAD_SHA and fetch-depth: 0, then run bash claude/workflow/pr-flow/bin/gate.sh ticket-open --repo . --base origin/$baseref --sha "$HEAD_SHA"; rc 1: say 3 'held: TICKET-OPEN <output>' and exit 0 (the next push after done re-runs CI and this workflow); rc 4: say 423 'blocked: ticket-open failed' exit 1. Re-render .github/workflows/merge-on-green.yml with the existing render target (make -C claude/workflow pr-flow-ci-install or the render script the template header names), never by hand.

Docs: claude/workflow/pr-flow/playbooks/worker.md step 2 gains the sentence 'merge-on-green and merge.sh hold the PR with TICKET-OPEN until this commit is on the head, so the order cannot be lost.'; claude/workflow/docs/pr-process/pr-process.md failure table gains row F36: '| F36 | a PR squash-merged before its close-out commit, stranding the ticket (448e, 273, 285) | gate.sh ticket-open holds TICKET-OPEN in merge-on-green and merge.sh |'. Test: pr-flow/tests/ci-template.test.sh gains one case asserting the rendered workflow contains 'gate.sh ticket-open' and 'TICKET-OPEN'.

## Scope

**In**

- touches: claude/workflow/pr-flow/templates/merge-on-green.yml (the checkout and ticket-open step, as in Context)
- touches: .github/workflows/merge-on-green.yml (rendered from the template by its script, never hand edited)
- touches: claude/workflow/pr-flow/tests/ci-template.test.sh (1 appended case)
- touches: claude/workflow/pr-flow/playbooks/worker.md (one sentence in step 2)
- touches: claude/workflow/docs/pr-process/pr-process.md (row F36)
- touches (generated, written only by work-order.sh start/submit/done, never by hand or git add): this ticket file and its archive path; work-orders/INDEX.md and the parent epic README.md are ignored generated views
- step: branch from origin/main in your own git worktree, never the ~/dotfiles primary clone
- step: rebase on origin/main after the gate ticket and 39da merged; make the edits exactly as in Context; render the workflow
- step: run make -C claude/workflow pr-flow-test CASES=ci-template and the AC checks only
- step: UAT after merge is the next line PR: its merge-on-green log shows 'held: TICKET-OPEN' on the head before done and a merge after; the orchestrator records it, the seat does not wait
- step: commit 'feat(workflow): merge-on-green holds TICKET-OPEN' with the ticket id; no Bump trailer
- tool: make:claude/workflow/pr-flow/pr-flow.mk:pr-flow-test - on main; tool: image localhost/dotfiles-workflow-test:1 - fallback: missing: make -C claude/workflow image, then retry once; build fails: stop with ENV-MISSING podman
- tool: cmd:gate.sh ticket-open - built by WO-20261016-e56d; fallback: absent on main: stop with DESIGN-GAP
- tool: cmd:git, cmd:jq, cmd:make, cmd:podman, cmd:gh - fallback: missing on the host: stop with ENV-MISSING naming it; gh or GitHub down: retry 3 times, then stop with A2A-003 and its output

**Out - non-goals**

- gate.sh and merge.sh: the previous ticket
- branch protection or GitHub auto-merge settings
- any file not named under In: stop with DESIGN-GAP
- work-orders/INDEX.md and epic READMEs by hand or by git add; waiting on CI or merging: push, open the PR, write the result, leave
- a Bump trailer: no skill under claude/skills changes

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [ ] `AC-H1` *(human)* the ci-template cases pass
  - check: `make -C claude/workflow pr-flow-test CASES=ci-template` exit 0 expect /ok ci-template/
- [ ] `AC-H2` *(human)* the rendered workflow runs ticket-open
  - check: `grep -c 'gate.sh ticket-open' .github/workflows/merge-on-green.yml` exit 0 expect /^1$/
- [ ] `AC-H3` *(human)* pr-process.md carries row F36
  - check: `grep -c '^| F36 |' claude/workflow/docs/pr-process/pr-process.md` exit 0 expect /^1$/
- [ ] `AC-H4` *(human)* the diff holds only In files and generated work-orders files
  - check: `git diff --name-only origin/main...HEAD | grep -vE '^(work-orders/.*|\.github/workflows/merge-on-green\.yml|claude/workflow/pr-flow/(templates/merge-on-green\.yml|tests/ci-template\.test\.sh|playbooks/worker\.md)|claude/workflow/docs/pr-process/pr-process\.md)$'` exit 1

## Test plan

```sh
{"scope":"merge-on-green template ticket-open hold","cases":[{"id":"TP-1","intent":"the Action is the first merger; without the hold it still races the close-out commit","command":"make -C claude/workflow pr-flow-test CASES=ci-template","expected":"exit 0; ok ci-template"}],"isolation":{"runtime":"podman","image":"localhost/dotfiles-workflow-test:1"},"out_of_scope":["live Action behaviour: observed on the next line PR"]}
```

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
