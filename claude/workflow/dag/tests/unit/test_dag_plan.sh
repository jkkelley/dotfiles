#!/usr/bin/env bash
# name: test_dag_plan.sh
# purpose: proves bin/dag-plan.sh classes nodes and orders the ready set as docs/design/dag-state.spec.xml <verb name="plan"> says.
# inputs: none
# outputs: stdout, exit code
# writes-to: a mktemp scratch dir
# cleanup: removes its own temp dir on exit
# Each check names the failure it rules out:
#   - a node run before its dependencies are done              - a ready set not ordered by priority then layer (item 40)
#   - a stale done node left looking done                      - a node ready with a bundle document missing
#   - a plan that changes the state or the world               - a wrong exit code for bad usage or a bad node
# Hermetic: state, nodes and the bundle files live in a temp dir.
set -uo pipefail
R="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
export DAG_STATE_DIR="$T/state" DAG_SLEEP=true
# shellcheck source=../../bin/dag-lib.sh disable=SC1091
. "$R/bin/dag-lib.sh"
PLAN="$R/bin/dag-plan.sh"
fail=0; n=0
ok()  { n=$((n+1)); printf 'ok  %s\n' "$1"; }
bad() { n=$((n+1)); fail=$((fail+1)); printf 'FAIL %s\n' "$1"; [ $# -gt 1 ] && printf '     %s\n' "${@:2}"; }
check() { if [ "$1" = "$2" ]; then ok "$3"; else bad "$3" "wanted [$1] got [$2]"; fi; }

RUN=dagrun-20261016T041500Z-t2
SHA="$(printf 'x' | sha256sum | cut -d' ' -f1)"
RD="$DAG_STATE_DIR/runs/$RUN"
ROOT="$T/root"; NODES="$T/nodes"; mkdir -p "$ROOT/docs" "$ROOT/claude/workflow/runbooks" "$NODES"
: >"$ROOT/docs/a.md"; : >"$ROOT/claude/workflow/runbooks/RB-t.md"; : >"$ROOT/pb.md"

# node <id> <deps-json> [priority] [version] - writes a valid node declaration.
node() {
  jq -n --arg id "$1" --argjson deps "$2" --arg v "${4:-1.0.0}" --arg p "${3:-}" \
    '{schema_version:1, id:$id, version:$v, script:("bin/" + $id + ".sh"), depends_on:$deps,
      input:{path:("records/" + $id + ".in.json"), schema_version:1}, output:{path:("records/" + $id + ".out.json"), schema_version:1},
      checklist:[{box:"b", proof:"p"}],
      bundle:{checklist_doc:"docs/a.md", runbook:"claude/workflow/runbooks/RB-t.md", playbook:"pb.md", docs:["docs/a.md"]},
      retry:{max:3, waits_seconds:[1,2,3], idempotent:true}, serial:null, parallel:"none"}
     + (if $p == "" then {} else {priority:$p} end)' >"$NODES/$1.node.json"
}
# A diamond: N1 -> N2, N3 -> N4; N5 and N6 are roots of their own (layer 0).
node N1 '[]'; node N2 '["N1"]'; node N3 '["N1"]'; node N4 '["N2","N3"]'; node N5 '[]' p0; node N6 '[]'
dag_init "$RUN" WO-1 "A title" dag-state 1.0.0 "$SHA" /wt/a feat/a
# The input record each non-root node reads; N8 is left without one on purpose, further down.
for i in N2 N3 N4 N7; do printf '{}' >"$RD/records/$i.in.json"; done
plan() { bash "$PLAN" --run "$RUN" --nodes "$NODES" --root "$ROOT" "$@"; }
cls() { awk -F'\t' -v n="$1" '$1 == n {print $2}' <<<"$OUT"; }
st() { dag_write "$RUN" ".nodes.$1 = {status:\"$2\",version:\"${3:-1.0.0}\",attempts:0,proofs:[]}"; }

OUT="$(plan)"; check 0 $? "plan exits 0"
check "DG-READY" "$(cls N1)" "a root node is ready"
check "DG-PENDING" "$(cls N2)" "a node waits on its dependency"
check "DG-PENDING" "$(cls N4)" "a node two deep waits"
check "N5 N1 N6" "$(awk -F'\t' '$2 == "DG-READY" {printf "%s ", $1}' <<<"$OUT" | sed 's/ $//')" "ready set: p0 first, then missing=p2 by layer then id"
check "DG-READY" "$(head -1 <<<"$OUT" | cut -f2)" "the ready set is printed first"
grep -q "run bin/N1.sh" <<<"$OUT"; check 0 $? "a ready node says what it will run"

# Priority beats layer; layer beats id.
node N6 '[]' p1; node N7 '["N6"]' p0; st N6 DG-DONE
OUT="$(plan)"
check "N5 N7 N1" "$(awk -F'\t' '$2 == "DG-READY" {printf "%s ", $1}' <<<"$OUT" | sed 's/ $//')" "all p0 before p2, each by layer: a deeper p0 still beats a shallower p2"
rm -f "$NODES/N7.node.json"; node N6 '[]'; dag_write "$RUN" 'del(.nodes.N6)'

# Dependencies done make the next layer ready.
st N1 DG-DONE
OUT="$(plan)"
check "DG-DONE" "$(cls N1)" "a done node is passed through"
check "DG-READY" "$(cls N2)" "done dependencies make a node ready"
check "DG-READY" "$(cls N3)" "its sibling is ready too"
check "DG-PENDING" "$(cls N4)" "a node with one dependency still open waits"
st N2 DG-DONE; st N3 DG-SKIPPED
OUT="$(plan)"; check "DG-READY" "$(cls N4)" "a skipped dependency counts as done"

# Stale: pinned version moved; input hash moved.
st N2 DG-DONE 0.9.0
OUT="$(plan)"; check "DG-STALE" "$(cls N2)" "a done node pinned at an old version is stale"
grep -q "pinned 0.9.0 design 1.0.0" <<<"$OUT"; check 0 $? "stale prints both versions"
st N2 DG-DONE
printf 'v1' >"$ROOT/in.json"; h1="$(sha256sum "$ROOT/in.json" | cut -d' ' -f1)"
dag_write "$RUN" ".nodes.N3 = {status:\"DG-DONE\",version:\"1.0.0\",attempts:1,input:\"in.json\",input_sha256:\"$h1\",proofs:[]}"
OUT="$(plan)"; check "DG-DONE" "$(cls N3)" "an input that still hashes the same is not stale"
printf 'v2' >"$ROOT/in.json"
OUT="$(plan)"; check "DG-STALE" "$(cls N3)" "an input whose hash moved is stale"

# Blocked: a failed dependency; a missing bundle file.
st N3 DG-DONE; st N2 DG-FAILED
OUT="$(plan)"; check "DG-BLOCKED" "$(cls N4)" "a failed dependency blocks its dependants"
st N2 DG-DONE
mv "$ROOT/pb.md" "$ROOT/pb.gone"
OUT="$(plan)"; check "DG-BLOCKED" "$(cls N5)" "a missing bundle file blocks a root node"
grep -q "DG-BUNDLE-MISSING pb.md" <<<"$OUT"; check 0 $? "blocked by a bundle names DG-BUNDLE-MISSING and the file"
mv "$ROOT/pb.gone" "$ROOT/pb.md"

# Input record: a non-root node needs its input record, else pending.
node N8 '["N1"]'; OUT="$(plan)"; check "DG-PENDING" "$(cls N8)" "a non-root node without its input record waits"
grep -q "input record missing" <<<"$OUT"; check 0 $? "and says why"
mkdir -p "$RD/records"; printf '{}' >"$RD/records/N8.in.json"
OUT="$(plan)"; check "DG-READY" "$(cls N8)" "the input record under the run dir makes it ready"
rm -f "$NODES/N8.node.json"

# R: a plan writes the ledger and nothing else.
before="$(sha256sum "$RD/state.json")"; rows="$(wc -l <"$RD/ledger.jsonl")"; wt="$(find "$ROOT" "$NODES" -type f | sort | xargs sha256sum | sha256sum)"
plan >/dev/null
check "$before" "$(sha256sum "$RD/state.json")" "plan leaves state.json untouched"
check "$((rows + 1))" "$(wc -l <"$RD/ledger.jsonl")" "plan adds exactly one ledger row"
check "$wt" "$(find "$ROOT" "$NODES" -type f | sort | xargs sha256sum | sha256sum)" "plan changes nothing it reads"
check "plan" "$(tail -1 "$RD/ledger.jsonl" | jq -r .verb)" "the ledger row is a plan row"
check 0 "$(find "$RD" -name '.*' -type f | wc -l)" "no temp file is left behind"
a="$(plan)"; b="$(plan)"; check "$a" "$b" "plan is idempotent: same state, same plan"

# Config: nodes dir default is nodes.lock under the run; state_dir from the config.
mkdir -p "$RD/nodes.lock"; cp "$NODES"/*.node.json "$RD/nodes.lock/"
bash "$PLAN" --run "$RUN" --root "$ROOT" >/dev/null; check 0 $? "nodes default to <run>/nodes.lock"
printf '{"state_dir":"%s"}' "$DAG_STATE_DIR" >"$T/dag.json"
( unset DAG_STATE_DIR; bash "$PLAN" --run "$RUN" --config "$T/dag.json" --root "$ROOT" >/dev/null ); check 0 $? "state_dir comes from the config"
DAG_RUN="$RUN" bash "$PLAN" --nodes "$NODES" --root "$ROOT" >/dev/null; check 0 $? "the run id may come from DAG_RUN"

# Exit 2: usage.
bash "$PLAN" 2>/dev/null; check 2 $? "no run is exit 2"
bash "$PLAN" --run 2>/dev/null; check 2 $? "a flag with no value is exit 2"
bash "$PLAN" --bogus 2>/dev/null; check 2 $? "an unknown flag is exit 2"
bash "$PLAN" --run dagrun-bad --nodes "$NODES" 2>/dev/null; check 2 $? "a bad run id is exit 2"
bash "$PLAN" --run dagrun-20261016T041500Z-none --nodes "$NODES" 2>/dev/null; check 2 $? "a run with no state is exit 2"
bash "$PLAN" --run "$RUN" --nodes "$T/absent" 2>/dev/null; check 2 $? "a missing nodes dir is exit 2"

# Exit 3: schema.
mkdir -p "$T/badnodes"; jq 'del(.checklist)' "$NODES/N1.node.json" >"$T/badnodes/N1.node.json"
bash "$PLAN" --run "$RUN" --nodes "$T/badnodes" --root "$ROOT" 2>"$T/e" >/dev/null; check 3 $? "a node that fails its schema is exit 3"
grep -q DG-SCHEMA "$T/e"; check 0 $? "and prints DG-SCHEMA"
jq '.priority = "high"' "$NODES/N1.node.json" >"$T/badnodes/N1.node.json"
bash "$PLAN" --run "$RUN" --nodes "$T/badnodes" --root "$ROOT" 2>/dev/null >/dev/null; check 3 $? "a priority outside p0-p9 is exit 3"
printf 'not json' >"$T/badnodes/N1.node.json"
bash "$PLAN" --run "$RUN" --nodes "$T/badnodes" --root "$ROOT" 2>/dev/null >/dev/null; check 3 $? "a node that is not JSON is exit 3"
mv "$RD/state.json" "$RD/state.json.keep"; echo '{"nope":1}' >"$RD/state.json"
bash "$PLAN" --run "$RUN" --nodes "$NODES" --root "$ROOT" 2>/dev/null >/dev/null; check 3 $? "a state that fails its schema is exit 3"
mv "$RD/state.json.keep" "$RD/state.json"

printf 'pass=%s fail=%s\n' "$((n-fail))" "$fail"
[ "$fail" = 0 ]
