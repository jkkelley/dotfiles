#!/usr/bin/env bash
# summary.json v1 -> v2: one JSON record on stdin, the new record on stdout. Never edits a file (copy-forward is
# migrate.sh's job). The only change is schema_version, the string 1.0.0 (or the integer 1) becoming the integer 2.
set -euo pipefail
jq -c '.schema_version = 2'
