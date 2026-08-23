#!/usr/bin/env bash
# checkpoint.sh - own the format of CONTEXT_STATE.md.
#
# CONTEXT_STATE.md is a sliding window: newest checkpoint on top, agents read
# the top 10 and stop, and nothing below the top is ever rewritten. Before this
# script existed the skill asked an agent to hand-write the file from a schema
# that described a single mutable state, which silently destroyed every prior
# checkpoint on the second run. Format now lives in a script, so the window is
# a property of the tool rather than a promise in prose.
#
#   init    write the preamble, once
#   check   validate a body without writing - refuses a malformed checkpoint
#   new     prepend one checkpoint, never touching anything below it
#   read    print the top N checkpoints, default 10
#   verify  the gate: ordering, uniqueness, required sections
#
# Contracts:
#   stdout   data only - a timestamp, the requested checkpoints, or one JSON object
#   stderr   every human word
#   exit 0 ok  2 usage  3 validation  4 io  5 lock  6 not found
#
# Locking is mkdir-based. flock is absent from Git Bash on Windows, where its
# absence surfaces as a lock timeout that never happened. Root CLAUDE.md Rule 17.
set -uo pipefail

SELF=$(basename "$0")

CP_OK=0
CP_USAGE=2
CP_VALIDATION=3
CP_IO=4
CP_LOCK=5
CP_NOTFOUND=6

CP_LOCK_TIMEOUT=${CP_LOCK_TIMEOUT:-10}
CP_HELD_LOCK=""
CP_FILE=CONTEXT_STATE.md
CP_MARK='## Checkpoint '

# The sections a checkpoint must carry. Current state is restated in full every
# time so the top checkpoint answers "what is true now" without reading down.
CP_REQUIRED=(
  '#### Infrastructure'
  '#### Toolchain'
  '#### Active Tasks'
  '#### Blockers'
  '### Hydration prompt'
)

cp_die() { local c=$1; shift; printf '%s: %s\n' "$SELF" "$*" >&2; exit "$c"; }

cp_now() {
  if [[ -n ${SOURCE_DATE_EPOCH:-} ]]; then
    date -u -d "@$SOURCE_DATE_EPOCH" '+%Y-%m-%d %H:%M UTC' 2>/dev/null \
      || date -u -r "$SOURCE_DATE_EPOCH" '+%Y-%m-%d %H:%M UTC'
  else
    date -u '+%Y-%m-%d %H:%M UTC'
  fi
}

cp_unlock() {
  [[ -n $CP_HELD_LOCK ]] || return 0
  rmdir "$CP_HELD_LOCK" 2>/dev/null
  CP_HELD_LOCK=""
}

cp_lock() {
  local ld="$1.lockdir" waited=0
  until mkdir "$ld" 2>/dev/null; do
    (( waited >= CP_LOCK_TIMEOUT )) \
      && cp_die "$CP_LOCK" "another writer held $ld for more than ${CP_LOCK_TIMEOUT}s"
    sleep 1
    waited=$(( waited + 1 ))
  done
  CP_HELD_LOCK="$ld"
  trap cp_unlock EXIT
}

cp_need() { [[ -n ${2:-} ]] || cp_die "$CP_USAGE" "$1 is required and may not be empty"; }
cp_dir_ok() { [[ -d $1 ]] || cp_die "$CP_IO" "project directory not found: $1"; }

# Line number of the first checkpoint heading, empty when there is none.
cp_first_mark() { grep -n "^$CP_MARK" "$1" 2>/dev/null | head -1 | cut -d: -f1; }

usage() {
  cat <<EOF
$SELF - own the format of $CP_FILE

USAGE
  $SELF init   --project DIR
  $SELF check  --body-file FILE
  $SELF new    --project DIR --body-file FILE
  $SELF read   --project DIR [--top N]
  $SELF verify --project DIR [--json]

A body file carries one checkpoint's content, without its heading:

  ### Current state
  #### Infrastructure
  #### Toolchain
  #### Active Tasks
  #### Blockers
  ### New this checkpoint      (optional - decisions and lessons since the last)
  ### Hydration prompt

Current state is restated in full every checkpoint, because the top one has to
answer "what is true now" on its own. Decisions and lessons are recorded once,
in the checkpoint where they happened, and are never restated.

EXIT
  0 ok   2 usage   3 validation   4 io   5 lock   6 not found
EOF
}

# ---------------------------------------------------------------------------
cmd_init() {
  local project=""
  while [[ $# -gt 0 ]]; do
    case $1 in
      --project) project=${2:-}; shift 2 ;;
      -h|--help) usage; exit $CP_OK ;;
      *) usage >&2; cp_die "$CP_USAGE" "unknown argument: $1" ;;
    esac
  done
  cp_need --project "$project"
  cp_dir_ok "$project"

  local f="$project/$CP_FILE"
  if [[ -e $f ]]; then
    printf '%s already exists, left byte-identical\n' "$CP_FILE" >&2
    printf '%s\n' "$f"
    return $CP_OK
  fi

  local tmp="$project/.$CP_FILE.$$"
  cat > "$tmp" <<'EOF'
# CONTEXT_STATE.md

> Session state, newest checkpoint first.
> **Read the top checkpoint and stop.** It restates current state in full and is
> complete on its own. Everything below it is how you got here.
>
> Go deeper only when the top checkpoint points at an older one, when you are
> chasing something that recurs across the window, or when asked. Say so when
> you do.
>
> Never edit a checkpoint. A new one is prepended above the last; the ones below
> are history and are immutable. Written by `checkpoint.sh`, never by hand.
EOF
  mv -f "$tmp" "$f" || cp_die "$CP_IO" "cannot write: $f"
  printf '%s\n' "$f"
}

# ---------------------------------------------------------------------------
cp_validate_body() {
  local body=$1 missing=() s
  [[ -f $body ]] || cp_die "$CP_IO" "body file not found: $body"
  [[ -s $body ]] || cp_die "$CP_VALIDATION" "body file is empty: $body"

  for s in "${CP_REQUIRED[@]}"; do
    grep -qF "$s" "$body" || missing+=("$s")
  done

  if grep -q "^$CP_MARK" "$body"; then
    cp_die "$CP_VALIDATION" \
      "body carries its own '$CP_MARK' heading - the script writes the heading and its timestamp"
  fi

  if (( ${#missing[@]} > 0 )); then
    printf '%s: checkpoint is missing required section(s):\n' "$SELF" >&2
    printf '  %s\n' "${missing[@]}" >&2
    exit $CP_VALIDATION
  fi
}

cmd_check() {
  local body=""
  while [[ $# -gt 0 ]]; do
    case $1 in
      --body-file) body=${2:-}; shift 2 ;;
      -h|--help)   usage; exit $CP_OK ;;
      *) usage >&2; cp_die "$CP_USAGE" "unknown argument: $1" ;;
    esac
  done
  cp_need --body-file "$body"
  cp_validate_body "$body"
  printf 'ok\n' >&2
}

# ---------------------------------------------------------------------------
cmd_new() {
  local project="" body=""
  while [[ $# -gt 0 ]]; do
    case $1 in
      --project)   project=${2:-}; shift 2 ;;
      --body-file) body=${2:-}; shift 2 ;;
      -h|--help)   usage; exit $CP_OK ;;
      *) usage >&2; cp_die "$CP_USAGE" "unknown argument: $1" ;;
    esac
  done
  cp_need --project "$project"
  cp_need --body-file "$body"
  cp_dir_ok "$project"
  cp_validate_body "$body"

  local f="$project/$CP_FILE"
  [[ -f $f ]] || cp_die "$CP_NOTFOUND" "no $CP_FILE - run '$SELF init' first"

  cp_lock "$f"

  local stamp head_end tmp
  stamp=$(cp_now)

  grep -qF "$CP_MARK$stamp" "$f" \
    && cp_die "$CP_VALIDATION" "a checkpoint already exists at $stamp - minute resolution collision"

  # Everything before the first existing checkpoint is the preamble and stays put.
  head_end=$(cp_first_mark "$f")
  if [[ -z $head_end ]]; then
    head_end=$(wc -l < "$f")
  else
    head_end=$(( head_end - 1 ))
  fi

  tmp="$project/.$CP_FILE.$$"
  {
    head -n "$head_end" "$f"
    printf '\n%s%s\n\n' "$CP_MARK" "$stamp"
    cat "$body"
    if [[ $head_end -lt $(wc -l < "$f") ]]; then
      printf '\n'
      tail -n +"$(( head_end + 1 ))" "$f"
    fi
  } > "$tmp" || cp_die "$CP_IO" "cannot write: $tmp"

  mv -f "$tmp" "$f" || cp_die "$CP_IO" "cannot write: $f"
  cp_unlock
  printf '%s\n' "$stamp"
}

# ---------------------------------------------------------------------------
cmd_read() {
  local project="" top=10
  while [[ $# -gt 0 ]]; do
    case $1 in
      --project) project=${2:-}; shift 2 ;;
      --top)     top=${2:-}; shift 2 ;;
      -h|--help) usage; exit $CP_OK ;;
      *) usage >&2; cp_die "$CP_USAGE" "unknown argument: $1" ;;
    esac
  done
  cp_need --project "$project"
  [[ $top =~ ^[0-9]+$ ]] || cp_die "$CP_USAGE" "--top must be a non-negative integer: $top"
  local f="$project/$CP_FILE"
  [[ -f $f ]] || cp_die "$CP_NOTFOUND" "no $CP_FILE in $project"

  awk -v mark="$CP_MARK" -v want="$top" '
    index($0, mark) == 1 { seen++ }
    seen == 0 { next }
    seen > want { exit }
    { print }
  ' "$f"
}

# ---------------------------------------------------------------------------
cmd_verify() {
  local project="" json=0
  while [[ $# -gt 0 ]]; do
    case $1 in
      --project) project=${2:-}; shift 2 ;;
      --json)    json=1; shift ;;
      -h|--help) usage; exit $CP_OK ;;
      *) usage >&2; cp_die "$CP_USAGE" "unknown argument: $1" ;;
    esac
  done
  cp_need --project "$project"
  local f="$project/$CP_FILE"
  [[ -f $f ]] || cp_die "$CP_NOTFOUND" "no $CP_FILE in $project"

  local -a stamps=()
  local line s
  while IFS= read -r line; do
    stamps+=("${line#"$CP_MARK"}")
  done < <(grep "^$CP_MARK" "$f")

  local count=${#stamps[@]}
  local disordered=0 duplicate=0 i prev

  for (( i = 1; i < count; i++ )); do
    prev=${stamps[$(( i - 1 ))]}
    s=${stamps[$i]}
    if [[ $s == "$prev" ]]; then
      duplicate=$(( duplicate + 1 ))
      printf '%s: duplicate checkpoint timestamp: %s\n' "$SELF" "$s" >&2
    elif [[ ! $prev > $s ]]; then
      disordered=$(( disordered + 1 ))
      printf '%s: out of order: %s appears above %s\n' "$SELF" "$prev" "$s" >&2
    fi
  done

  # Only the top checkpoint is required to be complete. Older ones were written
  # under whatever the schema was at the time, and rewriting them to satisfy a
  # newer gate is the in-place edit this whole change exists to prevent.
  local incomplete=0 top_body
  if (( count > 0 )); then
    top_body=$(cmd_read --project "$project" --top 1)
    for s in "${CP_REQUIRED[@]}"; do
      printf '%s' "$top_body" | grep -qF "$s" || {
        incomplete=$(( incomplete + 1 ))
        printf '%s: top checkpoint is missing %s\n' "$SELF" "$s" >&2
      }
    done
  fi

  local failures=$(( disordered + duplicate + incomplete ))

  if (( json )); then
    printf '{"checkpoints":%d,"disordered":%d,"duplicate":%d,"incomplete":%d,"ok":%s}\n' \
      "$count" "$disordered" "$duplicate" "$incomplete" \
      "$( (( failures == 0 )) && printf true || printf false )"
  else
    printf '%d checkpoint(s) in %s\n' "$count" "$f" >&2
    (( failures == 0 )) && printf 'ok\n' >&2
  fi

  (( failures == 0 )) || exit $CP_VALIDATION
  return $CP_OK
}

# ---------------------------------------------------------------------------
main() {
  local sub=${1:-}
  [[ -n $sub ]] || { usage >&2; exit $CP_USAGE; }
  shift
  case $sub in
    init)   cmd_init "$@" ;;
    check)  cmd_check "$@" ;;
    new)    cmd_new "$@" ;;
    read)   cmd_read "$@" ;;
    verify) cmd_verify "$@" ;;
    -h|--help) usage ;;
    *) usage >&2; cp_die "$CP_USAGE" "unknown subcommand: $sub" ;;
  esac
}

main "$@"
