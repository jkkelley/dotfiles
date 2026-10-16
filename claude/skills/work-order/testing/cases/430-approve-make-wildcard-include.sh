#!/usr/bin/env bash
# rolodex: header drafted by scripts/rolodex.py headers - correct any line that is wrong
# name: 430-approve-make-wildcard-include.sh
# purpose: Assert approve resolves a make target reached through a self-dir wildcard include and still refuses a missing one.
# inputs: env SKILL (skill root, default /skill); sourced assert.sh helpers
# outputs: exit code 0 when every assertion passes, assertion lines on stdout
# writes-to: scratch project dirs under $WORK (mktemp), removed with the test sandbox
# cleanup: the sandbox container is discarded; nothing outside $WORK is touched
# The reason this case exists.
#
# WO-20261016-0f38: approve refused "tool_missing wiki-process" for a target
# defined in a file that wiki.mk reaches with
# `-include $(wildcard $(WIKI_DIR)mk/*.mk)`, where WIKI_DIR is wiki.mk's own
# directory. The resolver skipped every include holding a `$`.
source "${SKILL:-/skill}/testing/assert.sh"

d=$(git_project)
mkdir -p "$d/sub/mk"
printf 'include sub/s.mk\n' >"$d/Makefile"
printf 'D := $(dir $(lastword $(MAKEFILE_LIST)))\n-include $(wildcard $(D)mk/*.mk)\n' >"$d/sub/s.mk"
printf 'pt:\n\t@true\n' >"$d/sub/mk/p.mk"
git -C "$d" add -A && git -C "$d" commit -qm "wildcard include" && git -C "$d" push -q origin main

mk() { # mk <title> [extra new args...]
  local t="$1"; shift
  wo new --project "$d" --title "$t" --type feature --problem P --top-level --out X --ac ok "$@" >/dev/null
  wo list --project "$d" --json | jq -r --arg t "$t" '.[] | select(.title == $t) | .id'
}
appr() { wo approve --project "$d" --id "$1" --no-lavish --reason "no lavish in CI"; }

id=$(mk "Behind wildcard" --in 'step: run `make pt`')
run 0 "approve passes a make target behind a self-dir wildcard include" appr "$id"

id=$(mk "Absent behind wildcard" --in 'step: run `make absent`')
run 3 "approve still refuses a make target that is not defined" appr "$id"
