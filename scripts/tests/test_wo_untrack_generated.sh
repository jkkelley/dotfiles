#!/usr/bin/env bash
# rolodex: header reviewed
# name: test_wo_untrack_generated.sh
# purpose: Test plan TP-1 to TP-3 for scripts/wo-untrack-generated.sh. Run in podman: see the work order.
# inputs: none; builds a temp repo with a bare remote and a stub gh
# outputs: stdout ok / not ok lines; exit 0 when every case passes
# writes-to: a mktemp scratch path
# cleanup: removes its own temp files on exit
# TP-1 plan writes nothing; TP-2 apply untracks INDEX.md and READMEs and adds the ignore lines; TP-3 a second apply is WO-UNTRACK-NOCHANGE.
# Isolation: podman, localhost/dotfiles-workflow-test:1. Out of scope, CI covers: the full scripts suite.
set -uo pipefail
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
S=$HERE/../wo-untrack-generated.sh
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
fails=0
ok() { echo "ok  $1"; }
no() { echo "not ok  $1"; fails=$((fails + 1)); }
git init -q --bare "$T/remote.git"
git init -q -b main "$T/r"
R=$T/r
g() { git -C "$R" -c user.name=t -c user.email=t@example.com "$@"; }
mkdir -p "$R/work-orders/WO-1"
echo idx >"$R/work-orders/INDEX.md"; echo rd >"$R/work-orders/WO-1/README.md"
g add -A; g commit -qm init; g remote add origin "$T/remote.git"; g push -q origin main
mkdir -p "$T/bin"; printf '#!/bin/sh\necho "stub gh $*"\n' >"$T/bin/gh"; chmod +x "$T/bin/gh"
# stub work-order.sh so the test needs no real tickets
mkdir -p "$T/df/claude/skills/work-order/scripts"
printf '#!/bin/sh\nexit 0\n' >"$T/df/claude/skills/work-order/scripts/work-order.sh"
export PATH=$T/bin:$PATH DOTFILES=$T/df GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@e.com GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@e.com

before=$(g status --porcelain; g rev-parse HEAD)
out=$(bash "$S" --repo "$R"); after=$(g status --porcelain; g rev-parse HEAD)
[ "$before" = "$after" ] && [[ $out == *"UNTRACK work-orders/INDEX.md"* && $out == *"UNTRACK work-orders/WO-1/README.md"* && $out == *"IGNORE /work-orders/INDEX.md"* ]] \
  && ok "plan writes nothing" || no "plan writes nothing [$out]"

out=$(bash "$S" --repo "$R" --apply); rc=$?
tracked=$(g ls-files work-orders | grep -c -e INDEX.md -e README.md)
if [ $rc = 0 ] && [ "$tracked" = 0 ] && grep -qxF '/work-orders/INDEX.md' "$R/.gitignore" && grep -qxF '/work-orders/**/README.md' "$R/.gitignore" \
   && [[ $out == *"ROLLBACK git -C"* ]] && [ -f "$R/work-orders/INDEX.md" ]; then ok "apply untracks INDEX.md and READMEs and adds the ignore lines"; else no "apply [$rc $tracked $out]"; fi

out=$(bash "$S" --repo "$R" --apply)
[ "$out" = "WO-UNTRACK-NOCHANGE" ] && ok "a second apply is WO-UNTRACK-NOCHANGE" || no "second apply [$out]"
exit $fails
