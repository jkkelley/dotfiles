#!/usr/bin/env bash
# The scratch directory must outlive the command substitution that asked for a
# temp file. ps_tempfile is only ever called as `tmp=$(ps_tempfile)`, and the
# EXIT trap it installed used to run when that substitution closed - deleting
# the directory, and the file just created in it, before the caller could write
# a byte. Every mutating command failed with "No such file or directory"; only
# close worked, because it alone initialised the scratch dir eagerly first.
source "${SKILL:-/skill}/testing/assert.sh"

lib="${SKILL:-/skill}/scripts/lib/common.sh"

run 0 "a temp file survives the command substitution that made it" \
  bash -c 'source "$1"; f=$(ps_tempfile); [ -e "$f" ]' _ "$lib"

run 0 "a temp file is writable by its caller" \
  bash -c 'source "$1"; f=$(ps_tempfile); printf hi >"$f"; [ "$(cat "$f")" = hi ]' _ "$lib"

run 0 "two calls return distinct paths" \
  bash -c 'source "$1"; a=$(ps_tempfile); b=$(ps_tempfile); [ "$a" != "$b" ]' _ "$lib"

# The fix must not trade a corruption bug for a leak.
run 0 "the scratch directory is removed when the shell exits" \
  bash -c '
    p=$(bash -c "source \"\$1\"; printf %s \"\$PS_SCRATCH\"" _ "$1")
    [ -n "$p" ] || exit 1
    [ ! -d "$p" ]
  ' _ "$lib"
