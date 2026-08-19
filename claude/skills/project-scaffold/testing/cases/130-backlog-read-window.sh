#!/usr/bin/env bash
# The sliding-window rule reaches BACKLOG.md, not just ISSUES.md.
#
# The rule only works if an agent meets it where it is looking. A scaffolded
# project states it in three places on purpose - CLAUDE.md is the rule, COMPASS
# routes to it, and BACKLOG.md restates it at the point of use - so an agent
# that opens BACKLOG.md directly, without reading CLAUDE.md first, still stops
# at 10. If any one of those drops the rule, the default silently becomes
# "read all 20 Done entries" and nothing fails loudly.
CASE_NAME=130-backlog-read-window
source "${SKILL:-/skill}/testing/assert.sh"

p=$(scaffolded_project)

assert_contains "$p/CLAUDE.md" "\`BACKLOG.md\`" "CLAUDE.md names BACKLOG in the sliding-window rule"
assert_contains "$p/CLAUDE.md" "top 10 of \`Done\` only" "CLAUDE.md scopes the window to Done"
assert_contains "$p/COMPASS.md" "top 10 entries only" "COMPASS.md carries the window into its routing table"
assert_contains "$p/BACKLOG.md" "Read protocol:" "BACKLOG.md restates the rule at the point of use"
assert_contains "$p/BACKLOG.md" "top 10 entries and stop" "BACKLOG.md states the depth"

# The distinction that makes it correct rather than merely consistent: Now /
# Next / Later are live work. A window over those would hide committed work an
# agent is supposed to pull from, which is worse than reading too much.
assert_contains "$p/CLAUDE.md" "read them in full" "live buckets are exempt from the window"
assert_contains "$p/BACKLOG.md" "in full - that is live work" "BACKLOG.md exempts the live buckets too"

# Retention is 20 and the read window is 10 - two different numbers, and the
# file has to say why, or the next reader will "fix" one to match the other.
assert_contains "$p/BACKLOG.md" "trimmed to the last 20" "retention limit still documented"

finish
