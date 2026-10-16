#!/usr/bin/env bash
# main-clone-guard.sh - say whether a primary clone is on its branch and current; fast-forward it when that is safe. No model calls.
# name: main-clone-guard.sh
# purpose: report MAIN-DRIFT when a clone is off its branch, behind, dirty or diverged; ff it only when safe
# inputs: VERB (check|ff), CLONE, [BRANCH=main], [REMOTE=origin]
# outputs: one status line on stdout; exit 0 ok/skip, 3 MAIN-DRIFT, 2 usage
# writes-to: CLONE's own refs and working tree on ff only (git fetch, git merge --ff-only)
# cleanup: none (one-shot)
#
# usage: main-clone-guard.sh check|ff CLONE [BRANCH] [REMOTE]
# BREADCRUMB - WO-20261016-3327 (ORD-0830 RR-orch-14).
# What broke: seat dag-t6b ran work-order.sh start inside the ~/dotfiles primary clone and left it on feat/dag-state-t6 at
#   c7bd763 for 40+ min; every seat calling ~/dotfiles tools ran stale code (wr2-feed ENV-MISSING on claude/tools/shot).
#   Evidence: ~/.local/state/zenith/breakglass/2026/10/20261016-095436-main-clone-efb2-start-stamp.patch
# Why this fix: one generic check; ff never switches branches, stashes or resets, it only fast-forwards a clean clone.
# Cost: a dirty or diverged clone stays MAIN-DRIFT until the orchestrator breaks glass (item 33).
set -uo pipefail
usage() { echo "usage: main-clone-guard.sh check|ff CLONE [BRANCH] [REMOTE]" >&2; exit 2; }
if [ $# -lt 2 ] || [ $# -gt 4 ]; then usage; fi
verb=$1; clone=$2; branch=${3:-main}; remote=${4:-origin}
case "$verb" in check|ff) ;; *) usage ;; esac
if ! git -C "$clone" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "skip main-clone $clone: not a git clone"; exit 0
fi
timeout 30 git -C "$clone" fetch -q "$remote" "$branch" 2>/dev/null \
  || echo "warn main-clone fetch failed, using last fetched $remote/$branch" >&2
short=$(git -C "$clone" rev-parse --short HEAD)
cur=$(git -C "$clone" symbolic-ref -q --short HEAD || echo detached)
if [ "$cur" != "$branch" ]; then
  echo "MAIN-DRIFT $clone on $cur at $short, want $branch"; exit 3
fi
n=$(git -C "$clone" rev-list --count "HEAD..$remote/$branch" 2>/dev/null || echo 0)
if [ "$n" -eq 0 ]; then
  echo "ok main-clone $clone $branch $short"; exit 0
fi
if [ "$verb" = check ]; then
  echo "MAIN-DRIFT $clone behind $remote/$branch by $n"; exit 3
fi
if [ -n "$(git -C "$clone" status --porcelain --untracked-files=no)" ]; then
  echo "MAIN-DRIFT $clone dirty, cannot fast-forward"; exit 3
fi
if git -C "$clone" merge --ff-only -q "$remote/$branch" >/dev/null 2>&1; then
  echo "ok main-clone $clone fast-forwarded $short..$(git -C "$clone" rev-parse --short HEAD)"; exit 0
fi
echo "MAIN-DRIFT $clone diverged from $remote/$branch"; exit 3
