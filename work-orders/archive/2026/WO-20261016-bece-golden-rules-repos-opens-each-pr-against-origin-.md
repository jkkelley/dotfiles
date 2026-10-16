---
{
  "id": "WO-20261016-bece",
  "slug": "golden-rules-repos-opens-each-pr-against-origin-",
  "title": "golden-rules repos opens each PR against origin, never the fork parent",
  "type": "bug",
  "status": "done",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T05:06:54+00:00",
  "parent": "WO-20261016-949a",
  "branch": "feat/golden-rules-repos-opens-each-pr-against-origin-",
  "pr": 165,
  "closed": "2026-10-16",
  "approval": {
    "via": "override",
    "reason": "owner: i approved of everything (brief BR-20261016-spec-check)",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [],
  "blocks": []
}
---

# WO-20261016-bece - golden-rules repos opens each PR against origin, never the fork parent

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

make golden-rules-repos reported firstmate FAIL pr create: gh resolved the repo to the third-party upstream kunchenguid/firstmate.

## Scope

**In**

- files: scripts/golden-rules.sh (one_repo, PR lines)
- commands: make golden-rules-repos PROJECTS=<dir with only firstmate>
- docs: ~/AGENTS.md golden rules section

**Out - non-goals**

- the pre-existing shellcheck warnings in scripts/golden-rules.sh

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [x] `AC-H1` *(human)* firstmate row is PR with a jkkelley/firstmate URL
  - observed `2026-10-16` firstmate PR https://github.com/jkkelley/firstmate/pull/6: /home/luna/.local/state/zenith/log/2026/10/20261016-050654-golden-rules-pr-origin.txt
- [x] `AC-H2` *(human)* evidence: repro command and output written by claude/tools/artifact/artifact.sh new --key log to the artifact store
  - observed `2026-10-16` evidence: /home/luna/.local/state/zenith/log/2026/10/20261016-050654-golden-rules-pr-origin.txt

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
