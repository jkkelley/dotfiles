# shellcheck shell=bash
#
# common.sh - shared foundation for every project-scaffold tool.
#
# Sourced, never executed. Every function is prefixed ps_ so a project's own
# shell environment cannot collide with it.
#
# The invariants this file exists to guarantee:
#   - user input is written literally, never evaluated
#   - writes are atomic: build in a temp file, rename over the target
#   - concurrent writers serialise on a lock instead of racing for an ID
#   - every temp path is removed on exit, whether the run passed or failed
#   - stdout carries data only; every human word goes to stderr

# ---------------------------------------------------------------------------
# Exit codes. Agents branch on these numbers, never on message text.
# ---------------------------------------------------------------------------
readonly PS_OK=0
readonly PS_USAGE=2      # bad flag, missing required flag, empty required value
readonly PS_VALIDATION=3 # bad enum value, missing sentinel, malformed file
readonly PS_IO=4         # unreadable / unwritable path
readonly PS_LOCK=5       # another writer held the lock too long
readonly PS_NOTFOUND=6   # referenced ID does not exist

readonly PS_SCHEMA_VERSION=1
readonly PS_TOOL_VERSION=1

# Set by ps_parse_common; consulted by ps_emit_* .
PS_JSON=0
PS_PROJECT=""
PS_LOCK_TIMEOUT=10

# ---------------------------------------------------------------------------
# Output. Data on stdout, everything else on stderr.
# ---------------------------------------------------------------------------

ps_info() { printf '%s\n' "$*" >&2; }
ps_warn() { printf 'warning: %s\n' "$*" >&2; }

# ps_die <exit-code> <error-slug> <human message>
# In --json mode the slug is what an agent reads; the human message is for you.
ps_die() {
  local code="$1" slug="$2"
  shift 2
  if ((PS_JSON)); then
    printf '{"ok":false,"code":%d,"error":"%s","message":%s}\n' \
      "$code" "$slug" "$(ps_json_string "$*")"
  else
    printf 'error: %s\n' "$*" >&2
  fi
  exit "$code"
}

# ---------------------------------------------------------------------------
# JSON. Hand-rolled because the test image has no jq and we refuse to add a
# runtime dependency to a tool whose whole point is being always available.
# ---------------------------------------------------------------------------

# ps_json_string <text> -> a quoted, escaped JSON string
ps_json_string() {
  local s=${1-} out='' i ch
  for ((i = 0; i < ${#s}; i++)); do
    ch=${s:i:1}
    case $ch in
      '"') out+='\"' ;;
      '\') out+='\\' ;;
      $'\n') out+='\n' ;;
      $'\r') out+='\r' ;;
      $'\t') out+='\t' ;;
      *)
        # Escape remaining C0 control characters as \u00XX; pass everything
        # else (including UTF-8) through untouched.
        if [[ $ch < $'\x20' ]]; then
          printf -v ch '\\u%04x' "'$ch"
        fi
        out+=$ch
        ;;
    esac
  done
  printf '"%s"' "$out"
}

# ---------------------------------------------------------------------------
# Time. Injectable so determinism is provable rather than asserted.
# ---------------------------------------------------------------------------

ps_now() {
  if [[ -n ${SCAFFOLD_NOW-} ]]; then
    printf '%s' "$SCAFFOLD_NOW"
  else
    date -Iseconds
  fi
}

ps_today() {
  if [[ -n ${SCAFFOLD_NOW-} ]]; then
    printf '%s' "${SCAFFOLD_NOW%%T*}"
  else
    date -I
  fi
}

# ---------------------------------------------------------------------------
# Scratch space. One temp dir per run, removed on every exit path.
# ---------------------------------------------------------------------------

PS_SCRATCH=""

ps_scratch_init() {
  # Guarded with if/fi rather than `[[ ... ]] && return 0`: under `set -e` a
  # trailing false test would take the whole script down.
  if [[ -n $PS_SCRATCH ]]; then return 0; fi
  PS_SCRATCH=$(mktemp -d "${TMPDIR:-/tmp}/project-scaffold.XXXXXX") || {
    printf 'error: could not create a temporary directory\n' >&2
    exit "$PS_IO"
  }
  # Only the top-level shell installs the cleanup traps. Every caller reaches
  # this through `tmp=$(ps_tempfile)`, and bash runs an EXIT trap set inside a
  # command substitution when that substitution closes. That deleted the scratch
  # directory, and the file just created inside it, before the caller could use
  # the path it had printed. Leaking a temp directory is survivable; handing back
  # a path to a file that no longer exists is not.
  # INT and TERM re-raise after cleanup so the caller sees a real signal death.
  if [[ ${BASHPID:-$$} == "$$" ]]; then
    trap 'ps_cleanup' EXIT
    trap 'ps_cleanup; trap - INT; kill -INT $$' INT
    trap 'ps_cleanup; trap - TERM; kill -TERM $$' TERM
  fi
}

ps_cleanup() {
  if [[ -n $PS_SCRATCH && -d $PS_SCRATCH ]]; then
    rm -rf -- "$PS_SCRATCH"
  fi
  PS_SCRATCH=""
}

ps_tempfile() {
  ps_scratch_init
  mktemp "$PS_SCRATCH/tmp.XXXXXX"
}

# Create the scratch directory here, at source time, in the shell that will still
# be alive to clean it up. Left lazy, the first code to reach it was always a
# command substitution, so a subshell became the owner and tore the directory
# down on its way out - every ps_tempfile caller then got a path to a file that
# had already been removed. cmd_close in work-order.sh called this eagerly for
# its own reasons and was the only command that worked; this makes it the rule.
ps_scratch_init

# ---------------------------------------------------------------------------
# Input sanitising.
#
# Values reach the markdown verbatim - no shell ever evaluates them. The only
# transformation is defensive: a literal comment terminator inside a value
# would end the metadata block early and corrupt every downstream parse.
# ---------------------------------------------------------------------------

# The replacements are held in variables and expanded quoted. Bash 5.2 treats a
# bare `&` in a substitution replacement as "whatever the pattern matched", so
# an inline --&gt; would silently produce ---->gt;.
readonly PS_GT_ESCAPE='--&gt;'
readonly PS_LT_ESCAPE='&lt;!--'

# ps_sanitize_line <text> -> single line, comment-terminator neutralised
ps_sanitize_line() {
  local s=${1-}
  s=${s//$'\r'/}
  s=${s//$'\n'/ }
  s=${s//$'\t'/ }
  s=${s//-->/"$PS_GT_ESCAPE"}
  s=${s//<!--/"$PS_LT_ESCAPE"}
  # collapse runs of spaces, then trim
  while [[ $s == *"  "* ]]; do s=${s//  / }; done
  s=${s# }
  s=${s% }
  printf '%s' "$s"
}

# ps_sanitize_body <text> -> newlines preserved, terminator neutralised
ps_sanitize_body() {
  local s=${1-}
  s=${s//$'\r'/}
  s=${s//-->/"$PS_GT_ESCAPE"}
  s=${s//<!--/"$PS_LT_ESCAPE"}
  printf '%s' "$s"
}

# ---------------------------------------------------------------------------
# Locking. Every mutation of a managed file happens inside this.
# ---------------------------------------------------------------------------

# ps_with_lock <lockfile> <command...>
ps_with_lock() {
  local lockfile="$1"
  shift
  local lockdir
  lockdir=$(dirname -- "$lockfile")
  [[ -d $lockdir ]] || ps_die "$PS_IO" "lock_dir_missing" "lock directory does not exist: $lockdir"

  exec 9>"$lockfile" || ps_die "$PS_IO" "lock_open_failed" "cannot open lock file: $lockfile"
  if ! flock -w "$PS_LOCK_TIMEOUT" 9; then
    ps_die "$PS_LOCK" "lock_timeout" \
      "another writer held $lockfile for more than ${PS_LOCK_TIMEOUT}s"
  fi
  "$@"
  local rc=$?
  exec 9>&-
  return $rc
}

# ---------------------------------------------------------------------------
# Atomic write. Never leaves a half-written managed file behind.
# ---------------------------------------------------------------------------

# ps_atomic_install <source-temp-file> <destination>
ps_atomic_install() {
  local src="$1" dst="$2"
  local dstdir
  dstdir=$(dirname -- "$dst")
  [[ -w $dstdir ]] || ps_die "$PS_IO" "dir_not_writable" "directory is not writable: $dstdir"

  # Stage inside the destination directory so the rename cannot cross a
  # filesystem boundary and silently degrade into a copy.
  local staged
  staged=$(mktemp "$dstdir/.project-scaffold.XXXXXX") || \
    ps_die "$PS_IO" "stage_failed" "cannot stage a write in $dstdir"

  if [[ -e $dst ]]; then
    # Preserve the mode of the file being replaced.
    chmod --reference="$dst" "$staged" 2>/dev/null || true
  else
    chmod 0644 "$staged" 2>/dev/null || true
  fi

  cat -- "$src" >"$staged" || { rm -f -- "$staged"; ps_die "$PS_IO" "write_failed" "cannot write to $dstdir"; }
  mv -f -- "$staged" "$dst" || { rm -f -- "$staged"; ps_die "$PS_IO" "rename_failed" "cannot replace $dst"; }
}

# ---------------------------------------------------------------------------
# File helpers.
# ---------------------------------------------------------------------------

# ps_normalize_newlines <file> - strip CR so sentinel matching survives a file
# that has been touched on Windows. Operates on a temp copy, not the original.
ps_strip_cr() {
  local src="$1" out
  out=$(ps_tempfile)
  tr -d '\r' <"$src" >"$out"
  printf '%s' "$out"
}

# ps_has_sentinel <file> <sentinel-text>
ps_has_sentinel() {
  local file="$1" sentinel="$2"
  [[ -f $file ]] || return 1
  grep -qF -- "$sentinel" "$file"
}

# ps_ends_with_newline <file> - false for an empty file too, which is correct:
# appending to it must not assume a leading blank line exists.
ps_ends_with_newline() {
  local file="$1"
  [[ -s $file ]] || return 1
  [[ $(tail -c 1 -- "$file" | od -An -c | tr -d ' ') == '\n' ]]
}

# ---------------------------------------------------------------------------
# Entry files. Issues and backlog items are one file per entry, named
# <UTC-timestamp>-<suffix>.md. This replaced the monolithic ISSUES.md /
# BACKLOG.md plus sequential IDs (ISS-0043) in September 2026 (dotfiles #95):
# allocating a successor ID required a scan AND a lock over one shared file,
# which is exactly what two concurrent agents on a trunk-based workflow collide
# over - and even when the lock held, git still saw one file touched by every
# writer, so merges conflicted. A random 5-char suffix minted at write time
# needs no scan and no lock, and one file per entry means merges never meet.
# The cost: IDs are no longer dense or pronounceable, and "the next number"
# tells you nothing about recency. The timestamp in the filename carries
# ordering instead, which is all the read window ever used the number for.
# ---------------------------------------------------------------------------

# ps_now_utc_compact -> YYYYMMDDTHHMMSSZ, the filename-grade UTC timestamp.
# Filename timestamps fix the month shard, so they must be UTC: two agents in
# different timezones would otherwise mint the same moment into different
# shards, and the shard check would flag one of them.
ps_now_utc_compact() {
  if [[ -n ${SCAFFOLD_NOW-} ]]; then
    date -u -d "$SCAFFOLD_NOW" +%Y%m%dT%H%M%SZ
  else
    date -u +%Y%m%dT%H%M%SZ
  fi
}

# ps_now_utc -> YYYY-MM-DDTHH:MM:SSZ, the metadata-grade UTC timestamp.
ps_now_utc() {
  if [[ -n ${SCAFFOLD_NOW-} ]]; then
    date -u -d "$SCAFFOLD_NOW" +%Y-%m-%dT%H:%M:%SZ
  else
    date -u +%Y-%m-%dT%H:%M:%SZ
  fi
}

# ps_to_utc_compact <any-date-parseable-timestamp> -> YYYYMMDDTHHMMSSZ
# Used by migrate, where the filename must come from the entry's own recorded
# timestamp rather than from now. Prints nothing and returns non-zero when the
# value cannot be parsed, so the caller decides whether to die or skip.
ps_to_utc_compact() {
  date -u -d "$1" +%Y%m%dT%H%M%SZ 2>/dev/null
}

# ps_mint_suffix -> 5 random lowercase alphanumerics.
# SCAFFOLD_SUFFIX pins the result for tests, the same role SCAFFOLD_NOW plays
# for the clock. 36^5 names makes a collision unlikely rather than impossible,
# which is why creation retries with a fresh suffix instead of trusting this.
ps_mint_suffix() {
  if [[ -n ${SCAFFOLD_SUFFIX-} ]]; then
    printf '%s' "$SCAFFOLD_SUFFIX"
    return 0
  fi
  local s
  # head closes the pipe after 5 chars and tr dies of SIGPIPE; under pipefail
  # that 141 would kill the caller, so the `|| true` is load-bearing, not
  # decoration.
  s=$(tr -dc 'a-z0-9' </dev/urandom 2>/dev/null | head -c 5 || true)
  printf '%s' "$s"
}

# ---------------------------------------------------------------------------
# Atomic create-if-absent. The entry-file counterpart of ps_atomic_install.
# ---------------------------------------------------------------------------

# ps_atomic_create <source-temp-file> <destination>
# Returns 1 when the destination already exists so the caller can mint a fresh
# name and retry - a collision is expected input here, not an error. ln is the
# primitive: it is atomic and refuses to overwrite, which mv -n does not
# guarantee on every filesystem.
ps_atomic_create() {
  local src="$1" dst="$2"
  local dstdir
  dstdir=$(dirname -- "$dst")
  [[ -w $dstdir ]] || ps_die "$PS_IO" "dir_not_writable" "directory is not writable: $dstdir"

  local staged
  staged=$(mktemp "$dstdir/.project-scaffold.XXXXXX") || \
    ps_die "$PS_IO" "stage_failed" "cannot stage a write in $dstdir"
  chmod 0644 "$staged" 2>/dev/null || true

  cat -- "$src" >"$staged" || { rm -f -- "$staged"; ps_die "$PS_IO" "write_failed" "cannot write to $dstdir"; }
  if ln -- "$staged" "$dst" 2>/dev/null; then
    rm -f -- "$staged"
    return 0
  fi
  rm -f -- "$staged"
  return 1
}

# ---------------------------------------------------------------------------
# Entry lookup and reading.
# ---------------------------------------------------------------------------

# ps_newest_entries <dir> <count> -> newest-first entry paths, one per line.
# A count of 0 means "all of them" - the live backlog buckets are read in
# full, while issues/ and done/ take a real window. Filenames and shard
# directories both sort chronologically, so a reverse lexical sort of the
# full path IS the chronological order. The read window is a directory walk:
# there is no index file, so there is nothing to go stale.
ps_newest_entries() {
  local dir="$1" n="$2"
  [[ -d $dir ]] || return 0
  if ((n > 0)); then
    find "$dir" -type f -name '*.md' | sort -r | head -n "$n"
  else
    find "$dir" -type f -name '*.md' | sort -r
  fi
}

# ps_find_suffix <suffix> <dir...> -> every entry path carrying that suffix.
# Zero lines means not found; two or more means ambiguous - both are the
# caller's exit codes, not this function's.
ps_find_suffix() {
  local suffix="$1"
  shift
  local d
  for d in "$@"; do
    [[ -d $d ]] || continue
    find "$d" -type f -name "*-${suffix}.md"
  done
}

# ps_meta <file> <key> -> the value from the entry's HTML-comment metadata
# block. Parsing the comment rather than the prose is the whole point of
# writing that block in the first place.
ps_meta() {
  awk -v key="$2" '
    /^<!-- (issue|item)$/ { inblock = 1; next }
    inblock && /^-->$/ { exit }
    inblock && index($0, key ": ") == 1 { print substr($0, length(key) + 3); exit }
  ' "$1"
}

# ps_body_field <file> <key> -> the value of a `- key: value` body line.
ps_body_field() {
  awk -v key="$2" 'index($0, "- " key ": ") == 1 { print substr($0, length(key) + 5); exit }' "$1"
}

# ps_rewrite_tokens <value> <map-nameref> -> comma-separated tokens with any
# token present in the map replaced by its value. Unknown tokens pass through
# unchanged: dropping them would hide information, and `check` names whatever
# does not resolve.
ps_rewrite_tokens() {
  local val="$1"
  local -n _map="$2"
  [[ -z $val || $val == - ]] && { printf '%s' "${val:--}"; return 0; }
  local rest=$val tok out="" first=1
  local -a toks=()
  while [[ $rest == *,* ]]; do toks+=("${rest%%,*}"); rest=${rest#*,}; done
  toks+=("$rest")
  for tok in "${toks[@]}"; do
    tok=${tok// /}
    [[ -z $tok ]] && continue
    local mapped=${_map[$tok]-$tok}
    if ((first)); then out=$mapped; first=0; else out="$out, $mapped"; fi
  done
  printf '%s' "${out:--}"
}

# ---------------------------------------------------------------------------
# Tree validation. The `check` verb on log-issue.sh and backlog.sh funnels
# here. Findings accumulate in PS_CHECK_PROBLEMS; ps_check_report renders them.
# ---------------------------------------------------------------------------

PS_CHECK_PROBLEMS=()

ps_check_note() { PS_CHECK_PROBLEMS+=("$1"); }

# ps_check_refs <file> <census-nameref> <rel-path> - every refs:/resolves:
# token must be a well-formed suffix that exists in the census. A dangling
# target is a pointer to an entry that is not there, which is worse than no
# pointer at all.
ps_check_refs() {
  local f="$1" rel="$3"
  local -n _census="$2"
  local key val rest tok
  for key in refs resolves; do
    val=$(ps_meta "$f" "$key")
    [[ -z $val || $val == - ]] && continue
    rest=$val
    local -a toks=()
    while [[ $rest == *,* ]]; do toks+=("${rest%%,*}"); rest=${rest#*,}; done
    toks+=("$rest")
    for tok in "${toks[@]}"; do
      tok=${tok// /}
      [[ -z $tok || $tok == - ]] && continue
      if [[ ! $tok =~ ^[a-z0-9]{5}$ ]]; then
        ps_check_note "$rel: $key target '$tok' is not a 5-char suffix"
        continue
      fi
      [[ -n ${_census[$tok]-} ]] || \
        ps_check_note "$rel: $key target '$tok' does not exist anywhere in the tree"
    done
  done
}

# ps_check_tree <project> <issues|backlog>
# Validates the scope's subtree, plus the two properties that are only
# meaningful globally: duplicate suffixes and ref resolution, both of which
# span issues/ and backlog/.
ps_check_tree() {
  local project="$1" scope="$2"
  PS_CHECK_PROBLEMS=()

  # A hand-written monolith beside the directories is two sources of truth,
  # and two sources of truth is none. migrate exists precisely for this file.
  if [[ $scope == issues && -f $project/ISSUES.md ]]; then
    ps_check_note "ISSUES.md: old monolith present alongside issues/ - run: log-issue.sh migrate --project <dir>"
  fi
  if [[ $scope == backlog && -f $project/BACKLOG.md ]]; then
    ps_check_note "BACKLOG.md: old monolith present alongside backlog/ - run: backlog.sh migrate --project <dir>"
  fi

  # The suffix census covers BOTH trees regardless of scope: refs point across
  # trees, and a duplicate is ambiguous no matter where the second copy lives.
  declare -A census=()
  local f base suffix
  while IFS= read -r f; do
    base=$(basename -- "$f")
    suffix=${base##*-}
    suffix=${suffix%.md}
    census[$suffix]="${census[$suffix]-}$f "
  done < <(find "$project/issues" "$project/backlog" -type f -name '*.md' 2>/dev/null)

  for suffix in "${!census[@]}"; do
    local -a holders=()
    # The census value is space-separated, but these scripts run with
    # IFS=newline+tab, so the split needs its own IFS.
    local IFS=' '
    read -ra holders <<<"${census[$suffix]}"
    if ((${#holders[@]} > 1)); then
      ps_check_note "suffix '$suffix' is not unique: ${holders[*]}"
    fi
  done

  local root
  if [[ $scope == issues ]]; then root="$project/issues"; else root="$project/backlog"; fi

  if [[ -d $root ]]; then
    # Anything that is not an entry file or a .gitkeep is a hand edit.
    while IFS= read -r f; do
      ps_check_note "${f#"$project"/}: unexpected file - only <UTC-timestamp>-<suffix>.md entries belong here"
    done < <(find "$root" -type f ! -name '*.md' ! -name '.gitkeep')

    while IFS= read -r f; do
      local rel=${f#"$project"/}
      base=$(basename -- "$f")
      if [[ ! $base =~ ^[0-9]{8}T[0-9]{6}Z-[a-z0-9]{5}\.md$ ]]; then
        ps_check_note "$rel: filename is not <UTC-timestamp>-<suffix>.md"
        continue
      fi
      local ts=${base%%-*}
      suffix=${base##*-}
      suffix=${suffix%.md}
      local dirrel
      dirrel=$(dirname -- "$rel")
      # The shard a file sits in must be the shard its filename timestamp
      # implies, or the window walk visits it in the wrong month.
      local want
      if [[ $scope == issues ]]; then
        want="issues/${ts:0:4}/${ts:4:2}"
      else
        case $dirrel in
          backlog/now | backlog/next | backlog/later) want="$dirrel" ;;
          *) want="backlog/done/${ts:0:4}/${ts:4:2}" ;;
        esac
      fi
      if [[ $dirrel != "$want" ]]; then
        ps_check_note "$rel: sits in $dirrel but its timestamp places it in $want"
      fi

      local id; id=$(ps_meta "$f" id)
      if [[ -z $id ]]; then
        ps_check_note "$rel: metadata block has no id"
      elif [[ $id != "$suffix" ]]; then
        ps_check_note "$rel: id '$id' does not match the filename suffix '$suffix'"
      fi

      if [[ $scope == issues ]]; then
        [[ -n $(ps_meta "$f" logged) ]] || ps_check_note "$rel: metadata block has no logged"
        local sev; sev=$(ps_meta "$f" severity)
        case $sev in
          low | medium | high) : ;;
          *) ps_check_note "$rel: severity is missing or not low|medium|high" ;;
        esac
        [[ -n $(ps_meta "$f" area) ]] || ps_check_note "$rel: metadata block has no area"
        local field
        for field in Symptom Trigger Cause Resolution Verification; do
          grep -qF -- "- **${field}** - " "$f" || ps_check_note "$rel: missing the ${field} field"
        done
      else
        [[ -n $(ps_meta "$f" added) ]] || ps_check_note "$rel: metadata block has no added"
        grep -qF -- "- why: " "$f" || ps_check_note "$rel: missing the why field"
        grep -qF -- "- done-when: " "$f" || ps_check_note "$rel: missing the done-when field"
      fi

      ps_check_refs "$f" census "$rel"
    done < <(find "$root" -type f -name '*.md' | sort)
  fi

  ((${#PS_CHECK_PROBLEMS[@]} == 0))
}

# ps_check_report - render PS_CHECK_PROBLEMS and exit: 0 clean, 3 with every
# offending file named on stderr. Branch on the code, never the text.
ps_check_report() {
  if ((${#PS_CHECK_PROBLEMS[@]} == 0)); then
    if ((PS_JSON)); then printf '{"ok":true,"problems":[]}\n'; else ps_info "check: clean"; fi
    exit "$PS_OK"
  fi
  if ((PS_JSON)); then
    printf '{"ok":false,"problems":['
    local i
    for i in "${!PS_CHECK_PROBLEMS[@]}"; do
      ((i > 0)) && printf ','
      ps_json_string "${PS_CHECK_PROBLEMS[i]}"
    done
    printf ']}\n'
  else
    local prob
    for prob in "${PS_CHECK_PROBLEMS[@]}"; do printf 'check: %s\n' "$prob" >&2; done
  fi
  exit "$PS_VALIDATION"
}

# ---------------------------------------------------------------------------
# Project resolution and common flags.
# ---------------------------------------------------------------------------

ps_resolve_project() {
  local p="${1:-.}"
  [[ -d $p ]] || ps_die "$PS_IO" "project_missing" "no such directory: $p"
  (cd -- "$p" && pwd) || ps_die "$PS_IO" "project_unreadable" "cannot enter directory: $p"
}

# ps_require_value <flag-name> <value>
ps_require_value() {
  local name="$1" value="${2-}"
  [[ -n $value ]] || ps_die "$PS_USAGE" "required_empty" "--${name} is required and must not be empty"
}

# ps_require_enum <flag-name> <value> <allowed...>
ps_require_enum() {
  local name="$1" value="$2"
  shift 2
  local allowed=("$@") a
  for a in "${allowed[@]}"; do
    if [[ $value == "$a" ]]; then return 0; fi
  done
  ps_die "$PS_VALIDATION" "invalid_enum" \
    "--${name} must be one of: ${allowed[*]} (got: ${value})"
}

ps_is_tty() { [[ -t 0 && -t 1 ]]; }

# ps_prompt <label> <varname> - interactive fallback, only ever reached on a TTY
ps_prompt() {
  local label="$1" __var="$2" reply=""
  printf '%s: ' "$label" >&2
  IFS= read -r reply || reply=""
  printf -v "$__var" '%s' "$reply"
}
