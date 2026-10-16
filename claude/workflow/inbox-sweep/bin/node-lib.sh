# shellcheck shell=bash
# Node declarations: the loader and the two checks behind `make nodes-check` and `make bottleneck-check`.
# Sourced, or run as `bash bin/node-lib.sh nodes-check|bottleneck-check`; sets no shell options when sourced.
#
# Design: docs/design/inbox-sweep.md sections 15.1 and 16, spec node-declarations in docs/design/linkedin-reply.spec.xml.
#
# Environment (tests point these at fixtures; defaults are this tree):
#   NODE_DIR      directory holding <id>.node.json
#   NODE_SCHEMA   node.schema.json
#   NODE_DESIGN   the design markdown whose `### Rn` sections hold the checklist tables
#   NODE_SCRIPTS  directory scanned for `# node: <id>` markers (default: this bin/)
#
# A script opts in with a header line `# node: R4`. nodes-check then fails when it names a node with no declaration.
# Opt-in, not a scan for every script, because the scripts are other tickets' files and a header line is the whole cost.
#
# Not here yet, and owned by B21 (spec node WO migration runner): the check that a schema_version raise ships a migration.
# Not here yet, owned by B20b: L and S declarations, and nodes.lock written at init. NODE_DESIGN covers R1 to R7 only,
# so a declaration for any other node is checked against the schema and its script but has no table to disagree with.

_node_here="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

node_check() {
  local dir="${NODE_DIR:-$_node_here/nodes}" schema="${NODE_SCHEMA:-$_node_here/schemas/node.schema.json}"
  local design="${NODE_DESIGN:-$_node_here/../../../docs/design/inbox-sweep.md}" scripts="${NODE_SCRIPTS:-$_node_here/bin}"
  python3 -I - "$dir" "$schema" "$design" "$scripts" "$_node_here/../../.." <<'PY'
import json, pathlib, re, sys
from jsonschema import Draft202012Validator
d, schema, design, scripts, repo = (pathlib.Path(a) for a in sys.argv[1:6])
bad = 0
def no(m):
    global bad; bad = 1; print("FAIL " + m)
def ok(m): print("ok  " + m)

val = Draft202012Validator(json.loads(schema.read_text()))
decl = {}
for f in sorted(d.glob("*.node.json")):
    try: j = json.loads(f.read_text())
    except ValueError as e: no(f"{f.name} is not JSON: {e}"); continue
    errs = list(val.iter_errors(j))
    if errs: no(f"{f.name} fails node.schema.json: {errs[0].message}"); continue
    if f.name != j["id"] + ".node.json": no(f"{f.name} declares id {j['id']}; the file must be {j['id']}.node.json"); continue
    decl[j["id"]] = j
    ok(f"{f.name} validates")
    if not (repo / j["script"]).exists(): no(f"{f.name} names script {j['script']}, which does not exist")

# a script naming a node nobody declared
for s in sorted(scripts.glob("*.sh")):
    for n in re.findall(r"^# node: (\S+)", s.read_text(), re.M):
        if n not in decl: no(f"{s.name} names node {n}, which has no declaration in {d.name}/")

# the design table and the declaration must say the same thing
sec = {}
cur = None
for line in design.read_text().split("\n"):
    m = re.match(r"### (R\d+) ", line)
    if m: cur = m[1]; sec[cur] = []; continue
    if line.startswith("#"): cur = None; continue
    m = re.match(r"\s*- \[ \] (.*) - proof: (.*)$", line)
    if cur and m: sec[cur].append({"box": m[1], "proof": m[2]})
for n, rows in sorted(sec.items()):
    if n not in decl: no(f"design section {n} has no declaration"); continue
    if rows == decl[n]["checklist"]: ok(f"{n} declaration matches the design table")
    else:
        miss = [r["box"] for r in rows if r not in decl[n]["checklist"]]
        extra = [r["box"] for r in decl[n]["checklist"] if r not in rows]
        no(f"{n} declaration and design table disagree; only in design: {miss}; only in declaration: {extra}")
sys.exit(bad)
PY
}

node_bottleneck() {
  local dir="${NODE_DIR:-$_node_here/nodes}"
  python3 -I - "$dir" <<'PY'
import json, pathlib, sys
bad = 0
print(f"{'node':<5} {'parallel':<20} serial")
for f in sorted(pathlib.Path(sys.argv[1]).glob("*.node.json")):
    j = json.loads(f.read_text()); s = j.get("serial"); p = j.get("parallel")
    print(f"{j['id']:<5} {p:<20} {s if s else '-'}")
    # serial and parallel are two statements of one fact; "none" with no reason is a node nobody justified
    if (s is not None and not str(s).strip()) or (s is None and p == "none"):
        bad = 1; print(f"FAIL {j['id']} is serial and gives no reason (design section 16)")
sys.exit(bad)
PY
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  case "${1:-}" in
    nodes-check) node_check ;;
    bottleneck-check) node_bottleneck ;;
    *) echo "usage: node-lib.sh nodes-check | bottleneck-check" >&2; exit 2 ;;
  esac
fi
