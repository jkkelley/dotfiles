#!/usr/bin/env bash
# The cache is only useful if staleness is DETECTED. A cache trusted while stale
# is worse than no cache at all.
CASE_NAME=090-cache-freshness
source "${SKILL:-/skill}/testing/assert.sh"

p=$(scaffolded_project)

capture a log_issue --project "$p" --title "Alpha" --severity high --area export \
  --symptom s --trigger t --cause c --fix f --verify v
log_issue --project "$p" --title "Beta" --severity low --area ui \
  --symptom s --trigger t --cause c --fix f --verify v >/dev/null
log_issue --project "$p" --resolves "$a" --title "Alpha fixed" --severity high --area export \
  --symptom s --trigger t --cause c --fix f --verify v >/dev/null
backlog add --project "$p" --title "Task" --why W --done-when D --bucket now >/dev/null

run 0 "verify with no cache reports absence" bash -c \
  "bash '$SKILL/scripts/cache.sh' verify --project '$p' >/dev/null 2>&1; [ \$? -eq 3 ]"

run 0 "build" cache build --project "$p"
for s in index issues open-issues backlog map naming; do
  assert_file "$p/.claude/cache/$s.json" "built $s.json"
done

run 0 "verify is fresh right after a build" cache verify --project "$p"

# The one thing the cache computes: an issue is open until a later entry
# resolves it. This is exactly what a 10-deep window cannot answer alone.
assert_not_contains "$p/.claude/cache/open-issues.json" '"id":"ISS-0001"' "resolved issue is not open"
assert_contains "$p/.claude/cache/open-issues.json" '"id":"ISS-0002"' "unresolved issue is open"

# Mutating a source must make the cache stale, and the write tools must say so.
log_issue --project "$p" --title "Gamma" --severity low --area x \
  --symptom s --trigger t --cause c --fix f --verify v >/dev/null
run 3 "verify detects a mutated source" cache verify --project "$p"
capture stale cache verify --project "$p" --json
case $stale in *'"stale":["ISSUES.md"]'*) _pass "names the stale source" ;;
  *) _fail "names the stale source" "got: $stale" ;; esac

run 0 "rebuild restores freshness" cache build --project "$p"
run 0 "verify fresh again" cache verify --project "$p"

# A tampered hash must be reported, not crashed on.
sed -i 's/"sha256": "[a-f0-9]*"/"sha256": "deadbeef"/' "$p/.claude/cache/index.json"
run 3 "tampered hash reports stale" cache verify --project "$p"

# The cache is derived: deleting it loses nothing.
rm -rf "$p/.claude/cache"
run 0 "rebuild from scratch" cache build --project "$p"
run 0 "fresh after rebuild" cache verify --project "$p"

finish
