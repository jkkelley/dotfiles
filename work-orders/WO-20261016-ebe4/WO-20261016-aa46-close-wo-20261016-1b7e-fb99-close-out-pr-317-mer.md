---
{
  "id": "WO-20261016-aa46",
  "slug": "close-wo-20261016-1b7e-fb99-close-out-pr-317-mer",
  "title": "Close WO-20261016-1b7e (fb99 close-out, PR 317 merged, done refused ac_check_failed 7): re-run checks 1-6 and 8 under this ticket without the contradicting check 7, move its acbe edge here and cancel 1b7e as superseded",
  "type": "chore",
  "status": "ready",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T11:12:04+00:00",
  "parent": "WO-20261016-ebe4",
  "branch": null,
  "pr": null,
  "closed": null,
  "approval": {
    "via": "override",
    "reason": "infra-design17 cut for ORD-1053 / ORD-0830 RR-orch-14; design approvals ruled done, ORD-0550 O4; Lavish prohibited for Claude seats (global rule)",
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
      "command": "bash claude/skills/work-order/scripts/work-order.sh show --id WO-20261016-fb99 --json | jq -r '.status + \" \" + (.superseded_by // \"-\")'",
      "exit": 0,
      "expect": "^cancelled WO-"
    },
    {
      "index": 8,
      "command": "bash claude/skills/work-order/scripts/work-order.sh show --id WO-20261016-1b7e --json | jq -r '.status + \" \" + (.superseded_by // \"-\")'",
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
  ]
}
---

# WO-20261016-aa46 - Close WO-20261016-1b7e (fb99 close-out, PR 317 merged, done refused ac_check_failed 7): re-run checks 1-6 and 8 under this ticket without the contradicting check 7, move its acbe edge here and cancel 1b7e as superseded

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

WO-20261016-1b7e cannot close: work-order.sh done refuses ac_check_failed 7. Its check 7 pipes git diff into grep -vE '^(work-orders/|claude/workflow/(...))$' with the $ outside the work-orders/ alternative, so only a line equal to 'work-orders/' matches; any ticket path in the diff makes check 7 exit 1, while check 9 requires a work-orders-only diff, so 7 and 9 contradict. Evidence: ~/.local/state/zenith/inbox-triage/20261015/seats/close-fb99.result.json (DESIGN-GAP, done refused ac_check_failed 7); on main 1b7e is in-progress with every box ticked, fb99 cancelled superseded-by 1b7e, acbe depends on 1b7e (PR 317 merged).

## Owner words

> DESIGN-GAP 1b7e ac_checks[7]: WO-20261016-1b7e - Close WO-20261016-fb99 (pr-flow sweep autofix, PR 270 merged): re-run its checks under this ticket, move its edges here and cancel fb99 as superseded: ac_checks[7] contradicts AC-H9 ($ inside the regex group); fix the regex or drop AC-H7. PR 317 merged. (orchestrator brief BR-20261016-infra-design17)

> get this code merged the fuck in, dead code is shit, it sitting under agents is stupid (Design principles 101 item 21)

## Context

Order brief BR-20261016-infra-design17, ORD-0830 RR-orch-14; pattern WO-20261016-1b7e and WO-20261016-bcb4. Ruling on the gap: check 7 is dropped, not repaired. It was fb99's code-scope check; on a close ticket the diff is work-orders files only, and check 9 (copied here as the last criterion) already asserts that, so a repaired 7 would prove nothing 9 does not. Checks 1-6 and 8 of 1b7e are copied verbatim; a new criterion proves 1b7e cancelled. The generator side (a scope check anchoring a bare work-orders/ alternative) is WO-20261016-25f7, already ready; nothing is recut for it. THIS-TICKET-ID is this ticket's own id, the .id in its frontmatter. Steps on the branch, after start: bash claude/skills/work-order/scripts/work-order.sh link --id WO-20261016-acbe --depends-on THIS-TICKET-ID --no-depends-on WO-20261016-1b7e; then bash claude/skills/work-order/scripts/work-order.sh cancel --id WO-20261016-1b7e --reason 'its fb99 close-out landed in PR 317; done refused ac_check_failed 7 (check 7 regex contradicts check 9); checks re-run under THIS-TICKET-ID without 7' --superseded-by THIS-TICKET-ID; then bash claude/skills/work-order/scripts/work-order.sh check --id THIS-TICKET-ID (check ticks every passing criterion; never tick by hand with evidence); commit those generated moves; open the PR; submit --pr <N>; done; commit and push.

## Scope

**In**

- touches (generated, by work-order.sh link and cancel only): the WO-20261016-1b7e ticket file and its archive path, the WO-20261016-acbe ticket file
- touches (generated, written only by work-order.sh start/submit/done, never by hand or git add): this ticket file and its archive path; work-orders/INDEX.md and the parent epic README.md are ignored generated views
- step: branch from origin/main in your own git worktree, never the ~/dotfiles primary clone
- step: run the link, the cancel and the check exactly as in Context, then submit --pr <this PR> and done
- step: commit 'chore(work-orders): close WO-20261016-1b7e under its re-checked successor' with the ticket id; no Bump trailer
- tool: make:claude/workflow/Makefile:pr-flow-test, make:claude/workflow/Makefile:pr-flow-lint, make:claude/workflow/Makefile:pr-autofix - on main (PR 270); fallback: missing: stop with DESIGN-GAP naming it; image build fails: stop with ENV-MISSING podman
- tool: make:Makefile:rolodex-check - on main; fallback: missing: stop with DESIGN-GAP naming it
- tool: cmd:git, cmd:jq, cmd:make, cmd:podman, cmd:gh, cmd:python3 - fallback: missing on the host: stop with ENV-MISSING naming it; gh or GitHub down: retry 3 times, then stop with A2A-003 and its output

**Out - non-goals**

- any code, test or doc file: PR 270 shipped them
- the stale seat worktree /home/luna/.cache/wt-close-fb99 and its branch: the orchestrator retires them (line operation)
- WO-20261016-fb99: already cancelled on main; not touched
- any file not named under In: stop with DESIGN-GAP
- work-orders/INDEX.md and epic READMEs by hand or by git add; waiting on CI or merging: push, open the PR, write the result, leave
- a Bump trailer: no skill under claude/skills changes

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [ ] `AC-H1` *(human)* WO-20261016-fb99 check 1 passes on main (copied from WO-20261016-1b7e check 1)
  - check: `make -C claude/workflow pr-flow-test CASES="autofix consume regen-index rerun-stale-red records"` exit 0 expect /ok autofix/
- [ ] `AC-H2` *(human)* WO-20261016-fb99 check 2 passes on main (copied from WO-20261016-1b7e check 2)
  - check: `make -C claude/workflow pr-flow-lint` exit 0
- [ ] `AC-H3` *(human)* WO-20261016-fb99 check 3 passes on main (copied from WO-20261016-1b7e check 3)
  - check: `make -C claude/workflow pr-autofix` exit 2 expect /pr-autofix needs REPO=/
- [ ] `AC-H4` *(human)* WO-20261016-fb99 check 4 passes on main (copied from WO-20261016-1b7e check 4)
  - check: `jq -r .defaults.autofix.mode claude/workflow/pr-flow/config/pr-flow.json` exit 0 expect /^on$/
- [ ] `AC-H5` *(human)* WO-20261016-fb99 check 5 passes on main (copied from WO-20261016-1b7e check 5)
  - check: `bash -c python3\ -c\ \'import\ xml.dom.minidom\,sys\;\ xml.dom.minidom.parse\(sys.argv\[1\]\)\'\ claude/workflow/docs/pr-process/pr-process.spec.xml\ \&\&\ grep\ -c\ \'value=\"AUTOFIX\"\'\ claude/workflow/docs/pr-process/pr-process.spec.xml` exit 0 expect /^1$/
- [ ] `AC-H6` *(human)* WO-20261016-fb99 check 6 passes on main (copied from WO-20261016-1b7e check 6)
  - check: `make rolodex-check BASE=origin/main` exit 0
- [ ] `AC-H7` *(human)* WO-20261016-fb99 is cancelled and superseded
  - check: `bash claude/skills/work-order/scripts/work-order.sh show --id WO-20261016-fb99 --json | jq -r '.status + " " + (.superseded_by // "-")'` exit 0 expect /^cancelled WO-/
- [ ] `AC-H8` *(human)* WO-20261016-1b7e is cancelled and superseded by this ticket
  - check: `bash claude/skills/work-order/scripts/work-order.sh show --id WO-20261016-1b7e --json | jq -r '.status + " " + (.superseded_by // "-")'` exit 0 expect /^cancelled WO-/
- [ ] `AC-H9` *(human)* the diff holds only generated work-orders files
  - check: `git diff --name-only origin/main...HEAD | grep -vE '^(work-orders/.*)$'` exit 1

## Test plan

```sh
{"scope":"WO-20261016-fb99 checks re-run on main under the 1b7e successor","cases":[{"id":"TP-1","intent":"merged code still meets every criterion of WO-20261016-fb99, and 1b7e no longer blocks acbe","command":"bash claude/skills/work-order/scripts/work-order.sh check --id THIS-TICKET-ID","expected":"exit 0; one AC-PASS line per criterion"}],"isolation":{"runtime":"podman","image":"as each copied check names"},"out_of_scope":["full suites: CI runs them"]}
```

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
