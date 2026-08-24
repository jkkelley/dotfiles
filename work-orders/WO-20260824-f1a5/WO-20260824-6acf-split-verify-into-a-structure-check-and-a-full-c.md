---
{
  "id": "WO-20260824-6acf",
  "slug": "split-verify-into-a-structure-check-and-a-full-c",
  "title": "Split verify into a structure check and a full check, and delete the notice assertion",
  "type": "feature",
  "status": "draft",
  "priority": "p1",
  "created": "2026-08-24",
  "updated": "2026-08-24",
  "created_at": "2026-08-24T13:19:06-05:00",
  "parent": "WO-20260824-f1a5",
  "branch": null,
  "pr": null,
  "merge_sha": null,
  "closed": null,
  "approval": null,
  "evidence": null,
  "surfaces": [],
  "depends_on": [],
  "blocks": [
    "WO-20260824-2ad1"
  ]
}
---

# WO-20260824-6acf - Split verify into a structure check and a full check, and delete the notice assertion

## Problem

Under merge-time allocation every skill PR legitimately edits a skill and leaves the registry alone, which today's verify calls drifted. The PR gate needs a check that passes in exactly that state, while the publisher still needs the strict one. The existing notice assertion at skill-version.sh:195 also has to go before the notice can leave any file.

## Scope

**In**

- verify --structure: every skill versioned, no hand-edited version: or registry.json in the diff
- plain verify keeping its current meaning, structure plus registry match
- deleting the notice check at skill-version.sh:195
- extending the skill-versioning test suite to cover both forms

**Out - non-goals**

- asserting the notice is absent, which cannot land until all 42 files are clean

## Acceptance criteria


- [ ] `AC-H1` *(human)* on a branch with an edited skill and an untouched registry, verify --structure exits 0 and plain verify exits non-zero
- [ ] `AC-H2` *(human)* the suite covers both forms and passes in Podman

## Test plan

```sh
bash claude/skills/skill-versioning/testing/run-tests.sh in Podman per Rule 14
```

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

- `2026-08-24` Poker 2026-08-24: 3 points. Bounded change to one script plus its existing suite.

## Outcome

_Written by `work-order close`. Empty until then._
