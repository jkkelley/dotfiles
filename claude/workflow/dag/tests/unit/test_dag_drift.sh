#!/usr/bin/env bash
# shellcheck disable=SC2016 # the fake tool body and jq filters are single-quoted on purpose; they expand in the child
# name: test_dag_drift.sh
# purpose: proves bin/dag-drift.sh reports each mismatch with both values, exits 0/1, and never repairs (spec rule R6).
# inputs: none
# outputs: stdout (one ok/FAIL line per case, last line pass=N fail=M), exit code
# writes-to: a mktemp scratch dir
# cleanup: removes its own temp dir on exit
# Each case names the failure it rules out:
#   - a clean run reported as drifted, or a drifted run reported clean     - a DR line with no state or world value (R6)
#   - a repair: state.json changed by drift                                - a world tool that fails read as "no drift"
# Hermetic: git, gh, slot.sh and work-order.sh are fakes driven by files in the temp dir; nothing touches the host.
set -uo pipefail
R="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
export DAG_STATE_DIR="$T/state" DAG_SLEEP=true DAG_NODES_DIR="$T/nodes"
# shellcheck source=../../bin/dag-lib.sh disable=SC1091
. "$R/bin/dag-lib.sh"
fail=0; n=0
ok()  { n=$((n+1)); printf 'ok  %s\n' "$1"; }
bad() { n=$((n+1)); fail=$((fail+1)); printf 'FAIL %s\n' "$1"; [ $# -gt 1 ] && printf '     %s\n' "${@:2}"; }
check() { if [ "$1" = "$2" ]; then ok "$3"; else bad "$3" "wanted [$1] got [$2]"; fi; }

# Fakes: each prints the content of a file in $T/world, or exits 1 when the file is absent.
mkdir -p "$T/world" "$T/nodes" "$T/bin"
for tool in git gh slot wo; do
  printf '#!/usr/bin/env bash\nf="%s/world/%s.$(printf "%%s" "$*" | tr -cs "a-zA-Z0-9" _)"\n[ -f "$f" ] && cat "$f" || exit 1\n' "$T" "$tool" >"$T/bin/$tool"
  chmod +x "$T/bin/$tool"
done
export DAG_GIT="$T/bin/git" DAG_GH="$T/bin/gh" DAG_SLOT="$T/bin/slot" DAG_WO="$T/bin/wo"
w() { printf '%s\n' "$2" >"$T/world/$1"; } # w <tool.args_with_underscores> <content>

printf '{"id":"N1","version":"1.0.0"}' >"$T/nodes/N1.node.json"
DSHA="$(cd "$T/nodes" && sha256sum -- *.node.json | LC_ALL=C sort -k2 | sha256sum | cut -d' ' -f1)"
printf 'artifact' >"$T/out.json"; OSHA="$(sha256sum "$T/out.json" | cut -d' ' -f1)"
printf '{"required_checks":["lint","unit"]}' >"$T/dag.json"

RUN=dagrun-20261016T090000Z-t4
RD="$DAG_STATE_DIR/runs/$RUN"
dag_init "$RUN" WO-9 "Nine" dag-state 1.0.0 "$DSHA" /wt/nine feat/nine slot-3
dag_write "$RUN" '.pr = {number:7,url:"u"}
  | .nodes.N3 = {status:"DG-DONE",version:"1.0.0",attempts:1,proofs:[]}
  | .nodes.N6 = {status:"DG-DONE",version:"1.0.0",attempts:1,proofs:[]}
  | .nodes.N8 = {status:"DG-DONE",version:"1.0.0",attempts:1,proofs:[],output:$o,output_sha256:$s}' --arg o "$T/out.json" --arg s "$OSHA"

clean_world() {
  rm -f "$T"/world/*
  w git.worktree_list_porcelain $'worktree /wt/nine\nHEAD abc\nbranch refs/heads/feat/nine\n'
  w slot.status_repo_wt_nine $'luna\tslot-3\t/wt/nine'
  w wo.show_id_WO_9_json '{"status":"in-review"}'
  w gh.pr_view_7_json_number_state '{"number":7,"state":"OPEN"}'
  w gh.pr_checks_7_json_name_bucket '[{"name":"lint","bucket":"pass"},{"name":"unit","bucket":"pass"}]'
}
drift() { bash "$R/bin/dag-drift.sh" --run "$RUN" --config "$T/dag.json" 2>"$T/err"; }
before() { sha256sum "$RD/state.json"; }

clean_world
B="$(before)"; out="$(drift)"; rc=$?
check 0 "$rc" "no drift exits 0"
check "" "$out" "no drift prints nothing"
check 1 "$(grep -c '"detail":"no drift"' "$RD/ledger.jsonl")" "a clean run writes one ledger row"
check "$B" "$(before)" "drift leaves state.json untouched"

# One case per check: the line names the code and carries both values.
case_drift() { # case_drift <label> <expected-line-regex>
  out="$(drift)"; rc=$?
  check 1 "$rc" "$1 exits 1"
  if grep -Eq "$2" <<<"$out"; then ok "$1 prints state and world"; else bad "$1 prints state and world" "got: $out"; fi
}

clean_world; printf '{"id":"N1","version":"1.0.1"}' >"$T/nodes/N1.node.json"
case_drift "design drift" "^DR-DESIGN state=$DSHA world=[0-9a-f]{64}$"
printf '{"id":"N1","version":"1.0.0"}' >"$T/nodes/N1.node.json"
rm -f "$T/nodes/N1.node.json"; case_drift "design dir empty" "^DR-DESIGN state=$DSHA world=missing$"
printf '{"id":"N1","version":"1.0.0"}' >"$T/nodes/N1.node.json"

clean_world; w git.worktree_list_porcelain $'worktree /wt/nine\nHEAD abc\nbranch refs/heads/feat/other\n'
case_drift "branch drift" '^DR-WORKTREE state=/wt/nine@feat/nine world=/wt/nine@feat/other$'
clean_world; w git.worktree_list_porcelain $'worktree /wt/else\nHEAD abc\nbranch refs/heads/feat/nine\n'
case_drift "worktree gone" '^DR-WORKTREE state=/wt/nine@feat/nine world=/wt/nine@absent$'

clean_world; w slot.status_repo_wt_nine $'-\tslot-3\t/wt/nine'
case_drift "lease freed" '^DR-LEASE state=held:slot-3 world=free$'

clean_world; w wo.show_id_WO_9_json '{"status":"ready"}'
case_drift "ticket status" '^DR-TICKET state=in-review\|in-progress world=ready$'

clean_world; w gh.pr_view_7_json_number_state '{"number":7,"state":"CLOSED"}'
case_drift "pr closed" '^DR-PR state=7:OPEN world=7:CLOSED$'

clean_world; w gh.pr_checks_7_json_name_bucket '[{"name":"lint","bucket":"pass"},{"name":"unit","bucket":"fail"}]'
case_drift "ci red" '^DR-CI N8 state=DG-DONE all-pass world=unit:fail$'

clean_world; printf 'changed' >"$T/out.json"
case_drift "output hash" "^DR-OUTPUT N8 state=$OSHA world=[0-9a-f]{64}$"
rm -f "$T/out.json"; case_drift "output file gone" "^DR-OUTPUT N8 state=$OSHA world=missing\$"
printf 'artifact' >"$T/out.json"

# A world tool that fails is drift with world=unreadable, never silence; it retried 3 times first.
clean_world; rm -f "$T/world/gh.pr_view_7_json_number_state"
case_drift "gh unreadable" '^DR-PR state=7:OPEN world=unreadable$'

# Merged PR is the expected state once N9 is done.
clean_world; dag_write "$RUN" '.nodes.N7 = {status:"DG-DONE",version:"1.0.0",attempts:1,proofs:[]} | .nodes.N9 = {status:"DG-DONE",version:"1.0.0",attempts:1,proofs:[]}'
w wo.show_id_WO_9_json '{"status":"done"}'; w gh.pr_view_7_json_number_state '{"number":7,"state":"MERGED"}'
out="$(drift)"; check 0 $? "merged pr and done ticket after N9 is no drift"

# Several mismatches: one line each, one ledger row each, state still untouched.
clean_world; w slot.status_repo_wt_nine $'-\tslot-3\t/wt/nine'; w wo.show_id_WO_9_json '{"status":"ready"}'
w gh.pr_view_7_json_number_state '{"number":7,"state":"MERGED"}'
B="$(before)"; rows0="$(wc -l <"$RD/ledger.jsonl")"; out="$(drift)"; rc=$?
check 1 "$rc" "two mismatches exit 1"
check 2 "$(grep -c '^DR-' <<<"$out")" "two mismatches print two lines"
check 2 "$(( $(wc -l <"$RD/ledger.jsonl") - rows0 ))" "two mismatches write two ledger rows"
check "$B" "$(before)" "drift with mismatches leaves state.json untouched"
check 0 "$(grep -vcE ' state=.+ world=.+' <<<"$out")" "every line carries both values"

# Usage and schema errors.
bash "$R/bin/dag-drift.sh" 2>/dev/null; check 2 $? "no run is exit 2"
bash "$R/bin/dag-drift.sh" --run dagrun-bad 2>/dev/null; check 2 $? "a bad run id is exit 2"
bash "$R/bin/dag-drift.sh" --bogus 2>/dev/null; check 2 $? "an unknown flag is exit 2"
printf '{}' >"$RD/state.json"; bash "$R/bin/dag-drift.sh" --run "$RUN" 2>/dev/null; check 3 $? "a state file failing its schema is exit 3"

printf 'pass=%s fail=%s\n' "$((n-fail))" "$fail"
[ "$fail" = 0 ]
