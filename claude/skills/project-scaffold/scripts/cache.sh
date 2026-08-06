#!/usr/bin/env bash
#
# cache.sh - build and verify the derived agent cache.
#
# Everything under .claude/cache/ is DERIVED. Deleting the directory loses
# nothing; `cache.sh build` reconstructs it from the markdown. The cache never
# answers a question its sources cannot - it only reshapes them so an agent can
# read a field instead of parsing prose.
#
# Staleness is detected, never assumed: index.json records a sha256 per source
# file, and `verify` reports which slices no longer match.
#
# scaffold-version: 1

set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

readonly WINDOW=10
readonly SOURCES=(COMPASS.md ISSUES.md BACKLOG.md NAMING.md)

usage() {
  cat <<'EOF'
cache.sh - build or verify the derived agent cache

Usage:
  cache.sh build  [--project DIR] [--json]
  cache.sh verify [--project DIR] [--json]

build   regenerate every slice under .claude/cache/
verify  report whether each slice still matches its source (exit 3 if stale)

Slices:
  index.json        manifest: schema, built-at, sha256 per source file
  map.json          from COMPASS.md   - path, purpose, when-to-open
  issues.json       from ISSUES.md    - the top 10 entries, fields only
  open-issues.json  COMPUTED          - issues no later entry resolves
  backlog.json      from BACKLOG.md   - every item with its bucket
  naming.json       from NAMING.md    - rule rows by tier

The cache is derived. Delete it freely; build reconstructs it.

Exit codes: 0 ok, 2 usage, 3 stale, 4 io
EOF
}

(($#)) || { usage; exit "$PS_USAGE"; }

# --help must be handled before subcommand dispatch, or it is consumed as the
# command name and reported as an unknown command.
case ${1-} in --help | -h) usage; exit "$PS_OK" ;; esac

command="$1"; shift

while (($#)); do
  case $1 in
    --project) PS_PROJECT="${2-}"; shift 2 ;;
    --json) PS_JSON=1; shift ;;
    --help | -h) usage; exit "$PS_OK" ;;
    *) PS_JSON=0; ps_die "$PS_USAGE" "unknown_flag" "unknown flag: $1 (try --help)" ;;
  esac
done

project=$(ps_resolve_project "${PS_PROJECT:-.}")
cache_dir="$project/.claude/cache"

hash_of() {
  local f="$1"
  if [[ -f $f ]]; then
    sha256sum -- "$f" | cut -d' ' -f1
  else
    printf 'absent'
  fi
}

# --- ISSUES ---------------------------------------------------------------
# Emits one record per entry as NUL-free, tab-delimited fields, newest first.
# Parsing the metadata comment block rather than the prose is the whole point
# of writing that block in the first place.
issues_records() {
  local file="$1"
  [[ -f $file ]] || return 0
  awk '
    /^<!-- issue$/ { inblock = 1; id=""; logged=""; sev=""; area=""; tags=""; refs=""; res=""; next }
    inblock && /^-->$/ {
      printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n", id, logged, sev, area, tags, refs, res, title
      inblock = 0; next
    }
    inblock {
      split($0, kv, ": ")
      key = kv[1]
      val = substr($0, length(key) + 3)
      if (key == "id") id = val
      else if (key == "logged") logged = val
      else if (key == "severity") sev = val
      else if (key == "area") area = val
      else if (key == "tags") tags = val
      else if (key == "refs") refs = val
      else if (key == "resolves") res = val
      next
    }
    /^## ISS-/ { title = substr($0, index($0, " - ") + 3) }
  ' "$file"
}

build_issues() {
  local file="$project/ISSUES.md"
  local out="$cache_dir/issues.json"
  local tmp; tmp=$(ps_tempfile)
  local n=0 first=1

  printf '{"window":%d,"entries":[' "$WINDOW" >"$tmp"
  while IFS=$'\t' read -r id logged sev area tags refs res title; do
    [[ -z $id ]] && continue
    n=$((n + 1))
    if ((n > WINDOW)); then break; fi
    if ((first == 0)); then printf ',' >>"$tmp"; fi
    first=0
    printf '{"id":"%s","logged":%s,"severity":"%s","area":%s,"tags":%s,"refs":%s,"resolves":%s,"title":%s}' \
      "$id" "$(ps_json_string "$logged")" "$sev" "$(ps_json_string "$area")" \
      "$(ps_json_string "$tags")" "$(ps_json_string "$refs")" \
      "$([[ $res == "-" || -z $res ]] && printf 'null' || ps_json_string "$res")" \
      "$(ps_json_string "$title")" >>"$tmp"
  done < <(issues_records "$file")
  printf ']}\n' >>"$tmp"
  ps_atomic_install "$tmp" "$out"
}

# An issue is open when no later entry resolves it. This is the one thing the
# cache computes, and it is exactly what an append-only log cannot answer by
# reading a 10-entry window.
build_open_issues() {
  local file="$project/ISSUES.md"
  local out="$cache_dir/open-issues.json"
  local tmp; tmp=$(ps_tempfile)
  local resolved; resolved=$(ps_tempfile)

  if [[ -f $file ]]; then
    grep -E '^resolves: ISS-[0-9]{4}$' "$file" 2>/dev/null | sed 's/^resolves: //' | sort -u >"$resolved" || true
  else
    : >"$resolved"
  fi

  local first=1
  printf '{"open":[' >"$tmp"
  while IFS=$'\t' read -r id logged sev area tags refs res title; do
    [[ -z $id ]] && continue
    if grep -qxF -- "$id" "$resolved"; then continue; fi
    if ((first == 0)); then printf ',' >>"$tmp"; fi
    first=0
    printf '{"id":"%s","severity":"%s","area":%s,"logged":%s,"title":%s}' \
      "$id" "$sev" "$(ps_json_string "$area")" "$(ps_json_string "$logged")" \
      "$(ps_json_string "$title")" >>"$tmp"
  done < <(issues_records "$file")
  printf ']}\n' >>"$tmp"
  ps_atomic_install "$tmp" "$out"
}

# --- BACKLOG ---------------------------------------------------------------
# Reuses backlog.sh rather than re-implementing the parser: one parser, one set
# of bugs, one place to fix them.
build_backlog() {
  local out="$cache_dir/backlog.json"
  local tmp; tmp=$(ps_tempfile)
  if [[ -f $project/BACKLOG.md ]]; then
    bash "$SCRIPT_DIR/backlog.sh" list --project "$project" --json >"$tmp" 2>/dev/null || printf '[]\n' >"$tmp"
  else
    printf '[]\n' >"$tmp"
  fi
  ps_atomic_install "$tmp" "$out"
}

# --- markdown tables -------------------------------------------------------
# Rows whose cells are all placeholders are dropped: an unfilled template row
# is not data, and an agent treating it as data is worse than an empty slice.
table_rows_json() {
  local file="$1" tmp="$2" label="$3"
  local first=1
  printf '{"%s":[' "$label" >>"$tmp"
  if [[ -f $file ]]; then
    while IFS= read -r line; do
      [[ $line == \|*\| ]] || continue
      [[ $line == *---* ]] && continue
      local body="${line#|}"; body="${body%|}"
      local -a cells=()
      local IFS='|' c
      read -ra cells <<<"$body"
      local all_placeholder=1 any=0
      for c in "${cells[@]}"; do
        c="${c#"${c%%[![:space:]]*}"}"; c="${c%"${c##*[![:space:]]}"}"
        [[ -n $c ]] && any=1
        [[ $c == '<'*'>' ]] || all_placeholder=0
      done
      ((any)) || continue
      ((all_placeholder)) && continue
      # Skip the header row, which names columns rather than carrying data.
      local head="${cells[0]}"
      head="${head#"${head%%[![:space:]]*}"}"; head="${head%"${head##*[![:space:]]}"}"
      case $head in Path | Thing | Term | File) continue ;; esac

      if ((first == 0)); then printf ',' >>"$tmp"; fi
      first=0
      printf '[' >>"$tmp"
      local i
      for i in "${!cells[@]}"; do
        c="${cells[i]}"
        c="${c#"${c%%[![:space:]]*}"}"; c="${c%"${c##*[![:space:]]}"}"
        ((i > 0)) && printf ',' >>"$tmp"
        ps_json_string "$c" >>"$tmp"
      done
      printf ']' >>"$tmp"
    done <"$file"
  fi
  printf ']}\n' >>"$tmp"
}

build_map() {
  local tmp; tmp=$(ps_tempfile)
  table_rows_json "$project/COMPASS.md" "$tmp" "map"
  ps_atomic_install "$tmp" "$cache_dir/map.json"
}

build_naming() {
  local tmp; tmp=$(ps_tempfile)
  table_rows_json "$project/NAMING.md" "$tmp" "rules"
  ps_atomic_install "$tmp" "$cache_dir/naming.json"
}

build_index() {
  local tmp; tmp=$(ps_tempfile)
  {
    printf '{\n  "schema": %d,\n  "tool_version": %d,\n  "built": %s,\n  "window": %d,\n  "sources": {\n' \
      "$PS_SCHEMA_VERSION" "$PS_TOOL_VERSION" "$(ps_json_string "$(ps_now)")" "$WINDOW"
    local i slice
    for i in "${!SOURCES[@]}"; do
      case "${SOURCES[i]}" in
        COMPASS.md) slice="map.json" ;;
        ISSUES.md) slice="issues.json" ;;
        BACKLOG.md) slice="backlog.json" ;;
        NAMING.md) slice="naming.json" ;;
      esac
      printf '    %s: { "sha256": "%s", "slice": "%s" }' \
        "$(ps_json_string "${SOURCES[i]}")" "$(hash_of "$project/${SOURCES[i]}")" "$slice"
      ((i < ${#SOURCES[@]} - 1)) && printf ','
      printf '\n'
    done
    printf '  }\n}\n'
  } >"$tmp"
  ps_atomic_install "$tmp" "$cache_dir/index.json"
}

cmd_build() {
  mkdir -p "$cache_dir" || ps_die "$PS_IO" "mkdir_failed" "cannot create $cache_dir"
  build_issues
  build_open_issues
  build_backlog
  build_map
  build_naming
  build_index
  if ((PS_JSON)); then
    printf '{"ok":true,"cache":%s,"slices":6}\n' "$(ps_json_string "$cache_dir")"
  else
    printf 'built 6 slices in %s\n' "$cache_dir" >&2
  fi
}

cmd_verify() {
  local index="$cache_dir/index.json"
  if [[ ! -f $index ]]; then
    if ((PS_JSON)); then
      printf '{"ok":false,"fresh":false,"reason":"no_cache","stale":[]}\n'
    else
      printf 'no cache present - run: cache.sh build --project %s\n' "$project" >&2
    fi
    exit "$PS_VALIDATION"
  fi

  local -a stale=()
  local src recorded actual
  for src in "${SOURCES[@]}"; do
    recorded=$(sed -n "s/.*\"${src}\": { \"sha256\": \"\([a-f0-9]*\)\".*/\1/p" "$index")
    actual=$(hash_of "$project/$src")
    if [[ $recorded != "$actual" ]]; then stale+=("$src"); fi
  done

  if ((${#stale[@]} == 0)); then
    if ((PS_JSON)); then printf '{"ok":true,"fresh":true,"stale":[]}\n'; else printf 'cache is fresh\n' >&2; fi
    exit "$PS_OK"
  fi

  if ((PS_JSON)); then
    printf '{"ok":false,"fresh":false,"stale":['
    local i
    for i in "${!stale[@]}"; do
      ((i > 0)) && printf ','
      ps_json_string "${stale[i]}"
    done
    printf ']}\n'
  else
    printf 'cache is stale for: %s\n' "${stale[*]}" >&2
    printf 'read the markdown directly, or run: cache.sh build --project %s\n' "$project" >&2
  fi
  exit "$PS_VALIDATION"
}

ps_scratch_init
case $command in
  build)
    [[ -w $project ]] || ps_die "$PS_IO" "dir_not_writable" "directory is not writable: $project"
    cmd_build ;;
  verify) cmd_verify ;;
  *) ps_die "$PS_USAGE" "unknown_command" "unknown command: $command (build | verify)" ;;
esac
