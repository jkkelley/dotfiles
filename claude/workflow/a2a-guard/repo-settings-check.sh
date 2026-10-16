#!/usr/bin/env bash
# name: repo-settings-check.sh
# purpose: read-only report of auto-merge, branch protection and merge workflow per repo, by status code.
# outputs: stdout one RS-* line per repo, exit code
# writes-to: nothing
# cleanup: none
# repo-settings-check.sh - read-only report, per repo, of what merge-on-green needs: allow_auto_merge, branch protection
#   on the default branch, and a workflow that merges on green. Changes nothing; merge-port owns the workflow itself.
#
# usage: repo-settings-check.sh OWNER/REPO...
# prints one line per repo: "<code> <repo> auto_merge=<bool> protection=<bool> merge_workflow=<file|none>"
#   RS-OK              all three present
#   RS-NO-AUTOMERGE    allow_auto_merge is false (gh pr merge --auto is refused)
#   RS-NO-PROTECTION   the default branch has no protection rule (gh refuses --auto with nothing to wait on)
#   RS-NO-MERGE-WF     no workflow under .github/workflows mentions auto-merge or gh pr merge
#   RS-UNREADABLE      the API call failed (no access, no repo)
#   several failures print the first in the order above; every field is still printed.
# exit: 0 all RS-OK, 1 any other code, 2 usage.
# inputs: arguments; GH_BIN (default gh). writes-to: stdout only. cleanup: none.
#
# BREADCRUMB - P2 of brief BR-20261016-a2a-guard: `gh pr merge --auto` was refused on all three repos (no protected
#   branch on dotfiles main; allow_auto_merge=false on the private repos), and nobody could see why until a merge failed.
#   Read-only on purpose: settings are the owner's and merge-port's to change; this only makes the gap visible with a code.
set -uo pipefail
GH="${GH_BIN:-gh}"
[ $# -gt 0 ] || { echo "A2A-USAGE repo-settings-check.sh OWNER/REPO..." >&2; exit 2; }
rc=0
for r in "$@"; do
  info=$("$GH" api "repos/$r" 2>/dev/null) || { echo "RS-UNREADABLE $r"; rc=1; continue; }
  am=$(jq -r '.allow_auto_merge // false' <<<"$info"); def=$(jq -r '.default_branch' <<<"$info")
  if "$GH" api "repos/$r/branches/$def/protection" >/dev/null 2>&1; then prot=true
  elif "$GH" api "repos/$r/rulesets" 2>/dev/null | jq -e 'length > 0' >/dev/null 2>&1; then prot=true
  else prot=false; fi
  wf=none
  while read -r path; do
    [ -n "$path" ] || continue
    if "$GH" api "repos/$r/contents/$path" -q .content 2>/dev/null | base64 -d 2>/dev/null \
         | grep -qiE 'gh pr merge|auto-merge|automerge|enablePullRequestAutoMerge'; then wf=$(basename "$path"); break; fi
  done < <("$GH" api "repos/$r/contents/.github/workflows" -q '.[].path' 2>/dev/null)
  if [ "$am" != true ]; then code=RS-NO-AUTOMERGE; elif [ $prot != true ]; then code=RS-NO-PROTECTION
  elif [ "$wf" = none ]; then code=RS-NO-MERGE-WF; else code=RS-OK; fi
  [ "$code" = RS-OK ] || rc=1
  printf '%s %s auto_merge=%s protection=%s merge_workflow=%s\n' "$code" "$r" "$am" "$prot" "$wf"
done
exit $rc
