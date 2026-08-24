---
{
  "id": "WO-20260824-5b89",
  "slug": "skill-sync-sh-part-one-resolution-and-the-tools-",
  "title": "skill-sync.sh part one: resolution, and the tools test tree it is proved in",
  "type": "feature",
  "status": "draft",
  "priority": "p1",
  "created": "2026-08-24",
  "updated": "2026-08-24",
  "created_at": "2026-08-24T13:19:07-05:00",
  "parent": "WO-20260824-f1a5",
  "branch": null,
  "pr": null,
  "merge_sha": null,
  "closed": null,
  "approval": null,
  "evidence": null,
  "surfaces": [],
  "depends_on": [
    "WO-20260824-de9e",
    "WO-20260824-2136"
  ],
  "blocks": [
    "WO-20260824-efb0"
  ]
}
---

# WO-20260824-5b89 - skill-sync.sh part one: resolution, and the tools test tree it is proved in

## Problem

The sync has to decide what should be installed before it touches anything: read the manifest, fetch the registry, resolve requires, read the receipt of what it previously owned, and produce the owned set. That decision is a pure function of its inputs and is the half that can be tested without anything destructive happening. claude/tools/ has no test suite at all today, so this ticket stands one up.

## Scope

**In**

- --boot: no manifest here, or a stamp under 15 minutes old, exits 0 and prints nothing
- a minimal hand-rolled manifest parse, because no TOML parser exists on Git Bash
- registry fetch with three attempts, then a loud two-line failure and exit 0
- resolving requires into the owned set, and reading the previous receipt
- claude/tools/testing/run-tests.sh and its Containerfile, on the existing pinned debian digest

**Out - non-goals**

- writing anything into .claude/skills/, which is part two
- the self-update path, which is part two

## Acceptance criteria


- [ ] `AC-H1` *(human)* given a manifest, a registry fixture and a receipt fixture, the resolved owned set is correct including transitive requires
- [ ] `AC-H2` *(human)* --boot with no manifest present exits 0 and prints nothing at all
- [ ] `AC-H3` *(human)* a registry that is unreachable three times produces the two-line failure and still exits 0

## Test plan

```sh
bash claude/tools/testing/run-tests.sh in Podman per Rule 14, on the digest-pinned base already used by the skill suites
```

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

- `2026-08-24` Poker 2026-08-24: 5 points. Was half of a 13. Includes standing up claude/tools/testing/, which goes here so part two is never the ticket where part one first gets tested.

## Outcome

_Written by `work-order close`. Empty until then._
