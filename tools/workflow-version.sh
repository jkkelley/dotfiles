#!/usr/bin/env bash
# skill-tool-version: 1.0.0
#
# workflow-version.sh — owns the versions of the documents in workflows/.
#
# A workflow document states how this repository is operated. The version exists
# so that "the procedure changed" is a fact with a number on it rather than a
# thing you notice from a diff, and so that a document nobody versioned cannot
# quietly join the set.
#
#   workflow-version.sh init                    stamp unversioned documents at 1.0.0
#   workflow-version.sh bump <name> --minor     bump one document
#   workflow-version.sh verify                  every document carries a version
#   workflow-version.sh list                    print every document and its version
#
# Deliberately NOT a second registry. skill-version.sh writes registry.json
# because projects fetch it over HTTPS to decide what to install. Nothing fetches
# these documents, so an index would be a generated file with no reader. verify
# walking the directory buys the whole anti-drift property at none of the cost.
#
# Deliberately NOT part of skill-version.sh either. That script is built around a
# tree of <dir>/<name>/SKILL.md with YAML frontmatter; these are flat markdown
# files with an HTML comment. Teaching one script two unrelated trees is how both
# of them get harder to change.
#
# WORKFLOW_VERSION_DIR overrides the workflows directory (used by the tests).
set -euo pipefail

SELF=$(basename "$0")
HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
WORKFLOWS_DIR=${WORKFLOW_VERSION_DIR:-$(cd "$HERE/.." && pwd)/workflows}

# The same marker token claude/tools/ uses, so the repository has one convention
# rather than two. Not `version:`, so it can never collide with a version: in
# prose, and it reads under any comment syntax.
MARKER='workflow-version'

die() { printf '%s: %s\n' "$SELF" "$*" >&2; exit 1; }

usage() {
  cat <<EOF
USAGE
  $SELF init
  $SELF bump <name> --major|--minor|--patch
  $SELF verify
  $SELF list
  $SELF --help

SUBCOMMANDS
  init     Stamp every document with no $MARKER marker at 1.0.0. Safe to
           re-run — already-versioned documents are left alone.

  bump     Raise one document's version. This is the only supported way to
           change it. Never hand-edit the marker.

             --major   the procedure changed in a way that invalidates the old
             --minor   a step was added, and the old procedure still works
             --patch   wording, a clarification, a corrected path

  verify   Exit non-zero if any document in workflows/ carries no version, or
           carries one that is not semver. Names every offender rather than
           printing a count, because the answer wanted is which file to fix.

  list     Print each document and its current version.

THE MARKER
  Line two of the document, or anywhere in its first 20 lines:

    <!-- $MARKER: 1.0.0 -->

FILES
  $WORKFLOWS_DIR
EOF
}

# ── discovery ──────────────────────────────────────────────────────────────────
# Deterministic order. Only .md files directly in workflows/ count; a nested
# directory is somebody's supporting material, not a procedure.
doc_files() {
  find "$WORKFLOWS_DIR" -mindepth 1 -maxdepth 1 -type f -name '*.md' \
    | LC_ALL=C sort
  return 0
}

doc_name() { basename -- "$1" .md; }

# ── the marker ─────────────────────────────────────────────────────────────────
# Read from the head of the file so it stays a header field rather than something
# that can hide at the bottom. Matched loosely enough to survive any comment
# syntax.
#
# Returns the raw token rather than only a well-formed semver, on purpose. A file
# carrying `1.0` has a marker and a wrong value; reporting that as "unversioned"
# sends the reader looking for a marker that is sitting right there. verify is
# what judges the shape.
read_doc_version() {
  [[ -f "$1" ]] || return 0
  head -20 "$1" | awk -v m="$MARKER" '
    match($0, m ":[[:space:]]*[^[:space:]]+") {
      s = substr($0, RSTART, RLENGTH)
      sub(/.*:[[:space:]]*/, "", s)
      print s; exit
    }'
}

# Replaces the marker in place, or inserts one directly under the title. Under
# the title rather than at line one so the document still opens with its own
# heading when read by a human or rendered anywhere.
write_doc_version() {
  local file=$1 ver=$2 tmp
  tmp=$(mktemp)
  if [[ -n $(read_doc_version "$file") ]]; then
    awk -v m="$MARKER" -v ver="$ver" '
      !done && match($0, m ":[[:space:]]*[0-9]+\\.[0-9]+\\.[0-9]+") {
        print "<!-- " m ": " ver " -->"; done = 1; next
      }
      { print }
    ' "$file" > "$tmp"
  else
    awk -v m="$MARKER" -v ver="$ver" '
      NR == 1 { print; if ($0 ~ /^# /) { print ""; print "<!-- " m ": " ver " -->"; done = 1 } next }
      !done && !inserted { print "<!-- " m ": " ver " -->"; print ""; inserted = 1 }
      { print }
    ' "$file" > "$tmp"
  fi
  cat "$tmp" > "$file"
  rm -f "$tmp"
}

# ── subcommands ────────────────────────────────────────────────────────────────
cmd_init() {
  local stamped=0 f
  while IFS= read -r f; do
    if [[ -z $(read_doc_version "$f") ]]; then
      write_doc_version "$f" "1.0.0"
      printf 'stamped   %s  1.0.0\n' "$(doc_name "$f")"
      stamped=$((stamped + 1))
    fi
  done < <(doc_files)
  printf '\n%d document(s) stamped\n' "$stamped"
}

cmd_bump() {
  local name=${1:-} level=${2:-} file cur new ma mi pa
  [[ -n $name && -n $level ]] || die "usage: $SELF bump <name> --major|--minor|--patch"
  file="$WORKFLOWS_DIR/${name%.md}.md"
  [[ -f "$file" ]] || die "no such workflow document: $name"

  cur=$(read_doc_version "$file")
  [[ -n $cur ]] || cur="0.0.0"
  [[ $cur =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "$name has a malformed version: $cur"
  IFS=. read -r ma mi pa <<< "$cur"

  case $level in
    --major) ma=$((ma + 1)); mi=0; pa=0 ;;
    --minor) mi=$((mi + 1)); pa=0 ;;
    --patch) pa=$((pa + 1)) ;;
    *) die "unknown level: $level (want --major, --minor or --patch)" ;;
  esac

  new="$ma.$mi.$pa"
  write_doc_version "$file" "$new"
  printf '%s  %s -> %s\n' "$(doc_name "$file")" "$cur" "$new"
}

cmd_verify() {
  local rc=0 f total=0 ver unversioned=0 malformed=0
  while IFS= read -r f; do
    total=$((total + 1))
    ver=$(read_doc_version "$f")
    if [[ -z $ver ]]; then
      printf 'unversioned   %s\n' "$(doc_name "$f")" >&2
      unversioned=1
      rc=1
    elif [[ ! $ver =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
      printf 'malformed     %s  (%s)\n' "$(doc_name "$f")" "$ver" >&2
      malformed=1
      rc=1
    fi
  done < <(doc_files)

  # Two different failures want two different instructions. init stamps a file
  # that has no marker and deliberately skips one that has a wrong marker, so
  # telling a reader with a malformed version to run init sends them to a command
  # that will do nothing and report success.
  if [[ $rc -ne 0 ]]; then
    [[ $unversioned -eq 0 ]] || printf "\nrun '%s init' to stamp them\n" "$SELF" >&2
    [[ $malformed -eq 0 ]] || printf "\ncorrect the marker by hand, then '%s bump' owns it from there\n" "$SELF" >&2
    return 1
  fi

  printf 'ok — %d workflow document(s) versioned\n' "$total"
  return 0
}

cmd_list() {
  local f
  while IFS= read -r f; do
    printf '%-32s %s\n' "$(doc_name "$f")" "$(read_doc_version "$f")"
  done < <(doc_files)
}

# ── entry point ────────────────────────────────────────────────────────────────
# help is answered before the directory is asserted. A command whose entire job
# is to explain itself cannot demand a correctly set up repository first - that
# refusal lands on exactly the person who ran --help to find out what to set up.
case ${1:---help} in
  -h|--help|help) usage; exit 0 ;;
esac

[[ -d "$WORKFLOWS_DIR" ]] || die "workflows directory not found: $WORKFLOWS_DIR"

case ${1:---help} in
  init)            shift; cmd_init "$@" ;;
  bump)            shift; cmd_bump "$@" ;;
  verify)          shift; cmd_verify "$@" ;;
  list)            shift; cmd_list "$@" ;;
  -h|--help|help)  usage ;;
  *)               usage >&2; die "unknown subcommand: $1" ;;
esac
