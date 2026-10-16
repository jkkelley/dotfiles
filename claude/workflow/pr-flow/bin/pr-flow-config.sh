#!/usr/bin/env bash
# name: pr-flow-config.sh
# purpose: print one repository's resolved pr-flow config (defaults merged under its entry), or the list of repositories
# inputs: config/pr-flow.json (or PR_FLOW_CONFIG); argument: OWNER/NAME, or --list
# outputs: JSON on stdout; the list as one slug per line
# writes-to: nothing
# cleanup: none
set -uo pipefail
CFG=${PR_FLOW_CONFIG:-$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)/config/pr-flow.json}
[ -f "$CFG" ] || { echo "pr-flow-config: no config at $CFG" >&2; exit 4; }
case ${1:-} in
  --list) jq -r '.repos | keys[]' "$CFG" ;;
  */*) jq -e --arg r "$1" '.repos[$r] as $e | if $e == null then error("no entry for \($r)") else (.defaults * $e) + {repo: $r}
         | .clone = ((.clone // "") | sub("^~"; env.HOME)) end' "$CFG" 2>/dev/null || { echo "pr-flow-config: no entry for $1 in $CFG" >&2; exit 2; } ;;
  *) echo "usage: pr-flow-config.sh OWNER/NAME | --list" >&2; exit 2 ;;
esac
