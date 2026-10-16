#!/usr/bin/env bash
# AC-H1, AC-H2, AC-H3 for node B2: the three seat brief templates.
# shellcheck disable=SC2016 # the ${VAR} placeholders are literal text in the templates, single quotes are the point
# Rules out: a brief that reaches a seat without the owner's words (the 2026-10-15 hand run had no owner text and the
# seat improvised), a forbidden list that drifted from the spec rules because someone retyped it, an em dash or a
# two-sentence line sneaking into a Markdown output (spec rule `prose`), and a placeholder the renderer
# (envsubst over a fixed variable list, spec `briefs/render`) would leave unreplaced.
set -uo pipefail
R="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=_t.sh
. "$R/tests/unit/_t.sh"
SPEC="${SWEEP_SPEC:-$R/../../../docs/design/inbox-sweep.spec.xml}"
TPL="${SWEEP_TEMPLATES:-$R/templates}"
FILES="brief-gmail.md brief-proton.md brief-linkedin.md"
BROWSER="brief-proton.md brief-linkedin.md"
RULES="no-send untrusted own-tab no-credentials"
RENDER_VARS="RUN_ID SEAT ACCOUNT DEADLINE_AT RESULT_PATH SCHEMA_PATH MARK_READ OWNER_WORDS"

rule_text() { sed -n "s|^ *<rule id=\"$1\">\(.*\)</rule>\$|\1|p" "$SPEC"; }
# One sentence per line, the way the templates hold it; the join below proves the split lost nothing.
rule_lines() { rule_text "$1" | sed 's/\. \([A-Z]\)/.\n\1/g'; }
expected_forbidden() { local r; for r in $RULES; do echo; echo "Rule $r:"; rule_lines "$r"; done; }
actual_forbidden() { sed -n '/^<forbidden>$/,/^<\/forbidden>$/p' "$1" | sed '1d;$d'; }

for r in $RULES tab-anchor; do
  check yes "$([ -n "$(rule_text "$r")" ] && echo yes)" "spec rule $r is found, so the diffs below compare against something"
  check "$(rule_text "$r")" "$(rule_lines "$r" | paste -sd' ')" "splitting rule $r into lines loses no text"
done

for f in $FILES; do
  t="$TPL/$f"
  # AC-H1
  check 1 "$(grep -c '^<owner-words>$' "$t")" "$f opens one owner-words block"
  check 1 "$(grep -c '^</owner-words>$' "$t")" "$f closes one owner-words block"
  check '${OWNER_WORDS}' "$(sed -n '/^<owner-words>$/,/^<\/owner-words>$/p' "$t" | sed '1d;$d')" "$f holds the owner words variable and nothing else inside the block"
  check yes "$([ "$(grep -n '^<owner-words>$' "$t" | cut -d: -f1)" -lt "$(grep -n '^<forbidden>$' "$t" | cut -d: -f1)" ] && echo yes)" "$f puts the owner words before the forbidden list"
  # AC-H2
  if diff <(expected_forbidden) <(actual_forbidden "$t") >/dev/null; then ok "$f forbidden list is verbatim from the spec rules"; else bad "$f forbidden list differs from the spec rules" "$(diff <(expected_forbidden) <(actual_forbidden "$t") | head -5)"; fi
  # the result path and schema path are in the brief
  check 1 "$(grep -c '^Result path: ${RESULT_PATH}$' "$t")" "$f names the result path"
  check 1 "$(grep -c '^Schema path: ${SCHEMA_PATH}$' "$t")" "$f names the schema path"
  # AC-H3
  check 0 "$(grep -c $'\xe2\x80\x94' "$t")" "$f has no em dash"
  check 0 "$(grep -cE '[.!?] [A-Z]' "$t")" "$f has one sentence per line"
  # Every placeholder must be one the renderer substitutes.
  unknown="$(grep -o '\${[A-Za-z_]*}' "$t" | tr -d '${}' | sort -u | grep -vxF -f <(tr ' ' '\n' <<<"$RENDER_VARS") || true)"
  check "" "$unknown" "$f uses only the render variables"
done

for f in $BROWSER; do
  t="$TPL/$f"
  check 1 "$(grep -c '^## Browser check$' "$t")" "$f carries the browser check"
  check yes "$(grep -q 'BLOCKED-NO-BROWSER' "$t" && echo yes)" "$f names BLOCKED-NO-BROWSER"
  check yes "$(grep -qxF -f <(rule_lines tab-anchor) "$t" && [ "$(grep -cxF -f <(rule_lines tab-anchor) "$t")" -eq "$(rule_lines tab-anchor | wc -l)" ] && echo yes)" "$f carries every line of rule tab-anchor verbatim"
  check yes "$(grep -q 'tab_group' "$t" && echo yes)" "$f tells the seat to record tab_group"
done
check 0 "$(grep -c 'tab-anchor\|tabs_context_mcp\|list_connected_browsers' "$TPL/brief-gmail.md")" "the Gmail brief is connector only and names no browser tool"
check yes "$(grep -q 'BLOCKED-CONNECTOR' "$TPL/brief-gmail.md" && echo yes)" "the Gmail brief names BLOCKED-CONNECTOR"

# Mutation: the comparator must fail when a rule is edited, or AC-H2 would pass on anything.
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
sed 's/never sends, replies/sometimes sends, replies/' "$TPL/brief-gmail.md" >"$T/m.md"
if diff <(expected_forbidden) <(actual_forbidden "$T/m.md") >/dev/null; then bad "a reworded no-send rule is caught by the forbidden diff"; else ok "a reworded no-send rule is caught by the forbidden diff"; fi
printf 'one. Two\n' >"$T/p.md"
check 1 "$(grep -cE '[.!?] [A-Z]' "$T/p.md")" "a two-sentence line is caught by the sentence check"
printf 'a \xe2\x80\x94 b\n' >"$T/e.md"
check 1 "$(grep -c $'\xe2\x80\x94' "$T/e.md")" "an em dash is caught by the dash check"
finish
