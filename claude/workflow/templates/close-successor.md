<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->

- [Close-successor template](#close-successor-template)
  - [When to use](#when-to-use)
  - [Fields](#fields)
  - [Steps](#steps)
  - [Acceptance criteria](#acceptance-criteria)
  - [Test plan](#test-plan)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

# Close-successor template

## When to use

Use it for a ticket whose code PR merged but which is not done on main (ready, in-progress or in-review), or whose done is refused by a broken check.
A successor closes it, never a second build.

## Fields

- title: `Close <OLD-ID> (<what>, PR <N> merged): re-run its checks <i,j,k> on main under this ticket, move its <dependents> edges here and cancel <OLD hex> as superseded`
- type: `chore`
- parent: the same parent as the old ticket
- `--blocks`: each open dependent of the old ticket, at cut time

## Steps

A design seat copies this block into Context.

```text
bash claude/skills/work-order/scripts/work-order.sh link --id <DEP> --no-depends-on <OLD-ID>
bash claude/skills/work-order/scripts/work-order.sh cancel --id <OLD-ID> --reason '<what>; re-checked under THIS-TICKET-ID' --superseded-by THIS-TICKET-ID
bash claude/skills/work-order/scripts/work-order.sh check --id THIS-TICKET-ID
commit the generated moves, open the PR, submit --pr <N>, done, commit and push
```

One `link` line per dependent.

## Acceptance criteria

- For every check of the old ticket, write `<OLD-ID> check N passes on main (copied from <OLD-ID> check N)` and copy its command, exit and expect verbatim.
- Drop the old ticket's scope check.
- Add `<OLD-ID> is cancelled and superseded`.
  - check: `bash claude/skills/work-order/scripts/work-order.sh show --id <OLD-ID> --json | jq -r '.status + " " + (.superseded_by // "-")'`, exit 0, expect `^cancelled WO-`
- Add `no open ticket still depends on <OLD-ID>`.
  - check: `grep -rlE '"<OLD-ID>"' work-orders --include='WO-*.md' | xargs -r grep -L -E '"status": "(done|cancelled)"' | grep -v -- '-<OLD hex>-'`, exit 1
- The last criterion is the scope check of `claude/workflow/templates/scope-ac.md` with the alternation `work-orders/.*` alone, exit 1.

## Test plan

Shape: `claude/workflow/templates/test-plan.md`.

- `TP-1`
  - intent: the successor's own checks all pass, so done is not refused
  - command: `bash claude/skills/work-order/scripts/work-order.sh check --id THIS-TICKET-ID`
  - expected: exit 0 and one AC-PASS line per criterion

GOOD: WO-20261016-aa46 - copies 1b7e checks 1-6 and 8, drops the contradicting 7, ends on the work-orders-only scope check.

NEVER: copying the old ticket's scope check into the successor - it names code paths a close diff never touches, or contradicts the work-orders-only check (WO-20261016-1b7e check 7).

NEVER: re-running start on the stranded ticket - its branch may exist and its scope check fails on a close diff.
