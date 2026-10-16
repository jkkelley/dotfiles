#!/usr/bin/env bash
# Stub for claude/workflow/bin/seat-record.sh, reached through SWEEP_SEAT_RECORD, for the watch suite.
# The real script validates against a declaration and writes under the user's state dir; a test must do neither.
# One line per call in $TEST_OUT/calls.log (`seat-record <args>`), and one JSON row per call in $TEST_OUT/records.jsonl:
# {outcome, workflow, ticket, pane, run_id, status, result_path}, built from the same flags the real script takes.
#   STUB_RECORD_FAIL=1  exit 1 after logging, as if the row did not validate
: "${TEST_OUT:?stub-seat-record: TEST_OUT must be set}"
printf 'seat-record %s\n' "$*" >>"$TEST_OUT/calls.log"
[ "${STUB_RECORD_FAIL:-0}" = 1 ] && exit 1
outcome="$1"; shift
wf="" ticket="" pane="" run_id="" status="" path=""
while [ $# -gt 0 ]; do
  case "$1" in
    --workflow) wf="$2"; shift 2 ;;
    --ticket) ticket="$2"; shift 2 ;;
    --pane) pane="$2"; shift 2 ;;
    --set) case "$2" in run_id=*) run_id="${2#*=}" ;; status=*) status="${2#*=}" ;; result_path=*) path="${2#*=}" ;; esac; shift 2 ;;
    *) shift ;;
  esac
done
jq -cn --arg o "$outcome" --arg w "$wf" --arg t "$ticket" --arg p "$pane" --arg r "$run_id" --arg s "$status" --arg f "$path" \
  '{outcome:$o, workflow:$w, ticket:$t, pane:$p, run_id:$r, status:$s, result_path:$f}' >>"$TEST_OUT/records.jsonl"
