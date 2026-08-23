#!/usr/bin/env bash
# docs.sh - own the formats of a project's documentation layer.
#
# Five subcommands:
#   init     write docs/README.md, the router that names every mode
#   adr      append a new architecture decision record
#   sop      append a new standard operating procedure
#   verify   the gate: every doc declares a mode and a review date
#   modes    print the Diataxis modes, for a caller that needs to choose one
#
# Contracts, matching the rest of this repo:
#   stdout   data only - an ID, or one JSON object under --json
#   stderr   every human word
#   exit 0   success
#   exit 2   usage
#   exit 3   validation
#   exit 4   io
#   exit 5   lock timeout
#   exit 6   not found
#
# Locking is mkdir-based rather than flock. mkdir is atomic on every filesystem
# this repo runs on; flock is absent from Git Bash on Windows, where its absence
# surfaces as a lock timeout that never happened. A skill that claims to be OS
# aware cannot take a lock that only exists on one OS.
set -uo pipefail

SELF=$(basename "$0")

DL_OK=0
DL_USAGE=2
DL_VALIDATION=3
DL_IO=4
DL_LOCK=5
DL_NOTFOUND=6

DL_LOCK_TIMEOUT=${DL_LOCK_TIMEOUT:-10}
DL_HELD_LOCK=""

# SOURCE_DATE_EPOCH lets the tests pin the clock and compare bytes with cmp
# instead of asserting around a moving value.
dl_today() {
  if [[ -n ${SOURCE_DATE_EPOCH:-} ]]; then
    date -u -d "@$SOURCE_DATE_EPOCH" +%Y-%m-%d 2>/dev/null \
      || date -u -r "$SOURCE_DATE_EPOCH" +%Y-%m-%d
  else
    date +%Y-%m-%d
  fi
}

dl_die() {
  local code=$1; shift
  printf '%s: %s\n' "$SELF" "$*" >&2
  exit "$code"
}

dl_unlock() {
  [[ -n $DL_HELD_LOCK ]] || return 0
  rmdir "$DL_HELD_LOCK" 2>/dev/null
  DL_HELD_LOCK=""
}

dl_lock() {
  local lockdir="$1.lockdir"
  local waited=0
  until mkdir "$lockdir" 2>/dev/null; do
    if (( waited >= DL_LOCK_TIMEOUT )); then
      dl_die "$DL_LOCK" "another writer held $lockdir for more than ${DL_LOCK_TIMEOUT}s"
    fi
    sleep 1
    waited=$(( waited + 1 ))
  done
  DL_HELD_LOCK="$lockdir"
  trap dl_unlock EXIT
}

# Staged write then rename. Never leaves a half-written file behind.
dl_atomic() {
  local tmp=$1 dest=$2
  mv -f "$tmp" "$dest" || dl_die "$DL_IO" "cannot write: $dest"
}

dl_slug() {
  printf '%s' "$1" \
    | tr '[:upper:]' '[:lower:]' \
    | sed -e 's/[^a-z0-9]\+/-/g' -e 's/^-//' -e 's/-$//'
}

# Next zero-padded number in a directory, given a prefix. 0001 when empty.
dl_next_id() {
  local dir=$1 prefix=$2 n=0 f base num
  if [[ -d $dir ]]; then
    for f in "$dir/$prefix"-[0-9][0-9][0-9][0-9]-*.md; do
      [[ -e $f ]] || continue
      base=$(basename "$f")
      num=${base#"$prefix"-}
      num=${num%%-*}
      num=$((10#$num))
      (( num > n )) && n=$num
    done
  fi
  printf '%s-%04d' "$prefix" $(( n + 1 ))
}

dl_need() {
  [[ -n ${2:-} ]] || dl_die "$DL_USAGE" "$1 is required and may not be empty"
}

dl_project_ok() {
  [[ -d $1 ]] || dl_die "$DL_IO" "project directory not found: $1"
}

usage() {
  cat <<EOF
$SELF - own the formats of a project's documentation layer

USAGE
  $SELF init   --project DIR
  $SELF adr    --project DIR --title T --context C --decision D --consequences X
               [--status proposed|accepted|superseded] [--supersedes ADR-0003]
  $SELF sop    --project DIR --title T --purpose P --when W --steps S
  $SELF verify --project DIR [--json]
  $SELF modes

EXIT
  0 ok   2 usage   3 validation   4 io   5 lock   6 not found
EOF
}

# ---------------------------------------------------------------------------
# modes
# ---------------------------------------------------------------------------
cmd_modes() {
  cat <<'EOF'
tutorial     learning-oriented     takes a beginner through a first success
how-to       task-oriented         gets someone with a goal to the goal
reference    information-oriented  describes the machinery, no narrative
explanation  understanding-oriented  the why, the context, the trade-offs
EOF
}

# ---------------------------------------------------------------------------
# init
# ---------------------------------------------------------------------------
cmd_init() {
  local project=""
  while [[ $# -gt 0 ]]; do
    case $1 in
      --project) project=${2:-}; shift 2 ;;
      -h|--help) usage; exit $DL_OK ;;
      *) usage >&2; dl_die "$DL_USAGE" "unknown argument: $1" ;;
    esac
  done
  dl_need --project "$project"
  dl_project_ok "$project"

  local docs="$project/docs"
  mkdir -p "$docs" || dl_die "$DL_IO" "cannot create: $docs"

  local readme="$docs/README.md"
  if [[ -e $readme ]]; then
    printf 'docs/README.md already exists, left byte-identical\n' >&2
    printf '%s\n' "$readme"
    return $DL_OK
  fi

  local tmp="$docs/.README.md.$$"
  cat > "$tmp" <<EOF
# Documentation

Diataxis mode: **reference**.
Last reviewed: $(dl_today).

This is the router. Every document below declares its mode in its own first lines.

| Directory | Mode | Answers |
| --- | --- | --- |
| \`tutorials/\` | tutorial | "I am new, walk me to a first success" |
| \`how-to/\` | how-to | "I have a goal, get me to it" |
| \`reference/\` | reference | "What exactly does this do" |
| \`explanation/\` | explanation | "Why is it like this" |
| \`decisions/\` | reference | Architecture decision records, append-only |
| \`sops/\` | how-to | Standard operating procedures |

A directory appears once it has something in it.
An empty directory is a promise nobody kept, so none are created ahead of need.

## The two rules

**Every document declares its mode and its review date.**
\`docs.sh verify\` fails the build when one does not.

**A decision is superseded, never edited.**
A new record supersedes an old one and says so.
Reading top-down, the current answer arrives before the one it replaced.
EOF
  dl_atomic "$tmp" "$readme"
  printf '%s\n' "$readme"
}

# ---------------------------------------------------------------------------
# adr
# ---------------------------------------------------------------------------
cmd_adr() {
  local project="" title="" context="" decision="" consequences=""
  local status="proposed" supersedes=""
  while [[ $# -gt 0 ]]; do
    case $1 in
      --project)      project=${2:-}; shift 2 ;;
      --title)        title=${2:-}; shift 2 ;;
      --context)      context=${2:-}; shift 2 ;;
      --decision)     decision=${2:-}; shift 2 ;;
      --consequences) consequences=${2:-}; shift 2 ;;
      --status)       status=${2:-}; shift 2 ;;
      --supersedes)   supersedes=${2:-}; shift 2 ;;
      -h|--help)      usage; exit $DL_OK ;;
      *) usage >&2; dl_die "$DL_USAGE" "unknown argument: $1" ;;
    esac
  done
  dl_need --project "$project"
  dl_need --title "$title"
  dl_need --context "$context"
  dl_need --decision "$decision"
  dl_need --consequences "$consequences"
  dl_project_ok "$project"

  case $status in
    proposed|accepted|superseded) ;;
    *) dl_die "$DL_VALIDATION" "--status must be proposed, accepted or superseded: $status" ;;
  esac

  local dir="$project/docs/decisions"
  mkdir -p "$dir" || dl_die "$DL_IO" "cannot create: $dir"
  dl_lock "$dir/.adr"

  if [[ -n $supersedes ]]; then
    local hit
    hit=$(find "$dir" -maxdepth 1 -name "$supersedes-*.md" -print -quit 2>/dev/null)
    [[ -n $hit ]] || dl_die "$DL_NOTFOUND" "no such decision to supersede: $supersedes"
  fi

  local id slug file tmp
  id=$(dl_next_id "$dir" ADR)
  slug=$(dl_slug "$title")
  file="$dir/$id-$slug.md"
  tmp="$dir/.$id.$$"

  {
    printf '# %s: %s\n\n' "$id" "$title"
    printf 'Diataxis mode: **reference**.\n'
    printf 'Status: **%s**.\n' "$status"
    printf 'Last reviewed: %s.\n' "$(dl_today)"
    [[ -n $supersedes ]] && printf 'Supersedes: %s.\n' "$supersedes"
    printf '\n## Context\n\n%s\n' "$context"
    printf '\n## Decision\n\n%s\n' "$decision"
    printf '\n## Consequences\n\n%s\n' "$consequences"
  } > "$tmp" || dl_die "$DL_IO" "cannot write: $tmp"

  dl_atomic "$tmp" "$file"
  dl_unlock
  printf '%s\n' "$id"
}

# ---------------------------------------------------------------------------
# sop
# ---------------------------------------------------------------------------
cmd_sop() {
  local project="" title="" purpose="" when="" steps=""
  while [[ $# -gt 0 ]]; do
    case $1 in
      --project) project=${2:-}; shift 2 ;;
      --title)   title=${2:-}; shift 2 ;;
      --purpose) purpose=${2:-}; shift 2 ;;
      --when)    when=${2:-}; shift 2 ;;
      --steps)   steps=${2:-}; shift 2 ;;
      -h|--help) usage; exit $DL_OK ;;
      *) usage >&2; dl_die "$DL_USAGE" "unknown argument: $1" ;;
    esac
  done
  dl_need --project "$project"
  dl_need --title "$title"
  dl_need --purpose "$purpose"
  dl_need --when "$when"
  dl_need --steps "$steps"
  dl_project_ok "$project"

  local dir="$project/docs/sops"
  mkdir -p "$dir" || dl_die "$DL_IO" "cannot create: $dir"
  dl_lock "$dir/.sop"

  local id slug file tmp
  id=$(dl_next_id "$dir" SOP)
  slug=$(dl_slug "$title")
  file="$dir/$id-$slug.md"
  tmp="$dir/.$id.$$"

  {
    printf '# %s: %s\n\n' "$id" "$title"
    printf 'Diataxis mode: **how-to**.\n'
    printf 'Last reviewed: %s.\n' "$(dl_today)"
    printf '\n## Purpose\n\n%s\n' "$purpose"
    printf '\n## When to run this\n\n%s\n' "$when"
    printf '\n## Steps\n\n%s\n' "$steps"
    printf '\n## Verification\n\n'
    printf 'A step that cannot be verified is a wish.\n'
    printf 'Record what the successful run actually printed.\n'
  } > "$tmp" || dl_die "$DL_IO" "cannot write: $tmp"

  dl_atomic "$tmp" "$file"
  dl_unlock
  printf '%s\n' "$id"
}

# ---------------------------------------------------------------------------
# verify
# ---------------------------------------------------------------------------
cmd_verify() {
  local project="" json=0
  while [[ $# -gt 0 ]]; do
    case $1 in
      --project) project=${2:-}; shift 2 ;;
      --json)    json=1; shift ;;
      -h|--help) usage; exit $DL_OK ;;
      *) usage >&2; dl_die "$DL_USAGE" "unknown argument: $1" ;;
    esac
  done
  dl_need --project "$project"
  dl_project_ok "$project"

  local docs="$project/docs"
  [[ -d $docs ]] || dl_die "$DL_NOTFOUND" "no docs/ directory - run '$SELF init' first"

  local checked=0 missing_mode=0 missing_date=0
  local -a bad_mode=() bad_date=()
  local f rel

  while IFS= read -r f; do
    [[ -n $f ]] || continue
    checked=$(( checked + 1 ))
    rel=${f#"$project/"}
    if ! head -20 "$f" | grep -qi 'Diataxis mode:'; then
      bad_mode+=("$rel"); missing_mode=$(( missing_mode + 1 ))
    fi
    if ! head -20 "$f" | grep -qi 'Last reviewed:'; then
      bad_date+=("$rel"); missing_date=$(( missing_date + 1 ))
    fi
  done < <(find "$docs" -type f -name '*.md' | sort)

  local failures=$(( missing_mode + missing_date ))

  if (( json )); then
    printf '{"checked":%d,"missing_mode":%d,"missing_date":%d,"ok":%s}\n' \
      "$checked" "$missing_mode" "$missing_date" \
      "$( (( failures == 0 )) && printf true || printf false )"
  else
    printf 'checked %d document(s) under %s\n' "$checked" "$docs" >&2
    local b
    for b in "${bad_mode[@]:-}";  do [[ -n $b ]] && printf '  no Diataxis mode:  %s\n' "$b" >&2; done
    for b in "${bad_date[@]:-}";  do [[ -n $b ]] && printf '  no review date:    %s\n' "$b" >&2; done
    (( failures == 0 )) && printf 'ok\n' >&2
  fi

  (( failures == 0 )) || exit $DL_VALIDATION
  return $DL_OK
}

# ---------------------------------------------------------------------------
main() {
  local sub=${1:-}
  [[ -n $sub ]] || { usage >&2; exit $DL_USAGE; }
  shift
  case $sub in
    init)   cmd_init "$@" ;;
    adr)    cmd_adr "$@" ;;
    sop)    cmd_sop "$@" ;;
    verify) cmd_verify "$@" ;;
    modes)  cmd_modes ;;
    -h|--help) usage ;;
    *) usage >&2; dl_die "$DL_USAGE" "unknown subcommand: $sub" ;;
  esac
}

main "$@"
