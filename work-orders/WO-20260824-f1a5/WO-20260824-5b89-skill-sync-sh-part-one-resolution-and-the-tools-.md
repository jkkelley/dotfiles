---
{
  "id": "WO-20260824-5b89",
  "slug": "skill-sync-sh-part-one-resolution-and-the-tools-",
  "title": "skill-sync.sh part one: resolution, and the tools test tree it is proved in",
  "type": "feature",
  "status": "ready",
  "priority": "p1",
  "created": "2026-08-24",
  "updated": "2026-08-24",
  "created_at": "2026-08-24T13:19:07-05:00",
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

- `2026-08-24` Scope note from WO-20260824-7a63 - Close-out moves onto the branch: done archives, cleanup only deletes branches. That ticket created a repo-local tools/ tree at the repository root with its own suite at tools/testing/, for tooling that maintains this repository and is never vendored. It deliberately did NOT create claude/tools/testing/, which is still this ticket to stand up, so nothing here shrinks. What it does give you is a worked example of the shape: tools/testing/run-tests.sh re-execs itself into Podman on the pinned debian digest with --network=none and the repo mounted read-only, and it uses set -uo pipefail rather than -e, because over half the checks run a command expected to fail and -e ends the run on the first of them while reporting the assertion as an error.
- `2026-08-24` Poker 2026-08-24: 5 points. Was half of a 13. Includes standing up claude/tools/testing/, which goes here so part two is never the ticket where part one first gets tested.

## Outcome

_Written by `work-order close`. Empty until then._
