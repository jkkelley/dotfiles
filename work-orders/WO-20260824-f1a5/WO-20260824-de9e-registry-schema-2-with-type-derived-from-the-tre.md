---
{
  "id": "WO-20260824-de9e",
  "slug": "registry-schema-2-with-type-derived-from-the-tre",
  "title": "Registry schema 2, with type derived from the tree and requires read from frontmatter",
  "type": "feature",
  "status": "in-progress",
  "priority": "p1",
  "created": "2026-08-24",
  "updated": "2026-08-24",
  "created_at": "2026-08-24T13:19:06-05:00",
  "parent": "WO-20260824-f1a5",
  "branch": "feat/registry-schema-2-with-type-derived-from-the-tre",
  "pr": null,
  "merge_sha": null,
  "closed": null,
  "approval": {
    "via": "override",
    "reason": "Reviewed and approved on PR #55 on GitHub, which is where the whole cut was read as one diff. Lavish was offered and declined in favour of the PR.",
    "at": "2026-08-24"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [],
  "blocks": [
    "WO-20260824-5b89"
  ]
}
---

# WO-20260824-de9e - Registry schema 2, with type derived from the tree and requires read from frontmatter

## Problem

The sync needs to know what an entry is, what it depends on, and which shared tools it was built with. The current registry carries none of that. Decision 21 fixed the shape: type is routing and is derived from the directory the entry was found in rather than declared, and requires is an optional comma-separated frontmatter key.

## Scope

**In**

- render_registry emitting schema 2 with per-skill type and requires
- a tools block carrying skill-sync and read-only-notice, each with a version and a hash
- requires: work-order on living-docs and cartography, and on nothing else
- verify reporting a schema mismatch as its own failure rather than as drift

**Out - non-goals**

- declaring type in frontmatter, which decision 21 rejected
- YAML list syntax for requires, which needs a parser Git Bash does not have
- soft or optional dependencies

## Acceptance criteria


- [x] `AC-H1` *(human)* render_registry reproduces registry.json byte for byte
  - observed `2026-08-24` Container, real 43-skill tree copied out of a read-only mount, bitnami/git pinned by digest, --network=none. skill-version.sh verify printed "ok - 43 skills versioned, registry in sync" at rc 0. verify is a byte-for-byte string comparison of render_registry output against the committed registry.json, so rc 0 is the reproduction.
- [x] `AC-H2` *(human)* both work-order edges appear in the rendered registry and no other entry has one
  - observed `2026-08-24` Same container run. Grepping the rendered registry for a non-empty requires returned exactly two lines - cartography 1.0.3 and living-docs 1.0.1, each carrying ["work-order"]. Count of entries with a non-empty requires: 2, against 43 entries total. The other 41 render an empty array.
- [x] `AC-H3` *(human)* a deliberately mistyped requires: name fails verify
  - observed `2026-08-24` Same container. living-docs requires rewritten to work-ordr, one character short. Plain verify printed "unresolved requires living-docs -> work-ordr (no such skill)" then "fix the requires: line, or add the skill it names" at rc 1, and did NOT emit the run-init advice that belongs to an unversioned skill. verify --structure rejected it identically at rc 1, so the typo fails at the PR gate rather than on some project first sync.

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

- `2026-08-24` Option A settled 2026-08-24 - render_tools emits an entry only for a registered tool that exists on disk, so the tools block renders empty today. That is the intended output and not a stub: render_registry stays a pure function of the tree, which is what lets verify be a byte comparison instead of a parser. claude/tools/partials/read-only-notice.md.tmpl is created by WO-20260824-2136 - Extract the read-only notice into a single rendered partial, whose AC-H2 already reads "the partial appears in the registry tools block with a version and a hash", so the empty block has an owner and is not a loose end. claude/tools/skill-sync.sh is created by WO-20260824-5b89 - skill-sync.sh part one: resolution, and the tools test tree it is proved in, which lists this ticket in its depends_on and therefore cannot come first. Both entries appear on their own as those files land; neither needs an edit to render_tools. Full context and the migration caveat are on the epic WO-20260824-f1a5 - Skills package manager: prove the path on one skill.
- `2026-08-24` Poker 2026-08-24: 5 points. More surface than the verify split: rendering, awk-read frontmatter, hash block, and a new distinct failure mode.

## Outcome

_Written by `work-order close`. Empty until then._
