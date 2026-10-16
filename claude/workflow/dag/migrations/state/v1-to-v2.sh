#!/usr/bin/env bash
# name: v1-to-v2.sh
# purpose: state schema v1 -> v2, one compact state record on stdin, the migrated record on stdout (migrate.sh contract)
# inputs: stdin, one JSON record with schema_version 1
# outputs: stdout, the same record with schema_version 2; nothing else changes (spec <migration>: copy-forward, original kept)
# writes-to: nothing
# cleanup: none
# Spec: docs/design/dag-state-nodes.spec.xml <migration> case "state schema bumped". Invoked by dag-migrate.sh through
# inbox-sweep/bin/migrate.sh only once a state.v2.schema.json exists; the v2 schema itself is a later ticket's file.
set -euo pipefail
jq -c '.schema_version = 2'
