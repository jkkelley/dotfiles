#!/usr/bin/env bash
# A suffix IS the ID, so it has to be unique across issues/ and backlog/ both.
# S-05 M1: creation used to retry only when ln met the exact same file name,
# which needs the same second AND the same suffix - so a suffix already held by
# an entry from another second was minted again, and find_item then refused
# that ID for good. S-05 L5: a short mint (no /dev/urandom) was written as-is
# and log exited 0 with a name check rejects.
# SCAFFOLD_SUFFIX pins the mint; a comma list pins successive attempts, which
# is how the re-mint path is proven rather than left to 36^5 odds.
CASE_NAME=240-suffix-uniqueness
source "${SKILL:-/skill}/testing/assert.sh"

p=$(scaffolded_project)
iss() { log_issue --project "$p" --title "$1" --severity low --area a --symptom s --trigger t --cause c --fix f --verify v; }

got=$(SCAFFOLD_SUFFIX=aaaaa iss first 2>/dev/null)
assert_eq aaaaa "$got" "the pinned suffix is used when it is free"

# A later second, the same suffix: the file names differ, so ln alone accepts it.
run 4 "an issue suffix already held in issues/ is refused, not duplicated" \
  env SCAFFOLD_NOW=2026-08-05T14:40:00-05:00 SCAFFOLD_SUFFIX=aaaaa bash "$SKILL/scripts/log-issue.sh" \
  --project "$p" --title dup --severity low --area a --symptom s --trigger t --cause c --fix f --verify v
run 4 "a backlog suffix already held in issues/ is refused" \
  env SCAFFOLD_NOW=2026-08-05T14:41:00-05:00 SCAFFOLD_SUFFIX=aaaaa bash "$SKILL/scripts/backlog.sh" add \
  --project "$p" --title dup --why w --done-when d
assert_count 1 "$(find "$p/issues" "$p/backlog" -name '*-aaaaa.md' | wc -l)" "exactly one entry carries aaaaa"

got=$(SCAFFOLD_NOW=2026-08-05T14:42:00-05:00 SCAFFOLD_SUFFIX=aaaaa,bbbbb iss second 2>/dev/null)
assert_eq bbbbb "$got" "a taken suffix is re-minted, and the fresh one is used"
got=$(SCAFFOLD_NOW=2026-08-05T14:43:00-05:00 SCAFFOLD_SUFFIX=bbbbb,ccccc backlog add --project "$p" --title x --why w --done-when d 2>/dev/null)
assert_eq ccccc "$got" "backlog add re-mints past a suffix held in issues/"

# L5: a mint that is not 5 lowercase alphanumerics is an error, not a file.
run 4 "a short mint is refused" env SCAFFOLD_SUFFIX=abc bash "$SKILL/scripts/log-issue.sh" \
  --project "$p" --title short --severity low --area a --symptom s --trigger t --cause c --fix f --verify v
assert_count 0 "$(find "$p/issues" -name '*-abc.md' | wc -l)" "no entry is written under a short suffix"

run 0 "issues check is green" log_issue check --project "$p"
run 0 "backlog check is green" backlog check --project "$p"

finish
