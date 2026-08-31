#!/usr/bin/env bash
#
# skill-sync.sh - installs the skills a project declares, and nothing else.
#
# skill-tool-version: 2.1.0
#
# `--plan` resolves and prints. `--boot` resolves and then applies: it builds
# every owned skill into a temp directory under .claude/cache/, renders the
# read-only notice into each SKILL.md, swaps each owned directory into place one
# at a time, removes the directories the last receipt says it installed and the
# manifest no longer asks for, writes the receipt and the stamp, fills the
# skills list between the markers in the project's CLAUDE.md, and finally
# replaces itself if the registry has a newer version of this file.
#
# That CLAUDE.md write is the one thing this script does outside .claude/skills/
# and it is a narrow one: the block between two marker lines it did not invent,
# rewritten with the names it installed, or nothing at all when the project's
# CLAUDE.md does not carry the pair. See fill_skills_block.
#
# The one rule the whole design is built around: ownership is per-directory,
# never per-parent. `.claude/skills/` is blanket gitignored, hand-authored
# project-only skills live in it beside the managed ones, and a directory this
# script did not install is one it must not read, touch, report or clean up.
# There is no `rm -rf` of the parent anywhere below, and the only names that can
# become a path are ones that passed NAME_RE - including the ones read back out
# of the receipt, which is a file on disk like any other.
#
# Rule 17, and this is the first thing in the repository that has to run under
# Git Bash: no `flock`, no `cmp`, no `diff`, and no TOML parser. The lock is a
# `mkdir`, which is atomic on every platform this runs on. The manifest parse
# below is hand-rolled for the same reason.
#
# No `set -e`. A sync that dies mid-way is a sync that took the session with it;
# every failure here is caught where it happens and turned into a loud message
# and exit 0.
set -uo pipefail

SELF=$(basename -- "${BASH_SOURCE[0]}")
# Resolved once, before anything changes the working directory, because the
# self-update path renames this exact file and `$0` alone may be a bare name
# found on PATH.
SELF_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)
SELF_PATH="${SELF_DIR:-.}/$SELF"

# ── paths, all relative to the project the sync was invoked in ─────────────────
# The hook runs `skill-sync --boot` with the project as the working directory,
# so the project root is the working directory and nothing else.
MANIFEST=".claude/skills.toml"
CACHE=".claude/cache"
SKILLS_DIR=".claude/skills"
RECEIPT="$CACHE/skills-receipt.json"
STAMP="$CACHE/.sync-stamp"
# The only file outside .claude/ this script ever writes, and only ever between
# the two marker lines below.
PROJECT_DOC="CLAUDE.md"

# The lock and the build directories are siblings of the stamp, and neither
# pattern can match the other: `.sync-lock` and `.sync-stamp` have a dash where
# `.sync.XXXXXX` has a dot. The sweep globs `.sync.*` and therefore cannot eat
# the lock or the stamp, which is why the names are shaped this way.
LOCK="$CACHE/.sync-lock"
BUILD_PREFIX="$CACHE/.sync."

# The churn guard. Two sessions opened a minute apart must not both sync.
STAMP_MAX_AGE=900

# The one failure mode that skips the EXIT trap is a hook timeout - a hard kill -
# and it is also the likeliest one. Anything left behind by it is swept on the
# next run rather than accumulating in a gitignored directory forever.
BUILD_MAX_AGE=3600

# The lock gets a much shorter window than the build directories, and for a
# reason worth stating: a lock is only ever held by a sync that is running, and
# a sync cannot outlive the 30-second hook that started it. Five minutes is far
# above any legitimate hold and far below the hour a temp directory may sit
# waiting to be swept. At an hour, one killed hook would block every session on
# the machine for the rest of that hour, silently.
LOCK_MAX_AGE=300

# Seconds to wait for another sync to finish before giving up on the lock.
# Overridable so the suite can prove the wait without spending it.
LOCK_WAIT=${SKILL_SYNC_LOCK_WAIT:-20}

# One of the two documented exceptions in the repository's PII policy: these are
# the addresses of specific published files in this specific public repo, and a
# <placeholder> here would resolve to a repository that does not exist.
SRC_REPO="jkkelley/dotfiles"
SRC_REF="main"
REGISTRY_URL="https://raw.githubusercontent.com/$SRC_REPO/$SRC_REF/claude/skills/registry.json"
SELF_URL="https://raw.githubusercontent.com/$SRC_REPO/$SRC_REF/claude/tools/skill-sync.sh"
# One request for the whole tree, then the directories wanted out of it. A skill
# is not always a single file - 20 of them ship scripts, tests and references -
# so a per-file raw fetch would need a file list nobody maintains. This is the
# same call skill-update.sh already makes for the same reason.
TARBALL_URL="https://codeload.github.com/$SRC_REPO/tar.gz/refs/heads/$SRC_REF"
PARTIAL_PATH="claude/tools/partials/read-only-notice.md.tmpl"
# The name of this tool's own row in the registry's `tools` block.
SELF_TOOL="skill-sync"

FETCH_ATTEMPTS=3

# A name becomes a directory under .claude/skills/, and one of them becomes an
# `rm -rf`. Anything with a slash, a dot-dot or a space in it is refused by name
# instead of being pasted into a path. Applied in two places that do not cover
# each other: `resolve` for manifest names, `read_previous` for receipt names.
NAME_RE='^[A-Za-z0-9][A-Za-z0-9._-]*$'

declare -A REG_HAS=()       # name -> 1 for every skill in the registry
declare -A REG_REQUIRES=()  # name -> space-separated dependency names
declare -A REG_VERSION=()   # name -> version, for the receipt
declare -A REG_SHA=()       # name -> sha256, for the receipt

# Everything in here is removed by the EXIT trap. One trap, one list: a second
# `trap ... EXIT` anywhere below would silently replace the first, and the thing
# it replaced would be the lock release.
CLEANUP=()
LOCK_HELD=""
REGISTRY_FILE=""
NOTICE_TMPL=""
BUILD=""

OWNED=()      # resolved from the manifest: what the project should have
UNKNOWN=()    # declared, and in no registry
PREVIOUS=()   # what the last receipt says this script installed
DROPPED=()    # previously installed, no longer declared - the only rm -rf set
INSTALLED=()  # what this run put in place
REMOVED=()    # what this run took away
MISSING=()    # in the registry, absent from the source tree
CLAIMED=()    # what the receipt this run writes will claim ownership of

cleanup() {
  local path
  for path in "${CLEANUP[@]}"; do
    [[ -n $path ]] && rm -rf -- "$path"
  done
  [[ -n $LOCK_HELD ]] && rm -rf -- "$LOCK"
  return 0
}
trap cleanup EXIT

usage() {
  cat <<EOF
$SELF - install the skills this project declares in .claude/skills.toml.

  $SELF --boot     the SessionStart entry point. Silent and exit 0 when there is
                   no manifest here, or when the last sync was under 15 minutes
                   ago. Otherwise resolves, prints the plan, and applies it.
  $SELF --plan     resolve and print the plan and stop. Ignores the stamp, takes
                   no lock, and writes nothing. Unlike --boot it reports failure
                   in its exit code: 1 when there is no manifest here and 1 when
                   the registry could not be read.
  $SELF --help     this text.

The plan is one tagged line per name:

  owned     the project should have this installed, declared or required
  previous  the last sync owned this, per the receipt
  dropped   the last sync owned it and the manifest no longer asks for it
  unknown   the manifest asks for it and the registry has no such skill

--boot replaces every owned directory under $SKILLS_DIR and removes every
dropped one. It never touches a directory it did not install, and it never
removes the parent. A directory the receipt does not claim is not its business.

It then rewrites the block between the skills markers in $PROJECT_DOC with the
names it installed, and leaves that file untouched when it carries no such
block.
EOF
}

# ── the loud failure ───────────────────────────────────────────────────────────
# Two requirements that must not be conflated, which is what `|| true` does:
# never kill the session, and never hide a failure. Exit 0 answers the first.
# These two lines answer the second, on stdout, because a SessionStart hook's
# stdout lands in the agent's context and its stderr does not.
#
# The caller follows this with write_receipt failed wherever a receipt can be
# written at all, so "the last sync did not work" survives the session that saw
# these two lines.
sync_failed() { # $1 = one-line reason
  printf '!! SKILL SYNC FAILED - %s\n' "$1"
  printf '!! Skills are as of %s. Say so before doing skill-dependent work.\n' "$(last_sync_date)"
}

last_sync_date() {
  local synced=""
  [[ -f $RECEIPT ]] && synced=$(json_string "$RECEIPT" synced)
  if [[ -n $synced ]]; then printf '%s' "${synced%%T*}"; else printf 'an unknown date'; fi
}

warn() { printf '%s: %s\n' "$SELF" "$1" >&2; }

# ── JSON, read with awk because jq is not a dependency this may take ───────────
# The registry is a pure function of the tree, rendered by skill-version.sh with
# one skill per line, and `verify` is a byte comparison against that generator -
# so the shape cannot drift without the gate going red first. That is what makes
# a line-oriented read safe here. A name the read fails to find is reported as
# `unknown` rather than silently resolving to nothing, which is the backstop.
load_registry() { # $1 = registry file
  local name reqs ver sha
  # `|` and not a tab. A tab is IFS whitespace, so bash collapses two of them
  # into one and a skill with no `requires` - 41 of the 43 - silently shifts its
  # version into the field after it. `|` cannot appear in a name that passed
  # NAME_RE, and empty fields between two of them survive.
  while IFS='|' read -r name reqs ver sha; do
    REG_HAS[$name]=1
    REG_REQUIRES[$name]=$reqs
    REG_VERSION[$name]=$ver
    REG_SHA[$name]=$sha
  done < <(awk '
    function members(seg,   s, out) {
      out = ""
      while (match(seg, /"[^"]*"/)) {
        s = substr(seg, RSTART + 1, RLENGTH - 2)
        seg = substr(seg, RSTART + RLENGTH)
        out = out (out == "" ? "" : " ") s
      }
      return out
    }
    # The tools block carries entries of the same shape that are not skills, so
    # the walk is bounded to the skills block explicitly rather than by pattern.
    /^[[:space:]]*"skills"[[:space:]]*:[[:space:]]*\{/ { inskills = 1; next }
    /^[[:space:]]*"tools"[[:space:]]*:[[:space:]]*\{/  { inskills = 0; next }
    /^[[:space:]]*\},?[[:space:]]*$/                   { inskills = 0; next }
    inskills && match($0, /^[[:space:]]*"[^"]+"[[:space:]]*:[[:space:]]*\{/) {
      key = $0
      sub(/^[[:space:]]*"/, "", key)
      sub(/".*/, "", key)
      reqs = ""
      if (match($0, /"requires"[[:space:]]*:[[:space:]]*\[[^]]*\]/)) {
        seg = substr($0, RSTART, RLENGTH)
        sub(/^"requires"[[:space:]]*:[[:space:]]*\[/, "", seg)
        reqs = members(seg)
      }
      print key "|" reqs "|" field($0, "version") "|" field($0, "sha256")
    }
    function field(line, k,   s) {
      if (!match(line, "\"" k "\"[[:space:]]*:[[:space:]]*\"[^\"]*\"")) return ""
      s = substr(line, RSTART, RLENGTH)
      sub(/^"[^"]*"[[:space:]]*:[[:space:]]*"/, "", s)
      sub(/"$/, "", s)
      return s
    }' "$1")
}

# The version of a tool - not a skill - from the registry's `tools` block. Used
# for exactly one thing: deciding whether this file is stale against upstream.
registry_tool_version() { # $1 = registry file, $2 = tool name
  awk -v want="$2" '
    /^[[:space:]]*"tools"[[:space:]]*:[[:space:]]*\{/  { intools = 1; next }
    /^[[:space:]]*"skills"[[:space:]]*:[[:space:]]*\{/ { intools = 0; next }
    /^[[:space:]]*\},?[[:space:]]*$/                   { intools = 0; next }
    intools && match($0, "^[[:space:]]*\"" want "\"[[:space:]]*:") {
      if (match($0, /"version"[[:space:]]*:[[:space:]]*"[^"]*"/)) {
        s = substr($0, RSTART, RLENGTH)
        sub(/^"[^"]*"[[:space:]]*:[[:space:]]*"/, "", s)
        sub(/"$/, "", s)
        print s
      }
      exit
    }' "$1" 2>/dev/null
}

# Members of a top-level JSON string array, one per line. Handles the array
# spanning lines, because the receipt is hand-written by part two and a
# formatter reaching it later must not change what it means.
json_array() { # $1 = file, $2 = key
  awk -v key="$2" '
    function emit(seg,   s) {
      while (match(seg, /"[^"]*"/)) {
        s = substr(seg, RSTART + 1, RLENGTH - 2)
        seg = substr(seg, RSTART + RLENGTH)
        print s
      }
    }
    state == 0 {
      if (!match($0, "\"" key "\"[[:space:]]*:[[:space:]]*\\[")) next
      $0 = substr($0, RSTART + RLENGTH)
      state = 1
    }
    state == 1 {
      j = index($0, "]")
      if (j) { emit(substr($0, 1, j - 1)); exit }
      emit($0)
    }' "$1" 2>/dev/null
}

json_string() { # $1 = file, $2 = key
  awk -v key="$2" '
    match($0, "\"" key "\"[[:space:]]*:[[:space:]]*\"[^\"]*\"") {
      s = substr($0, RSTART, RLENGTH)
      sub(/^"[^"]*"[[:space:]]*:[[:space:]]*"/, "", s)
      sub(/"$/, "", s)
      print s; exit
    }' "$1" 2>/dev/null
}

# ── the manifest ───────────────────────────────────────────────────────────────
# Hand-rolled, and deliberately not a TOML parser. It reads exactly one shape:
#
#   [skills]
#   use = [
#     "work-order",
#   ]
#
# Git Bash has no TOML parser and Rule 17 makes it a supported platform, so the
# choice is between this and a dependency that half the target machines cannot
# install. Anything the format grows beyond a list of names is a decision to
# revisit, not something to smuggle in by making this cleverer.
manifest_list() { # $1 = manifest file, $2 = section
  awk -v want="$2" '
    function emit(seg,   s) {
      while (match(seg, /"[^"]*"/)) {
        s = substr(seg, RSTART + 1, RLENGTH - 2)
        seg = substr(seg, RSTART + RLENGTH)
        if (s != "") print s
      }
    }
    { sub(/#.*/, "") }
    /^[[:space:]]*\[[A-Za-z0-9_.-]+\][[:space:]]*$/ {
      sec = $0
      sub(/^[[:space:]]*\[/, "", sec)
      sub(/\][[:space:]]*$/, "", sec)
      insec = (sec == want)
      collecting = 0
      next
    }
    insec && !collecting && /^[[:space:]]*use[[:space:]]*=/ {
      collecting = 1
      sub(/^[[:space:]]*use[[:space:]]*=[[:space:]]*/, "")
      sub(/^\[/, "")
    }
    collecting {
      j = index($0, "]")
      if (j) { emit(substr($0, 1, j - 1)); collecting = 0; next }
      emit($0)
      next
    }' "$1"
}

# ── the registry ───────────────────────────────────────────────────────────────
# Three attempts and no sleep between them. A SessionStart hook has a 30-second
# budget; spending it waiting rather than attempting is how a sync that would
# have succeeded on the second try times out on the first.
fetch_registry() { # $1 = destination
  local attempt
  command -v curl >/dev/null 2>&1 || return 2
  for ((attempt = 1; attempt <= FETCH_ATTEMPTS; attempt++)); do
    if curl -fsS --max-time 10 "$REGISTRY_URL" -o "$1" 2>/dev/null && [[ -s $1 ]]; then
      return 0
    fi
  done
  return 1
}

# ── resolution ─────────────────────────────────────────────────────────────────
# Breadth-first over `requires`, with a seen set so a dependency cycle
# terminates instead of running until the hook times out. The two real edges are
# both on work-order, from cartography and from living-docs.
#
# Agents are parsed out of the manifest and go no further: they carry no version
# and no registry row, so there is nothing to resolve them against. They are the
# half of the library with no loop at all, and a name under [agents] must never
# reach the skills set.
resolve() { # names on stdin; sets OWNED and UNKNOWN
  local -a queue=()
  local -A seen=()
  local name dep i=0

  while IFS= read -r name; do
    [[ -n $name ]] || continue
    if [[ ! $name =~ $NAME_RE ]]; then
      warn "refusing the name '$name': a skill name becomes a directory and this one is not a plain name"
      continue
    fi
    queue+=("$name")
  done

  OWNED=()
  UNKNOWN=()
  while ((i < ${#queue[@]})); do
    name=${queue[i]}
    i=$((i + 1))
    [[ -n ${seen[$name]:-} ]] && continue
    seen[$name]=1
    if [[ -z ${REG_HAS[$name]:-} ]]; then
      UNKNOWN+=("$name")
      continue
    fi
    OWNED+=("$name")
    for dep in ${REG_REQUIRES[$name]:-}; do
      queue+=("$dep")
    done
  done
  # Explicit, because a while loop returns the status of the last command in its
  # body and the last one here is a `for` over a list that is usually empty.
  return 0
}

# Sets PREVIOUS and DROPPED from the receipt. DROPPED is the only set that turns
# into an `rm -rf`, so every name in it is validated against NAME_RE first: the
# receipt is a file on disk in a gitignored directory, and a corrupt or crafted
# one saying `"../../.."` must be refused by name rather than pasted into a path.
# `resolve` does the same for manifest names, and neither check covers the other.
read_previous() {
  local name
  PREVIOUS=()

  if [[ -f $RECEIPT ]]; then
    while IFS= read -r name; do
      [[ -n $name ]] || continue
      if [[ ! $name =~ $NAME_RE ]]; then
        warn "ignoring the receipt entry '$name': it is not a plain skill name"
        continue
      fi
      PREVIOUS+=("$name")
    done < <(json_array "$RECEIPT" owned)
  fi
  return 0
}

# Previously installed, and the manifest no longer asks for it. Separate from
# read_previous because PREVIOUS has to be known before resolution runs - a run
# that fails at the registry still has to write a receipt that keeps claiming
# what it owns - and DROPPED cannot be known until after it.
compute_dropped() {
  local name owned_line
  DROPPED=()
  owned_line=$(printf ' %s ' "${OWNED[@]}")
  for name in "${PREVIOUS[@]}"; do
    [[ $owned_line == *" $name "* ]] || DROPPED+=("$name")
  done
  return 0
}

emit_plan() {
  plan_lines owned    "${OWNED[@]}"
  plan_lines previous "${PREVIOUS[@]}"
  plan_lines dropped  "${DROPPED[@]}"
  plan_lines unknown  "${UNKNOWN[@]}"
}

plan_lines() { # $1 = tag, rest = names
  local tag=$1
  shift
  (($#)) || return 0
  printf '%s\n' "$@" | sort | while IFS= read -r n; do printf '%-8s  %s\n' "$tag" "$n"; done
}

# Resolves and leaves the answer in OWNED and UNKNOWN. Returns non-zero only
# when the registry could not be read, having already said so.
resolve_project() {
  local rc
  REGISTRY_FILE=$(mktemp "${TMPDIR:-/tmp}/skill-sync-registry.XXXXXX") || {
    sync_failed "no writable temporary directory"
    return 1
  }
  # Added to the one cleanup list rather than trapped here. A second
  # `trap ... EXIT` would replace the trap that releases the lock.
  CLEANUP+=("$REGISTRY_FILE")
  local registry=$REGISTRY_FILE

  fetch_registry "$registry"
  rc=$?
  if ((rc == 2)); then
    sync_failed "curl is not installed, so the registry cannot be fetched"
    return 1
  elif ((rc != 0)); then
    sync_failed "registry unreachable after $FETCH_ATTEMPTS tries"
    return 1
  fi

  load_registry "$registry"
  if ((${#REG_HAS[@]} == 0)); then
    sync_failed "the registry was fetched but lists no skills"
    return 1
  fi

  resolve < <(manifest_list "$MANIFEST" skills)
}

stamp_is_fresh() {
  local mtime now
  [[ -f $STAMP ]] || return 1
  mtime=$(stat -c %Y "$STAMP" 2>/dev/null) || return 1
  [[ -n $mtime ]] || return 1
  now=$(date +%s)
  ((now - mtime < STAMP_MAX_AGE))
}

# Injectable so two runs can be compared byte for byte, per skill-testing.md.
# Nothing else in the script reads the clock for anything it writes.
now_iso() {
  if [[ -n ${SKILL_SYNC_NOW:-} ]]; then
    printf '%s' "$SKILL_SYNC_NOW"
  else
    date -u +%Y-%m-%dT%H:%M:%SZ
  fi
}

# ── the sweep ──────────────────────────────────────────────────────────────────
# The EXIT trap covers every ordinary failure. It does not cover a hard kill, and
# a hook that overruns its 30-second budget is killed rather than asked to stop -
# which makes the case the trap cannot handle also the likeliest one. Every run
# therefore clears what an earlier run could not, before it starts.
#
# The glob is `.sync.*`, which cannot match `.sync-lock` or `.sync-stamp`. That
# is why those two are spelled with a dash.
sweep_stale_builds() {
  local dir mtime now
  now=$(date +%s)
  for dir in "$BUILD_PREFIX"*; do
    [[ -d $dir ]] || continue
    mtime=$(stat -c %Y "$dir" 2>/dev/null) || continue
    [[ -n $mtime ]] || continue
    ((now - mtime > BUILD_MAX_AGE)) && rm -rf -- "$dir"
  done
  return 0
}

# ── the lock ───────────────────────────────────────────────────────────────────
# `mkdir` and not `flock`, per Rule 17: Git Bash has no flock, and its absence
# surfaces as a lock timeout that never happened - the least traceable error
# message available. `mkdir` is atomic on every platform this runs on.
#
# A lock older than LOCK_MAX_AGE belonged to a run that was killed, and is
# broken rather than waited out. Otherwise a single hook timeout would block
# every future session on the machine, permanently and silently.
take_lock() {
  local waited=0 now="" mtime=""
  while :; do
    if mkdir -- "$LOCK" 2>/dev/null; then
      LOCK_HELD=1
      return 0
    fi
    now=$(date +%s)
    mtime=$(stat -c %Y "$LOCK" 2>/dev/null) || mtime=""
    if [[ -n $mtime ]] && ((now - mtime > LOCK_MAX_AGE)); then
      warn "breaking $LOCK, left behind by a sync that was killed"
      rm -rf -- "$LOCK" 2>/dev/null
      if mkdir -- "$LOCK" 2>/dev/null; then
        LOCK_HELD=1
        return 0
      fi
    fi
    ((waited >= LOCK_WAIT)) && return 1
    waited=$((waited + 1))
    sleep 1
  done
}

# ── the source tree ────────────────────────────────────────────────────────────
# `--max-time 20` against a 30-second hook budget is deliberate. The budget is
# the real ceiling and three attempts cannot fit inside it; what that buys is
# that a slow network fails by being killed, which the sweep already handles,
# rather than by installing half a skill.
fetch_tarball() { # $1 = destination
  local attempt
  command -v curl >/dev/null 2>&1 || return 2
  for ((attempt = 1; attempt <= FETCH_ATTEMPTS; attempt++)); do
    if curl -fsSL --max-time 20 "$TARBALL_URL" -o "$1" 2>/dev/null && [[ -s $1 ]]; then
      return 0
    fi
  done
  return 1
}

# ── the read-only notice ───────────────────────────────────────────────────────
# The rendering contract is stated in the header of the template itself, because
# the template is the thing that is versioned and a convention written anywhere
# else would not travel with it:
#
#   1. discard every line up to and including the first blank line - the header,
#      which carries the version marker and must never reach the output
#   2. substitute %%SKILL_NAME%% with the skill's directory name
#   3. emit the rest byte for byte
#
# Insertion lands after the first `# ` heading, which puts it below the
# frontmatter without having to parse the frontmatter. An existing notice - the
# one 43 upstream SKILL.md files still carry inline - is removed first, so this
# is idempotent and so a copy installed during the transition carries the
# rendered notice rather than the stale inline one.
#
# A SKILL.md with no `# ` heading is left exactly as it was found. Rewriting the
# head of a file whose shape is not understood is worse than shipping it without
# the notice, and the caller says so loudly.
render_notice() { # $1 = SKILL.md, $2 = skill name
  local out=$1.rendered rc
  awk -v tmpl="$NOTICE_TMPL" -v name="$2" '
    BEGIN {
      header = 1
      while ((getline l < tmpl) > 0) {
        if (header) { if (l == "") header = 0; continue }
        gsub(/%%SKILL_NAME%%/, name, l)
        notice[++n] = l
      }
    }
    dropping { if ($0 ~ /^>/) next; dropping = 0; if ($0 == "") next }
    $0 == "> **This copy is read-only.**" { dropping = 1; next }
    eat_blank { eat_blank = 0; if ($0 == "") next }
    !done && /^# / {
      print
      print ""
      for (i = 1; i <= n; i++) print notice[i]
      print ""
      done = 1
      eat_blank = 1
      next
    }
    { print }
    END {
      if (n == 0) exit 4    # the template was unreadable or empty
      if (!done) exit 3     # no `# ` heading to insert after
    }
  ' "$1" > "$out" 2>/dev/null
  rc=$?
  if ((rc != 0)); then
    rm -f -- "$out"
    return $rc
  fi
  mv -f -- "$out" "$1" 2>/dev/null
}

# ── applying the plan ──────────────────────────────────────────────────────────
# The whole destructive half, in one place, in the order the design fixes:
# build everything, then swap one directory at a time, then remove only what the
# receipt claims. A kill during the build leaves the tree exactly as it was,
# because nothing has moved yet.
apply_plan() {
  local root="" name src target rc failed=0
  local -a staged=()
  INSTALLED=()
  REMOVED=()
  MISSING=()
  # Ownership survives an early return. A run that fails before it can work out
  # what it owns must not write a receipt claiming nothing, because "sync owns
  # nothing" is how a managed directory becomes an orphan.
  CLAIMED=("${PREVIOUS[@]}")

  BUILD=$(mktemp -d "${BUILD_PREFIX}XXXXXX" 2>/dev/null) || {
    sync_failed "no writable $CACHE to build in"
    return 1
  }
  CLEANUP+=("$BUILD")

  if ((${#OWNED[@]})); then
    fetch_tarball "$BUILD/src.tar.gz" || {
      sync_failed "the skills archive could not be downloaded after $FETCH_ATTEMPTS tries"
      return 1
    }
    # The archive root is <repo>-<ref>, but a ref with a slash in it mangles
    # that, so it is read out of the archive rather than assumed. awk and not
    # `head -1`: awk reads to EOF, so the upstream tar cannot die of SIGPIPE and
    # turn a good archive into a failed pipeline.
    root=$(tar -tzf "$BUILD/src.tar.gz" 2>/dev/null | awk -F/ 'NR == 1 { print $1 }')
    [[ -n $root ]] || {
      sync_failed "the downloaded skills archive is not a readable tarball"
      return 1
    }
    tar -xzf "$BUILD/src.tar.gz" -C "$BUILD" \
      "$root/claude/skills" "$root/$PARTIAL_PATH" 2>/dev/null || {
      sync_failed "the skills archive carries no claude/skills or no $PARTIAL_PATH"
      return 1
    }
    NOTICE_TMPL="$BUILD/$root/$PARTIAL_PATH"
    [[ -s $NOTICE_TMPL ]] || {
      sync_failed "the skills archive carries no $PARTIAL_PATH"
      return 1
    }
  fi

  # Build. Every owned skill is prepared in full before any of them is swapped.
  for name in "${OWNED[@]}"; do
    src="$BUILD/$root/claude/skills/$name"
    if [[ ! -f "$src/SKILL.md" ]]; then
      MISSING+=("$name")
      continue
    fi
    render_notice "$src/SKILL.md" "$name"
    rc=$?
    if ((rc == 3)); then
      # Nowhere to put it. Installing the skill without the notice beats
      # rewriting the head of a file whose shape is not understood.
      warn "$name/SKILL.md has no '# ' heading: installed without the read-only notice"
    elif ((rc != 0)); then
      sync_failed "the read-only notice could not be rendered into $name/SKILL.md"
      failed=1
    fi
    staged+=("$name")
  done
  if ((${#MISSING[@]})); then
    sync_failed "the registry lists ${MISSING[*]}, which the source tree does not have"
    failed=1
  fi

  # Swap, one directory at a time. `mkdir -p` on the parent and never anything
  # else: .claude/skills/ is shared with hand-authored skills and is not this
  # script's to create wholesale, empty, or replace.
  if ((${#staged[@]})); then
    mkdir -p -- "$SKILLS_DIR" 2>/dev/null || {
      sync_failed "$PWD/$SKILLS_DIR cannot be created"
      return 1
    }
  fi
  for name in "${staged[@]}"; do
    src="$BUILD/$root/claude/skills/$name"
    target="$SKILLS_DIR/$name"
    # Aside first, then in. `mv` onto an existing directory moves the source
    # *inside* it instead of replacing it, so these are two steps and not one.
    if [[ -e $target ]] && ! mv -f -- "$target" "$BUILD/replaced.$name" 2>/dev/null; then
      sync_failed "could not move $target aside; it is unchanged"
      failed=1
      continue
    fi
    if mv -f -- "$src" "$target" 2>/dev/null; then
      INSTALLED+=("$name")
    else
      [[ -e "$BUILD/replaced.$name" ]] && mv -f -- "$BUILD/replaced.$name" "$target" 2>/dev/null
      sync_failed "could not install $name; the copy that was there is back in place"
      failed=1
    fi
  done

  # Remove. Only names the receipt claimed, one directory at a time, and never
  # the parent. A name that got here passed NAME_RE in read_previous.
  for name in "${DROPPED[@]}"; do
    target="$SKILLS_DIR/$name"
    if [[ ! -e $target ]]; then
      REMOVED+=("$name")   # already gone; the sync no longer owns it either way
      continue
    fi
    if rm -rf -- "$target" 2>/dev/null; then
      REMOVED+=("$name")
    else
      sync_failed "could not remove $target, which the last sync installed"
      failed=1
    fi
  done

  claim_ownership
  ((failed == 0))
}

# What the receipt will say this script owns.
#
# A name is claimed when this run installed it, and also when a previous run
# installed it and the manifest still asks for it - a skill that failed to
# refresh is still one the sync owns and still one it may later remove. A name
# it never managed to install is not claimed, because claiming it would license
# the next sync to delete a directory this one did not create. That asymmetry is
# the whole point: orphan a managed directory, never delete a local one.
claim_ownership() {
  local name installed_line previous_line
  CLAIMED=()
  installed_line=$(printf ' %s ' "${INSTALLED[@]}")
  previous_line=$(printf ' %s ' "${PREVIOUS[@]}")
  for name in "${OWNED[@]}"; do
    if [[ $installed_line == *" $name "* || $previous_line == *" $name "* ]]; then
      CLAIMED+=("$name")
    fi
  done
  # A drop that did not happen is still owned, or the next run would walk away
  # from a directory it installed and leave it for good.
  for name in "${DROPPED[@]}"; do
    [[ -e "$SKILLS_DIR/$name" ]] && CLAIMED+=("$name")
  done
  return 0
}

# ── the receipt and the stamp ──────────────────────────────────────────────────
# The receipt answers one question nothing else can: which directories under
# .claude/skills/ this script installed. Everything else in it is for a human
# reading it after something behaved oddly.
#
# Written to a temp file and renamed, so a kill during the write leaves the
# previous receipt whole rather than half a JSON document.
#
# Nothing is escaped because nothing here can need it: names passed NAME_RE, and
# versions and hashes came out of a registry that `verify` compares byte for
# byte. The shape is the one json_array and json_string above can read back -
# the reader and the writer are the same file on purpose.
#
# On a failure the previous `synced` is kept rather than stamped with now. It is
# the date the two-line warning quotes, and moving it forward on a run that
# installed nothing would make that sentence a lie. `skills` is not preserved:
# it is diagnostic, there is no nested reader for it, and inventing one to carry
# a diagnostic across a failure is not worth the parser.
write_receipt() { # $1 = ok | failed
  local status=$1 tmp name first synced=""
  mkdir -p -- "$CACHE" 2>/dev/null || { warn "cannot create $CACHE, so no receipt was written"; return 1; }
  if [[ $status == ok ]]; then
    synced=$(now_iso)
  elif [[ -f $RECEIPT ]]; then
    synced=$(json_string "$RECEIPT" synced)
  fi

  tmp="$RECEIPT.tmp.$$"
  {
    printf '{\n'
    printf '  "synced": "%s",\n' "$synced"
    printf '  "source": "%s@%s",\n' "$SRC_REPO" "$SRC_REF"
    printf '  "status": "%s",\n' "$status"
    printf '  "owned": ['
    first=1
    for name in "${CLAIMED[@]}"; do
      ((first)) || printf ', '
      printf '"%s"' "$name"
      first=0
    done
    printf '],\n'
    printf '  "skills": {'
    first=1
    for name in "${INSTALLED[@]}"; do
      ((first)) || printf ','
      printf '\n    "%s": { "version": "%s", "sha256": "%s" }' \
        "$name" "${REG_VERSION[$name]:-}" "${REG_SHA[$name]:-}"
      first=0
    done
    ((first)) || printf '\n  '
    printf '}\n}\n'
  } > "$tmp" 2>/dev/null || {
    warn "cannot write $RECEIPT"
    rm -f -- "$tmp"
    return 1
  }
  mv -f -- "$tmp" "$RECEIPT" 2>/dev/null || {
    warn "cannot replace $RECEIPT"
    rm -f -- "$tmp"
    return 1
  }
  return 0
}

# Written only after a sync that worked. A failed sync deliberately leaves the
# stamp alone: the guard exists to stop two sessions a minute apart both doing
# the same work, and suppressing the next session's attempt - and with it the
# two-line warning that session would have printed - would turn a loud failure
# into a silent one fifteen minutes wide. That is the defect this design exists
# to remove, so the cost of retrying a broken fetch is accepted instead.
write_stamp() {
  mkdir -p -- "$CACHE" 2>/dev/null || return 1
  : > "$STAMP" 2>/dev/null || { warn "cannot write $STAMP"; return 1; }
  return 0
}

# ── the skills list in the project's CLAUDE.md ─────────────────────────────────
# project-scaffold's CLAUDE.md.tmpl ships a marker pair and names this script as
# the thing that writes between it. Nothing did, so a scaffolded project carried
# an empty pair for the rest of its life and the only record of what it actually
# holds was the receipt, which no agent reads.
#
# Names only, never versions, and that is a decision rather than an omission: a
# version table is wrong within a week, and a stale one is worse than none
# because an agent believes it. The receipt is where versions live, and it is
# written by the same run.
#
# The two markers below are matched as whole lines, byte for byte. Their text
# belongs to the template, not to this script, and a second spelling of them
# invented here would fill a block no template ships. The consequences of the
# match failing are therefore deliberate and are the same as the consequences of
# a project having no markers at all: nothing is written, and the sync still
# succeeds. A project may legitimately not carry the block, and rewriting a file
# whose shape is not understood is worse than leaving it alone - the same
# judgement render_notice makes about a SKILL.md with no heading.
MARK_BEGIN='<!-- skills:begin - generated by skill-sync, do not hand-edit -->'
MARK_END='<!-- skills:end -->'

# Reads CLAIMED, which is what the receipt written seconds earlier says is in
# place - installed by this run, or installed by an earlier one and still
# declared. Not OWNED: a skill the registry promises and the source tree does not
# have is owned and is not on disk, and a list naming a directory that is not
# there is the same lie as a stale version.
fill_skills_block() {
  local tmp rc names=""
  [[ -f $PROJECT_DOC ]] || return 0

  # LC_ALL=C so the order is a byte order. Two agents on two machines with two
  # locales must produce the same file or the block churns a diff back and forth
  # between them, which is exactly what the idempotency this write owes forbids.
  ((${#CLAIMED[@]})) && names=$(printf '%s\n' "${CLAIMED[@]}" | LC_ALL=C sort | tr '\n' ' ')

  # Built in the cache, which is gitignored, and not beside CLAUDE.md. A run
  # killed between the write and the rename must not leave a stray file in the
  # working tree for `git add -A` to pick up.
  tmp="$CACHE/claude-md.$$"
  CLEANUP+=("$tmp")
  awk -v begin="$MARK_BEGIN" -v end="$MARK_END" -v names="$names" '
    BEGIN { n = split(names, want, " ") }
    state == 0 {
      print
      if ($0 != begin) next
      print ""
      for (i = 1; i <= n; i++) print "- " want[i]
      if (n) print ""
      state = 1
      next
    }
    # Everything the block used to hold, dropped. The end marker is the only
    # line in here that is printed rather than replaced.
    state == 1 {
      if ($0 != end) next
      print
      state = 2
      next
    }
    { print }
    # A begin with no end after it, or no begin at all. The output is a file
    # with a hole in it either way, and the caller throws it away.
    END { if (state != 2) exit 3 }
  ' "$PROJECT_DOC" > "$tmp" 2>/dev/null
  rc=$?

  if ((rc != 0)); then
    rm -f -- "$tmp"
    ((rc == 3)) && return 0
    warn "could not read $PROJECT_DOC, so its skills list was left alone"
    return 1
  fi

  # Only written when it would change something, so an unchanged project is not
  # handed a modified mtime every fifteen minutes. A string comparison and not
  # `cmp`, which Rule 17 says is absent from Git Bash and from minimal images -
  # the file is one project's CLAUDE.md, so reading both is affordable.
  if [[ $(cat -- "$tmp" 2>/dev/null) == $(cat -- "$PROJECT_DOC" 2>/dev/null) ]]; then
    rm -f -- "$tmp"
    return 0
  fi
  if ! mv -f -- "$tmp" "$PROJECT_DOC" 2>/dev/null; then
    rm -f -- "$tmp"
    warn "could not write the skills list into $PROJECT_DOC"
    return 1
  fi
  printf '%s: %s now lists the %d skills between its markers.\n' \
    "$SELF" "$PROJECT_DOC" "${#CLAIMED[@]}"
  return 0
}

# ── self-update ────────────────────────────────────────────────────────────────
read_tool_version() { # $1 = file
  head -20 "$1" 2>/dev/null | awk '
    !got && match($0, /skill-tool-version:[[:space:]]*[0-9]+\.[0-9]+\.[0-9]+/) {
      s = substr($0, RSTART, RLENGTH)
      sub(/^skill-tool-version:[[:space:]]*/, "", s)
      print s
      got = 1
    }'
}

# Strictly newer, and a version that is not a plain triple is never newer. A
# published version older than the one on disk is a checkout running ahead of
# main, and re-fetching it every session would be a download loop with no end.
version_gt() { # $1 > $2
  local -a a b
  local i x y
  [[ $1 =~ ^[0-9]+\.[0-9]+\.[0-9]+$ && $2 =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || return 1
  IFS=. read -r -a a <<<"$1"
  IFS=. read -r -a b <<<"$2"
  for i in 0 1 2; do
    x=${a[i]}
    y=${b[i]}
    ((10#$x > 10#$y)) && return 0
    ((10#$x < 10#$y)) && return 1
  done
  return 1
}

self_update_failed() { # $1 = one-line reason
  printf '!! SKILL SYNC self-update failed - %s\n' "$1"
  printf '!! The skills themselves are current. This file is not.\n'
}

# Replaces this file with the published one, then runs the replacement once to
# prove it works. Real work has already happened by the time this is called, and
# it happened with the binary that is known to run.
#
# `mv`, never `cp`. Bash reads a script lazily, by byte offset, as it executes.
# `cp self self.bak && curl -o self` truncates and rewrites the live inode, so
# this shell resumes reading at the offset it had reached - inside a different
# file - and fails in ways that look like anything except a self-update bug.
# `mv self self.bak` is a rename: the inode survives, this shell keeps reading
# the bytes it started with, and `curl -o self` creates a new file beside it.
# The order below is that argument and must not be simplified into the other one.
#
# SKILL_SYNC_CHILD makes the recursion one deep by construction rather than by a
# counter that can be got wrong: the replacement is run with it set, and the
# first thing it does here is return.
self_update() { # "$@" from the entry point
  local have want got
  [[ -z ${SKILL_SYNC_CHILD:-} ]] || return 0
  [[ -n $REGISTRY_FILE && -f $REGISTRY_FILE ]] || return 0

  want=$(registry_tool_version "$REGISTRY_FILE" "$SELF_TOOL")
  have=$(read_tool_version "$SELF_PATH")
  [[ -n $want && -n $have ]] || return 0
  version_gt "$want" "$have" || return 0

  if [[ ! -w $SELF_PATH || ! -w ${SELF_DIR:-.} ]]; then
    self_update_failed "$SELF $want is published but $SELF_PATH is not writable"
    return 1
  fi

  mv -f -- "$SELF_PATH" "$SELF_PATH.bak" 2>/dev/null || {
    self_update_failed "could not set $SELF_PATH aside; it is unchanged at $have"
    return 1
  }
  if ! curl -fsS --max-time 20 "$SELF_URL" -o "$SELF_PATH" 2>/dev/null || [[ ! -s $SELF_PATH ]]; then
    rm -f -- "$SELF_PATH"
    mv -f -- "$SELF_PATH.bak" "$SELF_PATH"
    self_update_failed "could not download $SELF $want; rolled back to $have"
    return 1
  fi
  chmod +x "$SELF_PATH" 2>/dev/null

  # The proof is running it. A truncated download, a syntax error or a missing
  # interpreter all show up here and nowhere earlier.
  if SKILL_SYNC_CHILD=1 bash "$SELF_PATH" "$@"; then
    got=$(read_tool_version "$SELF_PATH")
    printf '%s: self-updated to %s.\n' "$SELF" "${got:-$want}"
    return 0
  fi
  rm -f -- "$SELF_PATH"
  mv -f -- "$SELF_PATH.bak" "$SELF_PATH"
  self_update_failed "$SELF $want does not run; rolled back to $have"
  return 1
}

# ── entry points ───────────────────────────────────────────────────────────────
# The hook fires in every project on the machine, including the ones that have
# never heard of this system. Silence is the correct output in most of them, and
# "silent" means both streams: a message on stderr is still a message in a
# terminal, and printing one on every session in every unrelated project is how
# a session-start hook gets uninstalled.
cmd_boot() {
  [[ -f $MANIFEST ]] || exit 0
  stamp_is_fresh && exit 0

  # The lock is a directory inside the cache, so the cache has to exist before
  # there is anywhere to take it. On a project's first ever sync there is a
  # manifest and nothing else, which is the single most common state this runs
  # in and the one where a missing mkdir reads as a lock that cannot be taken.
  mkdir -p -- "$CACHE" 2>/dev/null || {
    sync_failed "$PWD/$CACHE cannot be created, so nothing can be synced"
    exit 0
  }

  # Before the lock, because the debris being cleared is debris the lock's own
  # holder left behind when it was killed.
  sweep_stale_builds

  if ! take_lock; then
    sync_failed "another sync has held $LOCK for more than ${LOCK_WAIT}s"
    exit 0
  fi
  # The other sync may have finished while this one waited. Doing the same work
  # again immediately is exactly what the stamp exists to prevent.
  stamp_is_fresh && exit 0

  read_previous
  if ! resolve_project; then
    # Nothing was resolved, so nothing was installed and nothing was removed.
    # The receipt keeps claiming exactly what it claimed before, or a registry
    # outage would quietly disown every managed directory in the project.
    CLAIMED=("${PREVIOUS[@]}")
    write_receipt failed
    exit 0
  fi
  compute_dropped
  emit_plan

  if ! apply_plan; then
    write_receipt failed
    exit 0
  fi
  write_receipt ok
  write_stamp
  printf '%s: %d skills in place (%d installed, %d removed). Source %s@%s.\n' \
    "$SELF" "${#CLAIMED[@]}" "${#INSTALLED[@]}" "${#REMOVED[@]}" "$SRC_REPO" "$SRC_REF"

  # After the receipt, and only after an apply that worked. The block is a
  # restatement of what the receipt already says, so a run that could not write
  # the receipt has nothing truthful to put in it.
  fill_skills_block

  self_update "$@"
  exit 0
}

# --plan is not a session, so it does not owe a session an exit 0. Exit 0 exists
# to stop a SessionStart hook taking the session with it, and reporting success
# to a human or a script that asked a direct question would be the other half of
# the `|| true` mistake rather than a smaller version of it.
cmd_plan() {
  [[ -f $MANIFEST ]] || {
    warn "no $MANIFEST in $PWD - this project does not use the skills manifest"
    exit 1
  }
  read_previous
  resolve_project || exit 1
  compute_dropped
  emit_plan
  exit 0
}

(($#)) || { usage >&2; exit 2; }
case $1 in
  --boot) cmd_boot "$@" ;;   # forwarded so self_update can re-run the replacement
  --plan) cmd_plan ;;
  --help | -h) usage; exit 0 ;;
  *) printf '%s: unknown argument: %s\n' "$SELF" "$1" >&2; usage >&2; exit 2 ;;
esac
