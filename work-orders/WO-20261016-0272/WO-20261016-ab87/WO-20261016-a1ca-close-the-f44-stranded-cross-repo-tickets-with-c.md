---
{
  "id": "WO-20261016-a1ca",
  "slug": "close-the-f44-stranded-cross-repo-tickets-with-c",
  "title": "Close the F44-stranded cross-repo tickets with check and done --code-dir: WO-20261016-64f2 (gitops-builder PR 13), WO-20261016-5751 (homelab-gitops PR 104), WO-20261016-9ad9 (homelab-gitops PR 106), WO-20261016-ddf1 (homelab-gitops PR 105)",
  "type": "chore",
  "status": "ready",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T11:34:34+00:00",
  "parent": "WO-20261016-ab87",
  "branch": null,
  "pr": null,
  "closed": null,
  "approval": {
    "via": "override",
    "reason": "infra-design18 cut for the F44 close-outs; design approvals ruled done, ORD-0550 O4",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [
    "WO-20261016-1099",
    "WO-20261016-ddf1"
  ],
  "blocks": [
    "WO-20261016-03ef",
    "WO-20261016-c315"
  ],
  "ac_checks": [
    {
      "index": 1,
      "command": "bash claude/skills/work-order/scripts/work-order.sh show --id WO-20261016-64f2 --json | jq -r .status",
      "exit": 0,
      "expect": "^done$"
    },
    {
      "index": 2,
      "command": "bash claude/skills/work-order/scripts/work-order.sh show --id WO-20261016-5751 --json | jq -r .status",
      "exit": 0,
      "expect": "^done$"
    },
    {
      "index": 3,
      "command": "bash claude/skills/work-order/scripts/work-order.sh show --id WO-20261016-9ad9 --json | jq -r .status",
      "exit": 0,
      "expect": "^done$"
    },
    {
      "index": 4,
      "command": "bash claude/skills/work-order/scripts/work-order.sh show --id WO-20261016-ddf1 --json | jq -r .status",
      "exit": 0,
      "expect": "^done$"
    },
    {
      "index": 5,
      "command": "ls -d $HOME/.cache/wt-f44-* 2>/dev/null | wc -l",
      "exit": 0,
      "expect": "^0$"
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

# WO-20261016-a1ca - Close the F44-stranded cross-repo tickets with check and done --code-dir: WO-20261016-64f2 (gitops-builder PR 13), WO-20261016-5751 (homelab-gitops PR 104), WO-20261016-9ad9 (homelab-gitops PR 106), WO-20261016-ddf1 (homelab-gitops PR 105)

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

Four cross-repo tickets carry passing checks in their code repos but cannot close, because work-order.sh done ran their checks in the dotfiles tree (F44): 64f2 is still ready on main (seat lineops-img left it in-review uncommitted; seats/lineops-img.result.json: AC-FAIL 1-3 in dotfiles, every AC passing in gitops-builder), 5751 and 9ad9 are in-review with every AC evidenced (dotfiles PRs 329 and 331), and ddf1 (the 168e recut) ends at submit by design. They hold WO-20261016-03ef and WO-20261016-c315.

## Owner words

> once 1099 lands: one close-out ticket or verb that runs done --code-dir for every F44-stranded ticket: 64f2 (gitops-builder#13), 5751 (homelab-gitops#104, dotfiles#329), 9ad9 (homelab-gitops#106, dotfiles#331), 168e after its test plan fix (homelab-gitops#105) (orchestrator brief BR-20261016-infra-design18)

> get this code merged the fuck in, dead code is shit, it sitting under agents is stupid (Design principles 101 item 21)

## Context

Order brief BR-20261016-infra-design18. Rows, id repo branch pr: WO-20261016-64f2 gitops-builder feat/line-ops-tools 13; WO-20261016-5751 homelab-gitops feat/line-ops-pr-sweep-secrets 104; WO-20261016-9ad9 homelab-gitops feat/line-ops-pr-sweep 106; WO-20261016-ddf1 homelab-gitops feat/line-ops-pr-sweep-gates 105. The code PRs need not be merged: done closes the ticket on checks that pass at the PR head, and the code PRs merge on their own green (item 21). If WO-20261016-ef1b has merged by then, check and done build their own worktree from the PR head and the --code-dir worktree below is simply a valid checkout of the repo; the steps do not change.

Steps in your own dotfiles worktree, W=claude/skills/work-order/scripts/work-order.sh, each exactly as written. 1: bash $W start --id THIS-TICKET-ID, then git commit -qam 'chore(work-orders): start THIS-TICKET-ID' so the tree is clean. 2, 64f2 only, since it never reached in-review on main: b=$(git branch --show-current); bash $W start --id WO-20261016-64f2; git checkout -q "$b"; git branch -D "$(bash $W show --id WO-20261016-64f2 --json | jq -r .branch)"; bash $W submit --id WO-20261016-64f2 --pr 13. 3, for each row: git -C $HOME/projects/<repo> fetch -q origin; git -C $HOME/projects/<repo> worktree add -q --detach $HOME/.cache/wt-f44-<id hex> origin/<branch>; bash $W check --id <id> --code-dir $HOME/.cache/wt-f44-<id hex>; bash $W done --id <id> --code-dir $HOME/.cache/wt-f44-<id hex>; git -C $HOME/projects/<repo> worktree remove --force $HOME/.cache/wt-f44-<id hex>. A check that fails: remove that worktree, stop with DESIGN-GAP naming the id, the failing index and its output; never tick by hand. 4: git add -A work-orders (generated moves only, never INDEX.md or a README), commit 'chore(work-orders): close the F44-stranded cross-repo tickets' with the ticket id, push, open the PR, submit --id THIS-TICKET-ID --pr <N>, check --id THIS-TICKET-ID, done --id THIS-TICKET-ID, commit, push, leave. THIS-TICKET-ID is this ticket's own id, the .id in its frontmatter.

## Scope

**In**

- touches (generated, by work-order.sh start, submit, check and done only): the ticket files of WO-20261016-64f2, WO-20261016-5751, WO-20261016-9ad9 and WO-20261016-ddf1 and their archive paths
- touches (generated, written only by work-order.sh start/submit/done, never by hand or git add): this ticket file and its archive path; work-orders/INDEX.md and the parent epic README.md are ignored generated views
- step: after WO-20261016-1099 merged, branch from origin/main in your own git worktree (fallback: treehouse fails, use git worktree add), never the ~/dotfiles primary clone
- step: run steps 1-4 of Context exactly
- tool: cmd:git worktree on $HOME/projects/gitops-builder and $HOME/projects/homelab-gitops - fallback: a clone is missing: git clone https://github.com/jkkelley/<repo>.git into that path; worktree add fails on a stale entry: git worktree prune, then retry once
- tool: script:claude/skills/work-order/scripts/work-order.sh - on main; fallback: a verb refuses: stop with its status code and output, never edit a ticket by hand
- tool: cmd:git, cmd:jq, cmd:make, cmd:podman, cmd:gh - fallback: missing on the host: stop with ENV-MISSING naming it; gh or GitHub down: retry 3 times, then stop with A2A-003 and its output

**Out - non-goals**

- any change in gitops-builder or homelab-gitops: the code PRs are complete; a failing check is a DESIGN-GAP, not a fix
- merging the code PRs: they merge on their own green
- any file not named under In: stop with DESIGN-GAP and hand it back to the design seat (item 30)
- work-orders/INDEX.md and epic READMEs by hand or by git add; waiting on CI or merging: push, open the PR, write the result, leave
- a Bump trailer: no skill under claude/skills changes

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [ ] `AC-H1` *(human)* WO-20261016-64f2 is done
  - check: `bash claude/skills/work-order/scripts/work-order.sh show --id WO-20261016-64f2 --json | jq -r .status` exit 0 expect /^done$/
- [ ] `AC-H2` *(human)* WO-20261016-5751 is done
  - check: `bash claude/skills/work-order/scripts/work-order.sh show --id WO-20261016-5751 --json | jq -r .status` exit 0 expect /^done$/
- [ ] `AC-H3` *(human)* WO-20261016-9ad9 is done
  - check: `bash claude/skills/work-order/scripts/work-order.sh show --id WO-20261016-9ad9 --json | jq -r .status` exit 0 expect /^done$/
- [ ] `AC-H4` *(human)* WO-20261016-ddf1 is done
  - check: `bash claude/skills/work-order/scripts/work-order.sh show --id WO-20261016-ddf1 --json | jq -r .status` exit 0 expect /^done$/
- [ ] `AC-H5` *(human)* no close-out worktree is left behind
  - check: `ls -d $HOME/.cache/wt-f44-* 2>/dev/null | wc -l` exit 0 expect /^0$/
- [ ] `AC-H6` *(human)* the diff holds only generated work-orders files
  - check: `git diff --name-only origin/main...HEAD | grep -vE '^(work-orders/.*)$'` exit 1

## Test plan

_Test plan from claude/workflow/templates/test-plan.md, shaped by claude/workflow/schemas/test-plan.schema.json. The tester runs exactly these cases and nothing else._

**Scope under test**

the four F44-stranded tickets closed by done --code-dir in their code repos

**Cases**

- `TP-1`
  - intent: tickets whose code PRs carry passing checks sit in-review forever and hold 03ef and c315 (F44)
  - command: `bash claude/skills/work-order/scripts/work-order.sh check --id THIS-TICKET-ID`
  - expected: exit 0; one AC-PASS line per criterion

**Isolation**

- runtime: podman
- image: `docker.io/library/python@sha256:2f17fc044b579bab302c2e8054d3a686e2cb9a83de48e70534b94cd8ebbe06a9` (python:3.12-slim)

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
