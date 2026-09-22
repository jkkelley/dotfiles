# RB-failover - a seat is done, or cannot go on

Owner decision O-06: hot swap through the model chain until it is exhausted.
A human is notified, never required.

Watcher: `bin/seat-watch.sh`, one per seat, in a labeled herdr pane `watch-seat-<pane>` in the `monitors` tab.
Chain: the declaration's `agent.models`, for example `schemas/workflows/architect.workflow.json`: kimi-k3, then opus, then codex-sol.
Knobs: `config/project.json` under `workflow.watchers` (`stall_seconds`, `resume_attempts`, `interval_seconds`, `rail_ledger`, `auto_arm`) and `workflow.principal_pane`.

## Where it came from

Ported from bearings-v2, read-only from `~/tools/bearings-v2/bin/`: `watch.sh` (the supervisor sweep), `monitor-feed.sh` (one line per new record, deduped), `dispatch-seat.sh` (never `--wait`; wait for the seat's own record), `watch-toggle.sh` (a pause flag, no restart).
Two things changed in the port.
Bearings escalated after three resumes; here that is a hot swap to the next link.
Bearings ended in an owner line; here chain exhaustion is one ALERT and one prompt to the principal, and nothing waits.

## What the seat watcher reads

| File in the seat dir | Written by                                     | Means                                                                       |
| -------------------- | ---------------------------------------------- | --------------------------------------------------------------------------- |
| `seat-link`          | `bin/workflow-spawn.sh` after every real start | Workflow, seat, ticket, link N of M, worktree, start time                   |
| `PAUSED`             | `bin/watch-ctl.sh pause seat <pane>`           | Stand off; the seat keeps working                                           |
| `changeover-hold`    | the swap itself                                | A changeover owns the seat; `compact-watch` and `compact-now` stand off too |
| `failover-stopped`   | the watcher                                    | The chain is exhausted or a swap failed; watch for done only                |
| `.resumes`           | the watcher                                    | Resumes spent on this link                                                  |
| `.seen`              | the watcher                                    | Checksums of done rows already announced                                    |
| `handover.md`        | the swap                                       | The newest handover packet                                                  |

## Each tick

1. **Paused**: nothing happens.
2. **Done**: a row in the declaration's `record.emitted_to`, for this ticket, since this link started, or a rail ledger `complete` row with `by` equal to the seat name.
   The principal gets one line naming the seat, the ticket and the row, once per row, and the watcher ends.
   Done is never inferred from idleness. A seat that finishes without writing a record reads as silent.
3. **Stopped** or **held**: no swap.
4. **Exhausted**: the transcript's newest assistant row is Claude Code's synthetic API error of the exhaustion class (rate limit, 429, quota, credit or spend limit, overloaded, authentication).
   Swap now; resuming into a quota wall is the same wall.
5. **Dead**: herdr sees no agent in the pane. Restart the same link, up to `resume_attempts`, then swap.
6. **Silent**: no transcript growth for `stall_seconds`. Prompt the seat to continue, up to `resume_attempts`, then swap.
   A codex link has no Claude transcript, so its activity comes from herdr reporting it working.

## The swap

1. Touch `changeover-hold`.
2. Write the packet: the seat's `CONTEXT_STATE.md` if it verifies, else one built from the transcript tail (last brief, last assistant text, `git status`, `git log -5` of the worktree).
3. Stop the seat: `esc`, `/exit`, then `ctrl+c` twice, and prove it gone with `herdr agent get`.
   If it will not stop, nothing is started on top of it: ALERT, `failover-stopped`, principal told.
4. `bin/workflow-spawn.sh <workflow> <seat> --link N+1 --pane <pane> --ticket <ticket> --brief-file <seat dir>/takeover-brief.txt`.
   The brief says: you are taking over, read the packet at its path, continue on this worktree.
5. Clear the hold, log the swap, prompt the principal one line.

Past the last link: ALERT once, prompt the principal, touch `failover-stopped`.

## Turning it on and off

```sh
bin/watch-ctl.sh on seat <pane>        # workflow-spawn.sh does this for every seat while watchers.auto_arm is true
bin/watch-ctl.sh pause seat <pane>     # stand off without a restart
bin/watch-ctl.sh unpause seat <pane>
bin/watch-ctl.sh status seat <pane>    # pid, pane, last three log lines
bin/watch-ctl.sh off seat <pane>       # signals only the watcher
```

The spawner also arms the workflow's gate watcher, `bin/watch-ctl.sh on workflow <id> <worktree>`, which runs the declaration's gates in the seat's worktree until they all pass.

## After a failure

- **`failover-stopped` after an exhausted chain.** Read `<seat dir>/handover.md` and the transcript. Reset by deleting `failover-stopped` and `.resumes` once a link has headroom again, then `bin/workflow-spawn.sh <workflow> <seat> --link N --pane <pane>`.
- **ALERT, the seat would not stop.** Read the pane with `herdr pane read <pane>`. Nothing else was started in it.
- **ALERT, the next link failed to start.** Read `<seat dir>/swap.log`; it holds the spawner's output.
- **A stale `changeover-hold`.** Left only if the watcher itself died mid-swap. It holds compaction too. Delete it after checking the pane.
- **Principal unreachable.** The ALERT carries the message. Check that the principal's pane is labeled `claude-main`.
