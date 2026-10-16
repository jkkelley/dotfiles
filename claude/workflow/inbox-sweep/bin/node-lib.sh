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
# A schema_version raise is a new schemas/records/<name>.v<N>.schema.json (N >= 2); it must ship migrations/<name>/v<N-1>-to-v<N>.sh
# and the previous version's fixture tests/fixtures/migrations/<name>/v<N-1>.json (the test's input). REC_DIR, MIG_DIR and MIG_FIX
# point these elsewhere for tests. Why the fixture stands for "a test": migrate's suite upgrades every fixture it finds there, so
# a version with no fixture is a version nothing upgrades.
# nodes.lock at init is written by sweep-init.sh (B20b). The design tables for L1 to L12 and S1 to S7 are prose rows, not
# the `### Rn` checkbox lists the table check parses, so an L or S declaration is checked against the schema and its
# script but has no table to disagree with. Their checklists were cut from the rows of design sections 14.3 and 17.
#
# script_pending (B20b): the reply and lead scripts are other tickets' files (B14 to B17, B22, B23) and do not exist yet.
# A declaration may say "script_pending": true until its owner lands; nodes-check then skips the exists test, and prints
# a note once the script exists so the next edit removes the flag. Rejected: failing on a pending flag whose script now
# exists, because B14 merging would turn main red until a second change flipped a flag in a file it does not own.

_node_here="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

node_check() {
  local dir="${NODE_DIR:-$_node_here/nodes}" schema="${NODE_SCHEMA:-$_node_here/schemas/node.schema.json}"
  local design="${NODE_DESIGN:-$_node_here/../../../docs/design/inbox-sweep.md}" scripts="${NODE_SCRIPTS:-$_node_here/bin}"
  local rec="${REC_DIR:-$_node_here/schemas/records}" mig="${MIG_DIR:-$_node_here/migrations}" fix="${MIG_FIX:-$_node_here/tests/fixtures/migrations}"
  python3 -I - "$dir" "$schema" "$design" "$scripts" "$_node_here/../../.." "$rec" "$mig" "$fix" <<'PY'
import json, pathlib, re, sys
from jsonschema import Draft202012Validator
d, schema, design, scripts, repo, rec, mig, fix = (pathlib.Path(a) for a in sys.argv[1:9])
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
    there = (repo / j["script"]).exists()
    if j.get("script_pending"):
        if there: print(f"note {f.name} is script_pending but {j['script']} now exists; drop the flag")
    elif not there: no(f"{f.name} names script {j['script']}, which does not exist")

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
# a schema_version raise without its migration and the fixture its test upgrades
for f in sorted(rec.glob("*.v*.schema.json")):
    m = re.fullmatch(r"(.+)\.v(\d+)\.schema\.json", f.name)
    if not m or int(m[2]) < 2: continue
    name, n = m[1], int(m[2])
    script, fixture = mig / name / f"v{n-1}-to-v{n}.sh", fix / name / f"v{n-1}.json"
    if not script.exists(): no(f"{f.name} raises {name} to v{n} with no migration {name}/v{n-1}-to-v{n}.sh")
    elif not fixture.exists(): no(f"{f.name} raises {name} to v{n} with no test fixture {name}/v{n-1}.json")
    else: ok(f"{name} v{n} ships its migration and fixture")
sys.exit(bad)
PY
}

node_bottleneck() {
  local dir="${NODE_DIR:-$_node_here/nodes}"
  python3 -I - "$dir" <<'PY'
import json, pathlib, sys
bad = 0
waits = []
print(f"{'node':<5} {'parallel':<20} serial")
for f in sorted(pathlib.Path(sys.argv[1]).glob("*.node.json")):
    j = json.loads(f.read_text()); s = j.get("serial"); p = j.get("parallel")
    print(f"{j['id']:<5} {p:<20} {s if s else '-'}")
    if s and s.startswith("Intended wait:"): waits.append(j["id"])
    # serial and parallel are two statements of one fact; "none" with no reason is a node nobody justified
    if (s is not None and not str(s).strip()) or (s is None and p == "none"):
        bad = 1; print(f"FAIL {j['id']} is serial and gives no reason (design section 16)")
# the owner confirm is the one wait the process is allowed (design section 16); a second marked node is a bottleneck
print("intended wait: " + (", ".join(waits) or "none"))
if len(waits) > 1: bad = 1; print("FAIL more than one node is marked as the intended wait: " + ", ".join(waits))
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
