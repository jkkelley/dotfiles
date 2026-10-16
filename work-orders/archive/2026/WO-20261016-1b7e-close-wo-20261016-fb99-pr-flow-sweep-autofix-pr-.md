---
{
  "id": "WO-20261016-1b7e",
  "slug": "close-wo-20261016-fb99-pr-flow-sweep-autofix-pr-",
  "title": "Close WO-20261016-fb99 (pr-flow sweep autofix, PR 270 merged): re-run its checks under this ticket, move its edges here and cancel fb99 as superseded",
  "type": "chore",
  "status": "cancelled",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T10:39:01+00:00",
  "parent": "WO-20261016-ebe4",
  "branch": "feat/close-wo-20261016-fb99-pr-flow-sweep-autofix-pr-",
  "pr": null,
  "closed": "2026-10-16",
  "approval": {
    "via": "override",
    "reason": "infra-design15 cut for ORD-0830 RR-orch-14 F35; design approvals ruled done, ORD-0550 O4",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [],
  "blocks": [],
  "ac_checks": [
    {
      "index": 1,
      "command": "make -C claude/workflow pr-flow-test CASES=\"autofix consume regen-index rerun-stale-red records\"",
      "exit": 0,
      "expect": "ok  autofix"
    },
    {
      "index": 2,
      "command": "make -C claude/workflow pr-flow-lint",
      "exit": 0,
      "expect": null
    },
    {
      "index": 3,
      "command": "make -C claude/workflow pr-autofix",
      "exit": 2,
      "expect": "pr-autofix needs REPO="
    },
    {
      "index": 4,
      "command": "jq -r .defaults.autofix.mode claude/workflow/pr-flow/config/pr-flow.json",
      "exit": 0,
      "expect": "^on$"
    },
    {
      "index": 5,
      "command": "bash -c python3\\ -c\\ \\'import\\ xml.dom.minidom\\,sys\\;\\ xml.dom.minidom.parse\\(sys.argv\\[1\\]\\)\\'\\ claude/workflow/docs/pr-process/pr-process.spec.xml\\ \\&\\&\\ grep\\ -c\\ \\'value=\\\"AUTOFIX\\\"\\'\\ claude/workflow/docs/pr-process/pr-process.spec.xml",
      "exit": 0,
      "expect": "^1$"
    },
    {
      "index": 6,
      "command": "make rolodex-check BASE=origin/main",
      "exit": 0,
      "expect": null
    },
    {
      "index": 7,
      "command": "bash -c \\!\\ git\\ diff\\ --name-only\\ origin/main...HEAD\\ \\|\\ grep\\ -vE\\ \\'\\^\\(work-orders/\\|claude/workflow/\\(pr-flow/\\(bin/pr-flow-consume\\\\.sh\\|pr-flow\\\\.mk\\|config/pr-flow\\\\.json\\|schemas/pr-flow-record\\\\.schema\\\\.json\\|tests/\\(autofix\\|records\\)\\\\.test\\\\.sh\\)\\|docs/pr-process/pr-process\\\\.\\(md\\|spec\\\\.xml\\)\\)\\)\\$\\'",
      "exit": 0,
      "expect": null
    },
    {
      "index": 8,
      "command": "bash claude/skills/work-order/scripts/work-order.sh show --id WO-20261016-fb99 --json | jq -r '.status + \" \" + (.superseded_by // \"-\")'",
      "exit": 0,
      "expect": "^cancelled WO-"
    },
    {
      "index": 9,
      "command": "git diff --name-only origin/main...HEAD | grep -vE '^(work-orders/.*)$'",
      "exit": 1,
      "expect": null
    }
  ],
  "provides": [],
  "labels": [
    "line:inbox-triage"
  ],
  "superseded_by": "WO-20261016-aa46"
}
---

# WO-20261016-1b7e - Close WO-20261016-fb99 (pr-flow sweep autofix, PR 270 merged): re-run its checks under this ticket, move its edges here and cancel fb99 as superseded

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

WO-20261016-fb99 shipped in PR 270 (merged) but its ticket is still ready on main and cannot close: start refuses branch_exists: feat/pr-flow-sweep-verb-autofix-red-prs-with-a-tracke is held by /home/luna/.cache/wt-pr-autofix with unpushed duplicate commits

## Owner words

> close-outs fb99 3327 168d (F45-F47) (orchestrator brief BR-20261016-infra-design15)

> get this code merged the fuck in, dead code is shit, it sitting under agents is stupid (Design principles 101 item 21)

## Context

Order brief BR-20261016-infra-design15, ORD-0830 RR-orch-14; F35. Pattern: WO-20261016-bcb4 (A2A-ST close). The original ticket's checks are copied here verbatim as this ticket's checks, so done re-proves the merged code on main. THIS-TICKET-ID is this ticket's own id, the .id in its frontmatter. Steps on the branch, after start: for id in $(bash claude/skills/work-order/scripts/work-order.sh show --id WO-20261016-fb99 --json | jq -r '.blocks[]'): bash claude/skills/work-order/scripts/work-order.sh link --id $id --depends-on THIS-TICKET-ID --no-depends-on WO-20261016-fb99; then bash claude/skills/work-order/scripts/work-order.sh cancel --id WO-20261016-fb99 --reason 'code merged in PR 270; close-out blocked (start refuses branch_exists: feat/pr-flow-sweep-verb-autofix-red-prs-with-a-tracke is held by /home/luna/.cache/wt-pr-autofix with unpushed duplicate commits); checks re-run under THIS-TICKET-ID' --superseded-by THIS-TICKET-ID; then bash claude/skills/work-order/scripts/work-order.sh check --id THIS-TICKET-ID (check ticks every passing criterion; never tick by hand with evidence); commit those generated moves.

## Scope

**In**

- touches (generated, by work-order.sh link and cancel only): the WO-20261016-fb99 ticket file and its archive path, the ticket files of every id in its blocks list
- touches (generated, written only by work-order.sh start/submit/done, never by hand or git add): this ticket file and its archive path; work-orders/INDEX.md and the parent epic README.md are ignored generated views
- step: branch from origin/main in your own git worktree, never the ~/dotfiles primary clone
- step: run the link loop and the cancel exactly as in Context, then work-order.sh check --id THIS-TICKET-ID, submit --pr <this PR>, done
- step: commit 'chore(work-orders): close WO-20261016-fb99 under its re-checked successor' with the ticket id; no Bump trailer
- tool: make:Makefile:rolodex-check - on main; fallback: missing: stop with DESIGN-GAP naming it
- tool: cmd:git, cmd:jq, cmd:make, cmd:podman, cmd:gh - fallback: missing on the host: stop with ENV-MISSING naming it; gh or GitHub down: retry 3 times, then stop with A2A-003 and its output

**Out - non-goals**

- any code, test or doc file: PR 270 shipped them
- the stale seat worktree and branch named in Problem: the orchestrator retires them (line operation)
- any file not named under In: stop with DESIGN-GAP
- work-orders/INDEX.md and epic READMEs by hand or by git add; waiting on CI or merging: push, open the PR, write the result, leave
- a Bump trailer: no skill under claude/skills changes

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [x] `AC-H1` *(human)* WO-20261016-fb99 check 1 passes on main
  - observed `2026-10-16` check: make -C claude/workflow pr-flow-test CASES="autofix consume regen-index rerun-stale-red records" exit 0 output: make: Entering directory '/home/luna/.cache/wt-close-fb99/claude/workflow' ok image: localhost/dotfiles-workflow-test:1 ok autofix ok consume ok regen-index ok rerun-stale-red ok records make: Leaving directory '/home/luna/.cache/wt-close-fb99/claude/workflow'
  - check: `make -C claude/workflow pr-flow-test CASES="autofix consume regen-index rerun-stale-red records"` exit 0 expect /ok autofix/
- [x] `AC-H2` *(human)* WO-20261016-fb99 check 2 passes on main
  - observed `2026-10-16` check: make -C claude/workflow pr-flow-lint exit 0 output: make: Entering directory '/home/luna/.cache/wt-close-fb99/claude/workflow' ok image: localhost/dotfiles-workflow-test:1 make: Leaving directory '/home/luna/.cache/wt-close-fb99/claude/workflow'
  - check: `make -C claude/workflow pr-flow-lint` exit 0
- [x] `AC-H3` *(human)* WO-20261016-fb99 check 3 passes on main
  - observed `2026-10-16` check: make -C claude/workflow pr-autofix exit 2 output: make: Entering directory '/home/luna/.cache/wt-close-fb99/claude/workflow' pr-autofix needs REPO= make: *** [pr-flow/pr-flow.mk:48: pr-autofix] Error 2 make: Leaving directory '/home/luna/.cache/wt-close-fb99/claude/workflow'
  - check: `make -C claude/workflow pr-autofix` exit 2 expect /pr-autofix needs REPO=/
- [x] `AC-H4` *(human)* WO-20261016-fb99 check 4 passes on main
  - observed `2026-10-16` check: jq -r .defaults.autofix.mode claude/workflow/pr-flow/config/pr-flow.json exit 0 output: on
  - check: `jq -r .defaults.autofix.mode claude/workflow/pr-flow/config/pr-flow.json` exit 0 expect /^on$/
- [x] `AC-H5` *(human)* WO-20261016-fb99 check 5 passes on main
  - observed `2026-10-16` check: bash -c python3 -c 'import xml.dom.minidom,sys; xml.dom.minidom.parse(sys.argv[1])' claude/workflow/docs/pr-process/pr-process.spec.xml && grep -c 'value="AUTOFIX"' claude/workflow/docs/pr-process/pr-process.spec.xml exit 0 output: 1
  - check: `bash -c python3\ -c\ \'import\ xml.dom.minidom\,sys\;\ xml.dom.minidom.parse\(sys.argv\[1\]\)\'\ claude/workflow/docs/pr-process/pr-process.spec.xml\ \&\&\ grep\ -c\ \'value=\"AUTOFIX\"\'\ claude/workflow/docs/pr-process/pr-process.spec.xml` exit 0 expect /^1$/
- [x] `AC-H6` *(human)* WO-20261016-fb99 check 6 passes on main
  - observed `2026-10-16` check: make rolodex-check BASE=origin/main exit 0 output: python3 scripts/rolodex.py check --root . --base origin/main rolodex-check: 0 script(s) checked, all have headers
  - check: `make rolodex-check BASE=origin/main` exit 0
- [x] `AC-H7` *(human)* WO-20261016-fb99 check 7 passes on main
  - observed `2026-10-16` check: bash -c ! git diff --name-only origin/main...HEAD | grep -vE '^(work-orders/|claude/workflow/(pr-flow/(bin/pr-flow-consume\.sh|pr-flow\.mk|config/pr-flow\.json|schemas/pr-flow-record\.schema\.json|tests/(autofix|records)\.test\.sh)|docs/pr-process/pr-process\.(md|spec\.xml)))$' exit 0 output:
  - check: `bash -c \!\ git\ diff\ --name-only\ origin/main...HEAD\ \|\ grep\ -vE\ \'\^\(work-orders/\|claude/workflow/\(pr-flow/\(bin/pr-flow-consume\\.sh\|pr-flow\\.mk\|config/pr-flow\\.json\|schemas/pr-flow-record\\.schema\\.json\|tests/\(autofix\|records\)\\.test\\.sh\)\|docs/pr-process/pr-process\\.\(md\|spec\\.xml\)\)\)\$\'` exit 0
- [x] `AC-H8` *(human)* WO-20261016-fb99 is cancelled and superseded by this ticket
  - observed `2026-10-16` check: bash claude/skills/work-order/scripts/work-order.sh show --id WO-20261016-fb99 --json | jq -r '.status + " " + (.superseded_by // "-")' exit 0 output: cancelled WO-20261016-1b7e
  - check: `bash claude/skills/work-order/scripts/work-order.sh show --id WO-20261016-fb99 --json | jq -r '.status + " " + (.superseded_by // "-")'` exit 0 expect /^cancelled WO-/
- [x] `AC-H9` *(human)* the diff holds only generated work-orders files
  - observed `2026-10-16` check: git diff --name-only origin/main...HEAD | grep -vE '^(work-orders/.*)$' exit 1 output:
  - check: `git diff --name-only origin/main...HEAD | grep -vE '^(work-orders/.*)$'` exit 1

## Test plan

```sh
{"scope":"WO-20261016-fb99 checks re-run on main","cases":[{"id":"TP-1","intent":"merged code still meets every criterion of WO-20261016-fb99","command":"bash claude/skills/work-order/scripts/work-order.sh check --id THIS-TICKET-ID","expected":"exit 0; one AC-PASS line per criterion"}],"isolation":{"runtime":"podman","image":"as each copied check names"},"out_of_scope":["full suites: CI runs them"]}
```

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

Cancelled `2026-10-16` - nothing shipped.

- reason: its fb99 close-out landed in PR 317; done refused ac_check_failed 7 (check 7 regex contradicts check 9); checks re-run under WO-20261016-aa46 without 7
- superseded by: `WO-20261016-aa46`

No branch, no PR and no merge commit exist for this work order.

