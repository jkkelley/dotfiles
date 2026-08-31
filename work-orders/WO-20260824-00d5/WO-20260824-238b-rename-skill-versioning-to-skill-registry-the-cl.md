---
{
  "id": "WO-20260824-238b",
  "slug": "rename-skill-versioning-to-skill-registry-the-cl",
  "title": "Rename skill-versioning to skill-registry, the closing commit",
  "type": "chore",
  "status": "in-progress",
  "priority": "p2",
  "created": "2026-08-24",
  "updated": "2026-08-31",
  "created_at": "2026-08-24T13:19:15-05:00",
  "parent": "WO-20260824-00d5",
  "branch": "feat/rename-skill-versioning-to-skill-registry-the-cl",
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
    "WO-20260824-c6b0",
    "WO-20260824-81a6",
    "WO-20260824-b21b",
    "WO-20260824-d058",
    "WO-20260824-79b6",
    "WO-20260824-a6cb",
    "WO-20260824-6a33",
    "WO-20260825-dac4"
  ],
  "blocks": [
    "WO-20260830-eb89"
  ]
}
---

# WO-20260824-238b - Rename skill-versioning to skill-registry, the closing commit

## Problem

After this work the skill owns three publish-side things, consumers never touch it, and versioning is precisely the part CI took over - so the name now describes the one responsibility it no longer has. The rename must be last because every reference has to be updated in the same commit, and there can be no compat symlink: skill_dirs uses find -type d, which does not match a symlink to a directory, so the symlink would hide the breakage rather than surface it.

## Scope

**In**

- git mv claude/skills/skill-versioning claude/skills/skill-registry
- updating every remaining reference
- a major bump, because a renamed skill breaks a consumer's existing usage

**Out - non-goals**

- renaming skill-version.sh - the skill is renamed, the script is not
- a compat symlink, which the registry cannot see

## Acceptance criteria


- [x] `AC-H1` *(human)* git grep skill-versioning returns nothing outside history
  - observed `2026-08-31` Green, and the grep was proved to run. On a clone of the real 43-skill tree in a container: git grep -l skill-versioning excluding work-orders, HYDRATION.md, docs, notes and registry.json returned nothing; after pasting '# skill-versioning' into .github/scripts/bump-gate.sh the same grep returned that file. 'Outside history' was decided deliberately to cover both design documents under docs/superpowers/ as well as HYDRATION.md, the work-orders tree and notes/skills-pm-discovery.md: in every one of them the old name is the subject of a dated record of this rename rather than a path anyone follows, and rewriting the spec would produce the sentence 'Renaming skill-registry to skill-registry'. Reasoning stated in the PR body. registry.json is untouched by the branch by design and the publisher removes the stale entry when it renders.
- [x] `AC-H2` *(human)* verify is green on main after the publish run
  - observed `2026-08-31` Green. The squash merge was simulated on main in a container from the real PR title and body, then publish.sh apply run over it: it stamped skill-registry at 1.0.0, bumped project-scaffold 1.5.1 -> 1.5.2 from the trailer, rendered the registry, and plain verify then reported 'ok - 43 skills versioned, registry in sync', rc=0. The stale skill-versioning entry is gone from registry.json and skill-registry is present.
- [x] `AC-H3` *(human)* the publish run records a major bump for skill-registry
  - observed `2026-08-31` NOT MET, and not satisfiable by the pipeline as built. publish.sh files a skill absent from registry.json into FRESH (note(), line 188); a FRESH skill never reaches record(), so collect() does 'note $s || continue' and a Bump: skill-registry=major trailer is read, accepted, then silently discarded. cmd_apply loops EXISTING only. A renamed directory is absent from the registry under its new name by definition, so a rename can never carry a level. Measured: the publish run recorded 'skill-registry -> 1.0.0 (new, absent from the registry)'. No trailer for skill-registry was written, deliberately, since asserting a bump the publisher provably discards would misrepresent the result. Related defect found on the way and on no ticket: report() and commit_message() print 1.0.0 unconditionally for a FRESH skill while init stamps only unversioned ones, so the first run of this branch - which still carried the version: 2.1.0 line the git mv brought across - produced a commit message saying 1.0.0 beside a registry.json saying 2.1.0. The version: line was dropped so the two agree, on the user's decision of 2026-08-31; that masks the misreport rather than fixing it.

## Test plan

_none recorded - Rule 14 says this runs in a container_

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

- `2026-08-31` AC-H3 is recorded as evidenced but its verdict is NOT MET. work-order.sh evidence checks the box unconditionally and done refuses any unchecked criterion, so the tick means 'observed and recorded' rather than 'passed'; the observation text carries the verdict and it is the first two words of it. The substance: publish.sh cannot record a bump of any level for a renamed skill, because a rename makes the directory absent from registry.json under its new name, note() files it as FRESH, and collect() skips FRESH skills before any trailer is read. Measured against a clone of the real tree, not inferred. Extending the publisher to carry a level across a rename is real work on no ticket, and it is the only thing that would make a criterion of this shape satisfiable next time.
- `2026-08-24` Poker 2026-08-24: 3 points. Mechanical, and it must be last.

## Outcome

_Written by `work-order close`. Empty until then._
