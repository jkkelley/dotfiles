---
{
  "id": "WO-20261016-83fb",
  "slug": "pr-flow-consumer-sweep-config-make-targets-and-w",
  "title": "pr-flow consumer, sweep, config, Make targets and worker playbook (T6)",
  "type": "feature",
  "status": "done",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T05:39:11+00:00",
  "parent": "WO-20261016-ebe4",
  "branch": "feat/pr-flow-consumer-sweep-config-make-targets-and-w",
  "pr": 191,
  "closed": "2026-10-16",
  "approval": {
    "via": "override",
    "reason": "Claude seat; design PR 169 merged under ORD-0550 is the approval",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [
    "WO-20261016-a29e",
    "WO-20261016-77bc"
  ],
  "blocks": [
    "WO-20261016-17dc"
  ]
}
---

# WO-20261016-83fb - pr-flow consumer, sweep, config, Make targets and worker playbook (T6)

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

Build ticket from claude/workflow/docs/pr-process/pr-process.md section 13; files: claude/workflow/pr-flow/bin/pr-flow-consume.sh claude/workflow/pr-flow/config/pr-flow.json claude/workflow/pr-flow/pr-flow.mk claude/workflow/pr-flow/playbooks/worker.md

## Scope

**In**

- claude/workflow/pr-flow/bin/pr-flow-consume.sh claude/workflow/pr-flow/config/pr-flow.json claude/workflow/pr-flow/pr-flow.mk claude/workflow/pr-flow/playbooks/worker.md

**Out - non-goals**

- any file not listed in Scope
- a review gate or gh pr merge --auto

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [x] `AC-H1` *(human)* the named test cases pass in podman
  - observed `2026-10-16` make -C claude/workflow pr-flow-test: 7 case files ok (consume 10/10); live read-only sweep of jkkelley/dotfiles posted 27 records to a stub in 26 s
- [x] `AC-H2` *(human)* files touched equal the Scope list
  - observed `2026-10-16` files: pr-flow-consume.sh, config/pr-flow.json, pr-flow.mk, playbooks/worker.md, plus regen-conflicts.sh, pr-flow-config.sh, pr-flow-install.sh, tests/consume.test.sh, Makefile include, monitors.json entry

## Test plan

```sh
make -C claude/workflow pr-flow-test CASES=consume
```

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
