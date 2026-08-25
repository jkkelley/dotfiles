#!/usr/bin/env bash
#
# skill-sync.sh - decides which skills a project should have installed.
#
# skill-tool-version: 1.0.0
#
# This is part one of the sync: resolution only. It reads the manifest, fetches
# the registry, resolves `requires` transitively, reads the receipt for what the
# previous sync owned, and prints the answer. It writes nothing, anywhere.
#
# Building the directories, rendering the read-only notice, swapping them into
# place, removing dropped ones, writing the receipt and the stamp, and the
# self-update path are all part two. The constants for the receipt and the stamp
# are here even though only part two writes them, so that the two halves cannot
# invent different paths for the same file.
#
# Rule 17, and this is the first thing in the repository that has to run under
# Git Bash: no `flock`, no `cmp`, no `diff`, and no TOML parser. The manifest
# parse below is hand-rolled for exactly that reason.
#
# No `set -e`. A sync that dies mid-way is a sync that took the session with it;
# every failure here is caught where it happens and turned into a loud message
# and exit 0.
set -uo pipefail

SELF=$(basename -- "${BASH_SOURCE[0]}")

# ── paths, all relative to the project the sync was invoked in ─────────────────
# The hook runs `skill-sync --boot` with the project as the working directory,
# so the project root is the working directory and nothing else.
MANIFEST=".claude/skills.toml"
RECEIPT=".claude/cache/skills-receipt.json"   # written by part two, read here
STAMP=".claude/cache/.sync-stamp"             # written by part two, read here

# The churn guard. Two sessions opened a minute apart must not both sync.
STAMP_MAX_AGE=900

# One of the two documented exceptions in the repository's PII policy: this is
# the address of a specific published file in this specific public repo, and a
# <placeholder> here would resolve to a repository that does not exist.
REGISTRY_URL="https://raw.githubusercontent.com/jkkelley/dotfiles/main/claude/skills/registry.json"
FETCH_ATTEMPTS=3

# A name becomes a directory under .claude/skills/ in part two, so it is checked
# here rather than there. Anything with a slash, a dot-dot or a space in it is
# refused by name instead of being pasted into a path.
NAME_RE='^[A-Za-z0-9][A-Za-z0-9._-]*$'

declare -A REG_HAS=()       # name -> 1 for every skill in the registry
declare -A REG_REQUIRES=()  # name -> space-separated dependency names

usage() {
  cat <<EOF
$SELF - resolve which skills this project should have installed.

  $SELF --boot     the SessionStart entry point. Silent and exit 0 when there is
                   no manifest here, or when the last sync was under 15 minutes
                   ago. Otherwise resolves and prints the plan.
  $SELF --plan     resolve and print the plan, ignoring the stamp. Unlike --boot
                   this reports failure in its exit code: 1 when there is no
                   manifest here and 1 when the registry could not be read.
  $SELF --help     this text.

The plan is one tagged line per name:

  owned     the project should have this installed, declared or required
  previous  the last sync owned this, per the receipt
  dropped   the last sync owned it and the manifest no longer asks for it
  unknown   the manifest asks for it and the registry has no such skill

This build resolves only. Nothing is installed, removed or written.
EOF
}

# ── the loud failure ───────────────────────────────────────────────────────────
# Two requirements that must not be conflated, which is what `|| true` does:
# never kill the session, and never hide a failure. Exit 0 answers the first.
# These two lines answer the second, on stdout, because a SessionStart hook's
# stdout lands in the agent's context and its stderr does not.
#
# Part two adds "status": "failed" to the receipt on this path. There is no
# receipt write here at all.
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
  local name reqs
  while IFS=$'\t' read -r name reqs; do
    REG_HAS[$name]=1
    REG_REQUIRES[$name]=$reqs
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
      print key "\t" reqs
    }' "$1")
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

emit_plan() {
  local -a previous=() dropped=()
  local name owned_line

  if [[ -f $RECEIPT ]]; then
    while IFS= read -r name; do
      [[ -n $name ]] && previous+=("$name")
    done < <(json_array "$RECEIPT" owned)
  fi

  owned_line=$(printf ' %s ' "${OWNED[@]}")
  for name in "${previous[@]}"; do
    [[ $owned_line == *" $name "* ]] || dropped+=("$name")
  done

  plan_lines owned    "${OWNED[@]}"
  plan_lines previous "${previous[@]}"
  plan_lines dropped  "${dropped[@]}"
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
  local registry rc
  registry=$(mktemp "${TMPDIR:-/tmp}/skill-sync-registry.XXXXXX") || {
    sync_failed "no writable temporary directory"
    return 1
  }
  # shellcheck disable=SC2064  # $registry is wanted now, not at trap time
  trap "rm -f -- '$registry'" EXIT

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

# ── entry points ───────────────────────────────────────────────────────────────
# The hook fires in every project on the machine, including the ones that have
# never heard of this system. Silence is the correct output in most of them, and
# "silent" means both streams: a message on stderr is still a message in a
# terminal, and printing one on every session in every unrelated project is how
# a session-start hook gets uninstalled.
cmd_boot() {
  [[ -f $MANIFEST ]] || exit 0
  stamp_is_fresh && exit 0

  resolve_project || exit 0
  emit_plan
  printf '%s: resolved %d skills. This build resolves only and installs nothing.\n' \
    "$SELF" "${#OWNED[@]}"
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
  resolve_project || exit 1
  emit_plan
  exit 0
}

(($#)) || { usage >&2; exit 2; }
case $1 in
  --boot) cmd_boot ;;
  --plan) cmd_plan ;;
  --help | -h) usage; exit 0 ;;
  *) printf '%s: unknown argument: %s\n' "$SELF" "$1" >&2; usage >&2; exit 2 ;;
esac
