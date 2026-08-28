---
name: zzz-gate-probe
description: A throwaway skill that exists only to prove the PR gate accepts a brand new skill directory. Deleted in the same pull request that added it. Never install this.
---

# zzz-gate-probe

This is not a skill. It is the evidence for `AC-H1` of
`WO-20260825-dac4 - verify --structure refuses a brand new skill, whichever way it is written`.

It carries no `version:` line, deliberately.
Under merge-time allocation that is the correct shape for a new skill: the publisher stamps it at
`1.0.0` with `init` on `main` after the merge, and the branch states only the intent.
Before this ticket, `verify --structure` reported that shape as `unversioned` and the gate was red -
which made adding a skill the one change the pipeline could not land.

The gate only exists on a pull request, so a green local `verify --structure` is not the claim
`AC-H1` makes. This directory is how the claim gets made against the real thing.

It is deleted later in the same pull request, and it never reaches `main` or the registry.
