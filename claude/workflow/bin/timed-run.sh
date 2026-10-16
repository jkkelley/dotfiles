#!/usr/bin/env bash
# timed-run.sh - run any step with its start and end on the bus, its timeout enforced, up to 3 tries. No model calls.
#
# usage: timed-run.sh --node N [--kind K] [--line L] [--budget S] [--timeout S] [--retries R] -- cmd [args...]
#   per attempt: line.<L>.event.node.start, the command under `timeout`, then .end {rc, duration_s, budget_s} or
#   .timeout. Every attempt timed out -> line.<L>.timing.TIMEOUT and a bottleneck work order, exit 124. Otherwise the
#   command's exit code. An end over budget prints "SLOW <node>"; node-timing.sh is the one place that publishes SLOW.
# Make: make timed-run NODE= KIND= BUDGET= TIMEOUT= LINE= CMD='...'. Defaults: config/time-budgets.json; LINE from $LINE or "all".
#
# Owner, 2026-10-16 UTC (item 37): "every node, seat, job, CI run and merge emits start and end on the bus by script".
# BREADCRUMB - TIMEOUT is coded here, SLOW is coded by node-timing.sh, never both.
# What broke: nothing yet; the rejected alternative. Both coding SLOW would file two work orders for one slow run.
# Why this fix: only this wrapper knows a run was killed, so TIMEOUT is its job; every end event carries budget_s, so
#   the consumer can judge SLOW for wrapped and unwrapped producers alike. Cost: SLOW appears when node-timing consumes.
set -uo pipefail
HERE="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
# shellcheck source=timing/lib.sh disable=SC1091
. "$HERE/../timing/lib.sh"
NODE=""; KIND="make"; L="${LINE:-all}"; BUDGET=""; TIMEOUT=""; RETRIES=""
while [ $# -gt 0 ]; do case "$1" in
  --node) NODE="$2"; shift 2 ;; --kind) KIND="$2"; shift 2 ;; --line) L="$2"; shift 2 ;; --budget) BUDGET="$2"; shift 2 ;;
  --timeout) TIMEOUT="$2"; shift 2 ;; --retries) RETRIES="$2"; shift 2 ;; --) shift; break ;;
  -h|--help) sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;; *) echo "timed-run: unknown argument $1" >&2; exit 2 ;; esac; done
if [ -z "$NODE" ] || [ $# -eq 0 ]; then echo "timed-run: --node and a command after -- are required" >&2; exit 2; fi
BUDGET="${BUDGET:-$(tm_limit budget_s "$KIND" "$NODE")}"; TIMEOUT="${TIMEOUT:-$(tm_limit timeout_s "$KIND" "$NODE")}"
RETRIES="${RETRIES:-$(tm_cfg .retries)}"
RUN="$(date -u +%Y%m%dT%H%M%SZ)-$$"
for a in $(seq 1 "$RETRIES"); do
  tm_event "$L" "$NODE" "$KIND" "$RUN" start "$(jq -nc --argjson a "$a" --argjson b "$BUDGET" --argjson t "$TIMEOUT" '{attempt:$a,budget_s:$b,timeout_s:$t}')"
  t0="$(date -u +%s)"; timeout --kill-after=10 "$TIMEOUT" "$@"; rc=$?; d=$(( $(date -u +%s) - t0 ))
  if [ "$rc" = 124 ] || [ "$rc" = 137 ]; then
    tm_event "$L" "$NODE" "$KIND" "$RUN" timeout "$(jq -nc --argjson a "$a" --argjson d "$d" --argjson t "$TIMEOUT" '{attempt:$a,duration_s:$d,timeout_s:$t}')"
    echo "timed-run: $NODE attempt $a/$RETRIES past ${TIMEOUT}s" >&2; continue
  fi
  tm_event "$L" "$NODE" "$KIND" "$RUN" end "$(jq -nc --argjson a "$a" --argjson r "$rc" --argjson d "$d" --argjson b "$BUDGET" '{attempt:$a,rc:$r,duration_s:$d,budget_s:$b}')"
  [ "$d" -gt "$BUDGET" ] && echo "SLOW $NODE ${d}s over budget ${BUDGET}s" >&2
  exit "$rc"
done
ev="$(jq -nc --arg n "$NODE" --arg k "$KIND" --arg l "$L" --arg r "$RUN" --argjson t "$TIMEOUT" --argjson a "$RETRIES" --arg c "$*" \
  '{node:$n,kind:$k,line:$l,run_id:$r,timeout_s:$t,attempts:$a,command:$c}')"
tm_code "$L" TIMEOUT "$ev"
echo "TIMEOUT $NODE after $RETRIES attempts; work order: $(tm_wo "$NODE" TIMEOUT "$ev")" >&2
exit 124
