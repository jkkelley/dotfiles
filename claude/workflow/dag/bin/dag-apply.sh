#!/usr/bin/env bash
# shellcheck disable=SC2016 # jq filters use $var; they are jq variables, single quotes are the point
# dag-apply.sh - the apply verb: runs the ready set of a DAG run and writes the result to the state file.
#   name:       dag-apply.sh
#   purpose:    take the run lock, recompute the ready set, run up to JOBS ready nodes, record output/hashes/proofs, retry per
#               node, then DG-FAILED + DG-HANDOFF with a fix ticket carrying the reproduction (spec verb "apply", rules R4, R8)
#   inputs:     --run RUN (required); --jobs N (else DAG_JOBS, else "jobs" in DAG_CONFIG, else 1); --config FILE (else DAG_CONFIG);
#               DAG_STATE_DIR, DAG_REPO_ROOT (where node scripts resolve; default: the repo this script lives in),
#               DAG_HANDOFF_CMD (fix ticket command; gets the handoff file path as $1; default files a work-order),
#               DAG_RETRY_WAITS / DAG_SLEEP as in dag-lib.sh
#   outputs:    one line per node run on stdout; exit 0 ready set ran with no failure, 1 a node ended DG-FAILED, 2 usage,
#               3 DG-SCHEMA, 5 DG-LOCK-HELD (or DG-LOCK-STALE, which only recover clears)
#   writes-to:  <state_dir>/runs/<run-id>/{state.json,ledger.jsonl,records/} only (outside the repository)
#   cleanup:    releases the run lock on every exit path; per-node scratch files under records/ are removed after each batch
# Spec: docs/design/dag-state.spec.xml <verb name="apply">; node declarations: <run>/nodes.lock/<node>.json (node.schema.json).
# A node script is run as: bash <repo-root>/<node.script> --run RUN --node NODE, with DAG_CONFIG and DAG_STATE_DIR exported.
#
# BREADCRUMB (WO-20261016-141d, dag-state T3). Scripts of one batch run in parallel as background jobs of THIS script, but
# every state write happens afterwards, one at a time, from this shell: dag-lib holds the lock per shell, so a write from a
# parallel subshell would run outside the lock and lose a proof (rule R3). Rejected: letting each job write its own result.
# Cost: a finished node's DG-DONE lands when its whole batch finishes, not the instant it does.

set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=dag-lib.sh disable=SC1091
. "$DIR/dag-lib.sh"

RUN=""; JOBS=""
while [ $# -gt 0 ]; do
  case "$1" in
    --run) RUN="${2:-}"; shift 2 ;;
    --jobs) JOBS="${2:-}"; shift 2 ;;
    --config) DAG_CONFIG="${2:-}"; export DAG_CONFIG; shift 2 ;;
    *) dag_err "usage: dag-apply.sh --run RUN [--jobs N] [--config FILE]"; exit 2 ;;
  esac
done
[ -n "$RUN" ] || { dag_err "usage: dag-apply.sh --run RUN [--jobs N] [--config FILE]"; exit 2; }
JOBS="${JOBS:-${DAG_JOBS:-$(dag_cfg jobs 1)}}"
[[ $JOBS =~ ^[1-9][0-9]*$ ]] || { dag_err "dag-apply: bad jobs '$JOBS'"; exit 2; }
ROOT="${DAG_REPO_ROOT:-$(cd "$DIR/../../../.." && pwd)}"
RD="$(dag_run_dir "$RUN")" || exit 2
DAG_STATE_DIR="$(dag_state_dir)" || exit 2
export DAG_STATE_DIR

lock_rc=0
dag_lock "$RUN" || lock_rc=$?
case "$lock_rc" in 0) ;; 2) exit 2 ;; *) exit 5 ;; esac
trap 'dag_unlock "$RUN"' EXIT

decl() { cat "$RD/nodes.lock/$1.json"; }
node_ids() { local f; for f in "$RD"/nodes.lock/*.json; do [ -f "$f" ] && basename "$f" .json; done; return 0; }
status_of() { jq -r --arg n "$1" '.nodes[$n].status // "DG-PENDING"' <<<"$ST"; }

# ready_set - ids whose deps are all done/skipped and whose own status is pending or ready.
ready_set() {
  local n s d dep ok
  for n in $(node_ids); do
    s="$(status_of "$n")"
    case "$s" in DG-PENDING | DG-READY) ;; *) continue ;; esac
    ok=1
    for dep in $(jq -r '.depends_on[]' "$RD/nodes.lock/$n.json"); do
      d="$(status_of "$dep")"
      case "$d" in DG-DONE | DG-SKIPPED) ;; *) ok=0 ;; esac
    done
    [ "$ok" = 1 ] && printf '%s\n' "$n"
  done
  return 0
}
# blocked_set - pending nodes with a dependency that ended failed or blocked.
blocked_set() {
  local n s dep d
  for n in $(node_ids); do
    s="$(status_of "$n")"
    case "$s" in DG-PENDING | DG-READY) ;; *) continue ;; esac
    for dep in $(jq -r '.depends_on[]' "$RD/nodes.lock/$n.json"); do
      d="$(status_of "$dep")"
      case "$d" in DG-FAILED | DG-BLOCKED) printf '%s\n' "$n"; break ;; esac
    done
  done
  return 0
}

sha_of() { if [ -f "$1" ]; then sha256sum "$1" | cut -d' ' -f1; fi; }
abs_in_run() { case "$1" in /*) printf '%s' "$1" ;; *) printf '%s/%s' "$RD" "$1" ;; esac; }

# attempt_node <node> - one try: the script must exit 0 and leave its declared output.
attempt_node() {
  local n="$1" script out
  script="$(decl "$n" | jq -r '.script')"
  out="$(abs_in_run "$(decl "$n" | jq -r '.output.path')")"
  bash "$ROOT/$script" --run "$RUN" --node "$n" >>"$RD/records/$n.log" 2>&1 || return 1
  [ -f "$out" ] || { printf 'output missing: %s\n' "$out" >>"$RD/records/$n.log"; return 1; }
}

# run_node <node> - the retry loop of one node, run as a background job. Leaves <node>.rc and <node>.tries in records/.
run_node() {
  local n="$1" max idem tries=0 rc=0 d w
  local -a waits
  d="$(decl "$n")"
  max="$(jq -r '.retry.max' <<<"$d")"; idem="$(jq -r '.retry.idempotent' <<<"$d")"
  read -r -a waits <<<"$(jq -r '.retry.waits_seconds | map(tostring) | join(" ")' <<<"$d")"
  [ "$idem" = true ] || max=0   # R4: a non-idempotent node never retries blindly
  : >"$RD/records/$n.log"
  while :; do
    tries=$((tries + 1))
    if attempt_node "$n"; then rc=0; break; fi
    rc=1
    [ "$tries" -le "$max" ] || break
    w="${waits[$((tries - 1))]:-${waits[$((${#waits[@]} - 1))]:-0}}"
    ${DAG_SLEEP:-sleep} "$w"
  done
  printf '%s' "$tries" >"$RD/records/$n.tries"
  printf '%s' "$rc" >"$RD/records/$n.rc"
}

# handoff <node> - R8: a fix ticket with the reproduction command, its exit code and the last 40 log lines.
handoff() {
  local n="$1" f script
  f="$RD/records/$n.handoff.txt"
  script="$(decl "$n" | jq -r '.script')"
  {
    printf 'run: %s\nnode: %s\nreproduction: bash %s --run %s --node %s\nexit code: %s\nlast 40 log lines:\n' \
      "$RUN" "$n" "$ROOT/$script" "$RUN" "$n" "$(cat "$RD/records/$n.rc")"
    tail -n 40 "$RD/records/$n.log"
  } >"$f"
  if [ -n "${DAG_HANDOFF_CMD:-}" ]; then
    ${DAG_HANDOFF_CMD} "$f" >>"$RD/records/$n.log" 2>&1 || dag_err "dag-apply: handoff command failed for $n (file kept: $f)"
  else
    "$ROOT/claude/skills/work-order/scripts/work-order.sh" new --top-level --type bug \
      --title "dag $RUN node $n failed after retries" \
      --problem "Node $n of $RUN ended DG-FAILED. Reproduction and log: $f" \
      --out "node $n passes on the reproduction command" \
      --owner-words "see $f" --context "filed by dag-apply.sh, spec rule R8" \
      >>"$RD/records/$n.log" 2>&1 || dag_err "dag-apply: work-order new failed for $n (file kept: $f)"
  fi
  dag_ledger "$RUN" apply DG-HANDOFF "$n" "fix ticket filed; reproduction in $f"
}

mkdir -p "$RD/records"
failed=0
while :; do
  ST="$(dag_read "$RUN")" || exit $?
  for n in $(blocked_set); do
    dag_write "$RUN" '.nodes[$n] = ((.nodes[$n] // {version:$v, attempts:0, proofs:[]}) + {status:"DG-BLOCKED", error_code:"DG-BLOCKED"})' \
      --arg n "$n" --arg v "$(decl "$n" | jq -r '.version')" || exit $?
    dag_ledger "$RUN" apply DG-BLOCKED "$n" "a dependency did not finish"
  done
  ST="$(dag_read "$RUN")" || exit $?
  mapfile -t batch < <(ready_set | head -n "$JOBS")
  [ "${#batch[@]}" -gt 0 ] || break

  for n in "${batch[@]}"; do
    d="$(decl "$n")"
    in_path="$(abs_in_run "$(jq -r '.input.path' <<<"$d")")"
    dag_write "$RUN" '.nodes[$n] = ((.nodes[$n] // {proofs:[]}) + {status:"DG-RUNNING", version:$v, started_at:$now2, ended_at:null,
        error_code:null, input:$in, input_sha256:(if $sha == "" then null else $sha end), attempts:((.nodes[$n].attempts // 0) + 1)})' \
      --arg n "$n" --arg v "$(jq -r '.version' <<<"$d")" --arg now2 "$(dag_now)" --arg in "$in_path" --arg sha "$(sha_of "$in_path")" || exit $?
  done
  for n in "${batch[@]}"; do run_node "$n" & done
  wait

  for n in "${batch[@]}"; do
    d="$(decl "$n")"
    tries="$(cat "$RD/records/$n.tries")"; rc="$(cat "$RD/records/$n.rc")"
    out="$(abs_in_run "$(jq -r '.output.path' <<<"$d")")"
    if [ "$rc" = 0 ]; then
      proofs="$(jq -c --arg at "$(dag_now)" '[.checklist[] | {box, proof, at:$at}]' <<<"$d")"
      dag_write "$RUN" '.nodes[$n] += {status:"DG-DONE", attempts:$tries, output:$out, output_sha256:$sha, ended_at:$now2, error_code:null, proofs:$proofs}' \
        --arg n "$n" --argjson tries "$tries" --arg out "$out" --arg sha "$(sha_of "$out")" --arg now2 "$(dag_now)" --argjson proofs "$proofs" || exit $?
      dag_ledger "$RUN" apply DG-DONE "$n" "attempts=$tries"
      printf '%s DG-DONE attempts=%s\n' "$n" "$tries"
    else
      failed=1
      dag_write "$RUN" '.nodes[$n] += {status:"DG-FAILED", attempts:$tries, ended_at:$now2, error_code:"DG-FAILED"}' \
        --arg n "$n" --argjson tries "$tries" --arg now2 "$(dag_now)" || exit $?
      dag_ledger "$RUN" apply DG-FAILED "$n" "attempts=$tries"
      printf '%s DG-FAILED attempts=%s\n' "$n" "$tries"
      handoff "$n"
    fi
    rm -f "$RD/records/$n.rc" "$RD/records/$n.tries"
  done
done
exit "$failed"
