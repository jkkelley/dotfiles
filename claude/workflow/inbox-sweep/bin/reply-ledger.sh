#!/usr/bin/env bash
# shellcheck disable=SC2016 # jq filters use $var; they are jq variables, single quotes are the point
# (no node marker: B21c was a build ticket id, not a design node, and failed nodes-check on main b4d1b2e; the spec names
#  only this script as the owner of ledger.jsonl, so no node is claimed - WO-20261016-529a)
# name: reply-ledger.sh
# purpose: the one writer of ledger.jsonl; validates every row from stdin, then appends them all or none
# inputs: append --file <ledger.jsonl>, JSON rows on stdin
# outputs: exit 0 on append, exit 2 with the reason on stderr when any row is invalid
# writes-to: the ledger.jsonl named by --file
# cleanup: none (append-only event log)
# reply-ledger.sh - the one writer of ledger.jsonl (design 18, ruling R3, node B21c).
#
#   reply-ledger.sh append --file <ledger.jsonl> < rows.jsonl   append every row read from stdin to the ledger
#
# reply-cards.sh, reply-approve.sh, reply-send.sh and lead-followup.sh used to each open the ledger with `>>` and build their
# own row, so four scripts agreed on its shape by habit. They now pipe their rows to `append`, and a change to the file's
# shape or validation is a change to this one file (the same split as lead-ledger.sh for leads.jsonl).
# append validates before it writes: every row must be a JSON object with a non-empty string code, a non-empty string id and an
# integer schema_version. If any row fails, nothing is written (exit 2), so a half-valid batch never lands. The ledger is an
# event log, so rows are appended as given, never upserted; the callers keep their own exactly-once checks. Rejected
# alternative: a sourced function; grep could then not prove a single writer, and a script behind a verb can be tested alone.
#
# Exit: 0 appended (an empty stdin appends nothing); 2 usage or an invalid row.
# Environment: none. The ledger path is always the --file argument.
set -euo pipefail

usage() { echo "usage: reply-ledger.sh append --file <ledger.jsonl> < rows.jsonl" >&2; exit 2; }
[ "${1:-}" = append ] || usage
shift
file=""
while [ $# -gt 0 ]; do
  case "$1" in
    --file) [ $# -ge 2 ] || usage; file="$2"; shift 2 ;;
    *) usage ;;
  esac
done
[ -n "$file" ] || usage

rows="$(cat)"
[ -n "$rows" ] || exit 0
bad="$(jq -c 'select((type == "object" and ((.code | type) == "string") and (.code != "") and ((.id | type) == "string") and (.id != "")
  and ((.schema_version | type) == "number") and (.schema_version == (.schema_version | floor))) | not)' <<<"$rows" 2>&1)" \
  || { echo "reply-ledger: stdin is not JSON: $bad" >&2; exit 2; }
if [ -n "$bad" ]; then
  echo "reply-ledger: refused, a row lacks code, id or an integer schema_version: $bad" >&2
  exit 2
fi
mkdir -p "$(dirname "$file")"
jq -c . <<<"$rows" >>"$file"
