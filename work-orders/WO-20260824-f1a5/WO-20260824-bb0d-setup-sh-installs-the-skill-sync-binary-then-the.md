---
{
  "id": "WO-20260824-bb0d",
  "slug": "setup-sh-installs-the-skill-sync-binary-then-the",
  "title": "setup.sh installs the skill-sync binary, then the SessionStart hook",
  "type": "feature",
  "status": "ready",
  "priority": "p1",
  "created": "2026-08-24",
  "updated": "2026-08-24",
  "created_at": "2026-08-24T13:19:08-05:00",
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
    "WO-20260824-0615",
    "WO-20260824-efb0"
  ],
  "blocks": [
    "WO-20260824-316d"
  ]
}
---

# WO-20260824-bb0d - setup.sh installs the skill-sync binary, then the SessionStart hook

## Problem

The hook fires in every project on this machine, so it cannot be installed before the binary it calls exists, and it cannot be noisy in a project with no manifest - which is almost every project here. A hook that prints something irrelevant at every session start gets deleted by whoever is annoyed by it first, and the whole system goes with it.

## Scope

**In**

- installing skill-sync to ~/.local/bin, beside the existing -axi tools
- adding the SessionStart hook to ~/.claude/settings.json with a 30 second timeout, after the binary
- the matcher form decided by the matcher spike
- idempotency: running setup.sh twice does not produce two hooks

**Out - non-goals**

- per-project hook installation - this hook is machine level

## Acceptance criteria


- [ ] `AC-H1` *(human)* a session started in a project with no .claude/skills.toml prints nothing at all
- [ ] `AC-H2` *(human)* running setup.sh twice leaves exactly one SessionStart hook in settings.json

## Test plan

```sh
a container with a fake HOME proves idempotency; the silence criterion is observed in a real session
```

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

- `2026-08-24` Poker 2026-08-24: 3 points. Two steps in a fixed order; idempotency is the only trap.

## Outcome

_Written by `work-order close`. Empty until then._
