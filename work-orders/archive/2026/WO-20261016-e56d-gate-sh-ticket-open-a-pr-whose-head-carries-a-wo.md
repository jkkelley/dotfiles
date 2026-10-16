---
{
  "id": "WO-20261016-e56d",
  "slug": "gate-sh-ticket-open-a-pr-whose-head-carries-a-wo",
  "title": "gate.sh ticket-open: a PR whose head carries a work-order still in-progress or in-review is held TICKET-OPEN, and merge.sh holds on it",
  "type": "feature",
  "status": "cancelled",
  "priority": "p2",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T10:26:57+00:00",
  "parent": "WO-20261016-fb0c",
  "branch": null,
  "pr": null,
  "closed": "2026-10-16",
  "approval": {
    "via": "override",
    "reason": "infra-design14 cut for ORD-0830 RR-orch-14 F35; design approvals ruled done, ORD-0550 O4",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [],
  "blocks": [],
  "ac_checks": [
    {
      "index": 1,
      "command": "make -C claude/workflow pr-flow-test CASES='gate merge merge-hold'",
      "exit": 0,
      "expect": null
    },
    {
      "index": 2,
      "command": "make -C claude/workflow pr-flow-lint",
      "exit": 0,
      "expect": null
    },
    {
      "index": 3,
      "command": "make rolodex-check BASE=origin/main",
      "exit": 0,
      "expect": null
    },
    {
      "index": 4,
      "command": "git diff --name-only origin/main...HEAD | grep -vE '^(work-orders/.*|claude/workflow/pr-flow/(bin/gate\\.sh|bin/merge\\.sh|tests/gate\\.test\\.sh|tests/merge-hold\\.test\\.sh))$'",
      "exit": 1,
      "expect": null
    }
  ],
  "provides": [
    "cmd:gate.sh ticket-open"
  ],
  "labels": [
    "line:inbox-triage"
  ],
  "superseded_by": "WO-20261016-0233"
}
---

# WO-20261016-e56d - gate.sh ticket-open: a PR whose head carries a work-order still in-progress or in-review is held TICKET-OPEN, and merge.sh holds on it

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

Three times (448e, PR 273, PR 285) a PR squash-merged on green before its seat pushed the work-order.sh submit and done commit, stranding the close-out on a deleted branch; the ticket stays ready or in-progress on main and the close-out ticket WO-20261016-ea9e then failed on branch_exists. The worker playbook asks the seat to win a race against CI. The merge must instead refuse a head whose ticket is not closed.

## Owner words

> F36 class: close-out after squash merge. Third time (PR 273, PR 285, earlier 448e): a seat pushes its work-order.sh done commit after the PR already squash-merged ... or the merge loop refuses a PR whose ticket is not done (orchestrator brief BR-20261016-infra-design14)

> get this code merged the fuck in, dead code is shit (Design principles 101 item 21)

> if the task or job needs tools, the architect has a design agent build that shit out before the ticket goes in, thats a prereq for the ticket ready then (Design principles 101 item 30)

## Context

Order brief BR-20261016-infra-design14, ORD-0830 RR-orch-14; F35; evidence ~/.local/state/zenith/inbox-triage/20261015/seats/close-6e7f.result.json (branch feat/wk-d-wiki-engine-design-doc-and-xml-spec-mermaid tip a8b8410 'chore(work-orders): close WO-20261016-6e7f' unmerged; PR 285 squash-merged only f2a130c). The other option in the order (submit and done before gh pr create) cannot work: submit needs the PR number. So the gate holds.

New verb, exact: gate.sh ticket-open [--repo DIR] --base REF --sha SHA. (1) resolve SHA as gate.sh same-head does (one git fetch origin, else exit 4). (2) MB = git merge-base REF SHA. (3) P = git diff --name-only --diff-filter=AMR MB SHA filtered by ^work-orders/ and WO-[0-9]{8}-[0-9a-f]{4}-[^/]*\.md$ and not ^work-orders/archive/. (4) for each P: git show SHA:P, take the JSON between the first two '---' lines, jq -r .status; status in-progress or in-review prints 'TICKET-OPEN WO-id status' (WO-id from the json .id). (5) any printed: exit 1; none: exit 0. Usage errors exit 2. Ready and draft tickets do not hold, so design PRs that cut tickets merge. Header usage block and Exit line updated; breadcrumb names this ticket and the close-6e7f evidence.

merge.sh: after gate.sh ci-green returns 0 for a PR (line ~359), call gate.sh ticket-open --repo "$REPO_DIR" --base origin/<base> --sha "$head"; rc 1 is the held path with reason 'TICKET-OPEN <ids>' (code 3, nothing merged, the same records merge.sh already posts for held); rc 4 is the existing fail_io path. Tests: pr-flow/tests/gate.test.sh gains 4 cases (in-progress ticket held 1 with TICKET-OPEN; archived done ticket 0; new ready ticket 0; no work-orders file 0) and pr-flow/tests/merge-hold.test.sh gains 1 case (ci green, ticket in-review: held 3, gh pr merge never called).

## Scope

**In**

- touches: claude/workflow/pr-flow/bin/gate.sh (ticket-open verb, usage, breadcrumb)
- touches: claude/workflow/pr-flow/bin/merge.sh (one call after ci-green, as in Context)
- touches: claude/workflow/pr-flow/tests/gate.test.sh (4 appended cases)
- touches: claude/workflow/pr-flow/tests/merge-hold.test.sh (1 appended case)
- touches (generated, written only by work-order.sh start/submit/done, never by hand or git add): this ticket file and its archive path; work-orders/INDEX.md and the parent epic README.md are ignored generated views
- step: branch from origin/main in your own git worktree, never the ~/dotfiles primary clone
- step: write the verb, the call and the cases exactly as in Context
- step: run make -C claude/workflow pr-flow-test CASES='gate merge merge-hold' and pr-flow-lint and make rolodex-check BASE=origin/main and the AC checks only
- step: commit 'feat(workflow): pr-flow holds a PR whose ticket is still open (TICKET-OPEN)' with the ticket id; no Bump trailer
- tool: make:claude/workflow/pr-flow/pr-flow.mk:pr-flow-test - on main; tool: image localhost/dotfiles-workflow-test:1 - fallback: missing: make -C claude/workflow image, then retry once; build fails: stop with ENV-MISSING podman
- tool: cmd:git, cmd:jq, cmd:make, cmd:podman, cmd:gh - fallback: missing on the host: stop with ENV-MISSING naming it; gh or GitHub down: retry 3 times, then stop with A2A-003 and its output

**Out - non-goals**

- the merge-on-green Action: the next ticket calls this verb from it
- the worker playbook and pr-process docs: the merge-on-green ticket updates them
- any file not named under In: stop with DESIGN-GAP
- work-orders/INDEX.md and epic READMEs by hand or by git add; waiting on CI or merging: push, open the PR, write the result, leave
- a Bump trailer: no skill under claude/skills changes

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [ ] `AC-H1` *(human)* gate, merge and merge-hold cases pass
  - check: `make -C claude/workflow pr-flow-test CASES='gate merge merge-hold'` exit 0
- [ ] `AC-H2` *(human)* pr-flow scripts lint clean
  - check: `make -C claude/workflow pr-flow-lint` exit 0
- [ ] `AC-H3` *(human)* every changed script has a rolodex header
  - check: `make rolodex-check BASE=origin/main` exit 0
- [ ] `AC-H4` *(human)* the diff holds only In files and generated work-orders files
  - check: `git diff --name-only origin/main...HEAD | grep -vE '^(work-orders/.*|claude/workflow/pr-flow/(bin/gate\.sh|bin/merge\.sh|tests/gate\.test\.sh|tests/merge-hold\.test\.sh))$'` exit 1

## Test plan

```sh
{"scope":"gate.sh ticket-open and the merge.sh hold","cases":[{"id":"TP-1","intent":"a PR merged before its close-out commit strands the ticket (448e, 273, 285); the gate must hold an open ticket and pass ready, draft and archived ones","command":"make -C claude/workflow pr-flow-test CASES=gate","expected":"exit 0; ok gate"},{"id":"TP-2","intent":"the backstop merge must not merge what the gate holds","command":"make -C claude/workflow pr-flow-test CASES=merge-hold","expected":"exit 0; ok merge-hold"}],"isolation":{"runtime":"podman","image":"localhost/dotfiles-workflow-test:1"},"out_of_scope":["the GitHub Action: next ticket","the full pr-flow suite: CI runs it"]}
```

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

Cancelled `2026-10-16` - nothing shipped.

- reason: AC-H1 needs claude/workflow/pr-flow/tests/lib-merge.sh, not under In; recut with it in touches and the real-commit fixture ruling
- superseded by: `WO-20261016-0233`

No branch, no PR and no merge commit exist for this work order.

