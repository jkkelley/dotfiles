---
{
  "id": "WO-20260824-79b6",
  "slug": "invert-the-notice-assertion-verify-structure-now",
  "title": "Invert the notice assertion: verify --structure now fails on a notice that is present",
  "type": "feature",
  "status": "done",
  "priority": "p2",
  "created": "2026-08-24",
  "updated": "2026-08-31",
  "created_at": "2026-08-24T13:19:13-05:00",
  "parent": "WO-20260824-00d5",
  "branch": "feat/invert-the-notice-assertion-verify-structure-now",
  "pr": 90,
  "merge_sha": null,
  "closed": "2026-08-31",
  "approval": {
    "via": "override",
    "reason": "Reviewed and approved on PR #55 on GitHub, which is where the whole cut was read as one diff. Lavish was offered and declined in favour of the PR.",
    "at": "2026-08-24"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [
    "WO-20260824-d058"
  ],
  "blocks": [
    "WO-20260824-238b"
  ]
}
---

# WO-20260824-79b6 - Invert the notice assertion: verify --structure now fails on a notice that is present

## Problem

Between the notice check being deleted and this ticket, nothing stops someone pasting the notice back into a SKILL.md - and the obvious reaction to seeing it missing is to put it back. A committed notice plus a rendered one shows twice in the installed copy. This cannot land before every file is clean, because the assertion would fail on the repository's own contents.

## Scope

**In**

- the assertion inverting: a notice present in an upstream SKILL.md is now a failure
- a failure message that says why, because the obvious reaction is to paste it back

**Out - non-goals**

- anything about a rendered notice in an installed copy, which is expected and correct

## Acceptance criteria


- [x] `AC-H1` *(human)* pasting the notice into any SKILL.md fails the PR gate
  - observed `2026-08-31` Proved on a clone of the real 43-skill tree at commit 9c95dc4, in podman (bitnami/git pinned by digest, /repo mounted ro, --network=none): verify --structure --base origin/main exits 0 on the tree as it stands, exits 1 with the rendered notice pasted into claude/skills/container-sandbox/SKILL.md and prints 'read-only notice container-sandbox', and exits 0 again once it is reverted. Enumerated in the suite too - both spellings of the notice, a registered skill and a brand new one, each made to fail before being restored. 165 PASS / 0 FAIL via bump-gate.sh run-suite.
- [x] `AC-H2` *(human)* the failure message explains that the notice is rendered at install and must not be committed
  - observed `2026-08-31` The refusal prints: 'The read-only notice is rendered at install and must not be committed. skill-sync.sh inserts it into each installed copy from claude/tools/partials/read-only-notice.md.tmpl, which is the one place it is held. An upstream SKILL.md carries none of its own, so a committed notice is not a missing one restored - it is a second copy, and every project that syncs the skill shows the notice twice.' It closes with 'delete the notice block from the SKILL.md named above'. Each of those four halves is a separate assertion in the suite rather than the exit code standing in for the message.

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

- `2026-08-31` Retro. The two lines the ticket estimated were two lines, and the cost was everywhere else. The fixtures carried the notice, which was correct while a notice was the normal state of an upstream SKILL.md and was wrong the moment the gate existed; left alone the suite would have gone green on the gate being broken. Two design points earned their keep. Keying on the opener alone rather than any fuller line, because two spellings of the notice exist and they share exactly one line - an assertion against the deleted spelling would wave the rendered one through. And scanning the whole tree rather than the branch diff, because the property is that NO upstream SKILL.md carries the notice, and a diff-scoped check lets one that arrived by any other route sit green forever. The trap worth remembering: a gate that greps every SKILL.md for a string cannot quote that string in its own SKILL.md, so the documentation describes the opener instead of reproducing it and says why.
- `2026-08-24` Poker 2026-08-24: 2 points. One inverted assertion and a message.

## Outcome

_Written by `work-order close`. Empty until then._
