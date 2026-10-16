#!/usr/bin/env bash
# rolodex: header drafted by scripts/rolodex.py headers - correct any line that is wrong
# name: test_a2a_state.sh
# purpose: proves a seat state file has one checked shape per row (WO-20261016-8454, TP-1).
# inputs: none (uses brief.sh and the schemas in the repo)
# outputs: one 'ok <case>' line per case, 'FAIL <case>' and exit 1 otherwise
# writes-to: a mktemp scratch directory only
# cleanup: removes its own temp files on exit
set -euo pipefail
R="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
B="$R/bin/brief.sh"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
fail=0
ok()  { printf 'ok %s\n' "$1"; }
bad() { fail=1; printf 'FAIL %s\n' "$1"; }

printf '%s\n' \
  '{"step":"AC1","status":"started","at":"2026-10-16T05:00:00Z","proof":""}' \
  '{"step":"AC1","status":"done","at":"2026-10-16T05:01:00Z","proof":"exit 0"}' \
  '{"step":"AC2","status":"skipped","at":"2026-10-16T05:02:06Z","proof":""}' > "$T/valid.jsonl"
if bash "$B" state-check "$T/valid.jsonl" >/dev/null 2>&1; then ok "3-row valid file passes"; else bad "3-row valid file passes"; fi

echo '{"step":"AC1","status":"finished","at":"2026-10-16T05:00:00Z","proof":"x"}' > "$T/s.jsonl"
if bash "$B" state-check "$T/s.jsonl" >/dev/null 2>&1; then bad "status finished fails"; else ok "status finished fails"; fi

echo '{"step":"AC1","status":"started","at":"2026-10-16T05:02:06+02:00","proof":""}' > "$T/a.jsonl"
if bash "$B" state-check "$T/a.jsonl" >/dev/null 2>&1; then bad "non-UTC at fails"; else ok "non-UTC at fails"; fi

echo '{"step":"AC1","status":"done","at":"2026-10-16T05:00:00Z","proof":""}' > "$T/p.jsonl"
if bash "$B" state-check "$T/p.jsonl" >/dev/null 2>&1; then bad "done with empty proof fails"; else ok "done with empty proof fails"; fi

jq '.output.state_file = "/tmp/x/state.jsonl"' "$R/templates/a2a/brief.json" > "$T/brief.json"
if bash "$B" check "$T/brief.json" >/dev/null 2>&1; then ok "brief with output.state_file passes check"; else bad "brief with output.state_file passes check"; fi

exit "$fail"
