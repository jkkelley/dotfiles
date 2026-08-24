---
{
  "id": "WO-20260824-b21b",
  "slug": "claude-md-tmpl-replace-the-session-start-prose-a",
  "title": "CLAUDE.md.tmpl: replace the session-start prose, add the skills markers, the treehouse policy and the documentation-lifetime rule",
  "type": "chore",
  "status": "draft",
  "priority": "p2",
  "created": "2026-08-24",
  "updated": "2026-08-24",
  "created_at": "2026-08-24T13:19:12-05:00",
  "parent": "WO-20260824-00d5",
  "branch": null,
  "pr": null,
  "merge_sha": null,
  "closed": null,
  "approval": null,
  "evidence": null,
  "surfaces": [],
  "depends_on": [
    "WO-20260824-9712"
  ],
  "blocks": [
    "WO-20260824-238b"
  ]
}
---

# WO-20260824-b21b - CLAUDE.md.tmpl: replace the session-start prose, add the skills markers, the treehouse policy and the documentation-lifetime rule

## Problem

The template carries roughly 68 lines of session-start prose that this design deletes outright. It also has nowhere for the generated skills table to land, says nothing about where a workspace comes from, and leaves the conflict between local-k8s-docs and living-docs over who writes into docs/sops/ for each project to rediscover.

## Scope

**In**

- replacing CLAUDE.md.tmpl lines 269 to 336 with the short block from the design doc
- skills:begin and skills:end markers, written by the sync and not by scaffold.sh
- a treehouse policy section naming the user-level pool per decision 19 and pointing at treehouse status
- the documentation-lifetime rule that arbitrates docs/sops/

**Out - non-goals**

- versions in the generated table - names only, because a hand-maintained version table is wrong within a week

## Acceptance criteria


- [ ] `AC-H1` *(human)* the template names exactly one destination for a document and one source for a workspace
- [ ] `AC-H2` *(human)* the generated table sits between markers that the sync writes, and scaffold.sh writes no table

## Test plan

_none recorded - Rule 14 says this runs in a container_

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

- `2026-08-24` Poker 2026-08-24: 5 points. Sized above the plan's small and kept out of the bundle. Prose, four distinct edits, and it arbitrates a real conflict over docs/sops/.

## Outcome

_Written by `work-order close`. Empty until then._
