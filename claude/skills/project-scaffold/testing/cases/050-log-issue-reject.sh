#!/usr/bin/env bash
# Every rejection path. A validator that never rejects anything is not a
# validator, so most of this case is negative tests - and each asserts the
# specific exit code, not merely "it failed".
CASE_NAME=050-log-issue-reject
source "${SKILL:-/skill}/testing/assert.sh"

p=$(scaffolded_project)

# Missing required fields, with stdin closed so no prompt is reachable.
run 2 "missing required fields" bash -c \
  "exec </dev/null; bash '$SKILL/scripts/log-issue.sh' --project '$p' --title x"
assert_count 0 "$(find "$p/issues" -name '*.md' -type f | wc -l)" "rejected write left the tree empty"

run 2 "empty required value" bash -c \
  "exec </dev/null; bash '$SKILL/scripts/log-issue.sh' --project '$p' --title '' --severity low --area a --symptom s --trigger t --cause c --fix f --verify v"

run 3 "invalid severity" bash -c \
  "exec </dev/null; bash '$SKILL/scripts/log-issue.sh' --project '$p' --title x --severity URGENT --area a --symptom s --trigger t --cause c --fix f --verify v"

run 2 "unknown flag" log_issue --project "$p" --bogus x
run 6 "resolves a suffix that does not exist" log_issue --project "$p" --resolves zzzzz \
  --title x --severity low --area a --symptom s --trigger t --cause c --fix f --verify v
run 2 "malformed resolves ID" log_issue --project "$p" --resolves ISS-0041 \
  --title x --severity low --area a --symptom s --trigger t --cause c --fix f --verify v
run 2 "malformed refs ID" log_issue --project "$p" --refs BK-0014 \
  --title x --severity low --area a --symptom s --trigger t --cause c --fix f --verify v

# A hand-written monolith beside the tree is two sources of truth: refuse and
# point at migrate rather than write beside it.
q=$(new_project)
printf '# ISSUES\n\nHand-written, old format.\n' >"$q/ISSUES.md"
cp "$q/ISSUES.md" "$WORK/monolith-before.md"
run 3 "monolith is refused" log_issue --project "$q" --title x --severity low --area a \
  --symptom s --trigger t --cause c --fix f --verify v
assert_same "$q/ISSUES.md" "$WORK/monolith-before.md" "monolith untouched by the refusal"

# A read-only directory must fail loudly rather than half-write.
r=$(new_project)
bash "$SKILL/scripts/scaffold.sh" --project "$r" --apply --yes >/dev/null 2>&1
chmod a-w "$r"
run 4 "read-only project directory" log_issue --project "$r" --title x --severity low --area a \
  --symptom s --trigger t --cause c --fix f --verify v
chmod u+w "$r"

# --help must load on every entry point: it catches syntax errors in code paths
# the happy path never reaches.
run 0 "log-issue --help" log_issue --help
run 0 "backlog --help" backlog --help
run 0 "scaffold --help" scaffold --help
run 0 "cache --help" cache --help

finish
