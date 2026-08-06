#!/usr/bin/env bash
#
# log-issue.sh - append an entry to a project's ISSUES.md.
#
# ISSUES.md is append-only. Nothing already written is ever modified: a fix for
# an earlier issue is a NEW entry carrying `resolves: <ID>`, so an agent reading
# top-down meets the resolution before the problem it closed.
#
# scaffold-version: 1

set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
SKILL_DIR=$(cd -- "$SCRIPT_DIR/.." && pwd)
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

readonly SENTINEL='<!-- ISSUES:BEGIN'
readonly TEMPLATE="$SKILL_DIR/references/templates/ISSUES.md.tmpl"

usage() {
  cat <<'EOF'
log-issue.sh - append an entry to ISSUES.md (append-only, newest first)

Usage:
  log-issue.sh [--project DIR] --title T --severity S --area A \
               --symptom T --trigger T --cause T --fix T --verify T \
               [--tags a,b] [--refs BK-014] [--resolves ISS-0041] [--json]

Required:
  --title      one-line summary of what happened
  --severity   low | medium | high
  --area       the part of the project it touches
  --symptom    what was observed
  --trigger    what makes it happen
  --cause      why it happens
  --fix        what was changed (or "pending")
  --verify     how it was confirmed (or "none yet")

Optional:
  --tags       comma-separated labels
  --refs       related IDs, comma-separated
  --resolves   an earlier ISS-NNNN this entry closes (must exist)
  --project    project directory (default: .)
  --json       emit one JSON object on stdout instead of the bare ID
  --lock-timeout SECONDS   how long to wait for a concurrent writer (default 10)
  --help       this text

With no flags on a terminal, the fields are collected interactively.
Without a terminal, a missing required field is an error - never a prompt.

Exit codes: 0 ok, 2 usage, 3 validation, 4 io, 5 lock timeout, 6 id not found
EOF
}

title=""; severity=""; area=""
symptom=""; trigger=""; cause=""; fix=""; verify=""
tags=""; refs=""; resolves=""

while (($#)); do
  case $1 in
    --project) PS_PROJECT="${2-}"; shift 2 ;;
    --json) PS_JSON=1; shift ;;
    --lock-timeout) PS_LOCK_TIMEOUT="${2-}"; shift 2 ;;
    --title) title="${2-}"; shift 2 ;;
    --severity) severity="${2-}"; shift 2 ;;
    --area) area="${2-}"; shift 2 ;;
    --symptom) symptom="${2-}"; shift 2 ;;
    --trigger) trigger="${2-}"; shift 2 ;;
    --cause) cause="${2-}"; shift 2 ;;
    --fix) fix="${2-}"; shift 2 ;;
    --verify) verify="${2-}"; shift 2 ;;
    --tags) tags="${2-}"; shift 2 ;;
    --refs) refs="${2-}"; shift 2 ;;
    --resolves) resolves="${2-}"; shift 2 ;;
    --help | -h) usage; exit "$PS_OK" ;;
    *) PS_JSON=0; ps_die "$PS_USAGE" "unknown_flag" "unknown flag: $1 (try --help)" ;;
  esac
done

[[ $PS_LOCK_TIMEOUT =~ ^[0-9]+$ ]] || \
  ps_die "$PS_USAGE" "bad_lock_timeout" "--lock-timeout must be a whole number of seconds"

project=$(ps_resolve_project "${PS_PROJECT:-.}")
issues="$project/ISSUES.md"

# --- collect ---------------------------------------------------------------
# Prompting is reachable only on a terminal. An agent always supplies flags and
# therefore always takes the deterministic path.
if ps_is_tty; then
  [[ -n $title ]]    || ps_prompt "Title" title
  [[ -n $severity ]] || ps_prompt "Severity (low/medium/high)" severity
  [[ -n $area ]]     || ps_prompt "Area" area
  [[ -n $symptom ]]  || ps_prompt "Symptom (what was observed)" symptom
  [[ -n $trigger ]]  || ps_prompt "Trigger (what makes it happen)" trigger
  [[ -n $cause ]]    || ps_prompt "Cause (why it happens)" cause
  [[ -n $fix ]]      || ps_prompt "Resolution (or 'pending')" fix
  [[ -n $verify ]]   || ps_prompt "Verification (or 'none yet')" verify
  [[ -n $tags ]]     || ps_prompt "Tags (optional, comma-separated)" tags
  [[ -n $refs ]]     || ps_prompt "Refs (optional, comma-separated)" refs
fi

ps_require_value title "$title"
ps_require_value severity "$severity"
ps_require_value area "$area"
ps_require_value symptom "$symptom"
ps_require_value trigger "$trigger"
ps_require_value cause "$cause"
ps_require_value fix "$fix"
ps_require_value verify "$verify"
ps_require_enum severity "$severity" low medium high

if [[ -n $resolves ]]; then
  [[ $resolves =~ ^ISS-[0-9]{4}$ ]] || \
    ps_die "$PS_USAGE" "bad_id_format" "--resolves must look like ISS-0041 (got: $resolves)"
fi

# --- everything below mutates the file, so it runs under the lock -----------
write_entry() {
  # Create the file from the template the first time, so a project that has
  # never logged an issue still gets a correctly-shaped file.
  if [[ ! -e $issues ]]; then
    [[ -r $TEMPLATE ]] || ps_die "$PS_IO" "template_missing" "template not found: $TEMPLATE"
    local seeded; seeded=$(ps_tempfile)
    cat -- "$TEMPLATE" >"$seeded"
    ps_atomic_install "$seeded" "$issues"
  fi

  [[ -r $issues ]] || ps_die "$PS_IO" "unreadable" "cannot read $issues"

  # Work on a CR-stripped copy so a file edited on Windows still matches.
  local work; work=$(ps_strip_cr "$issues")

  ps_has_sentinel "$work" "$SENTINEL" || \
    ps_die "$PS_VALIDATION" "missing_sentinel" \
      "$issues has no '$SENTINEL' marker - refusing to guess where an entry belongs"

  if [[ -n $resolves ]] && ! ps_id_exists "$work" "$resolves"; then
    ps_die "$PS_NOTFOUND" "resolves_not_found" \
      "--resolves $resolves does not exist in $issues"
  fi

  local id; id=$(ps_next_id "$work" ISS)
  local now; now=$(ps_now)

  # Every value is sanitised to a single line. Fixed-size entries are what
  # makes a 10-deep read window meaningful, and a stray newline inside the
  # metadata block would break every downstream grep.
  local s_title s_area s_tags s_refs s_resolves
  s_title=$(ps_sanitize_line "$title")
  s_area=$(ps_sanitize_line "$area")
  s_tags=$(ps_sanitize_line "${tags:--}")
  s_refs=$(ps_sanitize_line "${refs:--}")
  s_resolves=${resolves:--}

  local s_symptom s_trigger s_cause s_fix s_verify
  s_symptom=$(ps_sanitize_line "$symptom")
  s_trigger=$(ps_sanitize_line "$trigger")
  s_cause=$(ps_sanitize_line "$cause")
  s_fix=$(ps_sanitize_line "$fix")
  s_verify=$(ps_sanitize_line "$verify")

  local entry; entry=$(ps_tempfile)
  {
    printf '\n'
    printf '## %s - %s\n\n' "$id" "$s_title"
    printf '<!-- issue\n'
    printf 'id: %s\n' "$id"
    printf 'logged: %s\n' "$now"
    printf 'severity: %s\n' "$severity"
    printf 'area: %s\n' "$s_area"
    printf 'tags: %s\n' "$s_tags"
    printf 'refs: %s\n' "$s_refs"
    printf 'resolves: %s\n' "$s_resolves"
    printf -- '-->\n\n'
    printf -- '- **Symptom** - %s\n' "$s_symptom"
    printf -- '- **Trigger** - %s\n' "$s_trigger"
    printf -- '- **Cause** - %s\n' "$s_cause"
    printf -- '- **Resolution** - %s\n' "$s_fix"
    printf -- '- **Verification** - %s\n' "$s_verify"
    printf '\n---\n'
  } >"$entry"

  # Splice by line number rather than a stream editor: the entry is copied
  # byte for byte, so no character in it can be interpreted as a pattern.
  local line
  line=$(grep -nF -m1 -- "$SENTINEL" "$work" | cut -d: -f1)
  [[ -n $line ]] || ps_die "$PS_VALIDATION" "missing_sentinel" "sentinel vanished mid-write"

  local out; out=$(ps_tempfile)
  head -n "$line" -- "$work" >"$out"
  cat -- "$entry" >>"$out"
  tail -n "+$((line + 1))" -- "$work" >>"$out"

  ps_atomic_install "$out" "$issues"

  if ((PS_JSON)); then
    printf '{"ok":true,"id":"%s","file":%s,"logged":%s,"severity":"%s","resolves":%s}\n' \
      "$id" \
      "$(ps_json_string "$issues")" \
      "$(ps_json_string "$now")" \
      "$severity" \
      "$([[ -n $resolves ]] && ps_json_string "$resolves" || printf 'null')"
  else
    printf '%s\n' "$id"
  fi
}

ps_scratch_init
[[ -d $project ]] || ps_die "$PS_IO" "project_missing" "no such directory: $project"
[[ -w $project ]] || ps_die "$PS_IO" "dir_not_writable" "directory is not writable: $project"
ps_with_lock "$project/.issues.lock" write_entry
