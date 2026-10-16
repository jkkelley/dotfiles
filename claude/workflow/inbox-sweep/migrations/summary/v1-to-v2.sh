#!/usr/bin/env bash
# name: v1-to-v2.sh
# purpose: migrate one summary record from schema v1 to v2 (integer schema_version); never edits a file, migrate.sh copies forward
# inputs: one summary v1 JSON record on stdin
# outputs: the v2 record on stdout
# writes-to: nothing (read-only)
# cleanup: none needed
# summary.json v1 -> v2: one JSON record on stdin, the new record on stdout. Never edits a file (copy-forward is
# migrate.sh's job). The only change is schema_version, the string 1.0.0 (or the integer 1) becoming the integer 2.
set -euo pipefail
jq -c '.schema_version = 2'
