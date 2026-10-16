---
{
  "id": "WO-20261016-04d3",
  "slug": "make-spec-check-gates-xml-specs-in-the-fast-pr-c",
  "title": "make spec-check gates XML specs in the fast PR check",
  "type": "feature",
  "status": "in-progress",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T04:42:29+00:00",
  "parent": "WO-20261016-949a",
  "branch": "feat/make-spec-check-gates-xml-specs-in-the-fast-pr-c",
  "pr": null,
  "closed": null,
  "approval": {
    "via": "override",
    "reason": "owner: i approved of everything (brief BR-20261016-spec-check)",
    "at": "2026-10-16"
  },
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

- files: scripts/spec-check.sh (new), Makefile (spec-check, spec-check-test block), .github/workflows/skill-pr-gate.yml (one step in md-contents job)
- commands: make spec-check FILES=<spec.xml>; make spec-check-test; make rolodex-check
- docs: ~/AGENTS.md Design principles 101 item 28; scripts/md-contents.sh (scope rule); claude/workflow/inbox-sweep/bin/spec-lint.sh (line count)

**Out - non-goals**

- migrating existing docs/design/*.spec.xml to a <contents> element
- changing claude/workflow/inbox-sweep/bin/spec-lint.sh

## Degrees of freedom

- [free] parser: xmllint --noout when present, python3 xml.etree otherwise

## Acceptance criteria

- [ ] `AC-H1` *(human)* make spec-check FILES=<1001-line spec> exits non-zero with FAIL <file>: 1001 lines, limit 1000
- [ ] `AC-H2` *(human)* make spec-check with no spec changed prints spec-check: nothing in scope and exits 0
- [ ] `AC-H3` *(human)* md-contents CI job runs make spec-check with BASE = PR base sha
- [ ] `AC-H4` *(human)* evidence: repro command and output written by claude/tools/artifact/artifact.sh new --key log to the artifact store, path in the PR body

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
