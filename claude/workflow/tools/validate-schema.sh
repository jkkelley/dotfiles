#!/usr/bin/env bash
# Thin wrapper over python-jsonschema. No bespoke validator: the wheel exists.
# Usage: validate-schema.sh <schema.json> <instance.json>
set -euo pipefail
[ $# -eq 2 ] || { echo "usage: validate-schema.sh <schema> <instance>" >&2; exit 2; }
python3 -c '
import json, sys
from jsonschema import Draft202012Validator
schema = json.load(open(sys.argv[1]))
inst   = json.load(open(sys.argv[2]))
errs = sorted(Draft202012Validator(schema).iter_errors(inst), key=lambda e: e.path)
for e in errs:
    loc = "/".join(str(p) for p in e.path) or "(root)"
    print(f"  {loc}: {e.message}", file=sys.stderr)
sys.exit(1 if errs else 0)
' "$1" "$2"
