---
{
  "id": "WO-20260824-de9e",
  "slug": "registry-schema-2-with-type-derived-from-the-tre",
  "title": "Registry schema 2, with type derived from the tree and requires read from frontmatter",
  "type": "feature",
  "status": "ready",
  "priority": "p1",
  "created": "2026-08-24",
  "updated": "2026-08-24",
  "created_at": "2026-08-24T13:19:06-05:00",
  "parent": "WO-20260824-f1a5",
  "branch": null,
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


- [ ] `AC-H1` *(human)* render_registry reproduces registry.json byte for byte
- [ ] `AC-H2` *(human)* both work-order edges appear in the rendered registry and no other entry has one
- [ ] `AC-H3` *(human)* a deliberately mistyped requires: name fails verify

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

- `2026-08-24` Poker 2026-08-24: 5 points. More surface than the verify split: rendering, awk-read frontmatter, hash block, and a new distinct failure mode.

## Outcome

_Written by `work-order close`. Empty until then._
