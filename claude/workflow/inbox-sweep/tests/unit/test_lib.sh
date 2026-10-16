#!/usr/bin/env bash
# AC-H2: sweep_retry gives up after exactly 3 attempts, waits the configured seconds, exits 1 and records the step.
# Rules out: an unbounded loop (global rule: retry up to 3 times, then recover and report, never loop), a step that
# fails without a row in run.json, a recording that corrupts run.json, and a test that really sleeps 130 seconds.
# shellcheck disable=SC2317 # the helper functions are called indirectly, through sweep_retry
set -uo pipefail
R="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=_t.sh
. "$R/tests/unit/_t.sh"
# shellcheck source=../../bin/sweep-lib.sh
. "$R/bin/sweep-lib.sh"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
export SWEEP_RUN_DIR="$T/run"; mkdir -p "$SWEEP_RUN_DIR"
fresh() { echo '{"run_id":"20261016T000000Z"}' >"$SWEEP_RUN_DIR/run.json"; : >"$T/calls"; : >"$T/waits"; }
fake_sleep() { echo "$1" >>"$T/waits"; }
export SWEEP_SLEEP=fake_sleep
always_fail() { echo x >>"$T/calls"; return 1; }
fail_twice() { echo x >>"$T/calls"; [ "$(wc -l <"$T/calls")" -ge 3 ]; }

fresh
sweep_retry 3 probe-extension always_fail; rc=$?
check 1 "$rc" "always-failing command: sweep_retry exits 1"
check 3 "$(wc -l <"$T/calls")" "always-failing command runs exactly 3 times, not 2 and not 4"
check "10 30" "$(tr '\n' ' ' <"$T/waits" | sed 's/ $//')" "waits are 10 then 30 between attempts, none after the last"
check '{"step":"probe-extension","status":"failed","attempts":3}' \
  "$(jq -c '.steps[0] | {step,status,attempts}' "$SWEEP_RUN_DIR/run.json")" "the failed step is recorded with 3 attempts"
check yes "$(jq -r '.steps[0].at | test("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:]{8}Z$") | if . then "yes" else "no" end' "$SWEEP_RUN_DIR/run.json")" "the step row carries a UTC timestamp"
check 20261016T000000Z "$(jq -r .run_id "$SWEEP_RUN_DIR/run.json")" "recording keeps the rest of run.json"

fresh
sweep_retry 3 flaky fail_twice; rc=$?
check 0 "$rc" "a command that succeeds on attempt 3 exits 0"
check '{"status":"ok","attempts":3}' "$(jq -c '.steps[0] | {status,attempts}' "$SWEEP_RUN_DIR/run.json")" "success after retries is recorded ok with its attempt count"

fresh
sweep_retry 3 first-try true; check 0 "$(wc -l <"$T/waits")" "success on the first attempt waits for nothing"

fresh
SWEEP_RETRY_WAITS="1 2 3" sweep_retry 4 wait-list always_fail
check "1 2 3" "$(tr '\n' ' ' <"$T/waits" | sed 's/ $//')" "SWEEP_RETRY_WAITS overrides the waits; 4 attempts take three of them"
fresh
sweep_retry 4 default-waits always_fail
check "10 30 90" "$(tr '\n' ' ' <"$T/waits" | sed 's/ $//')" "default waits are 10, 30, 90 (the third is reached by a 4-attempt caller)"

sweep_retry 0 bad true 2>/dev/null; check 2 "$?" "attempts of 0 is a usage error, not an infinite or empty loop"
sweep_retry 3 2>/dev/null; check 2 "$?" "missing step and command is a usage error"
unset SWEEP_RUN_DIR
sweep_retry 3 no-run always_fail; check 1 "$?" "with no run dir the retry still runs and returns its code"
export SWEEP_RUN_DIR="$T/run"

fresh
sweep_check B0 "stubs log calls" "calls.log line 1"
sweep_check B0 "second box" "proof two"
check 2 "$(wc -l <"$SWEEP_RUN_DIR/checklist.jsonl")" "sweep_check appends one row per call"
check '{"node":"B0","box":"stubs log calls","proof":"calls.log line 1"}' "$(sed -n 1p "$SWEEP_RUN_DIR/checklist.jsonl" | jq -c '{node,box,proof}')" "a checklist row holds node, box and proof"
sweep_check B0 only-two 2>/dev/null; check 2 "$?" "sweep_check with the wrong argument count is refused"

fresh
# shellcheck disable=SC2016 # $v is a jq variable, not a shell one
sweep_json_set "$SWEEP_RUN_DIR/run.json" '.a = $v' --arg v "x y"
check "x y" "$(jq -r .a "$SWEEP_RUN_DIR/run.json")" "sweep_json_set applies the filter"
sweep_json_set "$SWEEP_RUN_DIR/run.json" 'this is not jq' 2>/dev/null; check 1 "$?" "a bad filter returns non-zero"
check "x y" "$(jq -r .a "$SWEEP_RUN_DIR/run.json")" "a bad filter leaves the file intact"
check 0 "$(find "$SWEEP_RUN_DIR" -name '.sweep-json.*' | wc -l)" "no temp file is left behind"

fresh
check "/mnt/c/Users/test" "$(SWEEP_WIN_HOME=/mnt/c/Users/test sweep_win_home)" "SWEEP_WIN_HOME is honoured"
SWEEP_WIN_HOME=/mnt/c/Users/test sweep_win_home >/dev/null
check "/mnt/c/Users/test" "$(jq -r .win_home "$SWEEP_RUN_DIR/run.json")" "the win home is cached in run.json"
check "/mnt/c/Users/test" "$(SWEEP_WIN_HOME=/elsewhere sweep_win_home)" "the cache wins over a later lookup"
check yes "$(sweep_now | grep -Eq '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$' && echo yes)" "sweep_now is UTC ISO-8601 with a Z"
finish
