#!/usr/bin/env bash
# brief.sh - agent to agent briefs and results are JSON with defined acceptance criteria, never prose.
#
#   brief.sh check        FILE                     brief valid against schemas/brief.schema.json
#   brief.sh result-check FILE [--brief BRIEF]     result valid, status done, every AC ticked with proof
#                                                  (with --brief: same AC ids, same brief id, same done token)
#   brief.sh new  [--config FILE] [--id X] [--from X] [--to X] [--subject X] [--result-file X] [--done-token X]
#                 [--ac 'AC1|statement|command|proof']... [--out FILE]
#                                                  build a brief from the template, a config file (a partial brief)
#                                                  and arguments, in that order of precedence; refuses to write an invalid one
#   brief.sh migrate FILE [--out FILE]             upgrade an older brief to the current schema, by migrations/brief/*.jq
#
# Owner rule 2026-10-16: "agent to agent prose sucks, schemas with defined AC always".
# Inputs come from a config file or arguments (Design principles 101 item 17); Make passes them as VAR=value.
# Validation is python-jsonschema through tools/validate-schema.sh. No bespoke validator: the wheel exists (item 4).
set -euo pipefail
HERE="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"
SCHEMAS="$HERE/schemas"
BRIEF_SCHEMA_ID="zenith.a2a.brief.v1"
# The producer version stamped on briefs this script writes and migrates. Bump with the schema, not on a whim.
BRIEF_VERSION="1.0.0"

die() { printf 'brief.sh: %s\n' "$*" >&2; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || die "$1 is required"; }
need jq; need python3

validate() { # <schema-file> <instance>
  "$HERE/tools/validate-schema.sh" "$1" "$2"
}

cmd_check() {
  [ $# -eq 1 ] || die "usage: brief.sh check FILE"
  [ -f "$1" ] || die "no such file: $1"
  jq -e . "$1" >/dev/null 2>&1 || die "$1 is not JSON; agent to agent briefs are JSON, not prose"
  validate "$SCHEMAS/brief.schema.json" "$1" || die "$1 fails brief.schema.json"
  printf 'ok  brief %s valid (%s acceptance criteria)\n' "$1" "$(jq '.acceptance_criteria | length' "$1")"
}

cmd_result_check() {
  local file="" brief=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --brief) brief="${2:?--brief needs a path}"; shift 2 ;;
      *) [ -z "$file" ] || die "usage: brief.sh result-check FILE [--brief BRIEF]"; file="$1"; shift ;;
    esac
  done
  [ -n "$file" ] || die "usage: brief.sh result-check FILE [--brief BRIEF]"
  [ -f "$file" ] || die "no such file: $file"
  jq -e . "$file" >/dev/null 2>&1 || die "$file is not JSON"
  validate "$SCHEMAS/result.schema.json" "$file" || die "$file fails result.schema.json"
  # A blocked result is schema-valid so a seat can report it, but it is not a finished result.
  [ "$(jq -r .status "$file")" = "done" ] || die "$file status is not done: $(jq -r '.blockers | join("; ")' "$file")"
  if [ -n "$brief" ]; then
    cmd_check "$brief" >/dev/null
    [ "$(jq -r .brief_id "$file")" = "$(jq -r .id "$brief")" ] || die "result brief_id does not match brief id"
    [ "$(jq -r .done_token "$file")" = "$(jq -r .done_token "$brief")" ] || die "result done_token does not match the brief's"
    local missing
    missing="$(jq -nr --slurpfile b "$brief" --slurpfile r "$file" \
      '($r[0].acceptance_criteria | map(.id)) as $have | $b[0].acceptance_criteria | map(.id) | map(select(. as $i | $have | index($i) | not)) | join(" ")')"
    [ -z "$missing" ] || die "result has no entry for acceptance criteria: $missing"
  fi
  printf 'ok  result %s valid, %s acceptance criteria ticked with proof\n' "$file" "$(jq '.acceptance_criteria | length' "$file")"
}

cmd_new() {
  local config="" out="" id="" from="" to="" subject="" rfile="" token="" acs=()
  while [ $# -gt 0 ]; do
    case "$1" in
      --config) config="${2:?}"; shift 2 ;;
      --id) id="${2:?}"; shift 2 ;;
      --from) from="${2:?}"; shift 2 ;;
      --to) to="${2:?}"; shift 2 ;;
      --subject) subject="${2:?}"; shift 2 ;;
      --result-file) rfile="${2:?}"; shift 2 ;;
      --done-token) token="${2:?}"; shift 2 ;;
      --ac) acs+=("${2:?}"); shift 2 ;;
      --out) out="${2:?}"; shift 2 ;;
      *) die "unknown argument: $1" ;;
    esac
  done
  local base ac_json='[]' a aid st kind proof
  base="$(cat "$HERE/templates/a2a/brief.json")"
  if [ -n "$config" ]; then
    [ -f "$config" ] || die "no such config: $config"
    base="$(jq -s '.[0] * .[1]' <(printf '%s' "$base") "$config")"
  fi
  for a in "${acs[@]+"${acs[@]}"}"; do
    IFS='|' read -r aid st kind proof <<<"$a"
    [ -n "$proof" ] || die "--ac wants 'ID|statement|proof_kind|proof', got: $a"
    ac_json="$(jq -c --arg i "$aid" --arg s "$st" --arg k "$kind" --arg p "$proof" '. + [{id:$i,statement:$s,proof_kind:$k,proof:$p}]' <<<"$ac_json")"
  done
  base="$(jq --arg at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --arg ver "$BRIEF_VERSION" \
            --arg id "$id" --arg from "$from" --arg to "$to" --arg subject "$subject" --arg rf "$rfile" --arg tok "$token" \
            --argjson acs "$ac_json" '
      .version = $ver | .at = $at
      | (if $id != "" then .id = $id else . end)
      | (if $from != "" then .from.name = $from else . end)
      | (if $to != "" then .to.name = $to else . end)
      | (if $subject != "" then .subject = $subject else . end)
      | (if $rf != "" then .output.result_file = $rf else . end)
      | (if $tok != "" then .done_token = $tok else . end)
      | (if ($acs | length) > 0 then .acceptance_criteria = $acs else . end)' <<<"$base")"
  tmp="$(mktemp)"; trap 'rm -f "${tmp:-}"' EXIT
  printf '%s\n' "$base" > "$tmp"
  cmd_check "$tmp" >/dev/null || die "refusing to write an invalid brief"
  if [ -n "$out" ]; then mkdir -p "$(dirname "$out")"; cp "$tmp" "$out"; printf 'ok  brief written: %s\n' "$out"; else cat "$tmp"; fi
}

cmd_migrate() {
  local file="" out=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --out) out="${2:?}"; shift 2 ;;
      *) [ -z "$file" ] || die "usage: brief.sh migrate FILE [--out FILE]"; file="$1"; shift ;;
    esac
  done
  [ -f "$file" ] || die "no such file: $file"
  local cur step=0 sid mig
  cur="$(cat "$file")"
  # A migration is migrations/brief/<schema id with / as _>.jq and produces the next schema. Chained until current.
  while :; do
    sid="$(jq -r '.schema // empty' <<<"$cur")"
    [ -n "$sid" ] || die "$file has no schema field; cannot tell what to migrate from"
    if [ "$sid" = "$BRIEF_SCHEMA_ID" ]; then break; fi
    mig="$HERE/migrations/brief/${sid//\//_}.jq"
    [ -f "$mig" ] || die "no migration from schema $sid (looked for $mig)"
    cur="$(jq --arg version "$BRIEF_VERSION" -f "$mig" <<<"$cur")"
    step=$((step+1)); [ "$step" -le 10 ] || die "migration chain longer than 10; a cycle?"
  done
  if [ -n "$out" ]; then printf '%s\n' "$cur" > "$out"; printf 'ok  migrated %s -> %s (%s step(s))\n' "$file" "$out" "$step"; else printf '%s\n' "$cur"; fi
}

tmp=""
verb="${1:-}"; [ $# -gt 0 ] && shift
case "$verb" in
  check) cmd_check "$@" ;;
  result-check) cmd_result_check "$@" ;;
  new) cmd_new "$@" ;;
  migrate) cmd_migrate "$@" ;;
  *) die "usage: brief.sh check|result-check|new|migrate ..." ;;
esac
