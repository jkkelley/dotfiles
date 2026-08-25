---
{
  "id": "WO-20260825-dac4",
  "slug": "verify-structure-refuses-a-brand-new-skill-which",
  "title": "verify --structure refuses a brand new skill, whichever way it is written",
  "type": "bug",
  "status": "ready",
  "priority": "p1",
  "created": "2026-08-25",
  "updated": "2026-08-25",
  "created_at": "2026-08-25T07:14:14-05:00",
  "parent": "WO-20260824-f1a5",
  "branch": null,
  "pr": null,
  "closed": null,
  "approval": {
    "via": "override",
    "reason": "Approved in session on 2026-08-25. The ticket was read as a diff on PR #68, which is where its scope, its dependency on WO-20260824-8cd1 and its blocks edge to WO-20260824-238b were all visible as one change. Lavish was not used.",
    "at": "2026-08-25"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [
    "WO-20260824-8cd1"
  ],
  "blocks": [
    "WO-20260824-238b"
  ]
}
---

# WO-20260825-dac4 - verify --structure refuses a brand new skill, whichever way it is written

## Problem

Under merge-time allocation a new skill's SKILL.md carries no version: line, because CI stamps it with init at 1.0.0 on main. verify --structure refuses exactly that: cmd_verify walks every skill directory and reports any without a version as unversioned, before diff_check is even reached. Write the line by hand instead and diff_check reports it as a hand-edited version:. Either way the PR gate is red, so adding a skill becomes the one change that cannot be landed through the pipeline the pipeline exists to enforce. A rename is caught by the same edge, because a renamed directory arrives as an added file whose every line - version: included - is a + in the diff. bump-gate.sh resolve already handles the case correctly on its own, reporting an unregistered skill as new at 1.0.0 per E1.8, so the refusal comes out of skill-version.sh rather than out of the gate's own logic.

## Scope

**In**

- verify --structure treats a skill absent from registry.json as new, and does not require a version: line for it
- diff_check still refuses a version: edit on a skill that is already in the registry
- a renamed skill directory reads as new rather than as a hand-edit
- cases in claude/skills/skill-versioning/testing/run-tests.sh covering all three

**Out - non-goals**

- changing plain verify, which runs on main after the publisher and must still require every skill to be versioned
- teaching bump-gate.sh anything - resolve already reports an unregistered skill as new at 1.0.0
- the publisher's init call, which is WO-20260824-360d
- relaxing the refusal for a skill that is already in the registry, which is the check's whole purpose

## Acceptance criteria


- [ ] `AC-H1` *(human)* a PR adding a brand new skill directory with no version: line is green on the gate
- [ ] `AC-H2` *(human)* a PR that hand-edits the version: of a skill already in the registry is still refused, and the message says which
- [ ] `AC-H3` *(human)* a PR that renames a skill directory is green on the gate

## Test plan

```sh
skill-versioning's own suite for the unit level, then a real PR adding a throwaway skill directory - the gate is the thing under test and it only exists on a pull request
```

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

- `2026-08-25` The blocks edge to WO-20260824-238b - Rename skill-versioning to skill-registry, the closing commit is the one that matters, and it is why this is p1 rather than a backlog item. A renamed skill directory arrives in the diff as an added file, so every one of its lines is a + - version: included - and diff_check reads that as a hand-edit. The closing commit of epic 2 cannot land until this does.
- `2026-08-25` Found while building WO-20260824-2ad1 - PR gate workflow: validate the bump intent and run the affected suites, and recorded there as a note rather than fixed, because the refusal comes out of skill-version.sh and not out of the gate. The gate calls verify --structure and inherits it, so the symptom will present as 'the gate refuses my new skill' and the cause is two functions away.

## Outcome

_Written by `work-order done`. Empty until then._
