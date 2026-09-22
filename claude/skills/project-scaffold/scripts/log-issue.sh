#!/usr/bin/env bash
#
# log-issue.sh - record an issue as one entry file under issues/YYYY/MM/.
#
# Every entry is its own file, named <UTC-timestamp>-<suffix>.md. Two agents
# writing at the same second mint different names, so concurrent writers never
# touch the same file and trunk merges never collide - the property the old
# monolithic ISSUES.md could not provide (dotfiles #95). Nothing already
# written is ever modified: a fix for an earlier issue is a NEW entry carrying
# `resolves: <suffix>`, so an agent reading newest-first meets the resolution
# before the problem it closed.
#
# scaffold-version: 1

set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

usage() {
  cat <<'EOF'
log-issue.sh - record an issue as one entry file under issues/YYYY/MM/

Usage:
  log-issue.sh [--project DIR] --title T --severity S --area A \
               --symptom T --trigger T --cause T --fix T --verify T \
               [--tags a,b] [--refs x7q2m] [--resolves a3f9c2] [--json]
  log-issue.sh migrate [--project DIR] [--json]
  log-issue.sh check   [--project DIR] [--json]

Required (for logging):
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
  --refs       related entry suffixes, comma-separated
  --resolves   the suffix of an earlier entry this one closes (must exist)
  --project    project directory (default: .)
  --json       emit one JSON object on stdout instead of the bare suffix
  --lock-timeout SECONDS   accepted for compatibility; creation needs no lock
  --help       this text

migrate  convert an old monolithic ISSUES.md into entry files, preserving
         each entry's recorded timestamp as its filename and shard. Renames
         the monolith to ISSUES.md.migrated. Refuses to run twice.
check    validate the tree: shapes, shards, metadata, duplicate suffixes,
         dangling refs, and no monolith beside the directories.

With no flags on a terminal, the fields are collected interactively.
Without a terminal, a missing required field is an error - never a prompt.

Exit codes: 0 ok, 2 usage, 3 validation, 4 io, 5 lock timeout, 6 id not found
EOF
}

# A bare first token that names a verb dispatches; anything else is logging.
case ${1-} in
  --help | -h) usage; exit "$PS_OK" ;;
  migrate | check) command="$1"; shift ;;
  *) command="log" ;;
esac

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

# A monolith beside the directories is two sources of truth. Refuse at write
# time, not just at check time, or the agent that caused it never finds out.
refuse_monolith() {
  if [[ -f $project/ISSUES.md ]]; then
    ps_die "$PS_VALIDATION" "monolith_present" \
      "$project/ISSUES.md is the old monolith format - run: log-issue.sh migrate --project $project"
  fi
}

# ---------------------------------------------------------------------------

cmd_log() {
  refuse_monolith

  # --- collect -------------------------------------------------------------
  # Prompting is reachable only on a terminal. An agent always supplies flags
  # and therefore always takes the deterministic path.
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

  # Refs and resolves are suffixes now, greppable across the whole tree.
  # Comma-split by parameter expansion - IFS here is newline+tab, so an
  # unquoted space-separated expansion would NOT split.
  local tok rest
  local -a idvals=()
  for rest in "$refs" "$resolves"; do
    [[ -z $rest || $rest == - ]] && continue
    while [[ $rest == *,* ]]; do idvals+=("${rest%%,*}"); rest=${rest#*,}; done
    idvals+=("$rest")
  done
  for tok in "${idvals[@]}"; do
    tok=${tok// /}
    [[ -z $tok ]] && continue
    [[ $tok =~ ^[a-z0-9]{5}$ ]] || \
      ps_die "$PS_USAGE" "bad_id_format" "refs and resolves take 5-char suffixes (got: $tok)"
  done

  if [[ -n $resolves ]]; then
    local -a found=()
    mapfile -t found < <(ps_find_suffix "$resolves" "$project/issues" "$project/backlog")
    ((${#found[@]} > 0)) || \
      ps_die "$PS_NOTFOUND" "resolves_not_found" \
        "--resolves $resolves does not exist anywhere in $project/issues or $project/backlog"
  fi

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

  local ts logged
  ts=$(ps_now_utc_compact)
  logged=$(ps_now_utc)
  local shard="$project/issues/${ts:0:4}/${ts:4:2}"
  mkdir -p "$shard" || ps_die "$PS_IO" "mkdir_failed" "cannot create $shard"

  # Mint-and-retry: the name is unique by construction, so creation takes no
  # lock. A collision just costs another suffix.
  local suffix dst="" attempt
  for attempt in 1 2 3 4 5; do
    suffix=$(ps_mint_suffix)
    dst="$shard/${ts}-${suffix}.md"
    local entry; entry=$(ps_tempfile)
    {
      printf '# %s\n\n' "$s_title"
      printf '<!-- issue\n'
      printf 'id: %s\n' "$suffix"
      printf 'logged: %s\n' "$logged"
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
    } >"$entry"
    if ps_atomic_create "$entry" "$dst"; then break; fi
    dst=""
  done
  [[ -n $dst ]] || ps_die "$PS_IO" "name_collision" \
    "could not mint a unique entry name after 5 attempts"

  if ((PS_JSON)); then
    printf '{"ok":true,"id":"%s","file":%s,"logged":%s,"severity":"%s","resolves":%s}\n' \
      "$suffix" \
      "$(ps_json_string "$dst")" \
      "$(ps_json_string "$logged")" \
      "$severity" \
      "$([[ -n $resolves ]] && ps_json_string "$resolves" || printf 'null')"
  else
    printf '%s\n' "$suffix"
  fi
}

# ---------------------------------------------------------------------------

cmd_migrate() {
  local monolith="$project/ISSUES.md"
  [[ -f $monolith ]] || \
    ps_die "$PS_VALIDATION" "nothing_to_migrate" "no ISSUES.md in $project - nothing to migrate"
  if [[ -d $project/issues ]] && find "$project/issues" -type f -name '*.md' 2>/dev/null | grep -q .; then
    ps_die "$PS_VALIDATION" "already_migrated" \
      "$project/issues already holds entries - refusing to migrate twice over the same output"
  fi

  local work; work=$(ps_strip_cr "$monolith")
  mapfile -t LINES <"$work"

  # Pass 1: split the monolith into entries.
  local -a M_OLDID=() M_TITLE=() M_LOGGED=() M_SEV=() M_AREA=() M_TAGS=() M_REFS=() M_RES=()
  local -a M_SYM=() M_TRI=() M_CAU=() M_FIX=() M_VER=()
  local cur=-1 in_meta=0 line
  for line in "${LINES[@]}"; do
    if [[ $line =~ ^##\ (ISS-[0-9]{4})\ -\ (.*)$ ]]; then
      cur=$((cur + 1)); in_meta=0
      M_OLDID[cur]="${BASH_REMATCH[1]}"; M_TITLE[cur]="${BASH_REMATCH[2]}"
      M_LOGGED[cur]=""; M_SEV[cur]="medium"; M_AREA[cur]="-"
      M_TAGS[cur]="-"; M_REFS[cur]="-"; M_RES[cur]="-"
      M_SYM[cur]=""; M_TRI[cur]=""; M_CAU[cur]=""; M_FIX[cur]=""; M_VER[cur]=""
      continue
    fi
    ((cur >= 0)) || continue
    if [[ $line == '<!-- issue' ]]; then in_meta=1; continue; fi
    if [[ $line == '-->' ]]; then in_meta=0; continue; fi
    if ((in_meta)); then
      case $line in
        "logged:"*)    M_LOGGED[cur]="${line#logged: }" ;;
        "severity:"*)  M_SEV[cur]="${line#severity: }" ;;
        "area:"*)      M_AREA[cur]="${line#area: }" ;;
        "tags:"*)      M_TAGS[cur]="${line#tags: }" ;;
        "refs:"*)      M_REFS[cur]="${line#refs: }" ;;
        "resolves:"*)  M_RES[cur]="${line#resolves: }" ;;
      esac
      continue
    fi
    case $line in
      '- **Symptom** - '*)      M_SYM[cur]="${line#'- **Symptom** - '}" ;;
      '- **Trigger** - '*)      M_TRI[cur]="${line#'- **Trigger** - '}" ;;
      '- **Cause** - '*)        M_CAU[cur]="${line#'- **Cause** - '}" ;;
      '- **Resolution** - '*)   M_FIX[cur]="${line#'- **Resolution** - '}" ;;
      '- **Verification** - '*) M_VER[cur]="${line#'- **Verification** - '}" ;;
    esac
  done

  ((${#M_OLDID[@]} > 0)) || ps_die "$PS_VALIDATION" "nothing_to_migrate" \
    "$monolith holds no entries - nothing to migrate"

  # Mint every new suffix up front so refs and resolves can be rewritten
  # through the old-ID -> suffix map in one pass.
  declare -A NEWID=() USED=()
  local i suffix tries
  for i in "${!M_OLDID[@]}"; do
    for tries in $(seq 1 50); do
      suffix=$(ps_mint_suffix)
      [[ -z ${USED[$suffix]-} ]] && break
      suffix=""
    done
    [[ -n $suffix ]] || ps_die "$PS_VALIDATION" "suffix_exhausted" \
      "could not mint a unique suffix after 50 attempts"
    USED[$suffix]=1
    NEWID[${M_OLDID[i]}]=$suffix
  done

  # Pass 2: write the entry files. The filename timestamp comes from the
  # entry's own `logged:` value - that is what preserves both the shard and
  # the window order the monolith had.
  local migrated=0
  for i in "${!M_OLDID[@]}"; do
    [[ -n ${M_LOGGED[i]} ]] || ps_die "$PS_VALIDATION" "migrate_bad_entry" \
      "${M_OLDID[i]} has no logged timestamp - cannot place it in a shard"
    local ts
    ts=$(ps_to_utc_compact "${M_LOGGED[i]}") || ts=""
    [[ -n $ts ]] || ps_die "$PS_VALIDATION" "migrate_bad_timestamp" \
      "${M_OLDID[i]} has an unparseable logged value: ${M_LOGGED[i]}"
    suffix=${NEWID[${M_OLDID[i]}]}
    local shard="$project/issues/${ts:0:4}/${ts:4:2}"
    mkdir -p "$shard" || ps_die "$PS_IO" "mkdir_failed" "cannot create $shard"

    # Rewrite internal references through the map. Tokens with no mapping
    # (e.g. refs to old BK- IDs, whose tree this script does not own) are
    # kept as-is: `check` will name them, which is the honest outcome.
    local new_refs new_res
    new_refs=$(ps_rewrite_tokens "${M_REFS[i]}" NEWID)
    new_res=$(ps_rewrite_tokens "${M_RES[i]}" NEWID)

    local entry; entry=$(ps_tempfile)
    {
      printf '# %s\n\n' "${M_TITLE[i]}"
      printf '<!-- issue\n'
      printf 'id: %s\n' "$suffix"
      printf 'logged: %s\n' "$(date -u -d "${M_LOGGED[i]}" +%Y-%m-%dT%H:%M:%SZ)"
      printf 'severity: %s\n' "${M_SEV[i]}"
      printf 'area: %s\n' "${M_AREA[i]}"
      printf 'tags: %s\n' "${M_TAGS[i]}"
      printf 'refs: %s\n' "$new_refs"
      printf 'resolves: %s\n' "$new_res"
      printf -- '-->\n\n'
      printf -- '- **Symptom** - %s\n' "${M_SYM[i]}"
      printf -- '- **Trigger** - %s\n' "${M_TRI[i]}"
      printf -- '- **Cause** - %s\n' "${M_CAU[i]}"
      printf -- '- **Resolution** - %s\n' "${M_FIX[i]}"
      printf -- '- **Verification** - %s\n' "${M_VER[i]}"
    } >"$entry"
    ps_atomic_create "$entry" "$shard/${ts}-${suffix}.md" || \
      ps_die "$PS_IO" "name_collision" "name collision during migration at $shard"
    migrated=$((migrated + 1))
  done

  # Renamed, not deleted: the monolith stays recoverable, but it no longer
  # collides with the tree check's "no monolith beside the directories" rule.
  mv -- "$monolith" "$monolith.migrated" || \
    ps_die "$PS_IO" "rename_failed" "could not rename $monolith to $monolith.migrated"

  ps_info "migrated $migrated entries; ISSUES.md renamed to ISSUES.md.migrated"
  if ((PS_JSON)); then
    printf '{"ok":true,"migrated":%d,"renamed":%s}\n' \
      "$migrated" "$(ps_json_string "$monolith.migrated")"
  fi
}

cmd_check() {
  ps_check_tree "$project" issues || true
  ps_check_report
}

# ---------------------------------------------------------------------------

ps_scratch_init
[[ -d $project ]] || ps_die "$PS_IO" "project_missing" "no such directory: $project"
case $command in
  log) [[ -w $project ]] || ps_die "$PS_IO" "dir_not_writable" "directory is not writable: $project"
       cmd_log ;;
  migrate) [[ -w $project ]] || ps_die "$PS_IO" "dir_not_writable" "directory is not writable: $project"
       cmd_migrate ;;
  check) cmd_check ;;
esac
