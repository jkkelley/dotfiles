<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->

- [Scope AC template](#scope-ac-template)
  - [Rules](#rules)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

# Scope AC template

The scope acceptance criterion proves a branch touched only the files its ticket's In list names.
A design seat copies the line below into `--ac` and fills the alternation from the `touches:` lines, nothing else.

```text
`git diff --name-only origin/main...HEAD | grep -vE '^(work-orders/.*|<path\.one>|<dir/path\.two>)$'` exits 1 and prints nothing
```

## Rules

- `work-orders/.*` keeps the `.*`: the pattern is anchored with `^(...)$`, so a bare `work-orders/` matches only the literal path `work-orders/` and every generated ticket, INDEX.md and README.md file prints.
- Escape every `.` in a path as `\.`.
- A directory prefix that owns every file under it ends in `/.*`; a single file is written in full, with no `.*`.
- `grep -v` exits 1 only when it prints nothing, so "exits 1 and prints nothing" is the pass condition; exit 0 means a file outside scope.

GOOD: `grep -vE '^(work-orders/.*|scripts/rolodex\.py|tools/rolodex/tests/test_rolodex\.sh)$'`
NEVER: `grep -vE '^(work-orders/|scripts/rolodex\.py)$'` - prints every work-orders file and fails a branch that stayed in scope (WO-20261016-88d3, PR 219).
