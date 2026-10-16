---
{
  "id": "WO-20261016-a425",
  "slug": "close-the-merged-gitops-ci-mk-ticket-wo-20261016",
  "title": "Close the merged gitops-ci.mk ticket WO-20261016-ae02 (PR 347), TP-1 mounting the git common dir (recut of WO-20261016-436e)",
  "type": "chore",
  "status": "ready",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T12:50:26+00:00",
  "parent": "WO-20261016-770f",
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
  "depends_on": [],
  "blocks": [],
  "ac_checks": [
    {
      "index": 1,
      "command": "bash claude/skills/work-order/scripts/work-order.sh show --id WO-20261016-ae02 --json | jq -r .status",
      "exit": 0,
      "expect": "^done$"
    },
    {
      "index": 2,
      "command": "make -C claude/workflow image >/dev/null && podman run --rm --network=none --userns=keep-id -v \"$PWD:/work:Z\" -v \"$(git rev-parse --path-format=absolute --git-common-dir):$(git rev-parse --path-format=absolute --git-common-dir):ro\" -w /work -e HOME=/tmp localhost/dotfiles-workflow-test:1 bash -c 'make -f claude/workflow/gitops-ci/gitops-ci.mk gitops-select REPO=jkkelley/homelab-gitops REPO_DIR=$PWD BASE=HEAD SELECT=/tmp/gc-s.json && jq -c .deploy /tmp/gc-s.json'",
      "exit": 0,
      "expect": "^false$"
    },
    {
      "index": 3,
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

# WO-20261016-a425 - Close the merged gitops-ci.mk ticket WO-20261016-ae02 (PR 347), TP-1 mounting the git common dir (recut of WO-20261016-436e)

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

WO-20261016-ae02 (PR 347, in-review) merged but stays open, found by work-order.sh stale-merged (READY-MERGED); open tickets that are merged block their dependents (WO-20261016-21b4) and inflate next --line. Recut of WO-20261016-436e, whose TP-1 could not pass from a git worktree: .git there is a file pointing at the common dir, which was not mounted in podman, so git inside the container failed with 'fatal: not a git repository'.

## Owner words

> ORD-1140 S3: cut ready dotfiles leaves to keep the ready buffer at 6 (L0 first per ORD-0537); declare disjoint touches. get this code merged the fuck in, dead code is shit, it sitting under agents is stupid (Design principles 101 item 21)

> make sure you clean up too (Design principles 101 item 11)

## Context

Found by infra-design21 inventory: work-order.sh stale-merged lists WO-20261016-ae02 (PR 347, in-review) as READY-MERGED; its ## Acceptance criteria are all [x] with observed lines, so done needs no evidence call. Same close-out shape as WO-20261016-5092 (close of WO-20261016-5569). Closing ae02 lets WO-20261016-21b4 (gitops-ci dev gate) run.

Proven by infra-design23 from a worktree on origin/main 93dcff5: the TP-1 command below printed false and exited 0; the same command without the second -v (the git common dir at its own absolute path, read-only) printed 'fatal: not a git repository: /home/luna/dotfiles/.git/worktrees/<name>' and exited 2. From a primary clone the common dir is .git inside /work and the extra mount is harmless.

## Scope

**In**

- touches: none outside work-orders: the WO-20261016-ae02 ticket files move to work-orders/archive/2026/ by work-order.sh done only
- touches (generated, written only by work-order.sh start/submit/evidence/done, never by hand or git add): this ticket file and its archive path; work-orders/INDEX.md and the parent epic README.md are ignored generated views
- step: branch from origin/main in your own git worktree (fallback: treehouse fails, use git worktree add), never the ~/dotfiles primary clone; bash claude/skills/work-order/scripts/work-order.sh start --id THIS-TICKET-ID
- step: run TP-1; red: stop with DESIGN-GAP and its output, never close ae02
- step: bash claude/skills/work-order/scripts/work-order.sh done --id WO-20261016-ae02; then bash claude/skills/work-order/scripts/work-order.sh check --id THIS-TICKET-ID; commit 'chore(work-orders): close ae02 at merged PR 347' with this ticket id; no Bump trailer; push, gh pr create, submit --pr <N>, done on the branch, push, leave
- tool: make:claude/workflow/Makefile:image - on main; fallback: the image fails to build: stop with ENV-MISSING podman
- tool: cmd:git, cmd:jq, cmd:gh, cmd:make, cmd:podman - fallback: missing on the host: stop with ENV-MISSING naming it; gh or GitHub down: retry 3 times, then stop with A2A-003 and its output

**Out - non-goals**

- any edit to the closed ticket's content beyond what work-order.sh done writes
- any file outside work-orders/: stop with DESIGN-GAP
- work-orders/INDEX.md and epic READMEs by hand or by git add; waiting on CI or merging: push, open the PR, write the result, leave

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [ ] `AC-H1` *(human)* WO-20261016-ae02 is done
  - check: `bash claude/skills/work-order/scripts/work-order.sh show --id WO-20261016-ae02 --json | jq -r .status` exit 0 expect /^done$/
- [ ] `AC-H2` *(human)* the merged code is green on main (TP-1), from a worktree or a primary clone
  - check: `make -C claude/workflow image >/dev/null && podman run --rm --network=none --userns=keep-id -v "$PWD:/work:Z" -v "$(git rev-parse --path-format=absolute --git-common-dir):$(git rev-parse --path-format=absolute --git-common-dir):ro" -w /work -e HOME=/tmp localhost/dotfiles-workflow-test:1 bash -c 'make -f claude/workflow/gitops-ci/gitops-ci.mk gitops-select REPO=jkkelley/homelab-gitops REPO_DIR=$PWD BASE=HEAD SELECT=/tmp/gc-s.json && jq -c .deploy /tmp/gc-s.json'` exit 0 expect /^false$/
- [ ] `AC-H3` *(human)* the diff holds only work-orders files
  - check: `git diff --name-only origin/main...HEAD | grep -vE '^(work-orders/.*)$'` exit 1

## Test plan

_Test plan from claude/workflow/templates/test-plan.md, shaped by claude/workflow/schemas/test-plan.schema.json. The tester runs exactly these cases and nothing else._

**Scope under test**

the merged claude/workflow/gitops-ci/gitops-ci.mk on origin/main

**Cases**

- `TP-1`
  - intent: gitops-select still runs from the merged gitops-ci.mk before ae02 closes; the git common dir is mounted at its own path so git works from a worktree, whose .git is a file pointing at it (DESIGN-GAP fix, infra-design23)
  - command: `make -C claude/workflow image >/dev/null && podman run --rm --network=none --userns=keep-id -v "$PWD:/work:Z" -v "$(git rev-parse --path-format=absolute --git-common-dir):$(git rev-parse --path-format=absolute --git-common-dir):ro" -w /work -e HOME=/tmp localhost/dotfiles-workflow-test:1 bash -c 'make -f claude/workflow/gitops-ci/gitops-ci.mk gitops-select REPO=jkkelley/homelab-gitops REPO_DIR=$PWD BASE=HEAD SELECT=/tmp/gc-s.json && jq -c .deploy /tmp/gc-s.json'`
  - expected: exit 0 and false

**Isolation**

- runtime: podman
- image: `localhost/dotfiles-workflow-test:1`
- build: `make -C claude/workflow image`
- containerfile: claude/workflow/tests/container/Containerfile

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
