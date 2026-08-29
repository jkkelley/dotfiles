---
{
  "id": "WO-20260829-5ad4",
  "slug": "verify-s-drift-report-walks-the-registry-s-tools",
  "title": "verify's drift report walks the registry's tools block and names tools as missing skills",
  "type": "bug",
  "status": "ready",
  "priority": "p2",
  "created": "2026-08-29",
  "updated": "2026-08-29",
  "created_at": "2026-08-29T13:23:15-05:00",
  "parent": null,
  "branch": null,
  "pr": null,
  "closed": null,
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


- [ ] `AC-H1` *(human)* with a populated tools block and a genuine skill drift, a failing plain verify names no tool in a stale entry line
- [ ] `AC-H2` *(human)* on that same run a genuinely stale skill entry is still named, so the fix narrows the scan rather than silencing it
- [ ] `AC-H3` *(human)* a changed tool file is not reported as a drifted skill

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
