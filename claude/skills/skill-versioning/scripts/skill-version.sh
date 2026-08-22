#!/usr/bin/env bash
# skill-version.sh — owns skill versions and claude/skills/registry.json.
#
# The registry is generated, never hand-edited. Every subcommand that changes a
# version regenerates it in the same run, so the two can never drift apart
# inside a single commit.
#
#   skill-version.sh init                      stamp unversioned skills at 1.0.0
#   skill-version.sh bump <skill> --minor      bump one skill, regen registry
#   skill-version.sh verify                    CI gate: versions present, registry fresh
#   skill-version.sh list                      print every skill and its version
#
# SKILL_VERSION_SKILLS_DIR overrides the skills directory (used by the tests).
set -euo pipefail

SELF=$(basename "$0")
HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
SKILLS_DIR=${SKILL_VERSION_SKILLS_DIR:-$(cd "$HERE/../../" && pwd)}
REGISTRY="$SKILLS_DIR/registry.json"

die() { printf '%s: %s\n' "$SELF" "$*" >&2; exit 1; }

usage() {
  cat <<EOF
USAGE
  $SELF init
  $SELF bump <skill> --major|--minor|--patch
  $SELF verify
  $SELF list
  $SELF --help

SUBCOMMANDS
  init     Stamp every skill that has no version: line at 1.0.0, then write the
           registry. Safe to re-run — already-versioned skills are left alone.

  bump     Raise one skill's version and regenerate the registry. This is the
           only supported way to change a version. Never hand-edit the field.

             --major   a consumer's existing usage breaks
             --minor   new capability, backward compatible
             --patch   wording, script bugfix, doc clarification, tests

  verify   Exit non-zero if any skill lacks a version, if the registry is
           missing, or if the registry does not match what the skills on disk
           would produce. A stale registry means a skill changed without a bump.

  list     Print each skill and its current version.

FILES
  $SKILLS_DIR
  $REGISTRY
EOF
}

# ── skill discovery ────────────────────────────────────────────────────────────
# Deterministic order. Only directories holding a SKILL.md count as skills.
skill_dirs() {
  find "$SKILLS_DIR" -mindepth 1 -maxdepth 1 -type d | LC_ALL=C sort | while IFS= read -r d; do
    [[ -f "$d/SKILL.md" ]] && printf '%s\n' "$d"
  done
  return 0
}

# ── frontmatter ────────────────────────────────────────────────────────────────
# Reads version: from the leading --- fenced block only. A version: line in the
# body is prose, not metadata, and is ignored.
read_version() {
  [[ -f "$1" ]] || return 0
  awk '
    NR == 1 && $0 == "---" { inside = 1; next }
    inside && $0 == "---"  { exit }
    inside && /^version:[[:space:]]*/ { sub(/^version:[[:space:]]*/, ""); print; exit }
  ' "$1"
}

# Replaces the version: line in place, or appends it as the last frontmatter key.
write_version() {
  local file=$1 ver=$2 tmp
  head -1 "$file" | grep -qx -- '---' || die "no frontmatter in $file"
  tmp=$(mktemp)
  awk -v ver="$ver" '
    NR == 1 && $0 == "---" { print; inside = 1; next }
    inside && /^version:[[:space:]]*/ { print "version: " ver; done = 1; next }
    inside && $0 == "---" { if (!done) print "version: " ver; done = 1; inside = 0; print; next }
    { print }
  ' "$file" > "$tmp"
  cat "$tmp" > "$file"
  rm -f "$tmp"
}

# ── content hash ───────────────────────────────────────────────────────────────
# Covers every file in the skill plus its relative path, so a rename or a
# deletion moves the hash just like an edit does. The version line is inside
# SKILL.md, so this must always be computed after write_version.
hash_skill() {
  (
    cd "$1" || exit 1
    find . -type f | LC_ALL=C sort | while IFS= read -r f; do
      printf '%s\n' "$f"
      sha256sum "$f" | cut -d' ' -f1
    done
  ) | sha256sum | cut -d' ' -f1
}

# ── registry ───────────────────────────────────────────────────────────────────
# Pure function of the skills on disk: same tree in, same bytes out. That is what
# lets verify be a plain diff instead of a parser.
render_registry() {
  local first=1 d name ver hash
  printf '{\n'
  printf '  "schema": 1,\n'
  printf '  "generator": "skill-version.sh",\n'
  printf '  "skills": {\n'
  while IFS= read -r d; do
    name=$(basename "$d")
    ver=$(read_version "$d/SKILL.md")
    [[ -n $ver ]] || die "$name has no version — run '$SELF init' first"
    hash=$(hash_skill "$d")
    [[ $first -eq 1 ]] || printf ',\n'
    first=0
    printf '    "%s": { "version": "%s", "sha256": "%s" }' "$name" "$ver" "$hash"
  done < <(skill_dirs)
  [[ $first -eq 1 ]] || printf '\n'
  printf '  }\n'
  printf '}\n'
}

# ── subcommands ────────────────────────────────────────────────────────────────
cmd_init() {
  local stamped=0 d name
  while IFS= read -r d; do
    name=$(basename "$d")
    if [[ -z $(read_version "$d/SKILL.md") ]]; then
      write_version "$d/SKILL.md" "1.0.0"
      printf 'stamped   %s  1.0.0\n' "$name"
      stamped=$((stamped + 1))
    fi
  done < <(skill_dirs)
  render_registry > "$REGISTRY"
  printf '\n%d skill(s) stamped, registry written: %s\n' "$stamped" "$REGISTRY"
}

cmd_bump() {
  local name=${1:-} level=${2:-} dir cur new ma mi pa
  [[ -n $name && -n $level ]] || die "usage: $SELF bump <skill> --major|--minor|--patch"
  dir="$SKILLS_DIR/$name"
  [[ -f "$dir/SKILL.md" ]] || die "no such skill: $name"

  cur=$(read_version "$dir/SKILL.md")
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
  write_version "$dir/SKILL.md" "$new"
  render_registry > "$REGISTRY"
  printf '%s  %s -> %s\n' "$name" "$cur" "$new"
}

cmd_verify() {
  local rc=0 d name total=0 expected
  while IFS= read -r d; do
    name=$(basename "$d")
    total=$((total + 1))
    if [[ -z $(read_version "$d/SKILL.md") ]]; then
      printf 'unversioned   %s\n' "$name" >&2
      rc=1
    fi
  done < <(skill_dirs)

  if [[ $rc -ne 0 ]]; then
    printf "\nrun '%s init' to stamp them\n" "$SELF" >&2
    return 1
  fi

  [[ -f "$REGISTRY" ]] || { printf 'registry missing: %s\n' "$REGISTRY" >&2; return 1; }

  expected=$(render_registry)
  if [[ $expected == "$(cat "$REGISTRY")" ]]; then
    printf 'ok — %d skills versioned, registry in sync\n' "$total"
    return 0
  fi

  # Named drift beats a raw diff here: the answer the reader wants is which
  # skill to bump, not which byte moved. Compared line-wise rather than shelled
  # out to diff so the only dependencies stay bash, grep and coreutils.
  local line name actual_line
  while IFS= read -r line; do
    [[ $line == '    "'* ]] || continue
    name=${line#*\"}; name=${name%%\"*}
    actual_line=$(grep -m1 "^    \"$name\":" "$REGISTRY" || true)
    if [[ -z $actual_line ]]; then
      printf 'not in registry   %s\n' "$name" >&2
    elif [[ ${actual_line%,} != "${line%,}" ]]; then
      printf 'drifted           %s\n    registry: %s\n    on disk:  %s\n' \
        "$name" "${actual_line#*: }" "${line#*: }" >&2
    fi
  done <<< "$expected"

  while IFS= read -r line; do
    [[ $line == '    "'* ]] || continue
    name=${line#*\"}; name=${name%%\"*}
    [[ -d "$SKILLS_DIR/$name" ]] || printf 'stale entry       %s (no such skill)\n' "$name" >&2
  done < "$REGISTRY"

  cat >&2 <<EOF

registry is stale. A skill's contents changed without a version bump, or the
registry was hand-edited. Fix it with:

  $SELF bump <skill> --patch    # or --minor / --major
EOF
  return 1
}

cmd_list() {
  local d
  while IFS= read -r d; do
    printf '%-28s %s\n' "$(basename "$d")" "$(read_version "$d/SKILL.md")"
  done < <(skill_dirs)
}

# ── entry point ────────────────────────────────────────────────────────────────
[[ -d "$SKILLS_DIR" ]] || die "skills directory not found: $SKILLS_DIR"

case ${1:---help} in
  init)            shift; cmd_init "$@" ;;
  bump)            shift; cmd_bump "$@" ;;
  verify)          shift; cmd_verify "$@" ;;
  list)            shift; cmd_list "$@" ;;
  -h|--help|help)  usage ;;
  *)               usage >&2; die "unknown subcommand: $1" ;;
esac
