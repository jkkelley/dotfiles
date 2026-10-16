---
{
  "id": "WO-20261016-c6a5",
  "slug": "pr-flow-sweep-runs-work-order-sh-stale-merged-ea",
  "title": "pr-flow sweep runs work-order.sh stale-merged each tick and posts READY-MERGED once per ticket and PR, make pr-stale-merged (ORD-0848 Y3)",
  "type": "feature",
  "status": "ready",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T09:08:32+00:00",
  "parent": "WO-20261016-fb0c",
  "branch": null,
  "pr": null,
  "closed": null,
  "approval": {
    "via": "override",
    "reason": "infra-design8 cut for ORD-0837 RR-orch-18, ORD-0848 Y3 and the ORD-0830 RR-orch-14 DESIGN-GAPs; design approvals ruled done, ORD-0550 O4",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [
    "WO-20261016-2d5b"
  ],
  "blocks": [
    "WO-20261016-1933",
    "WO-20261016-9a0f"
  ],
  "ac_checks": [
    {
      "index": 1,
      "command": "make -C claude/workflow pr-flow-test CASES=\"stale-merged records\"",
      "exit": 0,
      "expect": "ok  stale-merged"
    },
    {
      "index": 2,
      "command": "make -C claude/workflow pr-flow-lint",
      "exit": 0,
      "expect": null
    },
    {
      "index": 3,
      "command": "jq -e '(.properties.kind.enum | index(\"ready.merged\")) and (.properties.code.enum | index(\"READY-MERGED\"))' claude/workflow/pr-flow/schemas/pr-flow-record.schema.json",
      "exit": 0,
      "expect": null
    },
    {
      "index": 4,
      "command": "bash -c '! git diff --name-only origin/main...HEAD | grep -vE \"^(work-orders/|claude/workflow/pr-flow/bin/pr-flow-consume[.]sh|claude/workflow/pr-flow/config/pr-flow[.]json|claude/workflow/pr-flow/pr-flow[.]mk|claude/workflow/pr-flow/schemas/pr-flow-record[.]schema[.]json|claude/workflow/pr-flow/tests/(records|stale-merged)[.]test[.]sh|claude/workflow/docs/pr-process/pr-process[.](md|spec[.]xml))$\"'",
      "exit": 0,
      "expect": null
    }
  ],
  "provides": [
    "claude/workflow/pr-flow/tests/stale-merged.test.sh",
    "pr-stale-merged"
  ],
  "labels": [
    "line:inbox-triage"
  ]
}
---

# WO-20261016-c6a5 - pr-flow sweep runs work-order.sh stale-merged each tick and posts READY-MERGED once per ticket and PR, make pr-stale-merged (ORD-0848 Y3)

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

With the stale-merged verb on main, nothing runs it: a ticket whose PR merged stays open until a seat happens to look. The merge loop (pr-flow-consume.sh sweep, once a minute) must run it per configured repo and post READY-MERGED on the bus for the design seat to consume (item 26: producer and consumer).

## Owner words

> get this code merged the fuck in, dead code is shit, it sitting under agents is stupid (item 21)

> i don't like agents doing shit when i have a k8s cluster too, automate processes right away (item 39)

## Context

Order ORD-0848 Y3, as on WO-20261016-2d5b. Depends on WO-20261016-448e - Restore PR 242 rerun-stale-red on main: commit 4817abc of PR 240 reverted all nine of its files, WO-20261016-fb99 - pr-flow sweep verb autofix: red PRs with a tracked-ignored path or a stale contents list get the mechanical fix pushed, post AUTOFIX, make pr-autofix, WO-20261016-73f2 - pr-flow sweep refreshes a green PR behind its base: update-branch once per base sha, post STALE-BASE, no backstop merge (RR-orch-15) and WO-20261016-39da - merge-on-green holds a green PR whose head is behind its base branch head, code STALE-BASE (RR-orch-15), which hold pr-flow-consume.sh, pr-flow.json, pr-flow.mk, the record schema, records.test.sh and the pr-process docs (item 19).

Design, fixed: pr-flow.json per repo gains optional "stale_merged": {"pr_repos": ["OWNER/NAME", ...]}; absent means [that repo]. Set jkkelley/business to ["jkkelley/business", "jkkelley/ypconsult-01-src"]. pr-flow-consume.sh gains verb stale-merged and calls it from sweep after the existing verbs: for each repo with a clone, for each pr_repo, run 'bash <dotfiles>/claude/skills/work-order/scripts/work-order.sh stale-merged --project <clone> --pr-repo <pr_repo> --json' and post one record per entry through the existing post(): kind ready.merged, code READY-MERGED, key READY-MERGED/<slug>/<ticket id>/<pr>, pr, sha=merge_commit, ticket=id, note '<status> <title>'. A verb failure prints one line and the sweep goes on (one repo never stops the others). make pr-stale-merged REPO=owner/name runs the verb for one repo. Record schema: kind enum + ready.merged, code enum + READY-MERGED. pr-process.md section 9 and pr-process.spec.xml records gain the row.

## Scope

**In**

- step: precondition, before branching: `bash -c 'git fetch -q origin && git ls-tree -r --name-only origin/main work-orders/archive | grep -q WO-20261016-448e-'` exits 0 (that ticket is done on main); else stop with BLOCKED naming it
- step: precondition, before branching: `bash -c 'git fetch -q origin && git ls-tree -r --name-only origin/main work-orders/archive | grep -q WO-20261016-fb99-'` exits 0 (that ticket is done on main); else stop with BLOCKED naming it
- step: precondition, before branching: `bash -c 'git fetch -q origin && git ls-tree -r --name-only origin/main work-orders/archive | grep -q WO-20261016-73f2-'` exits 0 (that ticket is done on main); else stop with BLOCKED naming it
- step: precondition, before branching: `bash -c 'git fetch -q origin && git ls-tree -r --name-only origin/main work-orders/archive | grep -q WO-20261016-39da-'` exits 0 (that ticket is done on main); else stop with BLOCKED naming it
- touches: claude/workflow/pr-flow/bin/pr-flow-consume.sh (verb stale-merged, its call in sweep, the header Records list line, a breadcrumb comment)
- touches: claude/workflow/pr-flow/config/pr-flow.json (stale_merged on jkkelley/business)
- touches: claude/workflow/pr-flow/pr-flow.mk (pr-stale-merged target)
- touches: claude/workflow/pr-flow/schemas/pr-flow-record.schema.json (kind ready.merged, code READY-MERGED)
- touches: claude/workflow/pr-flow/tests/stale-merged.test.sh (new: work-order.sh stubbed by PR_FLOW_WO; one entry posts once, a second sweep posts nothing, an empty list posts nothing, a failing verb does not stop the sweep)
- touches: claude/workflow/pr-flow/tests/records.test.sh (the new kind and code validate)
- touches: claude/workflow/docs/pr-process/pr-process.md and claude/workflow/docs/pr-process/pr-process.spec.xml (the READY-MERGED row)
- touches (generated, written only by work-order.sh start/submit/done, never by hand or git add): this ticket file and its archive path; work-orders/INDEX.md and the parent epic README.md are ignored generated views
- step: branch from origin/main in your own worktree after every dependency merged; edit exactly the files above to the design in Context
- step: run `make -C claude/workflow pr-flow-test CASES="stale-merged records"`, `make -C claude/workflow pr-flow-lint` and `make spec-check`, then the AC checks; commit 'feat(pr-flow): sweep posts READY-MERGED for open tickets whose PR merged (ORD-0848 Y3)'; no Bump trailer
- tool: cmd:git, cmd:jq, cmd:make, cmd:podman, cmd:gh - fallback: missing on the host: stop with ENV-MISSING naming it; gh or GitHub down: retry 3 times, then stop with A2A-003 and its output
- tool: make:claude/workflow/Makefile:pr-flow-test and pr-flow-lint - on main; fallback: missing: stop with DESIGN-GAP naming it
- tool: bus via records.sh post - fallback: bus down: records.sh retries 3 times and dies 4; the sweep logs the line and goes on (file ledger keeps post-once)

**Out - non-goals**

- closing tickets: the design seat does that from the records
- work-orders/INDEX.md and epic READMEs by hand or by git add: they are ignored generated views
- waiting on CI or merging: push, open the PR, write the result, leave (ORD-0542 O2)
- any file not named under In: stop with DESIGN-GAP and hand it back to infra-design (ORD-0548, item 30)

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [ ] `AC-H1` *(human)* the sweep posts READY-MERGED once
  - check: `make -C claude/workflow pr-flow-test CASES="stale-merged records"` exit 0 expect /ok stale-merged/
- [ ] `AC-H2` *(human)* pr-flow scripts stay shellcheck clean
  - check: `make -C claude/workflow pr-flow-lint` exit 0
- [ ] `AC-H3` *(human)* the record schema carries the kind and code
  - check: `jq -e '(.properties.kind.enum | index("ready.merged")) and (.properties.code.enum | index("READY-MERGED"))' claude/workflow/pr-flow/schemas/pr-flow-record.schema.json` exit 0
- [ ] `AC-H4` *(human)* the diff holds only In files and generated work-orders files
  - check: `bash -c '! git diff --name-only origin/main...HEAD | grep -vE "^(work-orders/|claude/workflow/pr-flow/bin/pr-flow-consume[.]sh|claude/workflow/pr-flow/config/pr-flow[.]json|claude/workflow/pr-flow/pr-flow[.]mk|claude/workflow/pr-flow/schemas/pr-flow-record[.]schema[.]json|claude/workflow/pr-flow/tests/(records|stale-merged)[.]test[.]sh|claude/workflow/docs/pr-process/pr-process[.](md|spec[.]xml))$"'` exit 0

## Test plan

_Test plan from claude/workflow/templates/test-plan.md, shaped by claude/workflow/schemas/test-plan.schema.json. The tester runs exactly these cases and nothing else._

**Scope under test**

pr-flow-consume.sh verb stale-merged, run by the sweep each tick: per configured repo, work-order.sh stale-merged against each stale_merged.pr_repos entry, one READY-MERGED record per ticket and PR, posted once

**Cases**

- `TP-1`
  - intent: the sweep must post READY-MERGED exactly once per ticket and merged PR, or the design seat never sees the stale tickets, or sees them every minute
  - command: `make -C claude/workflow pr-flow-test CASES="stale-merged records"`
  - expected: exit 0; prints `ok  stale-merged` and `ok  records`
- `TP-2`
  - intent: scripts stay shellcheck clean
  - command: `make -C claude/workflow pr-flow-lint`
  - expected: exit 0
- `TP-3`
  - intent: the record kind and code are in the record schema, or records.sh refuses the post
  - command: `jq -e '(.properties.kind.enum | index("ready.merged")) and (.properties.code.enum | index("READY-MERGED"))' claude/workflow/pr-flow/schemas/pr-flow-record.schema.json`
  - expected: exit 0; prints true

**Isolation**

- runtime: podman
- image: `localhost/dotfiles-workflow-test:1`
- build: `make -C claude/workflow image`
- containerfile: `claude/workflow/tests/container/Containerfile`

**Out of scope - CI covers**

- the full pr-flow and claude/workflow suites: CI runs them

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
