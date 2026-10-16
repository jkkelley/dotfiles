#!/usr/bin/env bash
# reply-verify.sh - L8 of the LinkedIn reply DAG, build node B17a: the character check before Send.
#
#   reply-verify.sh --id <draft id> --approval <send-*.txt> --readback <readback-<id>.txt>
#
# Compares the text the seat typed (its readback of the message box) with the owner-approved file, byte for byte under ONE
# newline rule, and only on an exact match writes verified-<id>.token beside the readback. The seat clicks nothing until the
# token exists (design 14.3 L8, spec reply-dag L8). Send is never reachable on a near-match.
#
# THE NEWLINE RULE (the only normalisation, applied identically to both sides, nothing else is ever trimmed or folded):
#   1. every CRLF becomes LF, then every remaining lone CR becomes LF (a browser box reads back line breaks as CRLF or CR);
#   2. then exactly ONE final LF is dropped, if there is one (a box read back through a tool often gains a trailing newline
#      the owner never typed, and an approved file may end in one).
# Case, spaces, tabs, tabs-vs-spaces, doubled blank lines, a second trailing newline, a trailing space: all differences.
# Rejected alternative: trimming whitespace at the ends. The owner approved exact bytes (design 14.5); a trimmed compare would
# let "end " and "end" both pass and a Send go out that the owner never read.
#
# Output (one line):  RP-VERIFIED <id> <sha256>   or   RP-TEXT-MISMATCH <id>
# A mismatch removes any token left by an earlier attempt, so a stale token can never open the gate for different text.
# The mismatch detail (first differing byte offset, lengths) goes to stderr as numbers only, never the message text.
# Single shot: the three retypes of RP-TEXT-MISMATCH (spec failures/mismatch) are the controller's loop (B17b), not this script's.
#
# Exit: 0 verified; 1 RP-TEXT-MISMATCH; 2 usage; 3 precondition (a file missing, or the approval file empty or not text).
# The token is one JSON line with an integer schema_version (design 15.2, version 1): code, id, sha256 of the normalised text,
# the sha256 of the approval file as given (so the controller can match it to approvals.jsonl), and the UTC time.
#
# Design: docs/design/inbox-sweep.md section 10 (B17), spec nodes reply-dag L8 and build node B17.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=sweep-lib.sh
. "$HERE/sweep-lib.sh"

usage() { echo "usage: reply-verify.sh --id <draft id> --approval <file> --readback <file>" >&2; exit 2; }
id="" approval="" readback=""
while [ $# -gt 0 ]; do
  case "$1" in
    --id) [ $# -ge 2 ] || usage; id="$2"; shift 2 ;;
    --approval) [ $# -ge 2 ] || usage; approval="$2"; shift 2 ;;
    --readback) [ $# -ge 2 ] || usage; readback="$2"; shift 2 ;;
    *) usage ;;
  esac
done
{ [ -n "$id" ] && [ -n "$approval" ] && [ -n "$readback" ]; } || usage
[[ $id =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] || { echo "reply-verify: bad id '$id'" >&2; exit 2; }
[ -f "$approval" ] || { echo "reply-verify: no approval file $approval" >&2; exit 3; }
[ -f "$readback" ] || { echo "reply-verify: no readback file $readback" >&2; exit 3; }
[ -s "$approval" ] || { echo "reply-verify: approval file is empty" >&2; exit 3; }

token="$(dirname "$readback")/verified-$id.token"
scratch="$(mktemp -d)"
trap 'rm -rf "$scratch"' EXIT

# The newline rule, in one place. perl -0777 reads the whole file as one string; -p prints it back with no added newline.
normalise() { perl -0777 -pe 's/\r\n/\n/g; s/\r/\n/g; s/\n\z//' "$1"; }
normalise "$approval" >"$scratch/a"
normalise "$readback" >"$scratch/r"

if cmp -s "$scratch/a" "$scratch/r"; then
  sha="$(sha256sum "$scratch/a" | cut -d' ' -f1)"
  asha="$(sha256sum "$approval" | cut -d' ' -f1)"
  # Temp file in the same folder then mv: a seat polling for the token never sees half of one.
  jq -cn --arg at "$(sweep_now)" --arg id "$id" --arg sha "$sha" --arg asha "$asha" \
    '{schema_version:1, code:"RP-VERIFIED", id:$id, sha256:$sha, approval_sha256:$asha, at:$at}' >"$token.tmp"
  mv "$token.tmp" "$token"
  echo "RP-VERIFIED $id $sha"
  exit 0
fi

rm -f "$token" "$token.tmp"
off="$(cmp "$scratch/a" "$scratch/r" 2>/dev/null | sed -n 's/.*byte \([0-9]*\).*/\1/p' | head -n1 || true)"
echo "reply-verify: first difference at byte ${off:-end}; approved $(wc -c <"$scratch/a") bytes, typed $(wc -c <"$scratch/r") bytes" >&2
echo "RP-TEXT-MISMATCH $id"
exit 1
