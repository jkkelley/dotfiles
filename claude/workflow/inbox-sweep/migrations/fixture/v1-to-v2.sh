#!/usr/bin/env bash
# Migration fixture v1 -> v2: one JSON record on stdin, the new record on stdout. Never edits a file (copy-forward is the
# runner's job: it writes the result beside the original). Adds the envelope and bumps schema_version; leaves text and
# text_sha256 alone, which migrate.sh then verifies rather than trusts (design 15.3, "a migration would change an approved text").
set -euo pipefail
jq -c '.schema_version = 2 | .envelope = {migrated_from: 1}'
