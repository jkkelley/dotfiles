# stuck-watch

<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->

- [Pieces](#pieces)
- [Status codes](#status-codes)
- [Gates](#gates)
- [Cleanup](#cleanup)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

Is a seat really stuck? A no-model watcher codes it with evidence on the bus and rings the owner's phone; a deadman that nothing on the line can kill watches the watcher.

Owner, 2026-10-16 UTC: "what really ensure things are stuck? i dont trust you or agents or humans" and "ensure it goes to my phone".

## Pieces

| File | Does | Started by |
| --- | --- | --- |
| `stuck-watch.sh` | every 60 s per seat: codes on `line.<line>.stuck.<code>`, ntfy once per seat+code per 30 min, `line.<line>.heartbeat` | `make stuck-watch-up LINE=` (monitors.json entry `stuck-watch`, slot 2.3 of the monitor tab) |
| `deadman.sh` | heartbeat older than 180 s, or bus down: ntfy priority high | `make deadman-install` (systemd --user timer, every minute) |
| `stuck-audit.sh` | every stuck seat+code: first, last, duration, evidence path, from the LINE stream | `make stuck-audit LINE= [SINCE=]` |
| `stuck-watch-ctl.sh` | up through bin/monitors.sh, down and status by pid | the Make targets |
| `config.json` | every threshold, path and the status code map | read by all of the above |

## Status codes

`config.json` `.codes` is the map, read by the scripts; this table mirrors it.

| Code | Means | Acts |
| --- | --- | --- |
| STK-001 | seat idle longer than `idle_seconds` and no result file | orchestrator |
| STK-002 | no commit on the seat's branch and no PR change for `stale_minutes`, no result file | orchestrator |
| STK-003 | seat CPU 0 for `cpu_zero_samples` ticks, no result file | orchestrator |
| STK-004 | seat context over `ctx_pct` | orchestrator (compaction) |
| STK-005 | result claims done, gh shows a PR not merged or CI not green | orchestrator, never trusts the claim |
| STK-090 | stuck-watch dead: heartbeat older than `heartbeat_max_seconds` | architect break glass: `make stuck-watch-up` |
| STK-091 | bus down | architect break glass: bring the bus up |
| A2A-004 | SOP breach in a result file, paged as is | architect |

## Gates

Each gate is a Make target (Design principles 101 item 34); none notifies the owner (item 35).

- `make stuck-watch-dev`: podman, `--network=none`, stub herdr, gh, bus and ntfy.
- `make stuck-watch-uat [LINE=stuck-uat]`: real bus and herdr, a haiku test seat left idle, `NTFY_TOPIC_VAR=YPC_NTFY_TEST_TOPIC` read back by script, then a poll proving the owner topic stayed empty.
- `make stuck-watch-stable`: a watcher for every line in `config.json` `.lines`, deadman timer on the owner topic, status checked.
- `make stuck-watch-rollback`: every watcher down, deadman timer removed.

## Cleanup

`make stuck-watch-clean [LINE=]` drops dedupe and per-line state; evidence and logs stay in the artifact store (`trace/`, `log/`) and age out with `artifact.sh clean`.
