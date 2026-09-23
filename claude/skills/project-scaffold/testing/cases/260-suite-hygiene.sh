#!/usr/bin/env bash
# Properties of the tools and the suite that no behaviour test would notice
# going wrong until it bit.
CASE_NAME=260-suite-hygiene
source "${SKILL:-/skill}/testing/assert.sh"

# --- S-05 L7: no two case files share a numeric prefix. The runner orders by
# glob, so a shared prefix makes run order depend on the rest of the name.
dups=$(for d in "$SKILL"/testing/cases "$SKILL"/testing/cases-git; do
  ls "$d" | sed -n 's/^\([0-9]*\)-.*\.sh$/\1/p' | sort | uniq -d | sed "s#^#$(basename "$d")/#"
done)
assert_eq "" "$dups" "every case file has its own numeric prefix"

# --- S-05 L8: every digest pin in the runner names its human-readable version
# in the comment above it (root CLAUDE.md Rule 15). A bare digest cannot be
# repinned by anyone who did not choose it.
while IFS= read -r ln; do
  name=${ln%%=*}
  block=$(awk -v n="$name" '/^#/ { c = c $0 "\n"; next } index($0, n "=") == 1 { print c; exit } { c = "" }' "$SKILL/testing/run-tests.sh")
  if grep -qE '[a-z]+(:|[[:space:]])[0-9]+\.[0-9]+' <<<"$block"; then _pass "$name digest comment names its version"; else _fail "$name digest comment names its version" "$block"; fi
done < <(grep -E '^[A-Z_]+=.*@sha256:' "$SKILL/testing/run-tests.sh")

# --- S-05 L6: the flock lock is gone, and so is every promise it made. flock
# is absent from Git Bash (Rule 17), creation needs no lock, and a documented
# exit 5 that can never happen sends an agent down a branch that is dead.
if grep -qE 'ps_with_lock|flock|PS_LOCK' "$SKILL/scripts/lib/common.sh"; then _fail "common.sh carries no lock helper" "$(grep -nE 'ps_with_lock|flock|PS_LOCK' "$SKILL/scripts/lib/common.sh")"; else _pass "common.sh carries no lock helper"; fi
for f in scripts/log-issue.sh scripts/backlog.sh SKILL.md references/templates/AGENTS.md.tmpl; do
  assert_not_contains "$SKILL/$f" "lock timeout" "$f documents no lock-timeout exit"
  assert_not_contains "$SKILL/$f" "lock-timeout" "$f documents no --lock-timeout flag"
done
p=$(scaffolded_project)
run 2 "--lock-timeout is an unknown flag now" log_issue check --project "$p" --lock-timeout 5

# --- S-05 L4: ps_check_tree's census split must not leak IFS=' ' into the rest
# of the function, or into ps_check_refs, which it calls. Every expansion there
# is quoted today; this keeps it harmless when one is not.
# The fixture is written by hand, not by backlog.sh, so this check exercises
# ps_check_tree alone and cannot pass because some other tool failed first.
mkdir -p "$p/backlog/later"
printf '# t\n\n<!-- item\nid: abcde\nadded: 2026-08-05T19:32:11Z\n-->\n\n- why: w\n- done-when: d\n' \
  >"$p/backlog/later/20260805T193211Z-abcde.md"
seen=$(bash -c '
  IFS=$'"'"'\n\t'"'"'
  source "$1/scripts/lib/common.sh"
  ps_check_refs() { printf "%q" "$IFS" >&3; }
  ps_check_tree "$2" backlog >/dev/null 2>&1 || true
' _ "$SKILL" "$p" 3>&1)
assert_eq "$(printf '%q' $'\n\t')" "$seen" "ps_check_refs runs with the caller's IFS, not the census split's"

finish
