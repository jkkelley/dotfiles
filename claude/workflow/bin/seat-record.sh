#!/usr/bin/env bash
# seat-record.sh <outcome> [--commit SHA] [--note TEXT] [--set KEY=VALUE]... [--pane ID] [--workflow ID] [--ticket ID]
#
# A seat's last act: append one record, valid against its declaration's record schema, to the declaration's
# record.emitted_to. bin/seat-watch.sh reads that row as the seat's done, tells the principal and retires the seat.
#
# Workflow, ticket and link come from the seat dir's seat-link, found from --pane or HERDR_PANE_ID (herdr sets it in
# every pane). --workflow and --ticket override it, for a seat started before seat-link existed. The role, the
# workflow version and the record schema come from the declaration. --set adds a field the schema asks for, such as
# scaffold-review's findings=3; a value that parses as JSON is stored as JSON, otherwise as a string.
#
# BREADCRUMB - why this script exists.
# What broke: O-09 (17616c9) made done the seat's own record, and nothing told a seat to write one or gave it a way to.
#   The orchestration builder wrote no record for O-08 or O-09, so a live seat-watch on it could never report done; the
#   suite passed only because its fixtures wrote the row (orchestrator review of 17616c9, 2026-09-22). bearings-v2 had
#   `rime status` for exactly this job.
# Why this fix: one command that knows the schema, so a seat states an outcome and nothing else, and a row that would
#   not validate is refused before it reaches the file. Rejected: telling seats the row format in their brief, which is
#   prose a model reinterprets, and a row the watcher cannot parse is a done nobody hears.
# Cost: python3 with jsonschema on the host, the same validator tools/validate-schema.sh already requires.
set -euo pipefail
# shellcheck source=bin/workflow-lib.sh disable=SC1091
. "$(dirname "$(readlink -f "$0")")/workflow-lib.sh"
wf_need jq
BIN="$(dirname "$(readlink -f "$0")")"

outcome=""; pane="${HERDR_PANE_ID:-}"; wf=""; ticket=""; commit=""; note=""; sets=()
while [ $# -gt 0 ]; do
  case "$1" in
    --commit)   commit="${2:?--commit needs a sha}"; shift 2 ;;
    --note)     note="${2:?--note needs text}"; shift 2 ;;
    --set)      sets+=("${2:?--set needs KEY=VALUE}"); shift 2 ;;
    --pane)     pane="${2:?--pane needs a pane id}"; shift 2 ;;
    --workflow) wf="${2:?--workflow needs an id}"; shift 2 ;;
    --ticket)   ticket="${2:?--ticket needs an id}"; shift 2 ;;
    -h|--help)  sed -n '2,10p' "$(readlink -f "$0")" | sed 's/^# \{0,1\}//'; exit 0 ;;
    -*) wf_die "unknown flag $1" ;;
    *) [ -z "$outcome" ] || wf_die "one outcome only, got '$outcome' and '$1'"; outcome="$1"; shift ;;
  esac
done
[ -n "$outcome" ] || wf_die "usage: seat-record.sh <outcome> [--commit SHA] [--note TEXT] [--set KEY=VALUE]... [--pane ID] [--workflow ID] [--ticket ID]"

link='{}'
if [ -n "$pane" ] && [ -f "$(wf_state_dir)/seats/${pane//[^A-Za-z0-9_-]/_}/seat-link" ]; then
  link="$(cat "$(wf_state_dir)/seats/${pane//[^A-Za-z0-9_-]/_}/seat-link")"
fi
[ -n "$wf" ] || wf="$(jq -r '.workflow // empty' <<<"$link")"
[ -n "$wf" ] || wf_die "no seat-link for pane '${pane:-unset}' and no --workflow; cannot tell which declaration this record belongs to"
[ -n "$ticket" ] || ticket="$(jq -r '.ticket // empty' <<<"$link")"

decl="$("$BIN/workflow-spec.sh" "$wf" --full)"
schema="$(jq -c .record.schema <<<"$decl")"
dest="$(wf_state_dir)/$(jq -r '.record.emitted_to | sub("^state:"; "")' <<<"$decl")"

extra='{}'
for kv in "${sets[@]+"${sets[@]}"}"; do
  k="${kv%%=*}"; v="${kv#*=}"
  [ "$k" != "$kv" ] || wf_die "--set takes KEY=VALUE, got '$kv'"
  if jq -e . >/dev/null 2>&1 <<<"$v"; then extra="$(jq -c --arg k "$k" --argjson v "$v" '.[$k] = $v' <<<"$extra")"
  else extra="$(jq -c --arg k "$k" --arg v "$v" '.[$k] = $v' <<<"$extra")"; fi
done

# Every fact this script knows is offered; only the ones the declaration's schema names are kept, so one script serves
# every declaration and the schema, not this file, decides the row's shape.
row="$(jq -nc --arg wf "$wf" --arg v "$(jq -r .version <<<"$decl")" --arg at "$(wf_now)" --arg role "$(jq -r .agent.role <<<"$decl")" \
      --arg o "$outcome" --arg t "$ticket" --arg c "$commit" --arg n "$note" --arg p "$pane" \
      --argjson link "$link" --argjson extra "$extra" --argjson s "$schema" '
  {schema_version:"1.0.0", workflow:$wf, workflow_version:$v, at:$at, role:$role, outcome:$o}
  + (if $t != "" then {ticket:$t} else {} end)
  + (if $c != "" then {commit:$c} else {} end)
  + (if $n != "" then {note:$n} else {} end)
  + (if $p != "" then {pane:$p} else {} end)
  + (if $link.link_id then {link:$link.link_id} else {} end)
  + $extra
  | with_entries(select(.key as $k | $s.properties | has($k)))')"

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
printf '%s\n' "$schema" > "$tmp/schema.json"; printf '%s\n' "$row" > "$tmp/row.json"
"$WF_REPO/tools/validate-schema.sh" "$tmp/schema.json" "$tmp/row.json" \
  || wf_die "record for $wf does not validate against its declaration's record schema; nothing written"
mkdir -p "$(dirname "$dest")"
printf '%s\n' "$row" >> "$dest"
printf 'recorded %s -> %s\n' "$row" "$dest"
