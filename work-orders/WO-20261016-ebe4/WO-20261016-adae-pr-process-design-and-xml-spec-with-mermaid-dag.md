---
{
  "id": "WO-20261016-adae",
  "slug": "pr-process-design-and-xml-spec-with-mermaid-dag",
  "title": "PR process design and XML spec with mermaid DAG",
  "type": "chore",
  "status": "in-progress",
  "priority": "p2",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T05:17:27+00:00",
  "parent": "WO-20261016-ebe4",
  "branch": "feat/pr-process-design-and-xml-spec-with-mermaid-dag",
  "pr": null,
  "closed": null,
  "approval": {
    "via": "override",
    "reason": "Claude seat: Lavish is prohibited for Claude runtimes (~/.claude/CLAUDE.md owner interaction surface); brief BR-20261016-merge-port v2 from the architect is the approval",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [],
  "blocks": []
}
---

# WO-20261016-adae - PR process design and XML spec with mermaid DAG

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

no design maps coq's PR process to a generic dotfiles flow with no review gate, smart CI and merge-on-green

## Scope

**In**

- claude/workflow/docs/pr-process/pr-process.md
- claude/workflow/docs/pr-process/pr-process.spec.xml

**Out - non-goals**

- any build code

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [ ] `AC-H1` *(human)* spec-check passes on pr-process.spec.xml
- [ ] `AC-H2` *(human)* every coq step maps to a ported file in section 7
- [ ] `AC-H3` *(human)* median step times taken from coq records

## Test plan

```sh
make spec-check FILES=claude/workflow/docs/pr-process/pr-process.spec.xml; bash scripts/md-contents.sh check claude/workflow/docs/pr-process/pr-process.md
```

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
