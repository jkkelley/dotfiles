#!/usr/bin/env bash
# migrate: a one-time conversion of a monolith into entry files.
# The round-trip must preserve every field, put each entry in the shard its
# own timestamp implies, rewrite internal references to the new suffixes, and
# refuse to run twice.
CASE_NAME=180-migrate
source "${SKILL:-/skill}/testing/assert.sh"

# --- issues ---------------------------------------------------------------
p=$(new_project)
cat >"$p/ISSUES.md" <<'EOF'
# ISSUES

Newest first. Written only by the `project-scaffold` skill's `log-issue.sh` - never by hand.

<!-- scaffold:section=issues-log -->
<!-- ISSUES:BEGIN - log-issue.sh inserts directly below this line -->

## ISS-0003 - Export now preserves the when clause

<!-- issue
id: ISS-0003
logged: 2026-09-01T09:00:00+00:00
severity: high
area: export
tags: fixed
refs: -
resolves: ISS-0001
-->

- **Symptom** - bindings fired globally after import
- **Trigger** - export a context-scoped binding
- **Cause** - serialiser wrote a fixed field list
- **Resolution** - serialise from the schema
- **Verification** - round-trip test added

---

## ISS-0002 - Second problem

<!-- issue
id: ISS-0002
logged: 2026-08-10T12:00:00-05:00
severity: low
area: ui
tags: -
refs: ISS-0001
resolves: -
-->

- **Symptom** - s2
- **Trigger** - t2
- **Cause** - c2
- **Resolution** - pending
- **Verification** - none yet

---

## ISS-0001 - First problem

<!-- issue
id: ISS-0001
logged: 2026-08-05T16:10:02-05:00
severity: medium
area: export
tags: data-loss
refs: -
resolves: -
-->

- **Symptom** - s1
- **Trigger** - t1
- **Cause** - c1
- **Resolution** - r1
- **Verification** - v1

---
EOF

run 0 "issues migrate exits 0" log_issue migrate --project "$p"
assert_count 3 "$(find "$p/issues" -name '*.md' -type f | wc -l)" "every monolith entry became a file"
assert_no_file "$p/ISSUES.md" "monolith is gone"
assert_file "$p/ISSUES.md.migrated" "monolith renamed aside, not deleted"

# Shards come from each entry's own logged timestamp, converted to UTC.
first=$(grep -rl '^# First problem$' "$p/issues")
case $first in
  "$p/issues/2026/08/20260805T211002Z-"*) _pass "shard and name preserve the entry timestamp" ;;
  *) _fail "shard and name preserve the entry timestamp" "got: $first" ;; esac
second=$(grep -rl '^# Second problem$' "$p/issues")
case $second in
  "$p/issues/2026/08/20260810T170000Z-"*) _pass "timezone offset normalised to UTC" ;;
  *) _fail "timezone offset normalised to UTC" "got: $second" ;; esac
third=$(grep -rl '^# Export now preserves' "$p/issues")
case $third in
  "$p/issues/2026/09/"*) _pass "a later month gets its own shard" ;;
  *) _fail "a later month gets its own shard" "got: $third" ;; esac

# Fields survive the round-trip.
assert_contains "$first" "- **Symptom** - s1" "body fields preserved"
assert_contains "$first" "severity: medium" "metadata fields preserved"
assert_contains "$first" "tags: data-loss" "tags preserved"

# Internal references are rewritten to the NEW suffixes, forming the same DAG.
id1=$(basename "$first" .md | sed 's/.*-//')
assert_contains "$third" "resolves: ${id1}" "resolves rewritten to the new suffix"
assert_contains "$second" "refs: ${id1}" "refs rewritten to the new suffix"
assert_not_contains "$third" "ISS-0001" "no sequential ID survives"

# The migrated tree validates clean.
run 0 "check is green after issues migrate" log_issue check --project "$p"

# Idempotent: a second run refuses rather than double-writing.
run 3 "second issues migrate is refused" log_issue migrate --project "$p"

# --- backlog ----------------------------------------------------------------
q=$(new_project)
cat >"$q/BACKLOG.md" <<'EOF'
# BACKLOG

<!-- scaffold:section=now -->

## Now

<!-- BACKLOG:NOW -->

- [ ] **BK-0001** - In flight item
  <!-- item
  id: BK-0001
  added: 2026-08-05T14:32:11-05:00
  -->
  - why: it matters
  - done-when: it is checkable

<!-- scaffold:section=next -->

## Next

<!-- BACKLOG:NEXT -->

<!-- scaffold:section=later -->

## Later

<!-- BACKLOG:LATER -->

- [ ] **BK-0002** - Someday item
  <!-- item
  id: BK-0002
  added: 2026-07-01T10:00:00+00:00
  -->
  - why: captured
  - done-when: phrased as a check

<!-- scaffold:section=done -->

## Done

<!-- BACKLOG:DONE -->

- [x] **BK-0003** - Finished item
  <!-- item
  id: BK-0003
  added: 2026-06-01T10:00:00+00:00
  completed: 2026-06-20
  -->
  - why: it was needed
  - done-when: it shipped
EOF

run 0 "backlog migrate exits 0" backlog migrate --project "$q"
assert_count 3 "$(find "$q/backlog" -name '*.md' -type f | wc -l)" "every monolith item became a file"
assert_no_file "$q/BACKLOG.md" "backlog monolith is gone"
assert_file "$q/BACKLOG.md.migrated" "backlog monolith renamed aside"

inflight=$(grep -rl '^# In flight item$' "$q/backlog")
case $inflight in
  "$q/backlog/now/"*) _pass "live item lands in its bucket directory" ;;
  *) _fail "live item lands in its bucket directory" "got: $inflight" ;; esac
someday=$(grep -rl '^# Someday item$' "$q/backlog")
case $someday in
  "$q/backlog/later/"*) _pass "later item keeps its bucket" ;;
  *) _fail "later item keeps its bucket" "got: $someday" ;; esac
finished=$(grep -rl '^# Finished item$' "$q/backlog")
case $finished in
  "$q/backlog/done/2026/06/20260620T000000Z-"*) _pass "done item sharded by its completion date" ;;
  *) _fail "done item sharded by its completion date" "got: $finished" ;; esac
assert_contains "$finished" "completed: 2026-06-20T00:00:00Z" "completion date preserved in metadata"
assert_contains "$inflight" "- done-when: it is checkable" "done-when preserved"

run 0 "check is green after backlog migrate" backlog check --project "$q"
run 3 "second backlog migrate is refused" backlog migrate --project "$q"

# The window order survives: the newest logged entry sorts first in a
# directory walk, exactly where the monolith's top entry used to sit.
newest=$(find "$p/issues" -name '*.md' -type f | sort -r | head -1)
assert_eq "$third" "$newest" "newest entry sorts first in the window walk"

# --- S-05 H1: a cross-tree ref survives migration --------------------------
# The old log-issue.sh documented `--refs BK-014` as normal usage. Two separate
# migrates each held half the map, so the BK token was kept verbatim, `check`
# rejected it, and immutable entries meant no sanctioned command could ever turn
# `check` green again. One migrate, one map, both monoliths.
x=$(new_project)
cat >"$x/ISSUES.md" <<'EOF'
## ISS-0001 - Blocks the backlog item

<!-- issue
id: ISS-0001
logged: 2026-08-05T16:10:02-05:00
severity: medium
area: export
tags: -
refs: BK-0001
resolves: -
-->

- **Symptom** - s1
- **Trigger** - t1
- **Cause** - c1
- **Resolution** - r1
- **Verification** - v1
EOF
cat >"$x/BACKLOG.md" <<'EOF'
<!-- BACKLOG:NOW -->

- [ ] **BK-0001** - The item it blocks
  <!-- item
  id: BK-0001
  added: 2026-08-05T14:32:11-05:00
  -->
  - why: it matters
  - done-when: it is checkable
EOF
run 0 "one migrate converts both monoliths" log_issue migrate --project "$x"
assert_no_file "$x/ISSUES.md" "ISSUES.md renamed aside by the combined migrate"
assert_no_file "$x/BACKLOG.md" "BACKLOG.md renamed aside by the same run"
iss=$(grep -rl '^# Blocks the backlog item$' "$x/issues")
item=$(grep -rl '^# The item it blocks$' "$x/backlog")
bk_suffix=$(basename "$item" .md | sed 's/.*-//')
assert_contains "$iss" "refs: ${bk_suffix}" "the BK ref is rewritten to the item's new suffix"
run 0 "issues check is green after a cross-tree migrate" log_issue check --project "$x"
run 0 "backlog check is green after a cross-tree migrate" backlog check --project "$x"

# --- S-05 H2: a refused migrate writes nothing and can be rerun -----------
# A bad timestamp on entry N used to be found after entries 1..N-1 were written.
# The rerun was then refused as already_migrated, and logging was refused
# because the monolith was still there: stuck, with hand deletion the only exit.
y=$(new_project)
cp "$x/ISSUES.md.migrated" "$y/ISSUES.md"
cp "$x/BACKLOG.md.migrated" "$y/BACKLOG.md"
cat >>"$y/ISSUES.md" <<'EOF'

## ISS-0002 - Broken timestamp

<!-- issue
id: ISS-0002
logged: not a date
severity: low
area: ui
tags: -
refs: -
resolves: -
-->

- **Symptom** - s2
- **Trigger** - t2
- **Cause** - c2
- **Resolution** - r2
- **Verification** - v2
EOF
run 3 "migrate with one bad timestamp is refused" log_issue migrate --project "$y"
assert_count 0 "$(find "$y" -name '*.md' -path '*/issues/*' -o -name '*.md' -path '*/backlog/*' | wc -l)" "a refused migrate writes no entry file in either tree"
assert_file "$y/ISSUES.md" "ISSUES.md is untouched after a refused migrate"
assert_file "$y/BACKLOG.md" "BACKLOG.md is untouched after a refused migrate"
sed -i 's/^logged: not a date$/logged: 2026-08-06T10:00:00+00:00/' "$y/ISSUES.md"
run 0 "the corrected monolith migrates on the rerun" backlog migrate --project "$y"
run 0 "check is green after the rerun" log_issue check --project "$y"

finish
