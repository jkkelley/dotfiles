#!/usr/bin/env bash
# name: test_dag_migrate.sh
# purpose: proves bin/dag-migrate.sh moves a fixture run from design 1.0.0 to 1.1.0 and back (dag-state-nodes.spec.xml <migration>)
# inputs: none
# outputs: stdout, one ok/FAIL line per check, last line pass=N fail=M; exit 0 only when fail=0
# writes-to: a mktemp scratch dir
# cleanup: removes its own temp dir on exit
# Failures ruled out, one check each: an edited node that loses a done result it did not need to lose; a done node whose
# checklist moved staying DG-DONE; a new node missing or an upstream-of-done node not going stale; a removed node losing
# its output; a record or state schema bump overwriting the original; rollback leaving the new pins; a second migrate
# changing anything; a crash between state and files going unhealed; a design edited without a version bump unseen.
set -uo pipefail
R="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
export DAG_STATE_DIR="$T/state" DAG_SLEEP=true DAG_LOCK_STALE_SECONDS=600 DAG_SCHEMAS="$T/schemas" DAG_MIGRATIONS="$T/migrations"
cp -r "$R/schemas" "$T/schemas"; cp -r "$R/migrations" "$T/migrations"
export DAG_VALIDATE="$R/../tools/validate-schema.sh"
# shellcheck source=../../bin/dag-lib.sh disable=SC1091
. "$R/bin/dag-lib.sh"
M="$R/bin/dag-migrate.sh"
fail=0; n=0
ok()  { n=$((n+1)); printf 'ok  %s\n' "$1"; }
bad() { n=$((n+1)); fail=$((fail+1)); printf 'FAIL %s\n' "$1"; [ $# -gt 1 ] && printf '     %s\n' "${@:2}"; }
check() { if [ "$1" = "$2" ]; then ok "$3"; else bad "$3" "wanted [$1] got [$2]"; fi; }

RUN=dagrun-20261016T090000Z-fixture
RD="$DAG_STATE_DIR/runs/$RUN"
mknode() { # id version script deps(json) checklist-box
  jq -n --arg id "$1" --arg v "$2" --arg s "$3" --argjson d "$4" --arg box "$5" \
    '{schema_version:1,id:$id,version:$v,script:$s,depends_on:$d,input:{path:"in.json",schema_version:1},output:{path:"out.json",schema_version:1},
      checklist:[{box:$box,proof:"p"}],bundle:{checklist_doc:"c.md",runbook:"claude/workflow/runbooks/RB-x.md",playbook:"p.md",docs:[]},
      retry:{max:3,waits_seconds:[10,30,90],idempotent:true},serial:null,parallel:"none"}' >"$5.tmp" && mv "$5.tmp" "$OUT/$1.node.json"
}
design() { # dir version ; N1 N2 N3 N4 at the given edit level
  OUT="$1"; mkdir -p "$OUT"; jq -n --arg v "$2" '{version:$v}' >"$OUT/design.json"
}
sha_of() { (cd "$1" && LC_ALL=C sha256sum -- *.node.json | sha256sum | cut -d' ' -f1); }

# --- design 1.0.0 and the fixture run pinned to it
design "$T/d100" 1.0.0
OUT="$T/d100"; mknode N1 1.0.0 s/n1.sh '[]' a; mknode N2 1.0.0 s/n2.sh '["N1"]' b; mknode N3 1.0.0 s/n3.sh '["N2"]' c; mknode N4 1.0.0 s/n4.sh '["N1"]' d
mkdir -p "$RD/records" "$RD/nodes.lock"
cp "$T/d100"/N*.node.json "$RD/nodes.lock/"
jq --arg sha "$(sha_of "$T/d100")" '.design.sha256=$sha' "$R/tests/fixtures/run-1.0.0.json" >"$RD/state.json"
dag_validate state "$RD/state.json"; check 0 $? "the fixture run is a valid state at 1.0.0"
# a record at schema v1 and a v2 schema for it, plus a state v2 schema, so both schema-bump cases run
mkdir -p "$T/schemas/records" "$T/migrations/rec"
printf '{"schema_version":1,"k":"v"}\n' >"$RD/records/rec.jsonl"
for v in 1 2; do jq -n --argjson v "$v" '{type:"object",required:["schema_version"],properties:{schema_version:{const:$v}}}' >"$T/schemas/records/rec.v$v.schema.json"; done
printf '#!/usr/bin/env bash\njq -c ".schema_version = 2 | .added = true"\n' >"$T/migrations/rec/v1-to-v2.sh"; chmod +x "$T/migrations/rec/v1-to-v2.sh"
jq '.properties.schema_version={const:2}' "$T/schemas/state.schema.json" >"$T/schemas/state.v2.schema.json"
# the v1 pin for state: with no state.v1 schema the runner treats v2 as the target
SER0="$(jq -r .serial "$RD/state.json")"

# --- design 1.1.0: N2 edited (checklist moved), N3 edited (script moved, pending), N4 edited (version only), N5 added upstream of N4, N1 untouched
design "$T/d110" 1.1.0
OUT="$T/d110"; mknode N1 1.0.0 s/n1.sh '[]' a; mknode N2 1.1.0 s/n2.sh '["N1"]' b2; mknode N3 1.1.0 s/n3-new.sh '["N2"]' c
mknode N4 1.1.0 s/n4.sh '["N1","N5"]' d; mknode N5 1.0.0 s/n5.sh '["N1"]' e

out="$(bash "$M" --design "$T/d110" "$RUN" 2>&1)"; check 0 $? "migrate 1.0.0 -> 1.1.0 exits 0"
echo "$out" | sed 's/^/     /'
S="$RD/state.json"
check 1.1.0 "$(jq -r .design.version "$S")" "design pin moved to 1.1.0"
check "$(sha_of "$T/d110")" "$(jq -r .design.sha256 "$S")" "design hash is the new nodes.lock hash"
check "$(sha_of "$T/d110")" "$(sha_of "$RD/nodes.lock")" "nodes.lock now holds the 1.1.0 declarations"
check "DG-DONE 1.0.0" "$(jq -r '.nodes.N1|"\(.status) \(.version)"' "$S")" "untouched node N1 keeps status and pin"
check "DG-STALE 1.1.0" "$(jq -r '.nodes.N2|"\(.status) \(.version)"' "$S")" "done node whose checklist moved is DG-STALE"
check "DG-PENDING 1.1.0" "$(jq -r '.nodes.N3|"\(.status) \(.version)"' "$S")" "pending node takes the new version"
check "DG-STALE 1.1.0" "$(jq -r '.nodes.N4|"\(.status) \(.version)"' "$S")" "done node with a new upstream N5 is DG-STALE"
check "DG-PENDING 1.0.0" "$(jq -r '.nodes.N5|"\(.status) \(.version)"' "$S")" "added node N5 is DG-PENDING"
check 1 "$(jq '.nodes.N2.proofs|length' "$S")" "an edited done node keeps its proofs"
dag_validate state "$S"; check 0 $? "the migrated state is still valid"
check 1 "$([ -d "$RD/nodes.lock.v1.0.0" ] && ls "$RD/nodes.lock.v1.0.0"/*.node.json | wc -l | grep -qx 4 && echo 1)" "the 1.0.0 declarations are kept beside the new ones"
[ -e "$RD/records/rec.v2.jsonl" ]; check 0 $? "record schema bump wrote rec.v2.jsonl beside the original"
check 1 "$(jq -r .schema_version "$RD/records/rec.jsonl")" "the original record is not edited"
[ -e "$RD/state.v2.json" ]; check 0 $? "state schema bump wrote state.v2.json beside state.json"
check 2 "$(jq -r .schema_version "$RD/state.v2.json")" "the state copy is at schema 2"
check 1 "$(jq -r .schema_version "$S")" "state.json is not edited by the schema bump"
check "$((SER0+1))" "$(jq -r .serial "$S")" "one state write, one serial bump"
check 4 "$(jq -r 'select(.verb=="migrate")|.node' "$RD/ledger.jsonl" | grep -c .)" "one migrate ledger row per changed node"

# --- idempotent: the same migrate again changes nothing
cp "$S" "$T/after1.json"
bash "$M" --design "$T/d110" "$RUN" >/dev/null 2>&1; check 0 $? "a second migrate exits 0"
check "$(cat "$T/after1.json")" "$(cat "$S")" "a second migrate leaves state.json byte for byte as it was"

# --- heal: state migrated, files behind
rm -rf "$RD/nodes.lock"; cp -a "$RD/nodes.lock.v1.0.0" "$RD/nodes.lock"
out="$(bash "$M" --design "$T/d110" "$RUN" 2>&1)"; case "$out" in *MIG-HEALED*) h=0 ;; *) h=1 ;; esac; check 0 "$h" "a crash between state and files is healed"
check "$(sha_of "$T/d110")" "$(sha_of "$RD/nodes.lock")" "healed nodes.lock is the 1.1.0 set"
check "$(cat "$T/after1.json")" "$(cat "$S")" "healing writes no second state"

# --- drift: the design changed under the same version
cp -r "$T/d110" "$T/d110x"; OUT="$T/d110x"; mknode N1 1.0.0 s/n1-edited.sh '[]' a
out="$(bash "$M" --design "$T/d110x" "$RUN" 2>&1)"; case "$out" in *DR-DESIGN*) h=0 ;; *) h=1 ;; esac; check 0 "$h" "a design edited without a version bump is DR-DESIGN"
bash "$M" --design "$T/d110x" "$RUN" >/dev/null 2>&1; check 1 $? "DR-DESIGN is exit 1"

# --- rollback: back to 1.0.0
out="$(bash "$M" rollback "$RUN" 1.0.0 2>&1)"; check 0 $? "rollback to 1.0.0 exits 0"
echo "$out" | sed 's/^/     /'
check 1.0.0 "$(jq -r .design.version "$S")" "the pin is back at 1.0.0"
check "$(sha_of "$T/d100")" "$(jq -r .design.sha256 "$S")" "the design hash is the 1.0.0 hash"
check "$(sha_of "$T/d100")" "$(sha_of "$RD/nodes.lock")" "nodes.lock holds the 1.0.0 declarations again"
check "DG-DONE 1.0.0" "$(jq -r '.nodes.N2|"\(.status) \(.version)"' "$S")" "N2 is done at 1.0.0 again"
check "DG-DONE 1.0.0" "$(jq -r '.nodes.N4|"\(.status) \(.version)"' "$S")" "N4 is done at 1.0.0 again"
check "DG-PENDING 1.0.0" "$(jq -r '.nodes.N3|"\(.status) \(.version)"' "$S")" "N3 is pending at 1.0.0 again"
check null "$(jq -c '.nodes.N5' "$S")" "the added node N5 is gone from the state"
[ -e "$RD/nodes.lock.rolled-back" ]; check 0 $? "the 1.1.0 nodes.lock is set aside as .rolled-back"
[ -e "$RD/records/rec.v2.jsonl.rolled-back" ] && [ ! -e "$RD/records/rec.v2.jsonl" ]; check 0 $? "the v2 record copy is renamed .rolled-back"
[ -e "$RD/state.v2.json.rolled-back" ] && [ ! -e "$RD/state.v2.json" ]; check 0 $? "the v2 state copy is renamed .rolled-back"
check 1 "$(jq -r .schema_version "$RD/records/rec.jsonl")" "the original record is untouched by the rollback"
dag_validate state "$S"; check 0 $? "the rolled-back state is valid"
bash "$M" rollback "$RUN" 1.0.0 >/dev/null 2>&1; check 0 $? "a second rollback exits 0"
check 1.0.0 "$(jq -r .design.version "$S")" "a second rollback leaves the pin at 1.0.0"
bash "$M" rollback "$RUN" 9.9.9 >/dev/null 2>&1; check 2 $? "rollback to a version with no migration is exit 2"

# --- node removed: N3 gone from design 1.2.0 keeps its state entry as DG-SKIPPED
design "$T/d120" 1.2.0
OUT="$T/d120"; mknode N1 1.0.0 s/n1.sh '[]' a; mknode N2 1.0.0 s/n2.sh '["N1"]' b; mknode N4 1.0.0 s/n4.sh '["N1"]' d
jq '.nodes.N3.output="out/n3.json" | .nodes.N3.output_sha256="aa"' "$S" >"$T/s.tmp" && mv "$T/s.tmp" "$S"
bash "$M" --design "$T/d120" "$RUN" >/dev/null 2>&1; check 0 $? "migrate with a removed node exits 0"
check "DG-SKIPPED out/n3.json" "$(jq -r '.nodes.N3|"\(.status) \(.output)"' "$S")" "a removed node is DG-SKIPPED and keeps its output"
[ ! -e "$RD/nodes.lock/N3.node.json" ]; check 0 $? "the removed node is gone from nodes.lock"

# --- usage and refusals
bash "$M" 2>/dev/null; check 2 $? "no run is exit 2"
bash "$M" --design "$T/d120" dagrun-20261016T090000Z-nope 2>/dev/null; check 2 $? "an unknown run is exit 2"
bash "$M" --design "$T/nodir" "$RUN" 2>/dev/null; check 2 $? "a missing design dir is exit 2"
rm -rf "$T/dbad"; design "$T/dbad" 1.3.0; echo '{"id":"N1"}' >"$T/dbad/N1.node.json"
bash "$M" --design "$T/dbad" "$RUN" 2>/dev/null; check 3 $? "a node that fails its schema is exit 3"
[ ! -d "$RD/lock" ]; check 0 $? "the run lock is released on every exit"

printf 'pass=%s fail=%s\n' "$((n-fail))" "$fail"
[ "$fail" = 0 ]
