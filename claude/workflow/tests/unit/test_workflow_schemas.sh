#!/usr/bin/env bash
# Proves the workflow system is declared, not described.
#
# Three properties, each of which has a failure mode that is silent without a test:
#   1. Every workflow declaration validates against the meta-schema, so a declaration cannot drift
#      into a shape the machinery cannot read.
#   2. A spec missing context_threshold_percent is REJECTED. A seat spawned from a spec with no
#      threshold never compacts, and nothing else in the system would notice.
#   3. Every record schema sets additionalProperties:false, so a drifting producer fails the gate
#      instead of being silently tolerated.
#
# Hermetic: schema validation only. Nothing here runs a gate command, touches the network, talks to
# herdr, or reads anything outside the repository. The gate runs with --network=none and this test
# must pass inside it.
set -euo pipefail
R="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
W="$R/schemas/workflows"
fail=0

# ---- 1. the library must not change its caller's shell options -------------
# The house container-sandbox skill calls this out: a library that sets -e hands it to every caller,
# and a watcher loop built out of expected non-matches then dies silently. Checked by capturing $-
# rather than by reading the two files, because reading is exactly what misses it.
before="$-"
# shellcheck source=bin/workflow-lib.sh disable=SC1091
. "$R/bin/workflow-lib.sh"
if [ "$before" != "$-" ]; then
  echo "FAIL: sourcing bin/workflow-lib.sh changed shell options from [$before] to [$-]"; fail=1
fi

# ---- 2..4 schema properties, in one python pass ---------------------------
python3 - "$W" <<'PY' || fail=1
import json, pathlib, sys
from jsonschema import Draft202012Validator

W = pathlib.Path(sys.argv[1])
bad = 0

def errs(schema, inst):
    return sorted(Draft202012Validator(schema).iter_errors(inst), key=lambda e: list(e.path))

meta = json.loads((W / "workflow.schema.json").read_text())
Draft202012Validator.check_schema(meta)

cfg_schema = json.loads((W.parent.parent / "config" / "project.schema.json").read_text())
Draft202012Validator.check_schema(cfg_schema)
cfg = json.loads((W.parent.parent / "config" / "project.json").read_text())
for e in errs(cfg_schema, cfg):
    print(f"FAIL: config/project.json: {'/'.join(map(str, e.path)) or '(root)'}: {e.message}")
    bad = 1

workflows = sorted(W.glob("*.workflow.json"))
if not workflows:
    print("FAIL: no workflow declarations found")
    bad = 1

for p in workflows:
    d = json.loads(p.read_text())
    for e in errs(meta, d):
        print(f"FAIL: {p.name}: {'/'.join(map(str, e.path)) or '(root)'}: {e.message}")
        bad = 1
    if p.stem.split(".")[0] != d.get("id"):
        print(f"FAIL: {p.name}: id {d.get('id')!r} does not match its filename")
        bad = 1
    # Every agent spec carries a threshold. Restated as its own check so the failure message names
    # the real problem rather than a generic 'required property' line.
    if "context_threshold_percent" not in d.get("agent", {}):
        print(f"FAIL: {p.name}: agent spec has no context_threshold_percent")
        bad = 1
    # Every record schema is strict, and is itself a valid schema.
    rs = d["record"]["schema"]
    Draft202012Validator.check_schema(rs)
    if rs.get("additionalProperties") is not False:
        print(f"FAIL: {p.name}: record schema does not set additionalProperties:false")
        bad = 1
    # The in-process spawn ban is data, not prose.
    denied = set(d["agent"].get("denied_tools", []))
    if not {"Agent", "Task"} <= denied:
        print(f"FAIL: {p.name}: agent.denied_tools must contain Agent and Task")
        bad = 1

# ---- the negative cases. A schema is only strict if something proves it rejects. ----
sample = json.loads(workflows[0].read_text())

missing = json.loads(json.dumps(sample))
missing["agent"].pop("context_threshold_percent")
e = errs(meta, missing)
if not e:
    print("FAIL: meta-schema ACCEPTED an agent spec with no context_threshold_percent")
    bad = 1
else:
    print(f"ok  rejected: spec with no threshold -> {e[0].message}")

unknown = json.loads(json.dumps(sample))
unknown["agent"]["budget_usd"] = 5
e = errs(meta, unknown)
if not e:
    print("FAIL: meta-schema ACCEPTED an unknown field in an agent spec")
    bad = 1
else:
    print(f"ok  rejected: unknown agent field -> {e[0].message}")

loose = json.loads(json.dumps(sample))
loose["record"]["schema"]["additionalProperties"] = True
e = errs(meta, loose)
if not e:
    print("FAIL: meta-schema ACCEPTED a record schema with additionalProperties:true")
    bad = 1
else:
    print(f"ok  rejected: permissive record schema -> {e[0].message}")

out_of_range = json.loads(json.dumps(sample))
out_of_range["agent"]["context_threshold_percent"] = 0
e = errs(meta, out_of_range)
if not e:
    print("FAIL: meta-schema ACCEPTED a threshold of 0")
    bad = 1
else:
    print(f"ok  rejected: threshold out of range -> {e[0].message}")

# ---- the model chain (O-08). A seat runs one statement of its model, never two that can disagree. ----
chained = json.loads((W / "architect.workflow.json").read_text())
if errs(meta, chained):
    print("FAIL: meta-schema REJECTED the architect model chain")
    bad = 1
else:
    print("ok  accepted: architect chain kimi-k3 -> opus -> codex-sol")

both = json.loads(json.dumps(chained))
both["agent"].update(runtime="claude", model="opus")
e = errs(meta, both)
if not e:
    print("FAIL: meta-schema ACCEPTED an agent spec carrying both a chain and runtime/model")
    bad = 1
else:
    print(f"ok  rejected: chain plus runtime/model -> {e[0].message[:80]}")

empty = json.loads(json.dumps(chained))
empty["agent"]["models"] = []
e = errs(meta, empty)
if not e:
    print("FAIL: meta-schema ACCEPTED an empty model chain")
    bad = 1
else:
    print(f"ok  rejected: empty chain -> {e[0].message[:80]}")

neither = json.loads(json.dumps(chained))
neither["agent"].pop("models")
if not errs(meta, neither):
    print("FAIL: meta-schema ACCEPTED an agent spec with no model at all")
    bad = 1
else:
    print("ok  rejected: no chain and no runtime/model")

no_surface = json.loads(json.dumps(chained))
no_surface["agent"]["models"][0].pop("surface")
if not errs(meta, no_surface):
    print("FAIL: meta-schema ACCEPTED a link with no surface; the spawner would have to guess it from herdr_kind")
    bad = 1
else:
    print("ok  rejected: link with no surface")

cfg_bad = json.loads(json.dumps(cfg))
cfg_bad["workflow"]["seats"][0]["name"] = "Build Seat"          # herdr requires [a-z][a-z0-9_-]{0,31}
e = errs(cfg_schema, cfg_bad)
if not e:
    print("FAIL: config schema ACCEPTED a seat name herdr would refuse")
    bad = 1
else:
    print(f"ok  rejected: illegal herdr agent name -> {e[0].message}")

# ---- a real watcher state instance, against its own schema ----
ws = json.loads((W / "watcher-state.schema.json").read_text())
Draft202012Validator.check_schema(ws)
inst = {
    "schema_version": "1.0.0", "watcher": "compaction-watch", "state": "on", "pid": 4321,
    "started_at": "2026-09-21T21:08:44Z", "log": "/tmp/compaction-watch.log",
    "interval_seconds": 60, "watches_workflow": "compaction", "context_threshold_percent": 30,
}
for e in errs(ws, inst):
    print(f"FAIL: watcher-state instance: {e.message}")
    bad = 1
inst_bad = dict(inst, heartbeat_seconds=5)
if not errs(ws, inst_bad):
    print("FAIL: watcher-state schema ACCEPTED an unknown field")
    bad = 1
else:
    print("ok  rejected: unknown watcher-state field")

sys.exit(bad)
PY

[ "$fail" -eq 0 ] || exit 1
echo "ok  workflow-schemas: declarations valid, thresholds required, records strict"
