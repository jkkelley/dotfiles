#!/usr/bin/env bash
# Text that fights back: a missing trailing newline, shell metacharacters, and
# a literal comment terminator inside a field value.
CASE_NAME=080-encoding-and-injection
source "${SKILL:-/skill}/testing/assert.sh"

p=$(scaffolded_project)

# Shell metacharacters must be written literally, never evaluated. If $(id) or
# `whoami` were ever expanded, the substituted text would appear instead.
log_issue --project "$p" \
  --title 'evil $(id) and `whoami` stay literal' --severity low --area sec \
  --symptom 'dollar $(uname) and backtick `hostname`' --trigger t --cause c --fix f --verify v >/dev/null
f=$(find "$p/issues" -name '*.md' -type f)
assert_contains "$f" 'evil $(id) and `whoami` stay literal' "command substitution written literally"
assert_not_contains "$f" "uid=" "no command was executed"

# A literal --> inside a value would terminate the metadata block early and
# corrupt every downstream parse, so it is neutralised.
log_issue --project "$p" --title 'ends the block --> here' --severity low --area sec \
  --symptom s --trigger t --cause c --fix f --verify v >/dev/null
g=$(grep -rl 'ends the block' "$p/issues")
assert_contains "$g" 'ends the block --&gt; here' "comment terminator neutralised"
# Bash 5.2 expands an unquoted & in a substitution replacement to the matched
# text. If that regressed, this would read ---->gt; instead.
assert_not_contains "$g" '---->gt;' "ampersand not expanded to the match"

# The metadata block must still parse: exactly one closing --> per entry,
# across every entry file in the tree.
opens=$(grep -rh '^<!-- issue$' "$p/issues" | wc -l)
closes=$(grep -rh '^-->$' "$p/issues" | wc -l)
assert_count "$opens" "$closes" "every metadata block is balanced"

# Multi-line values collapse to one line, which is what keeps entries a fixed
# size and the 10-deep window meaningful.
log_issue --project "$p" --title 'multi
line
title' --severity low --area fmt --symptom s --trigger t --cause c --fix f --verify v >/dev/null
h=$(grep -rl '^# multi line title$' "$p/issues")
assert_file "$h" "multi-line value collapsed to one line"

# No trailing newline: the appended section must not be glued to the last line.
r=$(new_project)
printf '%s' "$(head -20 "$SKILL/references/templates/COMPASS.md.tmpl")" >"$r/COMPASS.md"
run 0 "append to a file with no trailing newline" scaffold --project "$r" --apply --yes
assert_not_contains "$r/COMPASS.md" "Open it when<!-- scaffold" "no glued seam"

# A path containing spaces must survive quoting.
s="$WORK/dir with spaces"
mkdir -p "$s"
run 0 "path with spaces" scaffold --project "$s" --apply --yes
assert_file "$s/issues/.gitkeep" "scaffolded into a path with spaces"

finish
