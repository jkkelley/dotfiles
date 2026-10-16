#!/usr/bin/env bash
# merge-train.sh - collapse every open PR of a repo into its default branch, leaves first.
#
# Owner, 2026-10-16 UTC: "get this code merged the fuck in, dead code is shit, it sitting under agents is stupid"
# (~/AGENTS.md Design principles 101 item 21: a stack is collapsed leaves first by the merge script).
#
# Usage: merge-train.sh --repo <owner/repo> [--dry] [--method merge|squash|rebase] [--retries 3]
#                       [--test-cmd '<cmd>'] [--result <file>] [--recover]
#
# --recover first reopens stranded work: a closed, unmerged PR whose head branch still exists but whose base branch is
# gone gets a new PR from that head into the default branch (GitHub cannot reopen a PR whose base was deleted).
#
# Graph: an open PR whose base is another open PR's head is that PR's child. Post-order walk from every root
# (base = default branch): each child merges into its parent branch, then the parent merges into its base, until the
# root lands on the default branch. CI is judged on the snapshot taken at start, per PR head, because every merge into
# a parent moves the parent's head and would leave its fresh CI pending for the rest of the train.
#
# Skips, each with evidence in the JSON summary: draft, ci-failed (failing check names and log lines), ci-pending,
# blocked-by-ancestor (merging under a skipped parent would strand the code), orphan-base (base is a branch no open PR
# owns), conflict (file list), merge-failed (last API error after --retries attempts).
#
# Conflict: rebase the head on its updated base in a temp clone (or, if that fails, merge the base into it), run --test-cmd with only the files the PR touches,
# force-push with lease, retry the merge once. Still conflicting: report and move on, never block the train.
# Stdout is the JSON summary only; progress goes to stderr.
set -euo pipefail

GH=${GH:-gh}
REPO="" DRY=0 RECOVER=0 METHOD=auto RETRIES=3 TEST_CMD="" RESULT="" SLEEP=${MERGE_TRAIN_SLEEP:-3}

die() { printf 'merge-train: %s\n' "$*" >&2; exit 2; }
log() { printf 'merge-train: %s\n' "$*" >&2; }

while [ $# -gt 0 ]; do
  case $1 in
    --repo) REPO=$2; shift 2 ;;
    --dry) DRY=1; shift ;;
    --recover) RECOVER=1; shift ;;
    --method) METHOD=$2; shift 2 ;;
    --retries) RETRIES=$2; shift 2 ;;
    --test-cmd) TEST_CMD=$2; shift 2 ;;
    --result) RESULT=$2; shift 2 ;;
    -h|--help) sed -n '2,22p' "$0"; exit 0 ;;
    *) die "unknown argument: $1" ;;
  esac
done
[ -n "$REPO" ] || die "--repo <owner/repo> is required"
command -v jq >/dev/null || die "jq is required"

# Retry any gh call up to RETRIES times; the last failure's stderr is kept in LAST_ERR.
LAST_ERR=""
gh_retry() {
  local i out
  for ((i = 1; i <= RETRIES; i++)); do
    if out=$("$GH" "$@" 2>&1); then printf '%s' "$out"; return 0; fi
    LAST_ERR=$out
    [ "$i" -lt "$RETRIES" ] && sleep "$SLEEP"
  done
  return 1
}

repo_json=$(gh_retry api "repos/$REPO") || die "cannot read repo $REPO: $LAST_ERR"
DEFAULT=$(jq -r .default_branch <<<"$repo_json")
if [ "$METHOD" = auto ]; then
  # Merge commits first: they keep a stacked child's commits intact, so a later rebase of a sibling still recognises them.
  METHOD=$(jq -r 'if .allow_merge_commit then "merge" elif .allow_squash_merge then "squash" elif .allow_rebase_merge then "rebase" else "none" end' <<<"$repo_json")
fi
[ "$METHOD" != none ] || die "repo $REPO allows no merge method"

RECOVERED=()
if [ "$RECOVER" = 1 ]; then
  heads=$(gh_retry api "repos/$REPO/git/matching-refs/heads/" --paginate --jq '.[].ref | sub("^refs/heads/"; "")') || die "cannot list branches: $LAST_ERR"
  open_heads=$(gh_retry pr list -R "$REPO" --state open --limit 500 --json headRefName --jq '.[].headRefName') || die "$LAST_ERR"
  while IFS=$'\t' read -r num head base title; do
    grep -qxF "$head" <<<"$heads" || continue
    grep -qxF "$base" <<<"$heads" && continue
    grep -qxF "$head" <<<"$open_heads" && continue
    if [ "$DRY" = 1 ]; then log "would recover #$num ($head) into $DEFAULT"; continue; fi
    body="Supersedes #$num, which GitHub closed when its base branch \`$base\` was deleted by merge-train. Recovered by \`merge-train.sh --recover\`."
    if url=$(gh_retry pr create -R "$REPO" --head "$head" --base "$DEFAULT" --title "$title" --body "$body"); then
      RECOVERED+=("$(jq -nc --argjson n "$num" --arg h "$head" --arg u "$url" '{closed: $n, head: $h, new_pr: $u}')")
      open_heads+=$'\n'"$head"; log "recovered #$num as $url"
    else log "could not recover #$num: $LAST_ERR"; fi
  done < <(gh_retry pr list -R "$REPO" --state closed --limit 500 --json number,headRefName,baseRefName,title,mergedAt \
             --jq '.[] | select(.mergedAt == null) | [.number, .headRefName, .baseRefName, .title] | @tsv' | sort -n)
fi

prs=$(gh_retry pr list -R "$REPO" --state open --limit 500 \
  --json number,title,url,headRefName,baseRefName,isDraft,mergeable,statusCheckRollup) || die "cannot list PRs: $LAST_ERR"

# One record per PR with its CI verdict from the start snapshot.
plan=$(jq --arg dflt "$DEFAULT" '
  def bad: (.conclusion // .state // "") as $c | ["FAILURE","CANCELLED","TIMED_OUT","ACTION_REQUIRED","STARTUP_FAILURE","ERROR"] | index($c);
  def pending: ((.status // "COMPLETED") != "COMPLETED") or ((.state // "") == "PENDING" or (.state // "") == "EXPECTED");
  [.[] | {number, title, url, head: .headRefName, base: .baseRefName, draft: .isDraft,
          failed: [.statusCheckRollup[]? | select(bad) | {name: (.name // .context), url: (.detailsUrl // .targetUrl // "")}],
          pending: [.statusCheckRollup[]? | select(pending) | (.name // .context)]}]
  | (map({key: .head, value: .number}) | from_entries) as $byhead
  | map(. + {parent: (if .base == $dflt then null else $byhead[.base] end)})' <<<"$prs")

# Initial verdict, before ancestry: draft, ci-failed, ci-pending, orphan-base, or ok.
declare -A VERDICT PARENT TITLE URL HEAD BASE
mapfile -t NUMS < <(jq -r '.[].number' <<<"$plan" | sort -n)
for n in "${NUMS[@]}"; do
  r=$(jq -c --argjson n "$n" '.[] | select(.number == $n)' <<<"$plan")
  TITLE[$n]=$(jq -r .title <<<"$r"); URL[$n]=$(jq -r .url <<<"$r")
  HEAD[$n]=$(jq -r .head <<<"$r"); BASE[$n]=$(jq -r .base <<<"$r")
  PARENT[$n]=$(jq -r '.parent // ""' <<<"$r")
  if [ "$(jq -r .draft <<<"$r")" = true ]; then VERDICT[$n]=draft
  elif [ "$(jq '.failed | length' <<<"$r")" -gt 0 ]; then VERDICT[$n]=ci-failed
  elif [ "$(jq '.pending | length' <<<"$r")" -gt 0 ]; then VERDICT[$n]=ci-pending
  elif [ "${BASE[$n]}" != "$DEFAULT" ] && [ -z "${PARENT[$n]}" ]; then VERDICT[$n]=orphan-base
  else VERDICT[$n]=ok; fi
done

# Evidence for a failed check: its name, link, and the tail of the failing job log when it is a GitHub Actions job.
ci_evidence() {
  local n=$1 checks
  checks=$(jq -c --argjson n "$n" '.[] | select(.number == $n) | .failed' <<<"$plan")
  jq -c '.[]' <<<"$checks" | while read -r c; do
    local url job lines=""
    url=$(jq -r .url <<<"$c")
    job=$(sed -n 's#.*/job/\([0-9][0-9]*\).*#\1#p' <<<"$url")
    [ -n "$job" ] && lines=$("$GH" run view -R "$REPO" --job "$job" --log-failed 2>/dev/null | tail -n 25 || true)
    jq -c --arg lines "$lines" '. + {log_tail: ($lines | split("\n") | map(select(length > 0)))}' <<<"$c"
  done | jq -s .
}

MERGED=() SKIPPED=()
skip() { # number reason evidence-json
  SKIPPED+=("$(jq -nc --argjson n "$1" --arg t "${TITLE[$1]}" --arg u "${URL[$1]}" --arg r "$2" --argjson e "$3" \
    '{number: $n, title: $t, url: $u, reason: $r, evidence: $e}')")
  log "skip #$1 ($2)"
}

# Rebase the head on its updated base in a throwaway clone. Prints the conflict file list on failure.
resolve_conflict() {
  local n=$1 tmp files rc=0
  tmp=$(mktemp -d)
  # shellcheck disable=SC2064 # expand now: the path is this call's own clone
  trap "rm -rf '$tmp'" RETURN
  "$GH" repo clone "$REPO" "$tmp" -- --quiet --no-tags >/dev/null 2>&1 || { echo '["clone failed"]'; return 1; }
  (
    cd "$tmp"
    git fetch --quiet origin "${HEAD[$n]}" "${BASE[$n]}"
    git checkout --quiet -B "${HEAD[$n]}" "origin/${HEAD[$n]}"
    local id=(-c user.name=merge-train -c user.email=merge-train@users.noreply.github.com) lease=--force-with-lease
    if ! git "${id[@]}" rebase --quiet "origin/${BASE[$n]}" >/dev/null 2>&1; then
      git rebase --abort >/dev/null 2>&1 || true
      # A rebase replays every commit and stops on the first that conflicts; one 3-way merge of the two tips often
      # resolves cleanly where that replay cannot (ypconsult-01-src, 2026-10-16 UTC). Still conflicting: report it.
      if ! git "${id[@]}" merge --quiet --no-edit "origin/${BASE[$n]}" >/dev/null 2>&1; then
        git diff --name-only --diff-filter=U | jq -R . | jq -sc .
        git merge --abort >/dev/null 2>&1 || true
        exit 1
      fi
      lease=""
    fi
    if [ -n "$TEST_CMD" ]; then
      mapfile -t files < <(git diff --name-only "origin/${BASE[$n]}...HEAD")
      # shellcheck disable=SC2086 # TEST_CMD is a command line by contract
      $TEST_CMD "${files[@]}" >&2 || { echo '["tests failed after rebase"]'; exit 1; }
    fi
    git push --quiet $lease origin "HEAD:${HEAD[$n]}" >&2 || { echo '["push failed"]'; exit 1; }
  ) || rc=$?
  return "$rc"
}

do_merge() { # number -> 0 merged, 1 skipped
  local n=$1 out sha conflict_tried=0 i
  if [ "$DRY" = 1 ]; then
    MERGED+=("$(jq -nc --argjson n "$n" --arg t "${TITLE[$n]}" --arg into "${BASE[$n]}" '{number: $n, title: $t, into: $into, dry: true}')")
    log "would merge #$n into ${BASE[$n]}"; return 0
  fi
  for ((i = 1; i <= RETRIES + 1; i++)); do
    if out=$("$GH" api -X PUT "repos/$REPO/pulls/$n/merge" -f merge_method="$METHOD" 2>&1); then
      sha=$(jq -r '.sha // ""' <<<"$out" 2>/dev/null || true)
      MERGED+=("$(jq -nc --argjson n "$n" --arg t "${TITLE[$n]}" --arg into "${BASE[$n]}" --arg sha "$sha" '{number: $n, title: $t, into: $into, sha: $sha}')")
      log "merged #$n into ${BASE[$n]}"
      # Retarget every still-open child onto ${BASE[$n]} before the head is deleted, then clean it up.
      # Broke on 2026-10-16 UTC (ypconsult-01-src run): deleting the ref through the API does NOT trigger GitHub's
      # auto-retarget (that only follows a UI or delete_branch_on_merge deletion), so 14 open children whose base
      # vanished were closed. Retargeting explicitly is the fix; skipping the delete was rejected because dead branches
      # are the clutter this train exists to remove. Recovery for anything already closed: --recover.
      local child
      for child in $("$GH" pr list -R "$REPO" --state open --base "${HEAD[$n]}" --limit 500 --json number --jq '.[].number' 2>/dev/null); do
        "$GH" api -X PATCH "repos/$REPO/pulls/$child" -f base="${BASE[$n]}" >/dev/null 2>&1 || log "could not retarget #$child"
        [ -n "${BASE[$child]:-}" ] && BASE[$child]=${BASE[$n]}
      done
      if [ -n "$("$GH" pr list -R "$REPO" --state open --base "${HEAD[$n]}" --limit 1 --json number --jq '.[].number' 2>/dev/null)" ]; then
        log "kept ${HEAD[$n]}: an open PR still targets it"
      else
        "$GH" api -X DELETE "repos/$REPO/git/refs/heads/${HEAD[$n]}" >/dev/null 2>&1 || log "could not delete ${HEAD[$n]}"
      fi
      return 0
    fi
    LAST_ERR=$out
    if grep -qiE 'not mergeable|merge conflict|conflict' <<<"$out" && [ "$conflict_tried" = 0 ]; then
      conflict_tried=1
      local files
      if ! files=$(resolve_conflict "$n"); then
        skip "$n" conflict "$(jq -nc --argjson f "${files:-[]}" --arg e "$out" '{files: $f, api: $e}')"; return 1
      fi
    fi
    [ "$i" -le "$RETRIES" ] && sleep "$SLEEP"
  done
  skip "$n" merge-failed "$(jq -nc --arg e "$LAST_ERR" '{api: $e}')"; return 1
}

# Post-order walk: children (by number) before parent. A node merges only if it and every ancestor is ok.
blocked_by() { local p=${PARENT[$1]}; while [ -n "$p" ]; do [ "${VERDICT[$p]}" = ok ] || { echo "$p"; return; }; p=${PARENT[$p]}; done; }
walk() {
  local n=$1 c b
  for c in "${NUMS[@]}"; do [ "${PARENT[$c]}" = "$n" ] && walk "$c"; done
  case ${VERDICT[$n]} in
    ok)
      b=$(blocked_by "$n")
      if [ -n "$b" ]; then skip "$n" blocked-by-ancestor "$(jq -nc --argjson p "$b" --arg v "${VERDICT[$b]}" '{ancestor: $p, ancestor_reason: $v}')"
      else do_merge "$n" || VERDICT[$n]=failed; fi ;;
    ci-failed) skip "$n" ci-failed "$(ci_evidence "$n")" ;;
    ci-pending) skip "$n" ci-pending "$(jq -c --argjson n "$n" '.[] | select(.number == $n) | {checks: .pending}' <<<"$plan")" ;;
    draft) skip "$n" draft '{"isDraft": true}' ;;
    orphan-base) skip "$n" orphan-base "$(jq -nc --arg b "${BASE[$n]}" '{base: $b, note: "no open PR has this branch as its head"}')" ;;
  esac
}

# Roots are PRs with no open parent PR (on the default branch, or orphaned).
for n in "${NUMS[@]}"; do [ -z "${PARENT[$n]}" ] && walk "$n"; done

open_after=null
[ "$DRY" = 1 ] || open_after=$("$GH" pr list -R "$REPO" --state open --limit 500 --json number --jq length 2>/dev/null || echo null)
summary=$(jq -n --arg repo "$REPO" --arg dflt "$DEFAULT" --arg method "$METHOD" --argjson dry "$DRY" \
  --arg at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --argjson open_after "$open_after" \
  --argjson merged "$(printf '%s\n' "${MERGED[@]}" | jq -s 'map(select(. != null))')" \
  --argjson skipped "$(printf '%s\n' "${SKIPPED[@]}" | jq -s 'map(select(. != null))')" \
  --argjson recovered "$(printf '%s\n' "${RECOVERED[@]}" | jq -s 'map(select(. != null))')" \
  '{repo: $repo, default_branch: $dflt, method: $method, dry: ($dry == 1), at: $at,
    recovered: $recovered, merged: $merged, skipped: $skipped, open_after: $open_after}')
[ -n "$RESULT" ] && printf '%s\n' "$summary" >"$RESULT"
printf '%s\n' "$summary"
