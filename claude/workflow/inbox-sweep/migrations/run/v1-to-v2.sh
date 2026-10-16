#!/usr/bin/env bash
# run.json v1 -> v2: one JSON record on stdin, the new record on stdout. Never edits a file (copy-forward is the runner's
# job, bin/migrate.sh). The only change is schema_version: the string "1.0.0" (or the integer 1) becomes the integer 2.
# Every other field passes through untouched, so a record init wrote keeps its seats, owner hash and pinned node versions.
set -euo pipefail
jq -c '.schema_version = 2'
