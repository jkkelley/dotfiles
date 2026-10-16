#!/usr/bin/env bash
# name: merge-train.sh
# purpose: collapse every open PR of a repo into its default branch, leaves first, through pr-flow's merge.sh
# inputs: merge-train.sh --repo <owner/repo> [--dry] [--result <file>] [--clone DIR]; env GH, MERGE_SH, PR_FLOW_*
# outputs: the JSON summary on stdout (and in --result); progress on stderr
# writes-to: what merge.sh writes (GitHub merges, records); --result
# cleanup: none of its own
#
# Owner, 2026-10-16 UTC: "get this code merged the fuck in, dead code is shit, it sitting under agents is stupid"
# (Design principles 101 item 21: a stack is collapsed leaves first by the merge script).
#
# Usage: merge-train.sh --repo <owner/repo> [--dry] [--result <file>] [--clone DIR]
#
# Graph: an open PR whose base is another open PR's head is that PR's child. Post-order walk from every root (base = the
# default branch), so each child lands in its parent branch before the parent lands in its base. Each PR is merged by
# claude/workflow/pr-flow/bin/merge.sh --pr N, which owns the whole decision: CI green on the head (gate.sh ci-green),
# never CONFLICTING (409 once per head), --match-head-commit, the merge hold, records and cleanup.
#
# BREADCRUMB 2026-10-16 - BR-20261016-merge-port, WO-20261016-1708 (T8). What broke: this script was written new beside
#   coq's proven merge.sh and decided merges itself: its dry run listed a CONFLICTING PR as would-merge (ypconsult-01-src
#   #34) and treated a PR with zero checks as green (#37). Why this fix: one merge decision, coq's, ported to pr-flow; this
#   file keeps only what merge.sh does not do, the leaves-first order of a stack. Rejected: keeping the old body behind a
#   flag (two merge decisions again). Cost: --method, --recover and --test-cmd are gone; merge.sh squashes, and a conflict
#   goes to the worker as merge.conflict 409 (or to regen-conflicts.sh when only generated files conflict) instead of being
#   rebased here. The old body is in git history before this commit.
set -uo pipefail
HERE=$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)
GH=${GH:-gh}; MERGE_SH=${MERGE_SH:-$HERE/../../claude/workflow/pr-flow/bin/merge.sh}
REPO="" DRY=0 RESULT="" CLONE=$(pwd)
die() { printf 'merge-train: %s\n' "$*" >&2; exit 2; }
while [ $# -gt 0 ]; do
  case $1 in
    --repo) REPO=${2:?}; shift 2 ;;
    --dry) DRY=1; shift ;;
    --result) RESULT=${2:?}; shift 2 ;;
    --clone) CLONE=${2:?}; shift 2 ;;
    --method|--retries|--test-cmd) printf 'merge-train: %s is retired (merge.sh owns the merge); ignored\n' "$1" >&2; shift 2 ;;
    --recover) printf 'merge-train: --recover is retired; ignored\n' >&2; shift ;;
    -h|--help) sed -n '12,18p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) die "unknown argument: $1" ;;
  esac
done
[ -n "$REPO" ] || die "--repo <owner/repo> is required"
command -v jq >/dev/null || die "jq is required"

prs=$("$GH" pr list -R "$REPO" --state open --limit 200 --json number,headRefName,baseRefName,isDraft) || { echo "merge-train: gh pr list failed" >&2; exit 4; }
default=$("$GH" repo view "$REPO" --json defaultBranchRef --jq .defaultBranchRef.name) || { echo "merge-train: gh repo view failed" >&2; exit 4; }
# post-order: children (base = this PR's head) before the PR itself, roots are PRs on the default branch
order=$(jq -r --arg d "$default" '
  def walk_from($p): . as $all | ([.[] | select(.baseRefName == $p.headRefName)] | sort_by(.number) | map(. as $c | $all | walk_from($c)) | add // []) + [$p.number];
  . as $all | [.[] | select(.baseRefName == $d)] | sort_by(.number) | map(. as $r | $all | walk_from($r)) | add // [] | .[]' <<<"$prs")
lines=()
for n in $order; do
  if [ "$(jq -r --argjson n "$n" '.[] | select(.number == $n) | .isDraft' <<<"$prs")" = true ]; then
    lines+=("$(jq -nc --argjson pr "$n" '{pr: $pr, outcome: "skipped", detail: "draft"}')"); continue
  fi
  if [ "$DRY" = 1 ]; then lines+=("$(jq -nc --argjson pr "$n" '{pr: $pr, outcome: "would-run", detail: "merge.sh --pr"}')"); continue; fi
  printf 'merge-train: PR %s\n' "$n" >&2
  out=$("$MERGE_SH" --slug "$REPO" --repo "$CLONE" --pr "$n" --json); rc=$?
  [ -n "$out" ] || out=$(jq -nc --argjson pr "$n" --argjson rc "$rc" '{pr: $pr, outcome: "failed", detail: "merge.sh exit \($rc), no line"}')
  lines+=("$out")
  [ "$rc" -ne 4 ] || break   # gh is down: one 423 from merge.sh is enough, as coq's --all stops
done
orphans=$(jq -c --arg d "$default" '. as $all | [$all[] | select(.baseRefName != $d) | . as $p
  | select([$all[] | select(.headRefName == $p.baseRefName)] | length == 0) | {pr: .number, outcome: "skipped", detail: "orphan-base \(.baseRefName)"}]' <<<"$prs")
summary=$(printf '%s\n' "${lines[@]}" | jq -sc --arg r "$REPO" --argjson o "$orphans" '{repo: $r, results: (. + $o), merged: [.[] | select(.outcome == "merged") | .pr]}')
[ -z "$RESULT" ] || printf '%s\n' "$summary" > "$RESULT"
printf '%s\n' "$summary"
