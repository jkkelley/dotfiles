#!/usr/bin/env bash
# name: pr-flow-consume.sh
# purpose: the pr-flow sweep - per configured repository: regenerate generated-file conflicts, post pr.opened, ci.passed, ci.failed
#          and merged records once per head, and merge a green PR the merge-on-green Action left open (the backstop)
# inputs: sweep | loop [--interval S]; env REPO (one OWNER/NAME, default every configured one), PR_FLOW_CONFIG, PR_FLOW_STATE, GH
# outputs: one line per action on stdout
# writes-to: records through records.sh (bus line.<line>.event.*); PR branches through regen-conflicts.sh; PR_FLOW_STATE
# cleanup: make pr-flow-clean removes PR_FLOW_STATE
#
#   pr-flow-consume.sh sweep            one pass
#   pr-flow-consume.sh loop [--interval 60]   a pass every interval, for the pr-flow pane of the monitoring tab (Rule 18: never &)
#   pr-flow-consume.sh regen-index      only the regen verb (env REPO, PR, DRY), what the sweep runs first on every tick
#   pr-flow-consume.sh rerun-stale-red  only the stale-red verb (env REPO, DRY), what the sweep runs on every red PR
#   pr-flow-consume.sh autofix          only the autofix verb (env REPO, PR), what the sweep runs on every red PR after its 422
#
# Records (pr-process.md section 9), each keyed so it is posted once (rule R3):
#   pr.opened 100  first sight of a head                    key 100/<slug>/<pr>/<head>
#   ci.passed 201  gate.sh ci-green passes on the head      key 201/<slug>/<pr>/<head>; note: last check completed <UTC>
#   ci.failed 422  a check concluded red on the head        key 422/<slug>/<pr>/<head>; note: the failing checks. This record is
#                  the fix work order for the worker lane (N3): the worker's consumer pulls line.<line>.event.ci.failed
#   merged 200     a merged PR seen in the last 20          key 200/<slug>/<pr> (the same key merge.sh uses); note: merged_at <UTC>
#                  and seconds from the last check to the merge, the AC2 number
#   regen REGEN    a PR conflicting only on regen.paths was merged with its base, regenerated and pushed  key REGEN/<slug>/<pr>/<new head>
#   ci.rerun RERUN a red whose failing checks started before the base head was refreshed  key RERUN/<slug>/<pr>/<base sha>
#   ci.autofix AUTOFIX  a red PR on headers or markdown contents lists got the mechanical fix pushed  key AUTOFIX/<slug>/<pr>/<head>; note: the fixes
# Backstop (node N4): a PR whose ci.passed was posted more than backstop_s seconds ago and is still open goes to merge.sh --pr.
# Every repository pass runs under step-time.sh (node sweep), so a slow pass posts SLOW (rule R7).
#
# BREADCRUMB 2026-10-16 - BR-20261016-merge-port, WO-20261016-83fb. Why a sweep and not a GitHub webhook consumer: the bus is local
#   (127.0.0.1) and the seats' gh login is the identity whose pushes start CI, which regen needs; a 60 s poll of three repositories is
#   six gh calls a minute. Rejected: posting records from the merge-on-green Action, which cannot reach the local bus. Cost: records
#   lag GitHub by up to one interval; the AC2 timing therefore reads GitHub's own timestamps, not the record times.
#
# BREADCRUMB 2026-10-16 - BR-20261016-infra-design4, ORD-0726 S1. What broke: regen results reached only stdout, so no consumer saw a
#   regen and the line stalled on index-only conflicts unseen (finding F20; dotfiles 159, 161, 162, 180, 187). Why a verb on the sweep:
#   item 30, a need is met by a verb on an existing tool; regen-conflicts.sh is the regen-merge.sh port. Rejected: a second script
#   copied from regen-merge.sh. Cost: one gh pr view per regenerated PR. WO-20261016-565d empties regen.paths, which makes this a no-op
#   by config, no code change.
#
# BREADCRUMB 2026-10-16 - BR-20261016-infra-design4, ORD-0726 S1. What broke: PRs 207 and 210 were MERGEABLE but red on claude/workflow
#   from a run before #208 (1dd0b32), finding F20; repo_pass posts ci.failed once per head and never looks again until the head moves.
#   Why update-branch and not rerun: GitHub docs, Re-running workflows and jobs: "Re-running a workflow or jobs in a workflow uses the
#   same GITHUB_SHA (commit SHA) and GITHUB_REF (Git ref) of the original event that triggered the workflow run", so gh run rerun
#   re-tests the old merge commit that still lacks the fix; a fresh merge ref needs a new pull_request event, which update-branch makes.
#   Rejected: gh run rerun as the default (mode rerun stays for flakes); closing and reopening the PR, which notifies. Cost: a merge
#   commit on the PR branch, as regen-conflicts.sh already makes, and one gh api call per base per pass. stale_red.mode off disables it.
#
# BREADCRUMB 2026-10-16 - WO-20261016-fb99, ORD-0814 P2. What broke: PRs 216, 219, 225, 234 sat red on headers or tracked-ignored-check
#   for a seat each; the fix was a git rm --cached or a contents-list rewrite, both local and fast. Why a verb run in a temp worktree of the
#   PR head: check names do not isolate the cause (job headers runs rolodex-check and tracked-ignored-check), so each configured fix has a
#   detect command and nothing detected means the failure needs content (headers, Bump lines) and stays with the 422 lane. Rejected:
#   fixing in the shared clone, which a seat may be using. Cost: one fetch and one worktree per red PR per head, and a push that starts CI.
#   autofix.mode off disables it by config.
set -uo pipefail
HERE=$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)
GH=${GH:-gh}; RS="$HERE/records.sh"; ST="$HERE/../../bin/step-time.sh"
VERB=${1:-}; shift || true; INTERVAL=60
while [ $# -gt 0 ]; do case $1 in --interval) INTERVAL=${2:?}; shift 2;; *) echo "pr-flow-consume: unknown argument $1" >&2; exit 2;; esac; done
STATE=${PR_FLOW_STATE:-$HOME/.local/state/zenith/pr-flow}; export PR_FLOW_STATE=$STATE; mkdir -p "$STATE" || exit 4

post() { # post SLUG LINE KIND CODE KEY PR SHA TICKET NOTE
  "$RS" post --repo "$1" --line "$2" --kind "$3" --code "$4" --key "$5" --pr "$6" --sha "$7" --ticket "$8" --seat pr-flow-sweep --note "${9:0:240}" \
    | jq -r --arg k "$3" '"posted \($k) pr=\(.pr) sha=\(.sha[0:12]) \(.note // "")"'
}
ticket_of() { local re=$1 t=$2 b=$3 n=$4; if [[ $t =~ $re ]] || [[ $b =~ $re ]]; then echo "${BASH_REMATCH[1]}"; else echo "PR-$n"; fi; }

declare -A MAIN_OF=()
autofix_pr() { # autofix_pr SLUG LINE N HEAD HEADREF BASEREF FORK TICKET FAILED CFG CLONE: push the mechanical fixes to a red PR head, once per head
  local slug=$1 line=$2 n=$3 head=$4 headref=$5 baseref=$6 fork=$7 t=$8 failed=$9 cfg=${10} clone=${11}
  local on_re w name detect fix names=() f i cnt fl key=${slug//\//_}-$n-$head dot
  case $(jq -r '.autofix.mode // "off"' <<<"$cfg") in on) ;; *) return 0;; esac
  on_re=$(jq -r '.autofix.on_checks // ""' <<<"$cfg"); [ -n "$on_re" ] || return 0
  f=0; IFS=, read -ra fl <<<"$failed"; for name in "${fl[@]}"; do [[ $name =~ $on_re ]] && f=1; done; [ $f = 1 ] || return 0
  "$RS" seen --key "AUTOFIX/$slug/$n/$head" && return 0
  [ -e "$STATE/autofix-none/$key" ] && return 0
  if [ "$fork" = true ]; then echo "$slug PR $n autofix-skip fork"; return 0; fi
  dot=$(cd "$HERE/../../../.." && pwd); dot=${DOTFILES:-$dot}
  w=$STATE/autofix/${slug//\//_}-$n; mkdir -p "$STATE/autofix" "$STATE/autofix-none"
  git -C "$clone" worktree remove --force "$w" >/dev/null 2>&1 || true
  if git -C "$clone" fetch -q origin "$headref" "$baseref" >/dev/null 2>&1 && git -C "$clone" worktree add -q --detach "$w" "origin/$headref" >/dev/null 2>&1; then
    cnt=$(jq -r '.autofix.fixes | length' <<<"$cfg")
    for ((i = 0; i < cnt; i++)); do
      name=$(jq -r ".autofix.fixes[$i].name" <<<"$cfg"); detect=$(jq -r ".autofix.fixes[$i].detect" <<<"$cfg"); fix=$(jq -r ".autofix.fixes[$i].fix" <<<"$cfg")
      if ! (cd "$w" && PR_BASE=$baseref DOTFILES=$dot bash -c "$detect") >/dev/null 2>&1; then
        (cd "$w" && PR_BASE=$baseref DOTFILES=$dot bash -c "$fix") >/dev/null 2>&1 && names+=("$name")
      fi
    done
    git -C "$w" add -u >/dev/null 2>&1
    if git -C "$w" diff --cached --quiet; then
      : > "$STATE/autofix-none/$key"; echo "$slug PR $n autofix-none: needs content (fix seat)"
    else
      name=$(IFS=+; echo "${names[*]}")
      git -C "$w" commit -q -m "chore: pr-flow autofix $name (AUTOFIX)" >/dev/null 2>&1
      if git -C "$w" push -q origin "HEAD:$headref" >/dev/null 2>&1; then
        echo "$slug PR $n autofix: $name"
        post "$slug" "$line" ci.autofix AUTOFIX "AUTOFIX/$slug/$n/$head" "$n" "$head" "$t" "fixed: $name"
      else echo "$slug PR $n autofix-fail push"; fi
    fi
  else echo "$slug PR $n autofix-fail fetch"; fi
  git -C "$clone" worktree remove --force "$w" >/dev/null 2>&1 || rm -rf "$w"
  return 0
}

stale_red_pr() { # stale_red_pr SLUG LINE N HEAD BASE TICKET CHECKS MODE: refresh a PR whose red predates its base head, once per base sha
  local slug=$1 line=$2 n=$3 head=$4 base=$5 t=$6 checks=$7 mode=$8 main msha mdate red_at key id ok=0
  case $mode in ""|null|off) return 0;; esac
  if [ -z "${MAIN_OF[$slug/$base]:-}" ]; then
    MAIN_OF[$slug/$base]=$("$GH" api "repos/$slug/commits/$base" --jq '.sha + " " + .commit.committer.date' 2>/dev/null || true)
  fi
  main=${MAIN_OF[$slug/$base]}; msha=${main%% *}; mdate=${main#* }
  [ -n "$msha" ] || return 0
  red_at=$(jq -r '[.[] | select(.s == "completed" and (.c | IN("success", "skipped", "neutral") | not)) | .st] | max // ""' <<<"$checks")
  [[ -n $red_at && $red_at < $mdate ]] || return 0
  key="RERUN/$slug/$n/$msha"
  "$RS" seen --key "$key" && return 0
  if [ -n "${DRY:-}" ]; then echo "$slug PR $n would-rerun: $mode"; return 0; fi
  case $mode in
    update-branch)
      if "$GH" pr update-branch "$n" -R "$slug" >/dev/null 2>&1 \
        || "$GH" api -X PUT "repos/$slug/pulls/$n/update-branch" -f expected_head_sha="$head" >/dev/null 2>&1; then ok=1; fi ;;
    rerun)
      id=$("$GH" run list -R "$slug" --commit "$head" --status failure --json databaseId --jq '.[0].databaseId' 2>/dev/null || true)
      if [ -n "$id" ] && "$GH" run rerun "$id" -R "$slug" --failed >/dev/null 2>&1; then ok=1; fi ;;
  esac
  if [ $ok = 1 ]; then
    post "$slug" "$line" ci.rerun RERUN "$key" "$n" "$head" "$t" "red at $red_at predates $base ${msha:0:12} at $mdate; mode $mode"
    echo "$slug PR $n rerun: $mode"
  else echo "$slug PR $n stale-red-fail: $mode"; fi
  return 0
}

regen_index() { # regen_index SLUG: regenerate index-only conflicts through regen-conflicts.sh and post REGEN once per new head
  local slug=$1 cfg line re clone out l n head pr title body t sel=(--all)
  cfg=$("$HERE/pr-flow-config.sh" "$slug") || return 0
  line=$(jq -r .line <<<"$cfg"); re=$(jq -r .ticket_re <<<"$cfg"); clone=$(jq -r .clone <<<"$cfg")
  export PR_FLOW_RECORDS; PR_FLOW_RECORDS=$(jq -r .records <<<"$cfg")
  [ -n "$(jq -r .regen.paths <<<"$cfg")" ] && { [ -d "$clone/.git" ] || [ -f "$clone/.git" ]; } || return 0
  [ -z "${PR:-}" ] || sel=(--pr "$PR")
  out=$(PR_FLOW_REGEN_PATHS=$(jq -r .regen.paths <<<"$cfg") PR_FLOW_REGEN_CMD=$(jq -r .regen.cmd <<<"$cfg") GH_REPO=$slug \
    "$HERE/regen-conflicts.sh" --repo "$clone" "${sel[@]}" ${DRY:+--dry-run} 2>&1 | grep -v ' clean: ') || true
  while IFS= read -r l; do
    if [[ $l =~ ^PR\ ([0-9]+)\ regenerated:\ (.*)$ ]]; then
      n=${BASH_REMATCH[1]}; pr=$("$GH" pr view "$n" -R "$slug" --json headRefOid,title,body) || continue
      head=$(jq -r .headRefOid <<<"$pr"); title=$(jq -r .title <<<"$pr"); body=$(jq -r '.body // ""' <<<"$pr"); t=$(ticket_of "$re" "$title" "$body" "$n")
      "$RS" seen --key "REGEN/$slug/$n/$head" || post "$slug" "$line" regen REGEN "REGEN/$slug/$n/$head" "$n" "$head" "$t" "regenerated: ${BASH_REMATCH[2]}"
    elif [[ $l == *' real-conflict: '* ]]; then echo "$slug $l"
    elif [ -n "$l" ]; then echo "$l"; fi
  done <<<"$out"
  return 0
}

repo_pass() { # repo_pass SLUG: one pass over one repository
  local slug=$1 cfg line re req clone prs row t n head title body checks failed last merged
  MAIN_OF=()
  cfg=$("$HERE/pr-flow-config.sh" "$slug") || return 2
  line=$(jq -r .line <<<"$cfg"); re=$(jq -r .ticket_re <<<"$cfg"); req=$(jq -r .required_check <<<"$cfg"); clone=$(jq -r .clone <<<"$cfg")
  export PR_FLOW_RECORDS; PR_FLOW_RECORDS=$(jq -r .records <<<"$cfg")
  # generated-file conflicts first: CI does not run on a PR GitHub cannot merge
  regen_index "$slug"
  prs=$("$GH" pr list -R "$slug" --state open --limit 100 --json number,headRefOid,title,body,baseRefName,headRefName,isCrossRepository) || { echo "$slug io: gh pr list"; return 4; }
  while IFS= read -r row; do
    n=$(jq -r .number <<<"$row"); head=$(jq -r .headRefOid <<<"$row"); title=$(jq -r .title <<<"$row"); body=$(jq -r '.body // ""' <<<"$row")
    t=$(ticket_of "$re" "$title" "$body" "$n")
    "$RS" seen --key "100/$slug/$n/$head" || post "$slug" "$line" pr.opened 100 "100/$slug/$n/$head" "$n" "$head" "$t" "PR $n head ${head:0:12}"
    checks=$("$GH" api "repos/$slug/commits/$head/check-runs?per_page=100" --jq '[.check_runs[] | {n: .name, s: .status, c: (.conclusion // ""), at: (.completed_at // ""), st: (.started_at // "")}]') || continue
    failed=$(jq -r '[.[] | select(.s == "completed" and (.c | IN("success", "skipped", "neutral") | not)) | .n] | join(",")' <<<"$checks")
    if [ -n "$failed" ]; then
      "$RS" seen --key "422/$slug/$n/$head" || post "$slug" "$line" ci.failed 422 "422/$slug/$n/$head" "$n" "$head" "$t" "failed: $failed"
      stale_red_pr "$slug" "$line" "$n" "$head" "$(jq -r .baseRefName <<<"$row")" "$t" "$checks" "$(jq -r '.stale_red.mode // "off"' <<<"$cfg")"
      autofix_pr "$slug" "$line" "$n" "$head" "$(jq -r .headRefName <<<"$row")" "$(jq -r .baseRefName <<<"$row")" "$(jq -r .isCrossRepository <<<"$row")" "$t" "$failed" "$cfg" "$clone"
      continue
    fi
    if GH=$GH "$HERE/gate.sh" ci-green --slug "$slug" --pr "$n" --sha "$head" --required "$req" >/dev/null 2>&1; then
      last=$(jq -r '[.[].at] | max' <<<"$checks")
      if ! "$RS" seen --key "201/$slug/$n/$head"; then
        post "$slug" "$line" ci.passed 201 "201/$slug/$n/$head" "$n" "$head" "$t" "last check completed $last"
        date +%s > "$STATE/green-${slug//\//_}-$n"
      elif [ -f "$STATE/green-${slug//\//_}-$n" ] && [ $(( $(date +%s) - $(cat "$STATE/green-${slug//\//_}-$n") )) -gt "$(jq -r .backstop_s <<<"$cfg")" ]; then
        echo "$slug PR $n backstop: green for over $(jq -r .backstop_s <<<"$cfg")s and still open"
        PR_FLOW_LINE=$line PR_FLOW_TICKET_RE=$re PR_FLOW_REQUIRED_CHECK=$req PR_FLOW_SLOTS=$(jq -r 'if .cleanup.slots then 1 else 0 end' <<<"$cfg") \
          "$HERE/merge.sh" --slug "$slug" --repo "$clone" --pr "$n" || true
      fi
    fi
  done < <(jq -c '.[]' <<<"$prs")
  # merges, whoever made them: the Action, merge.sh, or a hand
  merged=$("$GH" pr list -R "$slug" --state merged --limit 20 --json number,title,body,mergedAt,mergeCommit,headRefOid) || return 4
  while IFS= read -r row; do
    n=$(jq -r .number <<<"$row"); "$RS" seen --key "200/$slug/$n" && continue
    head=$(jq -r .headRefOid <<<"$row"); t=$(ticket_of "$re" "$(jq -r .title <<<"$row")" "$(jq -r '.body // ""' <<<"$row")" "$n")
    last=$("$GH" api "repos/$slug/commits/$head/check-runs?per_page=100" --jq '[.check_runs[].completed_at // empty] | max // ""' 2>/dev/null)
    at=$(jq -r .mergedAt <<<"$row")
    secs=""; [ -z "$last" ] || secs=$(( $(date -d "$at" +%s) - $(date -d "$last" +%s) ))
    post "$slug" "$line" merged 200 "200/$slug/$n" "$n" "$(jq -r .mergeCommit.oid <<<"$row")" "$t" "merged_at $at; last check $last; ci_to_merge_s ${secs:-unknown}"
    rm -f "$STATE/green-${slug//\//_}-$n"
  done < <(jq -c --arg since "$(date -u -d '-1 day' +%FT%TZ)" '.[] | select(.mergedAt >= $since)' <<<"$merged")
}

rerun_stale_red() { # rerun_stale_red SLUG: the verb on its own, same listing as repo_pass
  local slug=$1 cfg line re prs row n head title body t checks failed
  MAIN_OF=()
  cfg=$("$HERE/pr-flow-config.sh" "$slug") || return 0
  line=$(jq -r .line <<<"$cfg"); re=$(jq -r .ticket_re <<<"$cfg")
  export PR_FLOW_RECORDS; PR_FLOW_RECORDS=$(jq -r .records <<<"$cfg")
  prs=$("$GH" pr list -R "$slug" --state open --limit 100 --json number,headRefOid,title,body,baseRefName) || { echo "$slug io: gh pr list"; return 0; }
  while IFS= read -r row; do
    n=$(jq -r .number <<<"$row"); head=$(jq -r .headRefOid <<<"$row"); title=$(jq -r .title <<<"$row"); body=$(jq -r '.body // ""' <<<"$row")
    t=$(ticket_of "$re" "$title" "$body" "$n")
    checks=$("$GH" api "repos/$slug/commits/$head/check-runs?per_page=100" --jq '[.check_runs[] | {n: .name, s: .status, c: (.conclusion // ""), at: (.completed_at // ""), st: (.started_at // "")}]') || continue
    failed=$(jq -r '[.[] | select(.s == "completed" and (.c | IN("success", "skipped", "neutral") | not)) | .n] | join(",")' <<<"$checks")
    [ -n "$failed" ] || continue
    stale_red_pr "$slug" "$line" "$n" "$head" "$(jq -r .baseRefName <<<"$row")" "$t" "$checks" "$(jq -r '.stale_red.mode // "off"' <<<"$cfg")"
  done < <(jq -c '.[]' <<<"$prs")
  return 0
}

autofix_verb() { # autofix_verb SLUG: the verb on its own, same listing as repo_pass
  local slug=$1 cfg line re clone prs row n head title body t checks failed
  cfg=$("$HERE/pr-flow-config.sh" "$slug") || return 0
  line=$(jq -r .line <<<"$cfg"); re=$(jq -r .ticket_re <<<"$cfg"); clone=$(jq -r .clone <<<"$cfg")
  export PR_FLOW_RECORDS; PR_FLOW_RECORDS=$(jq -r .records <<<"$cfg")
  prs=$("$GH" pr list -R "$slug" --state open --limit 100 --json number,headRefOid,title,body,baseRefName,headRefName,isCrossRepository) || { echo "$slug io: gh pr list"; return 0; }
  while IFS= read -r row; do
    n=$(jq -r .number <<<"$row"); [ -z "${PR:-}" ] || [ "$PR" = "$n" ] || continue
    head=$(jq -r .headRefOid <<<"$row"); title=$(jq -r .title <<<"$row"); body=$(jq -r '.body // ""' <<<"$row")
    t=$(ticket_of "$re" "$title" "$body" "$n")
    checks=$("$GH" api "repos/$slug/commits/$head/check-runs?per_page=100" --jq '[.check_runs[] | {n: .name, s: .status, c: (.conclusion // ""), at: (.completed_at // ""), st: (.started_at // "")}]') || continue
    failed=$(jq -r '[.[] | select(.s == "completed" and (.c | IN("success", "skipped", "neutral") | not)) | .n] | join(",")' <<<"$checks")
    [ -n "$failed" ] || continue
    autofix_pr "$slug" "$line" "$n" "$head" "$(jq -r .headRefName <<<"$row")" "$(jq -r .baseRefName <<<"$row")" "$(jq -r .isCrossRepository <<<"$row")" "$t" "$failed" "$cfg" "$clone"
  done < <(jq -c '.[]' <<<"$prs")
  return 0
}

sweep() {
  local slug list; if [ -n "${REPO:-}" ]; then list=$REPO; else list=$("$HERE/pr-flow-config.sh" --list); fi
  for slug in $list; do
    cfg=$("$HERE/pr-flow-config.sh" "$slug") || continue
    if [ -x "$ST" ] && [ "${PR_FLOW_UNTIMED:-0}" != 1 ]; then
      PR_FLOW_UNTIMED=1 REPO=$slug "$ST" --line "$(jq -r .line <<<"$cfg")" --node sweep --retries 1 \
        --budget "$(jq -r .budgets.sweep.budget_s <<<"$cfg")" --timeout "$(jq -r .budgets.sweep.timeout_s <<<"$cfg")" -- "$0" sweep
    else repo_pass "$slug"; fi
  done
}

case $VERB in
  regen-index) for slug in ${REPO:-$("$HERE/pr-flow-config.sh" --list)}; do regen_index "$slug"; done ;;
  rerun-stale-red) for slug in ${REPO:-$("$HERE/pr-flow-config.sh" --list)}; do rerun_stale_red "$slug"; done ;;
  autofix) for slug in ${REPO:-$("$HERE/pr-flow-config.sh" --list)}; do autofix_verb "$slug"; done ;;
  sweep) sweep ;;
  loop) while :; do sweep; sleep "$INTERVAL"; done ;;
  *) sed -n '10,11p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 2 ;;
esac
