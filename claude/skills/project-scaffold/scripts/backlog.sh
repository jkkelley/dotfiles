#!/usr/bin/env bash
#
# backlog.sh - manage a project's BACKLOG.md.
#
# The one managed file with real mutation: items move between buckets and get
# marked done. Every operation refuses rather than guesses - an unknown ID, an
# unknown bucket, or an ID that appears twice all stop the run.
#
# scaffold-version: 1

set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
SKILL_DIR=$(cd -- "$SCRIPT_DIR/.." && pwd)
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

readonly TEMPLATE="$SKILL_DIR/references/templates/BACKLOG.md.tmpl"
readonly BUCKETS=(now next later done)
readonly DONE_KEEP=20

usage() {
  cat <<'EOF'
backlog.sh - manage BACKLOG.md (add | move | done | list)

Usage:
  backlog.sh add   [--project DIR] --title T --why T --done-when T [--bucket B] [--json]
  backlog.sh move  [--project DIR] --id BK-0014 --to BUCKET [--json]
  backlog.sh done  [--project DIR] --id BK-0014 [--json]
  backlog.sh list  [--project DIR] [--bucket BUCKET] [--json]

Buckets: now | next | later | done   (add defaults to later)

add:
  --title      one line, what the item is
  --why        why it matters - the reason it earned a slot
  --done-when  a check someone can run without asking you

move:
  --to         destination bucket. Moving to the current bucket is a reported no-op.

done:
  Moves the item to Done with today's date and trims Done to the newest 20.

Common:
  --project DIR   project directory (default: .)
  --json          machine-readable output on stdout
  --lock-timeout SECONDS
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
backlog="$project/BACKLOG.md"

marker_for() {
  case $1 in
    now) printf '<!-- BACKLOG:NOW -->' ;;
    next) printf '<!-- BACKLOG:NEXT -->' ;;
    later) printf '<!-- BACKLOG:LATER -->' ;;
    done) printf '<!-- BACKLOG:DONE -->' ;;
  esac
}

ensure_file() {
  if [[ ! -e $backlog ]]; then
    [[ -r $TEMPLATE ]] || ps_die "$PS_IO" "template_missing" "template not found: $TEMPLATE"
    local seeded; seeded=$(ps_tempfile)
    cat -- "$TEMPLATE" >"$seeded"
    ps_atomic_install "$seeded" "$backlog"
  fi
  [[ -r $backlog ]] || ps_die "$PS_IO" "unreadable" "cannot read $backlog"
}

# Load the file into LINES[], CR-stripped so a Windows-touched file still parses.
load_lines() {
  local work; work=$(ps_strip_cr "$backlog")
  mapfile -t LINES <"$work"
  local b
  for b in "${BUCKETS[@]}"; do
    grep -qF -- "$(marker_for "$b")" "$work" || \
      ps_die "$PS_VALIDATION" "missing_marker" \
        "$backlog has no '$(marker_for "$b")' marker - refusing to guess where items belong"
  done
}

# Index of the marker line for a bucket.
marker_index() {
  local want="$1" i
  for ((i = 0; i < ${#LINES[@]}; i++)); do
    if [[ ${LINES[i]} == "$(marker_for "$want")" ]]; then printf '%d' "$i"; return 0; fi
  done
  ps_die "$PS_VALIDATION" "missing_marker" "marker for bucket '$want' not found"
}

# An item runs from its heading line until the next item, bucket marker, or
# markdown heading. Everything between is preserved byte for byte on a move.
is_item_start() { [[ ${1-} =~ ^-\ \[[\ x]\]\ \*\*BK-[0-9]{4}\*\* ]]; }
is_boundary() { [[ ${1-} == '<!-- BACKLOG:'* || ${1-} == '## '* || ${1-} == '<!-- scaffold:section='* ]]; }

# find_item <id> -> sets ITEM_START, ITEM_END (exclusive), ITEM_BUCKET
find_item() {
  local want="$1" i cur_bucket="" count=0
  ITEM_START=-1; ITEM_END=-1; ITEM_BUCKET=""
  for ((i = 0; i < ${#LINES[@]}; i++)); do
    local b
    for b in "${BUCKETS[@]}"; do
      if [[ ${LINES[i]} == "$(marker_for "$b")" ]]; then cur_bucket="$b"; fi
    done
    if is_item_start "${LINES[i]}" && [[ ${LINES[i]} == *"**${want}**"* ]]; then
      count=$((count + 1))
      if ((count == 1)); then
        ITEM_START=$i
        ITEM_BUCKET=$cur_bucket
        local j
        for ((j = i + 1; j < ${#LINES[@]}; j++)); do
          if is_item_start "${LINES[j]}" || is_boundary "${LINES[j]}"; then break; fi
        done
        ITEM_END=$j
      fi
    fi
  done
  if ((count == 0)); then
    ps_die "$PS_NOTFOUND" "id_not_found" "$want is not in $backlog"
  fi
  if ((count > 1)); then
    ps_die "$PS_VALIDATION" "id_ambiguous" \
      "$want appears $count times in $backlog - a human needs to resolve that before I touch it"
  fi
  return 0
}

# Trailing blank lines belong to the gap between items, not to the item.
trim_item_end() {
  while ((ITEM_END > ITEM_START + 1)) && [[ -z ${LINES[ITEM_END - 1]} ]]; do
    ITEM_END=$((ITEM_END - 1))
  done
}

write_lines() {
  local out; out=$(ps_tempfile)
  local l
  for l in "${LINES[@]}"; do printf '%s\n' "$l"; done >"$out"
  ps_atomic_install "$out" "$backlog"
}

# --- commands ---------------------------------------------------------------

cmd_add() {
  ensure_file
  ps_require_value title "$title"
  ps_require_value why "$why"
  ps_require_value done-when "$done_when"
  bucket=${bucket:-later}
  ps_require_enum bucket "$bucket" "${BUCKETS[@]}"

  load_lines
  local work; work=$(ps_strip_cr "$backlog")
  local new_id; new_id=$(ps_next_id "$work" BK)
  local now; now=$(ps_now)

  local s_title s_why s_done
  s_title=$(ps_sanitize_line "$title")
  s_why=$(ps_sanitize_line "$why")
  s_done=$(ps_sanitize_line "$done_when")

  local checkbox="- [ ]"
  if [[ $bucket == done ]]; then checkbox="- [x]"; fi

  local -a item=(
    "$checkbox **${new_id}** - ${s_title}"
    "  <!-- item"
    "  id: ${new_id}"
    "  added: ${now}"
    "  -->"
    "  - why: ${s_why}"
    "  - done-when: ${s_done}"
    ""
  )

  local at; at=$(marker_index "$bucket")
  local -a out=()
  local i
  for ((i = 0; i <= at; i++)); do out+=("${LINES[i]}"); done
  out+=("")
  out+=("${item[@]}")
  for ((i = at + 1; i < ${#LINES[@]}; i++)); do out+=("${LINES[i]}"); done
  LINES=("${out[@]}")
  write_lines

  if ((PS_JSON)); then
    printf '{"ok":true,"id":"%s","bucket":"%s","file":%s,"added":%s}\n' \
      "$new_id" "$bucket" "$(ps_json_string "$backlog")" "$(ps_json_string "$now")"
  else
    printf '%s\n' "$new_id"
  fi
}

cmd_move() {
  ensure_file
  ps_require_value id "$id"
  ps_require_value to "$to"
  [[ $id =~ ^BK-[0-9]{4}$ ]] || ps_die "$PS_USAGE" "bad_id_format" "--id must look like BK-0014 (got: $id)"
  ps_require_enum to "$to" "${BUCKETS[@]}"

  load_lines
  find_item "$id"
  trim_item_end

  if [[ $ITEM_BUCKET == "$to" ]]; then
    if ((PS_JSON)); then
      printf '{"ok":true,"id":"%s","bucket":"%s","moved":false,"note":"already in that bucket"}\n' "$id" "$to"
    else
      ps_info "$id is already in $to - nothing to do"
      printf '%s\n' "$id"
    fi
    return 0
  fi

  # Lift the item out verbatim, then splice it in under the target marker.
  local -a item=()
  local i
  for ((i = ITEM_START; i < ITEM_END; i++)); do item+=("${LINES[i]}"); done

  local -a without=()
  for ((i = 0; i < ${#LINES[@]}; i++)); do
    if ((i >= ITEM_START && i < ITEM_END)); then continue; fi
    without+=("${LINES[i]}")
  done
  LINES=("${without[@]}")

  local at; at=$(marker_index "$to")
  local -a out=()
  for ((i = 0; i <= at; i++)); do out+=("${LINES[i]}"); done
  out+=("")
  out+=("${item[@]}")
  for ((i = at + 1; i < ${#LINES[@]}; i++)); do out+=("${LINES[i]}"); done
  LINES=("${out[@]}")
  write_lines

  if ((PS_JSON)); then
    printf '{"ok":true,"id":"%s","from":"%s","to":"%s","moved":true}\n' "$id" "$ITEM_BUCKET" "$to"
  else
    printf '%s\n' "$id"
  fi
}

cmd_done() {
  ensure_file
  ps_require_value id "$id"
  [[ $id =~ ^BK-[0-9]{4}$ ]] || ps_die "$PS_USAGE" "bad_id_format" "--id must look like BK-0014 (got: $id)"

  load_lines
  find_item "$id"
  trim_item_end

  local today; today=$(ps_today)
  local -a item=()
  local i first=1
  for ((i = ITEM_START; i < ITEM_END; i++)); do
    local line="${LINES[i]}"
    if ((first)); then
      # The pattern must be quoted: unquoted, `[ ]` is a glob character class
      # matching a single space, so the checkbox would never flip.
      line=${line/"- [ ]"/"- [x]"}
      first=0
    elif [[ $line == '  -->' ]]; then
      # The completion date belongs in the metadata block, not appended to the
      # title - otherwise it leaks into every parse of the item's name.
      item+=("  completed: ${today}")
    fi
    item+=("$line")
  done

  local -a without=()
  for ((i = 0; i < ${#LINES[@]}; i++)); do
    if ((i >= ITEM_START && i < ITEM_END)); then continue; fi
    without+=("${LINES[i]}")
  done
  LINES=("${without[@]}")

  local at; at=$(marker_index done)
  local -a out=()
  for ((i = 0; i <= at; i++)); do out+=("${LINES[i]}"); done
  out+=("")
  out+=("${item[@]}")
  for ((i = at + 1; i < ${#LINES[@]}; i++)); do out+=("${LINES[i]}"); done
  LINES=("${out[@]}")

  trim_done
  write_lines

  if ((PS_JSON)); then
    printf '{"ok":true,"id":"%s","bucket":"done","completed":%s}\n' "$id" "$(ps_json_string "$today")"
  else
    printf '%s\n' "$id"
  fi
}

# Keep only the newest DONE_KEEP items in Done. Git holds the rest.
trim_done() {
  local at; at=$(marker_index done)
  local -a kept=() i seen=0
  local -a head=() tail=()
  for ((i = 0; i <= at; i++)); do head+=("${LINES[i]}"); done

  local n=${#LINES[@]}
  for ((i = at + 1; i < n; i++)); do
    if is_item_start "${LINES[i]}"; then
      seen=$((seen + 1))
    fi
    if ((seen <= DONE_KEEP)); then
      kept+=("${LINES[i]}")
    fi
  done
  LINES=("${head[@]}" "${kept[@]}")
}

cmd_list() {
  ensure_file
  load_lines
  [[ -n $bucket ]] && ps_require_enum bucket "$bucket" "${BUCKETS[@]}"

  local i cur="" first=1
  if ((PS_JSON)); then printf '['; fi
  for ((i = 0; i < ${#LINES[@]}; i++)); do
    local b
    for b in "${BUCKETS[@]}"; do
      if [[ ${LINES[i]} == "$(marker_for "$b")" ]]; then cur="$b"; fi
    done
    is_item_start "${LINES[i]}" || continue
    if [[ -n $bucket && $cur != "$bucket" ]]; then continue; fi

    local line="${LINES[i]}"
    local item_id="${line#*\*\*}"; item_id="${item_id%%\*\**}"
    local item_title="${line#*\*\* - }"

    local dw="" wy="" j
    for ((j = i + 1; j < ${#LINES[@]}; j++)); do
      is_item_start "${LINES[j]}" && break
      is_boundary "${LINES[j]}" && break
      if [[ ${LINES[j]} == *'- done-when: '* ]]; then dw="${LINES[j]#*- done-when: }"; fi
      if [[ ${LINES[j]} == *'- why: '* ]]; then wy="${LINES[j]#*- why: }"; fi
    done

    if ((PS_JSON)); then
      if ((first == 0)); then printf ','; fi
      first=0
      printf '{"id":"%s","bucket":"%s","title":%s,"why":%s,"done_when":%s}' \
        "$item_id" "$cur" "$(ps_json_string "$item_title")" \
        "$(ps_json_string "$wy")" "$(ps_json_string "$dw")"
    else
      printf '%-10s %-6s %s\n' "$item_id" "$cur" "$item_title"
    fi
  done
  if ((PS_JSON)); then printf ']\n'; fi
  return 0
}

ps_scratch_init
[[ -d $project ]] || ps_die "$PS_IO" "project_missing" "no such directory: $project"

case $command in
  add) [[ -w $project ]] || ps_die "$PS_IO" "dir_not_writable" "directory is not writable: $project"
       ps_with_lock "$project/.backlog.lock" cmd_add ;;
  move) [[ -w $project ]] || ps_die "$PS_IO" "dir_not_writable" "directory is not writable: $project"
        ps_with_lock "$project/.backlog.lock" cmd_move ;;
  done) [[ -w $project ]] || ps_die "$PS_IO" "dir_not_writable" "directory is not writable: $project"
        ps_with_lock "$project/.backlog.lock" cmd_done ;;
  list) cmd_list ;;
  *) ps_die "$PS_USAGE" "unknown_command" "unknown command: $command (add | move | done | list)" ;;
esac
