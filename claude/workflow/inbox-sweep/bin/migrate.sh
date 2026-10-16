#!/usr/bin/env bash
# B21: copy-forward migration runner and rollback. Design: docs/design/inbox-sweep.md section 15, spec `migrations`.
#
#   migrate.sh migrate <dir>                       every pending record file under <dir>, one process per file
#   migrate.sh one <file>                          one record file (what `migrate` fans out to)
#   migrate.sh resolve <dir> <name>                path of the record file new runs read under the current pins
#   migrate.sh rollback <node> <to> <name> <sv> <dir>
#                                                  pin node <node> back to declaration version <to> and record <name>
#                                                  back to schema version <sv>, and set aside every record above <sv>
#
# A record file is <name>.json or <name>.jsonl (one record per line). Its schema_version says which version it is.
# `migrate` writes <name>.v<N>.json[l] BESIDE the original and never edits the original, so rollback needs no
# down-migration: the old record is still there. A migration is a script migrations/<name>/v<N-1>-to-v<N>.sh, one JSON
# record on stdin, the new record on stdout.
#
# Why the runner checks the text itself: an approval binds the sha256 of the text, never the schema (design 15.3). A
# migration is somebody else's script, so "it would change an approved text" is verified here on every record, in and
# out, and the migration is refused with no file written. Trusting each migration to behave is the alternative that was
# rejected: one buggy script would then alter approved bytes with nothing standing between it and the owner's decision.
# Cost: only records carrying `text` and `text_sha256` are guarded; every other field may change freely.
#
# Pins live in $MIGRATE_PINS (default under $SWEEP_STATE_DIR, outside the repository):
#   {"nodes": {"<id>": "<semver>"}, "records": {"<name>": <schema_version>}}
# With no pin for a name, the pinned version is the highest schemas/records/<name>.v<N>.schema.json.
#
# Environment (tests point these at fixtures): REC_SCHEMA_DIR, MIG_DIR, MIGRATE_PINS, MIGRATE_JOBS (default 4).
#
# Codes printed, one per file: MIG-OK, MIG-CURRENT (nothing pending), MIG-REFUSED-TEXT, MIG-NO-SCRIPT, MIG-FAILED-SCHEMA.
# Exit 0 only when no file was refused or failed. Each file is independent: one refusal never stops the others.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REC_SCHEMA_DIR="${REC_SCHEMA_DIR:-$HERE/schemas/records}"
MIG_DIR="${MIG_DIR:-$HERE/migrations}"
MIGRATE_PINS="${MIGRATE_PINS:-${SWEEP_STATE_DIR:-$HOME/.local/state/zenith/inbox-sweep}/pins.json}"
SELF="$HERE/bin/migrate.sh"

die() { echo "migrate.sh: $*" >&2; exit 2; }

record_name() { local b; b="$(basename "$1")"; b="${b%.jsonl}"; b="${b%.json}"; printf '%s' "${b%%.v[0-9]*}"; }
is_migrated_copy() { [[ "$(basename "$1")" =~ \.v[0-9]+\.jsonl?$ ]]; }

# highest schema version on disk for <name>, or empty when the name has no schemas
latest_schema() {
  local best=0 f n
  for f in "$REC_SCHEMA_DIR/$1".v*.schema.json; do
    [ -e "$f" ] || continue
    n="${f##*.v}"; n="${n%.schema.json}"
    [ "$n" -gt "$best" ] && best="$n"
  done
  [ "$best" -gt 0 ] && printf '%s' "$best"
  return 0
}

pinned_version() {
  local v=""
  [ -f "$MIGRATE_PINS" ] && v="$(jq -r --arg n "$1" '.records[$n] // empty' "$MIGRATE_PINS")"
  [ -n "$v" ] || v="$(latest_schema "$1")"
  printf '%s' "$v"
}

# first record's schema_version in a file (a .jsonl holds one version per file, by construction of the runner)
file_version() { head -n1 "$1" | jq -r '.schema_version // empty'; }

validate() { # <file> <name> <version>; every record in the file must satisfy that version's schema
  python3 -I - "$1" "$REC_SCHEMA_DIR/$2.v$3.schema.json" <<'PY'
import json, sys
from jsonschema import Draft202012Validator
v = Draft202012Validator(json.load(open(sys.argv[2])))
bad = 0
for line in open(sys.argv[1]):
    if not line.strip(): continue
    for e in v.iter_errors(json.loads(line)):
        print("  " + e.message); bad = 1
sys.exit(bad)
PY
}

text_pair() { jq -c '[.text, .text_sha256]' ; }

migrate_one() {
  local file="$1" name target have ext out tmp cur next script
  [ -f "$file" ] || die "no such file: $file"
  is_migrated_copy "$file" && return 0
  name="$(record_name "$file")"; target="$(pinned_version "$name")"
  [ -n "$target" ] || { echo "MIG-NO-SCRIPT $file: no schemas for record '$name'"; return 1; }
  have="$(file_version "$file")"
  [ -n "$have" ] || { echo "MIG-FAILED-SCHEMA $file: no schema_version"; return 1; }
  if [ "$have" -ge "$target" ]; then echo "MIG-CURRENT $file"; return 0; fi
  ext=".${file##*.}"; out="${file%"$ext"}.v$target$ext"
  [ -e "$out" ] && { echo "MIG-CURRENT $file (already has $(basename "$out"))"; return 0; }
  tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' RETURN
  cp "$file" "$tmp/cur"; cur="$have"
  while [ "$cur" -lt "$target" ]; do
    next=$((cur + 1)); script="$MIG_DIR/$name/v$cur-to-v$next.sh"
    [ -x "$script" ] || { echo "MIG-NO-SCRIPT $file: $script"; return 1; }
    : >"$tmp/next"
    while IFS= read -r line || [ -n "$line" ]; do
      [ -n "$line" ] || continue
      new="$(printf '%s\n' "$line" | bash "$script")" || { echo "MIG-FAILED-SCHEMA $file: $script exited non-zero"; return 1; }
      if [ "$(printf '%s' "$line" | text_pair)" != "$(printf '%s' "$new" | text_pair)" ]; then
        echo "MIG-REFUSED-TEXT $file: $script would change an approved text; supersede it under 14.5 and raise a new card"
        return 1
      fi
      printf '%s\n' "$new" >>"$tmp/next"
    done <"$tmp/cur"
    if ! msg="$(validate "$tmp/next" "$name" "$next")"; then
      echo "MIG-FAILED-SCHEMA $file: result is not valid v$next"; printf '%s\n' "$msg"; return 1
    fi
    mv "$tmp/next" "$tmp/cur"; cur="$next"
  done
  mv "$tmp/cur" "$out"
  echo "MIG-OK $file -> $(basename "$out")"
}

cmd_migrate() {
  local dir="${1:?usage: migrate <dir>}" rc=0
  [ -d "$dir" ] || die "no such directory: $dir"
  # one process per record file, in parallel (spec bottlenecks: "migrations" by record file); a failure in one is
  # reported and counted but never stops the rest, so xargs' own exit (123 when any child failed) is the signal
  find "$dir" -maxdepth 2 -type f \( -name '*.json' -o -name '*.jsonl' \) ! -name '*.v[0-9]*' -print0 \
    | xargs -0 -r -n1 -P "${MIGRATE_JOBS:-4}" bash "$SELF" one || rc=1
  return "$rc"
}

# The file new runs read for <name> under the current pins: the migrated copy at the pinned version if the original is
# older, otherwise the original. A run that started before a pin change reads its own nodes.lock, not this.
cmd_resolve() {
  local dir="${1:?dir}" name="${2:?name}" target base ext f best=""
  target="$(pinned_version "$name")"
  for f in "$dir/$name.json" "$dir/$name.jsonl"; do [ -f "$f" ] && base="$f"; done
  [ -n "${base:-}" ] || die "no record file for $name in $dir"
  if [ "$(file_version "$base")" -ge "$target" ]; then printf '%s\n' "$base"; return 0; fi
  ext=".${base##*.}"; f="${base%"$ext"}.v$target$ext"
  [ -f "$f" ] || die "$name is pinned to v$target but $f does not exist; run migrate first"
  printf '%s\n' "$f"
}

cmd_rollback() {
  local node="${1:?node}" to="${2:?to}" name="${3:?record name}" sv="${4:?schema version}" dir="${5:?dir}" f n tmp
  [[ "$to" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "TO must be semver, got '$to'"
  [[ "$sv" =~ ^[0-9]+$ ]] || die "schema version must be an integer, got '$sv'"
  [ -f "$REC_SCHEMA_DIR/$name.v$sv.schema.json" ] || die "no schema for $name v$sv"
  # the previous-version record must still be there: rollback restores it, it cannot invent it
  f=""; for n in "$dir/$name.json" "$dir/$name.jsonl"; do [ -f "$n" ] && f="$n"; done
  if [ -z "$f" ] || [ "$(file_version "$f")" -gt "$sv" ]; then die "no $name record at v$sv or below in $dir to roll back to"; fi
  mkdir -p "$(dirname "$MIGRATE_PINS")"
  [ -f "$MIGRATE_PINS" ] || echo '{"nodes":{},"records":{}}' >"$MIGRATE_PINS"
  tmp="$(mktemp)"
  jq --arg id "$node" --arg to "$to" --arg n "$name" --argjson sv "$sv" \
    '.nodes[$id]=$to | .records[$n]=$sv' "$MIGRATE_PINS" >"$tmp" && mv "$tmp" "$MIGRATE_PINS"
  # set aside, never delete: prune removes them after the retention, never before (design 15.3)
  for f in "$dir/$name".v[0-9]*.json "$dir/$name".v[0-9]*.jsonl; do
    [ -e "$f" ] || continue
    n="${f%.json*}"; n="${n##*.v}"
    [ "$n" -gt "$sv" ] && mv "$f" "$f.rolled-back"
  done
  echo "MIG-ROLLED-BACK $node -> $to, $name -> v$sv"
}

case "${1:-}" in
  migrate) shift; cmd_migrate "$@" ;;
  one) shift; migrate_one "${1:?file}" ;;
  resolve) shift; cmd_resolve "$@" ;;
  rollback) shift; cmd_rollback "$@" ;;
  *) echo "usage: migrate.sh migrate <dir> | one <file> | resolve <dir> <name> | rollback <node> <to> <name> <sv> <dir>" >&2; exit 2 ;;
esac
