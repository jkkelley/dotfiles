---
{
  "id": "WO-20261016-8454",
  "slug": "a2a-st-seat-state-file-spec-seat-state-schema-js",
  "title": "A2A-ST: seat state file spec - seat-state.schema.json, output.state_file in the brief, brief.sh state-check",
  "type": "feature",
  "status": "draft",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T07:00:30+00:00",
  "parent": "WO-20261016-0272",
  "branch": null,
  "pr": null,
  "closed": null,
  "approval": null,
  "evidence": null,
  "surfaces": [],
  "depends_on": [
    "WO-20261016-d304",
    "WO-20261016-8c8c",
    "WO-20261016-23b5"
  ],
  "blocks": [
    "WO-20261016-48af",
    "WO-20261016-9821"
  ]
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
- step: seat-state.schema.json, JSON Schema 2020-12, $id zenith.a2a.seat-state.v1, describes ONE line of a JSONL state file: object, additionalProperties false, required [step, status, at, proof]; step string minLength 1 (the brief's action or AC id); status enum [started, done, failed, skipped]; at string pattern `^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$`; proof string, minLength 1 when status is done or failed (if/then)
- step: brief.schema.json: properties.output.properties gains optional `state_file` (string, minLength 1, description `JSONL file the seat appends one zenith.a2a.seat-state.v1 row to per step; the seat's resume point after a compaction`); required stays [result_file]
- step: templates/a2a/brief.json: output gains `"state_file": "<path>/state.jsonl"`
- step: brief.sh: verb `state-check FILE`: a missing file dies `no such file`; each non-empty line must be JSON and pass the existing `validate` helper against seat-state.schema.json; success prints `ok <file> <n> row(s)` and exits 0; the first bad line dies `<file>:<line> fails seat-state.schema.json` (exit 1, the die convention of brief.sh); usage line gains state-check
- step: a2a.mk: target `state-check: ## Validate a seat state file: FILE=` calling `$(BRIEF_SH) state-check "$(FILE)"`, and a2a-test's bash -c line also runs `shellcheck -x tests/unit/test_a2a_state.sh && bash tests/unit/test_a2a_state.sh`
- step: tests/unit/test_a2a_state.sh, set -euo pipefail, one `ok <case>` line per case on success, `FAIL <case>` and exit 1 otherwise: (1) a 3-row valid file passes, (2) status `finished` fails, (3) at `2026-10-16T05:02:06+02:00` fails, (4) status done with empty proof fails, (5) a brief with output.state_file passes `brief.sh check`
- Tool: podman with a digest-pinned image (make -C ~/dotfiles/claude/workflow image builds localhost/dotfiles-workflow-test:1). Fallback: rerun with --pull=never on the locally cached image of the same digest. Switch: timed-run.sh --fallback ... --fallback-code FB-001 (status code FB-001; switch from WO-20261016-d304 - TR-FB)

**Out - non-goals**

- Writing state rows: seats keep writing their own rows; this is the shape and the check
- templates/a2a/README.md (TR-FB edits its code table)
- Migrating yp briefs (A2A-YP)

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [ ] `AC-H1` *(human)* `podman run --rm --network=none --userns=keep-id -v ~/dotfiles:/work:Z -w /work/claude/workflow -e HOME=/tmp localhost/dotfiles-workflow-test:1 bash tests/unit/test_a2a_state.sh` run from ~/dotfiles -> exit 0, output has 5 lines starting `ok` and no `FAIL`. Proof: command output
- [ ] `AC-H2` *(human)* `bash ~/dotfiles/claude/workflow/bin/brief.sh state-check /home/luna/.local/state/zenith/inbox-triage/20261015/seats/f08-state.json` -> exit 0, output starts `ok`. Proof: command output
- [ ] `AC-H3` *(human)* `FORCE_FALLBACK=1 bash ~/dotfiles/claude/workflow/bin/timed-run.sh --node a2a-st --fallback "podman run --rm --pull=never --network=none --userns=keep-id -v ~/dotfiles:/work:Z -w /work/claude/workflow -e HOME=/tmp localhost/dotfiles-workflow-test:1 bash tests/unit/test_a2a_state.sh" --fallback-code FB-001 -- podman run --rm --network=none --userns=keep-id -v ~/dotfiles:/work:Z -w /work/claude/workflow -e HOME=/tmp localhost/dotfiles-workflow-test:1 bash tests/unit/test_a2a_state.sh` run from ~/dotfiles -> exit 0, stderr contains `FALLBACK FB-001`. Proof: command output

## Test plan

```sh
podman run --rm --network=none --userns=keep-id -v ~/dotfiles:/work:Z -w /work/claude/workflow -e HOME=/tmp localhost/dotfiles-workflow-test:1 bash tests/unit/test_a2a_state.sh
```

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
