#!/usr/bin/env bash
# skill-update.sh — refresh one HAND-AUTHORED skill in a project from the
# published source.
#
# SHOULD YOU BE RUNNING THIS? Look at the project's .claude/skills.toml.
#
#   The skill is named in it  ->  NO. skill-sync owns it. Running this produces a
#                                 copy that the next session start replaces, so
#                                 the work is undone before anyone sees it.
#                                 Nothing warns you; the copy is simply gone.
#   The skill is not named    ->  YES. This is the path for it.
#   There is no skills.toml   ->  YES. The project is not on the sync at all.
#
# That is the whole split, and root CLAUDE.md Rule 16 states it as policy: a
# skill a manifest declares is installed from the published source at every
# session start by claude/tools/skill-sync.sh, which removes what its own receipt
# claims and the manifest no longer asks for. A skill nobody declared is the
# other case, and it is this one - it belongs to the project, it is committed
# there, and something has to be able to pull a newer version of it on demand.
#
# Putting a declared skill on the sync is skill-onboard.sh's job, not this
# script's. Adding one to a project already on the sync is a line in
# .claude/skills.toml and a new session, not a run of anything.
#
# The skill is fetched from GitHub by default, so nothing here depends on the
# machine having a dotfiles checkout. That dependency was the whole problem: the
# script lived inside the checkout it needed, so the one machine that could not
# update a skill was any machine that had never cloned dotfiles - which is every
# machine a vendored copy is most likely to be sitting on.
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
# scripts -> skill-registry -> skills -> claude -> <dotfiles>. Only meaningful
# when this script is running from inside a real checkout, which --from local
# requires and the default does not.
DOTFILES=$(cd "$HERE/../../../.." && pwd)

SRC_REPO="jkkelley/dotfiles"
SRC_REF="main"
FROM="remote"
FETCH_TMP=""
SRC=""

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
Refreshes one HAND-AUTHORED skill in a project. A skill named in that project's
.claude/skills.toml belongs to skill-sync and is reinstalled at every session
start, so pointing this at one only produces a copy that gets replaced.

USAGE
  $SELF --skill <name> --mode inline|standalone [--project <path>]
        [--from remote|local] [--repo OWNER/NAME] [--ref REF] [--dotfiles <path>]
  $SELF --help

OPTIONS
  --skill <name>     Skill directory name, e.g. hydration-prompt
  --mode <mode>      inline      copy into the working tree, leave it uncommitted
                     standalone  branch, copy, commit, PR, squash-merge, clean up
  --project <path>   Project to update. Default: current directory
  --from <where>     remote  fetch from GitHub — needs no checkout (default)
                     local   read --dotfiles, for testing an unpushed change
  --repo OWNER/NAME  Remote source. Default: $SRC_REPO
  --ref REF          Branch or tag to fetch. Default: $SRC_REF
  --dotfiles <path>  Local source checkout, implies --from local. Default: $DOTFILES

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

# Sets SRC. Deliberately NOT called as $(resolve_src): `die` inside a command
# substitution kills only the subshell, so a failed fetch would return an empty
# path to a caller that carried on.
resolve_src() {
  if [[ $FROM == local ]]; then
    SRC="$DOTFILES/claude/skills/$SKILL"
    [[ -f "$SRC/SKILL.md" ]] || die "no such skill in $DOTFILES: $SKILL"
    return 0
  fi
  [[ $FROM == remote ]] || die "--from must be remote or local"
  command -v curl >/dev/null 2>&1 || die "curl is not installed — it is how the skill is fetched"
  command -v tar  >/dev/null 2>&1 || die "tar is not installed — it is how the skill is unpacked"

  # One request for the whole tree, then one directory out of it. A skill is not
  # always a single file — 20 of them ship scripts, tests and references — so a
  # per-file raw fetch would need a file list nobody maintains.
  FETCH_TMP=$(mktemp -d)
  local url="https://codeload.github.com/$SRC_REPO/tar.gz/refs/heads/$SRC_REF"
  curl -fsSL --max-time 120 "$url" -o "$FETCH_TMP/src.tar.gz" \
    || die "could not download $url"

  # The archive root is <repo>-<ref>, but a ref with a slash mangles that, so
  # read it from the archive rather than assuming it.
  local root
  root=$(tar -tzf "$FETCH_TMP/src.tar.gz" 2>/dev/null | head -1 | cut -d/ -f1)
  [[ -n $root ]] || die "downloaded file is not a readable tarball: $url"
  tar -xzf "$FETCH_TMP/src.tar.gz" -C "$FETCH_TMP" "$root/claude/skills/$SKILL" 2>/dev/null \
    || die "no such skill in $SRC_REPO@$SRC_REF: $SKILL"

  SRC="$FETCH_TMP/$root/claude/skills/$SKILL"
  [[ -f "$SRC/SKILL.md" ]] || die "fetched $SKILL but it has no SKILL.md"
}

cleanup_fetch() {
  [[ -n $FETCH_TMP ]] || return 0
  rm -rf -- "$FETCH_TMP"
  FETCH_TMP=""
  return 0
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
  cleanup_fetch
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
    --from)     FROM=${2:-}; shift 2 ;;
    --repo)     SRC_REPO=${2:-}; shift 2 ;;
    --ref)      SRC_REF=${2:-}; shift 2 ;;
    --dotfiles) DOTFILES=${2:-}; FROM="local"; shift 2 ;;
    -h|--help)  usage; exit 0 ;;
    *)          usage >&2; die "unknown argument: $1" ;;
  esac
done

[[ -n $SKILL ]] || { usage >&2; die "--skill is required"; }
[[ $MODE == inline || $MODE == standalone ]] || { usage >&2; die "--mode must be inline or standalone"; }
[[ -d $PROJECT ]] || die "project directory not found: $PROJECT"
PROJECT=$(cd "$PROJECT" && pwd)

DEST_REL=".claude/skills/$SKILL"

# Logging is armed before the fetch, not after, so a download that fails leaves
# the reason in the log rather than only on a terminal somebody has closed.
LOG="$PROJECT/.claude/logs/skill-update-$SKILL-$(date +%Y%m%d-%H%M%S).log"
mkdir -p "$(dirname "$LOG")"
exec > >(tee -a "$LOG") 2>&1
trap on_exit EXIT

step "resolve source"
resolve_src
if [[ $FROM == remote ]]; then
  printf 'fetched %s from %s@%s\n' "$SKILL" "$SRC_REPO" "$SRC_REF"
else
  printf 'reading %s from %s\n' "$SKILL" "$DOTFILES"
fi

NEW_VER=$(read_version "$SRC/SKILL.md")
[[ -n $NEW_VER ]] || die "$SKILL has no version: in its frontmatter — run skill-version.sh init at the source"
OLD_VER=$(read_version "$PROJECT/$DEST_REL/SKILL.md")
[[ -n $OLD_VER ]] || OLD_VER="not installed"

printf '\n%s\n  skill:   %s\n  version: %s -> %s\n  project: %s\n  mode:    %s\n  source:  %s\n' \
  "$SELF" "$SKILL" "$OLD_VER" "$NEW_VER" "$PROJECT" "$MODE" \
  "$([[ $FROM == remote ]] && printf '%s@%s' "$SRC_REPO" "$SRC_REF" || printf '%s' "$DOTFILES")"

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
  --body "Refreshes \`$DEST_REL\` from $SRC_REPO@$SRC_REF.

| | |
|---|---|
| skill | \`$SKILL\` |
| from | \`$OLD_VER\` |
| to | \`v$NEW_VER\` |

Byte copy of the reviewed source in $SRC_REPO, applied by \`$SELF\`. No hand edits.")
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
