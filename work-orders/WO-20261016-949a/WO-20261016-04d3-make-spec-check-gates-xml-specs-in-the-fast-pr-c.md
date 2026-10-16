---
{
  "id": "WO-20261016-04d3",
  "slug": "make-spec-check-gates-xml-specs-in-the-fast-pr-c",
  "title": "make spec-check gates XML specs in the fast PR check",
  "type": "feature",
  "status": "draft",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T04:42:29+00:00",
  "parent": "WO-20261016-949a",
  "branch": null,
  "pr": null,
  "closed": null,
  "approval": null,
  "evidence": null,
  "surfaces": [],
  "depends_on": [
    "WO-20261016-87a3"
  ],
  "blocks": [
    "WO-20261016-bdcb"
  ]
}
---

# WO-20261016-04d3 - make spec-check gates XML specs in the fast PR check

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

Nothing enforces item 28 on XML specs outside inbox-sweep, and nothing checks for a contents element.

## Scope

**In**

- scripts/md-contents.sh check pattern; claude/workflow/inbox-sweep/bin/spec-lint.sh line counting

**Out - non-goals**

- scripts/spec-check.sh
- Makefile spec-check target, FILES= or changed *.xml vs BASE
- skill-pr-gate.yml md-contents job step
- scripts/tests/test_spec_check.sh

## Degrees of freedom

- [free] parser: xmllint --noout when present, python3 xml.etree otherwise

## Acceptance criteria

- [ ] `AC-H1` *(human)* spec-check fails a 1001-line spec, a malformed spec, a spec without a contents element, passes a good one (exit 3 / 0)
- [ ] `AC-H2` *(human)* two runs give the same result and git status is clean
- [ ] `AC-H3` *(human)* bad usage exits 2

## Test plan

_none recorded - Rule 14 says this runs in a container_

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
