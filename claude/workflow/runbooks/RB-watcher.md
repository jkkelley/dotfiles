# RB-watcher - run a watcher without disturbing what it watches

Switch: `bin/watch-ctl.sh on|off|status workflow <workflow-id>`; `bin/workflow-watch.sh <id> on|off` delegates to it.
Every watcher runs in the foreground of a labeled herdr pane, `watch-workflow-<id>` in the `monitors` tab. Nothing is backgrounded (dotfiles CLAUDE.md Rule 18).
Log and pid: the configured `state_dir`, currently `~/.local/state/dotfiles/execution/`, as `<workflow>-watch.log` and `<workflow>-watch.pid`.
State: `<workflow>-watch.state.json`, validated by `schemas/workflows/watcher-state.schema.json`.

## The contract

- Log only. Nothing is printed to the owner and nothing is sent to any pane.
- One line only on change. A tick that sees what the last tick saw writes nothing, so sixty identical lines an hour cannot bury the one that mattered.
- A line whose decision is the owner's is prefixed `ALERT`. Every other line takes a lowercase `key:` prefix, so `grep ALERT` is a complete filter and reading the log needs no judgement.
- Which lines those are is read from the declaration's `gates[].owner_decision`, never decided in the script. A watcher that classifies severity by pattern-matching a gate name drifts the first time a gate is renamed.
- `status` prints the pid and the last three lines, and nothing else.
- The watcher stops on its own when the run ends, which here means no gate is red.
- `off` signals only the watcher's own pid. It never touches the run.

## Use

```sh
bin/watch-ctl.sh on workflow scaffold-build
bin/watch-ctl.sh status workflow scaffold-build
bin/watch-ctl.sh off workflow scaffold-build
```

To be told about decisions without reading the log, tail it for `ALERT` only:

```sh
tail -n 0 -F ~/.local/state/dotfiles/execution/scaffold-build-watch.log | grep --line-buffered ALERT
```

The owner hears one line only when the decision is theirs to take.

## Failure modes

- **The watcher is dead.** `status` says `off` while the log's last line is old and the run is still going. Nothing was lost: the watcher holds no state the run needs, and every gate it evaluates is re-evaluated from scratch on the next tick. Run `on` again. If it dies repeatedly, run one tick's gate commands by hand; a gate command that hangs holds the loop open and looks like a hang in the watcher.
- **`status` says `off` immediately after `on`.** The watcher died in its pane. Read the pane: `herdr pane read <pane>`; the error is on screen, which is the point of running it there.
- **The log stops growing but `status` says `on`.** Expected, and usually correct: nothing changed. Confirm against the interval in the state file before assuming a hang.
- **A gate is red forever.** Check whether it is red for a reason anyone watching can act on. A permanently red gate trains a reader to ignore the watcher, which is worse than not watching at all. Either fix it, or move it out of the gate list and into the runbook where a human reads it.
- **Two watchers on one workflow.** `on` refuses while a live pid is in the pid file. A stale pid file with a dead pid is replaced silently, which is correct: the previous watcher is gone.
- **The state file disagrees with reality.** It is written at transitions, not per tick, so a watcher killed with `kill -9` leaves `state: on` behind. The pid is the truth; the state file is a description of the last transition that completed.
