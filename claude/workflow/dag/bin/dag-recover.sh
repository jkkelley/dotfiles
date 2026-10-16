#!/usr/bin/env bash
# dag-recover.sh - resume a DAG run from its last good node.
#   name:       dag-recover.sh
#   purpose:    the `recover` verb of docs/design/dag-state.spec.xml: clear a dead lock, reset nodes left DG-RUNNING with no
#               live seat, run plan then apply, and resume or swap a dead build seat
#   inputs:     --run <run-id> (or RUN); DAG_STATE_DIR / DAG_CONFIG / DAG_LOCK_STALE_SECONDS as dag-lib.sh;
#               DAG_PLAN, DAG_APPLY (verb scripts, default siblings dag-plan.sh, dag-apply.sh); DAG_JOBS (apply JOBS, default 1);
#               DAG_SEAT_ALIVE (command: <node> exits 0 when a live seat is on it; unset means no seat is alive);
#               DAG_BUILD_NODES (nodes that have a build seat, default "N4"); DAG_SEAT_RESUME (command given <node> <run-dir>
#               <checkpoint-file>: seat-watch resume or hot swap); DAG_CHECKPOINT_CMD (prints the last checkpoint, default
#               checkpoint.sh read --top 1)
#   outputs:    stdout: one line per action and one DR line per node it could not safely re-run; exit 0 run resumed,
#               1 still blocked with the reason on stdout, 2 bad usage, 3 DG-SCHEMA
#   writes-to:  <state_dir>/runs/<run-id>/{state.json,ledger.jsonl} only, through dag-lib.sh
#   cleanup:    holds the run lock only while it writes; none left behind
# Spec: docs/design/dag-state.spec.xml <verb name="recover">, rules R1 R4 R6; design docs/design/dag-state.md section recover.
#
# BREADCRUMB (WO-20261016-61f0, dag-state T5). A DG-RUNNING node whose declaration is not idempotent (N6 open PR, N9 merge)
# becomes DG-BLOCKED with a DR line and is never re-run: re-running N6 would open a second PR. A node with no declaration in
# nodes.lock is treated as non-idempotent for the same reason. A lock is cleared only when it is older than lock_stale_seconds
# AND its holder pid is gone; a slow live holder is reported, not broken (dag-lib.sh breadcrumb). Cost: a node blocked here needs
# the orchestrator to look at the world before it moves.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=dag-lib.sh disable=SC1091
. "$HERE/dag-lib.sh"

run="${RUN:-}"
while [ $# -gt 0 ]; do
  case "$1" in
    --run) run="${2:-}"; shift 2 ;;
    *) dag_err "usage: dag-recover.sh --run <run-id>"; exit 2 ;;
  esac
done
[ -n "$run" ] || { dag_err "usage: dag-recover.sh --run <run-id>"; exit 2; }
rd="$(dag_run_dir "$run")" || exit 2
[ -f "$rd/state.json" ] || { dag_err "dag-recover: no state for $run"; exit 2; }

blocked=0
say() { printf '%s\n' "$*"; }
stop() { say "BLOCKED $*"; dag_ledger "$run" recover DG-BLOCKED "" "$*" || true; exit 1; }

# 1. the lock.
if [ -d "$rd/lock" ]; then
  stale="${DAG_LOCK_STALE_SECONDS:-$(dag_cfg lock_stale_seconds 600)}"
  t0="$(jq -r '.epoch // empty' "$rd/lock/holder.json" 2>/dev/null || true)"
  [ -n "$t0" ] || t0="$(stat -c %Y "$rd/lock" 2>/dev/null || date +%s)"
  pid="$(jq -r '.pid // empty' "$rd/lock/holder.json" 2>/dev/null || true)"
  age=$(($(date +%s) - t0))
  if [ "$age" -le "$stale" ]; then stop "DG-LOCK-HELD $run age=${age}s stale_after=${stale}s"; fi
  if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then stop "DG-LOCK-HELD $run holder pid=$pid is alive age=${age}s"; fi
  rm -rf "$rd/lock"
  dag_ledger "$run" unlock DG-LOCK-STALE "" "cleared lock age=${age}s holder pid=${pid:-none}"
  say "unlock DG-LOCK-STALE age=${age}s pid=${pid:-none}"
fi

# 2. nodes left DG-RUNNING with no live seat.
dag_read "$run" >/dev/null || exit 3
alive() { [ -n "${DAG_SEAT_ALIVE:-}" ] && $DAG_SEAT_ALIVE "$1" >/dev/null 2>&1; }
idempotent() { jq -er '.retry.idempotent' "$rd/nodes.lock/$1.node.json" 2>/dev/null || echo false; }
drift_code() { case "$1" in N6|N9) echo DR-PR ;; N7) echo DR-TICKET ;; *) echo DR-OUTPUT ;; esac; }
dead_build=""
while read -r node; do
  [ -n "$node" ] || continue
  alive "$node" && continue
  case " ${DAG_BUILD_NODES:-N4} " in *" $node "*) dead_build="$dead_build $node" ;; esac
  if [ "$(idempotent "$node")" = true ]; then
    dag_write "$run" '.nodes[$n].status = "DG-READY"' --arg n "$node" || exit $?
    dag_ledger "$run" recover DG-READY "$node" "no live seat; idempotent, reset to DG-READY"
    say "reset $node DG-RUNNING -> DG-READY"
  else
    dag_write "$run" '.nodes[$n].status = "DG-BLOCKED" | .nodes[$n].error_code = "DG-BLOCKED"' --arg n "$node" || exit $?
    say "$(drift_code "$node") node=$node state=DG-RUNNING world=no-live-seat, not idempotent, not re-run"
    dag_ledger "$run" recover DG-BLOCKED "$node" "no live seat; not idempotent, ask the world before any re-run"
    blocked=1
  fi
done < <(dag_read "$run" | jq -r '.nodes | to_entries[] | select(.value.status == "DG-RUNNING") | .key')

# a node already DG-BLOCKED keeps the run blocked, so a second recover lands where the first did.
[ "$(dag_read "$run" | jq '[.nodes[] | select(.status == "DG-BLOCKED")] | length')" = 0 ] || blocked=1

# 3. a dead build seat: resume or hot swap, with the node bundle and the last checkpoint.
for node in $dead_build; do
  [ "$(idempotent "$node")" = true ] || continue
  if [ -n "${DAG_SEAT_RESUME:-}" ]; then
    ckpt="$(mktemp "$rd/.checkpoint.XXXXXX")"
    ${DAG_CHECKPOINT_CMD:-bash claude/skills/context-compaction/scripts/checkpoint.sh read --top 1} >"$ckpt" 2>/dev/null || true
    if $DAG_SEAT_RESUME "$node" "$rd" "$ckpt"; then
      dag_ledger "$run" recover DG-RUNNING "$node" "dead seat resumed or swapped"
      say "seat $node resumed"
    else
      dag_ledger "$run" recover DG-BLOCKED "$node" "seat resume failed"
      say "BLOCKED seat $node resume failed"; blocked=1
    fi
    rm -f "$ckpt"
  else
    say "seat $node dead, no DAG_SEAT_RESUME set; node left DG-READY for apply"
  fi
done

# 4. plan, then apply.
plan="${DAG_PLAN:-$HERE/dag-plan.sh}"; apply="${DAG_APPLY:-$HERE/dag-apply.sh}"
[ -f "$plan" ] || stop "plan script missing: $plan"
[ -f "$apply" ] || stop "apply script missing: $apply"
bash "$plan" --run "$run" || stop "plan failed exit=$?"
rc=0; bash "$apply" --run "$run" --jobs "${DAG_JOBS:-1}" || rc=$?
[ "$rc" = 0 ] || stop "apply exit=$rc"
if [ "$blocked" = 1 ]; then stop "run resumed with nodes still DG-BLOCKED"; fi
dag_ledger "$run" recover DG-READY "" "run resumed"
say "run $run resumed"
