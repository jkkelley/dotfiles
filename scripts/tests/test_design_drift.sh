#!/usr/bin/env bash
# rolodex: header reviewed
# name: test_design_drift.sh
# purpose: Test plan TP-1 to TP-8 for scripts/design-drift.sh. Run in podman: make design-drift-test.
# inputs: none; builds a throwaway git repo with a design.md and wireframes/README.md
# outputs: stdout ok / not ok lines; exit 0 when every case passes
# writes-to: a mktemp scratch path
# cleanup: removes its own temp files on exit
# Test plan for scripts/design-drift.sh (brief BR-20261016-design-drift, AC1). Run in podman: make design-drift-test.
# Rules out: frames passing after design.md moved on (the drift the check exists for), a README with no record
# passing, stamp not being idempotent, check writing files, and drift surviving a squash merge rewrite.
#
# Test plan (claude/workflow/templates/test-plan.md shape)
# Scope under test: scripts/design-drift.sh check and stamp.
# TP-1 intent: frames that reflect the current design pass, or every repo is red. expected: exit 0, "ok".
# TP-2 intent: design.md edited after the stamp must fail, the whole point (AC1). expected: exit 3, names design.md.
# TP-3 intent: a README with no record must fail, or drift hides behind a missing line. expected: exit 3.
# TP-4 intent: stamp is idempotent (item 28). expected: second stamp says "already", file bytes unchanged.
# TP-5 intent: check is read-only. expected: two runs, same output, no file changed.
# TP-6 intent: squash merge keeps a stamped pair in step. expected: exit 0 after the history is rewritten.
# TP-7 intent: a wireframes dir with no design.md is not a failure. expected: exit 0, "skip".
# TP-8 intent: bad usage is not mistaken for drift. expected: exit 2.
# Isolation: podman, localhost/dotfiles-workflow-test:1 built from claude/workflow/tests/container/Containerfile
# (debian bookworm-slim pinned by digest there). Out of scope, CI covers: the gate job wiring.
set -uo pipefail
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
DD=$HERE/../design-drift.sh
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
fails=0
check() { if [ "$1" = "$2" ]; then echo "ok - $3"; else echo "not ok - $3 (want $1, got $2)"; fails=$((fails + 1)); fi; }
has() { case $1 in *"$2"*) echo "ok - $3" ;; *) echo "not ok - $3 [$1]"; fails=$((fails + 1)) ;; esac; }
g() { git -C "$T/repo" -c user.name=t -c user.email=t@example.com "$@"; }

mkdir -p "$T/repo/site/wireframes" "$T/repo/bare/wireframes"
g init -q -b main
printf '# Site design\n\nv1\n' >"$T/repo/site/design.md"
printf '# Site wireframes\n\nFrames.\n' >"$T/repo/site/wireframes/README.md"
printf '# Bare wireframes\n' >"$T/repo/bare/wireframes/README.md"
g add -A && g commit -qm init
cd "$T/repo" || exit 1
R=site/wireframes/README.md

out=$(bash "$DD"); check 3 $? "TP-3 no record exits 3"
has "$out" "no Design-Reflects line" "TP-3 names the missing line"

out=$(bash "$DD" stamp "$R"); check 0 $? "stamp exits 0"
has "$out" "stamped" "stamp writes the record"
sum1=$(md5sum "$R")
out=$(bash "$DD" stamp "$R"); check 0 $? "TP-4 second stamp exits 0"
has "$out" "already" "TP-4 second stamp is a no-op"
check "$sum1" "$(md5sum "$R")" "TP-4 bytes unchanged"
g add -A && g commit -qm stamp

out=$(bash "$DD"); check 0 $? "TP-1 in step exits 0"
has "$out" "ok   $R" "TP-1 reports ok"
has "$out" "skip bare/wireframes/README.md" "TP-7 no design.md is skipped"

before=$(find . -path ./.git -prune -o -type f -exec md5sum {} + | sort)
a=$(bash "$DD"); ra=$?; b=$(bash "$DD"); rb=$?
after=$(find . -path ./.git -prune -o -type f -exec md5sum {} + | sort)
check "$a$ra" "$b$rb" "TP-5 two runs same output"
check "$before" "$after" "TP-5 nothing written"

# TP-6: squash the history into one fresh root commit, as gh pr merge --squash does to branch commits.
g checkout -q --orphan squashed && g commit -qm squashed && g branch -qD main
out=$(bash "$DD"); check 0 $? "TP-6 in step after squash exits 0"

printf '# Site design\n\nv2\n' >site/design.md
g commit -qam "design moves on"
out=$(bash "$DD"); check 3 $? "TP-2 design.md moved past the record exits 3"
has "$out" "site/design.md changed since" "TP-2 names design.md"
bash "$DD" stamp "$R" >/dev/null
bash "$DD" >/dev/null; check 0 $? "TP-2 restamp after redraw exits 0"

bash "$DD" --bogus >/dev/null 2>&1; check 2 $? "TP-8 bad option exits 2"
bash "$DD" stamp >/dev/null 2>&1; check 2 $? "TP-8 stamp with no README exits 2"
[ "$fails" = 0 ]
