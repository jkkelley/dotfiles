---
{
  "id": "WO-20260830-eb89",
  "slug": "skill-sync-fills-the-claude-md-skills-table-betw",
  "title": "skill-sync fills the CLAUDE.md skills table between the markers",
  "type": "feature",
  "status": "done",
  "priority": "p2",
  "created": "2026-08-30",
  "updated": "2026-08-31",
  "created_at": "2026-08-30T10:28:11-05:00",
  "parent": "WO-20260824-00d5",
  "branch": "feat/skill-sync-fills-the-claude-md-skills-table-betw",
  "pr": 92,
  "closed": "2026-08-31",
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


- [x] `AC-H1` *(human)* a project scaffolded from the template and synced against a manifest of N skills carries exactly those N names between the markers, and nothing else
  - observed `2026-08-31` MET. Section 18 of claude/tools/testing/run-tests.sh copies project-scaffold's real CLAUDE.md.tmpl verbatim into the project, syncs a manifest of two skills, and asserts the block holds exactly '- container-sandbox' and '- work-order' with no other non-blank line, that both markers survive, and that every byte outside the block is the template's. A second case syncs a manifest naming only cartography and gets '- cartography' and '- work-order', so the list is what was installed rather than what was declared. 406 assertions green via bump-gate.sh run-suite claude/tools.
- [x] `AC-H2` *(human)* a second sync with an unchanged manifest leaves CLAUDE.md byte-identical, so the write is idempotent and never churns a diff
  - observed `2026-08-31` MET. A second sync against an unchanged manifest leaves CLAUDE.md byte-identical by sha256, and does not rewrite it at all - the mtime is aged an hour first, since two syncs a second apart carry the same mtime either way. The comparison was then made to fail on purpose: dropping a skill from the manifest changes the hash and removes the name. Removing the unchanged-file guard from fill_skills_block turns both assertions red, which is how they were proved to bite.
- [x] `AC-H3` *(human)* a CLAUDE.md with no marker pair is byte-identical after a sync that installed skills, and the sync reports success
  - observed `2026-08-31` MET. Four shapes - no markers, a begin with no end, a reworded pair, an end before a begin - each byte-identical after a sync that installed the skills, each printing '1 skills in place' rather than a failure, each saying nothing about a file it did not write. A project with no CLAUDE.md syncs normally and has none created. Loosening the marker match to a substring turns the reworded case red, so the byte-for-byte match is what is being asserted.
- [x] `AC-H4` *(human)* no version string appears anywhere between the markers, asserted on the data with comments stripped first
  - observed `2026-08-31` MET. Asserted on the block with HTML comments stripped, again on the raw block including them, and on the absence of the word 'version' - while the registry fixture is asserted to have a version for what was installed, so the absence means something. The same assertion returns non-zero on a block with '- work-order 1.2.3' planted in it, and emitting '- name 1.2.3' from the writer turns six assertions red.

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

- `2026-08-31` Found while writing this ticket's hydration entry and fixed on the same pull request, on the user's instruction of 2026-08-31, rather than deferred to a ticket. workflows/close-out-procedure.md lines 20 and 21 still told a contributor to run skill-version.sh bump <skill> --patch on the feature branch and then to expect plain verify at rc 0. Both describe the pre-Rule-16 world. A branch never allocates a version now, and verify --structure is the check that refuses one; plain verify is EXPECTED to be red on any branch that touched a skill, because the branch correctly moved a skill's content hash while correctly leaving registry.json alone, so must be rc 0 sends a reader chasing the correct state as though it were a failure. The two lines now read skill-version.sh verify --structure, and the Bump: <skill>=major|minor|patch trailer in the last paragraph of the PR body with main allocating. Nothing else in that document is stale - the ordering, the one-PR rule, the no-merge_sha argument and the cleanup semantics are all current. Why it drifted: WO-20260824-8cd1 - Rewrite root CLAUDE.md for merge-time allocation and the named main exception moved allocation to merge time and rewrote root CLAUDE.md, but the workflow document was not in its scope, and root CLAUDE.md:248 points at that document as the procedure in full - so the two files have contradicted each other since, with the pointer aimed at the wrong one. Bumped with tools/workflow-version.sh bump close-out-procedure --patch, 1.0.0 -> 1.0.1: patch and not major because the procedure itself never changed, the document misdescribed it, and the marker versions the procedure rather than the prose. Note that nothing in CI would have caught this and nothing does now: bump-gate.sh detect only watches claude/skills/, claude/tools/ and the gate itself, so a change under workflows/ runs no suite at all. tools/testing/run-tests.sh is the suite that covers workflow-version.sh and it is run by hand, in a container.

## Outcome

_Written by `work-order done`. Empty until then._
