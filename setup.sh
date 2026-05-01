#!/usr/bin/env bash
# setup.sh — install Claude agents and skills from this dotfiles repo
#
# Symlinks selected agents and skills into ~/.claude/
# Run with --help for full usage.
set -euo pipefail

DOTFILES="$(cd "$(dirname "$0")" && pwd)"
AGENTS_SRC="$DOTFILES/claude/agents"
SKILLS_SRC="$DOTFILES/claude/skills"
AGENTS_DST="$HOME/.claude/agents"
SKILLS_DST="$HOME/.claude/skills"

# ── colour helpers ─────────────────────────────────────────────────────────────
_red()    { printf '\033[0;31m%s\033[0m\n' "$*" >&2; }
_yellow() { printf '\033[0;33m%s\033[0m\n' "$*"; }
_green()  { printf '\033[0;32m%s\033[0m\n' "$*"; }
_bold()   { printf '\033[1m%s\033[0m\n' "$*"; }

# ── usage ──────────────────────────────────────────────────────────────────────
usage() {
  cat <<EOF
USAGE
  ./setup.sh [--help]

DESCRIPTION
  Symlinks Claude agents and/or skills from this dotfiles repo into ~/.claude/.
  Runs interactively — no arguments required.

MODES  (chosen at runtime)
  1  Full suite   Install every agent and skill found in the repo
  2  From file    Read an install.conf specifying which to install
  3  Manual       Type names or drop a file path at each prompt

CONFIG FILE FORMAT  (used by mode 2)
  agents=api-designer argocd-gitops solutions-architect
  skills=container-sandbox context-compaction

  • Lines beginning with # are ignored
  • Either key may be omitted to skip that category

MANUAL MODE  (mode 3)
  At each prompt you can do one of three things:

  a) Type names directly (space-separated, no .md extension):
       → api-designer argocd-gitops solutions-architect

  b) Drop a file path containing a flat list of names:
       → /home/you/my-agents.txt

  c) Press Enter to skip that category entirely

FLAT LIST FILE FORMAT  (used when dropping a file path in mode 3)
  One name per line, or multiple names space-separated on a line.
  Lines beginning with # are ignored.

  Example agents.txt:
    # core agents
    api-designer
    argocd-gitops solutions-architect

OPTIONS
  --help, -h    Show this message and exit
EOF
}

# ── discovery ──────────────────────────────────────────────────────────────────
# Populates global arrays AVAIL_AGENTS and AVAIL_SKILLS by reading the repo.
discover_agents() {
  AVAIL_AGENTS=()
  [[ -d "$AGENTS_SRC" ]] || { _red "Agents directory not found: $AGENTS_SRC"; exit 1; }
  for f in "$AGENTS_SRC"/*.md; do
    [[ -f "$f" ]] || continue
    AVAIL_AGENTS+=("$(basename "$f" .md)")
  done
}

discover_skills() {
  AVAIL_SKILLS=()
  [[ -d "$SKILLS_SRC" ]] || { _red "Skills directory not found: $SKILLS_SRC"; exit 1; }
  for d in "$SKILLS_SRC"/*/; do
    [[ -d "$d" && -f "${d}SKILL.md" ]] || continue
    AVAIL_SKILLS+=("$(basename "$d")")
  done
}

# ── validation ─────────────────────────────────────────────────────────────────
# validate_names CATEGORY AVAIL_NAMEREF REQUESTED_NAMEREF OUT_NAMEREF
#
# Checks each name in REQUESTED against AVAIL. Unknown names print a red error
# and a yellow hint. Valid names are collected into OUT.
# Returns 1 if any invalid names were found (script uses || true to continue).
validate_names() {
  local category="$1"
  local -n _avail="$2"
  local -n _requested="$3"
  local -n _out="$4"
  _out=()
  local had_error=0

  for name in "${_requested[@]+"${_requested[@]}"}"; do
    local found=0
    for known in "${_avail[@]+"${_avail[@]}"}"; do
      [[ "$known" == "$name" ]] && found=1 && break
    done

    if (( found )); then
      _out+=("$name")
    else
      _red "  ✗ Unknown ${category}: '${name}'"
      local hints=()
      for known in "${_avail[@]+"${_avail[@]}"}"; do
        [[ "$known" == *"$name"* || "$name" == *"$known"* ]] && hints+=("$known")
      done
      if [[ ${#hints[@]} -gt 0 ]]; then
        _yellow "    Hint: did you mean one of: ${hints[*]}"
      else
        _yellow "    Hint: available ${category}s → ${_avail[*]}"
      fi
      had_error=1
    fi
  done

  return $had_error
}

# ── flat list file reader ──────────────────────────────────────────────────────
# read_flat_file FILE OUT_NAMEREF
#
# Reads a file containing names (one per line or space-separated on a line).
# Lines beginning with # are ignored. Populates OUT with the parsed names.
read_flat_file() {
  local file="$1"
  local -n _dest="$2"
  _dest=()

  if [[ ! -f "$file" ]]; then
    _red "File not found: '$file'"
    _yellow "Hint: provide a path to a flat list file (one name per line)."
    return 1
  fi

  local -a words
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%%#*}"                  # strip inline comments
    line="${line#"${line%%[^ ]*}"}"     # ltrim
    line="${line%"${line##*[^ ]}"}"     # rtrim
    [[ -z "$line" ]] && continue
    read -ra words <<< "$line"
    _dest+=("${words[@]+"${words[@]}"}")
  done < "$file"

  if [[ ${#_dest[@]} -eq 0 ]]; then
    _red "No names found in: '$file'"
    _yellow "Hint: file should contain names like 'api-designer', one per line."
    return 1
  fi
}

# ── resolve input — names or file path ────────────────────────────────────────
# resolve_input INPUT OUT_NAMEREF
#
# If INPUT is a single token resolving to an existing file, reads it as a flat
# list. Otherwise splits INPUT as space-separated names. Populates OUT.
resolve_input() {
  local input="$1"
  local -n _out="$2"
  _out=()
  [[ -z "$input" ]] && return 0

  # Single token that is a real file → read as flat list
  if [[ "$input" != *" "* && -f "$input" ]]; then
    read_flat_file "$input" _out || return 1
  else
    read -ra _out <<< "$input"
  fi
}

# ── config file parser ─────────────────────────────────────────────────────────
# Populates global arrays FILE_AGENTS and FILE_SKILLS.
parse_config() {
  local file="$1"
  FILE_AGENTS=()
  FILE_SKILLS=()

  if [[ ! -f "$file" ]]; then
    _red "File not found: '$file'"
    _yellow "Hint: provide the path to a plain-text config file."
    _yellow "      Example:"
    _yellow "        agents=api-designer argocd-gitops"
    _yellow "        skills=container-sandbox"
    return 1
  fi

  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%%#*}"                             # strip inline comments
    line="${line#"${line%%[^ ]*}"}"                # ltrim spaces
    line="${line%"${line##*[^ ]}"}"                # rtrim spaces
    [[ -z "$line" ]] && continue

    if [[ "$line" == agents=* ]]; then
      read -ra FILE_AGENTS <<< "${line#agents=}"
    elif [[ "$line" == skills=* ]]; then
      read -ra FILE_SKILLS <<< "${line#skills=}"
    else
      _yellow "  Warning: ignoring unrecognised line → '$line'"
    fi
  done < "$file"

  if [[ ${#FILE_AGENTS[@]} -eq 0 && ${#FILE_SKILLS[@]} -eq 0 ]]; then
    _red "Config file parsed but contained no agents or skills."
    _yellow "Hint: ensure the file has 'agents=...' or 'skills=...' lines."
    return 1
  fi
}

# ── linking ────────────────────────────────────────────────────────────────────
_link() {
  local src="$1" dst="$2"
  if [[ -e "$dst" && ! -L "$dst" ]]; then
    _yellow "  Backing up: $dst → ${dst}.bak"
    mv "$dst" "${dst}.bak"
  fi
  ln -sfn "$src" "$dst"
}

install_selections() {
  local -n _agents_sel="$1"
  local -n _skills_sel="$2"

  if [[ ${#_agents_sel[@]} -gt 0 ]]; then
    _bold "\nLinking agents..."
    mkdir -p "$AGENTS_DST"
    for name in "${_agents_sel[@]}"; do
      _link "$AGENTS_SRC/${name}.md" "$AGENTS_DST/${name}.md"
      _green "  ✓ agent: $name"
    done
  fi

  if [[ ${#_skills_sel[@]} -gt 0 ]]; then
    _bold "\nLinking skills..."
    mkdir -p "$SKILLS_DST"
    for name in "${_skills_sel[@]}"; do
      _link "$SKILLS_SRC/${name}" "$SKILLS_DST/${name}"
      _green "  ✓ skill: $name"
    done
  fi
}

# ── main ───────────────────────────────────────────────────────────────────────
main() {
  case "${1:-}" in
    --help|-h) usage; exit 0 ;;
    "")        ;;
    *)
      _red "Unknown option: '$1'"
      _yellow "Hint: run './setup.sh --help' for usage."
      exit 1
      ;;
  esac

  discover_agents
  discover_skills

  _bold "\nClaude Dotfiles Setup"
  echo "────────────────────────────────────────────────────────────"
  printf "  Repo             : %s\n" "$DOTFILES"
  printf "  Agents available : %d  (%s)\n" "${#AVAIL_AGENTS[@]}" "${AVAIL_AGENTS[*]}"
  printf "  Skills available : %d  (%s)\n" "${#AVAIL_SKILLS[@]}" "${AVAIL_SKILLS[*]}"
  echo "────────────────────────────────────────────────────────────"
  echo

  echo "Installation mode:"
  printf "  [1] Full suite — all %d agents + %d skills\n" "${#AVAIL_AGENTS[@]}" "${#AVAIL_SKILLS[@]}"
  echo "  [2] From a config file"
  echo "  [3] Type names manually"
  printf "\nChoice [1/2/3]: "
  read -r choice

  SEL_AGENTS=()
  SEL_SKILLS=()
  TYPED_AGENTS=()
  TYPED_SKILLS=()

  case "$choice" in
    1)
      SEL_AGENTS=("${AVAIL_AGENTS[@]}")
      SEL_SKILLS=("${AVAIL_SKILLS[@]}")
      ;;

    2)
      printf "Path to config file: "
      read -r config_path
      parse_config "$config_path" || exit 1
      validate_names "agent" AVAIL_AGENTS FILE_AGENTS SEL_AGENTS   || true
      validate_names "skill" AVAIL_SKILLS FILE_SKILLS SEL_SKILLS   || true
      ;;

    3)
      echo
      printf "  Agents — type names (space-separated, no .md), drop a file path, or Enter to skip:\n"
      printf "  → "
      read -r agent_input
      echo
      printf "  Skills — type names, drop a file path, or Enter to skip:\n"
      printf "  → "
      read -r skill_input

      resolve_input "$agent_input" TYPED_AGENTS || exit 1
      resolve_input "$skill_input" TYPED_SKILLS || exit 1

      validate_names "agent" AVAIL_AGENTS TYPED_AGENTS SEL_AGENTS  || true
      validate_names "skill" AVAIL_SKILLS TYPED_SKILLS SEL_SKILLS  || true
      ;;

    *)
      _red "Invalid choice: '$choice'"
      _yellow "Hint: enter 1, 2, or 3."
      exit 1
      ;;
  esac

  if [[ ${#SEL_AGENTS[@]} -eq 0 && ${#SEL_SKILLS[@]} -eq 0 ]]; then
    _yellow "\nNothing valid to install. Exiting without changes."
    exit 0
  fi

  echo
  _bold "Ready to link:"
  [[ ${#SEL_AGENTS[@]} -gt 0 ]] && printf "  Agents : %s\n" "${SEL_AGENTS[*]}"
  [[ ${#SEL_SKILLS[@]} -gt 0 ]] && printf "  Skills : %s\n" "${SEL_SKILLS[*]}"
  echo
  printf "Proceed? [y/N]: "
  read -r confirm
  if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    _yellow "Aborted. No changes made."
    exit 0
  fi

  install_selections SEL_AGENTS SEL_SKILLS

  echo
  _bold "Done. Items linked into ~/.claude/"
}

main "$@"
