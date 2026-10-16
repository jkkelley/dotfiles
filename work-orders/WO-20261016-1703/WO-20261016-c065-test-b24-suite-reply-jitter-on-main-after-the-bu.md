---
{
  "id": "WO-20261016-c065",
  "slug": "test-b24-suite-reply-jitter-on-main-after-the-bu",
  "title": "Test B24 - suite reply-jitter on main after the build merges",
  "type": "test",
  "status": "draft",
  "priority": "p2",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T07:56:14+00:00",
  "parent": "WO-20261016-1703",
  "branch": null,
  "pr": null,
  "closed": null,
  "approval": null,
  "evidence": null,
  "surfaces": [],
  "depends_on": [
    "WO-20261016-667d"
  ],
  "blocks": [],
  "labels": [
    "line:inbox-triage"
  ]
}
---

# WO-20261016-c065 - Test B24 - suite reply-jitter on main after the build merges

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

B24 needs its own scripted test run on main (item 30).

## Scope

**In**

_none_

**Out - non-goals**

- end-to-end sends - never from a test (item 35)

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [ ] `AC-H1` *(human)* every case in the plan passes

## Test plan


_Test plan from claude/workflow/templates/test-plan.md, shaped by claude/workflow/schemas/test-plan.schema.json. The tester runs exactly these cases and nothing else._

**Scope under test**

reply-send.sh and lead-followup.sh hand every approved send to the shared ypli jitter scheduler

**Cases**

- `TP-1`
  - intent: a batch of approved replies sent at once is a burst, which the owner's post timing rule forbids
  - command: `podman run --rm --pull=never --network=none --userns=keep-id -v "$PWD:/work:Z" -w /work -e HOME=/tmp localhost/dotfiles-workflow-test:1 bash claude/workflow/inbox-sweep/tests/run.sh --suite reply-jitter`
  - expected: exit 0; the stub ypli records one jitter plan call per batch and the send times it returned, none earlier than planned

- `TP-2`
  - intent: a missing or failing scheduler must stop the send, never fall back to sending now
  - command: `podman run --rm --pull=never --network=none --userns=keep-id -v "$PWD:/work:Z" -w /work -e HOME=/tmp localhost/dotfiles-workflow-test:1 bash claude/workflow/inbox-sweep/tests/run.sh --suite reply-jitter`
  - expected: exit 0; with the stub ypli exiting non-zero the ledger gets RP-SCHEDULE-FAILED and no send seat starts

**Isolation**

- runtime: podman
- image: `localhost/dotfiles-workflow-test:1`
- build: `make -C claude/workflow image`
- containerfile: `claude/workflow/tests/container/Containerfile`

**Out of scope - CI covers**

- every other inbox-sweep suite and lint, run by the claude/workflow CI job

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

- `2026-10-16` infra-design8 RR-orch-18: test plan amended from localhost digest 0a6832bb to the local-image form (tag, build make -C claude/workflow image, containerfile, --pull=never); start accepts it once WO-20261016-86b9 merges

## Outcome

_Written by `work-order done`. Empty until then._
