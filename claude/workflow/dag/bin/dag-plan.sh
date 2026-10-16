#!/usr/bin/env bash
# shellcheck disable=SC2016 # jq filters use $var; they are jq variables, single quotes are the point
# dag-plan.sh - the plan verb: diffs the pinned node declarations against the run state and prints what each node is and will run.
#   name:       dag-plan.sh
#   purpose:    classes every node DG-READY, DG-PENDING, DG-STALE or DG-BLOCKED and prints the ready set, priority then layer
#   inputs:     --run <run-id> (or DAG_RUN), --config <dag.json> (or DAG_CONFIG), --nodes <dir> (or DAG_NODES_DIR; default
#               <run>/nodes.lock), --root <repo root for bundle paths> (or DAG_ROOT; default the repo this script is in);
#               DAG_STATE_DIR, DAG_RETRY_WAITS, DAG_SLEEP as dag-lib.sh
#   outputs:    stdout "<node>\t<class>\t<what it will run | reason>", ready set first; exit 0 plan printed, 2 usage, 3 DG-SCHEMA
#   writes-to:  one ledger row in <state_dir>/runs/<run-id>/ledger.jsonl, nothing else; never state.json, never the world
#   cleanup:    removes its own temp dir on exit
# Spec: docs/design/dag-state.spec.xml <verb name="plan">; docs/design/dag-state.md section 8; docs/design/dag-state-nodes.spec.xml <bundles>.
#
# BREADCRUMB (WO-20261016-acde, dag-state T2).
# Priority: item 40 orders the ready set by node priority (p0 first, missing = p2). node.schema.json has no "priority" field and
# forbids extra ones (additionalProperties false), and schemas are not in this ticket's files. So the validator is shown the node
# with "priority" removed, and the value is read from the raw file. A priority outside p0-p9 is DG-SCHEMA. Rejected: skipping
# validation of nodes that carry a priority. Cost: when the schema gains the field, this strip becomes a no-op and can go.
# Schema ref: node.schema.json points at bundle.schema.json by a relative $ref under a non-resolvable $id, so the bundle schema is
# inlined into a temp copy before validating. Rejected: a registry in validate-schema.sh (a shared tool, not in this ticket).
# Input present: a node with no dependencies starts from the ticket and is always present; any other node needs its input record
# (state input path, else node.input.path) as a file under the run directory or the repo root, else it is DG-PENDING.
# DG-STALE: a DG-DONE node whose pinned version differs from the design now, or whose input file no longer hashes to input_sha256.
# DG-BLOCKED: a dependency is DG-FAILED or DG-BLOCKED, or the bundle names a file that does not exist (printed DG-BUNDLE-MISSING).
set -euo pipefail

D="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=dag-lib.sh disable=SC1091
. "$D/dag-lib.sh"

run="${DAG_RUN:-}" cfg="${DAG_CONFIG:-}" nodes_dir="${DAG_NODES_DIR:-}" root="${DAG_ROOT:-$(cd "$D/../../../.." && pwd)}"
usage() { dag_err "usage: dag-plan.sh --run <run-id> [--config <dag.json>] [--nodes <dir>] [--root <dir>]"; exit 2; }
while [ $# -gt 0 ]; do
  case "$1" in
    --run) [ $# -ge 2 ] || usage; run="$2"; shift 2 ;;
    --config) [ $# -ge 2 ] || usage; cfg="$2"; shift 2 ;;
    --nodes) [ $# -ge 2 ] || usage; nodes_dir="$2"; shift 2 ;;
    --root) [ $# -ge 2 ] || usage; root="$2"; shift 2 ;;
    -h|--help) usage ;;
    *) usage ;;
  esac
done
[ -n "$run" ] || usage
[ -z "$cfg" ] || export DAG_CONFIG="$cfg"
rd="$(dag_run_dir "$run")" || exit 2
[ -n "$nodes_dir" ] || nodes_dir="$rd/nodes.lock"
[ -d "$nodes_dir" ] || { dag_err "dag-plan: no node declarations at $nodes_dir"; exit 2; }

T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT

state="$(dag_read "$run")" || exit $?

# Node schema with the bundle schema inlined (see BREADCRUMB).
jq --slurpfile b "$DAG_SCHEMAS/bundle.schema.json" '(.properties.bundle) = ($b[0] | del(."$schema", ."$id"))' \
  "$DAG_SCHEMAS/node.schema.json" >"$T/node.schema.json"

shopt -s nullglob
files=("$nodes_dir"/*.node.json)
[ "${#files[@]}" -gt 0 ] || { dag_err "dag-plan: no *.node.json in $nodes_dir"; exit 2; }

# Validate every node; collect the raw declarations into one array.
for f in "${files[@]}"; do
  pr="$(jq -r '.priority // "p2"' "$f" 2>/dev/null)" || { dag_err "DG-SCHEMA $f: not JSON"; exit 3; }
  [[ $pr =~ ^p[0-9]$ ]] || { dag_err "DG-SCHEMA $f: priority '$pr' is not p0-p9"; exit 3; }
  jq 'del(.priority)' "$f" >"$T/n.json"
  if ! out="$(bash "$DAG_VALIDATE" "$T/node.schema.json" "$T/n.json" 2>&1)"; then dag_err "DG-SCHEMA $f: $out"; exit 3; fi
done
jq -s '.' "${files[@]}" >"$T/nodes.json"

# Facts the world gives the classifier: which bundle files and input records exist, and what an input hashes to now.
facts='{}'
while IFS= read -r n; do
  missing="[]"; inpath="$(jq -r --arg n "$n" '.[] | select(.id == $n) | (.input.path)' "$T/nodes.json")"
  sin="$(jq -r --arg n "$n" '.nodes[$n].input // empty' <<<"$state")"
  for p in $(jq -r --arg n "$n" '.[] | select(.id == $n) | .bundle | [.checklist_doc, .runbook, .playbook] + .docs | .[]' "$T/nodes.json"); do
    [ -e "$root/$p" ] || missing="$(jq -c --arg p "$p" '. + [$p]' <<<"$missing")"
  done
  ipath=""
  for c in "${sin:-$inpath}"; do
    if [ -f "$c" ]; then ipath="$c"; elif [ -f "$rd/$c" ]; then ipath="$rd/$c"; elif [ -f "$root/$c" ]; then ipath="$root/$c"; fi
  done
  hash=""; [ -z "$ipath" ] || hash="$(sha256sum "$ipath" | cut -d' ' -f1)"
  facts="$(jq -c --arg n "$n" --argjson m "$missing" --arg h "$hash" --arg ip "$ipath" \
    '.[$n] = {missing:$m, input_present:($ip != ""), input_hash:$h}' <<<"$facts")"
done < <(jq -r '.[].id' "$T/nodes.json")

# Classify. Layer is the longest dependency chain to the node; priority from the raw file.
jq -r --argjson st "$state" --argjson facts "$facts" --slurpfile pri <(for f in "${files[@]}"; do jq -c '{(.id): (.priority // "p2")}' "$f"; done | jq -s 'add') '
  . as $nodes
  | ($nodes | map({key: .id, value: .}) | from_entries) as $by
  | def layer($id): if ($by[$id].depends_on | length) == 0 then 0 else 1 + ([$by[$id].depends_on[] | select($by[.] != null) | layer(.)] | max // 0) end;
  def stat($id): ($st.nodes[$id].status // "DG-PENDING");
  [ $nodes[] | . as $n
    | stat($n.id) as $s
    | ($n.depends_on) as $deps
    | ($facts[$n.id]) as $f
    | (if ($f.missing | length) > 0 then ["DG-BLOCKED", "DG-BUNDLE-MISSING " + ($f.missing | join(","))]
       elif ([$deps[] | stat(.) | select(. == "DG-FAILED" or . == "DG-BLOCKED")] | length) > 0 then ["DG-BLOCKED", "dependency failed or blocked"]
       elif $s == "DG-DONE" and ($st.nodes[$n.id].version != $n.version) then ["DG-STALE", "pinned " + $st.nodes[$n.id].version + " design " + $n.version]
       elif $s == "DG-DONE" and ($st.nodes[$n.id].input_sha256 // "") != "" and $f.input_hash != "" and $st.nodes[$n.id].input_sha256 != $f.input_hash then ["DG-STALE", "input hash moved"]
       elif ($s == "DG-DONE" or $s == "DG-SKIPPED" or $s == "DG-RUNNING" or $s == "DG-FAILED" or $s == "DG-BLOCKED") then [$s, "state"]
       elif ([$deps[] | stat(.) | select(. != "DG-DONE" and . != "DG-SKIPPED")] | length) > 0 then ["DG-PENDING", "waiting on " + ([$deps[] | select(stat(.) != "DG-DONE" and stat(.) != "DG-SKIPPED")] | join(","))]
       elif ($deps | length) > 0 and ($f.input_present | not) then ["DG-PENDING", "input record missing"]
       else ["DG-READY", "run " + $n.script] end) as $c
    | {id: $n.id, class: $c[0], what: $c[1], layer: layer($n.id), pri: ($pri[0][$n.id] // "p2")}
  ]
  | (map(select(.class == "DG-READY")) | sort_by([.pri, .layer, .id])) as $ready
  | (map(select(.class != "DG-READY")) | sort_by([.layer, .id])) as $rest
  | ($ready + $rest)[] | "\(.id)\t\(.class)\t\(.what)"
' "$T/nodes.json" | tee "$T/plan.txt"

# The one write: a ledger row, retried 3 times (rule R4).
ready_n="$(awk -F'\t' '$2 == "DG-READY"' "$T/plan.txt" | wc -l)"
code=DG-PENDING; [ "$ready_n" -eq 0 ] || code=DG-READY
dag_retry 3 dag_ledger "$run" plan "$code" "" "ready=$ready_n of $(wc -l <"$T/plan.txt")"
