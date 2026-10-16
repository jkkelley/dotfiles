#!/usr/bin/env bash
# name: test_dag_recover.sh
# purpose: proves bin/dag-recover.sh keeps the recover promises of docs/design/dag-state.spec.xml: lock, DG-RUNNING reset, plan then apply.
# inputs: none
# outputs: stdout, exit code
# writes-to: a mktemp scratch dir
# cleanup: removes its own temp dir on exit
# Each check names the failure it rules out: a live lock broken, a stale lock left, a non-idempotent node re-run (a second PR),
# an idempotent node left stuck, apply run without plan, a failing apply reported as success.
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

REC="$R/bin/dag-recover.sh"
RUN=dagrun-20261016T041500Z-t5
SHA="$(printf 'x' | sha256sum | cut -d' ' -f1)"
RD="$DAG_STATE_DIR/runs/$RUN"
LOG="$T/calls"
printf '#!/usr/bin/env bash\necho "plan $*" >>"%s"\n' "$LOG" >"$T/plan.sh"
printf '#!/usr/bin/env bash\necho "apply $*" >>"%s"\nexit "${FAKE_APPLY_RC:-0}"\n' "$LOG" >"$T/apply.sh"
export DAG_PLAN="$T/plan.sh" DAG_APPLY="$T/apply.sh"

fresh() {
  rm -rf "$DAG_STATE_DIR" "$LOG"; : >"$LOG"
  dag_init "$RUN" WO-1 "A title" dag-state 1.0.0 "$SHA" /wt/a feat/a
  dag_write "$RUN" '.nodes.N4 = {status:"DG-RUNNING",version:"1.0.0",attempts:1,proofs:[]}
    | .nodes.N6 = {status:"DG-RUNNING",version:"1.0.0",attempts:1,proofs:[]}
    | .nodes.N1 = {status:"DG-DONE",version:"1.0.0",attempts:1,proofs:[]}'
  mkdir -p "$RD/nodes.lock"
  printf '{"retry":{"idempotent":true}}' >"$RD/nodes.lock/N4.node.json"
  printf '{"retry":{"idempotent":false}}' >"$RD/nodes.lock/N6.node.json"
}
st() { jq -r ".nodes.$1.status" "$RD/state.json"; }

bash "$REC" 2>/dev/null; check 2 $? "no run is exit 2"
bash "$REC" --run dagrun-bad 2>/dev/null; check 2 $? "a bad run id is exit 2"

fresh
out="$(bash "$REC" --run "$RUN")"; rc=$?
check 1 "$rc" "a non-idempotent node left running leaves the run blocked, exit 1"
check DG-READY "$(st N4)" "an idempotent DG-RUNNING node with no live seat becomes DG-READY"
check DG-BLOCKED "$(st N6)" "a non-idempotent DG-RUNNING node becomes DG-BLOCKED, not re-run"
check DG-DONE "$(st N1)" "a done node is untouched"
grep -q '^DR-PR node=N6 state=DG-RUNNING world=' <<<"$out"; check 0 $? "the drift line carries state and world values"
grep -q '^plan --run' "$LOG" && grep -q '^apply --run' "$LOG"; check 0 $? "plan then apply still run"
check "plan,apply" "$(cut -d' ' -f1 "$LOG" | paste -sd,)" "plan runs before apply"

# a second run lands in the same place: no duplicate reset, same end state.
before="$(st N4)$(st N6)"
bash "$REC" --run "$RUN" >/dev/null; check 1 $? "recover again is still exit 1"
check "$before" "$(st N4)$(st N6)" "recover again lands in the same end state"

# a live seat is left alone.
fresh; DAG_SEAT_ALIVE="true" bash "$REC" --run "$RUN" >/dev/null
check DG-RUNNING "$(st N4)" "a node with a live seat stays DG-RUNNING"
check DG-RUNNING "$(st N6)" "a live non-idempotent node is not blocked"

# only idempotent nodes: run resumed, exit 0, ledger row.
fresh; dag_write "$RUN" 'del(.nodes.N6)'
bash "$REC" --run "$RUN" >/dev/null; check 0 $? "all idempotent: run resumed, exit 0"
check recover "$(tail -1 "$RD/ledger.jsonl" | jq -r .verb)" "recover writes a ledger row"

# apply failing is exit 1.
fresh; dag_write "$RUN" 'del(.nodes.N6)'
FAKE_APPLY_RC=1 bash "$REC" --run "$RUN" >/dev/null; check 1 $? "a failing apply is exit 1"

# lock: fresh lock is held, never broken.
fresh; dag_write "$RUN" 'del(.nodes.N6)'
mkdir "$RD/lock"; printf '{"pid":1,"at":"x","epoch":%s}\n' "$(date +%s)" >"$RD/lock/holder.json"
bash "$REC" --run "$RUN" >/dev/null; check 1 $? "a fresh lock is reported held, exit 1"
[ -d "$RD/lock" ]; check 0 $? "a fresh lock is not broken"
check 0 "$(wc -l <"$LOG")" "nothing ran under a held lock"
# stale lock, holder gone: cleared with an unlock row.
printf '{"pid":999999,"at":"x","epoch":%s}\n' "$(($(date +%s) - 700))" >"$RD/lock/holder.json"
bash "$REC" --run "$RUN" >/dev/null; check 0 $? "a stale lock with a dead holder is cleared and the run resumes"
[ ! -d "$RD/lock" ]; check 0 $? "the stale lock is gone"
grep -q '"verb":"unlock"' "$RD/ledger.jsonl"; check 0 $? "the clear is an unlock ledger row"
# stale lock, holder alive: not broken.
fresh; dag_write "$RUN" 'del(.nodes.N6)'
sleep 30 & lp=$!
mkdir "$RD/lock"; printf '{"pid":%s,"at":"x","epoch":%s}\n' "$lp" "$(($(date +%s) - 700))" >"$RD/lock/holder.json"
bash "$REC" --run "$RUN" >/dev/null; check 1 $? "a stale lock with a live holder is not broken"
kill "$lp" 2>/dev/null; wait "$lp" 2>/dev/null

# dead build seat: resume hook gets node, run dir and a checkpoint file.
fresh; dag_write "$RUN" 'del(.nodes.N6)'
printf '#!/usr/bin/env bash\necho "resume $1 $(basename "$2") $(cat "$3")" >>"%s"\n' "$LOG" >"$T/resume.sh"
DAG_SEAT_RESUME="bash $T/resume.sh" DAG_CHECKPOINT_CMD="echo ckpt-1" bash "$REC" --run "$RUN" >/dev/null
check 0 $? "a resumed dead seat lets the run resume"
grep -q "^resume N4 $RUN ckpt-1" "$LOG"; check 0 $? "the new seat gets the node and the last checkpoint"

printf 'pass=%s fail=%s\n' "$((n-fail))" "$fail"
[ "$fail" = 0 ]
