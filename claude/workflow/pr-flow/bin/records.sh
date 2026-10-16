#!/usr/bin/env bash
# name: records.sh
# purpose: write and read pr-flow records, on the bus or in coq's records tree, posting each one at most once
# inputs: verb and flags below; env PR_FLOW_RECORDS (bus|dir), PR_FLOW_RECORDS_DIR, PR_FLOW_STATE, PR_FLOW_PUB
# outputs: post prints the record JSON, or nothing when it was already posted; seen exits 0/1
# writes-to: bus subject line.<line>.event.<kind>, or <records_dir>/YYYY/MM/<id>.json; the posted ledger under PR_FLOW_STATE
# cleanup: make pr-flow-clean removes PR_FLOW_STATE; the bus drops records after max_age
#
#   records.sh post --kind K --code C --ticket T --line L --seat S [--pr N] [--sha SHA] [--repo O/N] [--note TEXT] [--key KEY]
#   records.sh seen --key KEY          0 a record with this dedupe key was posted, 1 not
#
# Ported from coq events/bin/event.sh (one file per record, UTC id, kind/code/ticket/sha/pr fields) and line/bin/merge.sh's
# post-once lookups (rule R3). Backends (pr-process.md section 10, records): `dir` writes coq's tree layout, so coq can read it;
# `bus` publishes to line.<line>.event.<kind> through bin/bus.sh (or PR_FLOW_PUB, which the tests stub).
# BREADCRUMB 2026-10-16 - BR-20261016-merge-port, WO-20261016-984d. Why a local ledger for post-once: a durable pull consumer acks
#   what it reads, so the bus cannot answer "was this posted"; the ledger is one line per key under the state root and is the
#   only state this script keeps. Rejected: reading the stream back on every post (a podman call per record, seconds each).
#   Cost: two hosts posting the same key would both post; pr-flow runs one sweep per line.
# Exit: 0 ok, 2 usage, 3 the record fails the schema, 4 io.
set -uo pipefail
HERE="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
SCHEMA="$HERE/../schemas/pr-flow-record.schema.json"
BACKEND="${PR_FLOW_RECORDS:-bus}"
STATE="${PR_FLOW_STATE:-$HOME/.local/state/zenith/pr-flow}"
LEDGER="$STATE/posted.keys"
die() { local c=$1; shift; echo "records: $*" >&2; exit "$c"; }
VERB="${1:-}"; shift || true
KIND=""; CODE=""; TICKET=""; LINE=""; SEAT=""; PR=""; SHA=""; REPO=""; NOTE=""; KEY=""
while [ $# -gt 0 ]; do case $1 in
  --kind) KIND=${2:?}; shift 2;; --code) CODE=${2:?}; shift 2;; --ticket) TICKET=${2:?}; shift 2;; --line) LINE=${2:?}; shift 2;;
  --seat) SEAT=${2:?}; shift 2;; --pr) PR=${2:?}; shift 2;; --sha) SHA=${2:?}; shift 2;; --repo) REPO=${2:?}; shift 2;;
  --note) NOTE=${2:?}; shift 2;; --key) KEY=${2:?}; shift 2;; *) die 2 "unknown argument $1";; esac; done

seen() { [ -f "$LEDGER" ] && grep -qxF -- "$1" "$LEDGER"; }
case $VERB in
  seen) [ -n "$KEY" ] || die 2 "seen needs --key"; seen "$KEY"; exit $? ;;
  post) ;;
  *) sed -n '10,11p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 2 ;;
esac
for v in KIND CODE TICKET LINE SEAT; do [ -n "${!v}" ] || die 2 "post needs --${v,,}"; done
case $BACKEND in bus|dir) ;; *) die 2 "PR_FLOW_RECORDS is bus or dir, not $BACKEND";; esac
[ -z "$KEY" ] || ! seen "$KEY" || exit 0

now=$(date -u +%Y-%m-%dT%H:%M:%SZ)
id="$(date -u +%Y%m%dT%H%M%SZ)-$KIND-$(head -c4 /dev/urandom | od -An -tx1 | tr -d ' \n')"
rec=$(jq -cn --arg id "$id" --arg k "$KIND" --arg c "$CODE" --arg t "$TICKET" --arg at "$now" --arg s "$SEAT" --arg l "$LINE" \
  --arg pr "$PR" --arg sha "$SHA" --arg repo "$REPO" --arg note "$NOTE" \
  '{id: $id, kind: $k, code: $c, ticket: $t, at: $at, seat: $s, line: $l}
   + (if $pr == "" then {} else {pr: ($pr | tonumber? // $pr)} end) + (if $sha == "" then {} else {sha: $sha} end)
   + (if $repo == "" then {} else {repo: $repo} end) + (if $note == "" then {} else {note: $note} end)') || die 2 "bad field"
python3 - "$SCHEMA" "$rec" <<'PY' || die 3 "record fails $SCHEMA: $rec"
import json, sys, jsonschema
jsonschema.validate(json.loads(sys.argv[2]), json.load(open(sys.argv[1])))
PY

case $BACKEND in
  bus) read -r -a PUB <<<"${PR_FLOW_PUB:-$HERE/../../bin/bus.sh pub}"
       ok=0; for n in 1 2 3; do "${PUB[@]}" "line.$LINE.event.$KIND" "$rec" >/dev/null 2>&1 && { ok=1; break; }; sleep "$(( n * ${RECORDS_BACKOFF:-1} ))"; done
       [ "$ok" = 1 ] || die 4 "publish to line.$LINE.event.$KIND failed 3 times" ;;
  dir) d="${PR_FLOW_RECORDS_DIR:?PR_FLOW_RECORDS_DIR is required for the dir backend}/$(date -u +%Y/%m)"
       if ! { mkdir -p "$d" && printf '%s\n' "$rec" > "$d/$(date -u +%Y%m%d%H%M%S)-$KIND-${PR:-x}-${id##*-}.json"; }; then die 4 "cannot write under $d"; fi ;;
esac
if [ -n "$KEY" ] && ! { mkdir -p "$STATE" && printf '%s\n' "$KEY" >> "$LEDGER"; }; then die 4 "cannot write $LEDGER"; fi
printf '%s\n' "$rec"
