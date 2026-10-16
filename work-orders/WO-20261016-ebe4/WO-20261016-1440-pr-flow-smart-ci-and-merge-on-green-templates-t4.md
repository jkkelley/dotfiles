---
{
  "id": "WO-20261016-1440",
  "slug": "pr-flow-smart-ci-and-merge-on-green-templates-t4",
  "title": "pr-flow smart CI and merge-on-green templates (T4)",
  "type": "feature",
  "status": "ready",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T05:39:01+00:00",
  "parent": "WO-20261016-ebe4",
  "branch": null,
  "pr": null,
  "closed": null,
  "approval": {
    "via": "override",
    "reason": "Claude seat; design PR 169 merged under ORD-0550 is the approval",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [],
  "blocks": [
    "WO-20261016-2447"
  ]
}
---

# WO-20261016-1440 - pr-flow smart CI and merge-on-green templates (T4)

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

Build ticket from claude/workflow/docs/pr-process/pr-process.md section 13; files: claude/workflow/pr-flow/templates/ci.yml claude/workflow/pr-flow/templates/merge-on-green.yml claude/workflow/pr-flow/bin/pr-flow-ci-render.sh claude/workflow/pr-flow/tests/ci-template.test.sh

## Scope

**In**

- claude/workflow/pr-flow/templates/ci.yml claude/workflow/pr-flow/templates/merge-on-green.yml claude/workflow/pr-flow/bin/pr-flow-ci-render.sh claude/workflow/pr-flow/tests/ci-template.test.sh

**Out - non-goals**

- any file not listed in Scope
- a review gate or gh pr merge --auto

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [ ] `AC-H1` *(human)* the named test cases pass in podman
- [ ] `AC-H2` *(human)* files touched equal the Scope list

## Test plan

```sh
make -C claude/workflow pr-flow-test CASES=ci-template
```

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
