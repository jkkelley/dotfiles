#!/usr/bin/env bash
# name: test_dag_merge.sh
# purpose: proves bin/dag-ci.sh (N8) and bin/dag-merge.sh (N9) keep the promises of docs/design/dag-state-nodes.spec.xml.
# inputs: none
# outputs: stdout (one ok/FAIL line per case, then the pass count), exit code
# writes-to: a mktemp scratch dir
# cleanup: removes its own temp dir on exit
# Each check names the failure it rules out: a red check passing N8, a pending check passing N8, polling forever past the
# timeout, N8 writing state, a merge with no approval, a merge for another design version, a merge on red CI, gh pr merge --auto,
# a second merge of an already merged PR, a merge that is not squash with the branch deleted.
set -uo pipefail
R="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
export DAG_STATE_DIR="$T/state" DAG_SLEEP=true DAG_RETRY_WAITS="0 0 0"
# shellcheck source=../../bin/dag-lib.sh disable=SC1091
. "$R/bin/dag-lib.sh"
fail=0; n=0
ok()  { n=$((n+1)); printf 'ok  %s\n' "$1"; }
bad() { n=$((n+1)); fail=$((fail+1)); printf 'FAIL %s\n' "$1"; [ $# -gt 1 ] && printf '     %s\n' "${@:2}"; }
check() { if [ "$1" = "$2" ]; then ok "$3"; else bad "$3" "wanted [$1] got [$2]"; fi; }

# Fake gh. checks: pops the first line of $T/checks.q (the last line repeats); view: prints $T/view; merge: logs, then view is MERGED.
mkdir -p "$T/bin"
cat >"$T/bin/gh" <<FAKE
#!/usr/bin/env bash
case "\$1 \$2" in
  "pr checks") q="$T/checks.q"; [ -s "\$q" ] || exit 1; head -n1 "\$q"; [ "\$(wc -l <"\$q")" -le 1 ] || sed -i 1d "\$q" ;;
  "pr view") cat "$T/view" ;;
  "pr merge") echo "\$*" >>"$T/merges"; [ -z "\${FAKE_MERGE_FAIL:-}" ] || exit 1
    echo '{"state":"MERGED","mergeCommit":{"oid":"abc123"}}' >"$T/view" ;;
  *) exit 1 ;;
esac
FAKE
chmod +x "$T/bin/gh"; export DAG_GH="$T/bin/gh"
printf '{"required_checks":["lint","unit"],"ci_poll_seconds":1,"ci_timeout_seconds":3,"approval_dir":"%s/appr"}' "$T" >"$T/dag.json"
export DAG_CONFIG="$T/dag.json"
mkdir -p "$T/appr"

RUN=dagrun-20261016T100000Z-t9
RD="$DAG_STATE_DIR/runs/$RUN"
SHA="$(printf 'x' | sha256sum | cut -d' ' -f1)"
dag_init "$RUN" WO-9 "Nine" dag-state 1.0.0 "$SHA" /wt/nine feat/nine
dag_write "$RUN" '.pr = {number:7,url:"u"}'
CI="$R/bin/dag-ci.sh"; MG="$R/bin/dag-merge.sh"
GREEN='[{"name":"lint","bucket":"pass"},{"name":"unit","bucket":"pass"},{"name":"other","bucket":"fail"}]'
RED='[{"name":"lint","bucket":"pass"},{"name":"unit","bucket":"fail"}]'
PEND='[{"name":"lint","bucket":"pass"},{"name":"unit","bucket":"pending"}]'
q() { printf '%s\n' "$@" >"$T/checks.q"; }
S0="$(sha256sum "$RD/state.json")"

bash "$CI" 2>/dev/null; check 2 $? "ci: no run is exit 2"
bash "$CI" --run dagrun-bad 2>/dev/null; check 2 $? "ci: a bad run id is exit 2"
q "$GREEN"; out="$(bash "$CI" --run "$RUN")"; check 0 $? "ci: all required green is exit 0 (a non-required fail is ignored)"
check green "$(jq -r .result "$RD/records/N8.ci.json")" "ci: result file says green"
check 2 "$(jq '.checks|length' "$RD/records/N8.ci.json")" "ci: result lists only the required checks"
q "$RED"; bash "$CI" --run "$RUN" >/dev/null; check 1 $? "ci: a red required check is exit 1"
check red "$(jq -r .result "$RD/records/N8.ci.json")" "ci: result file says red"
q "$PEND" "$PEND" "$GREEN"; out="$(bash "$CI" --run "$RUN")"; check 0 $? "ci: pending then green is exit 0"
check 2 "$(grep -c '^DG-CI pending' <<<"$out")" "ci: it polled twice while pending"
q "$PEND"; out="$(bash "$CI" --run "$RUN")"; check 1 $? "ci: pending past ci_timeout_seconds is exit 1"
grep -q '^DG-CI timeout' <<<"$out"; check 0 $? "ci: the timeout is named"
q '[{"name":"lint","bucket":"pass"}]'; bash "$CI" --run "$RUN" >/dev/null; check 1 $? "ci: a required check absent from the PR is not green"
rm -f "$T/checks.q"; bash "$CI" --run "$RUN" >/dev/null; check 1 $? "ci: gh unreadable until the timeout is exit 1, not a pass"
check "$S0" "$(sha256sum "$RD/state.json")" "ci: state.json untouched"
echo '{}' >"$T/empty.json"; DAG_CONFIG="$T/empty.json" bash "$CI" --run "$RUN" >/dev/null 2>&1; check 2 $? "ci: empty required_checks is refused, exit 2"

# merge
echo '{"state":"OPEN","mergeCommit":null}' >"$T/view"; rm -f "$T/merges"
printf '{"result":"green"}' >"$RD/records/N8.ci.json"
out="$(bash "$MG" --run "$RUN")"; check 1 $? "merge: no approval file is exit 1"
grep -q '^DG-APPROVAL-MISSING' <<<"$out"; check 0 $? "merge: names DG-APPROVAL-MISSING"
check no "$([ -f "$T/merges" ] && echo yes || echo no)" "merge: gh pr merge not called without approval"
echo "design dag-state version 0.9.0" >"$T/appr/a.txt"
bash "$MG" --run "$RUN" >/dev/null; check 1 $? "merge: approval for another version does not count"
echo "approved: dag-state 1.0.0" >"$T/appr/b.txt"
printf '{"result":"red"}' >"$RD/records/N8.ci.json"
out="$(bash "$MG" --run "$RUN")"; check 1 $? "merge: red CI result is exit 1"
grep -q '^DG-CI-NOT-GREEN' <<<"$out"; check 0 $? "merge: names DG-CI-NOT-GREEN"
check no "$([ -f "$T/merges" ] && echo yes || echo no)" "merge: gh pr merge not called on red CI"
printf '{"result":"green"}' >"$RD/records/N8.ci.json"
FAKE_MERGE_FAIL=1 bash "$MG" --run "$RUN" >/dev/null; check 1 $? "merge: a failing gh pr merge is exit 1"
rm -f "$T/merges"
out="$(bash "$MG" --run "$RUN")"; check 0 $? "merge: approved and green is exit 0"
check "pr merge 7 --squash --delete-branch" "$(cat "$T/merges")" "merge: squash, delete branch, no --auto"
check abc123 "$(jq -r .merge_commit "$RD/records/N9.merge.json")" "merge: merge commit recorded"
check MERGED "$(jq -r .state "$RD/records/N9.merge.json")" "merge: result state MERGED"
bash "$MG" --run "$RUN" >/dev/null; check 0 $? "merge: run again on a MERGED PR is exit 0"
check 1 "$(wc -l <"$T/merges")" "merge: the PR is merged once, not twice"
check "$S0" "$(sha256sum "$RD/state.json")" "merge: state.json untouched"

printf 'pass=%s fail=%s\n' "$((n-fail))" "$fail"
[ "$fail" = 0 ]
