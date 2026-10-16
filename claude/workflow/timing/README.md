# timing

<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->

- [Pieces](#pieces)
- [Status codes](#status-codes)
- [Gates](#gates)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

Every node's start and end on the bus, durations against budgets, and SLOW or TIMEOUT turned into a bottleneck work order.

Owner, 2026-10-16 UTC (Design principles 101 item 37): "every node, seat, job, CI run and merge emits start and end on the bus by script; budgets are set in the design; code that runs over budget is status SLOW and becomes a bottleneck work order".

## Pieces

| File | Does | Started by |
| --- | --- | --- |
| `../bin/timed-run.sh` | runs a step: `line.<line>.event.node.start`, `.end` or `.timeout`; timeout enforced, 3 tries, TIMEOUT coded with a work order | `make timed-run NODE= CMD='...'`, or any Make target that routes through it |
| `node-timing.sh` | durable pull consumer: durations into KV `TIMING`, SLOW and a work order over budget; herdr seat working spans count too | `make node-timing-loop` (monitors.json entry `node-timing`) |
| `line-timing.sh` | durations against budgets and the top 5 bottlenecks, Markdown report in the artifact store | `make line-timing LINE= [SINCE=]`, `make morning-audit LINE=` |
| `../config/time-budgets.json` | budget and timeout per kind and per node, retries, KV bucket, consumer, work-order project | read by all of the above |

## Status codes

| Code | Means | Acts |
| --- | --- | --- |
| SLOW | a node ended over its budget (`line.<line>.timing.SLOW`) | the bottleneck work order's owner |
| TIMEOUT | a step was past its timeout on every try (`line.<line>.timing.TIMEOUT`) | the bottleneck work order's owner |

Bottleneck work orders land in the work-order project `~/.local/state/zenith/bottlenecks` under one epic, one per node and code per UTC day; the architect promotes each to the repo that owns the node.

## Gates

- `make timing-dev`: podman, `--network=none`, stub bus, nats CLI and work-order.
- `make timing-uat [LINE=timing-uat]`: the real bus and KV, a slow node and a hung node, its own consumer and a throwaway work-order project, then the report; it purges its KV keys and removes its consumer afterwards.
- stable: `make timing-up`, then the `node-timing` monitor runs in the line's monitor tab like every other monitor.
