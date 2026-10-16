---
{
  "id": "WO-20261016-73f2",
  "slug": "pr-flow-sweep-refreshes-a-green-pr-behind-its-ba",
  "title": "pr-flow sweep refreshes a green PR behind its base: update-branch once per base sha, post STALE-BASE, no backstop merge (RR-orch-15)",
  "type": "feature",
  "status": "ready",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T08:49:46+00:00",
  "parent": "WO-20261016-fb0c",
  "branch": null,
  "pr": null,
  "closed": null,
  "approval": {
    "via": "override",
    "reason": "infra-design7 cut for ORD-0830 RR-orch-15 and ORD-0832 B1; design approvals ruled done, ORD-0550 O4",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [
    "WO-20261016-448e",
    "WO-20261016-fb99"
  ],
  "blocks": [
    "WO-20261016-7f26",
    "WO-20261016-2299",
    "WO-20261016-9a0f"
  ],
  "ac_checks": [
    {
      "index": 1,
      "command": "make -C claude/workflow pr-flow-test CASES=\"stale-base consume rerun-stale-red records\"",
      "exit": 0,
      "expect": "ok  stale-base"
    },
    {
      "index": 2,
      "command": "make -C claude/workflow pr-flow-lint",
      "exit": 0,
      "expect": null
    },
    {
      "index": 3,
      "command": "jq -r .defaults.stale_base.mode claude/workflow/pr-flow/config/pr-flow.json",
      "exit": 0,
      "expect": "^update-branch$"
    },
    {
      "index": 4,
      "command": "make rolodex-check BASE=origin/main",
      "exit": 0,
      "expect": null
    },
    {
      "index": 5,
      "command": "bash -c \\!\\ git\\ diff\\ --name-only\\ origin/main...HEAD\\ \\|\\ grep\\ -vE\\ \\'\\^\\(work-orders/\\|claude/workflow/pr-flow/\\(bin/pr-flow-consume\\\\.sh\\|pr-flow\\\\.mk\\|config/pr-flow\\\\.json\\|schemas/pr-flow-record\\\\.schema\\\\.json\\|tests/\\(stale-base\\|records\\)\\\\.test\\\\.sh\\)\\)\\$\\'",
      "exit": 0,
      "expect": null
    }
  ],
  "provides": [
    "path:claude/workflow/pr-flow/tests/stale-base.test.sh"
  ],
  "labels": [
    "line:inbox-triage"
  ]
}
---

# WO-20261016-73f2 - pr-flow sweep refreshes a green PR behind its base: update-branch once per base sha, post STALE-BASE, no backstop merge (RR-orch-15)

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

A green PR held by merge-on-green for a stale base needs a push the owner's token makes to start a fresh run, and the sweep's backstop would otherwise merge it through merge.sh, bypassing the hold.

## Owner words

> RR-orch-15: no branch protection gate. The merge-on-green Action refuses a PR whose last green run tested a base older than main head and runs gh pr update-branch instead, which starts a fresh run; code STALE-BASE on the bus.

## Context

Inventory (PR 242, restored by the restore ticket): pr-flow-consume.sh repo_pass lists open PRs with baseRefName, caches the base head in MAIN_OF[slug/base] as 'sha date', and stale_red_pr already runs gh pr update-branch with the REST PUT fallback once per base sha (key RERUN/slug/n/sha). The green branch of repo_pass (gate.sh ci-green) posts ci.passed 201 and runs the backstop merge.sh --pr when the green marker is older than backstop_s.

Why the sweep and not the Action: a GITHUB_TOKEN push starts no pull_request run; the sweep runs with the owner's gh token, so its update-branch starts the fresh run, and it reaches the local bus, so STALE-BASE lands there (records.sh post).

pr-flow.json defaults.stale_base, exactly: {"mode": "update-branch"}; mode off disables the verb with no code change.

## Scope

**In**

- touches: claude/workflow/pr-flow/bin/pr-flow-consume.sh
- touches: claude/workflow/pr-flow/config/pr-flow.json
- touches: claude/workflow/pr-flow/schemas/pr-flow-record.schema.json
- touches: claude/workflow/pr-flow/pr-flow.mk
- touches: claude/workflow/pr-flow/tests/stale-base.test.sh (new)
- touches: claude/workflow/pr-flow/tests/records.test.sh
- touches (generated, written only by work-order.sh start/submit/done, never by hand): work-orders/INDEX.md, this ticket file and its archive path, the parent epic README.md
- step: start only after the restore ticket and WO-20261016-fb99 are done and merged (both touch these files); branch from origin/main
- step: schema: append "ci.stale-base" to properties.kind.enum and "STALE-BASE" to properties.code.enum; nothing else
- step: pr-flow.json: add defaults.stale_base exactly as in Context; extend defaults.$comment by one clause: stale_base.mode update-branch or off; a green PR whose head is behind its base head gets one update-branch per base sha and no backstop merge
- step: pr-flow-consume.sh: new function stale_base_pr SLUG LINE N HEAD BASE TICKET MODE, header line beside stale_red_pr. Return 1 (not stale) when MODE is empty, null or off. Fill MAIN_OF[SLUG/BASE] exactly as stale_red_pr does; empty sha: return 1. behind=$("$GH" api "repos/SLUG/compare/BASE...HEAD" --jq .behind_by), retried 3 times; still failing: print 'SLUG PR N stale-base-unknown' and return 0 (hold, never merge blind). behind 0: return 1. key STALE-BASE/SLUG/N/<base sha>: seen by records.sh: return 0. DRY set: print 'SLUG PR N would-stale-base' and return 0. Else gh pr update-branch N -R SLUG, falling back to gh api -X PUT repos/SLUG/pulls/N/update-branch -f expected_head_sha=HEAD; success: post kind ci.stale-base code STALE-BASE that key with note 'head <behind> behind BASE <sha 12>; update-branch' and print 'SLUG PR N stale-base: update-branch'; both refused: print 'SLUG PR N stale-base-fail: update-branch' and post nothing. Return 0
- step: pr-flow-consume.sh repo_pass: first line inside the gate.sh ci-green success branch: if stale_base_pr with the PR fields and "$(jq -r '.stale_base.mode // "off"' <<<"$cfg")" returns 0, rm -f the green marker STATE/green-<slug with / as _>-N and continue; ci.passed and the backstop run only for a PR that is not stale
- step: pr-flow.mk: add stale-base to the default CASES list of pr-flow-test; nothing else
- step: tests/stale-base.test.sh (new; rolodex header; the rerun-stale-red.test.sh pattern: fake gh with a call log, stub PR_FLOW_PUB, temp PR_FLOW_STATE): cases exactly TP-1 to TP-4 of the test plan; the last line in the pass=N fail=M shape the pr-flow-test target greps
- step: tests/records.test.sh: two cases: post --kind ci.stale-base --code STALE-BASE exits 0; post --kind ci.stale-base --code NOPE exits 3
- step: run TP-1 to TP-6 and the AC checks only; CI runs the rest
- tool: path:claude/workflow/pr-flow/bin/records.sh seen and post - on main; fallback: bus down: the records.sh dir backend (item 28 file queue), no code change
- tool: stale_red_pr, MAIN_OF and baseRefName in pr-flow-consume.sh - land with the restore ticket; fallback: missing on main: stop with DESIGN-GAP naming it
- tool: make:claude/workflow/Makefile:pr-flow-test and pr-flow-lint - on main; fallback: missing: stop with DESIGN-GAP naming it
- tool: cmd:git, cmd:jq, cmd:make, cmd:podman, cmd:gh - fallback: missing on the host: stop with ENV-MISSING naming it; gh or GitHub down: retry 3 times, then stop with A2A-003 and its output
- tool: make:Makefile:rolodex-check - on main; fallback: missing: stop with DESIGN-GAP naming it

**Out - non-goals**

- the merge-on-green template and the pr-process docs: the Action ticket owns them
- merge.sh and gate.sh: unchanged; the sweep simply never calls the backstop for a stale PR
- fork PRs: update-branch on a fork is refused and prints the fail line; nothing else
- work-orders/INDEX.md and epic READMEs by hand or by git add: they are ignored generated views
- waiting on CI or merging: push, open the PR, write the result, leave (ORD-0542 O2)
- any file not named under In: stop with DESIGN-GAP and hand it back to infra-design (ORD-0548, item 30)

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [ ] `AC-H1` *(human)* stale-base and every sweep case beside it pass
  - check: `make -C claude/workflow pr-flow-test CASES="stale-base consume rerun-stale-red records"` exit 0 expect /ok stale-base/
- [ ] `AC-H2` *(human)* pr-flow scripts stay shellcheck clean
  - check: `make -C claude/workflow pr-flow-lint` exit 0
- [ ] `AC-H3` *(human)* stale_base is on by default in config
  - check: `jq -r .defaults.stale_base.mode claude/workflow/pr-flow/config/pr-flow.json` exit 0 expect /^update-branch$/
- [ ] `AC-H4` *(human)* every new script has a rolodex header
  - check: `make rolodex-check BASE=origin/main` exit 0
- [ ] `AC-H5` *(human)* the diff holds only In files and generated work-orders files
  - check: `bash -c \!\ git\ diff\ --name-only\ origin/main...HEAD\ \|\ grep\ -vE\ \'\^\(work-orders/\|claude/workflow/pr-flow/\(bin/pr-flow-consume\\.sh\|pr-flow\\.mk\|config/pr-flow\\.json\|schemas/pr-flow-record\\.schema\\.json\|tests/\(stale-base\|records\)\\.test\\.sh\)\)\$\'` exit 0

## Test plan

_Test plan from claude/workflow/templates/test-plan.md, shaped by claude/workflow/schemas/test-plan.schema.json. The tester runs exactly these cases and nothing else._

**Scope under test**

pr-flow-consume.sh stale_base_pr: a green PR behind its base head gets one update-branch per base sha from the sweep, posts STALE-BASE, and never reaches the backstop merge

**Cases**

- `TP-1`
  - intent: a fresh run only starts from a push the owner's token makes; GITHUB_TOKEN pushes start no pull_request run (recursion guard, the breadcrumb in templates/merge-on-green.yml), so the sweep, not the Action, refreshes a held PR (RR-orch-15)
  - command: `make -C claude/workflow pr-flow-test CASES="stale-base"`
  - expected: exit 0; prints `ok  stale-base`; a green fixture PR with compare behind_by 3 gets exactly one `gh pr update-branch 1 -R o/r` call, prints `o/r PR 1 stale-base: update-branch`, and pub.log holds one `ci.stale-base` line with code STALE-BASE and key STALE-BASE/o/r/1/<base sha>
- `TP-2`
  - intent: once per base sha, or every tick pushes a merge commit (item 1)
  - command: `make -C claude/workflow pr-flow-test CASES="stale-base"`
  - expected: exit 0; a second tick on the same base sha makes no update-branch call and posts nothing; a new base sha makes one more
- `TP-3`
  - intent: a stale PR never merges through the backstop, and an up-to-date green PR is untouched
  - command: `make -C claude/workflow pr-flow-test CASES="stale-base"`
  - expected: exit 0; behind_by 3 with the green marker older than backstop_s calls no merge.sh; behind_by 0 makes no update-branch call and still posts ci.passed 201
- `TP-4`
  - intent: the fallbacks are coded (item 28): update-branch refused falls back to the REST PUT; both refused prints the fail line and posts nothing; a compare outage holds the PR; stale_base.mode off disables the verb with no code change
  - command: `make -C claude/workflow pr-flow-test CASES="stale-base"`
  - expected: exit 0; refused CLI calls `api -X PUT repos/o/r/pulls/1/update-branch` once; both refused prints `o/r PR 1 stale-base-fail: update-branch`; compare failing prints `o/r PR 1 stale-base-unknown` and calls no merge.sh; mode off makes no compare call
- `TP-5`
  - intent: the sweep, stale-red and record cases still hold
  - command: `make -C claude/workflow pr-flow-test CASES="consume rerun-stale-red records"`
  - expected: exit 0
- `TP-6`
  - intent: scripts stay shellcheck clean
  - command: `make -C claude/workflow pr-flow-lint`
  - expected: exit 0

**Isolation**

- runtime: podman
- image: `docker.io/library/debian:bookworm-slim@sha256:3783cc01769c7b2b1b83a5c5ad96c815348e28ed7da68e2e3687004faa906251` (debian:bookworm-slim, base of localhost/dotfiles-workflow-test:1)

**Out of scope - CI covers**

- the live sweep against a real PR: the RR-orch-15 test ticket's UAT case
- the full claude/workflow suite: CI runs it

## Assumptions

1. whole-verb fallback: stale_base.mode off in pr-flow.json disables it with no code change; merge-on-green still holds, and a held PR then waits for its next push

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
