#!/usr/bin/env bash
# spec-lint.sh - node B19 of the inbox sweep: every spec file is well-formed XML and 1000 lines or fewer.
#
#   spec-lint.sh [spec.xml ...]      default: every docs/design/*.spec.xml in the repository
#
# Why: a spec that grows past 1000 lines is a spec no agent reads whole, and seats then work from a stale slice of
# it. The cap is the owner's rule for specs (design section 10, node B19); the fix for a long spec is to split it,
# never to raise the cap here.
# Output: one `ok  <file> (<n> lines)` line per clean file; `FAIL <file>: <n> lines, limit 1000` for an over-long
# one; `FAIL <file>: not well-formed XML (<reason>)` for a broken one. Exit 1 if any file failed, 2 on bad usage.
# Lines are counted the way wc -l counts, plus a final line with no trailing newline, so a 1000-line file passes
# whether or not its last line ends in a newline.
# XML is parsed with python3's xml.etree (in the pinned workflow test image) rather than xmllint, which the image
# does not carry; adding a package to the image for a well-formedness check was the rejected alternative.
set -uo pipefail
LIMIT=1000
R="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"

if [ $# -gt 0 ]; then
  files=("$@")
else
  shopt -s nullglob
  files=("$R"/docs/design/*.spec.xml)
  [ ${#files[@]} -gt 0 ] || { echo "spec-lint: no docs/design/*.spec.xml found" >&2; exit 2; }
fi

failed=0
for f in "${files[@]}"; do
  if [ ! -f "$f" ]; then printf 'FAIL %s: no such file\n' "$f"; failed=1; continue; fi
  n="$(awk 'END{print NR}' "$f")"
  bad=0
  if [ "$n" -gt "$LIMIT" ]; then
    printf 'FAIL %s: %s lines, limit %s\n' "$f" "$n" "$LIMIT"; bad=1
  fi
  if ! err="$(python3 -I -c 'import sys, xml.etree.ElementTree as E
try: E.parse(sys.argv[1])
except Exception as e: print(e); sys.exit(1)' "$f" 2>&1)"; then
    printf 'FAIL %s: not well-formed XML (%s)\n' "$f" "$err"; bad=1
  fi
  if [ "$bad" = 0 ]; then printf 'ok  %s (%s lines)\n' "$f" "$n"; else failed=1; fi
done
exit "$failed"
