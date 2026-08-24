---
{
  "id": "WO-20260824-6acf",
  "slug": "split-verify-into-a-structure-check-and-a-full-c",
  "title": "Split verify into a structure check and a full check, and delete the notice assertion",
  "type": "feature",
  "status": "done",
  "priority": "p1",
  "created": "2026-08-24",
  "updated": "2026-08-24",
  "created_at": "2026-08-24T13:19:06-05:00",
  "parent": "WO-20260824-f1a5",
  "branch": "feat/split-verify-into-a-structure-check-and-a-full-c",
  "pr": 59,
  "merge_sha": "e4ede60010b2c571e2b27e376ee03cb1218fe974",
  "closed": "2026-08-24",
  "approval": {
    "via": "override",
    "reason": "Reviewed and approved on PR #55 on GitHub, which is where the whole cut was read as one diff. Lavish was offered and declined in favour of the PR.",
    "at": "2026-08-24"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [],
  "blocks": [
    "WO-20260824-2ad1"
  ]
}
---

# WO-20260824-6acf - Split verify into a structure check and a full check, and delete the notice assertion

## Problem

Under merge-time allocation every skill PR legitimately edits a skill and leaves the registry alone, which today's verify calls drifted. The PR gate needs a check that passes in exactly that state, while the publisher still needs the strict one. The existing notice assertion at skill-version.sh:195 also has to go before the notice can leave any file.

## Scope

**In**

- verify --structure: every skill versioned, no hand-edited version: or registry.json in the diff
- plain verify keeping its current meaning, structure plus registry match
- deleting the notice check at skill-version.sh:195
- extending the skill-versioning test suite to cover both forms

**Out - non-goals**

- asserting the notice is absent, which cannot land until all 42 files are clean

## Acceptance criteria


- [x] `AC-H1` *(human)* on a branch with an edited skill and an untouched registry, verify --structure exits 0 and plain verify exits non-zero
  - observed `2026-08-24` On feat/split-verify-into-a-structure-check-and-a-full-c before the Rule 16 bump, with skill-version.sh and run-tests.sh edited and registry.json untouched, in the bitnami/git container with the repo mounted read-only: 'verify --structure' printed 'base: origin/main' then 'ok - 43 skills versioned, no version: or registry.json in the diff', rc=0. Plain 'verify' printed 'drifted skill-versioning' with both hashes and rc=1. Two exit codes on one tree.
- [x] `AC-H2` *(human)* the suite covers both forms and passes in Podman
  - observed `2026-08-24` run-tests.sh in Podman (bitnami/git pinned by digest, --network=none, source mounted read-only): PASS 72 FAIL 0. Section 5 is new and covers --structure against a real git fixture repo with skills under claude/: the motivating pair (--structure 0, plain verify 1 on one branch), --base and a bad --base, a hand-edited version: named as beta/SKILL.md, registry.json in the diff, an unversioned skill, and a hard failure outside a repository. It also proves the flag is parsed at all - 'verify REJECTS an unknown flag' exits 1, so --structure cannot be silently ignored. The two read-only-notice cases are gone; a stripped notice is now asserted to report as ordinary drift and to say nothing about the notice.

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

- `2026-08-24` This PR fails its own future gate, and that is correct rather than a defect. Rule 16 is still in force, so the branch carries the skill-versioning bump to 1.2.0 and the regenerated registry.json; 'verify --structure' therefore reports both and exits 1, while plain 'verify' is green. The state inverts at WO-20260824-8cd1 - Rewrite root CLAUDE.md for merge-time allocation and the named main exception, when the version stops being a contributor's business. WO-20260824-2ad1 - PR gate workflow: validate the bump intent and run the affected suites must not be pointed at --structure before that, or every skill PR fails the gate for obeying Rule 16.
- `2026-08-24` Poker 2026-08-24: 3 points. Bounded change to one script plus its existing suite.

## Outcome

_Written by `work-order close`. Empty until then._
