#!/usr/bin/env bash
# Thin wrapper over python-jsonschema. No bespoke validator: the wheel exists.
# Usage: validate-schema.sh <schema.json> <instance.json>
#
# WO-20261016-f052 (ORD-0921 E3). What broke: the old inline Draft202012Validator(schema) had no
# registry, so node.schema.json's {"$ref": "bundle.schema.json"} raised RefResolutionError under
# --network=none for every node file. Why it mattered: no gate has a network, so no DAG node file
# could be validated. Fix: schema_registry.py resolves $ref from a local store of the repo's
# *.schema.json files keyed by $id. Rejected: inlining bundle into node.schema.json - every future
# $ref would repeat the gap. Cost: one glob of claude/workflow per call.
set -euo pipefail
[ $# -eq 2 ] || { echo "usage: validate-schema.sh <schema> <instance>" >&2; exit 2; }
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
python3 "$HERE/schema_registry.py" "$1" "$2"
