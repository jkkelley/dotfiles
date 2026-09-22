# RB-compaction - compact a seat without losing the plan

Declaration: `schemas/workflows/compaction.workflow.json`.
Threshold: its `agent.context_threshold_percent`, currently 30, read by every script from there and defaulted nowhere.
Ceiling, cooldown and tick: `config/project.json` under `workflow.compaction`.

## Who does what

| Actor | Does | Never does |
| ----- | ---- | ---------- |
| The seat | Finishes its step, writes its checkpoint, touches its request, ends its turn | Sends `/compact` to itself |
| `bin/compact-watch.sh` | Reads the seat's context every tick, nudges at the threshold, compacts on request at idle, forces at the ceiling | Cuts a step, retries a failed compaction |
| `bin/compact-now.sh` | Runs one ceremony: hold check, checkpoint verify, idle gate, one bare `/compact`, proof, report | Resends, passes an argument to `/compact` |
| `bin/after-compact.sh` | Prints the seat's newest checkpoint into the rebuilt session | Prints another seat's state |
| `bin/watch-ctl.sh` | Turns watchers on and off in labeled herdr panes | Backgrounds anything |

A seat cannot compact itself.
A slash command only executes when submitted at an idle prompt, and a seat cannot see its own idleness while it is the thing that is busy.
Sent mid-turn, `/compact` lands in the conversation as prose and compacts nothing.

## Where a seat's state lives

Every seat has its own directory: `~/.local/state/dotfiles/execution/seats/<pane>/`, with `:` in the pane id written as `_`.
The checkpoint window is `CONTEXT_STATE.md` in that directory, owned by the `context-compaction` skill's `checkpoint.sh`.
One directory per seat means two seats never write the same file.

## Steps, for the seat

1. Finish the step you are on. A checkpoint taken mid-step describes a state that never existed.
2. Log the step on the rail: `report/rail.sh log <step> complete "<fifteen words>"`.
3. First time only, create your window: `bash ~/.claude/skills/context-compaction/scripts/checkpoint.sh init --project <seat dir>`.
4. Write the checkpoint body to a scratch file with the sections the skill requires: Infrastructure, Toolchain, Active Tasks, Blockers, Hydration prompt.
   The Hydration prompt names the next step by id and full title, every open question for the owner, and every path the next step needs.
5. Validate without writing: `... checkpoint.sh check --body-file <file>`.
   Exit 3 names every missing section and writes nothing.
6. Append it: `... checkpoint.sh new --project <seat dir> --body-file <file>`.
7. Request: `touch <seat dir>/compact-request`.
   End your turn.
   The watcher compacts you once you have been idle for 45 seconds.

## First act on the other side

`bin/after-compact.sh` runs as the SessionStart hook with matcher `compact` and prints your newest checkpoint.
Read it, state the step it names, and continue from there.
Log the resume on the rail with status `started`.

## Turning it on and off

```sh
bin/watch-ctl.sh on compact <pane>       # labeled pane watch-compact-<pane> in the monitors tab
bin/watch-ctl.sh status compact <pane>   # pid, pane, last three log lines
bin/watch-ctl.sh off compact <pane>      # signals only the watcher; the seat is never touched
bin/watch-ctl.sh status                  # every watcher
```

`bin/workflow-spawn.sh` arms the watcher on every seat it starts while `workflow.compaction.auto_arm` is true.
A seat whose watcher does not come up is reported as a failed start.
The principal's own pane is armed by hand once per herdr session.

## Checking without acting

`bin/compact-now.sh <pane> --dry-run` prints context percent, boundary count, idle seconds, hold state and whether the checkpoint verifies, and sends nothing.
`bin/context-pct.sh <pane>` prints the number the watcher acts on.

## Failure modes

- **Exit 3, checkpoint missing or invalid.** Nothing was sent. The seat fixes its checkpoint and touches the request again.
- **Exit 4, seat never idle within 600 seconds.** Nothing was sent. The seat is mid-turn; the next tick tries again.
- **Exit 5, held.** A model changeover owns the seat. The watcher waits for `changeover-hold` to disappear.
- **Exit 1, no `compact_boundary` within 600 seconds.** One `/compact` was sent and is never resent. A resend lands in the fresh session and is the double-compaction defect bearings-v2 found on 2026-09-21. Read `<seat dir>/ceremony-compact.md`, then read the pane with `herdr pane read <pane>`.
- **Verdict DEFECT in the report.** One submission and one boundary is OK; any other count is a defect in the ceremony. Name the line that caused it before running another ceremony by hand.
- **ALERT at the ceiling.** The seat reached the ceiling without requesting. It was compacted without a checkpoint and comes back with only the summary and the rail. That is the owner's to look at.
- **Two bubbles in the mobile app.** One submission is written to the transcript as a raw prompt and a `<command-name>` block. The report counts the raw rows; one is one.
