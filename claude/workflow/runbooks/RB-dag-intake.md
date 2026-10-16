# RB-dag-intake - run the intake DAG N1 to N10

<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->

- [Who does what](#who-does-what)
- [State](#state)
- [Steps](#steps)
- [Check](#check)
- [Failure modes](#failure-modes)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

Source: docs/design/dag-state.spec.xml and docs/design/dag-state-nodes.spec.xml. Per-node steps: claude/workflow/dag/playbooks/PB-intake.md.

## Who does what

| Node | Name | Script | Retry |
| --- | --- | --- | --- |
| N1 | claim | `claude/workflow/dag/bin/dag-take.sh` | 3 |
| N2 | worktree-branch | `claude/workflow/dag/bin/dag-take.sh` | 3 |
| N3 | start-ticket | `claude/workflow/dag/bin/dag-take.sh` | 3 |
| N4 | build | `claude/workflow/bin/workflow-spawn.sh` | 3 |
| N5 | verify | `claude/workflow/tools/ci-select.sh` | 3 |
| N6 | open-pr | `claude/workflow/dag/bin/dag-ship.sh` | 0 |
| N7 | close-out | `claude/workflow/dag/bin/dag-ship.sh` | 0 |
| N8 | ci | `claude/workflow/dag/bin/dag-ci.sh` | 3 |
| N9 | merge | `claude/workflow/dag/bin/dag-merge.sh` | 0 |
| N10 | cleanup | `claude/workflow/dag/bin/dag-ship.sh` | 3 |

A seat runs the node script and ticks the box. It never edits a node, the state or the DAG by hand.

## State

Each run keeps `state.json`, validated by `state.schema.json`, plus `nodes.lock/` (the design pinned by hash) and a run lock.
The state file is the source of truth; the DAG design is what it is planned and applied against.
Node status codes: DG-PENDING, DG-STALE, DG-SKIPPED, DG-FAILED, DG-HANDOFF, DG-COMPLETE, DG-BUNDLE-MISSING.

## Steps

1. Walk N1 to N10 in order; N4 fans out to build nodes B1..Bn when their touches are disjoint.
2. For each node: read its PB-intake.md section, run its script, tick every proof box.
3. Record start and end of the node by script.
4. Hand off on N5 fail x3 and on N8 red x3.

## Check

A node is done only when every proof in its PB-intake.md section is ticked.
The run is done when the ledger holds DG-COMPLETE and the run dir is archived.

## Failure modes

- **A node fails.** Retry per the node (3 for N1-N5, N8, N10), then DG-FAILED and DG-HANDOFF.
- **N6, N7, N9 fail.** They are not idempotent and retry 0: recover from state, never rerun by hand.
- **A bundle file is missing.** plan returns DG-BUNDLE-MISSING; the gap goes to the design seat.
- **The design changed mid-run.** Migrate with the dag migrate verb; a done node is DG-STALE only if its checklist or script changed.
- **The run stopped partway.** Recover from state.json; every idempotent step lands in the same end state.
