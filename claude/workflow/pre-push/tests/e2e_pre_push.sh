#!/usr/bin/env bash
# name: e2e_pre_push.sh
# purpose: end to end, the real dotfiles gate list refuses a push of a tracked-ignored path and passes once it is untracked (TP-7)
# inputs: the repository mounted read-only at /src, in the workflow test image
# note: git 2.39 sends a pre-push hook stdout to stdout, not stderr (fixed in later git), so the refused push is read with 2>&1
# outputs: PREPUSH-RED line on the refused push, last line E2E-OK; exit 1 on any mismatch
# writes-to: /tmp/r.git and /tmp/c inside the container
# cleanup: the container is run with --rm
set -e
git config --global user.email t@example.com
git config --global user.name t
git config --global --add safe.directory "*"
# a seat runs from a worktree, whose .git file points at a host path the container cannot see: rebuild a repo from the files
SRC=/src
if [ -f /src/.git ]; then
  mkdir /tmp/s && tar -C /src --exclude=.git -cf - . | tar -C /tmp/s -xf -
  git -C /tmp/s init -q -b main && git -C /tmp/s add -A && git -C /tmp/s commit -qm base
  SRC=/tmp/s
fi
git clone -q --bare "$SRC" /tmp/r.git
git clone -q /tmp/r.git /tmp/c
cd /tmp/c
git remote set-url origin https://github.com/jkkelley/dotfiles.git
git remote set-url --push origin /tmp/r.git
git fetch -q /tmp/r.git main:refs/remotes/origin/main
bash claude/workflow/pre-push/pre-push.sh install --repo /tmp/c
git checkout -q -b t
echo x > work-orders/INDEX.md
git add -f work-orders/INDEX.md
git commit -qm red
if git push -q origin t > /tmp/push.err 2>&1; then echo UNEXPECTED-PUSH; exit 1; fi
grep -q "PREPUSH-RED.*tracked-ignored-check" /tmp/push.err
git rm -q --cached work-orders/INDEX.md
git commit -qm green
git push -q origin t
echo E2E-OK
