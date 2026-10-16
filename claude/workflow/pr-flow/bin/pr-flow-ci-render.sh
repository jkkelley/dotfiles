#!/usr/bin/env bash
# name: pr-flow-ci-render.sh
# purpose: render the pr-flow ci.yml or merge-on-green.yml template for one repository
# inputs: --template, --set KEY=VALUE, --out; templates/*.yml beside bin/
# outputs: the rendered workflow on stdout or at --out
# writes-to: --out only
# cleanup: none; the output is a tracked workflow file in the target repository
# pr-flow-ci-render.sh - render a pr-flow workflow template for one repository.
#
#   pr-flow-ci-render.sh --template ci|merge-on-green [--set KEY=VALUE]... [--out FILE]
#
# Keys, with defaults (pr-process.md section 10 holds the per-repository values):
#   WORKFLOWS       JSON array of workflow names merge-on-green waits on   ["ci"]
#   REQUIRED_CHECK  the check run that must pass on the head               ci-ok
#   DISPATCH        space list of workflow files started after a merge     (none)
#   PR_TARGETS      JSON array of make targets on a PR (get BASE_REF)      ["lint","test"]
#   MAIN_TARGETS    JSON array of make targets on push to main             ["lint-all","test-all"]
#   SETUP           make target run before each target, empty for none    (none)
#   CACHE_PATHS     path list for actions/cache                            ~/.cache
#   CACHE_KEYS      hashFiles() arguments                                  '**/uv.lock', '**/package-lock.json'
#
# Exit 2 on a bad argument or a placeholder left unrendered, so a half-rendered workflow never reaches a repository.
set -euo pipefail
here="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"
die() { echo "pr-flow-ci-render: $*" >&2; exit 2; }

# SC2088: the tilde is for actions/cache to expand on the runner, not for bash.
# shellcheck disable=SC2088
declare -A V=(
  [WORKFLOWS]='["ci"]' [REQUIRED_CHECK]='ci-ok' [DISPATCH]=''
  [PR_TARGETS]='["lint","test"]' [MAIN_TARGETS]='["lint-all","test-all"]' [SETUP]=''
  [CACHE_PATHS]='~/.cache' [CACHE_KEYS]="'**/uv.lock', '**/package-lock.json'"
)
tpl=""; out=""
while [ $# -gt 0 ]; do
  case "$1" in
    --template) tpl="${2:?--template needs a name}"; shift 2 ;;
    --out) out="${2:?--out needs a path}"; shift 2 ;;
    --set) kv="${2:?--set needs KEY=VALUE}"; k="${kv%%=*}"; [ -v "V[$k]" ] || die "unknown key $k"; V[$k]="${kv#*=}"; shift 2 ;;
    -h|--help) sed -n '3,15p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) die "unknown argument $1" ;;
  esac
done
case "$tpl" in ci|merge-on-green) ;; *) die "--template must be ci or merge-on-green" ;; esac
for k in WORKFLOWS PR_TARGETS MAIN_TARGETS; do
  jq -e 'type == "array" and length > 0 and all(type == "string")' <<<"${V[$k]}" >/dev/null 2>&1 \
    || die "$k must be a non-empty JSON array of strings"
  V[$k]="$(jq -c . <<<"${V[$k]}")"
done

body="$(cat "$here/templates/$tpl.yml")"
for k in "${!V[@]}"; do body="${body//@@$k@@/${V[$k]}}"; done
left="$(grep -o '@@[A-Z_]*@@' <<<"$body" | sort -u | tr '\n' ' ' || true)"
[ -z "$left" ] || die "unrendered placeholders: $left"
if [ -n "$out" ]; then mkdir -p "$(dirname "$out")"; printf '%s\n' "$body" > "$out"; else printf '%s\n' "$body"; fi
