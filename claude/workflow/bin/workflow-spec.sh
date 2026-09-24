#!/usr/bin/env bash
# workflow-spec.sh - read a workflow declaration and print the agent spec the spawner needs.
#
#   workflow-spec.sh --list                list every declared workflow
#   workflow-spec.sh --validate            validate every declaration against the meta-schema
#   workflow-spec.sh <workflow-id>         print the agent spec as JSON
#   workflow-spec.sh <workflow-id> --full  print the whole declaration, interpolated
#
# Why this exists at all: so that starting the right agent is a read, not a retype. The role,
# runtime, model, effort, context threshold, tool allowlist, tool denylist, command denylist and
# write boundary are declared once in schemas/workflows/<id>.workflow.json and consumed from there
# by bin/workflow-spawn.sh. Nothing in this script knows any of those values, which is the property
# that makes a spec authoritative rather than decorative: if the two ever disagree, the script has
# no opinion to disagree with.
# Rejected: a table of parameters in the spawner, which is the arrangement where a schema becomes a
# document describing a script instead of the source the script reads.
set -euo pipefail
# shellcheck source=bin/workflow-lib.sh disable=SC1091
. "$(dirname "$(readlink -f "$0")")/workflow-lib.sh"
wf_need jq

usage() { sed -n '3,8p' "$(readlink -f "$0")" | sed 's/^# \{0,1\}//'; }

case "${1:-}" in
  ""|-h|--help) usage; exit 0 ;;
  --list)
    printf 'id\tversion\ttitle\n'
    wf_list
    exit 0 ;;
  --validate)
    rc=0
    for f in "$WF_SCHEMA_DIR"/*.workflow.json; do
      [ -f "$f" ] || continue
      if wf_validate "$WF_SCHEMA_DIR/workflow.schema.json" "$f" >/dev/null; then
        printf 'ok  %s\n' "$(basename "$f")"
      else
        printf 'FAIL %s\n' "$(basename "$f")" >&2; rc=1
      fi
    done
    exit "$rc" ;;
esac

id="$1"; shift
file="$(wf_workflow_file "$id")"

# Interpolation happens before extraction, so a caller that pipes the agent spec into a runner never
# receives an unexpanded ${gate_command} it would have to know how to resolve.
if [ "${1:-}" = --full ]; then
  wf_interpolate < "$file"
  exit 0
fi

# The threshold is re-asserted here rather than trusted from the file. A declaration that reached
# disk without it would otherwise produce a spec that silently carries no threshold, and a seat with
# no threshold never compacts, which is the failure the field exists to prevent. The meta-schema
# makes it required; this makes a bypass of the meta-schema loud at the point of use.
jq -e '.agent.context_threshold_percent // empty' "$file" >/dev/null 2>&1 \
  || wf_die "workflow '$id' has no agent.context_threshold_percent; a spec without a threshold is not runnable"

# The version is read into a variable before the pipeline rather than inline. Two reads of one file
# inside a single pipeline trip SC2094 at info level, which the gate's `shellcheck -S style` treats
# as a failure even though both reads here are reads. Hoisting it is clearer anyway.
version="$(jq -r .version "$file")"
wf_interpolate < "$file" | jq --arg id "$id" --arg v "$version" \
  '.agent + {workflow: $id, workflow_version: $v}'
