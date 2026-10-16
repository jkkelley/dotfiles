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
#
# Records (pr-process.md section 9), each keyed so it is posted once (rule R3):
#   pr.opened 100  first sight of a head                    key 100/<slug>/<pr>/<head>
#   ci.passed 201  gate.sh ci-green passes on the head      key 201/<slug>/<pr>/<head>; note: last check completed <UTC>
#   ci.failed 422  a check concluded red on the head        key 422/<slug>/<pr>/<head>; note: the failing checks. This record is
#                  the fix work order for the worker lane (N3): the worker's consumer pulls line.<line>.event.ci.failed
#   merged 200     a merged PR seen in the last 20          key 200/<slug>/<pr> (the same key merge.sh uses); note: merged_at <UTC>
#                  and seconds from the last check to the merge, the AC2 number
# Backstop (node N4): a PR whose ci.passed was posted more than backstop_s seconds ago and is still open goes to merge.sh --pr.
# Every repository pass runs under step-time.sh (node sweep), so a slow pass posts SLOW (rule R7).
#
# BREADCRUMB 2026-10-16 - BR-20261016-merge-port, WO-20261016-83fb. Why a sweep and not a GitHub webhook consumer: the bus is local
#   (127.0.0.1) and the seats' gh login is the identity whose pushes start CI, which regen needs; a 60 s poll of three repositories is
#   six gh calls a minute. Rejected: posting records from the merge-on-green Action, which cannot reach the local bus. Cost: records
#   lag GitHub by up to one interval; the AC2 timing therefore reads GitHub's own timestamps, not the record times.
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

repo_pass() { # repo_pass SLUG: one pass over one repository
  local slug=$1 cfg line re req clone prs row t n head title body checks failed last merged
  cfg=$("$HERE/pr-flow-config.sh" "$slug") || return 2
  line=$(jq -r .line <<<"$cfg"); re=$(jq -r .ticket_re <<<"$cfg"); req=$(jq -r .required_check <<<"$cfg"); clone=$(jq -r .clone <<<"$cfg")
  export PR_FLOW_RECORDS; PR_FLOW_RECORDS=$(jq -r .records <<<"$cfg")
  # generated-file conflicts first: CI does not run on a PR GitHub cannot merge
  if [ -n "$(jq -r .regen.paths <<<"$cfg")" ] && { [ -d "$clone/.git" ] || [ -f "$clone/.git" ]; }; then
    PR_FLOW_REGEN_PATHS=$(jq -r .regen.paths <<<"$cfg") PR_FLOW_REGEN_CMD=$(jq -r .regen.cmd <<<"$cfg") GH_REPO=$slug \
      "$HERE/regen-conflicts.sh" --repo "$clone" --all | grep -v ' clean: ' || true
  fi
  prs=$("$GH" pr list -R "$slug" --state open --limit 100 --json number,headRefOid,title,body) || { echo "$slug io: gh pr list"; return 4; }
  while IFS= read -r row; do
    n=$(jq -r .number <<<"$row"); head=$(jq -r .headRefOid <<<"$row"); title=$(jq -r .title <<<"$row"); body=$(jq -r '.body // ""' <<<"$row")
    t=$(ticket_of "$re" "$title" "$body" "$n")
    "$RS" seen --key "100/$slug/$n/$head" || post "$slug" "$line" pr.opened 100 "100/$slug/$n/$head" "$n" "$head" "$t" "PR $n head ${head:0:12}"
    checks=$("$GH" api "repos/$slug/commits/$head/check-runs?per_page=100" --jq '[.check_runs[] | {n: .name, s: .status, c: (.conclusion // ""), at: (.completed_at // "")}]') || continue
    failed=$(jq -r '[.[] | select(.s == "completed" and (.c | IN("success", "skipped", "neutral") | not)) | .n] | join(",")' <<<"$checks")
    if [ -n "$failed" ]; then
      "$RS" seen --key "422/$slug/$n/$head" || post "$slug" "$line" ci.failed 422 "422/$slug/$n/$head" "$n" "$head" "$t" "failed: $failed"
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
  sweep) sweep ;;
  loop) while :; do sweep; sleep "$INTERVAL"; done ;;
  *) sed -n '10,11p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 2 ;;
esac
