#!/usr/bin/env bash
# name: ci-select.sh
# purpose: decide which claude/workflow suite shards a pull request has to run, from the paths it changed
# inputs: changed paths on stdin, one per line; flags --config F (default ../config/ci-shards.json), --full
# outputs: two GITHUB_OUTPUT lines: workflow=true|false, then shards=<compact JSON array of shard names>
# writes-to: stdout only
# cleanup: none
#
# usage: git diff --name-only BASE...HEAD | ci-select.sh [--config F] ; ci-select.sh --full </dev/null
#
# The path list (roots, all_on, ignore, per-shard paths) lives in config/ci-shards.json, which says why each entry
# is there. Per path, in order: matches an all_on glob -> every shard; else every shard whose paths match; else
# matches an ignore glob -> none; else matches a roots glob -> every shard (fail safe); else none. Globs are bash
# [[ == ]] patterns. workflow=true iff shards is not []. --full ignores stdin and selects every shard (main, nightly).
#
# Why it lives here and not in .github/scripts/bump-gate.sh detect: the list is this suite's own dependency list,
# and the person adding a call to another skill is in this directory, next to this file and test_ci_job.sh.
set -euo pipefail
HERE="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
CONFIG="$HERE/../config/ci-shards.json"; FULL=0
while [ $# -gt 0 ]; do
  case "$1" in
    --config) CONFIG="${2:?--config needs a file}"; shift 2 ;;
    --full) FULL=1; shift ;;
    *) echo "ci-select: unknown argument $1" >&2; exit 2 ;;
  esac
done
[ -f "$CONFIG" ] || { echo "ci-select: no config $CONFIG" >&2; exit 2; }
mapfile -t ALL < <(jq -r '.shards[].name' "$CONFIG")
mapfile -t ALL_ON < <(jq -r '.all_on[]' "$CONFIG")
mapfile -t IGNORE < <(jq -r '.ignore[]' "$CONFIG")
mapfile -t ROOTS < <(jq -r '.roots[]' "$CONFIG")
declare -A sel=()
any_glob() { # any_glob <path> <globs...>
  local p="$1" g; shift
  for g in "$@"; do
    # shellcheck disable=SC2053
    [[ $p == $g ]] && return 0
  done
  return 1
}
select_all() { local n; for n in "${ALL[@]}"; do sel[$n]=1; done; }
if [ "$FULL" = 1 ]; then
  select_all
else
  while IFS= read -r p; do
    [ -n "$p" ] || continue
    if any_glob "$p" "${ALL_ON[@]}"; then select_all; continue; fi
    matched=0
    while IFS=$'\t' read -r name globs; do
      mapfile -t G < <(printf '%s' "$globs" | jq -r '.[]')
      if any_glob "$p" "${G[@]}"; then sel[$name]=1; matched=1; fi
    done < <(jq -r '.shards[] | [.name, (.paths | tojson)] | @tsv' "$CONFIG")
    [ "$matched" = 1 ] && continue
    any_glob "$p" "${IGNORE[@]}" && continue
    if any_glob "$p" "${ROOTS[@]}"; then select_all; fi
  done
fi
out=()
for n in "${ALL[@]}"; do [ -n "${sel[$n]:-}" ] && out+=("$n"); done
if [ "${#out[@]}" -eq 0 ]; then
  printf 'workflow=false\nshards=[]\n'
else
  printf 'workflow=true\nshards=%s\n' "$(printf '%s\n' "${out[@]}" | jq -Rnc '[inputs]')"
fi
