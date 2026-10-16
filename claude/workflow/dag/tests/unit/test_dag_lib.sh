#!/usr/bin/env bash
# name: test_dag_lib.sh
# purpose: proves bin/dag-lib.sh keeps the state, ledger, lock and retry promises of dag-state.spec.xml rules R1-R5.
# inputs: none
# outputs: stdout, exit code
# writes-to: a mktemp scratch dir
# cleanup: removes its own temp dir on exit
# Proves bin/dag-lib.sh does what docs/design/dag-state.spec.xml rules R1-R5 promise. Each check names the failure it rules out:
#   - a half-written state.json after a crash (R2)            - a write that skips the schema (R2)
#   - a last-writer-wins overwrite that drops a proof (R3)     - two writers inside the lock at once (R3)
#   - a stale lock broken silently                             - an init that duplicates or clobbers a run
#   - a ledger row that fails its schema, or is rewritten      - an unbounded retry loop (R4)
# Hermetic: state lives in a temp dir; nothing touches the host's state dir.
set -uo pipefail
R="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
export DAG_STATE_DIR="$T/state" DAG_SLEEP=true DAG_LOCK_STALE_SECONDS=600
# shellcheck source=../../bin/dag-lib.sh disable=SC1091
. "$R/bin/dag-lib.sh"
fail=0; n=0
ok()  { n=$((n+1)); printf 'ok  %s\n' "$1"; }
bad() { n=$((n+1)); fail=$((fail+1)); printf 'FAIL %s\n' "$1"; [ $# -gt 1 ] && printf '     %s\n' "${@:2}"; }
check() { if [ "$1" = "$2" ]; then ok "$3"; else bad "$3" "wanted [$1] got [$2]"; fi; }

RUN=dagrun-20261016T041500Z-t1
SHA="$(printf 'x' | sha256sum | cut -d' ' -f1)"
init() { dag_init "$RUN" WO-1 "A title" dag-state 1.0.0 "$SHA" /wt/a feat/a; }
RD="$DAG_STATE_DIR/runs/$RUN"

init; check 0 $? "init creates the run"
check 0 "$(jq -r .serial "$RD/state.json")" "init starts at serial 0"
check 1 "$(wc -l <"$RD/ledger.jsonl")" "init writes one ledger row"
init; check 0 $? "init again is a no-op"
check 1 "$(wc -l <"$RD/ledger.jsonl")" "init again adds no second ledger row"
dag_init "$RUN" WO-2 t dag-state 1.0.0 "$SHA" /wt/a feat/a 2>/dev/null; check 2 $? "init for another ticket is refused"
dag_init dagrun-bad WO-1 t d 1.0.0 "$SHA" /w b 2>/dev/null; check 2 $? "a bad run id is refused"
dag_read "$RUN" >/dev/null; check 0 $? "read validates and prints state"

L1="$(jq -r .lineage "$RD/state.json")"
dag_write "$RUN" '.nodes.N1 = {status:"DG-DONE",version:"1.0.0",attempts:1,proofs:[{box:"b1",proof:"p",at:"t"}]}'; check 0 $? "write applies the filter"
check 1 "$(dag_serial "$RUN")" "write bumps serial"
check "$L1" "$(jq -r .lineage "$RD/state.json")" "write keeps the lineage"
check "DG-DONE" "$(jq -r .nodes.N1.status "$RD/state.json")" "write landed the node"
dag_write "$RUN" '.nodes.N2 = {status:"DG-PENDING",version:"1.0.0",attempts:0,proofs:[]}'
check 2 "$(dag_serial "$RUN")" "serial climbs per write"

# R3: a writer that read serial 1 must abort when disk is at 2, and the proof already there must survive.
DAG_EXPECT_SERIAL=1 dag_write "$RUN" '.nodes.N1.proofs = []' 2>"$T/e"; check 4 $? "stale serial aborts with exit 4"
grep -q DG-STATE-STALE "$T/e"; check 0 $? "stale serial prints DG-STATE-STALE"
check 1 "$(jq '.nodes.N1.proofs | length' "$RD/state.json")" "the stale write dropped no proof"
DAG_EXPECT_SERIAL=2 dag_write "$RUN" '.nodes.N1.attempts = 2'; check 0 $? "a writer at the current serial succeeds"

# R2: a filter that breaks the schema leaves the old file and no temp file.
before="$(sha256sum "$RD/state.json")"
dag_write "$RUN" '.nodes.N1.status = "nope"' 2>/dev/null; check 3 $? "a schema-breaking write exits 3"
check "$before" "$(sha256sum "$RD/state.json")" "a schema-breaking write leaves the old file"
check 0 "$(find "$RD" -name '.state.*' | wc -l)" "no temp file is left behind"
if dag_write "$RUN" 'this is not jq' 2>/dev/null; then bad "a broken filter fails"; else ok "a broken filter fails"; fi
[ ! -d "$RD/lock" ]; check 0 $? "failed writes release the lock"

# Lock: held, stale, reentrant.
mkdir "$RD/lock"; printf '{"pid":1,"at":"x","epoch":%s}\n' "$(date +%s)" >"$RD/lock/holder.json"
dag_write "$RUN" '.nodes.N1.attempts = 3' 2>"$T/e"; check 5 $? "a held lock gives exit 5"
grep -q DG-LOCK-HELD "$T/e"; check 0 $? "a held lock prints DG-LOCK-HELD"
check 2 "$(jq -r '.nodes.N1.attempts' "$RD/state.json")" "a held lock blocks the write"
printf '{"pid":1,"at":"x","epoch":%s}\n' "$(($(date +%s) - 700))" >"$RD/lock/holder.json"
dag_write "$RUN" '.nodes.N1.attempts = 3' 2>"$T/e"; check 6 $? "a stale lock gives exit 6"
grep -q DG-LOCK-STALE "$T/e"; check 0 $? "a stale lock prints DG-LOCK-STALE"
[ -d "$RD/lock" ]; check 0 $? "a stale lock is not broken silently"
rm -rf "$RD/lock"
dag_lock "$RUN"; check 0 $? "lock is taken when free"
dag_write "$RUN" '.nodes.N1.attempts = 3'; check 0 $? "a holder can write without deadlocking itself"
[ -d "$RD/lock" ]; check 0 $? "a holder keeps the lock across a write"
dag_unlock "$RUN"; [ ! -d "$RD/lock" ]; check 0 $? "unlock releases it"

# Concurrency: ten writers, no lost update.
base="$(dag_serial "$RUN")"
for i in 1 2 3 4 5 6 7 8 9 10; do
  ( DAG_SLEEP="sleep 0.05" DAG_RETRY_WAITS="0.05" dag_retry 3 dag_write "$RUN" ".nodes.N2.proofs += [{box:\"c$i\",proof:\"p\",at:\"t\"}]" 2>/dev/null ) &
done; wait
got="$(jq '.nodes.N2.proofs | length' "$RD/state.json")"
# every writer that got the lock landed; those that lost three tries exited 5 and are not counted as lost updates
check "$got" "$(jq --argjson b "$base" '.serial - $b' "$RD/state.json")" "serial equals writes landed: no lost update"
[ "$got" -ge 1 ]; check 0 $? "at least one concurrent writer landed"

# Ledger.
dag_ledger "$RUN" plan DG-READY N1 "first"; check 0 $? "ledger appends a row"
dag_ledger "$RUN" bogus DG-READY 2>/dev/null; check 3 $? "a row that fails its schema is refused"
dag_ledger "$RUN" plan not-a-code 2>/dev/null; check 3 $? "a bad code is refused"
check 0 "$(jq -e . "$RD/ledger.jsonl" >/dev/null; echo $?)" "every ledger line is JSON"
check "init" "$(head -1 "$RD/ledger.jsonl" | jq -r .verb)" "the ledger keeps its first row"

# Retry bound (R4).
cnt="$T/cnt"; : >"$cnt"; failing() { echo x >>"$cnt"; return 7; }
dag_retry 3 failing; check 7 $? "retry returns the last exit code"
check 3 "$(wc -l <"$cnt")" "retry stops at 3 attempts"
: >"$cnt"; flaky() { echo x >>"$cnt"; [ "$(wc -l <"$cnt")" -ge 2 ]; }
dag_retry 3 flaky; check 0 $? "retry succeeds on the 2nd attempt"
check 2 "$(wc -l <"$cnt")" "retry stops once it passes"

# CLI and status.
bash "$R/bin/dag-lib.sh" status "$RUN" | head -1 | grep -q "ticket WO-1"; check 0 $? "status prints the run"
bash "$R/bin/dag-lib.sh" 2>/dev/null; check 2 $? "no function is exit 2"
bash "$R/bin/dag-lib.sh" nope 2>/dev/null; check 2 $? "unknown function is exit 2"
( unset DAG_STATE_DIR; dag_run_dir "$RUN" 2>/dev/null ); check 2 $? "no state_dir is exit 2"
printf '{"state_dir":"%s"}' "$T/cfgstate" >"$T/dag.json"
check "$T/cfgstate/runs/$RUN" "$( unset DAG_STATE_DIR; DAG_CONFIG="$T/dag.json" dag_run_dir "$RUN")" "state_dir comes from the config"

# Sourcing sets no shell options (the caller's options govern).
check "$(bash -c 'echo $-')" "$(bash -c ". '$R/bin/dag-lib.sh'; echo \$-")" "sourcing leaves the caller's options alone"

printf 'pass=%s fail=%s\n' "$((n-fail))" "$fail"
[ "$fail" = 0 ]
