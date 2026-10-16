#!/usr/bin/env bash
# shellcheck disable=SC2016 # jq programs are single-quoted on purpose
# ci-events.sh - GitHub Actions run start and end onto the bus (item 37), polled from the local machine.
# name: ci-events.sh
# purpose: turn `gh run list` into ci start and end events so node-timing sees CI durations
# inputs: config/time-budgets.json .ci_events, TM_* env
# outputs: one status line per published event on stdout
# writes-to: NATS line.all.event.node.{start,end}, the ci-events state file (ci_events.state)
# cleanup: delete the state file to re-publish; make timing-down
#
# usage: ci-events.sh [--once]      (one poll either way; the loop in timing.mk calls it with --once)
#   a run first seen not completed -> start; a run seen completed and not yet ended -> end (rc 0 on success else 1,
#   duration_s = updatedAt - createdAt, budget_s from tm_limit budget_s ci <node>). The state file dedupes: re-runs publish nothing.
# env: GH_BIN (default gh), TM_CI_STATE (state file override), TM_BUDGETS, SW_PUB_CMD.
#
# BREADCRUMB - a local poller, not a runner-side step.
# What broke: nothing yet; the rejected alternative. A workflow step publishing to NATS cannot work: GitHub runners cannot reach the local bus.
# Why this fix: `gh run list` is the one view of every run, so polling it from here needs no runner change. Cost: events land
#   up to one poll late, and a run that starts and ends between two polls publishes start and end together.
set -uo pipefail
HERE="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
# shellcheck source=timing/lib.sh disable=SC1091
. "$HERE/lib.sh"
GH="${GH_BIN:-gh}"
LIMIT="$(tm_cfg '.ci_events.limit')"
STATE="${TM_CI_STATE:-$(sw_expand "$(tm_cfg '.ci_events.state')")}"
mkdir -p "$(dirname "$STATE")"; [ -s "$STATE" ] || echo '{}' > "$STATE"

gh_runs() { # gh_runs <repo>: run list JSON, retried 3 times
  local out
  for _ in 1 2 3; do
    out="$("$GH" run list -R "$1" --limit "$LIMIT" --json databaseId,name,status,conclusion,createdAt,updatedAt,headBranch 2>&1)" && { printf '%s' "$out"; return 0; }
    sleep "${CI_EVENTS_RETRY_SLEEP:-2}"
  done
  echo "A2A-003 gh run list -R $1 failed 3 times: $out" >&2; return 1
}

ci_import() { # ci_import <repo> <id>: publish every step-time-* artifact line of a completed run verbatim; rc 0 done, 1 download failed
  local repo="$1" id="$2" tmp out f line s p tries=0 got=1
  tmp="$(mktemp -d)"
  while [ "$tries" -lt 3 ]; do
    tries=$((tries + 1))
    if out="$("$GH" run download "$id" -R "$repo" -p 'step-time-*' -D "$tmp" 2>&1)"; then got=0; break; fi
    case "$out" in *'no artifact matches'*) rm -rf "$tmp"; return 0 ;; esac
    [ "$tries" -lt 3 ] && sleep "${CI_EVENTS_RETRY_SLEEP:-2}"
  done
  if [ "$got" = 1 ]; then
    echo "A2A-003 gh run download $id -R $repo failed 3 times: $out" >&2; rm -rf "$tmp"; return 1
  fi
  for f in "$tmp"/*/step-time.jsonl; do
    [ -f "$f" ] || continue
    while IFS= read -r line || [ -n "$line" ]; do
      [ -n "$line" ] || continue
      s="$(jq -r .subject <<<"$line")"; p="$(jq -c .payload <<<"$line")"
      sw_pub "$s" "$p" || echo "ci-events: publish to $s failed" >&2
    done < "$f"
  done
  rm -rf "$tmp"; return 0
}

rc=0
while IFS= read -r repo; do
  runs="$(gh_runs "$repo")" || { rc=1; continue; }
  name="${repo##*/}"
  while IFS= read -r run; do
    id="$(jq -r .databaseId <<<"$run")"; key="$repo#$id"; node="ci-$name-$id"
    seen="$(jq -r --arg k "$key" '.[$k] // empty' "$STATE")"
    [ "$seen" = imported ] && continue
    if [ "$seen" != start ]; then
      tm_event all "$node" ci "$id" start "$(jq -c '{workflow:.name,branch:.headBranch}' <<<"$run")"
      echo "start $node"
      seen=start; jq --arg k "$key" '.[$k]="start"' "$STATE" > "$STATE.tmp" && mv "$STATE.tmp" "$STATE"
    fi
    [ "$(jq -r .status <<<"$run")" = completed ] || continue
    if [ "$seen" != end ]; then
      d="$(jq -r '((.updatedAt|fromdateiso8601) - (.createdAt|fromdateiso8601))' <<<"$run")"
      r=1; [ "$(jq -r .conclusion <<<"$run")" = success ] && r=0
      tm_event all "$node" ci "$id" end "$(jq -nc --argjson r "$r" --argjson d "$d" --argjson b "$(tm_limit budget_s ci "$node")" '{rc:$r,duration_s:$d,budget_s:$b}')"
      echo "end $node rc=$r duration_s=$d"
      jq --arg k "$key" '.[$k]="end"' "$STATE" > "$STATE.tmp" && mv "$STATE.tmp" "$STATE"
    fi
    if ci_import "$repo" "$id"; then
      jq --arg k "$key" '.[$k]="imported"' "$STATE" > "$STATE.tmp" && mv "$STATE.tmp" "$STATE"
      echo "import $node"
    fi
  done < <(jq -c '.[]' <<<"$runs")
done < <(tm_cfg '.ci_events.repos[]')
exit "$rc"
