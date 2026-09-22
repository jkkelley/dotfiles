#!/usr/bin/env bash
# check: the tree validator. Every fault it exists to catch gets planted here,
# and each assertion is on the exit code PLUS the offender being named -
# a red check that does not say what is wrong is only half the feature.
CASE_NAME=190-check
source "${SKILL:-/skill}/testing/assert.sh"

# A fresh, empty tree is clean.
p=$(scaffolded_project)
run 0 "empty issues tree is clean" log_issue check --project "$p"
run 0 "empty backlog tree is clean" backlog check --project "$p"

# A populated, well-formed tree is clean.
log_issue --project "$p" --title ok --severity low --area a \
  --symptom s --trigger t --cause c --fix f --verify v >/dev/null
backlog add --project "$p" --title ok --why w --done-when d --bucket now >/dev/null
run 0 "populated tree is clean" log_issue check --project "$p"
run 0 "populated tree is clean (backlog scope)" backlog check --project "$p"

mk_issue() { # mk_issue <dir> <name> - a minimal well-formed entry by hand
  mkdir -p "$(dirname "$1")"
  cat >"$1" <<EOF
# planted

<!-- issue
id: ${2}
logged: 2026-08-05T19:32:11Z
severity: low
area: test
tags: -
refs: -
resolves: -
-->

- **Symptom** - s
- **Trigger** - t
- **Cause** - c
- **Resolution** - r
- **Verification** - v
EOF
}

# --- a file in the wrong shard: its name says 2026/09, it sits in 2026/01
p=$(scaffolded_project)
mk_issue "$p/issues/2026/01/20260922T143005Z-a1b2c.md" a1b2c
run 3 "wrong shard is caught" log_issue check --project "$p"
capture msg bash -c "bash '$SKILL/scripts/log-issue.sh' check --project '$p' 2>&1"
case $msg in *"2026/01/20260922T143005Z-a1b2c.md"*) _pass "the offender is named" ;;
  *) _fail "the offender is named" "got: $msg" ;; esac

# --- a duplicate suffix anywhere in the tree
p=$(scaffolded_project)
mk_issue "$p/issues/2026/08/20260805T193211Z-dup01.md" dup01
mk_issue "$p/issues/2026/09/20260922T143005Z-dup01.md" dup01
run 3 "duplicate suffix is caught" log_issue check --project "$p"
capture msg bash -c "bash '$SKILL/scripts/log-issue.sh' check --project '$p' 2>&1"
case $msg in *"not unique"*) _pass "the duplicate is named" ;;
  *) _fail "the duplicate is named" "got: $msg" ;; esac

# --- a dangling resolves: a pointer to an entry that is not there
p=$(scaffolded_project)
mk_issue "$p/issues/2026/08/20260805T193211Z-a1b2c.md" a1b2c
sed -i 's/^resolves: -$/resolves: zzzzz/' "$p/issues/2026/08/20260805T193211Z-a1b2c.md"
run 3 "dangling resolves is caught" log_issue check --project "$p"
capture msg bash -c "bash '$SKILL/scripts/log-issue.sh' check --project '$p' 2>&1"
case $msg in *"zzzzz"*) _pass "the dangling target is named" ;;
  *) _fail "the dangling target is named" "got: $msg" ;; esac

# --- a missing mandatory field
p=$(scaffolded_project)
mk_issue "$p/issues/2026/08/20260805T193211Z-a1b2c.md" a1b2c
sed -i '/^- \*\*Verification\*\* - /d' "$p/issues/2026/08/20260805T193211Z-a1b2c.md"
run 3 "missing field is caught" log_issue check --project "$p"
capture msg bash -c "bash '$SKILL/scripts/log-issue.sh' check --project '$p' 2>&1"
case $msg in *"missing the Verification field"*) _pass "the missing field is named" ;;
  *) _fail "the missing field is named" "got: $msg" ;; esac

# --- an id that disagrees with its filename
p=$(scaffolded_project)
mk_issue "$p/issues/2026/08/20260805T193211Z-a1b2c.md" other
run 3 "id/suffix mismatch is caught" log_issue check --project "$p"

# --- a monolith beside the directories
p=$(scaffolded_project)
printf '# ISSUES\n' >"$p/ISSUES.md"
run 3 "monolith beside the tree is caught" log_issue check --project "$p"
printf '# BACKLOG\n' >"$p/BACKLOG.md"
run 3 "backlog monolith beside the tree is caught" backlog check --project "$p"

# --- backlog scope: missing done-when, and a done file in the wrong shard
p=$(scaffolded_project)
mkdir -p "$p/backlog/now"
cat >"$p/backlog/now/20260805T193211Z-b1c2d.md" <<'EOF'
# planted item

<!-- item
id: b1c2d
added: 2026-08-05T19:32:11Z
-->

- why: w
EOF
run 3 "missing done-when is caught" backlog check --project "$p"

p=$(scaffolded_project)
mkdir -p "$p/backlog/done/2025/01"
cat >"$p/backlog/done/2025/01/20260805T193211Z-b1c2d.md" <<'EOF'
# planted item

<!-- item
id: b1c2d
added: 2026-08-05T19:32:11Z
completed: 2026-08-06T00:00:00Z
-->

- why: w
- done-when: d
EOF
run 3 "done file in the wrong shard is caught" backlog check --project "$p"

# --- a stray file that is not an entry at all
p=$(scaffolded_project)
printf 'notes\n' >"$p/issues/notes.md"
run 3 "stray file is caught" log_issue check --project "$p"

finish
