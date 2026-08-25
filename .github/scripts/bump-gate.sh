#!/usr/bin/env bash
#
# bump-gate.sh - the reading half of .github/workflows/skill-pr-gate.yml.
#
# Version allocation happens at merge, on main, in the publisher. A pull request
# therefore carries the *intent* and never the number. This script is what reads
# that intent and refuses it when it does not hold up. It writes nothing, ever -
# not to the registry, not to a SKILL.md, not to the tree it is reading.
#
#   resolve    every changed skill gets a level, from a Bump: trailer or from a
#              parseable conventional title, and the resolution table is printed
#              so the outcome is readable before the merge button rather than
#              after it
#   detect     which changed skills ship a suite, and whether claude/tools/ or
#              .github/ changed, as GITHUB_OUTPUT lines
#   run-suite  one skill's suite, in a container, dispatching on whether the
#              suite containerises itself
#
# It lives in a script rather than inside the YAML because a shell block in a
# workflow can only be tested by pushing, and .github/scripts/testing/ drives
# every branch below against a fixture repository in a container. The workflow
# is the thin part on purpose.
#
# No -e. Both gates collect every failure and report them together: a
# contributor who gets one error, fixes it, pushes and gets the next one has
# paid for two CI rounds to learn what one round could have told them.
set -uo pipefail

SELF=$(basename "${BASH_SOURCE[0]}")
HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

# Pinned by digest per Rule 15. docker.io/bitnami/git:latest as of 2026-08-23.
# The same digest the living-docs, context-compaction and skill-versioning
# justfiles already run their suites on - a second digest for the same purpose
# is how a repository ends up with two answers to "what do the tests run on".
WRAP_IMAGE="docker.io/bitnami/git@sha256:1baa6ddbde79fa7ba2fdf441cea47c4f04fae067504d9265e416358db0879ab2"

die() { printf '%s: %s\n' "$SELF" "$1" >&2; exit 2; }

# The resolution itself is shared with publish.sh. Two halves of one pipeline
# that reach different conclusions about the same commit is the failure this
# whole design exists to prevent, so they run one copy of the code rather than
# two that agree today.
# shellcheck source=.github/scripts/bump-lib.sh
. "$HERE/bump-lib.sh"

usage() {
  cat <<EOF
$SELF resolve   --base <ref> --title-file <f> --body-file <f> [--repo <dir>]
$SELF detect    --base <ref> [--repo <dir>]
$SELF run-suite <skill-dir> [--print]

  resolve    Validate the Bump: trailers against what the branch actually
             changed, resolve a level for every changed skill, print the
             resolution table. Exit 1 if anything is unresolved or refused.

  detect     Print GITHUB_OUTPUT lines:
               skills=["a","b"]   changed skills that ship testing/run-tests.sh
               tools=true|false   anything under claude/tools/ changed
               gate=true|false    anything under .github/ changed

  run-suite  Run one suite. --print reports the dispatch (self|wrapped)
             without running anything.

Levels are major, minor and patch, and nothing else.
EOF
}

# ── shared ─────────────────────────────────────────────────────────────────────

BASE=""

require_base() {
  [[ -n $BASE ]] || die "--base is required"
  git -C "$REPO" rev-parse --verify -q "$BASE^{commit}" >/dev/null \
    || die "no such ref: $BASE"
}

# Three dots, so the comparison is against the merge base rather than against
# whatever the base branch has picked up since. A skill someone else changed on
# main is not a skill this branch has to account for.
changed_paths() { paths_in "$BASE...HEAD" "$@"; }
changed_skills() { skills_in "$BASE...HEAD"; }

# ── resolve ────────────────────────────────────────────────────────────────────

cmd_resolve() {
  local title_file="" body_file="" title body
  while [[ $# -gt 0 ]]; do
    case $1 in
      --base)       BASE=${2:-}; shift 2 ;;
      --repo)       REPO=${2:-}; shift 2 ;;
      --title-file) title_file=${2:-}; shift 2 ;;
      --body-file)  body_file=${2:-}; shift 2 ;;
      -h|--help)    usage; return 0 ;;
      *)            usage >&2; die "unknown option for resolve: $1" ;;
    esac
  done
  resolve_repo
  require_base
  [[ -n $title_file && -f $title_file ]] || die "--title-file must name a file"
  [[ -n $body_file  && -f $body_file  ]] || die "--body-file must name a file"

  title=$(head -n1 "$title_file")
  body=$(cat "$body_file")

  local -a errors=()
  local -A trailer_level=()
  local -a changed=()
  local s

  while IFS= read -r s; do
    skill_exists "$s" || continue
    changed+=("$s")
  done < <(changed_skills)

  # ── the trailers ────────────────────────────────────────────────────────────
  # Parsed out of the title and body joined the way the squash commit will join
  # them, because the repository is set to squash_merge_commit_message=PR_BODY
  # and squash_merge_commit_title=PR_TITLE. What the gate reads here is the
  # commit the publisher will read later, byte for byte.
  local parsed line name level
  parsed=$(printf '%s\n\n%s\n' "$title" "$body" | git -C "$REPO" interpret-trailers --parse 2>/dev/null)

  while IFS= read -r line; do
    [[ $line == Bump:* ]] || continue
    line=${line#Bump:}
    line=${line# }
    if [[ ! $line =~ ^([A-Za-z0-9._-]+)=([a-z]+)$ ]]; then
      errors+=("malformed trailer   Bump: $line   (want Bump: <skill>=<major|minor|patch>)")
      continue
    fi
    name=${BASH_REMATCH[1]}
    level=${BASH_REMATCH[2]}

    if [[ -n ${trailer_level[$name]+x} ]]; then
      errors+=("named twice         $name   (${trailer_level[$name]} and then $level)")
      continue
    fi
    case $level in
      major|minor|patch) ;;
      *) errors+=("bad level           $name=$level   (want major, minor or patch)"); continue ;;
    esac
    if ! skill_exists "$name"; then
      errors+=("no such skill       $name   (nothing at claude/skills/$name/SKILL.md)")
      continue
    fi
    # Captured, then matched against the variable. A grep -q in a pipeline
    # closes the pipe on its first hit, the upstream dies of SIGPIPE, and
    # pipefail reports the match as a failure.
    local found=0 c
    for c in ${changed[@]+"${changed[@]}"}; do [[ $c == "$name" ]] && found=1; done
    if [[ $found -eq 0 ]]; then
      errors+=("not changed here    $name   (the trailer names it, this branch never touched it)")
      continue
    fi
    trailer_level[$name]=$level
  done <<< "$parsed"

  # ── the level for every changed skill ───────────────────────────────────────
  local tlevel="" cur next src
  tlevel=$(title_level "$title" "$body") || tlevel=""

  local -a rows=()
  for s in ${changed[@]+"${changed[@]}"}; do
    if cur=$(registry_version "$s"); then
      if [[ -n ${trailer_level[$s]+x} ]]; then
        level=${trailer_level[$s]}; src="trailer"
      elif [[ -n $tlevel ]]; then
        level=$tlevel; src="title"
      else
        errors+=("unresolved          $s   (no Bump: trailer, and the title has no conventional type to fall back on)")
        continue
      fi
      next=$(next_version "$cur" "$level") || { errors+=("bad level           $s=$level"); continue; }
      rows+=("$(printf '%-26s %-9s -> %-9s %-6s %s' "$s" "$cur" "$next" "$level" "$src")")
    else
      # Absence from the registry is unambiguous, so a new skill needs no
      # trailer: the publisher stamps it at 1.0.0 with init.
      rows+=("$(printf '%-26s %-9s -> %-9s %-6s %s' "$s" "-" "1.0.0" "new" "absent from the registry")")
    fi
  done

  # ── report ──────────────────────────────────────────────────────────────────
  if [[ ${#changed[@]} -eq 0 ]]; then
    printf 'No skill changed on this branch. Nothing to resolve.\n'
  else
    printf '\n%-26s %-9s    %-9s %-6s %s\n' "skill" "current" "next" "level" "source"
    printf '%s\n' "$(printf '%.0s-' {1..78})"
    printf '%s\n' ${rows[@]+"${rows[@]}"}
    printf '\n'
    printf 'Nothing is written here. The publisher allocates these on main after the merge.\n'
  fi

  if [[ ${#errors[@]} -gt 0 ]]; then
    printf '\n' >&2
    printf '%s\n' "${errors[@]}" >&2
    cat >&2 <<EOF

Refusing. A version is allocated at merge, so the pull request has to say what
it wants and the gate has to be able to believe it. State one trailer per skill
in the pull request description, last paragraph, nothing after it:

  Bump: <skill>=major|minor|patch

A single-skill pull request needs no trailer at all when the title carries a
conventional type: feat is minor, fix is patch, a ! or a BREAKING CHANGE: footer
is major.
EOF
    return 1
  fi
  return 0
}

# ── detect ─────────────────────────────────────────────────────────────────────

cmd_detect() {
  while [[ $# -gt 0 ]]; do
    case $1 in
      --base)    BASE=${2:-}; shift 2 ;;
      --repo)    REPO=${2:-}; shift 2 ;;
      -h|--help) usage; return 0 ;;
      *)         usage >&2; die "unknown option for detect: $1" ;;
    esac
  done
  resolve_repo
  require_base

  local s json="" tools=false gate=false
  while IFS= read -r s; do
    [[ -f "$REPO/claude/skills/$s/testing/run-tests.sh" ]] || continue
    json+="${json:+,}\"$s\""
  done < <(changed_skills)

  [[ -n $(changed_paths claude/tools/) ]] && tools=true
  [[ -n $(changed_paths .github/) ]] && gate=true

  # An empty matrix is a workflow error in Actions rather than a skipped job,
  # so [] is a value the caller has to branch on and never a value it can feed
  # to fromJSON. The guard on the test job is load-bearing, not defensive.
  printf 'skills=[%s]\n' "$json"
  printf 'tools=%s\n' "$tools"
  printf 'gate=%s\n' "$gate"
}

# ── run-suite ──────────────────────────────────────────────────────────────────

# The suites are not uniform, and pretending they are is how a suite ends up
# running on the host. Three of the seven re-exec themselves into Podman and
# must be invoked directly; the other four expect to be started inside a
# container already, with the skill on /skill and a scratch mount on /work.
#
# The dispatch reads the suite rather than carrying a list, so a suite added
# later is handled without editing this file. Both ways of being wrong fail
# loudly: a self-execing suite wrapped by mistake finds no podman inside the
# container and says so, and a wrapped suite invoked directly finds no /work.
dispatch_of() {
  local script=$1
  if grep -qE '^[[:space:]]*[^#[:space:]].*\bpodman\b' "$script"; then
    printf 'self'
  else
    printf 'wrapped'
  fi
}

cmd_run_suite() {
  local dir="" print=0
  while [[ $# -gt 0 ]]; do
    case $1 in
      --print)   print=1; shift ;;
      -h|--help) usage; return 0 ;;
      -*)        usage >&2; die "unknown option for run-suite: $1" ;;
      *)         dir=$1; shift ;;
    esac
  done
  [[ -n $dir ]] || die "run-suite needs a skill directory"
  dir=$(cd "$dir" && pwd) || die "no such directory: $dir"
  local script="$dir/testing/run-tests.sh"
  [[ -f $script ]] || die "no suite at $script"

  local how work
  how=$(dispatch_of "$script")
  if [[ $print -eq 1 ]]; then printf '%s\n' "$how"; return 0; fi

  if [[ $how == self ]]; then
    printf '%s: %s runs its own container\n' "$SELF" "$(basename "$dir")"
    bash "$script"
  else
    printf '%s: %s is wrapped\n' "$SELF" "$(basename "$dir")"
    work=$(mktemp -d) || die "could not make a scratch directory"
    podman run --rm --userns=keep-id --network=none --entrypoint="" \
      -v "$dir:/skill:ro,Z" -v "$work:/work:Z" -w /work \
      "$WRAP_IMAGE" bash /skill/testing/run-tests.sh
  fi
}

# ── dispatch ───────────────────────────────────────────────────────────────────

(($#)) || { usage >&2; exit 2; }
case ${1-} in -h|--help) usage; exit 0 ;; esac
cmd=$1; shift
case $cmd in
  resolve)   cmd_resolve "$@" ;;
  detect)    cmd_detect "$@" ;;
  run-suite) cmd_run_suite "$@" ;;
  *)         usage >&2; die "unknown command: $cmd" ;;
esac
