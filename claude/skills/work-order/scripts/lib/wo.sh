# shellcheck shell=bash
#
# wo.sh - work-order specific helpers, layered on lib/common.sh.
#
# Split of responsibility with common.sh:
#   common.sh  emits JSON by hand and owns locking, atomic writes, exit codes.
#   wo.sh      reads JSON, and that is the one thing hand-rolled bash must not
#              do - hence jq. See wo_require_jq.
#
# work-order-version: 1

readonly WO_STATUSES=(draft ready in-progress in-review done stale)
readonly WO_TYPES=(feature bug chore spike)
readonly WO_PRIORITIES=(p0 p1 p2 p3)

readonly WO_DIR_NAME="work-orders"
readonly WO_FROZEN_START="<!-- wo:frozen:start"
readonly WO_FROZEN_END="<!-- wo:frozen:end -->"

# ---------------------------------------------------------------------------
# Preflight. Every dependency is checked before anything is written, so a
# missing tool is a clean refusal rather than a half-mutated ticket.
# ---------------------------------------------------------------------------

wo_require_jq() {
  command -v jq >/dev/null 2>&1 || ps_die "$PS_IO" "jq_missing" \
    "jq is required (work-order reads build-plan.json). Install jq and retry."
}

# wo_require_git <dir> - the repo under test is the project directory, never the
# caller's cwd. Checking cwd passes or fails for reasons that have nothing to do
# with the ticket being operated on.
wo_require_git() {
  local dir="${1:-.}"
  command -v git >/dev/null 2>&1 || ps_die "$PS_IO" "git_missing" "git is required"
  git -C "$dir" rev-parse --git-dir >/dev/null 2>&1 || ps_die "$PS_IO" "not_a_repo" \
    "$dir is not inside a git repository"
}

wo_require_gh() {
  command -v gh >/dev/null 2>&1 || ps_die "$PS_IO" "gh_missing" \
    "gh is required to verify merge state. Install the GitHub CLI and retry."
}

# ---------------------------------------------------------------------------
# Identity.
#
# WO-YYYYMMDD-<hash> - date for human ordering, hash so two branches minting a
# ticket on the same day cannot collide the way a sequential counter would.
# The hash is derived from title+timestamp, so it is reproducible from inputs
# rather than random.
# ---------------------------------------------------------------------------

wo_mint_id() {
  local title="$1" stamp="$2" day short
  day="${stamp%%T*}"
  day="${day//-/}"
  short=$(printf '%s\n' "${title}|${stamp}" | cksum | awk '{printf "%04x", $1 % 65536}')
  printf 'WO-%s-%s' "$day" "$short"
}

# wo_slug <text> -> lowercase kebab, collapsed, trimmed, max 48 chars
wo_slug() {
  printf '%s' "$1" \
    | tr '[:upper:]' '[:lower:]' \
    | sed -e 's/[^a-z0-9]\+/-/g' -e 's/^-\+//' -e 's/-\+$//' \
    | cut -c1-48
}

wo_id_valid() {
  [[ $1 =~ ^WO-[0-9]{8}-[0-9a-f]{4}$ ]]
}

# ---------------------------------------------------------------------------
# Locating tickets. An ID resolves whether the ticket is active or archived,
# which is what keeps links working after `close` moves the file.
# ---------------------------------------------------------------------------

wo_root() { printf '%s/%s' "$1" "$WO_DIR_NAME"; }

# wo_find <project> <id> -> path, or dies
wo_find() {
  local project="$1" id="$2" root hit count
  root=$(wo_root "$project")
  [[ -d $root ]] || ps_die "$PS_NOTFOUND" "no_work_orders" \
    "no $WO_DIR_NAME/ directory in $project - run 'work-order new' first"

  # -print rather than a glob: archived tickets live under archive/YYYY/.
  count=$(find "$root" -type f -name "${id}-*.md" | wc -l)
  ((count != 0)) || ps_die "$PS_NOTFOUND" "id_not_found" "$id is not in $root"
  ((count == 1)) || ps_die "$PS_VALIDATION" "id_ambiguous" \
    "$id matches $count files in $root - resolve by hand before continuing"
  hit=$(find "$root" -type f -name "${id}-*.md")
  printf '%s' "$hit"
}

wo_is_archived() { [[ $1 == */archive/* ]]; }

# ---------------------------------------------------------------------------
# Frontmatter. The ticket is one file: a JSON object between the first pair of
# --- fences, then markdown. Keeping both in one file is what stops the machine
# layer and the human layer from drifting apart.
# ---------------------------------------------------------------------------

# wo_fm <file> -> the frontmatter JSON on stdout
wo_fm() {
  local file="$1" fm
  [[ -r $file ]] || ps_die "$PS_IO" "unreadable" "cannot read $file"
  fm=$(awk 'NR==1 && $0!="---" {exit 1} NR==1 {next} /^---$/ {exit} {print}' "$file") \
    || ps_die "$PS_VALIDATION" "no_frontmatter" "$file does not start with a --- frontmatter fence"
  printf '%s\n' "$fm" | jq -e . >/dev/null 2>&1 \
    || ps_die "$PS_VALIDATION" "bad_frontmatter" "frontmatter in $file is not valid JSON"
  printf '%s\n' "$fm"
}

# wo_field <file> <jq-path> -> raw value ("" when null/absent)
wo_field() {
  local file="$1" path="$2"
  wo_fm "$file" | jq -r "${path} // \"\""
}

# wo_body <file> -> everything after the closing frontmatter fence
wo_body() {
  awk 'NR==1 && $0=="---" {infm=1; next} infm && /^---$/ {infm=0; body=1; next} body {print}' "$1"
}

# wo_fm_set <file> <jq-filter> [jq-args...] - rewrite frontmatter atomically.
# The body is never touched, so a bad filter cannot eat the human layer.
wo_fm_set() {
  local file="$1" filter="$2"
  shift 2
  local fm new tmp
  fm=$(wo_fm "$file")
  new=$(printf '%s\n' "$fm" | jq "$@" "$filter") \
    || ps_die "$PS_VALIDATION" "jq_failed" "could not apply update to $file"
  tmp=$(ps_tempfile)
  {
    printf -- '---\n'
    printf '%s\n' "$new"
    printf -- '---\n'
    wo_body "$file"
  } >"$tmp"
  ps_atomic_install "$tmp" "$file"
}

# ---------------------------------------------------------------------------
# Status transitions. A closed set with an explicit table - an illegal move is
# refused by name rather than silently allowed.
# ---------------------------------------------------------------------------

# wo_require_status <file> <allowed...>
wo_require_status() {
  local file="$1"
  shift
  local cur s
  cur=$(wo_field "$file" '.status')
  for s in "$@"; do
    if [[ $cur == "$s" ]]; then return 0; fi
  done
  ps_die "$PS_VALIDATION" "illegal_transition" \
    "status is '$cur'; this command requires one of: $*"
}

# ---------------------------------------------------------------------------
# Wireframe binding.
#
# The checksum covers build_order, done_when and non_goals - the semantic
# contract. Canvas x/y is deliberately excluded so nudging a frame does not
# falsely mark a ticket stale.
# ---------------------------------------------------------------------------

# wo_plan_checksum <build-plan.json> [frames-glob]
wo_plan_checksum() {
  local plan="$1" glob="${2:-*}"
  jq -S --arg g "$glob" '{
      build_order: [.build_order[] | select(test("^" + ($g | gsub("\\*"; ".*")) + "$"))],
      done_when:   (.done_when // null),
      non_goals:   (.non_goals // [])
    }' "$plan" | cksum | awk '{printf "cksum:%s-%s", $1, $2}'
}

# wo_plan_identity <build-plan.json> -> project|naming-prefix, used to tell
# "the wireframe was rebuilt" apart from "that file is a different feature now".
wo_plan_identity() {
  jq -r '[(.project // "?"), ((.frames[0].id // "wf/x") | split("/")[0])] | join("|")' "$1"
}

wo_plan_frames() {
  local plan="$1" glob="${2:-*}"
  jq -r --arg g "$glob" \
    '.build_order[] | select(test("^" + ($g | gsub("\\*"; ".*")) + "$"))' "$plan"
}
