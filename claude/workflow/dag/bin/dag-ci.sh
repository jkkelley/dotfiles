#!/usr/bin/env bash
# shellcheck disable=SC2016 # jq filters use $var; they are jq variables, single quotes are the point
# dag-ci.sh - node N8: poll the PR's gate checks until every required check is green.
#   name:       dag-ci.sh
#   purpose:    node N8 of docs/design/dag-state-nodes.spec.xml: read pr.number from the run state, poll `gh pr checks` every
#               ci_poll_seconds, exit 0 once each required_checks name is pass, exit 1 when one fails or ci_timeout_seconds passes
#   inputs:     --run <run-id> (or RUN), --node <id> (accepted, default N8), --out <file> (default: output.path of
#               <run>/nodes.lock/N8.json, else <run>/records/N8.ci.json); DAG_CONFIG (ci_poll_seconds default 30,
#               ci_timeout_seconds default 1800, required_checks), DAG_STATE_DIR, DAG_GH (gh), DAG_SLEEP, DAG_CI_POLL / DAG_CI_TIMEOUT
#   outputs:    gate results JSON (name, bucket per required check) at --out; one line per poll on stdout;
#               exit 0 all green, 1 red or timeout (apply retries N8 3 times, then DG-FAILED), 2 usage, 3 DG-SCHEMA
#   writes-to:  the output file inside the run directory only; never state.json
#   cleanup:    removes its temp file on exit
# Spec: docs/design/dag-state-nodes.spec.xml node N8; dag-state.spec.xml rule R7 and config ci_poll_seconds, ci_timeout_seconds.
#
# BREADCRUMB (WO-20261016-0797, dag-state T9). Idempotent: it only reads gh, so apply may re-run it. A red check is exit 1 at
# once instead of polling to the timeout, so the 3 attempts of apply give a flaky job its re-run. Pending and a gh read that
# fails keep polling. An empty required_checks list is refused (exit 2): green with nothing to check would let N9 merge blind.
# Cost: a check name missing from the PR counts as pending until the timeout.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=dag-lib.sh disable=SC1091
. "$HERE/dag-lib.sh"

run="${RUN:-}"; node=N8; out=""
usage() { dag_err "usage: dag-ci.sh --run <run-id> [--node N8] [--out file]"; exit 2; }
while [ $# -gt 0 ]; do
  case "$1" in
    --run) run="${2:-}"; shift 2 ;;
    --node) node="${2:-}"; shift 2 ;;
    --out) out="${2:-}"; shift 2 ;;
    *) usage ;;
  esac
done
[ -n "$run" ] || usage
rd="$(dag_run_dir "$run")" || exit 2
st="$(dag_read "$run")" || exit $?
gh="${DAG_GH:-gh}"
poll="${DAG_CI_POLL:-$(dag_cfg ci_poll_seconds 30)}"
limit="${DAG_CI_TIMEOUT:-$(dag_cfg ci_timeout_seconds 1800)}"
[[ $poll =~ ^[0-9]+$ && $limit =~ ^[0-9]+$ ]] || { dag_err "dag-ci: bad poll/timeout '$poll' '$limit'"; exit 2; }
pr="$(jq -r '.pr.number // empty' <<<"$st")"
[ -n "$pr" ] || { dag_err "dag-ci: run $run has no pr.number (N6 not done)"; exit 2; }
mapfile -t req < <(jq -r '.required_checks // [] | .[]' "${DAG_CONFIG:-/dev/null}" 2>/dev/null)
[ "${#req[@]}" -gt 0 ] || { dag_err "dag-ci: required_checks is empty in DAG_CONFIG"; exit 2; }
if [ -z "$out" ]; then
  out="$(jq -r '.output.path // empty' "$rd/nodes.lock/$node.json" 2>/dev/null)"
  case "$out" in "") out="$rd/records/$node.ci.json" ;; /*) ;; *) out="$rd/$out" ;; esac
fi
mkdir -p "$(dirname "$out")"
tmp="$(mktemp "$(dirname "$out")/.ci.XXXXXX")"; trap 'rm -f "$tmp"' EXIT

waited=0
while :; do
  if raw="$($gh pr checks "$pr" --json name,bucket 2>/dev/null)" && jq -e 'type == "array"' <<<"$raw" >/dev/null 2>&1; then
    res="$(jq -c --argjson req "$(printf '%s\n' "${req[@]}" | jq -R . | jq -sc .)" \
      '. as $all | [$req[] | . as $n | {name: $n, bucket: (([$all[] | select(.name == $n) | .bucket][0]) // "absent")}]' <<<"$raw")"
    red="$(jq -r '[.[] | select(.bucket == "fail" or .bucket == "cancel") | .name] | join(",")' <<<"$res")"
    pend="$(jq -r '[.[] | select(.bucket != "pass") | .name] | length' <<<"$res")"
    if [ -n "$red" ]; then
      jq -n --argjson r "$res" --arg at "$(dag_now)" '{pr:'"$pr"', result:"red", checks:$r, at:$at}' >"$tmp" && mv "$tmp" "$out"
      printf 'DG-CI red pr=%s checks=%s\n' "$pr" "$red"; exit 1
    fi
    if [ "$pend" = 0 ]; then
      jq -n --argjson r "$res" --arg at "$(dag_now)" '{pr:'"$pr"', result:"green", checks:$r, at:$at}' >"$tmp" && mv "$tmp" "$out"
      printf 'DG-CI green pr=%s\n' "$pr"; exit 0
    fi
    printf 'DG-CI pending pr=%s waited=%ss\n' "$pr" "$waited"
  else
    printf 'DG-CI unreadable pr=%s waited=%ss\n' "$pr" "$waited"
  fi
  if [ "$waited" -ge "$limit" ]; then
    printf 'DG-CI timeout pr=%s after=%ss\n' "$pr" "$waited"; exit 1
  fi
  ${DAG_SLEEP:-sleep} "$poll"; waited=$((waited + poll))
  [ "$poll" -gt 0 ] || waited=$((waited + 1))
done
