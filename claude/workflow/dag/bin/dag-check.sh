#!/usr/bin/env bash
# dag-check.sh - static checks of the dag-state build, and the dag-clean sweep.
#   name:       dag-check.sh
#   purpose:    check (default): config against config.schema.json, every node against node.schema.json, node scripts exist,
#               edges known and acyclic, every DG-/DR- code in a script is in the spec code map, no two tickets that can run at
#               once share a file, both specs pass spec-check.sh. clean: remove archived and empty runs (make dag-clean)
#   inputs:     check: --config FILE (else DAG_CONFIG, else ../config/dag.json), --root DIR (repo root, else DAG_ROOT, else
#               the repo this script is in); clean --older-than DAYS [--dry-run] (state dir from DAG_STATE_DIR or the config)
#   outputs:    stdout "ok  <check>" or "FAIL <check>: <reason>" lines; exit 0 all ok, 1 a check failed, 2 usage
#   writes-to:  check writes nothing; clean removes under <state_dir>/archive/ and <state_dir>/runs/ only
#   cleanup:    removes its own temp dir on exit
# Spec: docs/design/dag-state.spec.xml <make> dag-check, dag-clean; design docs/design/dag-state.md section 12.
#
# BREADCRUMB (WO-20261016-e271, dag-state T11).
# What broke: nothing yet; the design says "make dag-check fails if a code appears in a script and not in the map" and "if
#   two tickets that can run at once share a file", and no script did either.
# Why this fix: one read-only script runs every static check and prints every failure, not the first, so one run shows all
#   the drift. Rejected: separate scripts per check, which a Make target would have to chain. Cost: the code map is read
#   from the spec's <code id=...> elements, so a code added to a script without a spec edit fails here until the spec moves.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${DAG_ROOT:-$(cd "$HERE/../../../.." && pwd)}"
CFG="${DAG_CONFIG:-$HERE/../config/dag.json}"
usage() { echo "usage: dag-check.sh [--config FILE] [--root DIR] | clean --older-than DAYS [--dry-run]" >&2; exit 2; }

mode=check; older=""; dry=0
if [ "${1:-}" = clean ]; then mode=clean; shift; fi
while [ $# -gt 0 ]; do
  case "$1" in
    --config) [ $# -ge 2 ] || usage; CFG="$2"; shift 2 ;;
    --root) [ $# -ge 2 ] || usage; ROOT="$2"; shift 2 ;;
    --older-than) [ $# -ge 2 ] || usage; older="$2"; shift 2 ;;
    --dry-run) dry=1; shift ;;
    *) usage ;;
  esac
done

if [ "$mode" = clean ]; then
  case "$older" in ''|*[!0-9]*) usage ;; esac
  sd="${DAG_STATE_DIR:-$(jq -r .state_dir "$CFG" | sed "s|^~|$HOME|")}"
  [ -n "$sd" ] || usage
  n=0
  rm_dir() { if [ "$dry" = 1 ]; then echo "would remove $1"; else rm -rf -- "$1" && echo "removed $1"; fi; n=$((n + 1)); }
  # Archived runs older than the cut, and run dirs a crashed claim left with no state file (nothing a recover could resume).
  if [ -d "$sd/archive" ]; then
    while IFS= read -r d; do rm_dir "$d"; done < <(find "$sd/archive" -mindepth 1 -maxdepth 1 -type d -mtime "+$older")
  fi
  if [ -d "$sd/runs" ]; then
    while IFS= read -r d; do [ -f "$d/state.json" ] || rm_dir "$d"; done < <(find "$sd/runs" -mindepth 1 -maxdepth 1 -type d -mtime "+$older")
  fi
  echo "ok  clean: $n removed under $sd"
  exit 0
fi

DESIGN="$ROOT/docs/design"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
fail=0
pass() { echo "ok  $1"; }
bad() { echo "FAIL $1: $2"; fail=1; }

# 1. config
if out="$(bash "$ROOT/claude/workflow/tools/validate-schema.sh" "$ROOT/claude/workflow/dag/schemas/config.schema.json" "$CFG" 2>&1)"; then
  pass "config validates"
else bad "config" "$out"; fi

# 2. node declarations: schema, script, edges, cycles
nodes_dir="$ROOT/$(jq -r '.design_dir // "claude/workflow/dag/nodes"' "$CFG")"
shopt -s nullglob
files=("$nodes_dir"/*.node.json)
if [ "${#files[@]}" -eq 0 ]; then bad "nodes" "no *.node.json in $nodes_dir"; fi
ids=" "
for f in "${files[@]}"; do ids="$ids$(jq -r .id "$f") "; done
for f in "${files[@]}"; do
  id="$(jq -r .id "$f")"
  if ! out="$(bash "$ROOT/claude/workflow/tools/validate-schema.sh" "$ROOT/claude/workflow/dag/schemas/node.schema.json" "$f" 2>&1)"; then bad "node $id schema" "$out"; continue; fi
  sc="$(jq -r .script "$f")"
  if [ ! -f "$ROOT/$sc" ] && [ "$(jq -r '.script_pending // false' "$f")" != true ]; then bad "node $id script" "$sc missing"; fi
  for d in $(jq -r '.depends_on[]' "$f"); do
    case "$ids" in *" $d "*) ;; *) bad "node $id edge" "depends_on $d is not a node" ;; esac
  done
done
# Kahn: peel nodes with no unmet dependency; what is left is a cycle.
left="$ids"; progress=1
while [ "$progress" = 1 ] && [ -n "${left// /}" ]; do
  progress=0
  for f in "${files[@]}"; do
    id="$(jq -r .id "$f")"
    case "$left" in *" $id "*) ;; *) continue ;; esac
    unmet=0
    for d in $(jq -r '.depends_on[]' "$f"); do case "$left" in *" $d "*) unmet=1 ;; esac; done
    if [ "$unmet" = 0 ]; then left="${left/ $id / }"; progress=1; fi
  done
done
if [ -n "${left// /}" ]; then bad "nodes acyclic" "cycle among:$left"; else pass "nodes: ${#files[@]} declared, edges known, acyclic"; fi

# 3. code map and 4. ticket file sets, from the specs
if out="$(python3 -I - "$DESIGN/dag-state.spec.xml" "$DESIGN/dag-state-nodes.spec.xml" "$ROOT/claude/workflow/dag/bin" <<'PY'
import glob, re, sys, xml.etree.ElementTree as ET
core, nodes, bindir = sys.argv[1:4]
mapped = {c.get("id") for c in ET.parse(core).getroot().iter("code")}
used = {}
for f in sorted(glob.glob(bindir + "/*.sh")):
    for n, line in enumerate(open(f, encoding="utf-8"), 1):
        if line.lstrip().startswith("#"):
            continue
        line = re.sub(r"\s#.*$", "", line)  # a trailing comment may name a placeholder such as <DR-CODE>
        for c in re.findall(r"\b(?:DG|DR)-[A-Z]+(?:-[A-Z]+)*\b", line):
            used.setdefault(c, f"{f.rsplit('/', 1)[-1]}:{n}")
miss = sorted(c for c in used if c not in mapped)
errs = [f"code {c} used at {used[c]} is not in the spec code map" for c in miss]
tk = {t.get("id"): (set(t.get("needs", "").split()), [x.text for x in t.findall("file")]) for t in ET.parse(nodes).getroot().iter("ticket")}
def anc(i, seen=None):
    seen = seen if seen is not None else set()
    for p in tk[i][0]:
        if p in tk and p not in seen:
            seen.add(p); anc(p, seen)
    return seen
ids = sorted(tk)
for a in range(len(ids)):
    for b in range(a + 1, len(ids)):
        x, y = ids[a], ids[b]
        if x in anc(y) or y in anc(x):
            continue
        both = set(tk[x][1]) & set(tk[y][1])
        if both:
            errs.append(f"tickets {x} and {y} can run at once and share {sorted(both)}")
print("\n".join(errs))
sys.exit(1 if errs else 0)
PY
)"; then pass "code map covers every DG-/DR- code in dag/bin; ticket file sets disjoint"
else bad "code map / tickets" "$(printf '%s' "$out" | tr '\n' ';')"; fi

# 5. spec lint
if out="$(bash "$ROOT/scripts/spec-check.sh" "$DESIGN/dag-state.spec.xml" "$DESIGN/dag-state-nodes.spec.xml" 2>&1)"; then
  pass "specs: lines, parse, contents"
else bad "spec lint" "$out"; fi

exit "$fail"
