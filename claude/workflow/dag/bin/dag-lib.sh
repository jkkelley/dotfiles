# shellcheck shell=bash
# shellcheck disable=SC2016 # jq filters use $var; they are jq variables, single quotes are the point
# dag-lib.sh - the run state library for the DAG: init, read, write, lock, serial, ledger.
#   name:       dag-lib.sh
#   purpose:    the only writer of <state_dir>/runs/<run-id>/{state.json,ledger.jsonl}; every verb and node script calls it
#   inputs:     DAG_STATE_DIR (or "state_dir" in the file DAG_CONFIG names), DAG_LOCK_STALE_SECONDS (or "lock_stale_seconds"
#               in the config; default 600), DAG_RETRY_WAITS (seconds, default "10 30 90"), DAG_SLEEP (waiter, default sleep),
#               DAG_EXPECT_SERIAL (the serial the writer read; a mismatch aborts the write), DAG_SCHEMAS (schema dir),
#               DAG_VALIDATE (validate-schema.sh path)
#   outputs:    JSON on stdout for read; status codes on stderr; exit 0 ok, 2 usage, 3 DG-SCHEMA, 4 DG-STATE-STALE,
#               5 DG-LOCK-HELD, 6 DG-LOCK-STALE
#   writes-to:  <state_dir>/runs/<run-id>/ only (outside the repository)
#   cleanup:    dag_unlock removes lock/; nothing else is left behind but the temp file of a write that failed, removed on failure
# Sourced by the verbs (sets no shell options, so the caller's `set -euo pipefail` governs) or run as `dag-lib.sh <fn> args`.
# Spec: docs/design/dag-state.spec.xml <rules> R1 R2 R3 R4 R5 and <state>; schemas claude/workflow/dag/schemas/{state,ledger}.schema.json.
#
# BREADCRUMB (WO-20261016-05db, dag-state T1). Rules R2 and R3 are one code path on purpose: dag_write takes the lock, compares
# the serial the writer read with the serial on disk, applies the jq filter to a temp file in the run directory, validates it,
# then renames. A lock older than lock_stale_seconds is reported as DG-LOCK-STALE and never broken here (spec: "never broken
# silently"); `recover` clears it with an unlock ledger row. Rejected: breaking a stale lock on sight, which would let two
# writers in when a slow one is merely slow. Cost: a crashed writer blocks the run until recover runs.

_DAG_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DAG_SCHEMAS="${DAG_SCHEMAS:-$_DAG_LIB_DIR/../schemas}"
DAG_VALIDATE="${DAG_VALIDATE:-$_DAG_LIB_DIR/../../tools/validate-schema.sh}"
DAG_RUN_ID_RE='^dagrun-[0-9]{8}T[0-9]{6}Z-[a-z0-9-]+$'
DAG_LOCKED_RUN=""

dag_now() { date -u +%Y-%m-%dT%H:%M:%SZ; }

dag_err() { printf '%s\n' "$*" >&2; }

# dag_cfg <field> [default] - config field from the file DAG_CONFIG names, else the default.
dag_cfg() {
  local v=""
  if [ -n "${DAG_CONFIG:-}" ] && [ -f "$DAG_CONFIG" ]; then v="$(jq -r --arg f "$1" '.[$f] // empty' "$DAG_CONFIG")"; fi
  printf '%s' "${v:-${2:-}}"
}

dag_state_dir() {
  local d="${DAG_STATE_DIR:-$(dag_cfg state_dir)}"
  [ -n "$d" ] || { dag_err "dag-lib: no state_dir (set DAG_STATE_DIR or DAG_CONFIG)"; return 2; }
  printf '%s' "$d"
}

# dag_run_dir <run-id> - validates the id, prints <state_dir>/runs/<run-id>.
dag_run_dir() {
  [[ ${1:-} =~ $DAG_RUN_ID_RE ]] || { dag_err "dag-lib: bad run id '${1:-}'"; return 2; }
  local s; s="$(dag_state_dir)" || return 2
  printf '%s/runs/%s' "$s" "$1"
}

# dag_validate <schema-name> <file> - exit 3 (DG-SCHEMA) when the file fails its schema.
dag_validate() {
  local out
  if ! out="$(bash "$DAG_VALIDATE" "$DAG_SCHEMAS/$1.schema.json" "$2" 2>&1)"; then
    dag_err "DG-SCHEMA $1: $out"; return 3
  fi
}

# dag_retry <attempts> <cmd...> - runs cmd up to <attempts> times (rule R4, at most 3), waiting DAG_RETRY_WAITS between tries,
# never after the last. Returns the last exit code.
dag_retry() {
  local attempts="$1" n=0 rc=0; shift
  local -a waits; read -r -a waits <<<"${DAG_RETRY_WAITS:-10 30 90}"
  while [ "$n" -lt "$attempts" ]; do
    n=$((n + 1))
    "$@" && return 0
    rc=$?
    [ "$n" -lt "$attempts" ] || break
    ${DAG_SLEEP:-sleep} "${waits[$((n - 1 < ${#waits[@]} ? n - 1 : ${#waits[@]} - 1))]}"
  done
  return "$rc"
}

_dag_try_lock() {
  local d="$1/lock"
  if mkdir "$d" 2>/dev/null; then
    printf '{"pid":%s,"at":"%s","epoch":%s}\n' "$$" "$(dag_now)" "$(date +%s)" >"$d/holder.json"
    return 0
  fi
  local stale age t0
  stale="${DAG_LOCK_STALE_SECONDS:-$(dag_cfg lock_stale_seconds 600)}"
  t0="$(jq -r '.epoch // empty' "$d/holder.json" 2>/dev/null)"
  [ -n "$t0" ] || t0="$(stat -c %Y "$d" 2>/dev/null || date +%s)"
  age=$(($(date +%s) - t0))
  if [ "$age" -gt "$stale" ]; then dag_err "DG-LOCK-STALE $d age=${age}s"; return 6; fi
  return 5
}

# dag_lock <run-id> - takes the run lock (mkdir, atomic everywhere). Tries 3 times with the retry waits; 5 DG-LOCK-HELD, 6 DG-LOCK-STALE.
dag_lock() {
  local rd rc=0; rd="$(dag_run_dir "$1")" || return 2
  [ "$DAG_LOCKED_RUN" = "$1" ] && return 0
  [ -d "$rd" ] || { dag_err "dag-lib: no run $1"; return 2; }
  _dag_try_lock "$rd" || rc=$?
  if [ "$rc" = 5 ]; then
    dag_retry 3 _dag_try_lock_quiet "$rd" && rc=0 || rc=$?
  fi
  case "$rc" in
    0) DAG_LOCKED_RUN="$1" ;;
    5) dag_err "DG-LOCK-HELD $1" ;;
  esac
  return "$rc"
}
_dag_try_lock_quiet() { _dag_try_lock "$1" 2>/dev/null; }

# dag_unlock <run-id> - releases the lock only if this shell holds it.
dag_unlock() {
  [ "$DAG_LOCKED_RUN" = "$1" ] || return 0
  local rd; rd="$(dag_run_dir "$1")" || return 2
  rm -rf "$rd/lock"
  DAG_LOCKED_RUN=""
}

# dag_read <run-id> - prints state.json, validated against the schema (R1).
dag_read() {
  local rd f; rd="$(dag_run_dir "$1")" || return 2
  f="$rd/state.json"
  [ -f "$f" ] || { dag_err "dag-lib: no state for $1"; return 2; }
  dag_validate state "$f" || return 3
  cat "$f"
}

# dag_serial <run-id> - prints the serial on disk.
dag_serial() { dag_read "$1" | jq -r '.serial'; }

# dag_ledger <run-id> <verb> <code> [node] [detail] - appends one validated row to ledger.jsonl (append-only history).
dag_ledger() {
  local rd row tmp serial=0; rd="$(dag_run_dir "$1")" || return 2
  [ -f "$rd/state.json" ] && serial="$(jq -r '.serial' "$rd/state.json")"
  row="$(jq -cn --arg at "$(dag_now)" --arg verb "$2" --arg code "$3" --arg run "$1" --argjson serial "$serial" \
    --arg node "${4:-}" --arg detail "${5:-}" \
    '{schema_version:1, at:$at, verb:$verb, code:$code, run_id:$run, serial:$serial}
     + (if $node == "" then {} else {node:$node} end) + (if $detail == "" then {} else {detail:$detail} end)')" || return 2
  tmp="$(mktemp "$rd/.ledger-row.XXXXXX")" || return 1
  printf '%s\n' "$row" >"$tmp"
  if ! dag_validate ledger "$tmp"; then rm -f "$tmp"; return 3; fi
  rm -f "$tmp"
  printf '%s\n' "$row" >>"$rd/ledger.jsonl"
}

# dag_write <run-id> <jq-filter> [jq args...] - the one way state changes (R2, R3). Under the run lock: abort DG-STATE-STALE
# (4) if DAG_EXPECT_SERIAL is set and differs from disk; apply the filter, bump serial and updated_at, validate, rename.
dag_write() {
  local run="$1" filter="$2" rd tmp cur rc=0 held=0; shift 2
  rd="$(dag_run_dir "$run")" || return 2
  [ "$DAG_LOCKED_RUN" = "$run" ] && held=1
  dag_lock "$run" || return $?
  cur="$(jq -r '.serial' "$rd/state.json" 2>/dev/null)" || cur=""
  if [ -n "${DAG_EXPECT_SERIAL:-}" ] && [ "$DAG_EXPECT_SERIAL" != "$cur" ]; then
    dag_err "DG-STATE-STALE $run expected=$DAG_EXPECT_SERIAL disk=$cur"; rc=4
  else
    tmp="$(mktemp "$rd/.state.XXXXXX")" || rc=1
    if [ "$rc" = 0 ]; then
      if jq --arg now "$(dag_now)" "$@" "($filter) | .serial += 1 | .updated_at = \$now" "$rd/state.json" >"$tmp" \
        && dag_validate state "$tmp"; then
        mv "$tmp" "$rd/state.json"
      else
        rc=$?; [ "$rc" = 3 ] || rc=2; rm -f "$tmp"
      fi
    fi
  fi
  [ "$held" = 1 ] || dag_unlock "$run"
  return "$rc"
}

# dag_init <run-id> <ticket-id> <ticket-title> <design-id> <design-version> <design-sha256> <worktree-path> <branch> [slot]
# Creates the run directory and a validated state.json at serial 0, and an init ledger row. Idempotent: an existing run
# for the same ticket is left as it is (exit 0, no second row); an existing run for another ticket is exit 2.
dag_init() {
  [ $# -ge 8 ] || { dag_err "usage: dag_init <run-id> <ticket-id> <title> <design-id> <design-version> <design-sha256> <worktree> <branch> [slot]"; return 2; }
  local run="$1" rd tmp lineage; rd="$(dag_run_dir "$run")" || return 2
  if [ -f "$rd/state.json" ]; then
    [ "$(jq -r '.ticket.id' "$rd/state.json")" = "$2" ] && return 0
    dag_err "dag-lib: run $run exists for another ticket"; return 2
  fi
  mkdir -p "$rd/records" || return 1
  lineage="$(cat /proc/sys/kernel/random/uuid 2>/dev/null || od -An -N16 -tx1 /dev/urandom | tr -d ' \n')"
  tmp="$(mktemp "$rd/.state.XXXXXX")" || return 1
  jq -n --arg run "$run" --arg lin "$lineage" --arg tid "$2" --arg tt "$3" --arg did "$4" --arg dv "$5" --arg dsha "$6" \
    --arg wp "$7" --arg br "$8" --arg slot "${9:-}" --arg now "$(dag_now)" \
    '{schema_version:1, run_id:$run, serial:0, lineage:$lin, design:{id:$did, version:$dv, sha256:$dsha},
      ticket:{id:$tid, title:$tt}, worktree:{path:$wp, branch:$br, slot:(if $slot == "" then null else $slot end)},
      pr:null, nodes:{}, updated_at:$now}' >"$tmp"
  if ! dag_validate state "$tmp"; then rm -f "$tmp"; rmdir "$rd/records" "$rd" 2>/dev/null; return 3; fi
  mv "$tmp" "$rd/state.json"
  dag_ledger "$run" init DG-PENDING "" "run created for $2"
}

# dag_status <run-id> - one line per fact, then one per node.
dag_status() {
  local st; st="$(dag_read "$1")" || return $?
  jq -r '"run \(.run_id) serial \(.serial) ticket \(.ticket.id) design \(.design.id)@\(.design.version)",
         (.nodes | to_entries[] | "  \(.key) \(.value.status) attempts=\(.value.attempts)")' <<<"$st"
}

# Run directly: dag-lib.sh <function> args.
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  set -euo pipefail
  fn="${1:-}"; [ -n "$fn" ] || { dag_err "usage: dag-lib.sh <init|read|write|serial|ledger|status> args"; exit 2; }
  shift
  case "$fn" in
    init) dag_init "$@" ;; read) dag_read "$@" ;; write) dag_write "$@" ;;
    serial) dag_serial "$@" ;; ledger) dag_ledger "$@" ;; status) dag_status "$@" ;;
    *) dag_err "dag-lib: unknown function '$fn'"; exit 2 ;;
  esac
fi
