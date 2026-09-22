#!/usr/bin/env bash
#
# backlog.sh - manage a project's backlog/ tree: one entry file per item.
#
# Buckets are directories: backlog/now/, backlog/next/, backlog/later/ hold
# live work, and backlog/done/YYYY/MM/ is month-sharded because Done is the
# only bucket that accumulates. A move is a rename between bucket directories;
# done is a rename into the done shard plus a `completed:` line in the
# metadata. Every item has its own path, so two agents working two items
# never touch the same file - the property monolithic BACKLOG.md could not
# provide (dotfiles #95).
#
# Ambiguity is still refused, not guessed: a suffix that matches two files
# stops the run.
#
# scaffold-version: 1

set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

readonly BUCKETS=(now next later done)
readonly DONE_WINDOW=10

usage() {
  cat <<'EOF'
backlog.sh - manage the backlog/ tree (add | move | done | list | migrate | check)

Usage:
  backlog.sh add     [--project DIR] --title T --why T --done-when T [--bucket B] [--json]
  backlog.sh move    [--project DIR] --id SUFFIX --to BUCKET [--json]
  backlog.sh done    [--project DIR] --id SUFFIX [--json]
  backlog.sh list    [--project DIR] [--bucket BUCKET] [--json]
  backlog.sh migrate [--project DIR] [--json]
  backlog.sh check   [--project DIR] [--json]

Buckets are directories: now/ next/ later/ hold live work; done/YYYY/MM/ is
month-sharded because Done is the only bucket that accumulates.
add defaults to later.

add:
  --title      one line, what the item is
  --why        why it matters - the reason it earned a slot
  --done-when  a check someone can run without asking you

move:
  --to         destination bucket. Moving to the current bucket is a reported
               no-op. Moving to done stamps completion, same as `done`.

done:
  Renames the item into the done shard with the completion time as its new
  filename timestamp (the shard must match the name), and records
  `completed:` in the metadata rather than the title.

list:
  now / next / later in full - that is live work. done is a sliding window:
  the newest 10, then stop.

migrate:
  Convert an old monolithic BACKLOG.md into entry files, preserving each
  item's recorded timestamp as its filename. Renames the monolith to
  BACKLOG.md.migrated. Refuses to run twice.

check:
  Validate the tree: shapes, shards, metadata, duplicate suffixes, dangling
  refs, and no monolith beside the directories.

Common:
  --project DIR   project directory (default: .)
  --json          machine-readable output on stdout
  --lock-timeout SECONDS   accepted for compatibility; renames need no lock
  --help

Exit codes: 0 ok, 2 usage, 3 validation/ambiguous/bad-bucket, 4 io, 5 lock timeout, 6 id not found
EOF
}

(($#)) || { usage; exit "$PS_USAGE"; }

# --help must be handled before subcommand dispatch, or it is consumed as the
# command name and reported as an unknown command.
case ${1-} in --help | -h) usage; exit "$PS_OK" ;; esac

command="$1"; shift

title=""; why=""; done_when=""; bucket=""; id=""; to=""

while (($#)); do
  case $1 in
    --project) PS_PROJECT="${2-}"; shift 2 ;;
    --json) PS_JSON=1; shift ;;
    --lock-timeout) PS_LOCK_TIMEOUT="${2-}"; shift 2 ;;
    --title) title="${2-}"; shift 2 ;;
    --why) why="${2-}"; shift 2 ;;
    --done-when) done_when="${2-}"; shift 2 ;;
    --bucket) bucket="${2-}"; shift 2 ;;
    --id) id="${2-}"; shift 2 ;;
    --to) to="${2-}"; shift 2 ;;
    --help | -h) usage; exit "$PS_OK" ;;
    *) PS_JSON=0; ps_die "$PS_USAGE" "unknown_flag" "unknown flag: $1 (try --help)" ;;
  esac
done

[[ $PS_LOCK_TIMEOUT =~ ^[0-9]+$ ]] || \
  ps_die "$PS_USAGE" "bad_lock_timeout" "--lock-timeout must be a whole number of seconds"

project=$(ps_resolve_project "${PS_PROJECT:-.}")
tree="$project/backlog"

# A monolith beside the directories is two sources of truth. Refuse at write
# time, not just at check time, or the agent that caused it never finds out.
refuse_monolith() {
  if [[ -f $project/BACKLOG.md ]]; then
    ps_die "$PS_VALIDATION" "monolith_present" \
      "$project/BACKLOG.md is the old monolith format - run: backlog.sh migrate --project $project"
  fi
}

# find_item <suffix> -> SRC (the one matching path), or dies.
find_item() {
  local want="$1"
  [[ $want =~ ^[a-z0-9]{5}$ ]] || \
    ps_die "$PS_USAGE" "bad_id_format" "--id takes a 5-char suffix (got: $want)"
  local -a matches=()
  mapfile -t matches < <(ps_find_suffix "$want" "$tree")
  if ((${#matches[@]} == 0)); then
    ps_die "$PS_NOTFOUND" "id_not_found" "$want is not in $tree"
  fi
  if ((${#matches[@]} > 1)); then
    ps_die "$PS_VALIDATION" "id_ambiguous" \
      "$want matches ${#matches[@]} files (${matches[*]}) - a human needs to resolve that before I touch it"
  fi
  SRC="${matches[0]}"
}

# bucket_of <path> -> the bucket a path sits in, derived from its directory.
bucket_of() {
  local rel=${1#"$tree"/}
  case $rel in
    now/*) printf 'now' ;;
    next/*) printf 'next' ;;
    later/*) printf 'later' ;;
    done/*) printf 'done' ;;
    *) printf '?' ;;
  esac
}

# ---------------------------------------------------------------------------

cmd_add() {
  refuse_monolith
  ps_require_value title "$title"
  ps_require_value why "$why"
  ps_require_value done-when "$done_when"
  bucket=${bucket:-later}
  ps_require_enum bucket "$bucket" "${BUCKETS[@]}"

  local s_title s_why s_done
  s_title=$(ps_sanitize_line "$title")
  s_why=$(ps_sanitize_line "$why")
  s_done=$(ps_sanitize_line "$done_when")

  local ts added
  ts=$(ps_now_utc_compact)
  added=$(ps_now_utc)

  # done is sharded because it accumulates; the live buckets stay flat
  # because their discipline caps how many items they ever hold.
  local dir
  if [[ $bucket == done ]]; then
    dir="$tree/done/${ts:0:4}/${ts:4:2}"
  else
    dir="$tree/$bucket"
  fi
  mkdir -p "$dir" || ps_die "$PS_IO" "mkdir_failed" "cannot create $dir"

  local suffix dst="" attempt
  for attempt in 1 2 3 4 5; do
    suffix=$(ps_mint_suffix)
    dst="$dir/${ts}-${suffix}.md"
    local entry; entry=$(ps_tempfile)
    {
      printf '# %s\n\n' "$s_title"
      printf '<!-- item\n'
      printf 'id: %s\n' "$suffix"
      printf 'added: %s\n' "$added"
      printf -- '-->\n\n'
      printf -- '- why: %s\n' "$s_why"
      printf -- '- done-when: %s\n' "$s_done"
    } >"$entry"
    if ps_atomic_create "$entry" "$dst"; then break; fi
    dst=""
  done
  [[ -n $dst ]] || ps_die "$PS_IO" "name_collision" \
    "could not mint a unique entry name after 5 attempts"

  if ((PS_JSON)); then
    printf '{"ok":true,"id":"%s","bucket":"%s","file":%s,"added":%s}\n' \
      "$suffix" "$bucket" "$(ps_json_string "$dst")" "$(ps_json_string "$added")"
  else
    printf '%s\n' "$suffix"
  fi
}

# land_in_done <src-path> - the shared tail of `move --to done` and `done`.
# The filename is re-stamped with the completion time: the done shard a file
# sits in must be the shard its own name implies, and "when it finished" is
# the only ordering Done has ever meant.
land_in_done() {
  local src="$1"
  local ts completed
  ts=$(ps_now_utc_compact)
  completed=$(ps_now_utc)
  local shard="$tree/done/${ts:0:4}/${ts:4:2}"
  mkdir -p "$shard" || ps_die "$PS_IO" "mkdir_failed" "cannot create $shard"

  local base; base=$(basename -- "$src")
  local suffix=${base##*-}; suffix=${suffix%.md}

  # Insert completed: into the metadata block - not the title, where it would
  # leak into every parse of the item's name.
  local staged; staged=$(ps_tempfile)
  awk -v c="completed: $completed" '
    /^-->$/ && !stamped { print c; stamped = 1 }
    { print }
  ' "$src" >"$staged"

  local attempt dst=""
  for attempt in 1 2 3; do
    dst="$shard/${ts}-${suffix}.md"
    if ps_atomic_create "$staged" "$dst"; then break; fi
    # A same-suffix file already in done means a concurrent `done` beat us
    # to it - report the no-op rather than mint a duplicate suffix.
    local -a raced=()
    mapfile -t raced < <(ps_find_suffix "$suffix" "$tree/done")
    if ((${#raced[@]} > 0)); then
      dst="RACED"
      break
    fi
    ts=$(ps_now_utc_compact)
    shard="$tree/done/${ts:0:4}/${ts:4:2}"
    mkdir -p "$shard" || ps_die "$PS_IO" "mkdir_failed" "cannot create $shard"
    dst=""
  done

  if [[ $dst == RACED ]]; then
    if ((PS_JSON)); then
      printf '{"ok":true,"id":"%s","bucket":"done","moved":false,"note":"already done"}\n' "$suffix"
    else
      ps_info "$suffix is already done - nothing to do"
      printf '%s\n' "$suffix"
    fi
    return 0
  fi
  [[ -n $dst ]] || ps_die "$PS_IO" "name_collision" \
    "could not land $suffix in the done shard after 3 attempts"

  rm -f -- "$src" || ps_die "$PS_IO" "remove_failed" "landed the done copy but could not remove $src"

  if ((PS_JSON)); then
    printf '{"ok":true,"id":"%s","bucket":"done","completed":%s}\n' \
      "$suffix" "$(ps_json_string "$completed")"
  else
    printf '%s\n' "$suffix"
  fi
}

cmd_move() {
  refuse_monolith
  ps_require_value id "$id"
  ps_require_value to "$to"
  ps_require_enum to "$to" "${BUCKETS[@]}"

  find_item "$id"
  local cur; cur=$(bucket_of "$SRC")

  if [[ $cur == "$to" ]]; then
    if ((PS_JSON)); then
      printf '{"ok":true,"id":"%s","bucket":"%s","moved":false,"note":"already in that bucket"}\n' "$id" "$to"
    else
      ps_info "$id is already in $to - nothing to do"
      printf '%s\n' "$id"
    fi
    return 0
  fi

  if [[ $to == done ]]; then
    land_in_done "$SRC"
    return 0
  fi

  local dir="$tree/$to"
  mkdir -p "$dir" || ps_die "$PS_IO" "mkdir_failed" "cannot create $dir"
  local dst="$dir/$(basename -- "$SRC")"

  # link-then-unlink rather than mv: ln refuses to overwrite atomically, so a
  # same-named file in the target bucket can never be clobbered.
  if ln -- "$SRC" "$dst" 2>/dev/null; then
    rm -f -- "$SRC"
  else
    if [[ -e $dst ]]; then
      ps_die "$PS_VALIDATION" "duplicate_name" \
        "$dst already exists - the tree has a duplicate name; run: backlog.sh check --project $project"
    fi
    [[ -e $SRC ]] || ps_die "$PS_NOTFOUND" "id_not_found" \
      "$id is no longer where it was - another agent may have moved it"
    ps_die "$PS_IO" "move_failed" "could not move $SRC to $dst"
  fi

  if ((PS_JSON)); then
    printf '{"ok":true,"id":"%s","from":"%s","to":"%s","moved":true}\n' "$id" "$cur" "$to"
  else
    printf '%s\n' "$id"
  fi
}

cmd_done() {
  refuse_monolith
  ps_require_value id "$id"
  find_item "$id"

  if [[ $(bucket_of "$SRC") == done ]]; then
    if ((PS_JSON)); then
      printf '{"ok":true,"id":"%s","bucket":"done","moved":false,"note":"already done"}\n' "$id"
    else
      ps_info "$id is already done - nothing to do"
      printf '%s\n' "$id"
    fi
    return 0
  fi

  land_in_done "$SRC"
}

cmd_list() {
  [[ -n $bucket ]] && ps_require_enum bucket "$bucket" "${BUCKETS[@]}"

  local -a files=()
  local b
  if [[ -n $bucket ]]; then
    if [[ $bucket == done ]]; then
      mapfile -t files < <(ps_newest_entries "$tree/done" "$DONE_WINDOW")
    else
      mapfile -t files < <(ps_newest_entries "$tree/$bucket" 0)
    fi
  else
    for b in now next later; do
      local -a bf=()
      mapfile -t bf < <(ps_newest_entries "$tree/$b" 0)
      files+=("${bf[@]}")
    done
    local -a df=()
    mapfile -t df < <(ps_newest_entries "$tree/done" "$DONE_WINDOW")
    files+=("${df[@]}")
  fi

  local first=1 f
  if ((PS_JSON)); then printf '['; fi
  for f in ${files[@]+"${files[@]}"}; do
    local item_id item_title item_why item_done cur base
    item_id=$(ps_meta "$f" id)
    [[ -n $item_id ]] || { base=$(basename -- "$f"); item_id=${base##*-}; item_id=${item_id%.md}; }
    item_title=$(sed -n '1s/^# //p' "$f")
    item_why=$(ps_body_field "$f" why)
    item_done=$(ps_body_field "$f" done-when)
    cur=$(bucket_of "$f")
    if ((PS_JSON)); then
      if ((first == 0)); then printf ','; fi
      first=0
      printf '{"id":"%s","bucket":"%s","title":%s,"why":%s,"done_when":%s}' \
        "$item_id" "$cur" "$(ps_json_string "$item_title")" \
        "$(ps_json_string "$item_why")" "$(ps_json_string "$item_done")"
    else
      printf '%-7s %-6s %s\n' "$item_id" "$cur" "$item_title"
    fi
  done
  if ((PS_JSON)); then printf ']\n'; fi
  return 0
}

# ---------------------------------------------------------------------------

cmd_migrate() {
  local monolith="$project/BACKLOG.md"
  [[ -f $monolith ]] || \
    ps_die "$PS_VALIDATION" "nothing_to_migrate" "no BACKLOG.md in $project - nothing to migrate"
  if [[ -d $tree ]] && find "$tree" -type f -name '*.md' 2>/dev/null | grep -q .; then
    ps_die "$PS_VALIDATION" "already_migrated" \
      "$tree already holds entries - refusing to migrate twice over the same output"
  fi

  local work; work=$(ps_strip_cr "$monolith")
  mapfile -t LINES <"$work"

  # Pass 1: split the monolith into items. The current bucket comes from the
  # marker lines; an item runs from its checkbox heading to the next boundary.
  local -a M_OLDID=() M_TITLE=() M_ADDED=() M_COMPLETED=() M_WHY=() M_DONE=() M_BUCKET=()
  local cur=-1 cur_bucket="" in_meta=0 line
  for line in "${LINES[@]}"; do
    case $line in
      '<!-- BACKLOG:NOW -->')   cur_bucket="now"; continue ;;
      '<!-- BACKLOG:NEXT -->')  cur_bucket="next"; continue ;;
      '<!-- BACKLOG:LATER -->') cur_bucket="later"; continue ;;
      '<!-- BACKLOG:DONE -->')  cur_bucket="done"; continue ;;
    esac
    if [[ $line =~ ^-\ \[[\ x]\]\ \*\*(BK-[0-9]{4})\*\*\ -\ (.*)$ ]]; then
      cur=$((cur + 1)); in_meta=0
      M_OLDID[cur]="${BASH_REMATCH[1]}"; M_TITLE[cur]="${BASH_REMATCH[2]}"
      M_ADDED[cur]=""; M_COMPLETED[cur]=""; M_WHY[cur]=""; M_DONE[cur]=""
      M_BUCKET[cur]="${cur_bucket:-later}"
      continue
    fi
    ((cur >= 0)) || continue
    # Metadata and body lines are indented two spaces in the old format.
    local trimmed=${line#"  "}
    if [[ $trimmed == '<!-- item' ]]; then in_meta=1; continue; fi
    if [[ $trimmed == '-->' ]]; then in_meta=0; continue; fi
    if ((in_meta)); then
      case $trimmed in
        "added:"*)     M_ADDED[cur]="${trimmed#added: }" ;;
        "completed:"*) M_COMPLETED[cur]="${trimmed#completed: }" ;;
      esac
      continue
    fi
    case $trimmed in
      '- why: '*)      M_WHY[cur]="${trimmed#'- why: '}" ;;
      '- done-when: '*) M_DONE[cur]="${trimmed#'- done-when: '}" ;;
    esac
  done

  ((${#M_OLDID[@]} > 0)) || ps_die "$PS_VALIDATION" "nothing_to_migrate" \
    "$monolith holds no items - nothing to migrate"

  declare -A USED=()
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
    M_OLDID[i]=$suffix
  done

  # Pass 2: write the entry files. Live buckets take the filename timestamp
  # from `added:`; done items from `completed:` (falling back to `added:`),
  # because the done shard must be the shard the name implies.
  local migrated=0
  for i in "${!M_OLDID[@]}"; do
    suffix=${M_OLDID[i]}
    local stamp_source ts
    if [[ ${M_BUCKET[i]} == done && -n ${M_COMPLETED[i]} ]]; then
      stamp_source=${M_COMPLETED[i]}
    else
      stamp_source=${M_ADDED[i]}
    fi
    [[ -n $stamp_source ]] || ps_die "$PS_VALIDATION" "migrate_bad_entry" \
      "an item titled '${M_TITLE[i]}' has no timestamp - cannot place it"
    ts=$(ps_to_utc_compact "$stamp_source") || ts=""
    [[ -n $ts ]] || ps_die "$PS_VALIDATION" "migrate_bad_timestamp" \
      "the item titled '${M_TITLE[i]}' has an unparseable timestamp: $stamp_source"

    local dir
    if [[ ${M_BUCKET[i]} == done ]]; then
      dir="$tree/done/${ts:0:4}/${ts:4:2}"
    else
      dir="$tree/${M_BUCKET[i]}"
    fi
    mkdir -p "$dir" || ps_die "$PS_IO" "mkdir_failed" "cannot create $dir"

    local added_stamp
    if [[ -n ${M_ADDED[i]} ]]; then
      added_stamp=$(date -u -d "${M_ADDED[i]}" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null) || added_stamp=${M_ADDED[i]}
    else
      added_stamp="-"
    fi

    local entry; entry=$(ps_tempfile)
    {
      printf '# %s\n\n' "${M_TITLE[i]}"
      printf '<!-- item\n'
      printf 'id: %s\n' "$suffix"
      printf 'added: %s\n' "$added_stamp"
      if [[ -n ${M_COMPLETED[i]} ]]; then
        printf 'completed: %s\n' "$(date -u -d "${M_COMPLETED[i]}" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || printf '%s' "${M_COMPLETED[i]}")"
      fi
      printf -- '-->\n\n'
      printf -- '- why: %s\n' "${M_WHY[i]}"
      printf -- '- done-when: %s\n' "${M_DONE[i]}"
    } >"$entry"
    ps_atomic_create "$entry" "$dir/${ts}-${suffix}.md" || \
      ps_die "$PS_IO" "name_collision" "name collision during migration at $dir"
    migrated=$((migrated + 1))
  done

  # Renamed, not deleted: the monolith stays recoverable, but it no longer
  # collides with the tree check's "no monolith beside the directories" rule.
  mv -- "$monolith" "$monolith.migrated" || \
    ps_die "$PS_IO" "rename_failed" "could not rename $monolith to $monolith.migrated"

  ps_info "migrated $migrated items; BACKLOG.md renamed to BACKLOG.md.migrated"
  if ((PS_JSON)); then
    printf '{"ok":true,"migrated":%d,"renamed":%s}\n' \
      "$migrated" "$(ps_json_string "$monolith.migrated")"
  fi
}

cmd_check() {
  ps_check_tree "$project" backlog || true
  ps_check_report
}

# ---------------------------------------------------------------------------

ps_scratch_init
[[ -d $project ]] || ps_die "$PS_IO" "project_missing" "no such directory: $project"

case $command in
  add) [[ -w $project ]] || ps_die "$PS_IO" "dir_not_writable" "directory is not writable: $project"
       cmd_add ;;
  move) [[ -w $project ]] || ps_die "$PS_IO" "dir_not_writable" "directory is not writable: $project"
        cmd_move ;;
  done) [[ -w $project ]] || ps_die "$PS_IO" "dir_not_writable" "directory is not writable: $project"
        cmd_done ;;
  list) cmd_list ;;
  migrate) [[ -w $project ]] || ps_die "$PS_IO" "dir_not_writable" "directory is not writable: $project"
        cmd_migrate ;;
  check) cmd_check ;;
  *) ps_die "$PS_USAGE" "unknown_command" "unknown command: $command (add | move | done | list | migrate | check)" ;;
esac
