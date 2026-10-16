#!/usr/bin/env bash
# shellcheck disable=SC2016 # jq filters use $var; they are jq variables, single quotes are the point
# dag-merge.sh - node N9: merge the PR by script once CI is green and the design approval is on record.
#   name:       dag-merge.sh
#   purpose:    node N9 of docs/design/dag-state-nodes.spec.xml: refuse with DG-APPROVAL-MISSING unless a file in approval_dir
#               names the run's design id and version; refuse unless the N8 result is green; then `gh pr merge --squash
#               --delete-branch` and write the merge commit. No review gate, no --auto (owner 2026-10-16 UTC: "we dont need gates we need speed")
#   inputs:     --run <run-id> (or RUN), --node <id> (default N9), --out <file> (default: output.path of <run>/nodes.lock/N9.json,
#               else <run>/records/N9.merge.json); DAG_CONFIG (approval_dir), DAG_APPROVAL_DIR, DAG_CI_RESULT (the N8 output file,
#               default <run>/records/N8.ci.json or N8's output.path), DAG_STATE_DIR, DAG_GH (gh)
#   outputs:    merge JSON (pr, state, merge_commit) at --out; stdout one status line; exit 0 merged (or already MERGED),
#               1 refused or merge failed, 2 usage, 3 DG-SCHEMA
#   writes-to:  the output file inside the run directory only; never state.json
#   cleanup:    removes its temp file on exit
# Spec: docs/design/dag-state-nodes.spec.xml node N9; dag-state.spec.xml rule R7 and code DG-APPROVAL-MISSING.
#
# BREADCRUMB (WO-20261016-0797, dag-state T9). N9 is not idempotent (retry 0), so the one safe re-entry is read first: a PR that
# gh already reports MERGED is success and nothing is merged twice. Approval is a file whose text holds both the design id and
# version; a file naming a different version does not count, since the design moved under it. Rejected: asking a reviewer or
# waiting on a record (the PR process has no gate). Cost: the approval file is the only brake; no file, no merge.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=dag-lib.sh disable=SC1091
. "$HERE/dag-lib.sh"

run="${RUN:-}"; node=N9; out=""
usage() { dag_err "usage: dag-merge.sh --run <run-id> [--node N9] [--out file]"; exit 2; }
while [ $# -gt 0 ]; do
  case "$1" in
    --run) run="${2:-}"; shift 2 ;;
    --node) node="${2:-}"; shift 2 ;;
    --out) out="${2:-}"; shift 2 ;;
    *) usage ;;
  esac
done
[ -n "$run" ] || usage
rd="$(dag_run_dir "$run")" || exit 2
st="$(dag_read "$run")" || exit $?
gh="${DAG_GH:-gh}"
pr="$(jq -r '.pr.number // empty' <<<"$st")"
[ -n "$pr" ] || { dag_err "dag-merge: run $run has no pr.number"; exit 2; }
did="$(jq -r '.design.id' <<<"$st")"; dver="$(jq -r '.design.version' <<<"$st")"
adir="${DAG_APPROVAL_DIR:-$(dag_cfg approval_dir)}"
[ -n "$adir" ] || { dag_err "dag-merge: no approval_dir (set DAG_APPROVAL_DIR or DAG_CONFIG)"; exit 2; }
if [ -z "$out" ]; then
  out="$(jq -r '.output.path // empty' "$rd/nodes.lock/$node.json" 2>/dev/null)"
  case "$out" in "") out="$rd/records/$node.merge.json" ;; /*) ;; *) out="$rd/$out" ;; esac
fi
mkdir -p "$(dirname "$out")"
tmp="$(mktemp "$(dirname "$out")/.merge.XXXXXX")"; trap 'rm -f "$tmp"' EXIT
write() { jq -n --arg s "$1" --arg c "$2" --arg at "$(dag_now)" '{pr:'"$pr"', state:$s, merge_commit:$c, at:$at}' >"$tmp" && mv "$tmp" "$out"; }
view() { $gh pr view "$pr" --json state,mergeCommit 2>/dev/null; }

# already merged: success, nothing to do.
if v="$(view)" && [ "$(jq -r '.state' <<<"$v")" = MERGED ]; then
  write MERGED "$(jq -r '.mergeCommit.oid // ""' <<<"$v")"; printf 'DG-MERGED pr=%s already\n' "$pr"; exit 0
fi

# approval on record: a file naming the design id and version.
ok=""
if [ -d "$adir" ]; then
  while IFS= read -r f; do
    if grep -Fq -- "$did" "$f" && grep -Fq -- "$dver" "$f"; then ok="$f"; break; fi
  done < <(find "$adir" -maxdepth 1 -type f | LC_ALL=C sort)
fi
if [ -z "$ok" ]; then printf 'DG-APPROVAL-MISSING design=%s version=%s dir=%s\n' "$did" "$dver" "$adir"; exit 1; fi

# CI must be green on the N8 result.
ci="${DAG_CI_RESULT:-}"
if [ -z "$ci" ]; then
  ci="$(jq -r '.output.path // empty' "$rd/nodes.lock/N8.json" 2>/dev/null)"
  case "$ci" in "") ci="$rd/records/N8.ci.json" ;; /*) ;; *) ci="$rd/$ci" ;; esac
fi
if [ "$(jq -r '.result // empty' "$ci" 2>/dev/null)" != green ]; then
  printf 'DG-CI-NOT-GREEN pr=%s result_file=%s\n' "$pr" "$ci"; exit 1
fi

if ! $gh pr merge "$pr" --squash --delete-branch; then printf 'DG-MERGE-FAILED pr=%s\n' "$pr"; exit 1; fi
v="$(view)" || { printf 'DG-MERGE-FAILED pr=%s unreadable after merge\n' "$pr"; exit 1; }
[ "$(jq -r '.state' <<<"$v")" = MERGED ] || { printf 'DG-MERGE-FAILED pr=%s state=%s\n' "$pr" "$(jq -r '.state' <<<"$v")"; exit 1; }
write MERGED "$(jq -r '.mergeCommit.oid // ""' <<<"$v")"
printf 'DG-MERGED pr=%s approval=%s\n' "$pr" "$(basename "$ok")"
