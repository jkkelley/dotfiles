---
{
  "id": "WO-20261016-0233",
  "slug": "gate-sh-ticket-open-a-pr-whose-head-carries-a-wo",
  "title": "gate.sh ticket-open: a PR whose head carries a work-order still in-progress or in-review is held TICKET-OPEN, merge.sh holds on it, and lib-merge.sh fixture heads are real commits on origin",
  "type": "feature",
  "status": "done",
  "priority": "p2",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T10:53:18+00:00",
  "parent": "WO-20261016-fb0c",
  "branch": "feat/0233-gate-sh-ticket-open-a-pr-whose-head-carries-a-wo",
  "pr": 322,
  "closed": "2026-10-16",
  "approval": {
    "via": "override",
    "reason": "infra-design16 recut for ORD-0830 RR-orch-14 F35; design approvals ruled done, ORD-0550 O4",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [],
  "blocks": [
    "WO-20261016-ac25"
  ],
  "ac_checks": [
    {
      "index": 1,
      "command": "make -C claude/workflow pr-flow-test CASES='gate merge merge-hold merge-cleanup'",
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
      "command": "git diff --name-only origin/main...HEAD | grep -vE '^(work-orders/.*|claude/workflow/pr-flow/(bin/gate\\.sh|bin/merge\\.sh|tests/gate\\.test\\.sh|tests/merge-hold\\.test\\.sh|tests/lib-merge\\.sh))$'",
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

# WO-20261016-0233 - gate.sh ticket-open: a PR whose head carries a work-order still in-progress or in-review is held TICKET-OPEN, merge.sh holds on it, and lib-merge.sh fixture heads are real commits on origin

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

Three times (448e, PR 273, PR 285) a PR squash-merged on green before its seat pushed the work-order.sh submit and done commit, stranding the close-out on a deleted branch; the ticket stays ready or in-progress on main and the close-out ticket WO-20261016-ea9e then failed on branch_exists. The worker playbook asks the seat to win a race against CI. The merge must instead refuse a head whose ticket is not closed. Recut of WO-20261016-e56d: its AC-H1 (pr-flow-test CASES='gate merge merge-hold') cannot pass without editing claude/workflow/pr-flow/tests/lib-merge.sh, which e56d did not name under In; e56d is ready on main so amend refuses.

## Owner words

> F36 class: close-out after squash merge. Third time (PR 273, PR 285, earlier 448e): a seat pushes its work-order.sh done commit after the PR already squash-merged ... or the merge loop refuses a PR whose ticket is not done (orchestrator brief BR-20261016-infra-design14)

> get this code merged the fuck in, dead code is shit (Design principles 101 item 21)

> if the task or job needs tools, the architect has a design agent build that shit out before the ticket goes in, thats a prereq for the ticket ready then (Design principles 101 item 30)

> DESIGN-GAP e56d tests/lib-merge.sh: AC1 cannot pass without editing claude/workflow/pr-flow/tests/lib-merge.sh, not under In; add it to touches. (orchestrator brief BR-20261016-infra-design16)

## Context

Order brief BR-20261016-infra-design14, ORD-0830 RR-orch-14; F35; evidence ~/.local/state/zenith/inbox-triage/20261015/seats/close-6e7f.result.json (branch feat/wk-d-wiki-engine-design-doc-and-xml-spec-mermaid tip a8b8410 'chore(work-orders): close WO-20261016-6e7f' unmerged; PR 285 squash-merged only f2a130c). The other option in the order (submit and done before gh pr create) cannot work: submit needs the PR number. So the gate holds. New verb, exact: gate.sh ticket-open [--repo DIR] --base REF --sha SHA. (1) resolve SHA as gate.sh same-head does (one git fetch origin, else exit 4). (2) MB = git merge-base REF SHA. (3) P = git diff --name-only --diff-filter=AMR MB SHA filtered by ^work-orders/ and WO-[0-9]{8}-[0-9a-f]{4}-[^/]*\.md$ and not ^work-orders/archive/. (4) for each P: git show SHA:P, take the JSON between the first two '---' lines, jq -r .status; status in-progress or in-review prints 'TICKET-OPEN WO-id status' (WO-id from the json .id). (5) any printed: exit 1; none: exit 0. Usage errors exit 2. Ready and draft tickets do not hold, so design PRs that cut tickets merge. Header usage block and Exit line updated; breadcrumb names this ticket and the close-6e7f evidence. merge.sh: after gate.sh ci-green returns 0 for a PR (line ~359), call gate.sh ticket-open --repo "$REPO_DIR" --base origin/<base> --sha "$head"; rc 1 is the held path with reason 'TICKET-OPEN <ids>' (code 3, nothing merged, the same records merge.sh already posts for held); rc 4 is the existing fail_io path. Tests: pr-flow/tests/gate.test.sh gains 4 cases (in-progress ticket held 1 with TICKET-OPEN; archived done ticket 0; new ready ticket 0; no work-orders file 0) and pr-flow/tests/merge-hold.test.sh gains 1 case (ci green, ticket in-review: held 3, gh pr merge never called).

Recut ruling (infra-design16, BR-20261016-infra-design16): fixture heads become real commits; merge.sh does NOT treat an unresolvable head as pass, because a gate that passes what it cannot read fails open and merges an open ticket. Evidence /home/luna/.local/state/zenith/inbox-triage/20261015/seats/ticket-open.result.json: lib-merge.sh hd() mints aaaa...NN heads that are not commits in the clone, so ticket-open's resolve fetch fails, exit 4, merge.sh routes rc 4 to fail_io, merge.test.sh pass=13 fail=14.

lib-merge.sh change, exact: hd N (line 47) becomes: if git -C $W/clone ls-remote --exit-code --heads origin feat/t$N >/dev/null, print git -C $W/clone ls-remote origin refs/heads/feat/t$N | cut -f1; else from origin/main in $W/clone: git switch -qc feat/t$N origin/main; git commit -q --allow-empty -m t$N; git push -q origin feat/t$N; git switch -q main; print git rev-parse feat/t$N. Output stays one 40-hex line per N, distinct per N, stable on a second call (feat/t7 reuses the branch fixture_up already pushed). pr_set keeps calling hd; nothing else in lib-merge.sh changes. Explicit headRefOid overrides in merge.test.sh (pr 13 bb..b2, the moved ff..ff) stay: the conflict path returns before ci-green and the moved case is held by the merge loop, so neither reaches ticket-open.

The seat worktree /home/luna/.local/state/zenith/wt/ticket-open (branch feat/wk-ticket-open-gate, 4 In files written, uncommitted) is the previous seat's work; a new seat may copy its gate.sh, merge.sh and test edits as a start, but builds and proves on its own branch from origin/main.

## Scope

**In**

- touches: claude/workflow/pr-flow/bin/gate.sh (ticket-open verb, usage, breadcrumb)
- touches: claude/workflow/pr-flow/bin/merge.sh (one call after ci-green, as in Context)
- touches: claude/workflow/pr-flow/tests/gate.test.sh (4 appended cases)
- touches: claude/workflow/pr-flow/tests/merge-hold.test.sh (1 appended case)
- touches: claude/workflow/pr-flow/tests/lib-merge.sh (hd only, exactly as in Context, with a breadcrumb naming this ticket and ticket-open.result.json)
- touches (generated, written only by work-order.sh start/submit/done, never by hand or git add): this ticket file and its archive path; work-orders/INDEX.md and the parent epic README.md are ignored generated views
- step: branch from origin/main in your own git worktree, never the ~/dotfiles primary clone
- step: write the verb, the call, the hd change and the cases exactly as in Context
- step: run the AC checks only; CI runs the full suite
- step: commit 'feat(workflow): pr-flow holds a PR whose ticket is still open (TICKET-OPEN)' with the ticket id; no Bump trailer
- tool: make:claude/workflow/pr-flow/pr-flow.mk:pr-flow-test - on main; image localhost/dotfiles-workflow-test:1 - fallback: missing: make -C claude/workflow image, then retry once; build fails: stop with ENV-MISSING podman
- tool: make:claude/workflow/pr-flow/pr-flow.mk:pr-flow-lint and make:Makefile:rolodex-check - on main; fallback: missing: stop with DESIGN-GAP naming it
- tool: cmd:git, cmd:jq, cmd:make, cmd:podman, cmd:gh - fallback: missing on the host: stop with ENV-MISSING naming it; gh or GitHub down: retry 3 times, then stop with A2A-003 and its output

**Out - non-goals**

- the merge-on-green Action: WO-20261016-ac25 calls this verb from it
- the worker playbook and pr-process docs: the merge-on-green ticket updates them
- merge.test.sh, merge-cleanup.test.sh and any other lib-merge.sh function: unchanged
- any file not named under In: stop with DESIGN-GAP
- work-orders/INDEX.md and epic READMEs by hand or by git add; waiting on CI or merging: push, open the PR, write the result, leave
- a Bump trailer: no skill under claude/skills changes

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [x] `AC-H1` *(human)* gate, merge, merge-hold and merge-cleanup cases pass
  - observed `2026-10-16` make pr-flow-test CASES='gate merge merge-hold merge-cleanup' exit 0: ok gate, merge, merge-hold, merge-cleanup
  - check: `make -C claude/workflow pr-flow-test CASES='gate merge merge-hold merge-cleanup'` exit 0
- [x] `AC-H2` *(human)* pr-flow scripts lint clean
  - observed `2026-10-16` make pr-flow-lint exit 0
  - check: `make -C claude/workflow pr-flow-lint` exit 0
- [x] `AC-H3` *(human)* every changed script has a rolodex header
  - observed `2026-10-16` make rolodex-check BASE=origin/main exit 0
  - check: `make rolodex-check BASE=origin/main` exit 0
- [x] `AC-H4` *(human)* the diff holds only In files and generated work-orders files
  - observed `2026-10-16` grep -vE filter over git diff --name-only origin/main...HEAD printed nothing, exit 1
  - check: `git diff --name-only origin/main...HEAD | grep -vE '^(work-orders/.*|claude/workflow/pr-flow/(bin/gate\.sh|bin/merge\.sh|tests/gate\.test\.sh|tests/merge-hold\.test\.sh|tests/lib-merge\.sh))$'` exit 1

## Test plan

_Test plan from claude/workflow/templates/test-plan.md, shaped by claude/workflow/schemas/test-plan.schema.json. The tester runs exactly these cases and nothing else._

**Scope under test**

gate.sh ticket-open, the merge.sh hold on it, and the lib-merge.sh fixture heads it resolves

**Cases**

- `TP-1`
  - intent: a PR merged before its close-out commit strands the ticket (448e, 273, 285); the gate must hold an open ticket and pass ready, draft and archived ones
  - command: `make -C claude/workflow pr-flow-test CASES=gate`
  - expected: exit 0; ok gate
- `TP-2`
  - intent: the merge loop must not merge what the gate holds, and every merge case still merges now that fixture heads are real commits on origin
  - command: `make -C claude/workflow pr-flow-test CASES='merge merge-hold merge-cleanup'`
  - expected: exit 0; ok merge, ok merge-hold, ok merge-cleanup

**Isolation**

_A locally built image uses `- image: localhost/<name>:<tag>` plus `- build: <command>` and `- containerfile: <path>` lines, never a localhost digest (RR-orch-18)._

- runtime: podman
- image: `localhost/dotfiles-workflow-test:1`
- build: `make -C claude/workflow image`
- containerfile: `claude/workflow/tests/container/Containerfile`

**Out of scope - CI covers**

- the GitHub merge-on-green Action: WO-20261016-ac25
- the full pr-flow suite: CI runs it

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
