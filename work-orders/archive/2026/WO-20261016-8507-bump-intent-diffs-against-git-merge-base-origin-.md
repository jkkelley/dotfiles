---
{
  "id": "WO-20261016-8507",
  "slug": "bump-intent-diffs-against-git-merge-base-origin-",
  "title": "bump intent diffs against git merge-base origin/main HEAD (bump-gate.sh base), so a skill-publish commit on main never reads as the branch's own version edit",
  "type": "bug",
  "status": "done",
  "priority": "p2",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T10:27:22+00:00",
  "parent": "WO-20261016-fb0c",
  "branch": "feat/bump-intent-diffs-against-git-merge-base-origin-",
  "pr": 309,
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
      "command": "bash .github/scripts/testing/run-tests.sh",
      "exit": 0,
      "expect": null
    },
    {
      "index": 2,
      "command": "grep -c 'github.event.pull_request.base.sha' .github/workflows/skill-pr-intent.yml",
      "exit": 1,
      "expect": "^0$"
    },
    {
      "index": 3,
      "command": "grep -c 'bump-gate.sh base --ref' .github/workflows/skill-pr-intent.yml",
      "exit": 0,
      "expect": "^1$"
    },
    {
      "index": 4,
      "command": "git diff --name-only origin/main...HEAD | grep -vE '^(work-orders/.*|\\.github/scripts/(bump-gate\\.sh|testing/run-tests\\.sh)|\\.github/workflows/skill-pr-intent\\.yml)$'",
      "exit": 1,
      "expect": null
    }
  ],
  "provides": [
    "cmd:bump-gate.sh base"
  ],
  "labels": [
    "line:inbox-triage"
  ]
}
---

# WO-20261016-8507 - bump intent diffs against git merge-base origin/main HEAD (bump-gate.sh base), so a skill-publish commit on main never reads as the branch's own version edit

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

skill-pr-intent.yml passes BASE = github.event.pull_request.base.sha to bump-gate.sh resolve and skill-version.sh verify --structure. When skill-publish commits a version allocation to main after the branch was cut, BASE is older than the main the merge ref is built on, the diff shows registry.json and version: as edited by the branch, and the job fails (PRs 274, 277, 297, 298 at 3285e3b and a3b4099), clearing only after the seat merges main in.

## Owner words

> skill-pr-gate bump intent compares the PR head merge ref against BASE = the PR base sha at event time ... Cut a tooling ticket: the gate diffs against git merge-base origin/main HEAD (orchestrator brief BR-20261016-infra-design14)

> CICD SPEED IS KING (Design principles 101 item 1)

## Context

Order brief BR-20261016-infra-design14, ORD-0830 RR-orch-14; F35. Evidence: gh run view 38885290759 -R jkkelley/dotfiles --log-failed: job 'bump intent', step 'no hand-edited version, no hand-edited registry': 'registry.json edited in this diff', 'version: edited in this diff work-order/SKILL.md', fix hint 'git checkout a3b4099... -- <path>'. The job is in .github/workflows/skill-pr-intent.yml (two BASE env lines, 53 and 70). skill-pr-gate.yml also reads base.sha but is in WO-20261016-75b7's In list, so it is out of scope here.

New verb, exact: bump-gate.sh base --ref REF prints git merge-base REF HEAD on stdout, exit 0; REF not resolvable or no merge base: stderr reason, exit 2. Workflow, exact: in skill-pr-intent.yml add a step right after checkout named 'BASE is the merge base with the target branch' running: set -euo pipefail; git fetch --no-tags origin "+refs/heads/$BASE_REF:refs/remotes/origin/$BASE_REF"; echo "BASE=$(bash .github/scripts/bump-gate.sh base --ref origin/$BASE_REF)" >> "$GITHUB_ENV", with env BASE_REF: ${{ github.base_ref }}; remove the two 'BASE: ${{ github.event.pull_request.base.sha }}' env lines so both steps read BASE from GITHUB_ENV. A comment above the new step is the breadcrumb: what broke (the four PRs), why merge-base (it equals the current base on a merge ref), the rejected alternative (re-running after merging main: a hand step), this ticket id.

Test, appended to .github/scripts/testing/run-tests.sh as one case in its existing style: fixture repo, branch cut from main, then main gets a commit editing registry.json and a version: line; the merge commit of the branch into main is HEAD; skill-version.sh verify --structure --base <old base sha> exits 1 and --base $(bump-gate.sh base --ref main) exits 0.

## Scope

**In**

- touches: .github/scripts/bump-gate.sh (base verb, usage line)
- touches: .github/workflows/skill-pr-intent.yml (the new step, the two env lines removed)
- touches: .github/scripts/testing/run-tests.sh (one appended case)
- touches (generated, written only by work-order.sh start/submit/done, never by hand or git add): this ticket file and its archive path; work-orders/INDEX.md and the parent epic README.md are ignored generated views
- step: branch from origin/main in your own git worktree, never the ~/dotfiles primary clone
- step: write the verb, the step and the case exactly as in Context
- step: run bash .github/scripts/testing/run-tests.sh (it runs itself in podman) and the AC checks only
- step: commit 'fix(ci): bump intent diffs against the merge base' with the ticket id; no Bump trailer
- tool: cmd:bash .github/scripts/testing/run-tests.sh - on main, re-execs in podman; fallback: podman missing: stop with ENV-MISSING podman
- tool: cmd:git, cmd:jq, cmd:make, cmd:podman, cmd:gh - fallback: missing on the host: stop with ENV-MISSING naming it; gh or GitHub down: retry 3 times, then stop with A2A-003 and its output

**Out - non-goals**

- .github/workflows/skill-pr-gate.yml: WO-20261016-75b7 owns it; a follow-up after it merges
- skill-version.sh: unchanged, it already takes --base
- any file not named under In: stop with DESIGN-GAP
- work-orders/INDEX.md and epic READMEs by hand or by git add; waiting on CI or merging: push, open the PR, write the result, leave
- a Bump trailer: no skill under claude/skills changes

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [x] `AC-H1` *(human)* the bump-gate fixture suite passes with the merge-base case
  - observed `2026-10-16` run-tests.sh in podman: 150 passed, 0 failed, exit 0
  - check: `bash .github/scripts/testing/run-tests.sh` exit 0
- [x] `AC-H2` *(human)* no step of skill-pr-intent.yml reads the event base sha
  - observed `2026-10-16` grep -c prints 0, exit 1
  - check: `grep -c 'github.event.pull_request.base.sha' .github/workflows/skill-pr-intent.yml` exit 1 expect /^0$/
- [x] `AC-H3` *(human)* the merge base step is present
  - observed `2026-10-16` grep -c prints 1, exit 0
  - check: `grep -c 'bump-gate.sh base --ref' .github/workflows/skill-pr-intent.yml` exit 0 expect /^1$/
- [x] `AC-H4` *(human)* the diff holds only In files and generated work-orders files
  - observed `2026-10-16` grep -v filter prints nothing, exit 1
  - check: `git diff --name-only origin/main...HEAD | grep -vE '^(work-orders/.*|\.github/scripts/(bump-gate\.sh|testing/run-tests\.sh)|\.github/workflows/skill-pr-intent\.yml)$'` exit 1

## Test plan

```sh
{"scope":"bump-gate.sh base and the bump intent base","cases":[{"id":"TP-1","intent":"a version allocation on main after the branch was cut turns every skill PR red (274, 277, 297, 298); the merge base must hide it","command":"bash .github/scripts/testing/run-tests.sh","expected":"exit 0; the merge-base case passes"}],"isolation":{"runtime":"podman","image":"localhost/dotfiles-workflow-test:1"},"out_of_scope":["live Actions: the next skill PR after a publish commit shows bump intent green"]}
```

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
