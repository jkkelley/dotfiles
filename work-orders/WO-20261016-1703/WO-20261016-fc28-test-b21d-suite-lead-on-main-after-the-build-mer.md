---
{
  "id": "WO-20261016-fc28",
  "slug": "test-b21d-suite-lead-on-main-after-the-build-mer",
  "title": "Test B21d - suite lead on main after the build merges",
  "type": "test",
  "status": "in-progress",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T04:46:23+00:00",
  "parent": "WO-20261016-1703",
  "branch": "feat/test-b21d-suite-lead-on-main-after-the-build-mer",
  "pr": null,
  "closed": null,
  "approval": {
    "via": "override",
    "reason": "Architect rulings R3 and R4, 2026-10-16T04:25Z, recorded in design 18 (PR 153); Claude seats never use lavish",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [
    "WO-20261016-ae19"
  ],
  "blocks": []
}
---

# WO-20261016-fc28 - Test B21d - suite lead on main after the build merges

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

The B21d build is proven only by its suite run on main, by a tester who did not write it (Design principles 101 item 30)

## Scope

**In**

_none_

**Out - non-goals**

- changing any code; a failing case is filed as a bug with its output

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [x] `AC-H1` *(human)* every case in the plan passes on main, output captured to the artifact store (item 31)
  - observed `2026-10-16` TP-1 on main 84c60d8: podman run localhost/dotfiles-workflow-test:1 bash tests/run.sh --suite lead -> output 'ok lead' / 'ran 1 suite', exit 0; single-writer case ok. Full output: /home/luna/.local/state/zenith/inbox-triage/20261015/seats/20261016-050413-t21d-lead-suite-evidence.md

## Test plan

_Test plan from claude/workflow/templates/test-plan.md, shaped by claude/workflow/schemas/test-plan.schema.json. The tester runs exactly these cases and nothing else._

**Scope under test**

lead-ledger.sh as sole writer of leads.jsonl

**Cases**

- `TP-1`
  - intent: a second writer of leads.jsonl makes its migration a multi-file change
  - command: `podman run --rm --network=none --userns=keep-id -v "$PWD:/work:ro,Z" -w /work/claude/workflow/inbox-sweep -e HOME=/tmp localhost/dotfiles-workflow-test:1 bash tests/run.sh --suite lead`
  - expected: exit 0; the output ends with `ok  lead` and `ran 1 suite`; the single-writer grep case is ok

**Isolation**

- runtime: podman
- image: `localhost/dotfiles-workflow-test@sha256:0a6832bb348572415fc3b304ed48ece90bcce4bd92b7f3f95a6ebc9d694f18f0` (localhost/dotfiles-workflow-test:1 at cut time, built from claude/workflow/tests/container/Containerfile)

**Out of scope - CI covers**

- lint and every other suite

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
