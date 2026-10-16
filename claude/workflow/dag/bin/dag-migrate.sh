#!/usr/bin/env bash
# shellcheck disable=SC2016 # jq filters use $var; they are jq variables, single quotes are the point
# dag-migrate.sh - moves a live run to a new design version, or back, without a restart.
#   name:       dag-migrate.sh
#   purpose:    migrate <RUN>: repin the run's nodes to the design now (edited, added, removed), copy-forward record and
#               state schema bumps; rollback <RUN> <TO>: undo the last migration that started at design version TO
#   inputs:     RUN (run id); rollback also TO (semver). Flags or env, then DAG_CONFIG fields:
#               --design DIR | DAG_DESIGN_DIR | design_dir   node declarations, *.node.json, plus design.json {"version"}
#               --to VERSION | DAG_DESIGN_VERSION            design version to move to (default: design.json .version)
#               DAG_STATE_DIR | state_dir, DAG_SCHEMAS, DAG_MIGRATIONS (default dag/migrations), DAG_MIGRATE_RUNNER
#   outputs:    one MIG-* line per step on stdout, DG-/DR- codes on node rows and in the ledger;
#               exit 0 done or already current, 1 drift (DR-DESIGN), 2 usage, 3 DG-SCHEMA, 4/5/6 from dag-lib (write/lock)
#   writes-to:  <state_dir>/runs/<RUN>/ only: state.json (via dag-lib), nodes.lock/, nodes.lock.v<from>/, migrations/,
#               pins.json, records/*.vN.json, state.vN.json, ledger.jsonl; set-aside copies end in .rolled-back
#   cleanup:    releases the run lock on exit; nothing outside the run directory is touched
# Spec: docs/design/dag-state-nodes.spec.xml <migration>; design docs/design/dag-state.md section 11; reuses
# claude/workflow/inbox-sweep/bin/migrate.sh for record and state schema copy-forward and for record rollback.
#
# BREADCRUMB (WO-20261016-3f4f, dag-state T10). State is written first, files second: a crash between them is healed by
# the next run (same version and hash in state, nodes.lock behind -> lock is rebuilt, no second state write). Rejected:
# swapping nodes.lock first, because the diff that drives the state change is lock-versus-design and would be gone.
# Rollback is the mirror: it restores only the nodes the migration touched (recorded in migrations/), so progress on
# untouched nodes survives; the cost is that a touched node finished after the migration returns to its old status.
# state.vN.json is a copy-forward snapshot made at migrate time (migrate.sh semantics: the original is never edited);
# dag-lib reads state.json only, so a v2 copy is inert until a later ticket reads it.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=dag-lib.sh disable=SC1091
. "$HERE/dag-lib.sh"
RUNNER="${DAG_MIGRATE_RUNNER:-$HERE/../../inbox-sweep/bin/migrate.sh}"
MIGS="${DAG_MIGRATIONS:-$HERE/../migrations}"
NODE_SCHEMA="$DAG_SCHEMAS/node.schema.json"

die() { dag_err "dag-migrate: $*"; exit "${2:-2}"; }

# dir_sha <dir> - sha256 over the sorted node declarations, the same value for a design dir and a nodes.lock copy.
dir_sha() { (cd "$1" && LC_ALL=C sha256sum -- *.node.json 2>/dev/null | sha256sum | cut -d' ' -f1); }

# decls <dir> - {id: declaration} for every node file in the dir.
decls() { jq -s 'map({key: .id, value: .}) | from_entries' "$1"/*.node.json 2>/dev/null || echo '{}'; }

# validate_node <file> - node.schema.json $refs bundle.schema.json by URL, which validate-schema.sh cannot resolve offline,
# so the pair is validated here with the bundle schema registered in the resolver store. Prints DG-SCHEMA and returns 3.
validate_node() {
  python3 -I - "$NODE_SCHEMA" "$DAG_SCHEMAS/bundle.schema.json" "$1" <<'PY' || { dag_err "DG-SCHEMA node $1"; return 3; }
import json, sys
from jsonschema import Draft202012Validator
node, bundle = json.load(open(sys.argv[1])), json.load(open(sys.argv[2]))
try:
    from referencing import Registry, Resource
    kw = {"registry": Registry().with_resource("https://dag.invalid/bundle.schema.json", Resource.from_contents(bundle))}
except ImportError:
    from jsonschema import RefResolver
    kw = {"resolver": RefResolver.from_schema(node, store={"https://dag.invalid/bundle.schema.json": bundle, "bundle.schema.json": bundle})}
errs = list(Draft202012Validator(node, **kw).iter_errors(json.load(open(sys.argv[3]))))
for e in errs: print("  " + e.message, file=sys.stderr)
sys.exit(1 if errs else 0)
PY
}

usage() { die "usage: dag-migrate.sh [--design DIR] [--to VERSION] <RUN> | rollback <RUN> <TO>"; }

verb=migrate; DESIGN="${DAG_DESIGN_DIR:-$(dag_cfg design_dir)}"; TO="${DAG_DESIGN_VERSION:-}"; pos=()
[ "${1:-}" = rollback ] && { verb=rollback; shift; }
while [ $# -gt 0 ]; do
  case "$1" in
    --design) DESIGN="${2:?--design DIR}"; shift 2 ;;
    --to) TO="${2:?--to VERSION}"; shift 2 ;;
    -*) usage ;;
    *) pos+=("$1"); shift ;;
  esac
done
RUN="${pos[0]:-}"; [ -n "$RUN" ] || usage
RD="$(dag_run_dir "$RUN")" || exit 2
[ -f "$RD/state.json" ] || die "no run $RUN"
[ -d "$RD/nodes.lock" ] || die "run $RUN has no nodes.lock"
mkdir -p "$RD/migrations"
dag_lock "$RUN" || exit $?
trap 'dag_unlock "$RUN"' EXIT

# --- record and state schema copy-forward through the shared runner (cases "record schema bumped", "state schema bumped")
copy_forward() {
  local rc=0 out
  export MIGRATE_PINS="$RD/pins.json" MIG_DIR="$MIGS"
  if [ -d "$DAG_SCHEMAS/records" ] && [ -d "$RD/records" ]; then
    out="$(REC_SCHEMA_DIR="$DAG_SCHEMAS/records" bash "$RUNNER" migrate "$RD/records")" || rc=1
    [ -z "$out" ] || printf '%s\n' "$out"
  fi
  if compgen -G "$DAG_SCHEMAS/state.v*.schema.json" >/dev/null; then
    # the runner reads one record per line and state.json is pretty-printed, so it migrates a compact staged copy
    local stage n dest; stage="$(mktemp -d)"; jq -c . "$RD/state.json" >"$stage/state.jsonl"
    out="$(REC_SCHEMA_DIR="$DAG_SCHEMAS" bash "$RUNNER" one "$stage/state.jsonl")" || rc=1
    printf '%s\n' "${out//$stage\//}"
    for n in "$stage"/state.v[0-9]*.jsonl; do
      [ -e "$n" ] || continue
      dest="$RD/$(basename "${n%.jsonl}").json"; [ -e "$dest" ] || jq . "$n" >"$dest"
    done
    rm -rf "$stage"
  fi
  return "$rc"
}

# record_versions - {name: schema_version} of the original record files, so rollback knows where to go back to.
record_versions() {
  local f n v out='{}'
  for f in "$RD"/records/*.json "$RD"/records/*.jsonl; do
    [ -e "$f" ] || continue
    case "$(basename "$f")" in *.v[0-9]*) continue ;; esac
    n="$(basename "$f")"; n="${n%.jsonl}"; n="${n%.json}"
    v="$(head -n1 "$f" | jq -r '.schema_version // empty')"
    [ -n "$v" ] && out="$(jq -c --arg n "$n" --argjson v "$v" '.[$n]=$v' <<<"$out")"
  done
  printf '%s' "$out"
}

set_aside() { # rename <path> to <path>.rolled-back, never deleting an earlier set-aside copy
  local p="$1" t="$1.rolled-back" i=1
  [ -e "$p" ] || return 0
  while [ -e "$t" ]; do t="$1.rolled-back.$i"; i=$((i + 1)); done
  mv "$p" "$t"
}

do_migrate() {
  [ -d "$DESIGN" ] || die "no design dir (set --design, DAG_DESIGN_DIR or design_dir)"
  compgen -G "$DESIGN/*.node.json" >/dev/null || die "design dir $DESIGN has no *.node.json"
  [ -n "$TO" ] || TO="$(jq -r '.version // empty' "$DESIGN/design.json" 2>/dev/null || true)"
  [[ "$TO" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "no design version: pass --to, DAG_DESIGN_VERSION or design.json .version"
  local f st cur cursha newsha plan
  for f in "$DESIGN"/*.node.json; do validate_node "$f" || exit 3; done
  st="$(dag_read "$RUN")" || exit $?
  cur="$(jq -r '.design.version' <<<"$st")"; cursha="$(jq -r '.design.sha256' <<<"$st")"
  newsha="$(dir_sha "$DESIGN")"
  if [ "$cur" = "$TO" ]; then
    if [ "$cursha" != "$newsha" ]; then echo "DR-DESIGN $RUN pinned $cur hash differs from the design now"; exit 1; fi
    # heal: state says migrated, files may be behind after a crash
    if [ "$(dir_sha "$RD/nodes.lock")" != "$newsha" ]; then
      rm -rf "$RD/nodes.lock.new"; cp -a "$DESIGN" "$RD/nodes.lock.new"; rm -f "$RD/nodes.lock.new/design.json"
      set_aside "$RD/nodes.lock"; mv "$RD/nodes.lock.new" "$RD/nodes.lock"
      echo "MIG-HEALED $RUN nodes.lock rebuilt to $TO"
    else
      echo "MIG-CURRENT $RUN at $TO"
    fi
    copy_forward || exit 1
    exit 0
  fi

  # the plan: what changes in the state, per node (spec cases: edited, added, removed)
  plan="$(jq -n --argjson st "$st" --argjson lock "$(decls "$RD/nodes.lock")" --argjson des "$(decls "$DESIGN")" '
    def blank: {status: "DG-PENDING", version: "0.0.0", attempts: 0, proofs: []};
    def prev($id): ($st.nodes[$id]) as $n | if $n == null then {present: false} else {present: true, status: $n.status, version: $n.version} end;
    ([$des | keys[] | select($lock[.] == null)]) as $added
    | ([$lock | keys[] | select($des[.] == null)]) as $removed
    | [ ($added[] | . as $id | {id: $id, code: "DG-PENDING", prev: prev($id), set: (if $st.nodes[$id] == null then blank + {version: $des[$id].version} else null end)}),
        ($removed[] | . as $id | select($st.nodes[$id] != null) | {id: $id, code: "DG-SKIPPED", prev: prev($id), set: {status: "DG-SKIPPED"}}),
        ($des | keys[] | . as $id | select($lock[$id] != null and $lock[$id] != $des[$id] and $st.nodes[$id] != null)
          | ($st.nodes[$id].status) as $s
          | (($lock[$id].checklist != $des[$id].checklist) or ($lock[$id].script != $des[$id].script)) as $moved
          | {id: $id, code: (if $s == "DG-DONE" and $moved then "DG-STALE" else $s end), prev: prev($id),
             set: ({version: $des[$id].version} + (if $s == "DG-DONE" and $moved then {status: "DG-STALE"} else {} end))}),
        # a new node upstream of a done node makes that node stale
        ($des | keys[] | . as $id | select(($st.nodes[$id].status // "") == "DG-DONE" and ((($des[$id].depends_on // []) | map(select(. as $d | $added | index($d) != null))) | length) > 0)
          | {id: $id, code: "DG-STALE", prev: prev($id), set: {status: "DG-STALE"}})
      ]
    # one change per node; a stale from an added upstream wins over a plain version move
    | group_by(.id) | map(if length == 1 then .[0] else (map(select(.code == "DG-STALE")) | first // .[0]) + {set: (map(.set // {}) | add)} end)')"

  mkdir -p "$RD/migrations"
  local rec="$RD/migrations/migrate-$cur-to-$TO.json" sv
  sv="$(jq -r '.schema_version' <<<"$st")"
  rm -rf "$RD/nodes.lock.v$cur"; cp -a "$RD/nodes.lock" "$RD/nodes.lock.v$cur"
  jq -n --arg from "$cur" --arg to "$TO" --arg at "$(dag_now)" --argjson ch "$plan" --argjson recs "$(record_versions)" --argjson sv "$sv" \
    '{from: $from, to: $to, at: $at, changes: ($ch | map({id, code, prev})), records: $recs, state_schema: $sv}' >"$rec.tmp"
  mv "$rec.tmp" "$rec"

  dag_write "$RUN" '
    reduce $plan[] as $x (.; if $x.set == null then . else .nodes[$x.id] = ((.nodes[$x.id] // {status:"DG-PENDING",version:"0.0.0",attempts:0,proofs:[]}) + $x.set) end)
    | .design = {id: .design.id, version: $to, sha256: $sha}' \
    --argjson plan "$plan" --arg to "$TO" --arg sha "$newsha" || exit $?
  rm -rf "$RD/nodes.lock.new"; cp -a "$DESIGN" "$RD/nodes.lock.new"; rm -f "$RD/nodes.lock.new/design.json"
  rm -rf "$RD/nodes.lock"; mv "$RD/nodes.lock.new" "$RD/nodes.lock"

  local id code
  while IFS=$'\t' read -r id code; do
    [ -n "$id" ] || continue
    echo "MIG-NODE $id $code"
    dag_ledger "$RUN" migrate "$code" "$id" "design $cur -> $TO"
  done < <(jq -r '.[] | [.id, .code] | @tsv' <<<"$plan")
  echo "MIG-OK $RUN $cur -> $TO"
  copy_forward || exit 1
}

do_rollback() {
  [[ "${pos[1]:-}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "rollback needs TO as semver"
  local to="${pos[1]}" rec="" f cur from_to name sv
  for f in "$RD"/migrations/migrate-"$to"-to-*.json; do [ -e "$f" ] && rec="$f"; done
  if [ -z "$rec" ]; then
    if [ "$(jq -r '.design.version' "$RD/state.json")" = "$to" ]; then echo "MIG-CURRENT $RUN at $to"; exit 0; fi
    die "no migration from $to to roll back"
  fi
  cur="$(jq -r '.design.version' "$RD/state.json")"; from_to="$(jq -r '.to' "$rec")"
  if [ "$cur" != "$to" ]; then
    [ "$cur" = "$from_to" ] || die "run is at $cur; the migration from $to went to $from_to"
    dag_write "$RUN" '
      reduce $chg[] as $x (.; if $x.prev.present then .nodes[$x.id].status = $x.prev.status | .nodes[$x.id].version = $x.prev.version else del(.nodes[$x.id]) end)
      | .design.version = $to | .design.sha256 = $sha' \
      --argjson chg "$(jq -c '.changes' "$rec")" --arg to "$to" --arg sha "$(dir_sha "$RD/nodes.lock.v$to")" || exit $?
  fi
  if [ -d "$RD/nodes.lock.v$to" ]; then set_aside "$RD/nodes.lock"; mv "$RD/nodes.lock.v$to" "$RD/nodes.lock"; fi
  # record copies back to their old schema version through the shared runner; the state copy is renamed here, since
  # state v1 is state.schema.json, which the runner has no numbered schema for
  export MIGRATE_PINS="$RD/pins.json" MIG_DIR="$MIGS"
  if [ -d "$DAG_SCHEMAS/records" ]; then
    while IFS=$'\t' read -r name sv; do
      [ -n "$name" ] || continue
      REC_SCHEMA_DIR="$DAG_SCHEMAS/records" bash "$RUNNER" rollback dag "$to" "$name" "$sv" "$RD/records" || true
    done < <(jq -r '.records | to_entries[] | [.key, .value] | @tsv' "$rec")
  fi
  sv="$(jq -r '.state_schema' "$rec")"
  for f in "$RD"/state.v[0-9]*.json; do
    [ -e "$f" ] || continue
    name="${f##*/state.v}"; name="${name%.json}"
    [ "$name" -gt "$sv" ] && set_aside "$f"
  done
  while IFS=$'\t' read -r name sv; do
    [ -n "$name" ] || continue
    echo "MIG-NODE $name $sv"; dag_ledger "$RUN" migrate "$sv" "$name" "rollback to design $to"
  done < <(jq -r '.changes[] | [.id, (if .prev.present then .prev.status else "DG-SKIPPED" end)] | @tsv' "$rec")
  mv "$rec" "$rec.rolled-back"
  echo "MIG-ROLLED-BACK $RUN -> $to"
}

"do_$verb"
