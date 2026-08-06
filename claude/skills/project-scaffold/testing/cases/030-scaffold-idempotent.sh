#!/usr/bin/env bash
# A second apply must be a byte-level no-op. Idempotency untested is a slogan.
CASE_NAME=030-scaffold-idempotent
source "${SKILL:-/skill}/testing/assert.sh"

p=$(scaffolded_project)
# scaffold.json carries a build timestamp by design, so it is excluded.
snap() { find "$1" -type f ! -name scaffold.json | sort | xargs sha256sum; }
snap "$p" >"$WORK/snap1"
run 0 "second apply exits 0" scaffold --project "$p" --apply --yes
snap "$p" >"$WORK/snap2"
assert_same "$WORK/snap1" "$WORK/snap2" "second apply changed nothing"

finish
