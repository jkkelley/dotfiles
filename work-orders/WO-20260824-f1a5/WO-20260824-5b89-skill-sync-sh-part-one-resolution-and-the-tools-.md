---
{
  "id": "WO-20260824-5b89",
  "slug": "skill-sync-sh-part-one-resolution-and-the-tools-",
  "title": "skill-sync.sh part one: resolution, and the tools test tree it is proved in",
  "type": "feature",
  "status": "in-progress",
  "priority": "p1",
  "created": "2026-08-24",
  "updated": "2026-08-24",
  "created_at": "2026-08-24T13:19:07-05:00",
  "parent": "WO-20260824-f1a5",
  "branch": "feat/skill-sync-sh-part-one-resolution-and-the-tools-",
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


- [x] `AC-H1` *(human)* given a manifest, a registry fixture and a receipt fixture, the resolved owned set is correct including transitive requires
  - observed `2026-08-24` Proved by 'bash claude/tools/testing/run-tests.sh', in Podman on debian@sha256:328d1649 with --network=none and /repo mounted ro. 80 checks, 0 failures. The AC-H1 group runs a manifest declaring cartography, deep-1, container-sandbox, no-such-skill and cartography again against a registry fixture in the exact shape render_registry emits, plus a receipt fixture. The owned set is exactly six names - cartography, work-order, container-sandbox, deep-1, deep-2, deep-3 - so the transitive edge is proved at one hop (cartography -> work-order) and past one hop (deep-1 -> deep-2 -> deep-3), which a one-level resolver would fail. Also asserted: a name declared twice is owned once; a name under [agents] reaches neither the owned set nor the unknown list; the registry's tools block is not read as skills, so neither skill-sync nor read-only-notice is owned; a name the registry lacks is reported as 'unknown' rather than silently dropped; a requires cycle (loop-a <-> loop-b) terminates and owns each side once. The receipt group proves it is read: gone-skill is 'previous' and 'dropped', work-order is 'previous' and not 'dropped', and a missing or corrupt receipt collapses to owning nothing previously rather than throwing. Section 10 repeats the resolution against /repo/claude/skills/registry.json itself and follows both real edges, cartography -> work-order and living-docs -> work-order, so the parser is not correct only against its own fixtures.
- [x] `AC-H2` *(human)* --boot with no manifest present exits 0 and prints nothing at all
  - observed `2026-08-24` Proved in the same containerised run, section 'AC-H2: --boot says nothing where there is nothing to do'. The two streams are captured to separate files and asserted separately, because 'prints nothing at all' is a claim about both and stdout alone passes with a message on stderr. In a directory with no .claude/skills.toml: exit 0, stdout zero bytes, stderr zero bytes. The same three hold with a manifest present and a stamp under 15 minutes old. The guard is then shown to be a guard rather than a permanent silence: with the stamp aged to 20 minutes via 'touch -d', --boot produces output. Without that last check the first six pass on a --boot that never does anything.
- [x] `AC-H3` *(human)* a registry that is unreachable three times produces the two-line failure and still exits 0
  - observed `2026-08-24` Proved in the same containerised run, section 'AC-H3: an unreachable registry'. curl is stubbed on PATH per skill-testing.md and is absent from the image, so the stub is the only curl there is; it increments a counter file on every call. With the stub failing: exit 0, the counter reads exactly 3, and stdout is exactly two lines - '!! SKILL SYNC FAILED - registry unreachable after 3 tries' and '!! Skills are as of 2026-08-21. Say so before doing skill-dependent work.', the date taken from the receipt's synced field. stderr is empty, because a SessionStart hook's stdout reaches the agent's context and its stderr does not. With no receipt the second line still reads as a sentence ('as of an unknown date'). An empty response is treated as a failed fetch and retried the full three times rather than accepted as a registry with no skills. The retry is shown to actually retry: a stub that fails twice and succeeds on the third attempt resolves normally and produces the real plan - a loop that gave up after one attempt would pass every other assertion in this group. curl missing entirely gets its own sentence rather than blaming a network that is fine. And --plan, which is not a session and owes one nothing, exits 1 on the same failure while still printing the same two lines.

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

- `2026-08-24` Rule 17's justfile clause was read and deliberately not applied. It binds 'every skill that ships executable code'; claude/tools/ is not a skill and is explicitly not under claude/skills/ because the syncer must not be one of its own packages. The nearest precedent is the repo-local tools/ tree that WO-20260824-7a63 shipped two tickets ago, which carries a testing/run-tests.sh and no justfile. Following it rather than forking silently. Flagging the gap rather than closing it: only 2 of 43 skills - context-compaction and living-docs - actually carry a justfile today, so the clause is largely unimplemented and closing it here would be one tools tree out of two and two skills out of forty-three.
- `2026-08-24` Scope call, made in the open. The plan's E1.6 checklist has a sweep box - 'Sweep .claude/cache/.sync.* older than an hour before starting' - sitting between 'Read the receipt' and 'Build into .claude/cache/.sync.XXXXXX'. The hydration entry says 'the first five boxes plus the --boot box are yours', which counts to six and would include it; this ticket's own Scope section names five things and does not. Picked: the sweep goes to WO-20260824-efb0. It clears temp directories that only the application half creates, so in part one it would delete nothing, and no test in this suite could produce a directory for it to find - a guard proved only against a fixture that this half of the script cannot generate is a decorative guard. The seam is now drawn explicitly in the plan at E1.6, one box higher than the prose implied.
- `2026-08-24` Scope note from WO-20260824-7a63 - Close-out moves onto the branch: done archives, cleanup only deletes branches. That ticket created a repo-local tools/ tree at the repository root with its own suite at tools/testing/, for tooling that maintains this repository and is never vendored. It deliberately did NOT create claude/tools/testing/, which is still this ticket to stand up, so nothing here shrinks. What it does give you is a worked example of the shape: tools/testing/run-tests.sh re-execs itself into Podman on the pinned debian digest with --network=none and the repo mounted read-only, and it uses set -uo pipefail rather than -e, because over half the checks run a command expected to fail and -e ends the run on the first of them while reporting the assertion as an error.
- `2026-08-24` Poker 2026-08-24: 5 points. Was half of a 13. Includes standing up claude/tools/testing/, which goes here so part two is never the ticket where part one first gets tested.

## Outcome

_Written by `work-order close`. Empty until then._
