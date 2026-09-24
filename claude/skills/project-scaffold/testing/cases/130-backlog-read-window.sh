#!/usr/bin/env bash
# The sliding-window rule, applied to the entry-tree model.
#
# Under the monolith the rule lived in three prose files. In the tree model
# the depth is enforced by the tool itself - backlog.sh list shows done/ at
# most 10 deep - with COMPASS.md restating it at the routing table. An agent
# cannot over-read done/ through the script, which is stronger than a sentence
# it was supposed to remember.
CASE_NAME=130-backlog-read-window
source "${SKILL:-/skill}/testing/assert.sh"

p=$(scaffolded_project)

# The routing table points at the trees and carries the window.
assert_contains "$p/COMPASS.md" '`issues/`' "COMPASS routes to the issues tree"
assert_contains "$p/COMPASS.md" "newest 10 entries only" "COMPASS carries the issues window"
assert_contains "$p/COMPASS.md" '`backlog/`' "COMPASS routes to the backlog tree"
assert_contains "$p/COMPASS.md" '`done/` newest 10 only' "COMPASS scopes the backlog window to done"

# The window itself: 12 done items, but list shows the newest 10 and stops.
for i in $(seq 1 12); do
  backlog add --project "$p" --title "item $i" --why W --done-when D --bucket now >/dev/null
done
for f in "$p"/backlog/now/*.md; do
  backlog done --project "$p" --id "$(basename "$f" .md | sed 's/.*-//')" >/dev/null
done
assert_count 12 "$(find "$p/backlog/done" -name '*.md' -type f | wc -l)" "all 12 items are retained in done/"
capture done_listing backlog list --project "$p" --bucket done
assert_count 10 "$(printf '%s\n' "$done_listing" | grep -c .)" "list shows the newest 10 of done and stops"

# Live buckets are exempt: all 12 in now/ would be listed in full, because a
# window over live work hides committed items an agent is supposed to pull.
q=$(scaffolded_project)
for i in $(seq 1 12); do
  backlog add --project "$q" --title "live $i" --why W --done-when D --bucket now >/dev/null
done
capture now_listing backlog list --project "$q" --bucket now
assert_count 12 "$(printf '%s\n' "$now_listing" | grep -c .)" "live buckets are listed in full"

finish
