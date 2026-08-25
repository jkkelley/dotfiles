#!/usr/bin/env bash
# setup.sh — install Claude agents and skills from this dotfiles repo
#
# Symlinks or copies selected agents and skills into a target .claude/ directory.
# Run with --help for full usage.
set -euo pipefail

DOTFILES="$(cd "$(dirname "$0")" && pwd)"
AGENTS_SRC="$DOTFILES/claude/agents"
SKILLS_SRC="$DOTFILES/claude/skills"

# Defaults — overridden by --dest at runtime
DEST_BASE="$HOME/.claude"
AGENTS_DST="$HOME/.claude/agents"
SKILLS_DST="$HOME/.claude/skills"

# ── skill-sync — machine level, never per-destination ──────────────────────────
# The SessionStart hook fires in *every* project on this machine, so it belongs
# in ~/.claude/settings.json even when --dest points at one project's .claude/.
# These four are deliberately not derived from DEST_BASE.
SKILL_SYNC_SRC="$DOTFILES/claude/tools/skill-sync.sh"
BIN_DST="$HOME/.local/bin"
SKILL_SYNC_DST="$BIN_DST/skill-sync"
SETTINGS_FILE="$HOME/.claude/settings.json"

# WO-20260824-0615 exercised all four SessionStart sources and wrote down which
# fired: matchers do filter, and alternation is honoured. `compact` is absent on
# purpose — a sync must never run in the middle of a session.
HOOK_MATCHER="startup|resume|clear"
HOOK_TIMEOUT=30

# $HOME is expanded by the shell the hook runs in, and the path is absolute
# because ~/.local/bin is not reliably on PATH in a non-interactive shell. The
# inner quotes matter on Windows, where $HOME routinely contains a space.
HOOK_COMMAND="\"\$HOME/.local/bin/skill-sync\" --boot"

# Set by the install-type prompt: "link" or "copy"
INSTALL_TYPE="link"

# ── colour helpers ─────────────────────────────────────────────────────────────
_red()    { printf '\033[0;31m%s\033[0m\n' "$*" >&2; }
_yellow() { printf '\033[0;33m%s\033[0m\n' "$*"; }
_green()  { printf '\033[0;32m%s\033[0m\n' "$*"; }
_bold()   { printf '\033[1m%s\033[0m\n' "$*"; }

# ── usage ──────────────────────────────────────────────────────────────────────
usage() {
  cat <<EOF
USAGE
  ./setup.sh [--dest <path>] [--help]

DESCRIPTION
  Installs Claude agents and/or skills from this dotfiles repo into a target
  .claude/ directory. Runs interactively — choose symlink or copy, pick what
  to install, and confirm before anything is written.

  It also installs skill-sync and the SessionStart hook that calls it, in that
  order. Both are machine level, not per-destination: the hook fires in every
  project on this machine, so it goes into ~/.claude/settings.json even when
  --dest points somewhere else. Running setup.sh twice replaces that hook rather
  than adding a second one.

OPTIONS
  --dest <path>   Exact directory to install into.
                  Agents are placed under <path>/agents/
                  Skills are placed under <path>/skills/
                  Default: ~/.claude/

                  Does not move skill-sync or its hook — see DESCRIPTION.

  --help, -h      Show this message and exit

SKILL SYNC  (always installed, after the confirmation prompt)
  Binary   ~/.local/bin/skill-sync — a copy, never a symlink, because it
           replaces itself in place when a newer version is published.

  Hook     SessionStart in ~/.claude/settings.json, matcher
           "startup|resume|clear", timeout 30. It runs skill-sync --boot,
           which is silent and exits 0 in a project with no
           .claude/skills.toml — which is most of them.

  Requires jq. Without it the binary is still installed, the hook is not, and
  setup.sh exits non-zero saying so.

INSTALL TYPES  (chosen at runtime)
  Symlink   Live link back to this repo. Changes here are reflected instantly.
            Best for personal machines where the dotfiles repo stays in place.

  Copy      Full copies of the files at the destination. Safe to commit into
            your project's own version control. No dependency on this repo.

SELECTION MODES  (chosen at runtime)
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

EXAMPLES
  ./setup.sh                                            # installs into ~/.claude/
  ./setup.sh --dest ~/projects/myapp/.claude            # installs into that project's .claude/
  ./setup.sh --dest ~/projects/myapp/.claude/skills     # skills only into that exact dir
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

# ── install item (symlink or copy) ─────────────────────────────────────────────
# _install_item SRC DST
#
# Backs up DST if it exists as a real file (not a symlink), then either
# symlinks or copies SRC to DST depending on INSTALL_TYPE.
_install_item() {
  local src="$1" dst="$2"
  if [[ -e "$dst" && ! -L "$dst" ]]; then
    _yellow "  Backing up: $dst → ${dst}.bak"
    mv "$dst" "${dst}.bak"
  fi
  if [[ "$INSTALL_TYPE" == "copy" ]]; then
    cp -r "$src" "$dst"
  else
    ln -sfn "$src" "$dst"
  fi
}

install_selections() {
  local -n _agents_sel="$1"
  local -n _skills_sel="$2"
  local verb; [[ "$INSTALL_TYPE" == "copy" ]] && verb="Copying" || verb="Linking"

  if [[ ${#_agents_sel[@]} -gt 0 ]]; then
    _bold "\n${verb} agents..."
    mkdir -p "$AGENTS_DST"
    for name in "${_agents_sel[@]}"; do
      _install_item "$AGENTS_SRC/${name}.md" "$AGENTS_DST/${name}.md"
      _green "  ✓ agent: $name"
    done
  fi

  if [[ ${#_skills_sel[@]} -gt 0 ]]; then
    _bold "\n${verb} skills..."
    mkdir -p "$SKILLS_DST"
    for name in "${_skills_sel[@]}"; do
      _install_item "$SKILLS_SRC/${name}" "$SKILLS_DST/${name}"
      _green "  ✓ skill: $name"
    done
  fi
}

# ── skill-sync: the binary first, then the hook that calls it ─────────────────
# The order is the whole point and is not cosmetic. A SessionStart hook fires in
# every project on this machine, so a hook written before the binary exists
# prints a command-not-found into every session until somebody removes it — and
# the error looks like Claude Code's rather than this script's. install_hook is
# therefore only ever reached when install_skill_sync returned 0.
#
# Always a copy, whatever INSTALL_TYPE says. skill-sync replaces itself in place
# when the registry publishes a newer version of it, so a symlink here would be
# swapped for a real file on the first self-update — silently turning a "live
# link to the repo" install into a stale copy nobody knows is stale.
install_skill_sync() {
  if [[ ! -f "$SKILL_SYNC_SRC" ]]; then
    _red "  ✗ skill-sync source not found: $SKILL_SYNC_SRC"
    return 1
  fi
  if ! mkdir -p "$BIN_DST"; then
    _red "  ✗ Could not create $BIN_DST"
    return 1
  fi
  if ! cp "$SKILL_SYNC_SRC" "$SKILL_SYNC_DST" || ! chmod +x "$SKILL_SYNC_DST"; then
    _red "  ✗ Could not install $SKILL_SYNC_DST"
    return 1
  fi
  _green "  ✓ tool: skill-sync → $SKILL_SYNC_DST"
}

# jq is the only safe way to edit settings.json. A sed into JSON is how every
# project on the machine loses its settings at once, so a missing jq means the
# hook is not written rather than written badly.
install_session_hook() {
  if ! command -v jq >/dev/null 2>&1; then
    _red "  ✗ jq not found — the SessionStart hook was NOT installed."
    _yellow "    settings.json is JSON, and jq is the only safe way to edit it."
    _yellow "    Install jq and re-run ./setup.sh."
    return 1
  fi

  if ! mkdir -p "$(dirname "$SETTINGS_FILE")"; then
    _red "  ✗ Could not create $(dirname "$SETTINGS_FILE")"
    return 1
  fi
  [[ -f "$SETTINGS_FILE" ]] || printf '{}\n' > "$SETTINGS_FILE"

  if ! jq -e . "$SETTINGS_FILE" >/dev/null 2>&1; then
    _red "  ✗ $SETTINGS_FILE is not valid JSON — refusing to touch it."
    _yellow "    Fix or move the file, then re-run ./setup.sh."
    return 1
  fi

  # jq reading and writing the same file truncates it, so this writes beside it
  # and moves. Every existing skill-sync entry is dropped before the new one is
  # appended: that is what makes a second run replace rather than duplicate, and
  # it is also how a changed matcher or timeout lands instead of accumulating
  # beside the old one.
  local tmp="${SETTINGS_FILE}.setup.$$"
  if ! jq \
        --arg cmd "$HOOK_COMMAND" \
        --arg matcher "$HOOK_MATCHER" \
        --argjson timeout "$HOOK_TIMEOUT" '
          .hooks //= {}
        | .hooks.SessionStart //= []
        | .hooks.SessionStart |= map(
            select(any(.hooks[]?; ((.command? // "") | tostring | contains("skill-sync"))) | not))
        | .hooks.SessionStart += [{
            matcher: $matcher,
            hooks: [{ type: "command", command: $cmd, timeout: $timeout }]
          }]
        ' "$SETTINGS_FILE" > "$tmp"; then
    rm -f "$tmp"
    _red "  ✗ Could not write the SessionStart hook into $SETTINGS_FILE"
    return 1
  fi
  if ! mv "$tmp" "$SETTINGS_FILE"; then
    rm -f "$tmp"
    _red "  ✗ Could not replace $SETTINGS_FILE"
    return 1
  fi
  _green "  ✓ hook: SessionStart (${HOOK_MATCHER}) → $SETTINGS_FILE"
}

# Returns 1 if either half failed. The caller reports it rather than swallowing
# it: "Done." printed over a hook that was never written is the failure this
# whole ticket exists to avoid.
install_skill_sync_and_hook() {
  _bold "\nInstalling skill-sync..."
  if ! install_skill_sync; then
    _yellow "  ⚠ The SessionStart hook was NOT written: the binary it calls is missing."
    return 1
  fi
  install_session_hook
}

# ── main ───────────────────────────────────────────────────────────────────────
main() {
  # ── parse args ──
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --help|-h)
        usage; exit 0 ;;
      --dest)
        if [[ -z "${2:-}" ]]; then
          _red "--dest requires a path argument."
          _yellow "Hint: ./setup.sh --dest ~/projects/myapp/.claude"
          exit 1
        fi
        DEST_BASE="${2%/}"       # strip trailing slash
        AGENTS_DST="$DEST_BASE/agents"
        SKILLS_DST="$DEST_BASE/skills"
        shift 2 ;;
      --dest=*)
        DEST_BASE="${1#--dest=}"
        DEST_BASE="${DEST_BASE%/}"   # strip trailing slash
        AGENTS_DST="$DEST_BASE/agents"
        SKILLS_DST="$DEST_BASE/skills"
        shift ;;
      *)
        _red "Unknown option: '$1'"
        _yellow "Hint: run './setup.sh --help' for usage."
        exit 1 ;;
    esac
  done

  discover_agents
  discover_skills

  _bold "\nClaude Dotfiles Setup"
  echo "────────────────────────────────────────────────────────────"
  printf "  Repo             : %s\n" "$DOTFILES"
  printf "  Destination      : %s/\n" "$DEST_BASE"
  printf "  Agents available : %d  (%s)\n" "${#AVAIL_AGENTS[@]}" "${AVAIL_AGENTS[*]}"
  printf "  Skills available : %d  (%s)\n" "${#AVAIL_SKILLS[@]}" "${AVAIL_SKILLS[*]}"
  echo "────────────────────────────────────────────────────────────"
  echo

  # ── install type ──
  echo "Install type:"
  echo "  [1] Symlink — live link to this repo (changes here reflect instantly)"
  echo "  [2] Copy    — full copy of files, safe to commit to version control"
  printf "\nChoice [1/2]: "
  read -r type_choice
  case "$type_choice" in
    1) INSTALL_TYPE="link" ;;
    2) INSTALL_TYPE="copy" ;;
    *)
      _red "Invalid choice: '$type_choice'"
      _yellow "Hint: enter 1 for symlink or 2 for copy."
      exit 1 ;;
  esac
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

  # An empty selection used to mean "exit without changes". It no longer can:
  # skill-sync and its hook are installed on every run, so exiting here would
  # skip them, and there is a real reason to want exactly that run - installing
  # the hook on a machine whose agents and skills are already in place. The
  # summary below lists what is about to happen either way, and the confirmation
  # prompt is still the only thing that lets anything be written.
  if [[ ${#SEL_AGENTS[@]} -eq 0 && ${#SEL_SKILLS[@]} -eq 0 ]]; then
    _yellow "\nNo agents or skills selected — skill-sync and its hook only."
  fi

  echo
  local action; [[ "$INSTALL_TYPE" == "copy" ]] && action="Copy" || action="Symlink"
  _bold "Ready to ${action,,}:"
  [[ ${#SEL_AGENTS[@]} -gt 0 ]] && printf "  Agents → %s/agents/\n" "$DEST_BASE"
  [[ ${#SEL_AGENTS[@]} -gt 0 ]] && printf "           %s\n" "${SEL_AGENTS[*]}"
  [[ ${#SEL_SKILLS[@]} -gt 0 ]] && printf "  Skills → %s/skills/\n" "$DEST_BASE"
  [[ ${#SEL_SKILLS[@]} -gt 0 ]] && printf "           %s\n" "${SEL_SKILLS[*]}"
  printf "  Tool   → %s\n" "$SKILL_SYNC_DST"
  printf "  Hook   → SessionStart in %s\n" "$SETTINGS_FILE"
  echo
  printf "Proceed? [y/N]: "
  read -r confirm
  if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    _yellow "Aborted. No changes made."
    exit 0
  fi

  install_selections SEL_AGENTS SEL_SKILLS

  local sync_ok=0
  install_skill_sync_and_hook || sync_ok=1

  echo
  if (( sync_ok )); then
    _red "Finished with errors — skill-sync is not fully installed. See above."
    _yellow "Agents and skills were installed into ${DEST_BASE}/"
    exit 1
  fi
  _bold "Done. Items installed into ${DEST_BASE}/"
}

main "$@"
