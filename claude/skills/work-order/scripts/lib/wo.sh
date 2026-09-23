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

# `cancelled` is terminal like `done`, but it is the other terminal: nothing
# shipped. It is a separate status rather than a deleted file because a ticket
# that was abandoned is a decision, and a decision with no record is how the same
# idea gets cut again three weeks later.
readonly WO_STATUSES=(draft ready in-progress in-review done cancelled stale)
# `test` is the testing ticket: the architect writes its `## Test plan` block and
# the tester runs exactly that. `start` refuses one whose plan cannot be run as
# written - see wo_require_test_plan (O-10).
readonly WO_TYPES=(feature bug chore spike test)
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

# wo_exists <project> <id> - quiet lookup, for validating an edge target.
wo_exists() {
  local root
  root=$(wo_root "$1")
  [[ -d $root ]] || return 1
  [[ -n $(find "$root" -type f -name "${2}-*.md" -print -quit) ]]
}

# ---------------------------------------------------------------------------
# Hierarchy and layout.
#
# The top level of work-orders/ holds directories and nothing else. Two rules
# produce that, and both are enforced rather than remembered:
#
#   1. A ticket with no parent owns the directory named for it, and its own file
#      lives inside that directory.
#   2. A ticket with a parent is written into the parent's directory, promoting
#      the parent into one first if it was still a loose leaf.
#
#   work-orders/WO-…-e21f/WO-…-e21f-dev001-pipeline-test.md   the epic itself
#   work-orders/WO-…-e21f/WO-…-a1d4-track-a1.md               a leaf beneath it
#   work-orders/WO-…-e21f/WO-…-234b/WO-…-234b-skeleton.md     a child that is
#                                                             itself an epic
#
# A loose ticket file at the root was the old shape, and it is what let ten
# unrelated tickets pile up with nothing tying them together. Placing every
# parentless ticket in its own directory makes that pile impossible rather than
# merely tidied.
#
# Owning a directory is monotone: a ticket that has one keeps it even after its
# last child leaves. A path recorded anywhere therefore stays valid, which is
# the same reason grouping is by parent and never by status.
# ---------------------------------------------------------------------------

# wo_owns_dir <file> - 0 when the ticket's file already sits inside the
# directory named for its own id.
wo_owns_dir() {
  local f="$1" id
  id=$(wo_field "$f" '.id')
  [[ $(basename -- "$(dirname -- "$f")") == "$id" ]]
}

# wo_own_dir <file> -> the directory this ticket owns, whether or not it exists
# on disk yet. For a ticket that already owns one, that is the directory its own
# file sits in.
wo_own_dir() {
  local f="$1" id
  if wo_owns_dir "$f"; then printf '%s' "$(dirname -- "$f")"; return 0; fi
  id=$(wo_field "$f" '.id')
  printf '%s/%s' "$(dirname -- "$f")" "$id"
}

# wo_child_dir <parent-file> -> the directory this ticket's children live in.
# The same directory the ticket owns: an epic sits beside its children rather
# than one level above them, so the folder is the whole unit of work.
wo_child_dir() { wo_own_dir "$1"; }

# wo_home_dir <project> <parent-id-or-empty> <id> -> where this ticket's own
# file belongs. The id is required for a parentless ticket because that ticket
# is placed in the directory named for itself, never at the root.
wo_home_dir() {
  local project="$1" parent="${2:-}" id="${3:-}"
  if [[ -z $parent ]]; then
    [[ -n $id ]] || ps_die "$PS_USAGE" "missing_id" \
      "wo_home_dir needs the ticket id to place a ticket that has no parent"
    printf '%s/%s' "$(wo_root "$project")" "$id"
    return 0
  fi
  wo_child_dir "$(wo_find "$project" "$parent")"
}

# wo_loose_at_root <root> -> every ticket file sitting directly in work-orders/,
# one per line. This is what the layout gate reads: a single hit means the rule
# above has been broken and the pile is starting again.
wo_loose_at_root() {
  find "$1" -maxdepth 1 -type f -name 'WO-*.md' | sort
}

# wo_ancestors <project> <id> - the parent chain, nearest first, on stdout.
# Depth-capped: a cycle already on disk must be reported, never looped on.
wo_ancestors() {
  local project="$1" cur="$2" depth=0 f p
  while ((depth < 32)); do
    wo_exists "$project" "$cur" || return 0
    f=$(wo_find "$project" "$cur")
    p=$(wo_field "$f" '.parent')
    [[ -n $p ]] || return 0
    printf '%s\n' "$p"
    cur="$p"
    depth=$((depth + 1))
  done
  ps_die "$PS_VALIDATION" "parent_cycle" \
    "the parent chain above $2 is more than 32 deep - it contains a cycle"
}

# ---------------------------------------------------------------------------
# Records. One jq per ticket, emitting every field the index and the graph
# need. Reading each field with its own jq call is what made reindex slow
# enough that an agent would be tempted to skip it.
# ---------------------------------------------------------------------------

# wo_records <root> -> TSV: id status type priority parent deps relpath title
#
# An absent parent and an empty dependency list are emitted as WO_NONE rather
# than as an empty field. Tab is an IFS whitespace character, so `read` collapses
# two adjacent tabs into one delimiter and every later column shifts left - a
# ticket with no parent would silently read its own path as its parent. The
# sentinel keeps all eight fields non-empty; the caller maps it back.
readonly WO_NONE="-"

wo_records() {
  local root="$1" f
  while IFS= read -r f; do
    wo_fm "$f" | jq -r --arg p "${f#"$root"/}" --arg none "$WO_NONE" '
      def blank_as_none: if . == "" then $none else . end;
      [ .id, .status, .type, (.priority // "p2"),
        ((.parent // "") | blank_as_none),
        (((.depends_on // []) | join(",")) | blank_as_none),
        $p, .title ] | @tsv'
  done < <(find "$root" -type f -name 'WO-*.md' | sort)
}

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
  # IFS is $'\n\t' script-wide, so an unqualified "$*" would list the allowed
  # statuses one per line inside a single-line error. The list is read by a human
  # deciding what to run next, so it is joined by hand.
  local allowed=""
  for s in "$@"; do allowed+="${allowed:+, }$s"; done
  ps_die "$PS_VALIDATION" "illegal_transition" \
    "status is '$cur'; this command requires one of: $allowed"
}

# ---------------------------------------------------------------------------
# The test plan (O-10).
#
# The architect writes the plan into the testing ticket and the tester runs
# exactly that plan. Before this, `## Test plan` held one free-text shell line,
# so a tester handed a `test` ticket had to invent its cases and the plan it ran
# was never the plan anyone reviewed. The block now has four fixed labels, the
# shape claude/workflow/templates/test-plan.md gives the architect to copy, and
# claude/workflow/schemas/test-plan.schema.json is the contract for what this
# parser emits.
#
# Markdown rather than a fenced JSON blob, because the ticket is read by a human
# at the approval gate and a JSON blob beside a prose rendering of it is two
# statements of one plan that can disagree.
# ---------------------------------------------------------------------------

# wo_test_plan_json <file> - the `## Test plan` section of a ticket as JSON on
# stdout. Only the labels actually present become keys, so a section still in
# the old one-line shape, or `_none recorded_`, has no `cases` key at all -
# which is how "missing" is told apart from "present with no case".
# A file with no `## Test plan` heading is read as a bare block body, which is
# what lets the workflow suite parse the template itself.
wo_test_plan_json() {
  local file="$1"
  awk '
    /^## Test plan[[:space:]]*$/ { insec = 1; seen = 1; next }
    /^## / { if (insec) exit; next }
    { lines[++n] = $0; if (insec) sec[++m] = $0 }
    END {
      if (seen) { for (i = 1; i <= m; i++) body(sec[i]) } else { for (i = 1; i <= n; i++) body(lines[i]) }
    }
    function strip(s) {
      sub(/^[[:space:]]+/, "", s); sub(/[[:space:]]+$/, "", s)
      if (s ~ /^`.*`$/) s = substr(s, 2, length(s) - 2)
      return s
    }
    function body(l,   k, v) {
      if (l ~ /^\*\*Scope under test\*\*[[:space:]]*$/)            { mode = "scope"; print "L\tscope"; return }
      if (l ~ /^\*\*Cases\*\*[[:space:]]*$/)                       { mode = "cases"; print "L\tcases"; return }
      if (l ~ /^\*\*Isolation\*\*[[:space:]]*$/)                   { mode = "iso";   print "L\tisolation"; return }
      if (l ~ /^\*\*Out of scope - CI covers\*\*[[:space:]]*$/)    { mode = "out";   print "L\tout_of_scope"; return }
      if (mode == "scope" && !scoped && l ~ /[^[:space:]]/)        { scoped = 1; print "S\t" strip(l); return }
      if (mode == "cases" && l ~ /^- `[^`]+`[[:space:]]*$/)        { cased = 1; print "C\t" strip(substr(l, 3)); return }
      if (mode == "cases" && cased && l ~ /^[[:space:]]+- (intent|command|expected):/) {
        sub(/^[[:space:]]+- /, "", l); k = l; sub(/:.*/, "", k); v = l; sub(/^[a-z]+:/, "", v)
        print "F\t" k "\t" strip(v); return
      }
      if (mode == "iso" && l ~ /^- (runtime|image):/) {
        sub(/^- /, "", l); k = l; sub(/:.*/, "", k); v = l; sub(/^[a-z]+:/, "", v)
        # The image line carries its human tag in parentheses after the digest,
        # the Rule 15 convention; the tag is for the reader, not the contract.
        if (k == "image") sub(/[[:space:]]+\(.*\)[[:space:]]*$/, "", v)
        print "R\t" k "\t" strip(v); return
      }
      if (mode == "out" && l ~ /^- /)                              { print "O\t" strip(substr(l, 3)) }
    }
  ' "$file" | jq -Rn '
    reduce (inputs | split("\t")) as $r ({};
      if   $r[0] == "L" and $r[1] == "scope"        then .scope //= ""
      elif $r[0] == "L" and $r[1] == "cases"        then .cases //= []
      elif $r[0] == "L" and $r[1] == "isolation"    then .isolation //= {}
      elif $r[0] == "L" and $r[1] == "out_of_scope" then .out_of_scope //= []
      elif $r[0] == "S" then .scope = ($r[1:] | join("\t"))
      elif $r[0] == "C" then .cases += [{id: $r[1]}]
      elif $r[0] == "F" then .cases[(.cases | length) - 1][$r[1]] = ($r[2:] | join("\t"))
      elif $r[0] == "R" then .isolation[$r[1]] = ($r[2:] | join("\t"))
      elif $r[0] == "O" then .out_of_scope += [$r[1:] | join("\t")]
      else . end)'
}

# wo_require_test_plan <file> - refuse a `test` ticket whose plan cannot be run
# as written. Called by `start`, because in-progress is the moment the tester
# picks the plan up; a draft may still be missing one while it is argued about.
#
# It checks what a tester needs to run the plan without inventing anything: the
# block, at least one case, every case complete, and a Podman image pinned by
# digest (Rule 14, Rule 15). The full shape - scope and the CI list included -
# is the schema's job, proven in claude/workflow's suite; restating all of it
# here in jq would be a second contract to drift from the first.
wo_require_test_plan() {
  local file="$1" plan id
  id=$(wo_field "$file" '.id')
  plan=$(wo_test_plan_json "$file")
  printf '%s' "$plan" | jq -e 'has("cases")' >/dev/null || ps_die "$PS_VALIDATION" "test_plan_missing" \
    "$id is a test ticket with no test plan block - copy claude/workflow/templates/test-plan.md, fill it, and pass it to amend --test-plan-file while the ticket is a draft"
  printf '%s' "$plan" | jq -e '.cases | length > 0' >/dev/null || ps_die "$PS_VALIDATION" "test_plan_no_case" \
    "$id has a test plan with no case - a tester cannot run a plan that names nothing to run"
  local bad
  bad=$(printf '%s' "$plan" | jq -r '[.cases[] | select((.intent // "") == "" or (.command // "") == "" or (.expected // "") == "") | .id] | join(", ")')
  [[ -z $bad ]] || ps_die "$PS_VALIDATION" "test_plan_incomplete_case" \
    "$id test plan case(s) missing intent, command or expected: $bad"
  printf '%s' "$plan" | jq -e '(.isolation.runtime // "") == "podman" and ((.isolation.image // "") | test("@sha256:[0-9a-f]{64}$"))' >/dev/null \
    || ps_die "$PS_VALIDATION" "test_plan_not_isolated" \
      "$id test plan must run in podman on an image pinned by digest (runtime: podman, image: <name>@sha256:<64 hex>)"
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
