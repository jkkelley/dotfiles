#!/usr/bin/env bash
# skill-update.sh — refresh one skill in a project from the dotfiles source.
#
# Two apply modes, matching the two "yes" answers the session-start check offers.
#
#   --mode inline       Copy the skill into the working tree and stop. The change
#                       is left uncommitted so it rides the commit the user is
#                       already about to make. No branch, no PR, no round trip.
#
#   --mode standalone   Do the whole thing now, in a throwaway git worktree so the
#                       user's dirty working tree is never touched: branch off
#                       origin/main, copy, commit, push, open a PR, squash-merge
#                       it, delete the branch, remove the worktree, report the URL.
#                       Merged without review on purpose — the content is a byte
#                       copy of a reviewed file in dotfiles, so there is nothing
#                       for a human to decide.
#
# Every run is logged. A failure names the step it died on and points at the log.
set -euo pipefail

SELF=$(basename "$0")
HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# scripts -> skill-versioning -> skills -> claude -> <dotfiles>
DOTFILES=$(cd "$HERE/../../../.." && pwd)

SKILL=""
MODE=""
PROJECT="$PWD"
STEP="startup"
WORKTREE=""
BRANCH=""
LOG=""

die() { printf '%s: %s\n' "$SELF" "$*" >&2; exit 1; }
step() { STEP=$1; printf '\n[ %s ]\n' "$1"; }

usage() {
  cat <<EOF
USAGE
  $SELF --skill <name> --mode inline|standalone [--project <path>] [--dotfiles <path>]
  $SELF --help

OPTIONS
  --skill <name>     Skill directory name, e.g. hydration-prompt
  --mode <mode>      inline      copy into the working tree, leave it uncommitted
                     standalone  branch, copy, commit, PR, squash-merge, clean up
  --project <path>   Project to update. Default: current directory
  --dotfiles <path>  Source repo. Default: $DOTFILES

EXIT
  0  the skill is at the source version in the project
  1  something failed — the failing step and the log path are printed
EOF
}

# ── frontmatter read, same rule as skill-version.sh ────────────────────────────
read_version() {
  [[ -f "$1" ]] || return 0
  awk '
    NR == 1 && $0 == "---" { inside = 1; next }
    inside && $0 == "---"  { exit }
    inside && /^version:[[:space:]]*/ { sub(/^version:[[:space:]]*/, ""); print; exit }
  ' "$1"
}

# gh wants OWNER/REPO. Accept either remote form rather than assuming one.
repo_slug() {
  local url
  url=$(git -C "$PROJECT" remote get-url origin)
  url=${url%.git}
  url=${url#git@*:}
  url=${url#https://*/}
  printf '%s\n' "$url"
}

# Full replace, not a merge: files deleted upstream must disappear here too, or a
# skill keeps executing a script its own SKILL.md no longer mentions.
copy_skill() {
  local src=$1 dest=$2
  rm -rf "$dest"
  mkdir -p "$dest"
  cp -a "$src/." "$dest/"
}

cleanup_worktree() {
  [[ -n $WORKTREE ]] || return 0
  git -C "$PROJECT" worktree remove --force "$WORKTREE" >/dev/null 2>&1 || rm -rf "$WORKTREE"
  [[ -n $BRANCH ]] && git -C "$PROJECT" branch -D "$BRANCH" >/dev/null 2>&1
  WORKTREE=""
  return 0
}

on_exit() {
  local rc=$?
  if [[ $rc -ne 0 ]]; then
    cleanup_worktree
    printf '\n%s FAILED\n  step: %s\n  exit: %d\n' "$SELF" "$STEP" "$rc" >&2
    [[ -n $LOG ]] && printf '  log:  %s\n' "$LOG" >&2
    printf '  nothing was left half-applied — the worktree and branch are gone\n' >&2
  fi
  return $rc
}

# ── argument parsing ───────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case $1 in
    --skill)    SKILL=${2:-}; shift 2 ;;
    --mode)     MODE=${2:-}; shift 2 ;;
    --project)  PROJECT=${2:-}; shift 2 ;;
    --dotfiles) DOTFILES=${2:-}; shift 2 ;;
    -h|--help)  usage; exit 0 ;;
    *)          usage >&2; die "unknown argument: $1" ;;
  esac
done

[[ -n $SKILL ]] || { usage >&2; die "--skill is required"; }
[[ $MODE == inline || $MODE == standalone ]] || { usage >&2; die "--mode must be inline or standalone"; }
[[ -d $PROJECT ]] || die "project directory not found: $PROJECT"
PROJECT=$(cd "$PROJECT" && pwd)

SRC="$DOTFILES/claude/skills/$SKILL"
[[ -f "$SRC/SKILL.md" ]] || die "no such skill in $DOTFILES: $SKILL"

DEST_REL=".claude/skills/$SKILL"
NEW_VER=$(read_version "$SRC/SKILL.md")
[[ -n $NEW_VER ]] || die "$SKILL has no version: in its frontmatter — run skill-version.sh init in $DOTFILES"
OLD_VER=$(read_version "$PROJECT/$DEST_REL/SKILL.md")
[[ -n $OLD_VER ]] || OLD_VER="not installed"

LOG="$PROJECT/.claude/logs/skill-update-$SKILL-$(date +%Y%m%d-%H%M%S).log"
mkdir -p "$(dirname "$LOG")"
exec > >(tee -a "$LOG") 2>&1
trap on_exit EXIT

printf '%s\n  skill:   %s\n  version: %s -> %s\n  project: %s\n  mode:    %s\n' \
  "$SELF" "$SKILL" "$OLD_VER" "$NEW_VER" "$PROJECT" "$MODE"

# ── inline ─────────────────────────────────────────────────────────────────────
if [[ $MODE == inline ]]; then
  step "copy into working tree"
  copy_skill "$SRC" "$PROJECT/$DEST_REL"

  step "report"
  if git -C "$PROJECT" rev-parse --git-dir >/dev/null 2>&1; then
    git -C "$PROJECT" status --porcelain -- "$DEST_REL" || true
  fi
  cat <<EOF

$SKILL is now v$NEW_VER (was $OLD_VER)
  path: $PROJECT/$DEST_REL
  left uncommitted on purpose — commit it alongside the work you are doing
  log:  $LOG
EOF
  exit 0
fi

# ── standalone ─────────────────────────────────────────────────────────────────
step "preflight"
git -C "$PROJECT" rev-parse --git-dir >/dev/null 2>&1 || die "$PROJECT is not a git repository"
command -v gh >/dev/null 2>&1 || die "gh is not installed — standalone mode needs it to open and merge the PR"

step "fetch origin"
git -C "$PROJECT" fetch origin --prune
git -C "$PROJECT" rev-parse --verify origin/main >/dev/null 2>&1 \
  || die "origin/main not found — standalone mode assumes a main-branch repo"

step "create worktree"
BRANCH="chore/skill-$SKILL-v$NEW_VER"
git -C "$PROJECT" rev-parse --verify "$BRANCH" >/dev/null 2>&1 \
  && die "branch $BRANCH already exists — an earlier run left it behind, delete it and retry"
WORKTREE=$(mktemp -d)
git -C "$PROJECT" worktree add -b "$BRANCH" "$WORKTREE" origin/main

step "copy skill"
copy_skill "$SRC" "$WORKTREE/$DEST_REL"
git -C "$WORKTREE" add -A -- "$DEST_REL"

if git -C "$WORKTREE" diff --cached --quiet; then
  step "nothing to do"
  cleanup_worktree
  printf '\n%s on origin/main is already v%s — no PR opened\n  log: %s\n' "$SKILL" "$NEW_VER" "$LOG"
  exit 0
fi

step "commit"
git -C "$WORKTREE" commit -m "chore(skills): update $SKILL to v$NEW_VER"

step "push"
git -C "$WORKTREE" push -u origin "$BRANCH"

step "open pull request"
PR_URL=$(gh pr create \
  --repo "$(repo_slug)" \
  --base main \
  --head "$BRANCH" \
  --title "chore(skills): update $SKILL to v$NEW_VER" \
  --body "Refreshes \`$DEST_REL\` from dotfiles.

| | |
|---|---|
| skill | \`$SKILL\` |
| from | \`$OLD_VER\` |
| to | \`v$NEW_VER\` |

Byte copy of the reviewed source in dotfiles, applied by \`$SELF\`. No hand edits.")
printf '%s\n' "$PR_URL"

# Retire the worktree before the merge. Leaving the branch checked out in a
# worktree is what makes branch deletion fail afterwards.
step "retire worktree"
cleanup_worktree

step "merge"
gh pr merge "$PR_URL" --squash

step "delete remote branch"
if git -C "$PROJECT" ls-remote --exit-code --heads origin "$BRANCH" >/dev/null 2>&1; then
  git -C "$PROJECT" push origin --delete "$BRANCH"
else
  printf 'already gone (the remote deletes merged branches)\n'
fi

step "clean up"
git -C "$PROJECT" fetch origin --prune

# Untracked files are ignored here on purpose: this script's own log lands in
# .claude/logs/, and an untracked file never blocks a fast-forward anyway.
if [[ $(git -C "$PROJECT" rev-parse --abbrev-ref HEAD) == "main" ]] \
   && [[ -z $(git -C "$PROJECT" status --porcelain --untracked-files=no) ]]; then
  git -C "$PROJECT" merge --ff-only origin/main
  FF_NOTE="local main fast-forwarded"
else
  FF_NOTE="local main NOT fast-forwarded (you are not on a clean main) — run: git -C $PROJECT fetch origin && git -C $PROJECT merge --ff-only origin/main"
fi

cat <<EOF

$SKILL updated to v$NEW_VER (was $OLD_VER)
  PR:   $PR_URL
  path: $PROJECT/$DEST_REL
  $FF_NOTE
  log:  $LOG
EOF
