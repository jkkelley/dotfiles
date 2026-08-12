#!/usr/bin/env bash
#
# cartograph.sh - map a system into islands, and mint the skeleton tickets that
# hang off them.
#
# The division of labour is the whole point:
#
#   the model  decides what the islands are, writes the prose and the Mermaid
#   this file  owns every ID, every HTML byte, and the shape of the ledger
#   work-order owns every ticket byte
#
# This script never writes ticket markdown. It shells out to work-order.sh for
# every mint and reads the ID back from `--json`, so a ticket ID that appears in
# an HTML map is one work-order actually issued. An ID the model typed would be
# a dangling pointer the moment anyone clicked it.

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
SKILL_DIR=$(cd -- "$SCRIPT_DIR/.." && pwd)
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

readonly TEMPLATE="$SKILL_DIR/references/island.tmpl"
readonly CARTO_DIR_NAME="cartography"
readonly WO_DIR_NAME="work-orders"

usage() {
  cat <<'EOF'
cartograph.sh - island maps backed by real work-orders

Usage:
  cartograph.sh plan   [--project DIR] --spec FILE [--json]
  cartograph.sh island [--project DIR] --spec FILE [--json]
  cartograph.sh render [--project DIR] [--island KEY] [--json]
  cartograph.sh ledger [--project DIR] [--json]

  --project  where cartography/ and work-orders/ live. Default: cwd.
  --spec     a JSON file the model writes. Schemas below.
  --work-order PATH  work-order.sh, if it is not a sibling skill.

plan runs once per system. It mints the system epic, one child epic per island,
wires the cross-island dependencies, and renders 000-macro-map.html. It refuses
to run twice - a second system epic over the same map is the one mistake that
cannot be undone with `link`.

island runs once per island, after you have approved that island's map. It mints
one skeleton ticket per entry under the island epic, wires the intra-island
dependencies, and renders NNN-<slug>.html.

render re-reads every ticket and rebuilds the HTML. It mints nothing, so it is
safe to run whenever ticket status has moved on. This is what keeps a map honest.

Skeletons:
  A ticket minted here carries at least one --ac and, for anything planning could
  not settle, a --question. work-order's own gates do the rest: `approve` refuses
  while a question is open, and `next` only ever returns `ready`. So a skeleton
  cannot be picked up as real work, and `resolve` is the verb that graduates it.

Exit codes: 0 ok, 2 usage, 3 validation, 4 io/missing dependency, 6 id not found.

--- macro spec ---------------------------------------------------------------
{
  "system":  {"title": "...", "problem": "...",
              "out": ["..."], "ac": ["..."], "questions": ["..."]},
  "overview": "<p>prose, HTML allowed</p>",
  "mermaid":  "graph TD\n  A --> B",
  "islands": [
    {"key": "ingestion", "number": 3, "title": "Product Ingestion",
     "summary": "one line for the macro map",
     "problem": "...", "out": ["..."], "ac": ["..."], "questions": ["..."],
     "depends_on": ["storefront"]}
  ]
}

--- island spec --------------------------------------------------------------
{
  "island": "ingestion",
  "overview": "<p>what this island is for</p>",
  "diagrams": [{"caption": "...", "mermaid": "graph TD\n  A --> B"}],
  "tickets": [
    {"key": "orchestrator", "title": "...", "type": "feature", "priority": "p1",
     "problem": "...", "in": ["..."], "out": ["..."],
     "ac": ["..."], "questions": ["..."], "test_plan": "...",
     "depends_on": ["scrapers"]}
  ]
}
EOF
}

# ---------------------------------------------------------------------------
# Dependencies.
# ---------------------------------------------------------------------------

require_jq() {
  command -v jq >/dev/null 2>&1 || ps_die "$PS_IO" "jq_missing" \
    "jq is required: cartograph reads model-authored spec JSON, and hand-rolled JSON parsing in bash is exactly the nondeterminism this skill exists to remove"
}

# work-order is not optional and there is no degraded mode. A cartography map
# whose tickets were written by anything but work-order.sh is a map of tickets
# that do not exist.
resolve_work_order() {
  local candidate
  for candidate in \
    "${CARTO_WORK_ORDER:-}" \
    "$wo_override" \
    "$SKILL_DIR/../work-order/scripts/work-order.sh" \
    "$project/.claude/skills/work-order/scripts/work-order.sh"; do
    [[ -n $candidate && -r $candidate ]] || continue
    WO_BIN=$(cd -- "$(dirname -- "$candidate")" && pwd)/$(basename -- "$candidate")
    return 0
  done
  ps_die "$PS_IO" "work_order_missing" \
    "cannot find work-order.sh - pass --work-order PATH or set CARTO_WORK_ORDER. cartography mints every ticket through work-order and has no fallback that writes tickets itself"
}

# work-order takes the subcommand first and its flags after it, so --project has
# to be injected after the verb rather than in front of it.
wo() {
  local verb="$1"; shift
  bash "$WO_BIN" "$verb" --project "$project" "$@"
}

# ---------------------------------------------------------------------------
# Paths.
# ---------------------------------------------------------------------------

carto_root() { printf '%s/%s' "$project" "$CARTO_DIR_NAME"; }
map_file()   { printf '%s/.map.json' "$(carto_root)"; }
spec_store() { printf '%s/specs' "$(carto_root)"; }

read_map() {
  local f; f=$(map_file)
  [[ -r $f ]] || ps_die "$PS_NOTFOUND" "no_map" \
    "no $CARTO_DIR_NAME/.map.json in $project - run 'cartograph.sh plan' first"
  cat -- "$f"
}

write_map() {
  local tmp; tmp=$(ps_tempfile)
  cat >"$tmp"
  jq -e . "$tmp" >/dev/null 2>&1 || ps_die "$PS_VALIDATION" "map_corrupt" "refusing to write malformed .map.json"
  ps_atomic_install "$tmp" "$(map_file)"
}

# The on-disk path of a ticket, relative to the project root. work-order files a
# child under a directory named for its parent, so the path is discovered rather
# than assumed - a layout this script guessed at would rot the first time
# work-order re-homed anything.
ticket_path() {
  local id="$1" found
  found=$(find "$project/$WO_DIR_NAME" -type f -name "${id}-*.md" 2>/dev/null | head -1)
  [[ -n $found ]] && printf '%s' "${found#"$project"/}"
}

# ---------------------------------------------------------------------------
# HTML.
# ---------------------------------------------------------------------------

# Everything read back out of a ticket is escaped. Only the model's own overview
# and Mermaid go in raw, because Mermaid labels legitimately carry <br> and a
# diagram whose arrows had been turned into &gt; would not render at all.
html_escape() {
  local s="${1-}"
  s=${s//&/&amp;}
  s=${s//</&lt;}
  s=${s//>/&gt;}
  s=${s//\"/&quot;}
  printf '%s' "$s"
}

# The body of one `## Heading` section of a ticket, up to the next H2.
section_lines() {
  awk -v h="## $2" '
    $0 == h { inside = 1; next }
    inside && /^## / { inside = 0 }
    inside { print }
  ' "$1"
}

# Render a checkbox list from a ticket section into <li> items, marking state.
checkbox_items() {
  local file="$1" heading="$2" cls="$3" line mark text label out=""
  while IFS= read -r line; do
    case "$line" in
      '- [ ] '*) mark="&#9744;"; text=${line#- \[ \] } ;;
      '- [x] '*) mark="&#9745;"; text=${line#- \[x\] } ;;
      *) continue ;;
    esac
    # A criterion reads `- [ ] `AC-H1` *(human)* the text`. The label is kept
    # because it is how someone addresses the criterion with `evidence --match`,
    # but it is set apart rather than left inline where it reads as prose.
    label=""
    if [[ $text =~ ^\`([A-Za-z0-9_-]+)\`[[:space:]]* ]]; then
      label="${BASH_REMATCH[1]}"
      text=${text#"${BASH_REMATCH[0]}"}
    fi
    # Strip the source markers rather than escape them, so the map reads as a
    # map and not as raw markdown.
    text=${text//\*(human)\*/}
    text=${text//\*(wireframe)\*/}
    text=${text//\`/}
    text=$(printf '%s' "$text" | tr -s '[:space:]' ' ')
    text=${text# }; text=${text% }
    out+="<li>${mark} "
    [[ -n $label ]] && out+="<span class=\"wo-id\">$(html_escape "$label")</span> "
    out+="$(html_escape "$text")</li>"
  done < <(section_lines "$file" "$heading")
  [[ -n $out ]] && printf '<ul class="%s">%s</ul>' "$cls" "$out"
}

# "Waiting on: Scraper adapters" beats "Waiting on: WO-20260805-9c1f". The id is
# the address, but the title is what tells a reader whether the blocker matters,
# and a map that made you open another file to find that out is a worse map.
dep_link() {
  local id="$1" rel title
  rel=$(ticket_path "$id")
  title=$(wo show --id "$id" --json 2>/dev/null | jq -r '.title // empty') || title=""
  if [[ -n $rel && -n $title ]]; then
    printf '<a href="../%s">%s</a> <span class="wo-id">%s</span>' \
      "$(html_escape "$rel")" "$(html_escape "$title")" "$(html_escape "$id")"
  else
    # A dependency outside this project's tree still has to render as something.
    printf '<code>%s</code>' "$(html_escape "$id")"
  fi
}

# One <div class="ticket"> from a ticket's own record. Nothing here is passed in
# by a caller: the title, the status and the criteria are read from the file
# work-order wrote, so the map cannot drift from the ticket by construction.
render_ticket() {
  local id="$1" rel file fm title status problem href
  rel=$(ticket_path "$id")
  [[ -n $rel ]] || ps_die "$PS_NOTFOUND" "ticket_gone" \
    "ticket $id is in .map.json but not on disk - it was moved or deleted outside work-order"
  file="$project/$rel"
  fm=$(wo show --id "$id" --json)
  title=$(jq -r '.title' <<<"$fm")
  status=$(jq -r '.status' <<<"$fm")
  problem=$(section_lines "$file" "Problem" | grep -v '^[[:space:]]*$' | head -3)
  href="../$rel"

  local questions criteria deps klass
  criteria=$(checkbox_items "$file" "Acceptance criteria" "ac")
  questions=$(checkbox_items "$file" "Open questions" "oq")
  # An open question is what makes a ticket a skeleton, so it is what colours it.
  klass="ticket"
  grep -q '^- \[ \] ' < <(section_lines "$file" "Open questions") && klass="ticket skeleton"

  deps=$(jq -r '.depends_on[]? // empty' <<<"$fm")

  printf '<div class="%s">' "$klass"
  printf '<h4><a href="%s">%s</a> <span class="wo-id">%s</span> <span class="badge %s">%s</span></h4>' \
    "$(html_escape "$href")" "$(html_escape "$title")" "$(html_escape "$id")" \
    "$(html_escape "$status")" "$(html_escape "$status")"
  [[ -n $problem ]] && printf '<p>%s</p>' "$(html_escape "$problem")"
  [[ -n $criteria ]] && printf '<strong>Acceptance criteria</strong>%s' "$criteria"
  if [[ -n $questions ]]; then
    printf '<strong>Open questions - resolve before this ticket can be approved</strong>%s' "$questions"
  fi
  if [[ -n $deps ]]; then
    printf '<p class="dep">Waiting on: '
    local d first=1
    while IFS= read -r d; do
      [[ -n $d ]] || continue
      ((first)) || printf ', '
      first=0
      dep_link "$d"
    done <<<"$deps"
    printf '</p>'
  fi
  printf '</div>\n'
}

# The template is filled by substitution and the result is checked for survivors,
# for the same reason work-order does it: a stray %%TOKEN%% breaks nothing
# downstream, renders as literal text, and is therefore invisible for months.
render_page() {
  local docid="$1" title="$2" epic_id="$3" epic_status="$4" body="$5" regen="$6"
  local epic_href out
  epic_href="../$(ticket_path "$epic_id")"
  out=$(ps_tempfile)

  local line
  while IFS= read -r line || [[ -n $line ]]; do
    line=${line//'%%DOCID%%'/$(html_escape "$docid")}
    line=${line//'%%TITLE%%'/$(html_escape "$title")}
    line=${line//'%%EPIC_ID%%'/$(html_escape "$epic_id")}
    line=${line//'%%EPIC_HREF%%'/$(html_escape "$epic_href")}
    line=${line//'%%EPIC_STATUS%%'/$(html_escape "$epic_status")}
    line=${line//'%%REGEN%%'/$(html_escape "$regen")}
    if [[ $line == *'%%BODY%%'* ]]; then
      printf '%s\n' "$body"
    else
      printf '%s\n' "$line"
    fi
  done <"$TEMPLATE" >"$out"

  if grep -q '%%[A-Z_]*%%' "$out"; then
    ps_die "$PS_VALIDATION" "unsubstituted_placeholder" \
      "a %%TOKEN%% survived rendering: $(grep -o '%%[A-Z_]*%%' "$out" | sort -u | tr '\n' ' ')"
  fi
  cat -- "$out"
}

# ---------------------------------------------------------------------------
# The ledger. Generated from the map and the tickets, never hand-maintained -
# the original skill kept it in prose, which is a count that goes stale silently.
# ---------------------------------------------------------------------------

ledger_rows() {
  local map; map=$(read_map)
  local key
  while IFS= read -r key; do
    [[ -n $key ]] || continue
    local iid num ititle ifile n_total n_open status
    iid=$(jq -r --arg k "$key" '.islands[$k].id' <<<"$map")
    num=$(jq -r --arg k "$key" '.islands[$k].number' <<<"$map")
    ititle=$(jq -r --arg k "$key" '.islands[$k].title' <<<"$map")
    ifile=$(jq -r --arg k "$key" '.islands[$k].file // ""' <<<"$map")
    n_total=$(jq -r --arg k "$key" '[.tickets[] | select(.island == $k)] | length' <<<"$map")
    status=$(wo show --id "$iid" --json | jq -r '.status')
    n_open=0
    local tid
    while IFS= read -r tid; do
      [[ -n $tid ]] || continue
      local tf; tf=$(ticket_path "$tid")
      [[ -n $tf ]] || continue
      if grep -q '^- \[ \] ' < <(section_lines "$project/$tf" "Open questions"); then
        n_open=$((n_open + 1))
      fi
    done < <(jq -r --arg k "$key" '.tickets | to_entries[] | select(.value.island == $k) | .value.id' <<<"$map")
    # One compact JSON object per line, rather than tab-separated fields.
    # An un-cut island has an empty "file", and tab is an IFS *whitespace*
    # character - bash collapses a run of them into one delimiter, so an empty
    # field silently shifts every column after it left. That failure is
    # invisible in the happy case and corrupts the ledger in exactly the case
    # the ledger exists for.
    jq -cn --arg n "$num" --arg t "$ititle" --arg f "$ifile" --arg i "$iid" \
           --arg s "$status" --arg c "$n_total" --arg o "$n_open" \
      '{number:($n|tonumber), title:$t, file:$f, id:$i, status:$s,
        tickets:($c|tonumber), unresolved:($o|tonumber)}'
  done < <(jq -r '.islands | to_entries | sort_by(.value.number) | .[].key' <<<"$map")
}

ledger_html() {
  printf '<h2>File Tracking Ledger</h2>'
  printf '<table><tr><th>#</th><th>Island</th><th>Document</th><th>Work order</th><th>Status</th><th>Tickets</th><th>Unresolved</th></tr>'
  local row num ititle ifile iid status n_total n_open cell
  while IFS= read -r row; do
    [[ -n $row ]] || continue
    num=$(jq -r '.number' <<<"$row");   ititle=$(jq -r '.title' <<<"$row")
    ifile=$(jq -r '.file' <<<"$row");   iid=$(jq -r '.id' <<<"$row")
    status=$(jq -r '.status' <<<"$row")
    n_total=$(jq -r '.tickets' <<<"$row"); n_open=$(jq -r '.unresolved' <<<"$row")
    if [[ -z $ifile ]]; then
      cell='<em>pending</em>'
    else
      cell="<a href=\"$(html_escape "$ifile")\">$(html_escape "$ifile")</a>"
    fi
    printf '<tr><td>%s</td><td>%s</td><td>%s</td><td><code>%s</code></td><td><span class="badge %s">%s</span></td><td>%s</td><td>%s</td></tr>' \
      "$(html_escape "$num")" "$(html_escape "$ititle")" "$cell" "$(html_escape "$iid")" \
      "$(html_escape "$status")" "$(html_escape "$status")" \
      "$(html_escape "$n_total")" "$(html_escape "$n_open")"
  done < <(ledger_rows)
  printf '</table>'
}

cmd_ledger() {
  require_jq; resolve_work_order
  # Read the map here, not only inside ledger_rows. ledger_rows is consumed
  # through a process substitution, and a ps_die in there kills the subshell
  # while the parent carries on to exit 0 - a refusal nobody would ever see.
  read_map >/dev/null
  if ((PS_JSON)); then
    ledger_rows | jq -s .
  else
    printf '%-4s %-28s %-30s %-18s %-8s %s\n' '#' 'ISLAND' 'DOCUMENT' 'WORK ORDER' 'STATUS' 'TICKETS'
    local row
    while IFS= read -r row; do
      [[ -n $row ]] || continue
      printf '%-4s %-28s %-30s %-18s %-8s %s (%s unresolved)\n' \
        "$(jq -r '.number' <<<"$row")" "$(jq -r '.title' <<<"$row")" \
        "$(jq -r 'if .file == "" then "(pending)" else .file end' <<<"$row")" \
        "$(jq -r '.id' <<<"$row")" "$(jq -r '.status' <<<"$row")" \
        "$(jq -r '.tickets' <<<"$row")" "$(jq -r '.unresolved' <<<"$row")"
    done < <(ledger_rows)
  fi
}

# ---------------------------------------------------------------------------
# Minting.
# ---------------------------------------------------------------------------

# Build the work-order argv for one spec node. Repeated flags stay repeated -
# work-order takes --out/--ac/--question many times, and collapsing them into one
# joined string would produce a single unreadable criterion.
declare -a MINT_ARGS
build_mint_args() {
  local node="$1" v
  MINT_ARGS=()
  while IFS= read -r v; do [[ -n $v ]] && MINT_ARGS+=(--in "$v"); done < <(jq -r '.in[]? // empty' <<<"$node")
  while IFS= read -r v; do [[ -n $v ]] && MINT_ARGS+=(--out "$v"); done < <(jq -r '.out[]? // empty' <<<"$node")
  while IFS= read -r v; do [[ -n $v ]] && MINT_ARGS+=(--ac "$v"); done < <(jq -r '.ac[]? // empty' <<<"$node")
  while IFS= read -r v; do [[ -n $v ]] && MINT_ARGS+=(--question "$v"); done < <(jq -r '.questions[]? // empty' <<<"$node")
  while IFS= read -r v; do [[ -n $v ]] && MINT_ARGS+=(--assume "$v"); done < <(jq -r '.assumptions[]? // empty' <<<"$node")
  v=$(jq -r '.test_plan // empty' <<<"$node"); [[ -n $v ]] && MINT_ARGS+=(--test-plan "$v")
  v=$(jq -r '.priority // empty' <<<"$node"); [[ -n $v ]] && MINT_ARGS+=(--priority "$v")
  return 0
}

# A ticket with no acceptance criterion can never be approved and no verb can add
# one after the fact - `--ac` is mint-time only. So an empty skeleton is not a
# loose ticket, it is an unusable one, and this is the right place to refuse it.
require_ac() {
  local node="$1" what="$2" n
  n=$(jq -r '[.ac[]? // empty] | length' <<<"$node")
  ((n > 0)) || ps_die "$PS_VALIDATION" "no_acceptance_criteria" \
    "$what has no \"ac\": work-order takes --ac only at mint time, so a ticket minted without one can never be approved and no later command can repair it. State what done looks like, however coarsely, and put the parts you cannot yet state in \"questions\"."
}

# ---------------------------------------------------------------------------
# plan
# ---------------------------------------------------------------------------

cmd_plan() {
  require_jq; resolve_work_order
  ps_require_value spec "$spec"
  [[ -r $spec ]] || ps_die "$PS_IO" "spec_unreadable" "cannot read spec: $spec"
  jq -e . "$spec" >/dev/null 2>&1 || ps_die "$PS_VALIDATION" "spec_invalid" "$spec is not valid JSON"

  [[ -e $(map_file) ]] && ps_die "$PS_VALIDATION" "already_planned" \
    "$CARTO_DIR_NAME/.map.json already exists. plan mints a system epic and runs once; to add an island to an existing map, mint it with work-order and add it to .map.json, or start a new project directory"

  local doc; doc=$(cat -- "$spec")
  local sys; sys=$(jq -c '.system // empty' <<<"$doc")
  [[ -n $sys ]] || ps_die "$PS_VALIDATION" "no_system" "spec has no \"system\" object"
  local n_islands; n_islands=$(jq -r '[.islands[]? // empty] | length' <<<"$doc")
  ((n_islands >= 1)) || ps_die "$PS_VALIDATION" "no_islands" \
    "spec has no \"islands\": a map with no islands is a title"

  # Validate every island before minting anything. A run that refused halfway
  # would leave a system epic with some of its children, which is worse than
  # having refused at the start.
  local i node key
  for ((i = 0; i < n_islands; i++)); do
    node=$(jq -c --argjson i "$i" '.islands[$i]' <<<"$doc")
    key=$(jq -r '.key // empty' <<<"$node")
    [[ -n $key ]] || ps_die "$PS_VALIDATION" "island_no_key" "islands[$i] has no \"key\""
    [[ -n $(jq -r '.title // empty' <<<"$node") ]] || ps_die "$PS_VALIDATION" "island_no_title" "island '$key' has no \"title\""
    [[ -n $(jq -r '.number // empty' <<<"$node") ]] || ps_die "$PS_VALIDATION" "island_no_number" "island '$key' has no \"number\""
    require_ac "$node" "island '$key'"
  done
  require_ac "$sys" "the system epic"
  local dup
  dup=$(jq -r '[.islands[].key] | group_by(.) | map(select(length > 1) | .[0]) | .[]' <<<"$doc")
  [[ -z $dup ]] && : || ps_die "$PS_VALIDATION" "duplicate_island_key" "island key used twice: $dup"

  mkdir -p "$(carto_root)" "$(spec_store)" || ps_die "$PS_IO" "mkdir_failed" "cannot create $(carto_root)"

  build_mint_args "$sys"
  local sys_id
  sys_id=$(wo new --json --top-level --type "$(jq -r '.type // "feature"' <<<"$sys")" \
    --title "$(jq -r '.title' <<<"$sys")" --problem "$(jq -r '.problem // "See the macro map."' <<<"$sys")" \
    "${MINT_ARGS[@]}" | jq -r '.id')
  [[ -n $sys_id && $sys_id != null ]] || ps_die "$PS_IO" "mint_failed" "work-order did not return an id for the system epic"
  ps_info "system epic: $sys_id"

  local map
  map=$(jq -n --arg id "$sys_id" --arg t "$(jq -r '.title' <<<"$sys")" \
    '{system:{id:$id,title:$t}, islands:{}, tickets:{}}')

  for ((i = 0; i < n_islands; i++)); do
    node=$(jq -c --argjson i "$i" '.islands[$i]' <<<"$doc")
    key=$(jq -r '.key' <<<"$node")
    build_mint_args "$node"
    local iid
    iid=$(wo new --json --parent "$sys_id" --type "$(jq -r '.type // "feature"' <<<"$node")" \
      --title "$(jq -r '.title' <<<"$node")" \
      --problem "$(jq -r '.problem // .summary // "See the island map."' <<<"$node")" \
      "${MINT_ARGS[@]}" | jq -r '.id')
    [[ -n $iid && $iid != null ]] || ps_die "$PS_IO" "mint_failed" "work-order did not return an id for island '$key'"
    ps_info "  island $key: $iid"
    map=$(jq --arg k "$key" --arg id "$iid" \
      --arg n "$(jq -r '.number' <<<"$node")" \
      --arg t "$(jq -r '.title' <<<"$node")" \
      --arg s "$(jq -r '.summary // ""' <<<"$node")" \
      '.islands[$k] = {id:$id, number:($n|tonumber), title:$t, summary:$s, file:""}' <<<"$map")
  done

  # Edges last, because a sibling cannot be referenced before it exists. This is
  # the same reason work-order's own epic recipe wires --depends-on with `link`.
  for ((i = 0; i < n_islands; i++)); do
    node=$(jq -c --argjson i "$i" '.islands[$i]' <<<"$doc")
    key=$(jq -r '.key' <<<"$node")
    local dep dep_id from_id
    from_id=$(jq -r --arg k "$key" '.islands[$k].id' <<<"$map")
    while IFS= read -r dep; do
      [[ -n $dep ]] || continue
      dep_id=$(jq -r --arg k "$dep" '.islands[$k].id // empty' <<<"$map")
      [[ -n $dep_id ]] || ps_die "$PS_NOTFOUND" "unknown_island_ref" \
        "island '$key' depends_on '$dep', which is not an island in this spec"
      wo link --id "$from_id" --depends-on "$dep_id" >/dev/null
    done < <(jq -r '.depends_on[]? // empty' <<<"$node")
  done

  printf '%s' "$map" | write_map
  cp -- "$spec" "$(spec_store)/macro.json"
  render_macro

  if ((PS_JSON)); then
    jq -n --arg id "$sys_id" --argjson map "$map" \
      '{system:$id, islands:($map.islands | to_entries | map({key:.key, id:.value.id}))}'
  else
    ps_info "wrote $CARTO_DIR_NAME/000-macro-map.html"
  fi
}

render_macro() {
  local map doc body
  map=$(read_map)
  doc=$(cat -- "$(spec_store)/macro.json")
  local sys_id sys_title sys_status
  sys_id=$(jq -r '.system.id' <<<"$map")
  sys_title=$(jq -r '.system.title' <<<"$map")
  sys_status=$(wo show --id "$sys_id" --json | jq -r '.status')

  body=$(
    local ov mm
    ov=$(jq -r '.overview // empty' <<<"$doc")
    [[ -n $ov ]] && { printf '<h2>Overview</h2>'; printf '%s' "$ov"; }
    mm=$(jq -r '.mermaid // empty' <<<"$doc")
    if [[ -n $mm ]]; then
      printf '<h2>Island map</h2><div class="mermaid">\n%s\n</div>' "$mm"
    fi
    printf '<h2>Islands</h2>'
    local key
    while IFS= read -r key; do
      [[ -n $key ]] || continue
      local iid num ititle summ ifile status
      iid=$(jq -r --arg k "$key" '.islands[$k].id' <<<"$map")
      num=$(jq -r --arg k "$key" '.islands[$k].number' <<<"$map")
      ititle=$(jq -r --arg k "$key" '.islands[$k].title' <<<"$map")
      summ=$(jq -r --arg k "$key" '.islands[$k].summary // ""' <<<"$map")
      ifile=$(jq -r --arg k "$key" '.islands[$k].file // ""' <<<"$map")
      status=$(wo show --id "$iid" --json | jq -r '.status')
      printf '<div class="ticket"><h4>'
      if [[ -n $ifile ]]; then
        printf '<a href="%s">%s. %s</a>' "$(html_escape "$ifile")" "$(html_escape "$num")" "$(html_escape "$ititle")"
      else
        printf '%s. %s' "$(html_escape "$num")" "$(html_escape "$ititle")"
      fi
      printf ' <span class="wo-id">%s</span> <span class="badge %s">%s</span></h4>' \
        "$(html_escape "$iid")" "$(html_escape "$status")" "$(html_escape "$status")"
      [[ -n $summ ]] && printf '<p>%s</p>' "$(html_escape "$summ")"
      [[ -z $ifile ]] && printf '<p class="dep">Not yet blueprinted - run <code>cartograph.sh island --spec %s.json</code></p>' "$(html_escape "$key")"
      printf '</div>'
    done < <(jq -r '.islands | to_entries | sort_by(.value.number) | .[].key' <<<"$map")
    ledger_html
  )

  local out; out=$(ps_tempfile)
  render_page "000" "$sys_title" "$sys_id" "$sys_status" "$body" \
    "cartograph.sh render --project ." >"$out"
  ps_atomic_install "$out" "$(carto_root)/000-macro-map.html"
}

# ---------------------------------------------------------------------------
# island
# ---------------------------------------------------------------------------

cmd_island() {
  require_jq; resolve_work_order
  ps_require_value spec "$spec"
  [[ -r $spec ]] || ps_die "$PS_IO" "spec_unreadable" "cannot read spec: $spec"
  jq -e . "$spec" >/dev/null 2>&1 || ps_die "$PS_VALIDATION" "spec_invalid" "$spec is not valid JSON"

  local doc map key
  doc=$(cat -- "$spec")
  map=$(read_map)
  key=$(jq -r '.island // empty' <<<"$doc")
  [[ -n $key ]] || ps_die "$PS_VALIDATION" "no_island_key" "spec has no \"island\""

  local iid
  iid=$(jq -r --arg k "$key" '.islands[$k].id // empty' <<<"$map")
  [[ -n $iid ]] || ps_die "$PS_NOTFOUND" "unknown_island" \
    "'$key' is not an island in this map. Known: $(jq -r '.islands | keys | join(", ")' <<<"$map")"

  local existing
  existing=$(jq -r --arg k "$key" '[.tickets[] | select(.island == $k)] | length' <<<"$map")
  ((existing == 0)) || ps_die "$PS_VALIDATION" "island_already_cut" \
    "island '$key' already has $existing ticket(s). Minting again would produce a second set with new ids and leave the first set orphaned. To refresh the document from current ticket state, run: cartograph.sh render --island $key"

  local n; n=$(jq -r '[.tickets[]? // empty] | length' <<<"$doc")
  ((n >= 1)) || ps_die "$PS_VALIDATION" "no_tickets" "island '$key' has no \"tickets\""

  local i node tkey
  for ((i = 0; i < n; i++)); do
    node=$(jq -c --argjson i "$i" '.tickets[$i]' <<<"$doc")
    tkey=$(jq -r '.key // empty' <<<"$node")
    [[ -n $tkey ]] || ps_die "$PS_VALIDATION" "ticket_no_key" "tickets[$i] has no \"key\""
    [[ -n $(jq -r '.title // empty' <<<"$node") ]] || ps_die "$PS_VALIDATION" "ticket_no_title" "ticket '$tkey' has no \"title\""
    [[ -n $(jq -r '.problem // empty' <<<"$node") ]] || ps_die "$PS_VALIDATION" "ticket_no_problem" "ticket '$tkey' has no \"problem\""
    require_ac "$node" "ticket '$tkey'"
  done

  mkdir -p "$(spec_store)" || ps_die "$PS_IO" "mkdir_failed" "cannot create $(spec_store)"

  for ((i = 0; i < n; i++)); do
    node=$(jq -c --argjson i "$i" '.tickets[$i]' <<<"$doc")
    tkey=$(jq -r '.key' <<<"$node")
    build_mint_args "$node"
    local tid
    tid=$(wo new --json --parent "$iid" --type "$(jq -r '.type // "feature"' <<<"$node")" \
      --title "$(jq -r '.title' <<<"$node")" --problem "$(jq -r '.problem' <<<"$node")" \
      "${MINT_ARGS[@]}" | jq -r '.id')
    [[ -n $tid && $tid != null ]] || ps_die "$PS_IO" "mint_failed" "work-order did not return an id for ticket '$tkey'"
    ps_info "  ticket $key/$tkey: $tid"
    map=$(jq --arg k "$key/$tkey" --arg id "$tid" --arg isl "$key" \
      '.tickets[$k] = {id:$id, island:$isl}' <<<"$map")
  done

  for ((i = 0; i < n; i++)); do
    node=$(jq -c --argjson i "$i" '.tickets[$i]' <<<"$doc")
    tkey=$(jq -r '.key' <<<"$node")
    local dep dep_id from_id
    from_id=$(jq -r --arg k "$key/$tkey" '.tickets[$k].id' <<<"$map")
    while IFS= read -r dep; do
      [[ -n $dep ]] || continue
      # A bare key means a sibling in this island; an explicit island/key or a
      # raw WO id reaches across islands.
      case "$dep" in
        WO-*) dep_id="$dep" ;;
        */*)  dep_id=$(jq -r --arg k "$dep" '.tickets[$k].id // empty' <<<"$map") ;;
        *)    dep_id=$(jq -r --arg k "$key/$dep" '.tickets[$k].id // empty' <<<"$map") ;;
      esac
      [[ -n $dep_id ]] || ps_die "$PS_NOTFOUND" "unknown_ticket_ref" \
        "ticket '$tkey' depends_on '$dep', which is not a ticket in this island or a known WO id"
      wo link --id "$from_id" --depends-on "$dep_id" >/dev/null
    done < <(jq -r '.depends_on[]? // empty' <<<"$node")
  done

  local num slug file
  num=$(jq -r --arg k "$key" '.islands[$k].number' <<<"$map")
  slug=$(jq -r --arg k "$key" '.islands[$k].title' <<<"$map" \
    | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | sed 's/^-//; s/-$//')
  file=$(printf '%03d-%s.html' "$num" "$slug")
  map=$(jq --arg k "$key" --arg f "$file" '.islands[$k].file = $f' <<<"$map")

  printf '%s' "$map" | write_map
  cp -- "$spec" "$(spec_store)/$key.json"
  render_island "$key"
  render_macro

  if ((PS_JSON)); then
    jq -n --arg k "$key" --arg id "$iid" --arg f "$file" \
      --argjson t "$(jq --arg k "$key" '[.tickets | to_entries[] | select(.value.island == $k) | .value.id]' <<<"$map")" \
      '{island:$k, epic:$id, file:$f, tickets:$t}'
  else
    ps_info "wrote $CARTO_DIR_NAME/$file"
  fi
}

render_island() {
  local key="$1" map doc
  map=$(read_map)
  [[ -r $(spec_store)/$key.json ]] || ps_die "$PS_NOTFOUND" "no_island_spec" \
    "no stored spec for island '$key' - it has not been blueprinted yet"
  doc=$(cat -- "$(spec_store)/$key.json")

  local iid num ititle status file
  iid=$(jq -r --arg k "$key" '.islands[$k].id' <<<"$map")
  num=$(jq -r --arg k "$key" '.islands[$k].number' <<<"$map")
  ititle=$(jq -r --arg k "$key" '.islands[$k].title' <<<"$map")
  file=$(jq -r --arg k "$key" '.islands[$k].file' <<<"$map")
  status=$(wo show --id "$iid" --json | jq -r '.status')

  local body
  body=$(
    local ov
    ov=$(jq -r '.overview // empty' <<<"$doc")
    [[ -n $ov ]] && { printf '<h2>Function</h2>'; printf '%s' "$ov"; }

    local nd; nd=$(jq -r '[.diagrams[]? // empty] | length' <<<"$doc")
    if ((nd > 0)); then
      printf '<h2>Internal logic</h2>'
      local j cap mm
      for ((j = 0; j < nd; j++)); do
        mm=$(jq -r --argjson j "$j" '.diagrams[$j].mermaid // empty' <<<"$doc")
        cap=$(jq -r --argjson j "$j" '.diagrams[$j].caption // empty' <<<"$doc")
        [[ -n $mm ]] || continue
        printf '<div class="mermaid">\n%s\n</div>' "$mm"
        [[ -n $cap ]] && printf '<p class="caption">%s</p>' "$(html_escape "$cap")"
      done
    fi

    printf '<h2>Execution tickets</h2>'
    printf '<div class="note">Every ticket below is a real work-order. An <strong>orange</strong> ticket is a skeleton: it has open questions, so <code>approve</code> refuses it and <code>next</code> will not offer it. Answer them with <code>work-order.sh resolve</code>.</div>'
    local tid
    while IFS= read -r tid; do
      [[ -n $tid ]] || continue
      render_ticket "$tid"
    done < <(jq -r --arg k "$key" '.tickets | to_entries | map(select(.value.island == $k)) | .[].value.id' <<<"$map")

    printf '<p class="dep"><a href="000-macro-map.html">&larr; back to the island map</a></p>'
  )

  local out; out=$(ps_tempfile)
  render_page "$(printf '%03d' "$num")" "$ititle" "$iid" "$status" "$body" \
    "cartograph.sh render --project . --island $key" >"$out"
  ps_atomic_install "$out" "$(carto_root)/$file"
}

# ---------------------------------------------------------------------------
# render
# ---------------------------------------------------------------------------

cmd_render() {
  require_jq; resolve_work_order
  local map; map=$(read_map)
  if [[ -n $island_key ]]; then
    [[ -n $(jq -r --arg k "$island_key" '.islands[$k].id // empty' <<<"$map") ]] || \
      ps_die "$PS_NOTFOUND" "unknown_island" "'$island_key' is not an island in this map"
    render_island "$island_key"
    render_macro
    ((PS_JSON)) && jq -n --arg k "$island_key" '{rendered:[$k]}' || ps_info "re-rendered island $island_key"
    return 0
  fi

  local rendered=() key
  while IFS= read -r key; do
    [[ -n $key ]] || continue
    [[ -r $(spec_store)/$key.json ]] || continue
    render_island "$key"
    rendered+=("$key")
  done < <(jq -r '.islands | keys[]' <<<"$map")
  render_macro

  if ((PS_JSON)); then
    printf '%s\n' "${rendered[@]+"${rendered[@]}"}" | grep -v '^$' | jq -R . | jq -s '{rendered:.}'
  else
    ps_info "re-rendered ${#rendered[@]} island document(s) and the macro map"
  fi
}

# ---------------------------------------------------------------------------
# Argument parsing.
# ---------------------------------------------------------------------------

subcommand="${1-}"
[[ -n $subcommand ]] || { usage; exit "$PS_USAGE"; }
shift || true

project="."
spec=""
island_key=""
wo_override=""
WO_BIN=""

while (($#)); do
  case "$1" in
    --project) project="${2-}"; shift 2 ;;
    --spec) spec="${2-}"; shift 2 ;;
    --island) island_key="${2-}"; shift 2 ;;
    --work-order) wo_override="${2-}"; shift 2 ;;
    --json) PS_JSON=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) ps_die "$PS_USAGE" "unknown_flag" "unknown flag: $1" ;;
  esac
done

project=$(ps_resolve_project "$project")

case "$subcommand" in
  plan)   cmd_plan ;;
  island) cmd_island ;;
  render) cmd_render ;;
  ledger) cmd_ledger ;;
  help|-h|--help) usage ;;
  *) ps_die "$PS_USAGE" "unknown_subcommand" "unknown subcommand: $subcommand" ;;
esac
