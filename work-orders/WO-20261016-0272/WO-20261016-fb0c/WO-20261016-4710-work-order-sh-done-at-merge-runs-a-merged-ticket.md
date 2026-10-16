---
{
  "id": "WO-20261016-4710",
  "slug": "work-order-sh-done-at-merge-runs-a-merged-ticket",
  "title": "work-order.sh done --at merge runs a merged ticket's checks at its PR merge commit",
  "type": "feature",
  "status": "ready",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T09:19:26+00:00",
  "parent": "WO-20261016-fb0c",
  "branch": null,
  "pr": null,
  "closed": null,
  "approval": {
    "via": "override",
    "reason": "infra-design9 cut for ORD-0830 RR-orch-14; design approvals ruled done, ORD-0550 O4",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [
    "WO-20261016-25f7"
  ],
  "blocks": [
    "WO-20261016-4575",
    "WO-20261016-da33",
    "WO-20261016-3a66"
  ],
  "ac_checks": [
    {
      "index": 1,
      "command": "bash claude/skills/work-order/testing/run-tests.sh",
      "exit": 0,
      "expect": "340-done-at-merge"
    },
    {
      "index": 2,
      "command": "bash claude/skills/work-order/scripts/work-order.sh --help",
      "exit": 0,
      "expect": "done .*--at merge"
    },
    {
      "index": 3,
      "command": "make rolodex-check BASE=origin/main",
      "exit": 0,
      "expect": null
    },
    {
      "index": 4,
      "command": "git diff --name-only origin/main...HEAD | grep -vE '^(work-orders/.*|claude/skills/work-order/(scripts/work-order\\.sh|testing/SOP\\.md|testing/cases/340-done-at-merge\\.sh))$'",
      "exit": 1,
      "expect": null
    }
  ],
  "provides": []
}
---

# WO-20261016-4710 - work-order.sh done --at merge runs a merged ticket's checks at its PR merge commit

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

A ticket whose PR merged before done ran cannot close: done runs every ac_check against HEAD of the close-out branch, and a point-in-time check (git diff --quiet against a fixed commit, a suite whose files a later PR moved) passes only at the merge commit. WO-20261016-448e failed AC-H1 on main after PR 270 (c48a266) moved the pr-flow files, and closed only by break glass; WO-20261016-75b7 (PR 220 merged) is in the same state.

## Owner words

> never hand automation (Design principles 101 item 37)

> Every break glass act ... is followed at once by a work order that turns it into automation, since a hand fix is a defect (item 33)

## Context

Break glass this replaces, logged at ~/.local/state/zenith/breakglass/2026/10/*-448e-done-at-merge.md: git worktree add --detach <wt> 7325896, work-order.sh done --id WO-20261016-448e there (AC-PASS 1 to 5), archived file copied onto chore/infra-design9-scope-regex.

Behaviour, fixed: done accepts --at merge (the only accepted value; anything else dies PS_USAGE bad_at). With it: wo_require_gh; read .pr from the frontmatter (empty: die PS_VALIDATION no_pr); gh pr view <pr> --json state,mergeCommit; state not MERGED: die PS_VALIDATION pr_not_merged; git worktree add --detach "$(ps_tempdir)/at" <mergeCommit.oid>, removed by a trap with git worktree remove --force on every exit; run_checks is called as (project=<that worktree>; run_checks "$file" "" notick) so only the cd moves and the frontmatter is read from the current tree; the rest of done (unchecked-criteria gate, stamp, archive, reindex) is unchanged. Without --at, done is byte-for-byte as today.

## Scope

**In**

- touches: claude/skills/work-order/scripts/work-order.sh (cmd_done: the --at branch around the run_checks call; the option parser: --at sets a local at; the usage line for done becomes done [--project DIR] --id WO-... [--at merge] [--json]; the done help paragraph gets one line; a breadcrumb comment at the change naming WO-20261016-448e, WO-20261016-75b7 and the break-glass log)
- touches: claude/skills/work-order/testing/cases/340-done-at-merge.sh (new, modelled on 090-done-archives-on-branch.sh with gh stubbed on PATH as in 070: fixture repo with commit A where the check git diff --quiet A HEAD -- f passes and a later commit B that changes f; ticket in-review with pr 7; gh stub prints {"state":"MERGED","mergeCommit":{"oid":"<A>"}}: done --at merge exits 0 and archives; plain done exits 3 ac_check_failed; stub OPEN: done --at merge exits 3 pr_not_merged; --at head exits 2 bad_at; after every run git worktree list prints one line)
- touches: claude/skills/work-order/testing/SOP.md (one entry for 340-done-at-merge.sh)
- touches (generated, written only by work-order.sh start/submit/done, never by hand or git add): this ticket file and its archive path; work-orders/INDEX.md and the parent epic README.md are ignored generated views
- step: branch from origin/main in your own worktree after WO-20261016-25f7 merged; make exactly the three edits above
- step: run TP-1 to TP-3 of the test plan and the AC checks only; CI runs the rest
- step: commit 'feat(work-order): done --at merge runs checks at the PR merge commit (ORD-0830 RR-orch-14)' with the ticket id; the PR body ends with 'Bump: work-order=minor'
- tool: script:claude/skills/work-order/testing/run-tests.sh and make:Makefile:rolodex-check - on main; fallback: missing: stop with DESIGN-GAP naming it
- tool: cmd:git, cmd:jq, cmd:make, cmd:podman, cmd:gh - fallback: missing on the host: stop with ENV-MISSING naming it; gh or GitHub down: retry 3 times, then stop with A2A-003 and its output

**Out - non-goals**

- any value of --at other than merge
- closing WO-20261016-75b7: that is its own ticket
- work-orders/INDEX.md and epic READMEs by hand or by git add
- waiting on CI or merging: push, open the PR, write the result, leave
- any file not named under In: stop with DESIGN-GAP

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [ ] `AC-H1` *(human)* the work-order suite passes with the new case
  - check: `bash claude/skills/work-order/testing/run-tests.sh` exit 0 expect /340-done-at-merge/
- [ ] `AC-H2` *(human)* the usage names the flag
  - check: `bash claude/skills/work-order/scripts/work-order.sh --help` exit 0 expect /done .*--at merge/
- [ ] `AC-H3` *(human)* every changed script has a rolodex header
  - check: `make rolodex-check BASE=origin/main` exit 0
- [ ] `AC-H4` *(human)* the diff holds only In files and generated work-orders files
  - check: `git diff --name-only origin/main...HEAD | grep -vE '^(work-orders/.*|claude/skills/work-order/(scripts/work-order\.sh|testing/SOP\.md|testing/cases/340-done-at-merge\.sh))$'` exit 1

## Test plan

{"scope":"work-order.sh done --at merge runs a merged ticket's checks in a detached worktree at its PR merge commit","cases":[
{"id":"TP-1","intent":"a point-in-time check (git diff against a fixed commit, a suite whose files a later PR moved) passes at the merge commit and fails on main forever, so done refused WO-20261016-448e and WO-20261016-75b7 and the close-out was done by break glass; --at merge makes that close-out a script","command":"bash claude/skills/work-order/testing/run-tests.sh","expected":"exit 0; the 340-done-at-merge.sh block prints only ok lines"},
{"id":"TP-2","intent":"the flag is in the usage block so a seat finds it","command":"bash claude/skills/work-order/scripts/work-order.sh --help","expected":"exit 0; prints a line containing done and --at merge"},
{"id":"TP-3","intent":"the changed scripts keep their rolodex headers","command":"make rolodex-check BASE=origin/main","expected":"exit 0"}],
"isolation":{"runtime":"podman","image":"docker.io/library/debian@sha256:328d16499860ae6cb9b345e2e4cebca08c2a36e4f7278482c7bd1f39d71e5bfd"},
"out_of_scope":["the full work-order suite on CI and the skill gates: CI runs them"]}

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
