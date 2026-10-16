#!/usr/bin/env bash
# rolodex: header reviewed
# name: test_pr_regen_index.sh
# purpose: Test plan TP-1 and TP-2 for scripts/pr-regen-index.sh. Run in podman: see the work order.
# inputs: none; builds a bare remote with a main and two branches, and a stub work-order.sh
# outputs: stdout ok / not ok lines; exit 0 when every case passes
# writes-to: a mktemp scratch path
# cleanup: removes its own temp files on exit
# TP-1 an index-only conflict is REGEN and pushed; TP-2 a real conflict aborts with CONFLICT-REAL.
# Isolation: podman, localhost/dotfiles-workflow-test:1. Out of scope, CI covers: the full scripts suite.
set -uo pipefail
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
S=$HERE/../pr-regen-index.sh
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
fails=0
ok() { echo "ok  $1"; }
no() { echo "not ok  $1"; fails=$((fails + 1)); }
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@e.com GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@e.com
mkdir -p "$T/df/claude/skills/work-order/scripts"
printf '#!/bin/sh\nexit 0\n' >"$T/df/claude/skills/work-order/scripts/work-order.sh"
export DOTFILES=$T/df TMPDIR=$T
git init -q --bare "$T/remote.git"
git init -q -b main "$T/r"
R=$T/r
g() { git -C "$R" "$@"; }
mkdir -p "$R/work-orders"
echo base >"$R/work-orders/INDEX.md"; echo base >"$R/real.txt"
g add -A; g commit -qm init; g remote add origin "$T/remote.git"; g push -q origin main
g switch -q -c idx; echo branch >"$R/work-orders/INDEX.md"; g commit -qam idx; g push -q origin idx
g switch -q main; g switch -q -c real; echo branch >"$R/real.txt"; g commit -qam real; g push -q origin real
g switch -q main; echo main >"$R/work-orders/INDEX.md"; echo main >"$R/real.txt"; g commit -qam main; g push -q origin main

out=$(bash "$S" --repo "$R" --branches idx)
head=$(git -C "$T/remote.git" show idx:work-orders/INDEX.md)
if [[ $out == *"idx REGEN PUSHED"* ]] && [ "$head" = main ] && git -C "$T/remote.git" merge-base --is-ancestor main idx; then
  ok "index-only conflict is REGEN and pushed"; else no "index-only conflict is REGEN and pushed [$out]"; fi

before=$(git -C "$T/remote.git" rev-parse real)
out=$(bash "$S" --repo "$R" --branches real)
if [[ $out == *"real CONFLICT-REAL real.txt"* ]] && [ "$before" = "$(git -C "$T/remote.git" rev-parse real)" ]; then
  ok "a real conflict aborts with CONFLICT-REAL"; else no "a real conflict aborts with CONFLICT-REAL [$out]"; fi
[ -z "$(g worktree list | sed 1d)" ] && ok "no worktree left behind" || no "worktree left behind"
exit $((fails > 0))
