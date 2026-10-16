---
{
  "id": "WO-20261016-8454",
  "slug": "a2a-st-seat-state-file-spec-seat-state-schema-js",
  "title": "A2A-ST: seat state file spec - seat-state.schema.json, output.state_file in the brief, brief.sh state-check",
  "type": "feature",
  "status": "cancelled",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T07:00:30+00:00",
  "parent": "WO-20261016-0272",
  "branch": null,
  "pr": null,
  "closed": "2026-10-16",
  "approval": {
    "via": "override",
    "reason": "infra-design12 cut for ORD-0830 RR-orch-14; design approvals ruled done, ORD-0550 O4",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [
    "WO-20261016-d304",
    "WO-20261016-8c8c",
    "WO-20261016-23b5"
  ],
  "blocks": [],
  "ac_checks": [
    {
      "index": 1,
      "command": "podman run --rm --network=none --userns=keep-id -v $PWD:/work:Z -w /work/claude/workflow -e HOME=/tmp localhost/dotfiles-workflow-test:1 bash tests/unit/test_a2a_state.sh",
      "exit": 0,
      "expect": "^ok "
    },
    {
      "index": 2,
      "command": "bash claude/workflow/bin/brief.sh state-check /home/luna/.local/state/zenith/inbox-triage/20261015/seats/f08-state.json",
      "exit": 0,
      "expect": "^ok "
    },
    {
      "index": 3,
      "command": "env FORCE_FALLBACK=1 bash claude/workflow/bin/timed-run.sh --node a2a-st --fallback \"podman run --rm --pull=never --network=none --userns=keep-id -v $PWD:/work:Z -w /work/claude/workflow -e HOME=/tmp localhost/dotfiles-workflow-test:1 bash tests/unit/test_a2a_state.sh\" --fallback-code FB-001 -- podman run --rm --network=none --userns=keep-id -v $PWD:/work:Z -w /work/claude/workflow -e HOME=/tmp localhost/dotfiles-workflow-test:1 bash tests/unit/test_a2a_state.sh 2>&1",
      "exit": 0,
      "expect": "FALLBACK FB-001"
    },
    {
      "index": 4,
      "command": "git diff --name-only origin/main...HEAD | grep -vE '^(work-orders/.*|claude/workflow/(schemas/seat-state\\.schema\\.json|schemas/brief\\.schema\\.json|templates/a2a/brief\\.json|bin/brief\\.sh|a2a\\.mk|tests/unit/test_a2a_state\\.sh))$'",
      "exit": 1,
      "expect": null
    }
  ],
  "provides": [
    "path:claude/workflow/tests/unit/test_a2a_state.sh"
  ],
  "superseded_by": "WO-20261016-bcb4"
}
---

# WO-20261016-8454 - A2A-ST: seat state file spec - seat-state.schema.json, output.state_file in the brief, brief.sh state-check

## Contents

- Problem
- Scope
- Degrees of freedom
- Acceptance criteria
- Test plan
- Assumptions
- Open questions
- Notes
- Outcome

## Problem

Orchestrator order O1 of MSG-20261016T064822Z-yp-design (2026-10-16 UTC): 'briefs name a state_file with no content spec, and yp results use schema yp-result/0, not zenith.a2a.result.v1 (brief.sh result-check fails); align the yp brief/result template.' Facts: yp-line's seat briefs (for example lif04c-brief.json in /home/luna/.local/state/zenith/inbox-triage/20261015/seats) carry schema yp-brief/0 with a state_file path and a result_shape of schema yp-result/0; the state files actually written are JSONL rows {step, status, at, proof} (f08-state.json); no schema or template in dotfiles names either shape. Owner item 18: 'agent to agent prose sucks, schemas with defined AC always'. Owner item 30: 'so its re-usable, add to it, makefiles, dont' be a crackhead and one off shit all the time': this adds a verb and two migrations to brief.sh, the existing tool.

## Scope

**In**

- touches: claude/workflow/schemas/seat-state.schema.json (new)
- touches: claude/workflow/schemas/brief.schema.json
- touches: claude/workflow/templates/a2a/brief.json
- touches: claude/workflow/bin/brief.sh
- touches: claude/workflow/a2a.mk
- touches: claude/workflow/tests/unit/test_a2a_state.sh (new)
- step: seat-state.schema.json, JSON Schema 2020-12, $id zenith.a2a.seat-state.v1, describes ONE line of a JSONL state file: object, additionalProperties false, required [step, status, at, proof]; step string minLength 1 (the brief's action or AC id); status enum [started, done, failed, skipped]; at string pattern '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$'; proof string, minLength 1 when status is done or failed (if/then)
- step: brief.schema.json: properties.output.properties gains optional 'state_file' (string, minLength 1, description 'JSONL file the seat appends one zenith.a2a.seat-state.v1 row to per step; the seat's resume point after a compaction'); required stays [result_file]
- step: templates/a2a/brief.json: output gains '"state_file": "<path>/state.jsonl"'
- step: brief.sh: verb 'state-check FILE': a missing file dies 'no such file'; each non-empty line must be JSON and pass the existing 'validate' helper against seat-state.schema.json; success prints 'ok <file> <n> row(s)' and exits 0; the first bad line dies '<file>:<line> fails seat-state.schema.json' (exit 1, the die convention of brief.sh); usage line gains state-check
- step: a2a.mk: target 'state-check: ## Validate a seat state file: FILE=' calling '$(BRIEF_SH) state-check "$(FILE)"', and a2a-test's bash -c line also runs 'shellcheck -x tests/unit/test_a2a_state.sh && bash tests/unit/test_a2a_state.sh'
- step: tests/unit/test_a2a_state.sh, set -euo pipefail, one 'ok <case>' line per case on success, 'FAIL <case>' and exit 1 otherwise: (1) a 3-row valid file passes, (2) status 'finished' fails, (3) at '2026-10-16T05:02:06+02:00' fails, (4) status done with empty proof fails, (5) a brief with output.state_file passes 'brief.sh check'
- touches (generated, written only by work-order.sh start/submit/done, never by hand or git add): this ticket file and its archive path; work-orders/INDEX.md and the parent epic README.md are ignored generated views
- step: branch from origin/main in your own worktree; build the image with `make -C claude/workflow image`; make exactly the six file edits above
- step: run TP-1 to TP-3 and the AC checks only, from the worktree root; CI runs the rest; commit 'feat(workflow): seat state file schema and brief.sh state-check (A2A-ST)' with the ticket id; no Bump trailer
- tool: podman with the locally built image localhost/dotfiles-workflow-test:1 (make -C claude/workflow image, digest-pinned FROM) - fallback: the pull or build fails: rerun with --pull=never on the cached image through claude/workflow/bin/timed-run.sh --fallback ... --fallback-code FB-001 (WO-20261016-d304 - TR-FB); image absent: stop with ENV-MISSING podman
- tool: cmd:git, cmd:jq, cmd:make, cmd:shellcheck, cmd:gh - fallback: missing on the host: stop with ENV-MISSING naming it; gh or GitHub down: retry 3 times, then stop with A2A-003 and its output

**Out - non-goals**

- writing state rows: seats keep writing their own rows; this is the shape and the check
- templates/a2a/README.md (TR-FB edits its code table)
- migrating yp briefs (WO-20261016-9821 - A2A-YP)
- work-orders/INDEX.md and epic READMEs by hand or by git add; waiting on CI or merging: push, open the PR, write the result, leave
- any file not named under In: stop with DESIGN-GAP

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [ ] `AC-H1` *(human)* the five state cases pass in the pinned image
  - check: `podman run --rm --network=none --userns=keep-id -v $PWD:/work:Z -w /work/claude/workflow -e HOME=/tmp localhost/dotfiles-workflow-test:1 bash tests/unit/test_a2a_state.sh` exit 0 expect /^ok/
- [ ] `AC-H2` *(human)* a real seat state file passes state-check
  - check: `bash claude/workflow/bin/brief.sh state-check /home/luna/.local/state/zenith/inbox-triage/20261015/seats/f08-state.json` exit 0 expect /^ok/
- [ ] `AC-H3` *(human)* the fallback switch runs the cached-image path and codes it
  - check: `env FORCE_FALLBACK=1 bash claude/workflow/bin/timed-run.sh --node a2a-st --fallback "podman run --rm --pull=never --network=none --userns=keep-id -v $PWD:/work:Z -w /work/claude/workflow -e HOME=/tmp localhost/dotfiles-workflow-test:1 bash tests/unit/test_a2a_state.sh" --fallback-code FB-001 -- podman run --rm --network=none --userns=keep-id -v $PWD:/work:Z -w /work/claude/workflow -e HOME=/tmp localhost/dotfiles-workflow-test:1 bash tests/unit/test_a2a_state.sh 2>&1` exit 0 expect /FALLBACK FB-001/
- [ ] `AC-H4` *(human)* the diff holds only In files and generated work-orders files
  - check: `git diff --name-only origin/main...HEAD | grep -vE '^(work-orders/.*|claude/workflow/(schemas/seat-state\.schema\.json|schemas/brief\.schema\.json|templates/a2a/brief\.json|bin/brief\.sh|a2a\.mk|tests/unit/test_a2a_state\.sh))$'` exit 1

## Test plan

```sh
{"scope":"seat state file schema and brief.sh state-check (A2A-ST)","cases":[{"id":"TP-1","intent":"a seat resumes after compaction from its state file only if every row has one checked shape","command":"podman run --rm --network=none --userns=keep-id -v $PWD:/work:Z -w /work/claude/workflow -e HOME=/tmp localhost/dotfiles-workflow-test:1 bash tests/unit/test_a2a_state.sh","expected":"exit 0; five lines starting ok, no FAIL"},{"id":"TP-2","intent":"the check accepts a state file a live seat wrote","command":"bash claude/workflow/bin/brief.sh state-check /home/luna/.local/state/zenith/inbox-triage/20261015/seats/f08-state.json","expected":"exit 0; output starts ok"},{"id":"TP-3","intent":"the declared fallback (cached image) has its own test (item 28)","command":"env FORCE_FALLBACK=1 bash claude/workflow/bin/timed-run.sh --node a2a-st --fallback \"podman run --rm --pull=never --network=none --userns=keep-id -v $PWD:/work:Z -w /work/claude/workflow -e HOME=/tmp localhost/dotfiles-workflow-test:1 bash tests/unit/test_a2a_state.sh\" --fallback-code FB-001 -- podman run --rm --network=none --userns=keep-id -v $PWD:/work:Z -w /work/claude/workflow -e HOME=/tmp localhost/dotfiles-workflow-test:1 bash tests/unit/test_a2a_state.sh","expected":"exit 0; output contains FALLBACK FB-001"}],"isolation":{"runtime":"podman","image":"localhost/dotfiles-workflow-test:1"},"out_of_scope":["a2a-lint and the full workflow suite: CI runs them"]}
```

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

Cancelled `2026-10-16` - nothing shipped.

- reason: code merged in PR 292; AC-H2 named a pre-schema state file; checks re-run under WO-20261016-bcb4
- superseded by: `WO-20261016-bcb4`

No branch, no PR and no merge commit exist for this work order.

