---
{
  "id": "WO-20261016-2d5b",
  "slug": "work-order-sh-stale-merged-lists-ready-in-progre",
  "title": "work-order.sh stale-merged lists ready, in-progress and in-review tickets whose PR or branch is merged, read-only (ORD-0848 Y3)",
  "type": "feature",
  "status": "in-progress",
  "priority": "p0",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T09:08:08+00:00",
  "parent": "WO-20261016-fb0c",
  "branch": "feat/work-order-sh-stale-merged-lists-ready-in-progre",
  "pr": null,
  "closed": null,
  "approval": {
    "via": "override",
    "reason": "infra-design8 cut for ORD-0837 RR-orch-18, ORD-0848 Y3 and the ORD-0830 RR-orch-14 DESIGN-GAPs; design approvals ruled done, ORD-0550 O4",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [],
  "blocks": [
    "WO-20261016-b766",
    "WO-20261016-c6a5",
    "WO-20261016-d5e3",
    "WO-20261016-2eb1"
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
      "command": "grep -c 'stale-merged) cmd_stale_merged' claude/skills/work-order/scripts/work-order.sh",
      "exit": 0,
      "expect": "^1$"
    },
    {
      "index": 3,
      "command": "bash -c '! git diff --name-only origin/main...HEAD | grep -vE \"^(work-orders/|claude/skills/work-order/scripts/work-order[.]sh|claude/skills/work-order/testing/cases/320-stale-merged[.]sh)$\"'",
      "exit": 0,
      "expect": null
    }
  ],
  "provides": [
    "claude/skills/work-order/testing/cases/320-stale-merged.sh",
    "stale-merged"
  ]
}
---

# WO-20261016-2d5b - work-order.sh stale-merged lists ready, in-progress and in-review tickets whose PR or branch is merged, read-only (ORD-0848 Y3)

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

A ticket whose PR merged without close-out stays open and the line reads it as work: WO-20261016-c770 - S02c: sa_ lead tables migration, WO-20261016-eb12 - S02d: Twenty custom fields bootstrap and schema drift check and WO-20261016-f58e - S02e: outbox sync from state.db to Twenty, clearing any LinkedIn link are in-review in business while ypconsult-01-src PRs 52, 51 and 53 are MERGED (merge commits 0e8a5934, 5ee83b0c, 131a4bc4). No verb finds them.

## Owner words

> get this code merged the fuck in, dead code is shit, it sitting under agents is stupid (item 21)

> create generic tooling too fucker (item 30)

> so its re-usable, add to it, makefiles, dont' be a crackhead and one off shit all the time (item 30)

## Context

Order ORD-0848 Y3: tooling ticket: zwo stale-merged lists ready or in-progress tickets whose branch or PR is merged; the merge loop runs it each tick and posts READY-MERGED on the bus; a design seat closes them in one batch with zwo done and the merged PR runs as evidence. Close c770, eb12, f58e in the first batch. Fact: those three are in-review, so the verb covers ready, in-progress and in-review.

Verb, fixed by this design: work-order.sh stale-merged [--project DIR] [--pr-repo OWNER/NAME] [--json]. Scans every non-archived ticket whose status is ready, in-progress or in-review. With .pr set: gh pr view <pr> -R <repo> --json state,mergeCommit,mergedAt,url; stale when state is MERGED. With .pr null and .branch set: gh pr list -R <repo> --head <branch> --state merged --json number,mergeCommit,mergedAt,url --limit 1; stale when non-empty. <repo> is --pr-repo, else gh repo view --json nameWithOwner run in the project. Every gh call retries 3 times, then dies exit 4 gh_failed naming the call. Text output: one line per stale ticket 'READY-MERGED <id> <status> pr=<n> merge=<sha12> <title>'. --json: an array of {id,title,status,pr,repo,merge_commit,merged_at,url}, [] when none. Exit 0 with or without findings. Writes nothing: no file, no commit, no reindex.

Rejected: a separate script under claude/workflow, because item 30 says a need is met by a verb on the existing tool. Cost: one gh call per open ticket per run; the sweep calls it once a minute per configured repo.

## Scope

**In**

- touches: claude/skills/work-order/scripts/work-order.sh (cmd_stale_merged; the usage block line; the dispatch line 'stale-merged) cmd_stale_merged ;;'; a breadcrumb comment at cmd_stale_merged citing ORD-0848 Y3 and the three tickets)
- touches: claude/skills/work-order/testing/cases/320-stale-merged.sh (new: gh stubbed on PATH as in 070; fixtures: ready with pr MERGED -> listed; in-review with pr OPEN -> not listed; in-progress with branch and the list stub returning one merged PR -> listed; draft -> not listed; an archived done ticket -> not scanned; --json shape; git status --porcelain empty after the run)
- touches (generated, written only by work-order.sh start/submit/done, never by hand or git add): this ticket file and its archive path; work-orders/INDEX.md and the parent epic README.md are ignored generated views
- step: branch from origin/main in your own worktree; write exactly the two files above to the verb in Context
- step: run `bash claude/skills/work-order/testing/run-tests.sh` and the AC checks; commit 'feat(work-order): stale-merged lists open tickets whose PR merged (ORD-0848 Y3)' with the ticket id; the PR body ends with 'Bump: work-order=minor'
- tool: cmd:git, cmd:jq, cmd:make, cmd:podman, cmd:gh - fallback: missing on the host: stop with ENV-MISSING naming it; gh or GitHub down: retry 3 times, then stop with A2A-003 and its output
- tool: path:claude/skills/work-order/testing/run-tests.sh - on main; fallback: its image fails to build: stop with ENV-MISSING podman

**Out - non-goals**

- closing any ticket: the batch close is its own ticket
- the pr-flow sweep wiring: its own ticket
- SKILL.md and testing/SOP.md: WO-20261016-377c owns them now; the docs follow-up ticket covers them
- work-orders/INDEX.md and epic READMEs by hand or by git add: they are ignored generated views
- waiting on CI or merging: push, open the PR, write the result, leave (ORD-0542 O2)
- any file not named under In: stop with DESIGN-GAP and hand it back to infra-design (ORD-0548, item 30)

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [ ] `AC-H1` *(human)* case 320 and the whole skill suite pass
  - check: `bash claude/skills/work-order/testing/run-tests.sh` exit 0 expect /all cases passed/
- [ ] `AC-H2` *(human)* the verb is dispatched
  - check: `grep -c 'stale-merged) cmd_stale_merged' claude/skills/work-order/scripts/work-order.sh` exit 0 expect /^1$/
- [ ] `AC-H3` *(human)* the diff holds only In files and generated work-orders files
  - check: `bash -c '! git diff --name-only origin/main...HEAD | grep -vE "^(work-orders/|claude/skills/work-order/scripts/work-order[.]sh|claude/skills/work-order/testing/cases/320-stale-merged[.]sh)$"'` exit 0

## Test plan

_Test plan from claude/workflow/templates/test-plan.md, shaped by claude/workflow/schemas/test-plan.schema.json. The tester runs exactly these cases and nothing else._

**Scope under test**

work-order.sh stale-merged: lists ready, in-progress and in-review tickets whose recorded PR, or a PR from whose recorded branch, is MERGED; writes nothing

**Cases**

- `TP-1`
  - intent: a ticket whose PR merged but was never closed out sits ready forever and the line reads it as open work (c770, eb12, f58e: ypconsult-01-src PRs 52, 51, 53 merged, tickets still in-review)
  - command: `bash claude/skills/work-order/testing/run-tests.sh 2>&1 | sed -n '/320-stale-merged.sh/,/checks, [0-9]* failed/p'`
  - expected: exit 0; the block ends with `0 failed`
- `TP-2`
  - intent: the new verb must not break any other verb
  - command: `bash claude/skills/work-order/testing/run-tests.sh | tail -1`
  - expected: exit 0; the last line starts with `all cases passed:`
- `TP-3`
  - intent: the verb is read-only against the real tickets of a live repo (dev gate on real data, nothing written)
  - command: `bash -c 'git -C ~/projects/business-80d3 fetch -q origin && d=$(mktemp -d) && git -C ~/projects/business-80d3 worktree add -q --detach $d origin/venture/yieldpoint-consulting && bash claude/skills/work-order/scripts/work-order.sh stale-merged --project $d --pr-repo jkkelley/ypconsult-01-src --json | jq -r ".[].id" | sort | tr "\n" " "; git -C $d status --porcelain | wc -l; git -C ~/projects/business-80d3 worktree remove --force $d'`
  - expected: exit 0; prints `WO-20261016-c770 WO-20261016-eb12 WO-20261016-f58e ` then `0` (unless those three were closed meanwhile, then the ids are absent)

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

_Written by `work-order done`. Empty until then._
