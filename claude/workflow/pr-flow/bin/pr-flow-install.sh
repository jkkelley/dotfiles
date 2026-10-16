#!/usr/bin/env bash
# name: pr-flow-install.sh
# purpose: open one PR in a repository that installs (or, with rollback, removes) the rendered pr-flow workflows
# inputs: install|rollback OWNER/NAME [--dry-run]; config/pr-flow.json (ci.* keys); env PR_FLOW_STATE
# outputs: the PR url, or the rendered files and the plan with --dry-run
# writes-to: a temporary clone under PR_FLOW_STATE/install (removed on exit); a branch and a PR in the target repository
# cleanup: the clone is removed by this script; the branch goes with the PR's merge (--delete-branch)
#
#   pr-flow-install.sh install  OWNER/NAME [--dry-run]   render ci.yml and merge-on-green.yml per ci.installed, open one PR
#   pr-flow-install.sh rollback OWNER/NAME [--dry-run]   open one PR deleting merge-on-green.yml (pr-process.md section 14)
#
# Idempotent: when the rendered files already equal the repository's, nothing is opened and the line says so.
# The installing PR itself is merged by hand of the seat (gh pr merge --squash --delete-branch), since the Action it installs only
# runs from the default branch once it is there.
set -uo pipefail
HERE=$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)
VERB=${1:-}; SLUG=${2:-}; DRY=0; [ "${3:-}" = --dry-run ] && DRY=1
die() { local c=$1; shift; echo "pr-flow-install: $*" >&2; exit "$c"; }
case $VERB in install|rollback) ;; *) die 2 "usage: pr-flow-install.sh install|rollback OWNER/NAME [--dry-run]";; esac
cfg=$("$HERE/pr-flow-config.sh" "$SLUG") || exit 2
STATE=${PR_FLOW_STATE:-$HOME/.local/state/zenith/pr-flow}; mkdir -p "$STATE/install" || die 4 "cannot make $STATE/install"
C=$(mktemp -d "$STATE/install/${SLUG//\//_}.XXXX"); trap 'rm -rf "$C"' EXIT
gh repo clone "$SLUG" "$C" -- -q --depth 1 >/dev/null 2>&1 || die 4 "cannot clone $SLUG"
branch="ci/pr-flow-$VERB-$(date -u +%Y%m%d%H%M%S)"; git -C "$C" switch -qc "$branch"
if [ "$VERB" = install ]; then
  for t in $(jq -r '.ci.installed // ["ci", "merge-on-green"] | .[]' <<<"$cfg"); do
    "$HERE/pr-flow-ci-render.sh" --template "$t" --out "$C/.github/workflows/$t.yml" \
      --set "WORKFLOWS=$(jq -c .ci.workflows <<<"$cfg")" --set "REQUIRED_CHECK=$(jq -r .required_check <<<"$cfg")" \
      --set "DISPATCH=$(jq -r .ci.dispatch <<<"$cfg")" --set "PR_TARGETS=$(jq -c .ci.pr_targets <<<"$cfg")" \
      --set "MAIN_TARGETS=$(jq -c .ci.main_targets <<<"$cfg")" --set "SETUP=$(jq -r .ci.setup <<<"$cfg")" \
      --set "CACHE_PATHS=$(jq -r .ci.cache_paths <<<"$cfg")" --set "CACHE_KEYS=$(jq -r .ci.cache_keys <<<"$cfg")" || die 4 "render $t failed"
  done
  title="ci: pr-flow smart CI and merge-on-green"
  body="Installs the pr-flow workflows rendered from jkkelley/dotfiles claude/workflow/pr-flow/templates by pr-flow-install.sh (no hand edits). Design: claude/workflow/docs/pr-process/pr-process.md. Rollback: make pr-flow-rollback REPO=$SLUG."
else
  git -C "$C" rm -q --ignore-unmatch .github/workflows/merge-on-green.yml
  title="ci: roll back pr-flow merge-on-green"; body="Removes merge-on-green.yml (pr-process.md section 14 rollback), by pr-flow-install.sh rollback."
fi
git -C "$C" add -A
if git -C "$C" diff --cached --quiet; then echo "$SLUG: nothing to $VERB, the repository already matches"; exit 0; fi
if [ "$DRY" = 1 ]; then git -C "$C" diff --cached --stat; echo "$SLUG: would open \"$title\""; exit 0; fi
git -C "$C" -c user.name="$(git config user.name)" -c user.email="$(git config user.email)" commit -qm "$title" || die 4 "commit failed"
git -C "$C" push -q origin "$branch" || die 4 "push failed"
(cd "$C" && gh pr create --title "$title" --body "$body" --head "$branch") || die 4 "gh pr create failed"
