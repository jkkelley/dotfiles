#!/usr/bin/env bash
# Stub `powershell.exe` for the inbox sweep's tests, installed as `powershell.exe` on PATH. It stands in for screen.ps1:
# the Podman image has no Windows, and a test must never grab a real screen. Logs one line per call to
# $TEST_OUT/calls.log as `powershell.exe <args>`.
#   STUB_PS_FAIL=1   exit 1 and write nothing (the capture-fails case)
#   STUB_PS_BAD=1    write a file that is not a PNG, exit 0
#   otherwise        write a PNG signature plus a few bytes to the path after -Out
: "${TEST_OUT:?stub-powershell-exe: TEST_OUT must be set}"
printf 'powershell.exe %s\n' "$*" >>"$TEST_OUT/calls.log"
[ "${STUB_PS_FAIL:-0}" = 1 ] && exit 1
out=""
while [ $# -gt 0 ]; do
  [ "$1" = "-Out" ] && out="${2:-}"
  shift
done
[ -n "$out" ] || exit 2
if [ "${STUB_PS_BAD:-0}" = 1 ]; then echo "not a png" >"$out"; else printf '\x89PNG\r\n\x1a\nstub-screen\n' >"$out"; fi
