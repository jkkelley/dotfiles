#!/usr/bin/env bash
# name: test_dag_apply.sh
# purpose: proves bin/dag-apply.sh keeps the apply promises of dag-state.spec.xml: ready set, JOBS, proofs, retry bound, handoff.
# inputs: none
# outputs: stdout (one ok/FAIL line per case, then the pass count), exit code
# writes-to: a mktemp scratch dir
# cleanup: removes its own temp dir on exit
# Each check names the failure it rules out:
#   - a node run before its dependency is done (R1)     - a dependent run after its dependency failed
#   - more than JOBS nodes at once                       - a done node without output hash or a proof per checklist box
#   - a retry loop past max, or a blind retry of a non-idempotent node (R4)
#   - a failure with no ledger row, no handoff or no reproduction (R8)    - a held lock overrun, or a lock left behind
# Hermetic: state, nodes and node scripts live in a temp dir; the handoff command is a stub, no ticket is filed.
set -uo pipefail
R="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
export DAG_STATE_DIR="$T/state" DAG_SLEEP=true DAG_LOCK_STALE_SECONDS=600 DAG_REPO_ROOT="$T/repo"
# shellcheck source=../../bin/dag-lib.sh disable=SC1091
. "$R/bin/dag-lib.sh"
APPLY="$R/bin/dag-apply.sh"
fail=0; n=0
ok()  { n=$((n+1)); printf 'ok  %s\n' "$1"; }
bad() { n=$((n+1)); fail=$((fail+1)); printf 'FAIL %s\n' "$1"; [ $# -gt 1 ] && printf '     %s\n' "${@:2}"; }
check() { if [ "$1" = "$2" ]; then ok "$3"; else bad "$3" "wanted [$1] got [$2]"; fi; }

RUN=dagrun-20261016T041500Z-t3
RD="$DAG_STATE_DIR/runs/$RUN"
SHA="$(printf 'x' | sha256sum | cut -d' ' -f1)"
mkdir -p "$T/repo/scripts"
export HANDOFFS="$T/handoffs"; : >"$HANDOFFS"
printf '#!/usr/bin/env bash\nprintf "%%s\\n" "$1" >>"$HANDOFFS"\n' >"$T/handoff.sh"
export DAG_HANDOFF_CMD="bash $T/handoff.sh"

# Node scripts: ok writes its output; flaky fails until its 3rd try; bad always fails; slow records overlap.
cat >"$T/repo/scripts/ok.sh" <<'S'
#!/usr/bin/env bash
node=""; while [ $# -gt 0 ]; do [ "$1" = --node ] && node="$2"; shift; done
echo "$node" >>"$RUN_COUNTS"; echo "out-$node" >"$DAG_STATE_DIR/runs/$RUN_ID/records/$node.out"
S
cat >"$T/repo/scripts/flaky.sh" <<'S'
#!/usr/bin/env bash
node=""; while [ $# -gt 0 ]; do [ "$1" = --node ] && node="$2"; shift; done
echo "$node" >>"$RUN_COUNTS"
c="$(grep -c "^$node\$" "$RUN_COUNTS")"; [ "$c" -ge "${FLAKY_PASS_ON:-3}" ] || { echo "flaky fail $c"; exit 7; }
echo ok >"$DAG_STATE_DIR/runs/$RUN_ID/records/$node.out"
S
cat >"$T/repo/scripts/bad.sh" <<'S'
#!/usr/bin/env bash
node=""; while [ $# -gt 0 ]; do [ "$1" = --node ] && node="$2"; shift; done
echo "$node" >>"$RUN_COUNTS"; echo "boom reproduction line"; exit 9
S
cat >"$T/repo/scripts/slow.sh" <<'S'
#!/usr/bin/env bash
node=""; while [ $# -gt 0 ]; do [ "$1" = --node ] && node="$2"; shift; done
touch "$DAG_STATE_DIR/runs/$RUN_ID/records/$node.start"; sleep 1
ls "$DAG_STATE_DIR/runs/$RUN_ID/records/"*.start | wc -l >>"$RUN_COUNTS.overlap"
sleep 1; rm -f "$DAG_STATE_DIR/runs/$RUN_ID/records/$node.start"
echo ok >"$DAG_STATE_DIR/runs/$RUN_ID/records/$node.out"
S
export RUN_ID="$RUN" RUN_COUNTS="$T/counts"

# mknode <id> <script> <deps-json> <retry-max> <idempotent>
mknode() {
  jq -n --arg id "$1" --arg s "scripts/$2.sh" --argjson d "$3" --argjson max "$4" --argjson idem "$5" '
    {schema_version:1, id:$id, version:"1.0.0", script:$s, depends_on:$d,
     input:{path:"records/in.json", schema_version:1}, output:{path:("records/"+$id+".out"), schema_version:1},
     checklist:[{box:"b1", proof:"p1"},{box:"b2", proof:"p2"}],
     bundle:{checklist_doc:"c.md", runbook:"claude/workflow/runbooks/RB-x.md", playbook:"p.md", docs:[]}, retry:{max:$max, waits_seconds:[1,2,3], idempotent:$idem}, serial:null, parallel:"none"}' >"$RD/nodes.lock/$1.json"
}
fresh() {
  rm -rf "$DAG_STATE_DIR"; : >"$RUN_COUNTS"; : >"$HANDOFFS"; rm -f "$RUN_COUNTS.overlap"
  dag_init "$RUN" WO-1 "A title" dag-state 1.0.0 "$SHA" /wt/a feat/a; mkdir -p "$RD/nodes.lock"
  echo '{}' >"$RD/records/in.json"
}


# --- chain N1 -> N2 -> N3: runs in order, one per round at JOBS=1, all done with proofs and hashes.
fresh; mknode N1 ok '[]' 0 true; mknode N2 ok '["N1"]' 0 true; mknode N3 ok '["N2"]' 0 true
bash "$APPLY" --run "$RUN" >"$T/o" 2>"$T/e"; check 0 $? "a clean chain exits 0"
check "N1 N2 N3" "$(tr '\n' ' ' <"$RUN_COUNTS" | sed 's/ $//')" "nodes ran in dependency order"
check "DG-DONE DG-DONE DG-DONE" "$(jq -r '[.nodes.N1.status,.nodes.N2.status,.nodes.N3.status]|join(" ")' "$RD/state.json")" "all nodes are DG-DONE"
check 2 "$(jq '.nodes.N2.proofs|length' "$RD/state.json")" "one proof per checklist box"
check "$(sha256sum <"$RD/records/N2.out" | cut -d' ' -f1)" "$(jq -r '.nodes.N2.output_sha256' "$RD/state.json")" "output hash recorded"
check 3 "$(jq -r 'select(.verb=="apply" and .code=="DG-DONE")|.node' "$RD/ledger.jsonl" | wc -l)" "one ledger row per node run"
[ ! -d "$RD/lock" ]; check 0 $? "the lock is released"
bash "$APPLY" --run "$RUN" >/dev/null 2>&1; check 0 $? "apply again exits 0"
check 3 "$(wc -l <"$RUN_COUNTS")" "apply again re-runs no done node (idempotent)"

# --- JOBS: three independent slow nodes at JOBS=2 never overlap more than 2; at JOBS=3 they do overlap.
fresh; mknode N1 slow '[]' 0 true; mknode N2 slow '[]' 0 true; mknode N3 slow '[]' 0 true
bash "$APPLY" --run "$RUN" --jobs 2 >/dev/null 2>&1; check 0 $? "jobs=2 exits 0"
check 2 "$(sort -n "$RUN_COUNTS.overlap" | tail -1)" "jobs=2 runs at most 2 nodes at once"
check 3 "$(jq '[.nodes[]|select(.status=="DG-DONE")]|length' "$RD/state.json")" "jobs=2 still finishes all three"
fresh; mknode N1 slow '[]' 0 true; mknode N2 slow '[]' 0 true; mknode N3 slow '[]' 0 true
bash "$APPLY" --run "$RUN" --jobs 3 >/dev/null 2>&1
check 3 "$(sort -n "$RUN_COUNTS.overlap" | tail -1)" "jobs=3 runs all three at once"

# --- R4: a flaky node passes on try 3 with max 3; the attempts show it.
fresh; mknode N1 flaky '[]' 3 true
bash "$APPLY" --run "$RUN" >/dev/null 2>&1; check 0 $? "a flaky node that passes on try 3 exits 0"
check 3 "$(jq '.nodes.N1.attempts' "$RD/state.json")" "attempts records 3"

# --- R4 + R8: a node that always fails: 1 + max tries, never a 5th, DG-FAILED, handoff with reproduction, dependent blocked.
fresh; mknode N1 bad '[]' 3 true; mknode N2 ok '["N1"]' 0 true
bash "$APPLY" --run "$RUN" >"$T/o" 2>"$T/e"; check 1 $? "a failed node exits 1"
check 4 "$(grep -c '^N1$' "$RUN_COUNTS")" "retry is bounded: 1 try + 3 retries, never more"
check "DG-FAILED" "$(jq -r '.nodes.N1.status' "$RD/state.json")" "the node ends DG-FAILED"
check "DG-BLOCKED" "$(jq -r '.nodes.N2.status' "$RD/state.json")" "its dependent is DG-BLOCKED, not run"
check 0 "$(grep -c '^N2$' "$RUN_COUNTS")" "the blocked dependent never ran"
check 1 "$(jq -r 'select(.code=="DG-HANDOFF")|.node' "$RD/ledger.jsonl" | wc -l)" "one DG-HANDOFF ledger row"
check 1 "$(wc -l <"$HANDOFFS")" "the handoff command ran once"
H="$(cat "$(head -1 "$HANDOFFS")")"
grep -q 'reproduction: bash .*bad.sh --run '"$RUN"' --node N1' <<<"$H"; check 0 $? "handoff carries the reproduction command"
grep -q 'exit code: 1' <<<"$H"; check 0 $? "handoff carries the exit code"
grep -q 'boom reproduction line' <<<"$H"; check 0 $? "handoff carries the log tail"
[ ! -d "$RD/lock" ]; check 0 $? "the lock is released after a failure"

# --- R4: a non-idempotent node never retries, even with max declared.
fresh; mknode N1 bad '[]' 3 false
bash "$APPLY" --run "$RUN" >/dev/null 2>&1; check 1 $? "a non-idempotent failure exits 1"
check 1 "$(grep -c '^N1$' "$RUN_COUNTS")" "a non-idempotent node runs once"

# --- a script that exits 0 but leaves no output is a failure, not a done node.
fresh; mknode N1 ok '[]' 0 true; jq '.output.path="records/never.out"' "$RD/nodes.lock/N1.json" >"$T/n" && mv "$T/n" "$RD/nodes.lock/N1.json"
bash "$APPLY" --run "$RUN" >/dev/null 2>&1; check 1 $? "missing output is a failure"
check "DG-FAILED" "$(jq -r '.nodes.N1.status' "$RD/state.json")" "missing output leaves the node DG-FAILED"

# --- lock: a live holder means exit 5 and no node runs.
fresh; mknode N1 ok '[]' 0 true
mkdir "$RD/lock"; printf '{"pid":1,"at":"x","epoch":%s}\n' "$(date +%s)" >"$RD/lock/holder.json"
bash "$APPLY" --run "$RUN" >/dev/null 2>"$T/e"; check 5 $? "a held lock exits 5"
grep -q DG-LOCK-HELD "$T/e"; check 0 $? "a held lock prints DG-LOCK-HELD"
check 0 "$(wc -c <"$RUN_COUNTS")" "nothing ran under a held lock"
[ -d "$RD/lock" ]; check 0 $? "the other holder's lock is left alone"
rm -rf "$RD/lock"

# --- usage.
bash "$APPLY" >/dev/null 2>&1; check 2 $? "no --run exits 2"
bash "$APPLY" --run "$RUN" --jobs 0 >/dev/null 2>&1; check 2 $? "--jobs 0 exits 2"
bash "$APPLY" --run dagrun-bad >/dev/null 2>&1; check 2 $? "a bad run id exits 2"

printf 'pass=%s fail=%s\n' "$((n - fail))" "$fail"
[ "$fail" = 0 ]
