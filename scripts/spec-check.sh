#!/usr/bin/env bash
# rolodex: header reviewed
# name: spec-check.sh
# purpose: every XML spec is 1000 lines or less, parses, and opens with a contents element.
# inputs: FILE... arguments; env BASE (origin/main), LIMIT (1000), PATTERN (*.spec.xml)
# outputs: stdout ok/FAIL lines; exit 0 ok, 3 violation, 2 usage
# writes-to: nothing (read-only)
# cleanup: none needed
# spec-check.sh - every XML spec is 1000 lines or less, parses, and opens with a contents element.
# Owner order 2026-10-16 UTC, Design principles 101 item 28: "xml specs 1000 lines or less with content list and
# mermaid code for doc design first with graceful recovery and idempotentency, automation forever NEVER HAND FED".
# Usage: spec-check.sh [FILE...]   (default: *.spec.xml changed vs BASE, plus modified and untracked ones)
# Inputs: BASE (default origin/main), LIMIT (default 1000), PATTERN (default *.spec.xml), all from env or Make.
# Exit: 0 every file ok (or nothing in scope), 3 any violation, 2 bad usage.
# Read-only: it writes nothing, so two runs give the same output.
set -uo pipefail

BASE=${BASE:-origin/main}
LIMIT=${LIMIT:-1000}
PATTERN=${PATTERN:-*.spec.xml}

case ${1:-} in
  -h|--help) sed -n '2,8p' "$0"; exit 0 ;;
  -*) echo "spec-check: unknown option $1" >&2; exit 2 ;;
esac
case $LIMIT in ''|*[!0-9]*) echo "spec-check: LIMIT must be a whole number, got [$LIMIT]" >&2; exit 2 ;; esac

# Same scope rule as md-contents.sh: explicit files, else changed vs BASE, else every tracked spec.
if [ "$#" -gt 0 ]; then
  files=("$@")
else
  root=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "spec-check: not in a git repo and no FILE given" >&2; exit 2; }
  cd "$root" || exit 2
  if git rev-parse --verify -q "$BASE" >/dev/null; then
    mapfile -t files < <({ git diff --name-only --diff-filter=AM "$BASE"...HEAD -- "$PATTERN"
                           git ls-files -m -o --exclude-standard -- "$PATTERN"; } | sort -u)
  else
    mapfile -t files < <(git ls-files -- "$PATTERN")
  fi
fi
[ "${#files[@]}" -gt 0 ] || { echo "spec-check: nothing in scope"; exit 0; }

# The parse uses xmllint --noout when it is on PATH (the brief's tool); the pinned test image and some hosts
# carry only python3, so xml.etree is the fallback rather than a package added to the image (the same call
# claude/workflow/inbox-sweep/bin/spec-lint.sh made). The contents check always uses python3: it needs the
# first child element of the root, which xmllint --noout cannot report.
first_child() {
  python3 -I -c 'import sys, xml.etree.ElementTree as E
try: r = E.parse(sys.argv[1]).getroot()
except Exception as e: print("PARSE", e); sys.exit(1)
k = list(r)
print(k[0].tag if k else "")' "$1" 2>&1
}

failed=0
for f in "${files[@]}"; do
  if [ ! -f "$f" ]; then printf 'FAIL %s: no such file\n' "$f"; failed=1; continue; fi
  # awk counts a last line with no trailing newline too, so a 1000-line file passes either way.
  n=$(awk 'END{print NR}' "$f")
  bad=()
  [ "$n" -le "$LIMIT" ] || bad+=("$n lines, limit $LIMIT")
  if command -v xmllint >/dev/null 2>&1 && ! err=$(xmllint --noout "$f" 2>&1); then
    bad+=("not well-formed XML (${err%%$'\n'*})")
  elif ! tag=$(first_child "$f"); then
    bad+=("not well-formed XML (${tag#PARSE })")
  elif [ "${tag:-}" != contents ]; then
    bad+=("first child element is <${tag:-none}>, want <contents>")
  fi
  if [ "${#bad[@]}" -eq 0 ]; then printf 'ok   %s (%s lines)\n' "$f" "$n"
  else for b in "${bad[@]}"; do printf 'FAIL %s: %s\n' "$f" "$b"; done; failed=1; fi
done
[ "$failed" = 0 ] || exit 3
