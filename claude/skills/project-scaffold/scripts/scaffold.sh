#!/usr/bin/env bash
#
# scaffold.sh - install the agent context layer into a project.
#
# Idempotent and non-destructive. Existing content is never modified, reordered
# or removed: a file that is already present only gains the sections it is
# missing. A file present but carrying none of the expected structure is left
# alone and reported, because guessing an insertion point is how hand-written
# work gets destroyed.
#
# scaffold-version: 1

set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
SKILL_DIR=$(cd -- "$SCRIPT_DIR/.." && pwd)
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

readonly TEMPLATE_DIR="$SKILL_DIR/references/templates"
readonly CONTEXT_FILES=(CLAUDE.md COMPASS.md BACKLOG.md ISSUES.md NAMING.md)
readonly VENDORED=(lib/common.sh log-issue.sh backlog.sh cache.sh)

APPLY=0
WITH_README=0
WITH_GITIGNORE=0
GIT_INIT=0
ASSUME_YES=0

usage() {
  cat <<'EOF'
scaffold.sh - install the agent context layer into a project

Usage:
  scaffold.sh [--project DIR] [options]

By default this is a DRY RUN: it prints the plan and writes nothing.
Add --apply to commit the plan.

Options:
  --apply            actually write the plan
  --with-readme      also create README.md if absent
  --with-gitignore   also create .gitignore if absent
  --git-init         run git init if the project is not already a repository
  --full             shorthand for --with-readme --with-gitignore --git-init
  --yes              skip the interview and take the flags as given
  --project DIR      project directory (default: .)
  --json             machine-readable plan / result on stdout
  --help

What it installs:
  CLAUDE.md COMPASS.md BACKLOG.md ISSUES.md NAMING.md
  .claude/settings.json
  .claude/scripts/   (log-issue.sh, backlog.sh, cache.sh, lib/common.sh)
  .claude/scaffold.json  (records the version these copies came from)

Existing files are APPENDED to, never deleted or overwritten.

Exit codes: 0 ok, 2 usage, 3 validation, 4 io
EOF
}

while (($#)); do
  case $1 in
    --project) PS_PROJECT="${2-}"; shift 2 ;;
    --json) PS_JSON=1; shift ;;
    --apply) APPLY=1; shift ;;
    --with-readme) WITH_README=1; shift ;;
    --with-gitignore) WITH_GITIGNORE=1; shift ;;
    --git-init) GIT_INIT=1; shift ;;
    --full) WITH_README=1; WITH_GITIGNORE=1; GIT_INIT=1; shift ;;
    --yes | -y) ASSUME_YES=1; shift ;;
    --help | -h) usage; exit "$PS_OK" ;;
    *) PS_JSON=0; ps_die "$PS_USAGE" "unknown_flag" "unknown flag: $1 (try --help)" ;;
  esac
done

project=$(ps_resolve_project "${PS_PROJECT:-.}")

# ---------------------------------------------------------------------------
# Section extraction.
#
# A template either carries explicit `<!-- scaffold:section=NAME -->` markers,
# or it does not - in which case its `## ` headings are the sections. CLAUDE.md
# is deliberately in the second group: it ships verbatim, with no markers added
# to text the user wrote.
# ---------------------------------------------------------------------------

template_for() { printf '%s/%s.tmpl' "$TEMPLATE_DIR" "$1"; }

uses_markers() { grep -q '^<!-- scaffold:section=' "$1"; }

# section_names <template> -> one name per line, in template order
section_names() {
  local tmpl="$1"
  if uses_markers "$tmpl"; then
    sed -n 's/^<!-- scaffold:section=\(.*\) -->$/\1/p' "$tmpl"
  else
    sed -n 's/^## \(.*\)$/\1/p' "$tmpl"
  fi
}

# section_present <file> <template> <name>
section_present() {
  local file="$1" tmpl="$2" name="$3"
  [[ -f $file ]] || return 1
  if uses_markers "$tmpl"; then
    grep -qF -- "<!-- scaffold:section=${name} -->" "$file"
  else
    grep -qxF -- "## ${name}" "$file"
  fi
}

# section_block <template> <name> -> the section's text, to stdout
section_block() {
  local tmpl="$1" name="$2" start
  if uses_markers "$tmpl"; then
    start="<!-- scaffold:section=${name} -->"
    awk -v s="$start" '
      $0 == s { inside = 1; print; next }
      inside && /^<!-- scaffold:section=/ { exit }
      inside { print }
    ' "$tmpl"
  else
    start="## ${name}"
    awk -v s="$start" '
      $0 == s { inside = 1; print; next }
      inside && /^## / { exit }
      inside { print }
    ' "$tmpl"
  fi
}

# ---------------------------------------------------------------------------
# Planning. Nothing here writes.
# ---------------------------------------------------------------------------

PLAN_FILES=()
PLAN_ACTIONS=()
PLAN_DETAIL=()

plan_add() {
  PLAN_FILES+=("$1")
  PLAN_ACTIONS+=("$2")
  PLAN_DETAIL+=("$3")
}

plan_context_file() {
  local name="$1"
  local target="$project/$name"
  local tmpl; tmpl=$(template_for "$name")

  [[ -r $tmpl ]] || ps_die "$PS_IO" "template_missing" "template not found: $tmpl"

  if [[ ! -e $target ]]; then
    plan_add "$name" create "absent"
    return 0
  fi

  local work; work=$(ps_strip_cr "$target")
  local -a missing=()
  local s
  while IFS= read -r s; do
    [[ -z $s ]] && continue
    if ! section_present "$work" "$tmpl" "$s"; then missing+=("$s"); fi
  done < <(section_names "$tmpl")

  local size; size=$(wc -c <"$target" | tr -d ' ')

  if ((${#missing[@]} == 0)); then
    plan_add "$name" skip "exists, ${size} bytes, all sections present"
    return 0
  fi

  # A non-empty file with none of the expected structure is not ours to edit.
  local total; total=$(section_names "$tmpl" | grep -c . || true)
  if ((size > 0 && ${#missing[@]} == total)); then
    plan_add "$name" refuse "exists, ${size} bytes, no recognisable sections - left untouched"
    return 0
  fi

  # Join explicitly: ${missing[*]} would join on IFS, which this script sets to
  # newline+tab, breaking the aligned plan table.
  local joined; joined=$(printf '%s, ' "${missing[@]}"); joined=${joined%, }
  plan_add "$name" append "exists, ${size} bytes, missing: ${joined}"
}

build_plan() {
  local f
  for f in "${CONTEXT_FILES[@]}"; do plan_context_file "$f"; done

  if [[ ! -e $project/.claude/settings.json ]]; then
    plan_add ".claude/settings.json" create "absent"
  else
    plan_add ".claude/settings.json" skip "exists"
  fi

  local v
  for v in "${VENDORED[@]}"; do
    local dst="$project/.claude/scripts/$v"
    if [[ ! -e $dst ]]; then
      plan_add ".claude/scripts/$v" create "absent"
    elif cmp -s "$SCRIPT_DIR/$v" "$dst"; then
      plan_add ".claude/scripts/$v" skip "up to date"
    else
      plan_add ".claude/scripts/$v" refresh "differs from skill version ${PS_TOOL_VERSION}"
    fi
  done

  if ((WITH_README)); then
    if [[ -e $project/README.md ]]; then plan_add "README.md" skip "exists"; else plan_add "README.md" create "absent"; fi
  fi
  if ((WITH_GITIGNORE)); then
    if [[ -e $project/.gitignore ]]; then plan_add ".gitignore" skip "exists"; else plan_add ".gitignore" create "absent"; fi
  fi
  if ((GIT_INIT)); then
    if [[ -d $project/.git ]]; then plan_add "git repository" skip "already initialised"; else plan_add "git repository" create "git init"; fi
  fi
}

print_plan() {
  local i
  if ((PS_JSON)); then
    printf '{"ok":true,"apply":%s,"project":%s,"plan":[' \
      "$( ((APPLY)) && printf 'true' || printf 'false')" "$(ps_json_string "$project")"
    for i in "${!PLAN_FILES[@]}"; do
      ((i > 0)) && printf ','
      printf '{"file":%s,"action":"%s","detail":%s}' \
        "$(ps_json_string "${PLAN_FILES[i]}")" "${PLAN_ACTIONS[i]}" "$(ps_json_string "${PLAN_DETAIL[i]}")"
    done
    printf ']}\n'
    return 0
  fi

  printf '\nplan for %s\n\n' "$project" >&2
  for i in "${!PLAN_FILES[@]}"; do
    printf '  %-28s %-8s %s\n' "${PLAN_FILES[i]}" "${PLAN_ACTIONS[i]}" "${PLAN_DETAIL[i]}" >&2
  done
  printf '\n' >&2
  printf 'Existing files are appended to. Nothing is deleted or overwritten.\n' >&2
  ((APPLY)) || printf 'Dry run - nothing written. Re-run with --apply to commit this plan.\n' >&2
  printf '\n' >&2
}

# ---------------------------------------------------------------------------
# The interview. Only ever reached on a terminal, and only without --yes.
# ---------------------------------------------------------------------------

interview() {
  cat >&2 <<EOF

project-scaffold - installing the agent context layer into:
  $project

Always installed (the context layer):
  CLAUDE.md     how an agent should behave here
  COMPASS.md    the map - pointers to everything else, capped at 100 lines
  BACKLOG.md    Now / Next / Later / Done, managed by backlog.sh
  ISSUES.md     append-only issue log, newest first, managed by log-issue.sh
  NAMING.md     naming conventions, inherited and project-specific
  .claude/      settings plus a versioned copy of the tools

Optional extras:
  README.md     e.g. a title, one-paragraph description, and setup steps
  .gitignore    e.g. .claude/cache/, *.lock, editor and OS noise
  git init      initialise a repository if this directory is not one yet

Existing files are APPENDED to - only the sections they are missing get added.
Nothing is deleted, overwritten, or reordered.

EOF
  local reply
  ps_prompt "Include README.md? [y/N]" reply
  [[ ${reply,,} == y* ]] && WITH_README=1
  ps_prompt "Include .gitignore? [y/N]" reply
  [[ ${reply,,} == y* ]] && WITH_GITIGNORE=1
  ps_prompt "Run git init if needed? [y/N]" reply
  [[ ${reply,,} == y* ]] && GIT_INIT=1
  return 0
}

# ---------------------------------------------------------------------------
# Applying.
# ---------------------------------------------------------------------------

apply_context_file() {
  local name="$1" action="$2"
  local target="$project/$name"
  local tmpl; tmpl=$(template_for "$name")

  case $action in
    create)
      local seeded; seeded=$(ps_tempfile)
      cat -- "$tmpl" >"$seeded"
      ps_atomic_install "$seeded" "$target"
      ;;
    append)
      local work; work=$(ps_strip_cr "$target")
      local out; out=$(ps_tempfile)
      cat -- "$work" >"$out"
      # Guarantee a clean seam even if the file lacked a trailing newline.
      if [[ -s $out ]] && ! ps_ends_with_newline "$out"; then printf '\n' >>"$out"; fi
      local s
      while IFS= read -r s; do
        [[ -z $s ]] && continue
        if ! section_present "$work" "$tmpl" "$s"; then
          printf '\n' >>"$out"
          section_block "$tmpl" "$s" >>"$out"
        fi
      done < <(section_names "$tmpl")
      ps_atomic_install "$out" "$target"
      ;;
    skip | refuse) : ;;
  esac
}

apply_plan() {
  mkdir -p "$project/.claude/scripts/lib"

  local i
  for i in "${!PLAN_FILES[@]}"; do
    local f="${PLAN_FILES[i]}" a="${PLAN_ACTIONS[i]}"
    case $f in
      CLAUDE.md | COMPASS.md | BACKLOG.md | ISSUES.md | NAMING.md)
        apply_context_file "$f" "$a" ;;
      .claude/settings.json)
        if [[ $a == create ]]; then
          local s; s=$(ps_tempfile)
          printf '{\n  "attribution": {\n    "commit": "",\n    "pr": ""\n  }\n}\n' >"$s"
          ps_atomic_install "$s" "$project/.claude/settings.json"
        fi ;;
      .claude/scripts/*)
        if [[ $a == create || $a == refresh ]]; then
          local rel="${f#.claude/scripts/}"
          local s; s=$(ps_tempfile)
          cat -- "$SCRIPT_DIR/$rel" >"$s"
          ps_atomic_install "$s" "$project/.claude/scripts/$rel"
          chmod +x "$project/.claude/scripts/$rel" 2>/dev/null || true
        fi ;;
      README.md)
        if [[ $a == create ]]; then
          local s; s=$(ps_tempfile)
          printf '# %s\n\n<one paragraph: what this is and who it is for>\n\n## Setup\n\n```sh\n<command>\n```\n\n## Layout\n\nSee [COMPASS.md](COMPASS.md).\n' \
            "$(basename -- "$project")" >"$s"
          ps_atomic_install "$s" "$project/README.md"
        fi ;;
      .gitignore)
        if [[ $a == create ]]; then
          local s; s=$(ps_tempfile)
          printf '# agent cache - derived, rebuildable, never authoritative\n.claude/cache/\n\n# lock files used by the scaffold tools\n.issues.lock\n.backlog.lock\n\n# editor and OS noise\n.DS_Store\n*.swp\n' >"$s"
          ps_atomic_install "$s" "$project/.gitignore"
        fi ;;
      "git repository")
        if [[ $a == create ]]; then
          git -C "$project" init -q || ps_die "$PS_IO" "git_init_failed" "git init failed in $project"
        fi ;;
    esac
  done

  # Record which skill version these vendored copies came from, so drift is
  # visible rather than guessed at.
  local meta; meta=$(ps_tempfile)
  printf '{\n  "schema": %d,\n  "tool_version": %d,\n  "scaffolded": %s\n}\n' \
    "$PS_SCHEMA_VERSION" "$PS_TOOL_VERSION" "$(ps_json_string "$(ps_now)")" >"$meta"
  ps_atomic_install "$meta" "$project/.claude/scaffold.json"
}

# ---------------------------------------------------------------------------

ps_scratch_init
[[ -w $project ]] || ps_die "$PS_IO" "dir_not_writable" "directory is not writable: $project"

if ((APPLY)) && ((ASSUME_YES == 0)) && ps_is_tty; then
  interview
fi

build_plan
print_plan

if ((APPLY)); then
  apply_plan
  if ((PS_JSON == 0)); then
    printf 'Applied. Log an issue with:\n  .claude/scripts/log-issue.sh --project %s --help\n\n' "$project" >&2
  fi
fi
