#!/usr/bin/env bash
# AC-H1, AC-H2 for reply-verify.sh. Rules out: a near-match opening the gate (one changed, added, dropped or reordered
# character; case; a trailing space; a doubled trailing newline), a stale token from an earlier attempt surviving a mismatch,
# the newline rule being wider than written (CRLF, lone CR and ONE final LF pass; nothing else does), a token without an
# integer schema_version, and the message text leaking into the mismatch output.
set -uo pipefail
R="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=_t.sh
. "$R/tests/unit/_t.sh"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
S="$R/bin/reply-verify.sh"
printf 'Hi Sam,\n\nhappy to talk - %s\nBest, J' "it's Thursday" >"$T/send-m1.txt"
tok="$T/verified-m1.token"
verify() { bash "$S" --id m1 --approval "$T/send-m1.txt" --readback "$T/readback-m1.txt" 2>"$T/err"; }
# shellcheck disable=SC2059 # the format IS the argument: it spells out \r and \n
typed() { printf "$1" >"$T/readback-m1.txt"; }   # $1 is a printf format, so \r and \n can be spelled out

# AC-H2: exact match writes the token
cp "$T/send-m1.txt" "$T/readback-m1.txt"
out="$(verify)"; rc=$?
check 0 "$rc" "AC-H2: exact match exits 0"
check yes "$([ -f "$tok" ] && echo yes)" "AC-H2: exact match writes verified-<id>.token"
check "RP-VERIFIED m1 $(sha256sum "$T/send-m1.txt" | cut -d' ' -f1)" "$out" "AC-H2: prints the code, id and sha256"
check integer "$(jq -r '.schema_version | type | if . == "number" then "integer" else . end' "$tok")" "token carries an integer schema_version"
check 1 "$(jq -r .schema_version "$tok")" "token schema_version is 1"
check "$(sha256sum "$T/send-m1.txt" | cut -d' ' -f1)" "$(jq -r .approval_sha256 "$tok")" "token names the approval file's sha256"

# AC-H1: a one-character mismatch writes no token. A stale token is planted first: it must be removed, not kept.
mismatch() { # <label> <printf format of the typed text>
  typed "$2"; : >"$tok"
  out="$(verify)"; rc=$?
  check 1 "$rc" "AC-H1: $1 exits 1"
  check "RP-TEXT-MISMATCH m1" "$out" "AC-H1: $1 gives RP-TEXT-MISMATCH"
  check no "$([ -e "$tok" ] && echo yes || echo no)" "AC-H1: $1 leaves no token (stale one removed)"
}
mismatch "one changed character" "Hi Sam,\n\nhappy to talk - it's Thursdax\nBest, J"
mismatch "one dropped character" "Hi Sam,\n\nhappy to talk - it's Thursda\nBest, J"
mismatch "one added character" "Hi Sam,\n\nhappy to talk - it's Thursdayy\nBest, J"
mismatch "case change" "hi Sam,\n\nhappy to talk - it's Thursday\nBest, J"
mismatch "curly apostrophe" "Hi Sam,\n\nhappy to talk - it’s Thursday\nBest, J"
mismatch "one trailing space" "Hi Sam,\n\nhappy to talk - it's Thursday\nBest, J "
mismatch "one leading space" " Hi Sam,\n\nhappy to talk - it's Thursday\nBest, J"
mismatch "a blank line collapsed" "Hi Sam,\nhappy to talk - it's Thursday\nBest, J"
mismatch "two trailing newlines" "Hi Sam,\n\nhappy to talk - it's Thursday\nBest, J\n\n"
mismatch "a space for a newline" "Hi Sam, \nhappy to talk - it's Thursday\nBest, J"
mismatch "empty readback" ""
check no "$(grep -c "Thursday" "$T/err" | sed 's/^0$/no/;t;s/.*/leak/')" "mismatch detail never prints the message text"
grep -q 'first difference at byte' "$T/err"; check 0 "$?" "mismatch detail gives the first differing byte"

# The written newline rule: CRLF, lone CR and exactly one final LF are the only tolerated differences.
accept() { typed "$2"; rm -f "$tok"; verify >/dev/null; rc=$?; check 0 "$rc" "newline rule: $1 passes"; check yes "$([ -f "$tok" ] && echo yes)" "newline rule: $1 writes the token"; }
accept "CRLF line breaks" "Hi Sam,\r\n\r\nhappy to talk - it's Thursday\r\nBest, J"
accept "lone CR line breaks" "Hi Sam,\r\rhappy to talk - it's Thursday\rBest, J"
accept "one final LF" "Hi Sam,\n\nhappy to talk - it's Thursday\nBest, J\n"
accept "one final CRLF" "Hi Sam,\n\nhappy to talk - it's Thursday\nBest, J\r\n"
printf 'ends with newline\n' >"$T/send-m1.txt"
accept "approval ending in LF, readback without" "ends with newline"
accept "approval ending in LF, readback with" "ends with newline\n"

# Preconditions and usage
: >"$T/send-m1.txt"; typed ""
verify >/dev/null; check 3 "$?" "empty approval file is a precondition failure, never a match with an empty box"
bash "$S" --id m1 --approval "$T/nope" --readback "$T/readback-m1.txt" 2>/dev/null; check 3 "$?" "missing approval file exits 3"
bash "$S" --id m1 --approval "$T/send-m1.txt" --readback "$T/nope" 2>/dev/null; check 3 "$?" "missing readback exits 3"
bash "$S" --id '../x' --approval "$T/send-m1.txt" --readback "$T/readback-m1.txt" 2>/dev/null; check 2 "$?" "unsafe id exits 2"
bash "$S" 2>/dev/null; check 2 "$?" "no arguments exits 2"
finish
