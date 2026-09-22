# RB-watcher - run a watcher without disturbing what it watches

Script: `bin/workflow-watch.sh <workflow-id> on|off|status`.
Log and pid: the configured `state_dir`, currently `~/.local/state/wsl-kimi-k3-proxy/execution/`, as `<workflow>-watch.log` and `<workflow>-watch.pid`.
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
bin/workflow-watch.sh credential-unblock on
bin/workflow-watch.sh credential-unblock status
bin/workflow-watch.sh credential-unblock off
```

To be told about decisions without reading the log, tail it for `ALERT` only:

```sh
tail -n 0 -F ~/.local/state/wsl-kimi-k3-proxy/execution/credential-unblock-watch.log | grep --line-buffered ALERT
```

The owner hears one line only when the decision is theirs to take.

## Failure modes

- **The watcher is dead.** `status` says `off` while the log's last line is old and the run is still going. Nothing was lost: the watcher holds no state the run needs, and every gate it evaluates is re-evaluated from scratch on the next tick. Run `on` again. If it dies repeatedly, run one tick's gate commands by hand; a gate command that hangs holds the loop open and looks like a hang in the watcher.
- **`status` says `off` immediately after `on`.** The pid file holds a pid that is not alive. This was a real defect: the loop wrote `$$` from inside a subshell, which in bash is the parent's pid, so the file named a process that exited as soon as `on` returned. Fixed with `$BASHPID`, with the breadcrumb at the fix site in `bin/workflow-watch.sh`. If it recurs, the pid file is the evidence: compare it against `pgrep -f workflow-watch`.
- **The log stops growing but `status` says `on`.** Expected, and usually correct: nothing changed. Confirm against the interval in the state file before assuming a hang.
- **A gate is red forever.** Check whether it is red for a reason anyone watching can act on. A permanently red gate trains a reader to ignore the watcher, which is worse than not watching at all. Either fix it, or move it out of the gate list and into the runbook where a human reads it.
- **Two watchers on one workflow.** `on` refuses while a live pid is in the pid file. A stale pid file with a dead pid is replaced silently, which is correct: the previous watcher is gone.
- **The state file disagrees with reality.** It is written at transitions, not per tick, so a watcher killed with `kill -9` leaves `state: on` behind. The pid is the truth; the state file is a description of the last transition that completed.
