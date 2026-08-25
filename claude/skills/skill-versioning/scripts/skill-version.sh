#!/usr/bin/env bash
# skill-version.sh — owns skill versions and claude/skills/registry.json.
#
# The registry is generated, never hand-edited. Every subcommand that changes a
# version regenerates it in the same run, so the two can never drift apart
# inside a single commit.
#
#   skill-version.sh init                      stamp unversioned skills at 1.0.0
#   skill-version.sh bump <skill> --minor      bump one skill, regen registry
#   skill-version.sh verify                    publisher gate: versions present, registry fresh
#   skill-version.sh verify --structure        PR gate: versions present, registry untouched
#   skill-version.sh list                      print every skill and its version
#
# SKILL_VERSION_SKILLS_DIR overrides the skills directory (used by the tests).
set -euo pipefail

SELF=$(basename "$0")
HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
SKILLS_DIR=${SKILL_VERSION_SKILLS_DIR:-$(cd "$HERE/../../" && pwd)}
REGISTRY="$SKILLS_DIR/registry.json"

# Shared tools are not skills and do not live under the skills tree. Derived from
# the skills directory rather than from the repo root so it follows
# SKILL_VERSION_SKILLS_DIR, which is what makes it reachable from a test fixture.
TOOLS_DIR=$(dirname "$SKILLS_DIR")/tools

# The schema this generator writes. verify compares it against the number the
# registry on disk claims and refuses to go further when they differ.
SCHEMA=2

die() { printf '%s: %s\n' "$SELF" "$*" >&2; exit 1; }

usage() {
  cat <<EOF
USAGE
  $SELF init
  $SELF bump <skill> --major|--minor|--patch
  $SELF verify [--structure [--base <ref>]]
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

  verify   Two forms, for two different callers.

           Plain — the publisher's gate. Exit non-zero if any skill lacks a
           version, if a requires: names a skill that does not exist, if the
           registry is missing, if it was written to a different schema, or if
           it does not match what the skills on disk would produce. A stale
           registry means a skill changed without a bump.

           --structure — the PR gate. Exit non-zero if any skill lacks a
           version, if a requires: names a skill that does not exist, or if
           this branch's diff touches a version: line or registry.json. It
           says nothing about whether the registry matches the tree, because
           under merge-time allocation a skill PR legitimately edits a skill
           and leaves the registry alone.

             --base <ref>   what to diff against. Default: the first of
                            origin/main or main that resolves.

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

# Reads requires: from the leading --- fenced block, for the same reason
# read_version does: a requires: line in the body is prose and is ignored.
#
# Comma-separated, never a YAML list. Rule 17 makes Git Bash a supported platform
# and it has no YAML parser, so "requires: a, b" is one line of awk where
# "requires: [a, b]" is a dependency — decision 21.
#
# Emits one name per line in declared order. Absent means no dependencies, which
# is 41 of the 43 skills.
read_requires() {
  [[ -f "$1" ]] || return 0
  awk '
    NR == 1 && $0 == "---" { inside = 1; next }
    inside && $0 == "---"  { exit }
    inside && /^requires:[[:space:]]*/ {
      sub(/^requires:[[:space:]]*/, "")
      n = split($0, part, ",")
      for (i = 1; i <= n; i++) {
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", part[i])
        if (part[i] != "") print part[i]
      }
      exit
    }
  ' "$1"
}

# Names on stdin, one per line, out as a JSON array on one line. Entries are
# rendered one per line so verify can compare them line-wise, so nothing here may
# introduce a newline.
json_array() {
  local first=1 n out=""
  while IFS= read -r n; do
    [[ -n $n ]] || continue
    [[ $first -eq 1 ]] || out+=", "
    out+="\"$n\""
    first=0
  done
  printf '[%s]' "$out"
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

# ── tools ──────────────────────────────────────────────────────────────────────
# Shared infrastructure that is not a skill: the sync binary, and the read-only
# notice template that replaces the copy currently inlined in 43 SKILL.md files.
# A version and a hash here are the only thing that lets a change to either one
# reach an installed project at all.
#
#   claude/tools/skill-sync.sh                       WO-20260824-5b89
#   claude/tools/partials/read-only-notice.md.tmpl   WO-20260824-2136
TOOLS_REGISTERED=(
  "skill-sync:skill-sync.sh"
  "read-only-notice:partials/read-only-notice.md.tmpl"
)

# A tool is a shell script or a markdown template, so it has no frontmatter to
# read. The version is a marker token instead, which works under any comment
# syntax and cannot be confused with a version: in prose:
#
#   # skill-tool-version: 1.0.0             in a shell script
#   <!-- skill-tool-version: 1.0.0 -->      in a markdown template
#
# Read from the head of the file so it stays a header field rather than something
# that can hide at the bottom.
read_tool_version() {
  head -20 "$1" | awk '
    match($0, /skill-tool-version:[[:space:]]*[0-9]+\.[0-9]+\.[0-9]+/) {
      s = substr($0, RSTART, RLENGTH)
      sub(/^skill-tool-version:[[:space:]]*/, "", s)
      print s; exit
    }'
}

# An entry is rendered only for a registered tool that is on disk, so this block
# is empty until claude/tools/ is built. That is the intended output, not a stub.
#
# render_registry is a pure function of the tree and cannot hash a file nobody
# has written. A placeholder hash would be strictly worse than an absent entry:
# it would stay green after the real file landed, which is the one failure this
# registry exists to prevent. Building the tools first was not available either —
# WO-20260824-5b89 depends on the ticket that added this block, so skill-sync.sh
# cannot exist before the generator that hashes it.
#
# Both entries appear on their own as those files land. Neither needs an edit here.
render_tools() {
  local first=1 entry name rel path ver hash
  printf '  "tools": {'
  for entry in "${TOOLS_REGISTERED[@]}"; do
    name=${entry%%:*}
    rel=${entry#*:}
    path="$TOOLS_DIR/$rel"
    [[ -f $path ]] || continue
    ver=$(read_tool_version "$path")
    [[ -n $ver ]] || die "$rel has no skill-tool-version: marker in its first 20 lines"
    hash=$(sha256sum "$path" | cut -d' ' -f1)
    [[ $first -eq 1 ]] || printf ','
    printf '\n    "%s": { "version": "%s", "sha256": "%s" }' "$name" "$ver" "$hash"
    first=0
  done
  [[ $first -eq 1 ]] || printf '\n  '
  printf '}\n'
}

# ── registry ───────────────────────────────────────────────────────────────────
# Pure function of the skills on disk: same tree in, same bytes out. That is what
# lets verify be a plain diff instead of a parser.
#
# type is routing only — skill to .claude/skills/, agent to .claude/agents/ — and
# is a property of the tree an entry was found in, never something the entry
# declares. Decision 21 rejected declaring it: the filesystem already states the
# fact, and writing it down a second time creates a source of truth that can
# disagree with the first. This walks the skills tree and nothing else, so every
# entry it can produce is a skill. claude/agents/ carries no version and no
# registry row yet; when it gains one it gains a walk here that stamps "agent".
render_registry() {
  local first=1 d name ver hash reqs
  printf '{\n'
  printf '  "schema": %s,\n' "$SCHEMA"
  printf '  "generator": "skill-version.sh",\n'
  printf '  "skills": {\n'
  while IFS= read -r d; do
    name=$(basename "$d")
    ver=$(read_version "$d/SKILL.md")
    [[ -n $ver ]] || die "$name has no version — run '$SELF init' first"
    hash=$(hash_skill "$d")
    # Rendered even when empty. A fixed key set makes every entry the same shape,
    # so a consumer never branches on key presence and verify's drift line reads
    # the same whether or not the skill has dependencies.
    reqs=$(read_requires "$d/SKILL.md" | json_array)
    [[ $first -eq 1 ]] || printf ',\n'
    first=0
    printf '    "%s": { "version": "%s", "sha256": "%s", "type": "skill", "requires": %s }' \
      "$name" "$ver" "$hash" "$reqs"
  done < <(skill_dirs)
  [[ $first -eq 1 ]] || printf '\n'
  printf '  },\n'
  render_tools
  printf '}\n'
}

# The schema number the registry on disk claims. Read with a match rather than a
# parser for the same reason verify is a byte comparison: bash, grep, coreutils
# and awk, nothing else.
registry_schema() {
  awk '
    match($0, /"schema"[[:space:]]*:[[:space:]]*[0-9]+/) {
      s = substr($0, RSTART, RLENGTH)
      sub(/.*:[[:space:]]*/, "", s)
      print s; exit
    }' "$1"
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

# ── the diff half of verify --structure ────────────────────────────────────────
# Under merge-time allocation the version and the registry are written by CI on
# main, never by a contributor on a branch. So the assertion is not "the edit
# looks wrong" but "there is no edit at all": any version: line or registry.json
# in this branch's diff is a hand-edit by definition.
#
# This lives in --structure alone. Plain verify catches the same hand-edit a
# different way - the version sits inside SKILL.md, so touching it moves both
# the rendered version and the content hash, and the registry comparison fails.
# Plain verify also has to stay usable on the branch that legitimately carries a
# bump, which is every skill PR until merge-time allocation lands.
diff_check() {
  local base=$1 rc=0 mb changed f d
  git -C "$SKILLS_DIR" rev-parse --git-dir >/dev/null 2>&1 || {
    printf 'not a git repository: %s\n' "$SKILLS_DIR" >&2
    printf 'verify --structure diffs a branch; there is nothing here to diff\n' >&2
    return 1
  }

  if [[ -n $base ]]; then
    git -C "$SKILLS_DIR" rev-parse --verify -q "$base^{commit}" >/dev/null \
      || { printf 'no such ref: %s\n' "$base" >&2; return 1; }
  else
    for f in origin/main main; do
      if git -C "$SKILLS_DIR" rev-parse --verify -q "$f^{commit}" >/dev/null; then base=$f; break; fi
    done
    [[ -n $base ]] || {
      printf 'no base ref found (tried origin/main, main) — pass --base <ref>\n' >&2
      return 1
    }
  fi

  mb=$(git -C "$SKILLS_DIR" merge-base "$base" HEAD 2>/dev/null) || {
    printf 'no merge base between HEAD and %s\n' "$base" >&2
    return 1
  }

  # --relative keeps both the pathspec and the reported names anchored to the
  # skills directory, so this reads the same whether the skills live at the repo
  # root or under claude/. Omitting the second rev is deliberate: the comparison
  # runs against the working tree, so an uncommitted hand-edit is caught too.
  if [[ -n $(git -C "$SKILLS_DIR" diff --relative --name-only "$mb" -- registry.json) ]]; then
    printf 'registry.json edited in this diff\n' >&2
    rc=1
  fi

  while IFS= read -r f; do
    [[ $f == */SKILL.md ]] || continue
    # Captured before grepping rather than piped into it: grep -q closes the
    # pipe on its first match, git dies of SIGPIPE, and pipefail would report
    # that as "no match" - the check passing precisely when it should fail.
    d=$(git -C "$SKILLS_DIR" diff --relative -U0 "$mb" -- "$f")
    if grep -qE '^[+-]version:' <<< "$d"; then
      printf 'version: edited in this diff   %s\n' "$f" >&2
      rc=1
    fi
  done < <(git -C "$SKILLS_DIR" diff --relative --name-only "$mb" -- .)

  if [[ $rc -ne 0 ]]; then
    cat >&2 <<EOF

CI allocates the version at merge and writes the registry itself. A branch
carries the intent, not the number. Revert both and state the bump in the PR.

  git checkout $mb -- <path>
EOF
    return 1
  fi

  printf 'base: %s\n' "$base"
  return 0
}

cmd_verify() {
  local structure=0 base="" rc=0 d name total=0 expected req found
  local unversioned=0 unresolved=0

  while [[ $# -gt 0 ]]; do
    case $1 in
      --structure)    structure=1; shift ;;
      --base)         base=${2:-}; [[ -n $base ]] || die "--base needs a ref"; shift 2 ;;
      -h|--help)      usage; return 0 ;;
      *)              usage >&2; die "unknown option for verify: $1" ;;
    esac
  done
  [[ $structure -eq 1 || -z $base ]] || die "--base only applies to verify --structure"

  # Both forms run this loop, deliberately. A requires: naming a skill that does
  # not exist is a property of the tree rather than of the registry, and it is
  # the one dependency failure the auto-install path cannot recover from — left
  # uncaught it surfaces on some project's first sync, days later and somewhere
  # else. Catching it here is free, because verify already walks every skill.
  while IFS= read -r d; do
    name=$(basename "$d")
    total=$((total + 1))
    if [[ -z $(read_version "$d/SKILL.md") ]]; then
      printf 'unversioned   %s\n' "$name" >&2
      unversioned=1
      rc=1
    fi
    while IFS= read -r req; do
      [[ -f "$SKILLS_DIR/$req/SKILL.md" ]] && continue
      printf 'unresolved requires   %s -> %s (no such skill)\n' "$name" "$req" >&2
      unresolved=1
      rc=1
    done < <(read_requires "$d/SKILL.md")
  done < <(skill_dirs)

  if [[ $rc -ne 0 ]]; then
    [[ $unversioned -eq 0 ]] || printf "\nrun '%s init' to stamp them\n" "$SELF" >&2
    [[ $unresolved -eq 0 ]] || printf '\nfix the requires: line, or add the skill it names\n' >&2
    return 1
  fi

  if [[ $structure -eq 1 ]]; then
    diff_check "$base" || return 1
    printf 'ok — %d skills versioned, no version: or registry.json in the diff\n' "$total"
    return 0
  fi

  [[ -f "$REGISTRY" ]] || { printf 'registry missing: %s\n' "$REGISTRY" >&2; return 1; }

  # A schema mismatch is its own failure and not drift. Every entry in a newer
  # schema carries fields an older one does not, so comparing across the two
  # names every skill in the repository as drifted and explains none of them.
  # That output is worse than useless: it points 43 times at the wrong cause.
  found=$(registry_schema "$REGISTRY")
  if [[ $found != "$SCHEMA" ]]; then
    printf 'schema mismatch: registry is schema %s, this generator writes schema %s\n' \
      "${found:-<none>}" "$SCHEMA" >&2
    cat >&2 <<EOF

The registry was written by a different generator. Nothing is compared against
it, because a cross-schema comparison reports every skill as drifted and names
the wrong cause every time.

  $SELF init    rewrite the registry with this generator
EOF
    return 1
  fi

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
