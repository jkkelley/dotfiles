#!/usr/bin/env bash
# Decides whether a pull request has to run `make -C claude/workflow test`, from the paths it changed.
#
# Reads changed paths on stdin, one per line (the gate pipes `git diff --name-only BASE...HEAD` in), and prints one
# GITHUB_OUTPUT line: workflow=true|false.
#
# Why it lives here and not in .github/scripts/bump-gate.sh detect: the list below is this suite's own dependency
# list, and the suite is the thing that knows it. When a test here starts calling a script from another skill, the
# person adding that call is in this directory, next to this file and to test_ci_job.sh, which pins the list.
#
# The paths, and why each one is on it:
#   claude/workflow/                     the machinery and its suite
#   claude/skills/context-compaction/    test_compaction.sh and test_seat_watch.sh run its checkpoint.sh
#   claude/skills/work-order/            test_test_plan.sh runs work-order's test-plan parser
#   .github/workflows/skill-pr-gate.yml  the job that runs this suite; a change to it is proved by running it
set -euo pipefail
hit=false
while IFS= read -r p; do
  case $p in
    claude/workflow/* | claude/skills/context-compaction/* | claude/skills/work-order/* | .github/workflows/skill-pr-gate.yml)
      hit=true ;;
  esac
done
printf 'workflow=%s\n' "$hit"
