#!/usr/bin/env bash
# name: step-time.sh
# purpose: run one DAG node's command under a budget and a timeout, retry it, and put its start and end on the bus
# inputs: --line, --node, --budget, --timeout, --retries, then -- and the command; env STEP_TIME_PUB
# outputs: the command's own output; one status line on stderr per attempt; the command's exit code
# writes-to: the bus, subjects line.<line>.time.<node> and line.<line>.event.step.slow
# cleanup: none; the stream's max_age drops old timings
#
# usage: step-time.sh --line L --node N [--budget S] [--timeout S] [--retries 3] -- command [args...]
#
# Breadcrumb (owner, 2026-10-16 UTC, Design principles 101 item 37): "time out everything logically, you'll ID the
# bottlenecks". One wrapper times every Make target so no step runs untimed. Each attempt posts step.start and
# step.end (code 200 ok, 124 timeout, else the exit code) with dur_s; an attempt over --budget also posts
# step.slow (code SLOW). A timed-out or failed attempt is retried up to --retries times with backoff, then the
# last exit code is returned. A bus that cannot be reached never fails the step: the publish error goes to stderr
# and the command's own result stands. Rejected: timing inside each script, which drifts per script.
# STEP_TIME_PUB is the publish command (default: bus.sh pub beside this file); tests point it at a stub.
set -uo pipefail
HERE="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
LINE=""; NODE=""; BUDGET=60; TIMEOUT=300; RETRIES=3
die() { echo "step-time: $*" >&2; exit 2; }
while [ $# -gt 0 ]; do
  case "$1" in
    --line) LINE="${2:-}"; shift 2 ;;
    --node) NODE="${2:-}"; shift 2 ;;
    --budget) BUDGET="${2:-}"; shift 2 ;;
    --timeout) TIMEOUT="${2:-}"; shift 2 ;;
    --retries) RETRIES="${2:-}"; shift 2 ;;
    --) shift; break ;;
    -h|--help) sed -n '10,10p' "$0" | sed 's/^# //'; exit 0 ;;
    *) die "unknown argument $1" ;;
  esac
done
if [ -z "$LINE" ] || [ -z "$NODE" ]; then die "--line and --node are required"; fi
[ $# -gt 0 ] || die "no command after --"
for n in "$BUDGET" "$TIMEOUT" "$RETRIES"; do case "$n" in ''|*[!0-9]*) die "budget, timeout and retries are whole seconds or counts" ;; esac; done
[ "$RETRIES" -ge 1 ] || die "--retries is at least 1"
case "$LINE$NODE" in *[!A-Za-z0-9_-]*) die "line and node are subject tokens: letters, digits, _ and -" ;; esac
read -r -a PUB <<<"${STEP_TIME_PUB:-$HERE/bus.sh pub}"
run_id="$(date -u +%Y%m%dT%H%M%SZ)-$$"

pub() { # subject kind code attempt [dur rc]
  local j
  j="$(jq -cn --arg k "$2" --arg c "$3" --arg l "$LINE" --arg n "$NODE" --arg r "$run_id" --argjson a "$4" \
    --arg at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --arg d "${5:-}" --arg rc "${6:-}" --argjson b "$BUDGET" --argjson t "$TIMEOUT" \
    '{kind:$k, code:$c, line:$l, node:$n, run_id:$r, attempt:$a, at:$at, budget_s:$b, timeout_s:$t}
     + (if $d == "" then {} else {dur_s: ($d|tonumber), rc: ($rc|tonumber)} end)')"
  "${PUB[@]}" "$1" "$j" >/dev/null 2>&1 || echo "step-time: publish to $1 failed; step result unaffected" >&2
}

rc=1
for attempt in $(seq 1 "$RETRIES"); do
  pub "line.$LINE.time.$NODE" step.start 100 "$attempt"
  t0="$(date +%s)"
  timeout --kill-after=10 "$TIMEOUT" "$@"; rc=$?
  dur=$(( $(date +%s) - t0 ))
  code=$rc; [ "$rc" = 0 ] && code=200
  pub "line.$LINE.time.$NODE" step.end "$code" "$attempt" "$dur" "$rc"
  [ "$dur" -le "$BUDGET" ] || pub "line.$LINE.event.step.slow" step.slow SLOW "$attempt" "$dur" "$rc"
  echo "step-time: $LINE/$NODE attempt $attempt code $code ${dur}s budget ${BUDGET}s" >&2
  [ "$rc" = 0 ] && exit 0
  [ "$attempt" -lt "$RETRIES" ] && sleep "$(( attempt * ${STEP_TIME_BACKOFF:-2} ))"
done
exit "$rc"
