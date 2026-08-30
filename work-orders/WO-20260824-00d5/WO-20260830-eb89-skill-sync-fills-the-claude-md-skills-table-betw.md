---
{
  "id": "WO-20260830-eb89",
  "slug": "skill-sync-fills-the-claude-md-skills-table-betw",
  "title": "skill-sync fills the CLAUDE.md skills table between the markers",
  "type": "feature",
  "status": "ready",
  "priority": "p2",
  "created": "2026-08-30",
  "updated": "2026-08-30",
  "created_at": "2026-08-30T10:28:11-05:00",
  "parent": "WO-20260824-00d5",
  "branch": null,
  "pr": null,
  "closed": null,
  "approval": {
    "via": "override",
    "reason": "Approved in conversation on 2026-08-30 by the user, in the session that surfaced it. The gap was found while shipping WO-20260824-b21b - CLAUDE.md.tmpl: replace the session-start prose, add the skills markers, the treehouse policy and the documentation-lifetime rule, the user was asked whether to widen b21b or cut a ticket, and chose the ticket. Lavish was not used because the whole content of the decision is the question that was asked and answered.",
    "at": "2026-08-30"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [
    "WO-20260824-238b"
  ],
  "blocks": []
}
---

# WO-20260830-eb89 - skill-sync fills the CLAUDE.md skills table between the markers

## Problem

WO-20260824-b21b put skills:begin and skills:end markers into project-scaffold's CLAUDE.md template and named skill-sync as their writer, per the design doc's body and plan E2.4. Nothing writes between them. A project scaffolded from that template therefore carries an empty marker pair forever, and the only record of what the project actually holds is the receipt under .claude/cache/, which no agent reads. Verified 2026-08-30 across every open and archived ticket: this is covered nowhere. WO-20260824-5b89 and WO-20260824-efb0 both name writing outside .claude/skills/ as an explicit non-goal, so the gap was never anyone's, and it was surfaced by b21b rather than planned.

## Scope

**In**

- after a successful apply, skill-sync rewrites the block between the two markers in the project's CLAUDE.md with the names it installed
- names only, never versions - a version table is wrong within a week and a stale one is worse than none because agents believe it
- a CLAUDE.md with no marker pair is left byte-identical and the sync still succeeds silently, because a project may legitimately not carry the block
- cases in claude/tools/testing/run-tests.sh that feed project-scaffold's real CLAUDE.md.tmpl to the writer, per the existing 'the manifest project-scaffold ships' pattern - the two files live in different skills and drift between them is silent

**Out - non-goals**

- scaffold.sh writing the table, which the design and b21b both refuse
- any version string between the markers
- a marker pair in any file other than the project's CLAUDE.md
- changing the marker text itself, which b21b already shipped and skill-sync must match byte for byte

## Acceptance criteria


- [ ] `AC-H1` *(human)* a project scaffolded from the template and synced against a manifest of N skills carries exactly those N names between the markers, and nothing else
- [ ] `AC-H2` *(human)* a second sync with an unchanged manifest leaves CLAUDE.md byte-identical, so the write is idempotent and never churns a diff
- [ ] `AC-H3` *(human)* a CLAUDE.md with no marker pair is byte-identical after a sync that installed skills, and the sync reports success
- [ ] `AC-H4` *(human)* no version string appears anywhere between the markers, asserted on the data with comments stripped first

## Test plan

```sh
bash .github/scripts/bump-gate.sh run-suite claude/tools
```

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
