#!/usr/bin/env bash
# name: gate.sh
# purpose: the pr-flow merge gate - same-head from coq's factory/bin/gate.sh, and ci-green in place of review
# inputs: verb and flags below; env GH (default gh), PR_FLOW_IGNORE_PATHS (default events)
# outputs: exit code and one hold line on stdout; differing paths for same-head
# writes-to: nothing (same-head may git fetch origin once)
# cleanup: none
#
# Ported from ~/projects/coq-jev-herdr-plugin factory/bin/gate.sh at 4f7f44c (pr-process.md section 7, rule R1).
#
#   gate.sh same-head [--repo DIR] A B            0 the two shas are one head: equal, or their trees differ only under ignored paths
#                                                 1 they differ; the paths that differ are printed, one per line
#                                                 4 a sha is not in the repo
#   gate.sh ci-green --slug OWNER/NAME --pr N --sha SHA [--required CHECK]
#                                                 0 the PR's head is SHA and every check run on it completed with success, skipped
#                                                   or neutral, and CHECK (default ci-ok) is among them and passed
#                                                 1 hold: the reason is printed on one line   4 gh failed 3 times
# Exit: 0 ok, 1 hold or differ, 2 usage, 4 io or a sha the repo cannot resolve.
#
# BREADCRUMB 2026-10-16 - BR-20261016-merge-port, WO-20261016-e6f1. What changed from coq, and why:
#   - heads_match (test.passed 201 on the same head) is replaced by ci-green. Owner, 2026-10-16 UTC: "automate that process, we dont
#     need gates we need speed"; CI on the head is the only gate, so the reviewer and tester records are gone.
#   - when, supersedes and pr-files are not ported: they read coq's records tree through paths.sh and claims.sh, which pr-flow does not
#     have; supersede is GitHub's job now (concurrency cancel-in-progress on a new head).
#   - the excluded path list is PR_FLOW_IGNORE_PATHS (space separated, default events, coq's value) instead of a literal, so a repo
#     that writes generated files from a gate names them in config (section 10, ignore_paths).
#   - ci-green holds a PR with zero checks (F3, ypconsult-01-src #37 merged that way under the old merge-train) and one whose head moved.
#   The coq breadcrumbs that explain same-head's choices 2 and 4 are kept below unchanged.
#   Choices that look arbitrary (coq):
#   2. A sha the repo cannot resolve is exit 4, not "differ", after one `git fetch origin` (20 s). A PR head lives on origin until
#      someone fetches it; calling it different would hold every merge in a checkout that has not fetched. Cost: with no network the
#      answer is an error, and route.sh turns it into a 500 rather than a hold.
#   4. Two literal shas where one is a prefix of the other (7 characters or more) are the same head with no git call, so a unit
#      test, or a checkout without the commit, still agrees with itself.
set -uo pipefail
export LC_ALL=C
REPO=$(pwd); SLUG=""; PR=""; SHA_ARG=""; REQUIRED="ci-ok"; GH=${GH:-gh}
read -r -a IGNORE <<<"${PR_FLOW_IGNORE_PATHS:-events}"
EXCL=(); for p in "${IGNORE[@]}"; do EXCL+=(":(exclude)$p"); done
die() { local c=$1; shift; printf 'gate: %s\n' "$*" >&2; exit "$c"; }
command -v jq >/dev/null || die 4 "jq is required"
VERB=${1:-}; shift || true
ARGS=()
while [ $# -gt 0 ]; do case $1 in
  --repo) REPO=$(cd "${2:?}" && pwd) || die 4 "no such --repo"; shift 2;; --slug) SLUG=${2:?}; shift 2;; --pr) PR=${2:?}; shift 2;;
  --sha) SHA_ARG=${2:?}; shift 2;; --required) REQUIRED=${2:?}; shift 2;;
  -*) die 2 "unknown flag $1";; *) ARGS+=("$1"); shift;; esac; done
case $VERB in same-head|ci-green) ;; *) sed -n '11,18p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 2;; esac

# resolve SHA: the commit it names in the repo, fetching once when it is not there; empty when it cannot be found.
resolve() {
  local c; c=$(git -C "$REPO" rev-parse --verify --quiet "$1^{commit}" 2>/dev/null) && { printf '%s' "$c"; return; }
  timeout 20 git -C "$REPO" fetch --quiet origin >/dev/null 2>&1 || true
  git -C "$REPO" rev-parse --verify --quiet "$1^{commit}" 2>/dev/null || true
}
# same_head A B: 0 same, 1 differ (paths on stdout), 4 unresolvable (the sha on stderr).
same_head() {
  local a=$1 b=$2 ca cb
  [[ $a =~ ^[0-9a-f]{7,40}$ && $b =~ ^[0-9a-f]{7,40}$ ]] || { printf 'gate: malformed sha %s or %s\n' "$a" "$b" >&2; return 4; }
  case $a in "$b"*) return 0;; esac; case $b in "$a"*) return 0;; esac
  ca=$(resolve "$a"); [ -n "$ca" ] || { printf 'gate: %s is not in this repo\n' "$a" >&2; return 4; }
  cb=$(resolve "$b"); [ -n "$cb" ] || { printf 'gate: %s is not in this repo\n' "$b" >&2; return 4; }
  [ "$ca" != "$cb" ] || return 0
  git -C "$REPO" diff --quiet "$ca" "$cb" -- . "${EXCL[@]}" && return 0
  git -C "$REPO" diff --name-only "$ca" "$cb" -- . "${EXCL[@]}"; return 1
}
# hold REASON: the one line a caller writes into its record.
hold() { printf '%s\n' "$1" | cut -c1-200; exit 1; }
# gh_retry ARGS...: gh, up to 3 tries with backoff (rule R5); stdout is gh's.
gh_retry() { local n; for n in 1 2 3; do "$GH" "$@" 2>/dev/null && return 0; sleep "$(( n * ${GATE_BACKOFF:-2} ))"; done; return 1; }
ci_green() {
  if [ -z "$SLUG" ] || [ -z "$PR" ] || [ -z "$SHA_ARG" ]; then die 2 "ci-green needs --slug, --pr and --sha"; fi
  local head checks pending failed
  head=$(gh_retry pr view "$PR" -R "$SLUG" --json headRefOid --jq .headRefOid) || die 4 "gh failed 3 times reading PR $PR"
  case $head in "$SHA_ARG"*) ;; *) hold "head moved: PR $PR is at $head, not $SHA_ARG";; esac
  checks=$(gh_retry api "repos/$SLUG/commits/$head/check-runs?per_page=100" --jq '[.check_runs[] | {n: .name, s: .status, c: (.conclusion // "")}]') \
    || die 4 "gh failed 3 times reading checks on $head"
  pending=$(jq -r '[.[] | select(.s != "completed") | .n] | join(",")' <<<"$checks")
  [ -z "$pending" ] || hold "pending: $pending"
  failed=$(jq -r '[.[] | select(.c | IN("success", "skipped", "neutral") | not) | .n] | join(",")' <<<"$checks")
  [ -z "$failed" ] || hold "failed: $failed"
  jq -e --arg r "$REQUIRED" 'any(.[]; .n == $r and .c == "success")' <<<"$checks" >/dev/null || hold "required check $REQUIRED has not passed on $head"
  exit 0
}

case $VERB in
  same-head) [ "${#ARGS[@]}" = 2 ] || die 2 "same-head needs two shas"; same_head "${ARGS[0]}" "${ARGS[1]}"; exit $? ;;
  ci-green) [ "${#ARGS[@]}" = 0 ] || die 2 "ci-green takes no positional arguments"; ci_green ;;
esac
