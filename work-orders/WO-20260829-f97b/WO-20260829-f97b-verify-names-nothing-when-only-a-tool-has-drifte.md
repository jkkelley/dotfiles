---
{
  "id": "WO-20260829-f97b",
  "slug": "verify-names-nothing-when-only-a-tool-has-drifte",
  "title": "verify names nothing when only a tool has drifted",
  "type": "bug",
  "status": "ready",
  "priority": "p3",
  "created": "2026-08-29",
  "updated": "2026-08-29",
  "created_at": "2026-08-29T13:41:47-05:00",
  "parent": null,
  "branch": null,
  "pr": null,
  "closed": null,
  "approval": {
    "via": "override",
    "reason": "Approved by the user in session on 2026-08-29, in the reply that read the regression, the ticket and its non-goals and said 'approve f97b and fix it'. Lavish was not used.",
    "at": "2026-08-29"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [],
  "blocks": []
}
---

# WO-20260829-f97b - verify names nothing when only a tool has drifted

## Problem

WO-20260829-5ad4 - verify's drift report walks the registry's tools block and names tools as missing skills scoped cmd_verify's two reporting loops to the registry's skills block, which was correct: they were calling claude/tools/skill-sync.sh a skill that does not exist, and telling the reader to run a bump that dies. The consequence is a gap that ticket's non-goals deliberately left open. On a tree where every skill is in sync and only a tool has changed - edit claude/tools/skill-sync.sh without moving its skill-tool-version: marker - verify still fails, correctly, because render_tools rehashes the file and the registry no longer matches. But it now names nothing at all. The reader gets the generic trailer, 'registry is stale. A skill's contents changed without a version bump, or the registry was hand-edited', and no line telling them it was a tool or which one. Before the fix they at least got the right filename under the wrong label. Observed 2026-08-29 in a container against a clone of main with claude/tools/skill-sync.sh edited: whole stderr was the trailer, rc 1. claude/tools/ is a live workflow - skill-sync.sh and partials/read-only-notice.md.tmpl both ship there and both carry markers - so this is a shape someone will hit.

## Scope

**In**

- a line naming a drifted tool, with advice that can actually be followed - a tool's version is a marker in the file, not something bump touches
- a case in claude/skills/skill-versioning/testing/run-tests.sh asserting a tool-only drift names the tool

**Out - non-goals**

- changing exit codes - a tool-only drift already fails and must keep failing
- reintroducing tools into the skills loops, which is the bug WO-20260829-5ad4 fixed
- a bump subcommand for tools, unless the ticket that adds one wants it

## Acceptance criteria


- [ ] `AC-H1` *(human)* a tree whose skills are all in sync and whose tool has changed reports the tool by name
- [ ] `AC-H2` *(human)* the advice printed for that case does not tell the reader to run bump on a tool
- [ ] `AC-H3` *(human)* no skill is named on that run, and the exit code is still 1

## Test plan

```sh
skill-versioning's own suite, the section added by WO-20260829-5ad4, which already builds a fixture tool and drives a tool-only drift
```

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
