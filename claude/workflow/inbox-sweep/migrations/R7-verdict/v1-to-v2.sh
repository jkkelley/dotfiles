#!/usr/bin/env bash
# Migration R7-verdict v1 -> v2: one JSON record on stdin, the new record on stdout. Never edits a file (copy-forward is the
# runner's job). Sets the integer schema_version; v1 carried none, the string 1.0.0, or the integer 1. Every other field is kept.
set -euo pipefail
jq -c '.schema_version = 2'
