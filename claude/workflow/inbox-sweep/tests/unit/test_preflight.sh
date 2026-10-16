#!/usr/bin/env bash
# AC-H1: every PF-* code has a fixture test, run against the stub herdr and stub claude.exe.
# AC-H2: an extension probe answering [] is tried exactly 3 times, then PF-NO-BROWSER (counted in calls.log).
# Rules out: a probe that trusts a sleeping extension's [], a fourth attempt or a second one never made (the retry rule
# is exactly 3), a failing precondition that still launches probes behind it, and a refusal that leaves no record.
set -uo pipefail
R="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=_t.sh
. "$R/tests/unit/_t.sh"
# shellcheck source=../lib/stubs.sh
. "$R/tests/lib/stubs.sh"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
export TEST_OUT="$T/out"
stubs_install "$T/bin"
LOG="$TEST_OUT/calls.log"
PRE="$R/bin/sweep-preflight.sh"
RUN_ID=20261016T000000Z
export SWEEP_WIN_HOME="$T/win" SWEEP_RETRY_WAITS="0 0 0" SWEEP_SLEEP=true HERDR_ENV=1
mkdir -p "$SWEEP_WIN_HOME/.local/bin"
cp "$T/bin/claude.exe" "$SWEEP_WIN_HOME/.local/bin/claude.exe"
# tasklist.exe is not a shared stub (only this suite uses it): CHROME=1 prints a chrome row, anything else prints the
# INFO line the real tool prints for no match.
cat >"$T/bin/tasklist.exe" <<'STUB'
#!/usr/bin/env bash
printf 'tasklist.exe %s\n' "$*" >>"$TEST_OUT/calls.log"
if [ "${STUB_CHROME:-1}" = 1 ]; then echo "chrome.exe                    4242 Console                    1    210,000 K"
else echo "INFO: No tasks are running which match the specified criteria."; fi
STUB
chmod +x "$T/bin/tasklist.exe"
GOOD='{"result":"[{\"deviceId\":\"d1\",\"name\":\"Your Chrome\"}]"}'

# fresh <name>: a new run dir with run.json, an empty call log, and probe state cleared
fresh() {
  export SWEEP_RUN_DIR="$T/$1/runs/$RUN_ID"
  rm -rf "${T:?}/$1"; mkdir -p "$SWEEP_RUN_DIR"
  echo "{\"run_id\":\"$RUN_ID\"}" >"$SWEEP_RUN_DIR/run.json"
  : >"$LOG"; rm -f "$TEST_OUT/claude-exe.count"
  unset STUB_CLAUDE_SEQ STUB_CLAUDE_FAIL STUB_HERDR_FAIL STUB_CHROME
  export HERDR_ENV=1
}
code_of() { jq -r --arg id "$1" '.checks[] | select(.id==$id) | .code' "$SWEEP_RUN_DIR/preflight.json"; }
# probes: how many extension probe calls reached claude.exe (the --version call does not carry --chrome)
probes() { grep -c '^claude.exe -p --chrome ' "$LOG" || true; }
seq_file() { printf '%s\n' "$@" >"$T/seq"; export STUB_CLAUDE_SEQ="$T/seq"; }

# PF-OK: every check passes on the first try
fresh ok; seq_file "2.0.0 (Claude Code)" "$GOOD"
bash "$PRE" --run "$RUN_ID" >/dev/null 2>&1; rc=$?
check 0 "$rc" "PF-OK: exits 0"
check "PF-OK PF-OK PF-OK PF-OK" "$(for i in herdr claude-exe chrome extension; do code_of $i; done | tr '\n' ' ' | sed 's/ $//')" "PF-OK: all four checks pass"
check 1 "$(probes)" "PF-OK: the extension was probed once, not three times"
check "$RUN_ID" "$(jq -r .run_id "$SWEEP_RUN_DIR/preflight.json")" "preflight.json names the run"
check 1 "$(jq -r .schema_version "$SWEEP_RUN_DIR/preflight.json")" "preflight.json carries schema_version 1"
check yes "$(jq -r '.checked_at | test("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:]{8}Z$") | if . then "yes" else "no" end' "$SWEEP_RUN_DIR/preflight.json")" "checked_at is UTC"
check "2.0.0 (Claude Code)" "$(jq -r '.checks[] | select(.id=="claude-exe") | .evidence' "$SWEEP_RUN_DIR/preflight.json")" "claude.exe version string is the evidence"
check 4 "$(jq -s 'map(select(.node=="R2")) | length' "$SWEEP_RUN_DIR/checklist.jsonl")" "four R2 checklist rows, one per passed box"

# PF-NO-HERDR: not inside herdr; exit 3, no probe behind it, but a record
fresh nohdr; unset HERDR_ENV
bash "$PRE" --run "$RUN_ID" >/dev/null 2>&1; rc=$?
check 3 "$rc" "PF-NO-HERDR: HERDR_ENV unset exits 3"
check PF-NO-HERDR "$(code_of herdr)" "PF-NO-HERDR: recorded in preflight.json"
check 0 "$(grep -c '^claude.exe\|^tasklist.exe' "$LOG")" "PF-NO-HERDR: no later probe ran"
fresh nohdr2; STUB_HERDR_FAIL=1 bash "$PRE" --run "$RUN_ID" >/dev/null 2>&1; rc=$?
check "3 PF-NO-HERDR" "$rc $(code_of herdr)" "PF-NO-HERDR: a failing herdr also refuses"

# PF-NO-CLAUDE-EXE: not runnable; chrome is still checked, the extension is not probed
fresh noexe; STUB_CLAUDE_FAIL=1 bash "$PRE" --run "$RUN_ID" >/dev/null 2>&1; rc=$?
check "0 PF-NO-CLAUDE-EXE PF-OK PF-NO-CLAUDE-EXE" "$rc $(code_of claude-exe) $(code_of chrome) $(code_of extension)" "PF-NO-CLAUDE-EXE: reported, extension not probed"
check 0 "$(probes)" "PF-NO-CLAUDE-EXE: no extension probe call"
rm -f "$SWEEP_WIN_HOME/.local/bin/claude.exe.keep"
mv "$SWEEP_WIN_HOME/.local/bin/claude.exe" "$SWEEP_WIN_HOME/.local/bin/claude.exe.keep"
fresh noexe2; bash "$PRE" --run "$RUN_ID" >/dev/null 2>&1
check PF-NO-CLAUDE-EXE "$(code_of claude-exe)" "PF-NO-CLAUDE-EXE: a missing binary is the same code"
mv "$SWEEP_WIN_HOME/.local/bin/claude.exe.keep" "$SWEEP_WIN_HOME/.local/bin/claude.exe"

# PF-NO-CHROME: no chrome.exe; extension not probed
fresh nochrome; seq_file "2.0.0" "$GOOD"; STUB_CHROME=0 bash "$PRE" --run "$RUN_ID" >/dev/null 2>&1; rc=$?
check "0 PF-NO-CHROME PF-NO-CHROME" "$rc $(code_of chrome) $(code_of extension)" "PF-NO-CHROME: reported, extension not probed"
check 0 "$(probes)" "PF-NO-CHROME: no extension probe call"

# PF-NO-BROWSER (AC-H2): [] every time is tried exactly 3 times
fresh nobrowser; seq_file "2.0.0" "[]"
bash "$PRE" --run "$RUN_ID" >/dev/null 2>&1; rc=$?
check "0 PF-NO-BROWSER" "$rc $(code_of extension)" "PF-NO-BROWSER: [] three times is the code, exit 0 (gmail still runs)"
check 3 "$(probes)" "PF-NO-BROWSER: the probe was called exactly 3 times (calls.log)"
check 3 "$(jq -r '.checks[] | select(.id=="extension") | .attempts' "$SWEEP_RUN_DIR/preflight.json")" "PF-NO-BROWSER: attempts recorded as 3"
check 3 "$(grep -c '^\[attempt ' "$SWEEP_RUN_DIR/logs/preflight.log")" "PF-NO-BROWSER: raw output of each attempt is in logs/preflight.log"
check 3 "$(jq -r '.steps[] | select(.step=="probe-extension") | .attempts' "$SWEEP_RUN_DIR/run.json")" "PF-NO-BROWSER: the retried step is recorded in run.json"

# a sleeping extension that wakes on the 2nd try passes, and stops probing
fresh wakes; seq_file "2.0.0" "[]" "$GOOD"
bash "$PRE" --run "$RUN_ID" >/dev/null 2>&1
check "PF-OK 2" "$(code_of extension) $(probes)" "extension answering on the 2nd try passes after exactly 2 probes"

# usage errors write nothing
fresh usage
bash "$PRE" >/dev/null 2>&1; check 2 "$?" "no arguments is a usage error (exit 2)"
bash "$PRE" --run not-an-id >/dev/null 2>&1; check 2 "$?" "a malformed run id is a usage error (exit 2)"
rm -f "$SWEEP_RUN_DIR/run.json"; bash "$PRE" --run "$RUN_ID" >/dev/null 2>&1; rc=$?
check "2 absent" "$rc $([ -e "$SWEEP_RUN_DIR/preflight.json" ] || echo absent)" "no run.json: exit 2 and preflight.json not written"
finish
