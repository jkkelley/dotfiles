#!/usr/bin/env bash
# AC-H1/H2/H3 for sweep-clean.sh. Rules out: prune deleting a run inside the window (a 13-day run must survive 14),
# prune keeping an expired one, clean running on a live run (RUN-RUNNING), clean closing another run's tab or a tab
# that merely looks similar, and prune destroying record rows it cannot parse.
set -uo pipefail
R="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=_t.sh
. "$R/tests/unit/_t.sh"
# shellcheck source=../lib/stubs.sh
. "$R/tests/lib/stubs.sh"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
export TEST_OUT="$T/out" SWEEP_SLEEP=true
stubs_install "$T/bin"
# Wrap the stub: a richer `tab list` (two runs' seat tabs plus a lookalike), everything else is the stub's.
cp "$T/bin/herdr" "$T/bin/herdr.real"
cat >"$T/bin/herdr" <<'W'
#!/usr/bin/env bash
if [ "${1:-} ${2:-}" = "tab list" ]; then
  printf 'herdr tab list\n' >>"$TEST_OUT/calls.log"
  printf '{"result":{"tabs":[{"tab_id":"t1","label":"orchestrator"},{"tab_id":"t2","label":"agent-sweep-gmail"},{"tab_id":"t3","label":"agent-sweep-linkedin"},{"tab_id":"t4","label":"agent-sweep-gmail-extra"}]}}\n'
  exit 0
fi
exec "$(dirname "$0")/herdr.real" "$@"
W
chmod +x "$T/bin/herdr"
export SWEEP_RUNS_ROOT="$T/runs" SWEEP_LATEST="$T/latest" SWEEP_EXEC_DIR="$T/exec" SWEEP_TEST_OUT="$T/test-out"
S="$R/bin/sweep-clean.sh"
stamp() { date -u -d "$1 days ago" +%Y%m%dT%H%M%SZ; }
mkrun() { mkdir -p "$SWEEP_RUNS_ROOT/$1/briefs"; echo x >"$SWEEP_RUNS_ROOT/$1/briefs/b.md"; printf '{"run_id":"%s","status":"%s"}\n' "$1" "$2" >"$SWEEP_RUNS_ROOT/$1/run.json"; }
mkseat() { mkdir -p "$SWEEP_EXEC_DIR/seats/$1"; printf '{"seat":"%s","ticket":"%s","pane":"%s"}\n' "$2" "$3" "$1" >"$SWEEP_EXEC_DIR/seats/$1/seat-link"; }

# prune
d13="$(stamp 13)"; d15="$(stamp 15)"
mkrun "$d13" RUN-OK; mkrun "$d15" RUN-OK
mkdir -p "$SWEEP_EXEC_DIR/records"
printf '%s\n' "{\"run_id\":\"$d13\",\"s\":1}" "{\"run_id\":\"$d15\",\"s\":2}" "not json" '{"no":"run id"}' >"$SWEEP_EXEC_DIR/records/inbox-sweep-gmail.jsonl"
ln -s "$SWEEP_RUNS_ROOT/$d15" "$SWEEP_LATEST"
bash "$S" prune --days 14 >/dev/null; rc=$?
check 0 "$rc" "prune --days 14 exits 0"
check yes "$([ -d "$SWEEP_RUNS_ROOT/$d13" ] && echo yes || echo no)" "AC-H1: the 13-day run is kept"
check no "$([ -d "$SWEEP_RUNS_ROOT/$d15" ] && echo yes || echo no)" "AC-H1: the 15-day run is removed"
check no "$([ -L "$SWEEP_LATEST" ] && echo yes || echo no)" "the dangling latest link is removed"
check 3 "$(wc -l <"$SWEEP_EXEC_DIR/records/inbox-sweep-gmail.jsonl")" "the expired record row is dropped; the fresh, unparsable and run-less rows stay"
check 0 "$(grep -c "$d15" "$SWEEP_EXEC_DIR/records/inbox-sweep-gmail.jsonl")" "no row of the expired run is left"
bash "$S" prune --days 0 >/dev/null 2>&1; check 2 "$?" "prune --days 0 is refused"
bash "$S" prune --days x >/dev/null 2>&1; check 2 "$?" "prune --days x is refused"

# clean refuses a running run
run="$(stamp 0)"; mkrun "$run" RUN-RUNNING
bash "$S" clean --run "$run" >/dev/null 2>&1; rc=$?
check 3 "$rc" "AC-H2: clean refuses RUN-RUNNING"
check yes "$([ -d "$SWEEP_RUNS_ROOT/$run/briefs" ] && echo yes || echo no)" "AC-H2: a refused clean removes nothing"

# clean closes only this run's tabs
other="$(stamp 1)"; mkrun "$other" RUN-OK
mkseat wS_p2 gmail "IS-$run"; mkseat wS_p3 linkedin "IS-$other"
jq '.status="RUN-OK"' "$SWEEP_RUNS_ROOT/$run/run.json" >"$T/j" && mv "$T/j" "$SWEEP_RUNS_ROOT/$run/run.json"
: >"$TEST_OUT/calls.log"
bash "$S" clean --run "$run" >/dev/null; rc=$?
check 0 "$rc" "clean on a finished run exits 0"
check "herdr tab close t2" "$(grep 'tab close' "$TEST_OUT/calls.log")" "AC-H3: only this run's tab is closed (not linkedin t3, not the lookalike t4)"
check no "$([ -d "$SWEEP_RUNS_ROOT/$run/briefs" ] && echo yes || echo no)" "briefs are removed"
check no "$([ -d "$SWEEP_EXEC_DIR/seats/wS_p2" ] && echo yes || echo no)" "this run's seat dir is removed"
check yes "$([ -d "$SWEEP_EXEC_DIR/seats/wS_p3" ] && echo yes || echo no)" "another run's seat dir stays"
check yes "$(jq -r '.cleaned_at | test("Z$") | if . then "yes" else "no" end' "$SWEEP_RUNS_ROOT/$run/run.json")" "cleaned_at is set"
check yes "$([ -f "$SWEEP_RUNS_ROOT/$run/logs/clean.log" ] && grep -q 'tab list after close' "$SWEEP_RUNS_ROOT/$run/logs/clean.log" && echo yes || echo no)" "clean.log holds the tab list taken after close"

# a tab that will not close is reported, not looped on, and the run is not marked cleaned
mkrun "$(stamp 2)" RUN-OK; f2="$(stamp 2)"; mkseat wS_p4 gmail "IS-$f2"
: >"$TEST_OUT/calls.log"
STUB_HERDR_FAIL=1 bash "$S" clean --run "$f2" >/dev/null 2>&1; rc=$?
check 1 "$rc" "a tab that will not close gives exit 1"
check 0 "$(jq -r 'has("cleaned_at") | if . then 1 else 0 end' "$SWEEP_RUNS_ROOT/$f2/run.json")" "no cleaned_at when a tab is left"

# no runs: test output goes
rm -rf "$SWEEP_RUNS_ROOT"; mkdir -p "$SWEEP_TEST_OUT"; echo x >"$SWEEP_TEST_OUT/f"
bash "$S" clean >/dev/null; check no "$([ -e "$SWEEP_TEST_OUT" ] && echo yes || echo no)" "clean with no run removes test output"
finish
