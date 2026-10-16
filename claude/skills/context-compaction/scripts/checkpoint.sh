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
#   migrate move an in-repo CONTEXT_STATE.md into the artifact store, leave the link
#   path    print where the file really lives
#
# Where the file lives. Owner order, 2026-10-16 UTC, Design principles 101 item
# 23: "any files we ever need to create, they never go in the git repo,
# artifacts get smartly linked to the outside like packages do on linux". Until
# then init wrote a regular CONTEXT_STATE.md into the project, so every repo
# carried session state in git. Now the file lives in the artifact store, at
#   $ROOT/context/YYYY/MM/YYYYMMDD-HHMMSS-<repo>-context-state.md
# with an index link at $ROOT/repos/<repo>/context/YYYY/MM/, and the project
# keeps a gitignored symlink named CONTEXT_STATE.md. The symlink is the right
# pointer rather than a path in CLAUDE.md, because every agent and every
# project's CLAUDE.md already read CONTEXT_STATE.md by name; a pointer they
# have to learn would break all of them. Writes resolve the link and land beside
# the real file, so an atomic mv never replaces the link with a regular file.
# Cost: on Windows Git Bash a symlink needs Developer Mode and
# MSYS=winsymlinks:nativestrict; without it init and migrate fail loudly
# rather than leave a copy that silently diverges. A project that still holds
# a regular file keeps working, with a warning to run migrate.
# ROOT: --root, else $ARTIFACT_ROOT, else ${XDG_STATE_HOME:-~/.local/state}/zenith,
# the same store and layout as dotfiles claude/tools/artifact. This script does
# not call that tool, because a vendored skill copy runs where dotfiles is absent.
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

CP_KEY=context
CP_ROOT=${ARTIFACT_ROOT:-${XDG_STATE_HOME:-$HOME/.local/state}/zenith}

cp_die() { local c=$1; shift; printf '%s: %s\n' "$SELF" "$*" >&2; exit "$c"; }

cp_now() {
  if [[ -n ${SOURCE_DATE_EPOCH:-} ]]; then
    date -u -d "@$SOURCE_DATE_EPOCH" '+%Y-%m-%d %H:%M UTC' 2>/dev/null \
      || date -u -r "$SOURCE_DATE_EPOCH" '+%Y-%m-%d %H:%M UTC'
  else
    date -u '+%Y-%m-%d %H:%M UTC'
  fi
}

# Compact UTC stamp, YYYYMMDDTHHMMSSZ, honouring SOURCE_DATE_EPOCH like cp_now.
cp_stamp() {
  if [[ -n ${SOURCE_DATE_EPOCH:-} ]]; then
    date -u -d "@$SOURCE_DATE_EPOCH" +%Y%m%dT%H%M%SZ 2>/dev/null || date -u -r "$SOURCE_DATE_EPOCH" +%Y%m%dT%H%M%SZ
  else
    date -u +%Y%m%dT%H%M%SZ
  fi
}

# The project's CONTEXT_STATE.md, resolved through its link to the real file.
cp_real() {
  local f="$1/$CP_FILE"
  if [[ -L $f ]]; then readlink -f "$f"; else printf '%s' "$f"; fi
}

cp_legacy_warn() {
  [[ -f "$1/$CP_FILE" && ! -L "$1/$CP_FILE" ]] || return 0
  printf '%s: %s lives in the repository; move it out with: %s migrate --project %s\n' \
    "$SELF" "$CP_FILE" "$SELF" "$1" >&2
}

cp_top() { git -C "$1" rev-parse --show-toplevel 2>/dev/null; }
cp_repo() { local top; top=$(cp_top "$1"); basename "${top:-$(cd "$1" && pwd)}"; }

# Allocate a store path for this project and its repo index link. Prints the path.
cp_store_path() {
  local project=$1 repo slug now base dir path ldir
  repo=$(cp_repo "$project")
  slug=$(printf '%s' "$repo" | tr 'A-Z' 'a-z' | tr -c 'a-z0-9' '-' | sed 's/--*/-/g; s/^-//; s/-$//')
  # YYYYMMDD-HHMMSS- (16) + <slug> + -context-state (14) must stay under 55.
  slug=${slug:0:24}; slug=${slug%-}; [[ -n $slug ]] || slug=project
  now=$(cp_stamp)
  base="${now:0:8}-${now:9:6}-$slug-context-state"
  dir="$CP_ROOT/$CP_KEY/${now:0:4}/${now:4:2}"
  path="$dir/$base.md"
  mkdir -p "$dir" || cp_die "$CP_IO" "cannot create store directory: $dir"
  [[ -e $path ]] && cp_die "$CP_IO" "store file already exists: $path"
  ldir="$CP_ROOT/repos/$repo/$CP_KEY/${now:0:4}/${now:4:2}"
  mkdir -p "$ldir" && ln -s "../../../../../$CP_KEY/${now:0:4}/${now:4:2}/$base.md" "$ldir/$base.md" \
    || cp_die "$CP_IO" "cannot write the repo index link in $ldir"
  printf '%s' "$path"
}

# Artifact frontmatter for a store path: what it is, who, where from, when.
cp_frontmatter() {
  local project=$1 path=$2 top repo branch="" b now
  top=$(cp_top "$project"); repo=$(cp_repo "$project")
  [[ -n $top ]] && branch=$(git -C "$project" rev-parse --abbrev-ref HEAD 2>/dev/null)
  b=$(basename "$path" .md); now=$(cp_stamp)
  printf -- '---\n'
  printf 'key: "%s"\nname: "%s"\nwhat: "session state for %s, newest checkpoint first"\n' "$CP_KEY" "${b:16}" "$repo"
  printf 'by: "%s"\nrepo: "%s"\nbranch: "%s"\nsession: "%s"\n' \
    "${ARTIFACT_BY:-${USER:-unknown}}" "$repo" "$branch" "${ARTIFACT_SESSION:-${CLAUDE_SESSION_ID:-}}"
  printf 'created: "%s-%s-%sT%s:%s:%sZ"\npath: "%s"\n---\n' \
    "${now:0:4}" "${now:4:2}" "${now:6:2}" "${now:9:2}" "${now:11:2}" "${now:13:2}" "$path"
}

# Drop a store path and its index link again, after losing an init race or a failed copy.
cp_store_drop() {
  local b; b=$(basename "$1")
  rm -f -- "$1"
  find "$CP_ROOT/repos" -name "$b" -type l -delete 2>/dev/null
}

# Point the project at the store: the CONTEXT_STATE.md symlink, gitignored.
cp_link() {
  local project=$1 path=$2 f="$1/$CP_FILE" top abs entry
  ln -s "$path" "$f" 2>/dev/null || return 1
  [[ -L $f ]] || { rm -f -- "$f"
    cp_die "$CP_IO" "symlinks are unavailable here (Windows: enable Developer Mode, export MSYS=winsymlinks:nativestrict)"; }
  top=$(cp_top "$project")
  [[ -n $top ]] || return 0
  abs=$(cd "$project" && pwd -P); top=$(cd "$top" && pwd -P)
  entry="/$CP_FILE"; [[ $abs != "$top" ]] && entry="/${abs#"$top"/}/$CP_FILE"
  grep -qxF "$entry" "$top/.gitignore" 2>/dev/null || {
    printf '\n# session state lives in the artifact store; this is a link to it (context-compaction)\n%s\n' \
      "$entry" >> "$top/.gitignore"
    printf '%s: added %s to .gitignore - commit it once\n' "$SELF" "$entry" >&2
  }
  return 0
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
  $SELF migrate --project DIR
  $SELF path   --project DIR

Every subcommand takes --root DIR, the artifact store root (default
\$ARTIFACT_ROOT, else \${XDG_STATE_HOME:-~/.local/state}/zenith). The file
lives there; the project holds a gitignored CONTEXT_STATE.md link to it.

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
  if [[ -e $f || -L $f ]]; then
    cp_legacy_warn "$project"
    printf '%s already exists, left byte-identical\n' "$CP_FILE" >&2
    cp_real "$project"; printf '\n'
    return $CP_OK
  fi

  local path tmp
  path=$(cp_store_path "$project") || exit
  tmp="$(dirname "$path")/.$(basename "$path").$$"
  { cp_frontmatter "$project" "$path"; cat <<'EOF'
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
  } > "$tmp" || cp_die "$CP_IO" "cannot write: $tmp"
  mv -f "$tmp" "$path" || cp_die "$CP_IO" "cannot write: $path"
  if ! cp_link "$project" "$path"; then
    # Another writer linked first. Theirs stands; this store file was never pointed at.
    cp_store_drop "$path"
    [[ -L $f ]] || cp_die "$CP_IO" "cannot write link: $f"
    cp_real "$project"; printf '\n'; return $CP_OK
  fi
  printf '%s\n' "$path"
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

  local f
  f=$(cp_real "$project")
  [[ -f $f ]] || cp_die "$CP_NOTFOUND" "no $CP_FILE - run '$SELF init' first"
  cp_legacy_warn "$project"

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

  tmp="$(dirname "$f")/.$(basename "$f").$$"
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
  local f; f=$(cp_real "$project")
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
  local f; f=$(cp_real "$project")
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
# Move an in-repo CONTEXT_STATE.md into the store, byte for byte below the new
# frontmatter, then leave the gitignored link. Order is copy, verify, untrack,
# remove, link, and a failed link puts the original back.
cmd_migrate() {
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
  if [[ -L $f ]]; then
    printf '%s is already a link into the store\n' "$CP_FILE" >&2
    cp_real "$project"; printf '\n'; return $CP_OK
  fi
  [[ -f $f ]] || cp_die "$CP_NOTFOUND" "no $CP_FILE in $project"

  cp_lock "$f"
  local path tmp fm n
  path=$(cp_store_path "$project") || exit
  tmp="$(dirname "$path")/.$(basename "$path").$$"
  fm=$(cp_frontmatter "$project" "$path"); n=$(printf '%s\n' "$fm" | wc -l)
  { printf '%s\n' "$fm"; cat "$f"; } > "$tmp" || cp_die "$CP_IO" "cannot write: $tmp"
  [[ "$(tail -n +"$(( n + 1 ))" "$tmp" | sha256sum)" == "$(sha256sum < "$f")" ]] \
    || { rm -f -- "$tmp"; cp_store_drop "$path"; cp_die "$CP_IO" "store copy does not match $f; nothing moved"; }
  mv -f "$tmp" "$path" || cp_die "$CP_IO" "cannot write: $path"

  if [[ -n $(cp_top "$project") ]] && git -C "$project" ls-files --error-unmatch "$CP_FILE" >/dev/null 2>&1; then
    git -C "$project" rm --cached -q -- "$CP_FILE" || cp_die "$CP_IO" "cannot untrack $f"
    printf '%s: untracked %s - commit the removal\n' "$SELF" "$CP_FILE" >&2
  fi
  rm -f -- "$f"
  cp_unlock
  if ! cp_link "$project" "$path"; then
    tail -n +"$(( n + 1 ))" "$path" > "$f"
    cp_die "$CP_IO" "cannot write link $f; original restored, store copy kept at $path"
  fi
  printf '%s\n' "$path"
}

cmd_path() {
  local project=""
  while [[ $# -gt 0 ]]; do
    case $1 in
      --project) project=${2:-}; shift 2 ;;
      -h|--help) usage; exit $CP_OK ;;
      *) usage >&2; cp_die "$CP_USAGE" "unknown argument: $1" ;;
    esac
  done
  cp_need --project "$project"
  [[ -e "$project/$CP_FILE" ]] || cp_die "$CP_NOTFOUND" "no $CP_FILE in $project"
  cp_legacy_warn "$project"
  cp_real "$project"; printf '\n'
}

# ---------------------------------------------------------------------------
main() {
  local -a args=()
  while [[ $# -gt 0 ]]; do
    case $1 in
      --root) [[ -n ${2:-} ]] || cp_die "$CP_USAGE" "--root needs a directory"; CP_ROOT=$2; shift 2 ;;
      *) args+=("$1"); shift ;;
    esac
  done
  set -- ${args[@]+"${args[@]}"}
  local sub=${1:-}
  [[ -n $sub ]] || { usage >&2; exit $CP_USAGE; }
  shift
  case $sub in
    init)   cmd_init "$@" ;;
    check)  cmd_check "$@" ;;
    new)    cmd_new "$@" ;;
    read)   cmd_read "$@" ;;
    verify) cmd_verify "$@" ;;
    migrate) cmd_migrate "$@" ;;
    path)   cmd_path "$@" ;;
    -h|--help) usage ;;
    *) usage >&2; cp_die "$CP_USAGE" "unknown subcommand: $sub" ;;
  esac
}

main "$@"
