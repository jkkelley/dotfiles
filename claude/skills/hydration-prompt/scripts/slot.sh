#!/usr/bin/env bash
# slot.sh - acquire and release a treehouse workbench, keyed by ticket ID.
#
# The close-out holds a slot for the ticket it is closing, and hands it back
# when it is finished. `treehouse status` is then the live map of which agent
# holds which workbench, and the key is the ticket ID rather than a directory
# nobody can attribute.
#
# THE WHOLE POINT OF THIS FILE IS THAT IT NEVER READS `$?` TO DECIDE WHETHER
# TREEHOUSE DID ANYTHING.
#
# `treehouse return` prompts when the worktree has uncommitted changes. With no
# TTY the prompt takes its default, the return is abandoned, the slot stays
# leased - and the process exits 0:
#
#     | Worktree has uncommitted changes. Clean and return? [Y/n] Aborted.
#       return rc                          0
#       final pool state                   1  leased  (held by gate-case-3)
#
# Probed in Podman against the real v2.3.0 binary on 2026-08-24 and again on
# 2026-08-30; written up in docs/worktree-workflow.md under "Verified". A
# caller that reads the exit code reports a successful close-out, moves on, and
# leaves a workbench held by a ticket that finished hours ago. So every verb
# here asks the pool what happened afterwards and reports THAT.
#
# The same reasoning runs the other way. `acquire` refuses when the holder
# already leases a slot, because treehouse itself does not: asking twice with
# one --lease-holder hands out a second slot and records the same holder
# against both. Observed, same probe.
#
# SECOND CALLER: skill-onboard.sh, which WO-20260824-c6b0 - "skill-onboard.sh
# brings an existing project onto the sync" adds. It has the same two
# obligations - take a slot so it never touches the user's working tree, and
# prove the slot went free - so it calls these verbs with
# `--holder skill-onboard` rather than growing its own copy. Nothing here is
# specific to a hydration entry, and nothing here should become specific to
# one.
#
# Exit codes match the fleet convention, with one addition:
#   0 ok  2 usage  3 validation  4 io  5 the pool disagrees with treehouse
#
# 5 is separate on purpose. "You called me wrong" and "treehouse reported
# success and the workbench is still held" need different reactions - the
# second one leaves a resource stranded and wants a human - and a caller that
# cannot tell them apart will retry the one case where retrying cannot help.
set -uo pipefail

readonly EX_OK=0 EX_USAGE=2 EX_VALIDATION=3 EX_IO=4 EX_POSTSTATE=5

die() { local code=$1; shift; printf 'slot: %s\n' "$*" >&2; exit "$code"; }
note() { printf 'slot: %s\n' "$*" >&2; }

usage() {
  cat <<'EOF'
slot.sh <command> [options]

  acquire  --holder LABEL [--repo DIR] [--fetch]
           Lease a workbench for LABEL and print its path on stdout, nothing
           else. Refuses when LABEL already holds one - treehouse would hand
           out a second and record LABEL against both. Skips the origin fetch
           unless --fetch is given.

  release  --holder LABEL [--path DIR] [--repo DIR]
           Hand the workbench back, then ask the pool whether LABEL still
           holds anything and exit 5 if it does. Never reads treehouse's exit
           code. A LABEL that holds nothing is already in the state release
           exists to reach, so that is success, not an error.

  holder   --holder LABEL [--repo DIR]
           Print the path LABEL leases. Exit 3 when it leases nothing. This is
           the primitive the other two assert with.

  status   [--repo DIR]
           The live map, one row per slot: HOLDER, name, path. An unleased
           slot has "-" for its holder.

Common: --help. --repo defaults to "." and must be inside the git repository
whose pool you mean; treehouse resolves the pool from the working directory.

Exit codes: 0 ok, 2 usage, 3 validation, 4 io, 5 the slot did not change hands.
EOF
}

# ---------------------------------------------------------------------------
# the pool

require_treehouse() {
  command -v treehouse >/dev/null 2>&1 || die "$EX_IO" \
    "treehouse is not on PATH - it installs to ~/.local/bin/treehouse and updates itself with 'treehouse update'"
}

# A label is compared against the raw JSON below, so it has to survive the trip
# unchanged. treehouse re-encodes a quote in a holder - `ho"ler` is stored as
# `ho\"ler` - and the comparison would then miss silently, which on the release
# path means reporting a clean hand-back that did not happen. Refuse the
# characters rather than escape them: a ticket ID and `skill-onboard` both pass,
# and anything that does not is a caller bug worth hearing about.
validate_label() {
  [[ -n $1 ]] || die "$EX_USAGE" "--holder is required"
  [[ $1 =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] || die "$EX_VALIDATION" \
    "--holder must be letters, digits, dot, underscore or dash, starting alphanumeric: got '$1'"
}

# `treehouse status --json` is a flat array of flat objects with one exception:
# "processes" is an array of objects, so splitting records on '},{' cuts a
# record in half whenever something is running inside a slot. Every record
# opens with the "name" key - Go renders struct fields in declaration order -
# so that is the split point.
th_records() {
  awk '{ gsub(/\},\{"name":"/, "}\n{\"name\":\""); print }'
}

# Sets SLOT_JSON. Not printed, because `j=$(pool_json)` would run die inside a
# command substitution where exit kills only the subshell, and the caller would
# carry on with an empty string and conclude the pool was empty - which is the
# one wrong answer that looks like a clean result.
SLOT_JSON=""
pool_json() {
  local repo=$1 out rc
  out=$(cd "$repo" 2>/dev/null && treehouse status --json 2>&1); rc=$?
  (( rc == 0 )) || die "$EX_IO" "treehouse status failed in $repo: $out"
  SLOT_JSON=$out
}

# The path LABEL leases, or "" for none. Keyed on the holder rather than on the
# path, and that is not a stylistic choice: a slot inspected from inside its own
# directory reports its status as "you're here" rather than "available", so a
# check reading the status field calls a returned slot occupied whenever the
# close-out is standing in it. lease_holder is cleared to "" on a successful
# return, so it answers the question that is actually being asked.
holder_path() {
  local label=$1 line p h
  while IFS= read -r line; do
    [[ $line == *'"lease_holder":"'* ]] || continue
    h=${line#*'"lease_holder":"'}; h=${h%%'"'*}
    [[ $h == "$label" ]] || continue
    [[ $line == *'"path":"'* ]] || continue
    p=${line#*'"path":"'}; p=${p%%'"'*}
    printf '%s\n' "$p"
    return 0
  done < <(printf '%s' "$SLOT_JSON" | th_records)
  return 1
}

# ---------------------------------------------------------------------------
# commands

cmd_acquire() {
  local label=$1 repo=$2 fetch=$3 held path out rc
  validate_label "$label"
  require_treehouse
  pool_json "$repo"

  if held=$(holder_path "$label"); then
    die "$EX_VALIDATION" "$label already holds $held - release it before acquiring another (treehouse would lease a second slot to the same holder without complaining)"
  fi

  local -a args=(--lease --lease-holder "$label")
  (( fetch )) || args+=(--no-fetch)
  out=$(cd "$repo" && treehouse get "${args[@]}" 2>/dev/null); rc=$?
  path=$out

  # Ask the pool, not the exit code. Symmetry with release is the point: if the
  # lease is not recorded then nothing was acquired, whatever rc said, and a
  # caller about to cd into $path deserves to hear that here.
  pool_json "$repo"
  held=$(holder_path "$label") || die "$EX_POSTSTATE" \
    "treehouse get exited $rc but the pool records no lease for $label - nothing was acquired"

  [[ $held == "$path" ]] || note "treehouse printed '$path', the pool records '$held' - using the pool"
  printf '%s\n' "$held"
}

cmd_release() {
  local label=$1 repo=$2 path=$3 held out rc
  validate_label "$label"
  require_treehouse
  pool_json "$repo"

  if ! held=$(holder_path "$label"); then
    # release asserts a post-state, and this one already holds. Failing here
    # would make a re-run of a close-out that already finished report a problem
    # it does not have.
    note "$label holds no slot - nothing to release"
    return "$EX_OK"
  fi
  [[ -n $path ]] || path=$held

  out=$(cd "$repo" && treehouse return "$path" --if-lease-holder "$label" 2>&1); rc=$?

  # THE LOAD-BEARING LINE. rc is printed as evidence and used for nothing.
  pool_json "$repo"
  if held=$(holder_path "$label"); then
    printf 'slot: treehouse return exited %s and said:\n' "$rc" >&2
    printf '%s\n' "$out" | sed 's/^/slot:   | /' >&2
    die "$EX_POSTSTATE" "$held is still leased to $label. Uncommitted changes in the slot are the usual cause: treehouse prompts, takes its no-TTY default, abandons the return and exits 0. Commit or discard them, then 'treehouse return $held --if-lease-holder $label'"
  fi
  printf 'released %s\n' "$path"
}

cmd_holder() {
  local label=$1 repo=$2 held
  validate_label "$label"
  require_treehouse
  pool_json "$repo"
  held=$(holder_path "$label") || die "$EX_VALIDATION" "$label holds no slot"
  printf '%s\n' "$held"
}

cmd_status() {
  local repo=$1 line n p h
  require_treehouse
  pool_json "$repo"
  while IFS= read -r line; do
    [[ $line == *'"name":"'* ]] || continue
    n=${line#*'"name":"'}; n=${n%%'"'*}
    p=${line#*'"path":"'}; p=${p%%'"'*}
    h=""
    if [[ $line == *'"lease_holder":"'* ]]; then
      h=${line#*'"lease_holder":"'}; h=${h%%'"'*}
    fi
    printf '%s\t%s\t%s\n' "${h:--}" "$n" "$p"
  done < <(printf '%s' "$SLOT_JSON" | th_records)
}

# ---------------------------------------------------------------------------

main() {
  local cmd=${1:-}; [[ -n $cmd ]] || { usage; exit "$EX_USAGE"; }
  case $cmd in -h|--help|help) usage; exit "$EX_OK" ;; esac
  shift

  local holder="" repo="." path="" fetch=0
  while (( $# )); do
    case $1 in
      --holder) holder=${2:-}; shift 2 ;;
      --repo)   repo=${2:-}; shift 2 ;;
      --path)   path=${2:-}; shift 2 ;;
      --fetch)  fetch=1; shift ;;
      -h|--help) usage; exit "$EX_OK" ;;
      *)        die "$EX_USAGE" "unknown option: $1" ;;
    esac
  done
  [[ -d $repo ]] || die "$EX_IO" "no such directory: $repo"

  case $cmd in
    acquire) cmd_acquire "$holder" "$repo" "$fetch" ;;
    release) cmd_release "$holder" "$repo" "$path" ;;
    holder)  cmd_holder "$holder" "$repo" ;;
    status)  cmd_status "$repo" ;;
    *)       die "$EX_USAGE" "unknown command: $cmd" ;;
  esac
}

main "$@"
