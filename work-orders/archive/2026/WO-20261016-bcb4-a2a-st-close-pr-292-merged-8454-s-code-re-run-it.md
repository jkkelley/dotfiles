---
{
  "id": "WO-20261016-bcb4",
  "slug": "a2a-st-close-pr-292-merged-8454-s-code-re-run-it",
  "title": "A2A-ST close: PR 292 merged 8454's code; re-run its checks with AC-H2 on a JSONL state row, move 8454's edges here and cancel 8454 as superseded",
  "type": "chore",
  "status": "done",
  "priority": "p2",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T10:28:14+00:00",
  "parent": "WO-20261016-0272",
  "branch": "feat/a2a-st-close-pr-292-merged-8454-s-code-re-run-it",
  "pr": 313,
  "closed": "2026-10-16",
  "approval": {
    "via": "override",
    "reason": "infra-design14 cut for ORD-0830 RR-orch-14 F35; design approvals ruled done, ORD-0550 O4",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [],
  "blocks": [
    "WO-20261016-48af",
    "WO-20261016-9821",
    "WO-20261016-7838"
  ],
  "ac_checks": [
    {
      "index": 1,
      "command": "podman run --rm --network=none --userns=keep-id -v $PWD:/work:Z -w /work/claude/workflow -e HOME=/tmp localhost/dotfiles-workflow-test:1 bash tests/unit/test_a2a_state.sh",
      "exit": 0,
      "expect": "^ok "
    },
    {
      "index": 2,
      "command": "bash -c 'f=$(mktemp); printf \"%s\\n\" \"{\\\"step\\\":\\\"read\\\",\\\"status\\\":\\\"done\\\",\\\"at\\\":\\\"2026-10-16T05:00:00Z\\\",\\\"proof\\\":\\\"brief read\\\"}\" \"{\\\"step\\\":\\\"AC1\\\",\\\"status\\\":\\\"started\\\",\\\"at\\\":\\\"2026-10-16T05:01:00Z\\\",\\\"proof\\\":\\\"\\\"}\" > \"$f\"; bash claude/workflow/bin/brief.sh state-check \"$f\"; rc=$?; rm -f \"$f\"; exit $rc'",
      "exit": 0,
      "expect": "^ok"
    },
    {
      "index": 3,
      "command": "bash claude/skills/work-order/scripts/work-order.sh show --id WO-20261016-8454 --json | jq -r '.status'",
      "exit": 0,
      "expect": "^cancelled$"
    },
    {
      "index": 4,
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

# WO-20261016-bcb4 - A2A-ST close: PR 292 merged 8454's code; re-run its checks with AC-H2 on a JSONL state row, move 8454's edges here and cancel 8454 as superseded

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

WO-20261016-8454 shipped in PR 292 (merged 10:03Z) but stays ready on main: its AC-H2 and TP-2 run brief.sh state-check on seats/f08-state.json, a pre-schema file holding one JSON object {nodes,updated}, not the JSONL rows {step,status,at,proof} that 8454's own seat-state.schema.json defines, so the check can never pass and the ticket cannot close. amend refuses a ready ticket.

## Owner words

> DESIGN-GAP WO-20261016-8454 AC-H2 ... Fix the fixture named by the check (a JSONL state file) or the schema (orchestrator brief BR-20261016-infra-design14)

> if the task or job needs tools, the architect has a design agent build that shit out before the ticket goes in, thats a prereq for the ticket ready then (Design principles 101 item 30)

## Context

Order brief BR-20261016-infra-design14, ORD-0830 RR-orch-14; F35; evidence seats/seat-state.result.json (H1 H3 H4 pass, H2 DESIGN-GAP) and seats/f08-state.json content {"nodes":[...],"updated":"2026-10-16T05:00:00Z"}. Ruling: fix the fixture, not the schema; every seat state file on disk predates output.state_file, so the check runs on a row written by the check itself. The schema stays as merged.

Precondition: PR 300 (infra-design13) is merged, because it adds 8454 blocks WO-20261016-7838; check gh pr view 300 --json state -q .state prints MERGED, else stop with DESIGN-GAP. THIS-TICKET-ID is this ticket's own id, the .id in its frontmatter. Steps on the branch: for each id in $(bash claude/skills/work-order/scripts/work-order.sh show --id WO-20261016-8454 --json | jq -r '.blocks[]'): work-order.sh link --id $id --depends-on THIS-TICKET-ID --no-depends-on WO-20261016-8454; then work-order.sh cancel --id WO-20261016-8454 --reason 'code merged in PR 292; AC-H2 named a pre-schema state file; checks re-run under THIS-TICKET-ID' --superseded-by THIS-TICKET-ID; commit those generated moves.

## Scope

**In**

- touches (generated, by work-order.sh link and cancel only): the 8454 ticket file and its archive path, the ticket files of every id in 8454's blocks list
- touches (generated, written only by work-order.sh start/submit/done, never by hand or git add): this ticket file and its archive path; work-orders/INDEX.md and the parent epic README.md are ignored generated views
- step: branch from origin/main in your own git worktree, never the ~/dotfiles primary clone
- step: check the precondition in Context, then run the link loop and the cancel exactly as in Context
- step: run the AC checks only
- step: commit 'chore(work-orders): close A2A-ST 8454 under its re-checked successor' with the ticket id; no Bump trailer
- tool: localhost/dotfiles-workflow-test:1 image for AC-H1 - fallback: missing: make -C claude/workflow image, then retry once; build fails: stop with ENV-MISSING podman
- tool: cmd:git, cmd:jq, cmd:make, cmd:podman, cmd:gh - fallback: missing on the host: stop with ENV-MISSING naming it; gh or GitHub down: retry 3 times, then stop with A2A-003 and its output

**Out - non-goals**

- claude/workflow code, schemas or tests: PR 292 shipped them
- migrating old {nodes,updated} state files: no seat is briefed with output.state_file yet
- any file not named under In: stop with DESIGN-GAP
- work-orders/INDEX.md and epic READMEs by hand or by git add; waiting on CI or merging: push, open the PR, write the result, leave
- a Bump trailer: no skill under claude/skills changes

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [x] `AC-H1` *(human)* 8454's unit cases still pass on main
  - observed `2026-10-16` check: podman run --rm --network=none --userns=keep-id -v $PWD:/work:Z -w /work/claude/workflow -e HOME=/tmp localhost/dotfiles-workflow-test:1 bash tests/unit/test_a2a_state.sh exit 0 output: ok 3-row valid file passes ok status finished fails ok non-UTC at fails ok done with empty proof fails ok brief with output.state_file passes check
  - check: `podman run --rm --network=none --userns=keep-id -v $PWD:/work:Z -w /work/claude/workflow -e HOME=/tmp localhost/dotfiles-workflow-test:1 bash tests/unit/test_a2a_state.sh` exit 0 expect /^ok/
- [x] `AC-H2` *(human)* a JSONL state row in the schema's shape passes state-check
  - observed `2026-10-16` check: bash -c 'f=$(mktemp); printf "%s
" "{"step":"read","status":"done","at":"2026-10-16T05:00:00Z","proof":"brief read"}" "{"step":"AC1","status":"started","at":"2026-10-16T05:01:00Z","proof":""}" > "$f"; bash claude/workflow/bin/brief.sh state-check "$f"; rc=$?; rm -f "$f"; exit $rc' exit 0 output: ok /tmp/tmp.6qWsKJVmDF 2 row(s)
  - check: `bash -c 'f=$(mktemp); printf "%s\n" "{\"step\":\"read\",\"status\":\"done\",\"at\":\"2026-10-16T05:00:00Z\",\"proof\":\"brief read\"}" "{\"step\":\"AC1\",\"status\":\"started\",\"at\":\"2026-10-16T05:01:00Z\",\"proof\":\"\"}" > "$f"; bash claude/workflow/bin/brief.sh state-check "$f"; rc=$?; rm -f "$f"; exit $rc'` exit 0 expect /^ok/
- [x] `AC-H3` *(human)* 8454 is cancelled and superseded by this ticket
  - observed `2026-10-16` check: bash claude/skills/work-order/scripts/work-order.sh show --id WO-20261016-8454 --json | jq -r '.status' exit 0 output: cancelled
  - check: `bash claude/skills/work-order/scripts/work-order.sh show --id WO-20261016-8454 --json | jq -r '.status'` exit 0 expect /^cancelled$/
- [x] `AC-H4` *(human)* the diff holds only generated work-orders files
  - observed `2026-10-16` check: git diff --name-only origin/main...HEAD | grep -vE '^(work-orders/.*)$' exit 1 output:
  - check: `git diff --name-only origin/main...HEAD | grep -vE '^(work-orders/.*)$'` exit 1

## Test plan

```sh
{"scope":"8454 checks re-run on main with a schema-shaped state row","cases":[{"id":"TP-1","intent":"8454 code is merged; its checks must pass on main before its edges move","command":"podman run --rm --network=none --userns=keep-id -v $PWD:/work:Z -w /work/claude/workflow -e HOME=/tmp localhost/dotfiles-workflow-test:1 bash tests/unit/test_a2a_state.sh","expected":"exit 0; five ok lines"}],"isolation":{"runtime":"podman","image":"localhost/dotfiles-workflow-test:1"},"out_of_scope":["a2a-lint and the full workflow suite: CI runs them"]}
```

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
