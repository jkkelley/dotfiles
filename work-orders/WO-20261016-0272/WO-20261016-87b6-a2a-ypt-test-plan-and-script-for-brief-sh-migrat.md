---
{
  "id": "WO-20261016-87b6",
  "slug": "a2a-ypt-test-plan-and-script-for-brief-sh-migrat",
  "title": "A2A-YPt: test plan and script for brief.sh migrate for yp-brief/0 and yp-result/0",
  "type": "test",
  "status": "draft",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T07:00:45+00:00",
  "parent": "WO-20261016-0272",
  "branch": null,
  "pr": null,
  "closed": null,
  "approval": null,
  "evidence": null,
  "surfaces": [],
  "depends_on": [
    "WO-20261016-9821"
  ],
  "blocks": [],
  "labels": [
    "line:inbox-triage"
  ]
}
---

# WO-20261016-87b6 - A2A-YPt: test plan and script for brief.sh migrate for yp-brief/0 and yp-result/0

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

Test sibling of A2A-YP. The tester runs exactly this plan from ~/dotfiles on the A2A-YP branch. Orchestrator order O1 of MSG-20261016T064822Z-yp-design (2026-10-16 UTC): 'briefs name a state_file with no content spec, and yp results use schema yp-result/0, not zenith.a2a.result.v1 (brief.sh result-check fails); align the yp brief/result template.' Facts: yp-line's seat briefs (for example lif04c-brief.json in /home/luna/.local/state/zenith/inbox-triage/20261015/seats) carry schema yp-brief/0 with a state_file path and a result_shape of schema yp-result/0; the state files actually written are JSONL rows {step, status, at, proof} (f08-state.json); no schema or template in dotfiles names either shape. Owner item 18: 'agent to agent prose sucks, schemas with defined AC always'. Owner item 30: 'so its re-usable, add to it, makefiles, dont' be a crackhead and one off shit all the time': this adds a verb and two migrations to brief.sh, the existing tool.

## Scope

**In**

- Run every case below from ~/dotfiles
- Evidence: every case's output, written to the path printed by `make -s -C ~/dotfiles artifact-new KEY=log NAME=a2a-yp-test EXT=log`
- Tool: make -C ~/dotfiles artifact-new (make artifact-new on main). Fallback: bash ~/dotfiles/claude/tools/artifact/artifact.sh new with the same KEY NAME EXT. Switch: timed-run.sh --fallback ... --fallback-code FB-004 (status code FB-004; switch from WO-20261016-d304 - TR-FB)
- Tool: podman with a digest-pinned image (make -C ~/dotfiles/claude/workflow image builds localhost/dotfiles-workflow-test:1). Fallback: rerun with --pull=never on the locally cached image of the same digest. Switch: timed-run.sh --fallback ... --fallback-code FB-001 (status code FB-001; switch from WO-20261016-d304 - TR-FB)

**Out - non-goals**

- Editing any file; a failing case is a note on the build ticket with its output

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [ ] `AC-H1` *(human)* Every case passes: each command exits as its expected line says. Proof: the evidence log path on this ticket

## Test plan

_Test plan from claude/workflow/templates/test-plan.md, shaped by claude/workflow/schemas/test-plan.schema.json. The tester runs exactly these cases and nothing else._

**Scope under test**

brief.sh migrate for yp-brief/0 and yp-result/0

**Cases**

- `TP-1`
  - intent: brief.sh migrate for yp-brief/0 and yp-result/0 works as the build ticket specifies
  - command: `podman run --rm --network=none --userns=keep-id -v ~/dotfiles:/work:Z -w /work/claude/workflow -e HOME=/tmp localhost/dotfiles-workflow-test:1 bash tests/unit/test_a2a_migrate_yp.sh`
  - expected: exit 0, 5 lines `ok`, no FAIL
- `TP-2`
  - intent: the a2a test target runs it
  - command: `make -C ~/dotfiles/claude/workflow -f a2a.mk a2a-test`
  - expected: exit 0, no FAIL
- `TP-3`
  - intent: fallback path: registry unreachable, the cached image runs
  - command: `FORCE_FALLBACK=1 bash ~/dotfiles/claude/workflow/bin/timed-run.sh --node a2a-yp-t --fallback "podman run --rm --pull=never --network=none --userns=keep-id -v ~/dotfiles:/work:Z -w /work/claude/workflow -e HOME=/tmp localhost/dotfiles-workflow-test:1 bash tests/unit/test_a2a_migrate_yp.sh" --fallback-code FB-001 -- podman run --rm --network=none --userns=keep-id -v ~/dotfiles:/work:Z -w /work/claude/workflow -e HOME=/tmp localhost/dotfiles-workflow-test:1 bash tests/unit/test_a2a_migrate_yp.sh`
  - expected: exit 0, stderr contains FALLBACK FB-001

**Isolation**

- runtime: podman
- image: `docker.io/library/debian@sha256:3783cc01769c7b2b1b83a5c5ad96c815348e28ed7da68e2e3687004faa906251` (debian:bookworm-slim, the FROM of claude/workflow/tests/container/Containerfile, built as localhost/dotfiles-workflow-test:1 by make -C ~/dotfiles/claude/workflow image)

**Out of scope - CI covers**

- make -C claude/workflow test in CI

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
