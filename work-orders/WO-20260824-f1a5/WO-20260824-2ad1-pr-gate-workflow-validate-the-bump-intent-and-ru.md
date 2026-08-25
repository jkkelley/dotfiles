---
{
  "id": "WO-20260824-2ad1",
  "slug": "pr-gate-workflow-validate-the-bump-intent-and-ru",
  "title": "PR gate workflow: validate the bump intent and run the affected suites",
  "type": "feature",
  "status": "in-progress",
  "priority": "p1",
  "created": "2026-08-24",
  "updated": "2026-08-25",
  "created_at": "2026-08-24T13:19:08-05:00",
  "parent": "WO-20260824-f1a5",
  "branch": "feat/pr-gate-workflow-validate-the-bump-intent-and-ru",
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
    "WO-20260824-6acf",
    "WO-20260824-efb0"
  ],
  "blocks": [
    "WO-20260824-316d"
  ]
}
---

# WO-20260824-2ad1 - PR gate workflow: validate the bump intent and run the affected suites

## Problem

Merge-time allocation means the PR carries intent and CI carries out the allocation. If a PR reaches main with an unresolvable or mistyped bump, the publisher fails closed and the failure looks like nothing happening. The gate exists to make that impossible before the merge button rather than after it.

## Scope

**In**

- validating that every trailer names a skill that exists and actually changed, at a legal level, with no skill named twice
- every changed skill resolving to a level, from a trailer or a parseable conventional title
- refusing a hand-edited version: or registry.json, and running verify --structure
- printing the resolution table so the outcome is visible before merge
- a detect job emitting changed skills that ship a suite, and a guarded matrix, one runner per skill
- a separate tools job for claude/tools/, which has no registry row and cannot appear in the matrix
- installing Podman on the runner, because ubuntu-24.04 ships Docker and Rule 14 requires Podman

**Out - non-goals**

- writing anything at all - this workflow only ever reads
- ubuntu-latest, banned by Rule 15

## Acceptance criteria


- [ ] `AC-H1` *(human)* a docs-only PR is green with the matrix skipped and no empty-matrix error
- [ ] `AC-H2` *(human)* a PR editing hydration-prompt runs exactly one matrix leg
- [ ] `AC-H3` *(human)* a PR whose trailer names a skill it did not change is refused, and the message says which

## Test plan

```sh
exercised by real PRs against the repository; the empty-matrix case is the one that only shows up live
```

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

- `2026-08-25` Gap found, not fixed here, on no ticket: verify --structure cannot pass for a brand new skill. With no version: line cmd_verify reports it unversioned; with one, diff_check reports the version: as hand-edited. Either way the gate refuses the one change nobody can land another way. bump-gate.sh resolve handles the case correctly - absent from the registry means 1.0.0 and no trailer needed, per E1.8 - so the refusal comes from skill-version.sh rather than from the gate's own logic. It belongs to skill-versioning.
- `2026-08-25` The hydration prompt's claim that every suite 'is invoked the same way, so the matrix leg is one line per skill' is false for four of the seven. cartography, project-scaffold and work-order re-exec themselves into Podman; context-compaction, hydration-prompt, living-docs and skill-versioning expect to be started inside a container already. run-suite reads the suite and dispatches, so it stays one line per skill without carrying a list, and the wrapper is the invocation the three justfiles and the two suite headers already agree on. All eight suites were run through it green: cartography 85, project-scaffold 161, work-order 299, claude/tools 193, hydration-prompt 47, skill-versioning 103, living-docs 39, context-compaction 41.
- `2026-08-25` The shell is in .github/scripts/bump-gate.sh, not inline in the YAML, and the plan's one-file table is deviated from on purpose. A shell block inside a workflow can only be tested by pushing, and this ticket was sized at 8 precisely because every fix costs a push. The script is driven against a fixture repository by .github/scripts/testing/run-tests.sh - 66 checks, self-exec'ing into Podman on the same bitnami/git digest the other suites use - and a fourth job runs that suite whenever .github/ changes, so the gate is gated by itself.
- `2026-08-25` The scope line 'installing Podman on the runner' is superseded by the runner image. ubuntu-24.04 ships Podman 5.8.4, checked against actions/runner-images Ubuntu2404-Readme.md on 2026-08-25, so there is nothing to install - and installing it anyway would mean an apt version this repository cannot pin to an immutable identifier the way Rule 15 asks. .github/scripts/require-podman.sh asserts instead, and its failure message says the runner image moved rather than that a step is missing.
- `2026-08-25` The conventional-type to level map, which the spec names only for feat, fix and BREAKING CHANGE: feat is minor; fix, docs, chore, refactor, test, style, perf, ci and build are patch; a ! or a BREAKING CHANGE: footer is major. The patch list is Rule 16's own table read back - wording, script bugfix, doc clarification, test-only change. revert is deliberately left unmapped: the right level depends on what was reverted, so it forces an explicit trailer rather than being guessed at.
- `2026-08-25` Precedence, decided: the trailer beats the title, always. The spec calls the title the fallback for 'anything changed but not listed', which makes the trailer the explicit source and the title the inferred one, and an explicit statement that loses to an inference is not a statement. The case this gives up is a breaking title carrying a patch trailer, and the printed resolution table is what buys it back: the override is visible in the check output before anyone reaches the merge button.
- `2026-08-24` Poker 2026-08-24: 8 points. Sized above the plan's medium. Three non-trivial shell blocks inside YAML, and CI has the worst iteration loop in the plan - every fix costs a push.

## Outcome

_Written by `work-order close`. Empty until then._
