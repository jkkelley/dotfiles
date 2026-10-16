---
{
  "id": "WO-20261016-f57d",
  "slug": "ticket-repo-field-new-repo-and-set-repo-name-the",
  "title": "Ticket repo field: new --repo and set --repo name the code repo OWNER/NAME; submit and stale-merged resolve a bare pr there (2d5b TP-3)",
  "type": "feature",
  "status": "cancelled",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T09:43:24+00:00",
  "parent": "WO-20261016-fb0c",
  "branch": null,
  "pr": null,
  "closed": "2026-10-16",
  "approval": {
    "via": "override",
    "reason": "infra-design11 cut for ORD-0932-next Q2 and the ORD-0830 RR-orch-14 DESIGN-GAPs; design approvals ruled done, ORD-0550 O4",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [
    "WO-20261016-67c7"
  ],
  "blocks": [],
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
      "command": "bash -c '! git diff --name-only origin/main...HEAD | grep -vE \"^(work-orders/.*|claude/skills/work-order/scripts/work-order[.]sh|claude/skills/work-order/testing/cases/360-ticket-repo[.]sh)$\"'",
      "exit": 0,
      "expect": null
    }
  ],
  "provides": [
    "claude/skills/work-order/testing/cases/360-ticket-repo.sh"
  ],
  "superseded_by": "WO-20261016-9c09"
}
---

# WO-20261016-f57d - Ticket repo field: new --repo and set --repo name the code repo OWNER/NAME; submit and stale-merged resolve a bare pr there (2d5b TP-3)

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

Business tickets store pr as a bare number with no repo: WO-20261016-c770 pr 52 lives in ypconsult-01-src while other business tickets have PRs (68) in the business repo itself, so one --pr-repo per run cannot be right for both, and stale-merged looks a bare number up in the wrong repo (WO-20261016-2d5b TP-3 unmet; evidence seats/stale-merged.result.json). submit has the same blind spot: gh pr view <n> runs in the ticket project, so a code PR in another repo is pr_not_found.

## Owner words

> get this code merged the fuck in, dead code is shit, it sitting under agents is stupid (item 21)

> so its re-usable, add to it, makefiles, dont' be a crackhead and one off shit all the time, if we need to do so (item 30)

## Context

DESIGN-GAP WO-20261016-2d5b TP-3: business tickets store pr as a bare number (c770 pr 52, 68) with no repo, so stale-merged cannot resolve the repo; E2 fix resolves only URL-valued pr. Name the source (record PR URL at submit, or a --pr-repo per project config).

Source named by this design: a per-ticket frontmatter key repo, OWNER/NAME of the repo the ticket code PR lands in, null by default (null means the project repo). One key serves stale-merged, submit and approve (the approve ticket that follows reads the same key). Fixed: (1) new --repo OWNER/NAME; set gains --repo OWNER/NAME and --clear-repo (same rules as labels: writes only .repo, any non-archived status, idempotent byte-identical). Syntax ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$, else exit 2 bad_repo. (2) submit: when .repo is set, gh pr view <n> -R <repo>; .pr stays a number. (3) merged_info and stale-merged repo precedence: a URL pr names its own repo; else ticket .repo; else --pr-repo; else gh repo view in the project. The row repo field reports the one used. (4) Breadcrumb at the precedence line citing 2d5b TP-3.

Rejected: recording the PR URL at submit, because it leaves every already-submitted bare-number ticket unresolvable and still needs a repo to verify the PR at submit; rejected: a project config map, because one project holds tickets for several code repos. Setting .repo on the live business tickets (c770, eb12, f58e and the ypli/ypconsult code tickets) is a business design seat run of set --repo once this merges.

## Scope

**In**

- touches: claude/skills/work-order/scripts/work-order.sh (new --repo; set --repo/--clear-repo; submit -R; merged_info precedence; usage lines; breadcrumb)
- touches: claude/skills/work-order/testing/cases/360-ticket-repo.sh (new, gh stubbed and logging its argv: bare pr with .repo -> gh called with -R that repo and the row repo is it; bare pr without .repo and --pr-repo X -> X; URL pr wins over .repo; submit with .repo calls gh pr view <n> -R <repo>; set --repo twice leaves git diff --quiet; --clear-repo writes null; bad repo exit 2 bad_repo; new --repo writes the key)
- touches (generated, written only by work-order.sh start/submit/done, never by hand or git add): this ticket file and its archive path; work-orders/INDEX.md and the parent epic README.md are ignored generated views
- step: branch from origin/main in your own worktree after the ticket it depends on merged; write exactly the two files above to the design in Context
- step: run `bash claude/skills/work-order/testing/run-tests.sh` and the AC checks; commit 'feat(work-order): ticket repo field resolves a bare pr in its own repo (2d5b TP-3)' with the ticket id; the PR body ends with 'Bump: work-order=minor'
- tool: cmd:git, cmd:jq, cmd:podman, cmd:gh - fallback: missing on the host: stop with ENV-MISSING naming it; gh or GitHub down: retry 3 times, then FB-003 (push with git, park the PR step with a note) and A2A-003 with the output
- tool: path:claude/skills/work-order/testing/run-tests.sh - on main; fallback: its image fails to build: stop with ENV-MISSING podman

**Out - non-goals**

- writing .repo into business tickets: a business design seat runs set --repo after merge
- approve tool resolution: the approve --code-dir ticket that depends on this one
- SKILL.md, references/lifecycle.md and testing/SOP.md: WO-20261016-2eb1 owns them and runs after this ticket; no doc edits here
- work-orders/INDEX.md and epic READMEs by hand or by git add: they are ignored generated views
- waiting on CI or merging: push, open the PR, write the result, leave (ORD-0542 O2)
- any file not named under In: stop with DESIGN-GAP and hand it back to infra-design (ORD-0548, item 30)

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [ ] `AC-H1` *(human)* case 360 and the whole skill suite pass
  - check: `bash claude/skills/work-order/testing/run-tests.sh` exit 0 expect /all cases passed/
- [ ] `AC-H2` *(human)* new and set take --repo
  - check: `grep -c -- '--repo) ' claude/skills/work-order/scripts/work-order.sh` exit 0 expect /^1$/
- [ ] `AC-H3` *(human)* the diff holds only In files and generated work-orders files
  - check: `bash -c '! git diff --name-only origin/main...HEAD | grep -vE "^(work-orders/.*|claude/skills/work-order/scripts/work-order[.]sh|claude/skills/work-order/testing/cases/360-ticket-repo[.]sh)$"'` exit 0

## Test plan

_Test plan from claude/workflow/templates/test-plan.md, shaped by claude/workflow/schemas/test-plan.schema.json. The tester runs exactly these cases and nothing else._

**Scope under test**

the ticket repo field: new --repo, set --repo, submit -R, stale-merged precedence URL > .repo > --pr-repo > project

**Cases**

- `TP-1`
  - intent: the new case proves the change; a red block means the verb ships broken to every seat that calls it
  - command: `bash claude/skills/work-order/testing/run-tests.sh 2>&1 | sed -n '/360-ticket-repo.sh/,/checks, [0-9]* failed/p'`
  - expected: exit 0; the block ends with `0 failed`
- `TP-2`
  - intent: the change must not break any other work-order verb
  - command: `bash claude/skills/work-order/testing/run-tests.sh | tail -1`
  - expected: exit 0; the last line starts with `all cases passed:`
- `TP-3`
  - intent: dev gate on real data: a business ticket with a bare pr and a repo set resolves in that repo, not the business repo (2d5b TP-3); read-only
  - command: `bash -c 'git -C ~/projects/business-80d3 fetch -q origin && d=$(mktemp -d) && git -C ~/projects/business-80d3 worktree add -q --detach $d origin/venture/yieldpoint-consulting && bash claude/skills/work-order/scripts/work-order.sh set --project $d --id WO-20261016-c770 --repo jkkelley/ypconsult-01-src >/dev/null && bash claude/skills/work-order/scripts/work-order.sh stale-merged --project $d --json | jq -r ".[] | select(.id==\"WO-20261016-c770\") | .repo"; git -C ~/projects/business-80d3 worktree remove --force $d'`
  - expected: exit 0; prints `jkkelley/ypconsult-01-src` (nothing when c770 was closed meanwhile)

**Isolation**

- runtime: podman
- image: `localhost/work-order-test:1`
- build: `bash claude/skills/work-order/testing/run-tests.sh`
- containerfile: `claude/skills/work-order/testing/Containerfile`

**Out of scope - CI covers**

- the full skill suite in skill-pr-gate

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

Cancelled `2026-10-16` - nothing shipped.

- reason: code merged in PR 295; checks re-run under WO-20261016-9c09
- superseded by: `WO-20261016-9c09`

No branch, no PR and no merge commit exist for this work order.

