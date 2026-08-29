---
{
  "id": "WO-20260829-5ad4",
  "slug": "verify-s-drift-report-walks-the-registry-s-tools",
  "title": "verify's drift report walks the registry's tools block and names tools as missing skills",
  "type": "bug",
  "status": "done",
  "priority": "p2",
  "created": "2026-08-29",
  "updated": "2026-08-29",
  "created_at": "2026-08-29T13:23:15-05:00",
  "parent": null,
  "branch": "feat/verify-s-drift-report-walks-the-registry-s-tools",
  "pr": 80,
  "closed": "2026-08-29",
  "approval": {
    "via": "override",
    "reason": "Approved in session on 2026-08-29. The user read the defect and its fix as a five-step plan in the session reply, asked for it to be completed, and the ticket is that plan written down verbatim. Lavish was not used.",
    "at": "2026-08-29"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [],
  "blocks": []
}
---

# WO-20260829-5ad4 - verify's drift report walks the registry's tools block and names tools as missing skills

## Problem

cmd_verify's two reporting loops in claude/skills/skill-versioning/scripts/skill-version.sh each walk every line of their input that begins with four spaces and a quote. render_tools emits the tools block at that same indent, so both loops read tool entries as skill entries. The visible symptom is at skill-version.sh:541 - a failing plain verify prints 'stale entry skill-sync (no such skill)' and the same for read-only-notice, because claude/skills/skill-sync/ is not a directory and never will be. The latent one is at skill-version.sh:529 - change a tool file and the drift loop prints 'drifted skill-sync' and then the trailer tells the reader to run 'skill-version.sh bump skill-sync --patch', which dies with 'no such skill'. Neither is a gate failure: both only appear in output that has already failed for another reason. That is precisely when they do damage, because they name the wrong cause at the moment someone is debugging a real drift. It arrived the moment claude/tools/ stopped being empty and has been on no ticket since. bump-lib.sh's registry_version already solves the same problem correctly by scoping its lookup to the skills block with sed.

## Scope

**In**

- both reporting loops scoped to the registry's skills block, using the same sed range idiom as bump-lib.sh registry_version
- the grep -m1 lookup at skill-version.sh:532 scoped the same way, so a tool can never satisfy a skill's name
- cases in claude/skills/skill-versioning/testing/run-tests.sh section 6b, where a fixture tool already exists

**Out - non-goals**

- changing what verify considers a failure - this is message quality only, and every exit code stays where it is
- giving tools their own drift report or bump path, which is a feature and not this bug
- touching render_tools or the registry format - the indent is fine, the readers are wrong

## Acceptance criteria


- [x] `AC-H1` *(human)* with a populated tools block and a genuine skill drift, a failing plain verify names no tool in a stale entry line
  - observed `2026-08-29` Observed 2026-08-29 twice: on the fixture and on the real tree. Fixture, in the skill-versioning suite section 'the drift report reads the skills block only', run via bump-gate.sh run-suite in Podman on the digest-pinned bitnami/git base with the source mounted read-only - a registry carrying a populated tools block (read-only-notice at 2.1.0) plus a genuine drift in alpha: verify exits 1, 'drifted alpha' is still printed, and neither 'stale entry .*read-only-notice' nor the bare string read-only-notice appears anywhere in the output. Real tree, the reproduction that matters, against a clone of this branch with both real tools present in the registry (skill-sync 2.0.0 and read-only-notice 1.0.0) and skill-versioning genuinely drifted because the branch edited it. Running origin/main's copy of the script over that same tree printed three lines: 'drifted skill-versioning', 'stale entry skill-sync (no such skill)' and 'stale entry read-only-notice (no such skill)'. Running this branch's copy over the identical tree printed one: 'drifted skill-versioning'. Same tree, same failure, two false lines gone. Exit code 1 on both, which is the non-goal holding.
- [x] `AC-H2` *(human)* on that same run a genuinely stale skill entry is still named, so the fix narrows the scan rather than silencing it
  - observed `2026-08-29` Observed 2026-08-29 in the same suite section and the same container run, on the same fixture as AC-H1 and one step later. beta's directory was removed while its row stayed in the registry, which is a genuinely stale entry rather than a tool. verify printed 'stale entry beta (no such skill)' and the string read-only-notice still did not appear. This is the assertion a careless fix breaks: dropping the loop, or matching on something narrower than the skills block, would make both checks pass by reporting nothing at all. Written as a pair on purpose - the positive and the negative on one tree, in one run - because either alone is satisfiable by the wrong implementation.
- [x] `AC-H3` *(human)* a changed tool file is not reported as a drifted skill
  - observed `2026-08-29` Observed 2026-08-29 in the same container run. Fixture rebuilt clean, verify green at rc 0 with the tool in sync, then a line appended to $WORK/tools/partials/read-only-notice.md.tmpl without moving its skill-tool-version: marker. verify then exits 1 - correctly, the registry genuinely is stale because render_tools rehashes the file - and 'drifted .*read-only-notice' does not appear. The stronger assertion is asserted alongside it: no line matching '^(drifted|stale entry|not in registry)' appears at all, so no skill is falsely blamed for a tool's change either. Before the fix this case printed 'drifted read-only-notice' followed by a trailer telling the reader to run 'skill-version.sh bump read-only-notice --patch', which dies with 'no such skill' - advice that cannot be followed. THE GAP THIS LEAVES IS REAL AND IS ON A TICKET: the case now names nothing, so a reader gets only the generic trailer. Verified on the real tree, not just the fixture - a clone of main with claude/tools/skill-sync.sh edited produced the trailer and nothing else at rc 1. That is WO-20260829-f97b - verify names nothing when only a tool has drifted, cut as a draft p3 rather than folded in here, because naming a tool properly needs advice this ticket's non-goals put out of scope.

## Test plan

```sh
skill-versioning's own suite, section 6b, which already builds a fixture tool at $WORK/tools and drives a populated tools block
```

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
