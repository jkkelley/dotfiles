#!/usr/bin/env bash
#
# skill-onboard.sh - bring a project that already exists onto the skills sync.
#
# One run, one pull request. It declares what the project already has, stops git
# tracking the copies, tells the agent the sync owns them, and hands the slot
# back. After it merges, the next session in that project installs its skills
# from the published source and `registry.json` is the only place a version
# lives.
#
# It writes exactly three things, and every one of them is copied out of the
# templates `project-scaffold` ships rather than re-authored here:
#
#   .claude/skills.toml   the manifest, from references/templates/skills.toml.tmpl
#                         with the [skills] use list replaced by this project's
#   .gitignore            the `**/.claude/skills/` and `.claude/cache/` stanzas,
#                         comments and all, from gitignore.tmpl
#   CLAUDE.md             the `## Skills` section from CLAUDE.md.tmpl, replacing
#                         the prose session-start version check where it is still
#                         there
#
# A second copy of any of those three is the failure this whole ordering was
# designed to prevent - a manifest written here would drift from the template
# within a release and nothing would report it. So there is no template text in
# this file at all: it fetches the real ones and splices.
#
# THE WORKING TREE IS NEVER TOUCHED. Not written, not stashed, not switched. The
# work happens in a treehouse workbench leased for it, which is what makes this
# safe to run in a project somebody is in the middle of using.
#
# AND THE SLOT IS ASSERTED FREE AFTERWARDS, NEVER TRUSTED TO BE. `treehouse
# return` prompts when the worktree is dirty; with no TTY the prompt takes its
# default, the return is abandoned, the slot stays leased - and it exits 0. So
# the release goes through `slot.sh`, which throws that exit code away and asks
# the pool. A run that cannot free its slot exits 5 and says which slot and how
# to free it, because a stranded workbench wants a human rather than a retry.
#
# NOT INSTALLED ANYWHERE. Unlike skill-sync.sh this is run once per project by a
# person, from a checkout or straight off GitHub, so it has no copy sitting in a
# project that could go stale and therefore no row in the registry's tools block
# and no self-update path.
#
# NO HOOK IS INSTALLED. That is machine level and setup.sh owns it.
set -euo pipefail

SELF=$(basename -- "${BASH_SOURCE[0]}")
HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# tools -> claude -> <dotfiles>. Only meaningful when this script is running from
# inside a real checkout, which --from local requires and the default does not.
DOTFILES=$(cd "$HERE/../.." && pwd)

readonly EX_OK=0 EX_USAGE=2 EX_VALIDATION=3 EX_IO=4 EX_POSTSTATE=5

# One of the two documented exceptions in the repository's PII policy: these are
# the addresses of specific published files in this specific public repo, and a
# <placeholder> here would resolve to a repository that does not exist.
SRC_REPO="jkkelley/dotfiles"
SRC_REF="main"

TMPL_DIR="claude/skills/project-scaffold/references/templates"
MANIFEST_TMPL_PATH="$TMPL_DIR/skills.toml.tmpl"
GITIGNORE_TMPL_PATH="$TMPL_DIR/gitignore.tmpl"
CLAUDEMD_TMPL_PATH="$TMPL_DIR/CLAUDE.md.tmpl"
REGISTRY_PATH="claude/skills/registry.json"
SLOT_PATH="claude/skills/hydration-prompt/scripts/slot.sh"

# The heading the new section is written under, and the heading of the prose
# block it replaces where a project still carries it. The second one is what the
# four repositories on WO-20260824-6a33 have today.
SKILLS_HEADING="## Skills"
LEGACY_HEADING="## Session start - skill version check"

# The two gitignore patterns a project needs to be on the sync, and no others.
# `.claude/settings.local.json` and the scaffold lock files are in the same block
# upstream and are not this script's business: they belong to a project that has
# been scaffolded, and this one may never be.
IGNORE_PATTERNS=(
  '**/.claude/skills/'
  '.claude/cache/'
)

# A declared name becomes a directory under .claude/skills/. Same expression
# skill-sync.sh refuses on, for the same reason.
NAME_RE='^[A-Za-z0-9][A-Za-z0-9._-]*$'

PROJECT="$PWD"
FROM="remote"
HOLDER="skill-onboard"
BRANCH="chore/skills-onboard"
BASE="main"
SKILLS_ARG=""
DO_MERGE=1
DRY_RUN=0

WORK=""          # scratch: the fetched tree, the rendered files
SRC=""           # the resolved source tree root - templates and slot.sh live under it
SLOT=""          # the resolved slot.sh
WT=""            # the leased workbench
STEP="startup"
PR_URL=""

declare -a DECLARED=()     # what the manifest will say
declare -a LOCAL_ONLY=()   # in .claude/skills/ and in no registry - left alone
declare -a UNTRACKED=()    # what git stopped tracking

die() { local code=$1; shift; printf '%s: %s\n' "$SELF" "$*" >&2; exit "$code"; }
step() { STEP=$1; printf '\n[ %s ]\n' "$1"; }
note() { printf '  %s\n' "$*"; }

usage() {
  cat <<EOF
$SELF - bring an existing project onto the skills sync, in one pull request.

USAGE
  $SELF [--project <path>] [--skills a,b,c] [--holder LABEL]
        [--branch NAME] [--base REF] [--no-merge] [--dry-run]
        [--from remote|local] [--repo OWNER/NAME] [--ref REF] [--dotfiles PATH]
  $SELF --help

WHAT IT WRITES
  .claude/skills.toml   the manifest, from the template, listing this project's
                        skills - by default the ones already in .claude/skills/
                        that the registry knows about
  .gitignore            $(printf '%s and %s' "${IGNORE_PATTERNS[0]}" "${IGNORE_PATTERNS[1]}")
  CLAUDE.md             the "$SKILLS_HEADING" section, replacing
                        "$LEGACY_HEADING" where it is still present

  and it stops git tracking the declared skill directories. A skill in
  .claude/skills/ that no registry knows is the project's own: it is not
  declared, not un-tracked, and not touched.

OPTIONS
  --project <path>   Project to onboard. Default: current directory
  --skills a,b,c     Declare exactly these instead of discovering them
  --holder LABEL     Lease label for the workbench. Default: $HOLDER
  --branch NAME      Branch to open the pull request from. Default: $BRANCH
  --base REF         Branch to open it against. Default: $BASE
  --no-merge         Open the pull request and stop. Does not squash-merge
  --dry-run          Resolve and print the plan. Takes no slot, writes nothing
  --from <where>     remote  fetch templates from GitHub - needs no checkout
                     local   read --dotfiles, for testing an unpushed change
  --repo OWNER/NAME  Remote source. Default: $SRC_REPO
  --ref REF          Branch or tag to fetch. Default: $SRC_REF
  --dotfiles <path>  Local source checkout, implies --from local

EXIT
  0  the pull request is merged and the workbench is free
  2  called wrong
  3  nothing to declare, an unknown skill name, or the workbench was not clean
  4  a missing dependency, or the source could not be read
  5  THE WORKBENCH IS STILL LEASED. treehouse reported success and the pool
     disagrees. The message names the slot and the command that frees it
EOF
}

# ── the exit path ──────────────────────────────────────────────────────────────
# The release runs on every path out of here once a slot has been taken, and its
# verdict outranks whatever else went wrong. That is not a preference: exit 5
# means a workbench is stranded and a person has to look at it, and a caller that
# saw the earlier failure code instead would retry the one thing retrying cannot
# fix.
on_exit() {
  local rc=$? released=0
  if [[ -n $WT && -n $SLOT ]]; then
    printf '\n[ release the workbench ]\n'
    if bash "$SLOT" release --holder "$HOLDER" --repo "$PROJECT"; then
      released=1
    fi
  fi
  [[ -n $WORK ]] && rm -rf -- "$WORK"
  if [[ -n $WT && -n $SLOT && $released -eq 0 ]]; then
    printf '\n%s: the workbench is STILL LEASED to %s - see above for the command that frees it\n' \
      "$SELF" "$HOLDER" >&2
    if ((rc != 0)); then
      printf '%s: the run had already failed at step: %s\n' "$SELF" "$STEP" >&2
    fi
    exit "$EX_POSTSTATE"
  fi
  if ((rc != 0)); then
    printf '\n%s FAILED\n  step: %s\n  exit: %d\n' "$SELF" "$STEP" "$rc" >&2
  fi
  return "$rc"
}

# ── the source tree ────────────────────────────────────────────────────────────
# Sets SRC. Deliberately not called as $(resolve_src): a `die` inside a command
# substitution kills only the subshell, and the caller would carry on with an
# empty path.
resolve_src() {
  if [[ $FROM == local ]]; then
    SRC="$DOTFILES"
    [[ -f "$SRC/$MANIFEST_TMPL_PATH" ]] \
      || die "$EX_IO" "$DOTFILES does not look like a dotfiles checkout: no $MANIFEST_TMPL_PATH"
    return 0
  fi
  [[ $FROM == remote ]] || die "$EX_USAGE" "--from must be remote or local"
  command -v curl >/dev/null 2>&1 || die "$EX_IO" "curl is not installed - it is how the templates are fetched"
  command -v tar  >/dev/null 2>&1 || die "$EX_IO" "tar is not installed - it is how they are unpacked"

  # One request for the whole tree, then the paths wanted out of it. The same
  # call skill-sync.sh and skill-update.sh already make, for the same reason: a
  # per-file raw fetch would need a file list nobody maintains, and slot.sh is
  # one of the files needed.
  local url="https://codeload.github.com/$SRC_REPO/tar.gz/refs/heads/$SRC_REF"
  curl -fsSL --max-time 120 "$url" -o "$WORK/src.tar.gz" \
    || die "$EX_IO" "could not download $url"

  # The archive root is <repo>-<ref>, but a ref with a slash mangles that, so it
  # is read out of the archive rather than assumed. awk and not `head -1`: awk
  # reads to EOF, so the upstream tar cannot die of SIGPIPE and turn a good
  # archive into a failed pipeline.
  local root
  root=$(tar -tzf "$WORK/src.tar.gz" 2>/dev/null | awk -F/ 'NR == 1 { print $1 }')
  [[ -n $root ]] || die "$EX_IO" "downloaded file is not a readable tarball: $url"
  tar -xzf "$WORK/src.tar.gz" -C "$WORK" \
    "$root/$TMPL_DIR" "$root/$REGISTRY_PATH" "$root/$SLOT_PATH" 2>/dev/null \
    || die "$EX_IO" "$SRC_REPO@$SRC_REF carries no $TMPL_DIR, $REGISTRY_PATH or $SLOT_PATH"
  SRC="$WORK/$root"
}

# Every path this script reads out of the source, checked in one place before
# anything is written. A template that moved is a loud failure here rather than
# an empty section spliced into somebody's CLAUDE.md.
require_source_files() {
  local rel
  for rel in "$MANIFEST_TMPL_PATH" "$GITIGNORE_TMPL_PATH" "$CLAUDEMD_TMPL_PATH" \
             "$REGISTRY_PATH" "$SLOT_PATH"; do
    [[ -s "$SRC/$rel" ]] || die "$EX_IO" "the source tree has no $rel"
  done
  SLOT="$SRC/$SLOT_PATH"
}

# ── reading the templates ──────────────────────────────────────────────────────
# A markdown section: the heading and everything under it up to the next `## `.
# Used on the template to lift `## Skills` out, and on the project's CLAUDE.md to
# ask whether a section is there at all.
section_of() { # $1 = file, $2 = heading
  awk -v h="$2" '
    $0 == h { f = 1 }
    f && /^## / && $0 != h { exit }
    f { print }
  ' "$1"
}

# Replaces the section under $2 with the contents of $3, in place. The caller has
# already established that $2 is present.
splice_section() { # $1 = file, $2 = heading, $3 = block file
  local out="$1.spliced"
  awk -v h="$2" -v b="$3" '
    $0 == h && !done {
      while ((getline l < b) > 0) print l
      skipping = 1; done = 1; next
    }
    skipping && /^## / { skipping = 0 }
    skipping { next }
    { print }
  ' "$1" > "$out"
  mv -f -- "$out" "$1"
}

# A gitignore pattern together with the comment block directly above it. The
# comments are the reason the line is there - the `**/.claude/skills/` one says
# what happens to a project that commits a copy - and a pattern pasted in without
# them is a line the next reader deletes.
stanza_of() { # $1 = gitignore template, $2 = pattern
  awk -v pat="$2" '
    { line[NR] = $0 }
    END {
      for (i = 1; i <= NR; i++) if (line[i] == pat) { hit = i; break }
      if (!hit) exit 3
      s = hit
      while (s > 1 && line[s - 1] ~ /^#/) s--
      for (i = s; i <= hit; i++) print line[i]
    }
  ' "$1"
}

# The manifest, with only the [skills] use list replaced. Every comment in the
# template survives byte for byte, which is the point: the prose explaining why
# there is no version table in there is the half most worth carrying into a
# project, and it is also the half a hand-written copy drops first.
render_manifest() { # $1 = template, $2 = newline-separated names
  awk -v names="$2" '
    /^\[[A-Za-z0-9_.-]+\][[:space:]]*$/ {
      insec = ($0 == "[skills]"); print; next
    }
    insec && !replaced && /^[[:space:]]*use[[:space:]]*=/ {
      print "use = ["
      n = split(names, a, "\n")
      for (i = 1; i <= n; i++) if (a[i] != "") printf "  \"%s\",\n", a[i]
      skipping = 1; replaced = 1; next
    }
    skipping { if (index($0, "]")) { print "]"; skipping = 0 } next }
    { print }
    END { if (!replaced) exit 3 }
  ' "$1"
}

# ── the registry ───────────────────────────────────────────────────────────────
# One line per skill, rendered by skill-version.sh and byte-compared by its own
# verify, so a line-oriented read is safe here. Only the names are wanted: this
# script pins nothing and writes no version anywhere.
registry_names() { # $1 = registry.json
  awk '
    /^  "skills": \{/ { inside = 1; next }
    inside && /^  \}/ { exit }
    inside && match($0, /^    "[^"]+"/) {
      s = substr($0, RSTART + 5, RLENGTH - 5); sub(/"$/, "", s); print s
    }
  ' "$1"
}

in_list() { # $1 = needle, rest = haystack
  local needle=$1; shift
  local item
  for item in "$@"; do [[ $item == "$needle" ]] && return 0; done
  return 1
}

# ── the plan ───────────────────────────────────────────────────────────────────
# What the project already has, split by whether any registry knows it. A skill
# nobody published is the project's own - it gets declared nowhere, un-tracked
# nowhere, and mentioned once so the person running this knows it survived.
build_plan() {
  local -a known=() present=()
  local name
  mapfile -t known < <(registry_names "$SRC/$REGISTRY_PATH")
  ((${#known[@]})) || die "$EX_IO" "the registry at $REGISTRY_PATH lists no skills"

  if [[ -n $SKILLS_ARG ]]; then
    local -a asked=()
    IFS=, read -r -a asked <<< "$SKILLS_ARG"
    local -a unknown=()
    for name in "${asked[@]}"; do
      name=${name// /}
      [[ -n $name ]] || continue
      [[ $name =~ $NAME_RE ]] \
        || die "$EX_VALIDATION" "refusing the name '$name': a skill name becomes a directory and this one is not a plain name"
      if in_list "$name" "${known[@]}"; then DECLARED+=("$name"); else unknown+=("$name"); fi
    done
    if ((${#unknown[@]})); then
      die "$EX_VALIDATION" "no such skill in the registry: ${unknown[*]} - the sync would report these as unknown at every session start"
    fi
  else
    if [[ -d "$PROJECT/.claude/skills" ]]; then
      for name in "$PROJECT"/.claude/skills/*/; do
        [[ -d $name ]] || continue
        name=$(basename -- "${name%/}")
        [[ $name =~ $NAME_RE ]] || continue
        present+=("$name")
      done
    fi
    for name in "${present[@]}"; do
      if in_list "$name" "${known[@]}"; then DECLARED+=("$name"); else LOCAL_ONLY+=("$name"); fi
    done
  fi

  ((${#DECLARED[@]})) || die "$EX_VALIDATION" \
    "nothing to declare: $PROJECT/.claude/skills/ holds no skill the registry knows. Name them with --skills a,b,c"
}

# ── writing, in the workbench ──────────────────────────────────────────────────
# A file that does not end in a newline glues whatever is appended next onto its
# last line. One function because both of the files this script appends to are
# somebody else's, and neither is guaranteed to end tidily.
end_with_newline() { # $1 = file
  [[ -s $1 ]] || return 0
  if [[ $(tail -c1 -- "$1" | wc -l) -eq 0 ]]; then
    printf '\n' >> "$1"
  fi
  return 0
}

write_manifest() {
  local names dest="$WT/.claude/skills.toml"
  names=$(printf '%s\n' "${DECLARED[@]}")
  mkdir -p "$WT/.claude"
  render_manifest "$SRC/$MANIFEST_TMPL_PATH" "$names" > "$dest" \
    || die "$EX_IO" "$MANIFEST_TMPL_PATH has no [skills] use list to replace"
  note "wrote .claude/skills.toml declaring ${#DECLARED[@]}: ${DECLARED[*]}"
}

write_gitignore() {
  local dest="$WT/.gitignore" pattern stanza rules added=0 body=""
  [[ -f $dest ]] || : > "$dest"
  # Comments stripped once, into a variable. `**/.claude/skills/` appears inside
  # the prose explaining the line as well as as the line, so an assertion that
  # greps the whole file matches the explanation and concludes the rule is
  # already there. A variable and a herestring rather than a pipe into `grep -q`,
  # which under pipefail reports "no match" for a match it found early enough to
  # SIGPIPE the awk feeding it.
  rules=$(awk '{ sub(/#.*/, ""); gsub(/^[[:space:]]+|[[:space:]]+$/, "") }
               $0 != "" { print }' "$dest")
  for pattern in "${IGNORE_PATTERNS[@]}"; do
    if grep -qxF -- "$pattern" <<< "$rules"; then
      note ".gitignore already ignores $pattern"
      continue
    fi
    stanza=$(stanza_of "$SRC/$GITIGNORE_TMPL_PATH" "$pattern") \
      || die "$EX_IO" "$GITIGNORE_TMPL_PATH no longer carries the line '$pattern'"
    body+="$stanza"$'\n\n'
    added=$((added + 1))
  done
  ((added)) || { note ".gitignore needed nothing"; return 0; }
  end_with_newline "$dest"
  {
    printf '\n# --- skills sync ------------------------------------------------------------\n'
    printf '# Added by skill-onboard.sh. Copied from %s.\n\n' "$GITIGNORE_TMPL_PATH"
    printf '%s' "$body"
  } >> "$dest"
  note "added $added stanza(s) to .gitignore"
}

write_claude_md() {
  local dest="$WT/CLAUDE.md" block="$WORK/skills-section.md"
  [[ -f $dest ]] || die "$EX_VALIDATION" \
    "$PROJECT has no CLAUDE.md on $BASE - there is nowhere to put the $SKILLS_HEADING section. Scaffold the project first"

  section_of "$SRC/$CLAUDEMD_TMPL_PATH" "$SKILLS_HEADING" > "$block"
  [[ -s $block ]] || die "$EX_IO" "$CLAUDEMD_TMPL_PATH no longer carries a '$SKILLS_HEADING' section"

  if [[ -n $(section_of "$dest" "$SKILLS_HEADING") ]]; then
    splice_section "$dest" "$SKILLS_HEADING" "$block"
    note "replaced the existing $SKILLS_HEADING section in CLAUDE.md"
  elif [[ -n $(section_of "$dest" "$LEGACY_HEADING") ]]; then
    splice_section "$dest" "$LEGACY_HEADING" "$block"
    note "replaced \"$LEGACY_HEADING\" with $SKILLS_HEADING in CLAUDE.md"
  else
    end_with_newline "$dest"
    printf '\n' >> "$dest"
    cat "$block" >> "$dest"
    note "appended the $SKILLS_HEADING section to CLAUDE.md"
  fi
}

# `git rm -r --cached` only where they were committed. A project that never
# committed its skills has nothing to un-track, and an unconditional run there
# fails with "did not match any files", which reads like a broken script.
#
# Only the declared ones. A project-local skill stays tracked and keeps working:
# gitignore has no say over a file git already follows, so the blanket added
# above stops new copies being committed without evicting anything.
untrack_skills() {
  local name path
  for name in "${DECLARED[@]}"; do
    path=".claude/skills/$name"
    [[ -n $(git -C "$WT" ls-files -- "$path") ]] || continue
    git -C "$WT" rm -r --cached --quiet -- "$path"
    UNTRACKED+=("$name")
  done
  if ((${#UNTRACKED[@]})); then
    note "git no longer tracks ${#UNTRACKED[@]}: ${UNTRACKED[*]}"
  else
    note "none of the declared skills were committed - nothing to un-track"
  fi
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

pr_body() {
  cat <<EOF
Brings this project onto the skills sync.

\`.claude/skills.toml\` is the manifest and the only file to edit to add or drop
a skill. The directories under \`.claude/skills/\` are copies from now on: a
\`SessionStart\` hook installs them from the published source at the version
\`registry.json\` names, so nothing here pins a version and there is no version
to hand-maintain.

| | |
|---|---|
| declared | ${DECLARED[*]} |
| un-tracked | ${UNTRACKED[*]:-none - they were never committed} |
| left alone | ${LOCAL_ONLY[*]:-none} |

Applied by \`$SELF\` from $SRC_REPO@$SRC_REF. The three edits are spliced from
the templates \`project-scaffold\` ships, not re-authored.
EOF
}

# ── argument parsing ───────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case $1 in
    --project)  PROJECT=${2:-}; shift 2 ;;
    --skills)   SKILLS_ARG=${2:-}; shift 2 ;;
    --holder)   HOLDER=${2:-}; shift 2 ;;
    --branch)   BRANCH=${2:-}; shift 2 ;;
    --base)     BASE=${2:-}; shift 2 ;;
    --no-merge) DO_MERGE=0; shift ;;
    --dry-run)  DRY_RUN=1; shift ;;
    --from)     FROM=${2:-}; shift 2 ;;
    --repo)     SRC_REPO=${2:-}; shift 2 ;;
    --ref)      SRC_REF=${2:-}; shift 2 ;;
    --dotfiles) DOTFILES=${2:-}; FROM="local"; shift 2 ;;
    -h|--help)  usage; exit "$EX_OK" ;;
    *)          usage >&2; die "$EX_USAGE" "unknown argument: $1" ;;
  esac
done

[[ -d $PROJECT ]] || die "$EX_IO" "project directory not found: $PROJECT"
PROJECT=$(cd "$PROJECT" && pwd)

WORK=$(mktemp -d "${TMPDIR:-/tmp}/skill-onboard.XXXXXX")
trap on_exit EXIT

# ── preflight ──────────────────────────────────────────────────────────────────
step "preflight"
command -v git >/dev/null 2>&1 || die "$EX_IO" "git is not installed"
git -C "$PROJECT" rev-parse --git-dir >/dev/null 2>&1 \
  || die "$EX_VALIDATION" "$PROJECT is not a git repository"
git -C "$PROJECT" remote get-url origin >/dev/null 2>&1 \
  || die "$EX_VALIDATION" "$PROJECT has no origin remote - there is nowhere to open a pull request"
if ((DRY_RUN == 0)); then
  command -v gh >/dev/null 2>&1 \
    || die "$EX_IO" "gh is not installed - it is how the pull request is opened"
fi
note "project: $PROJECT"
note "source:  $([[ $FROM == remote ]] && printf '%s@%s' "$SRC_REPO" "$SRC_REF" || printf '%s' "$DOTFILES")"

step "resolve source"
resolve_src
require_source_files
note "templates and slot.sh read from $SRC"

step "plan"
build_plan
note "declare:    ${DECLARED[*]}"
note "leave be:   ${LOCAL_ONLY[*]:-none}"
note "branch:     $BRANCH -> $BASE"
note "merge:      $( ((DO_MERGE)) && printf 'squash, then delete the branch' || printf 'no - the pull request is left open' )"

if ((DRY_RUN)); then
  printf '\n%s: --dry-run, so no workbench was taken and nothing was written\n' "$SELF"
  exit "$EX_OK"
fi

# ── the workbench ──────────────────────────────────────────────────────────────
step "lease a workbench"
WT=$(bash "$SLOT" acquire --holder "$HOLDER" --repo "$PROJECT") \
  || { WT=""; die "$EX_IO" "could not lease a workbench for $HOLDER"; }
note "$WT"

# Before a single byte is written. A workbench handed over with changes already
# in it cannot be returned - treehouse prompts, takes its no-TTY default and
# leaves the lease in place - so a run that started here would end with the
# workbench stranded AND half this project's onboarding applied to a branch
# nobody asked for. Refusing costs nothing and the release below still reports
# the lease honestly.
step "the workbench must be clean"
if [[ -n $(git -C "$WT" status --porcelain) ]]; then
  git -C "$WT" status --short >&2
  die "$EX_VALIDATION" "the workbench $WT already has uncommitted changes - an earlier run left them. Look at them, then clean the workbench and re-run"
fi
note "clean"

step "branch"
git -C "$WT" fetch origin --prune
git -C "$WT" rev-parse --verify "origin/$BASE" >/dev/null 2>&1 \
  || die "$EX_VALIDATION" "origin/$BASE not found - pass --base with the branch this repository uses"
if git -C "$WT" rev-parse --verify "refs/heads/$BRANCH" >/dev/null 2>&1; then
  die "$EX_VALIDATION" "the branch $BRANCH already exists - an earlier run left it behind. Delete it and re-run"
fi
git -C "$WT" switch -c "$BRANCH" "origin/$BASE"
note "$BRANCH on origin/$BASE"

step "write"
write_manifest
write_gitignore
write_claude_md
untrack_skills

step "commit"
git -C "$WT" add -- .claude/skills.toml .gitignore CLAUDE.md
if git -C "$WT" diff --cached --quiet; then
  die "$EX_VALIDATION" "nothing changed - this project is already on the sync"
fi
git -C "$WT" commit -q -m "chore(skills): bring this project onto the skills sync

Declares ${DECLARED[*]} in .claude/skills.toml, gitignores the installed copies
and the sync cache, and replaces the session-start prose with the $SKILLS_HEADING
section. Applied by $SELF."
note "$(git -C "$WT" log --oneline -1)"

step "push"
git -C "$WT" push -u origin "$BRANCH"

step "open pull request"
PR_URL=$(gh pr create \
  --repo "$(repo_slug)" \
  --base "$BASE" \
  --head "$BRANCH" \
  --title "chore(skills): bring this project onto the skills sync" \
  --body "$(pr_body)")
note "$PR_URL"

# The branch is retired from the workbench either way. A branch still checked out
# somewhere is what makes the deletion fail, and a local branch left behind is
# what makes the next run refuse with "the branch already exists".
#
# `switch --detach` with no ref, and deliberately not `--detach origin/$BASE`.
# Detaching where we already are changes not one file. Checking out the base
# would restore every skill directory this commit just stopped tracking, on top
# of the identical untracked copies still sitting there - which git refuses,
# having no way to know they are the same bytes.
step "leave the branch"
git -C "$WT" switch --detach
git -C "$WT" branch -D "$BRANCH" >/dev/null

if ((DO_MERGE)); then
  step "merge"
  gh pr merge "$PR_URL" --squash --delete-branch
  note "squash-merged and the remote branch is gone"
else
  note "$BRANCH is pushed and the pull request is open - merge it yourself"
fi

step "report"
cat <<EOF

$PROJECT is on the skills sync.
  PR:         $PR_URL
  declared:   ${DECLARED[*]}
  un-tracked: ${UNTRACKED[*]:-none - they were never committed}
  left alone: ${LOCAL_ONLY[*]:-none}

The next session in that project installs them from the published source. Add
or drop a skill by editing .claude/skills.toml - nothing else.
EOF
