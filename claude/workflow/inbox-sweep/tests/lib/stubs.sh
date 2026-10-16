# shellcheck shell=bash
# Sourced by tests. stubs_install <dir> copies the stubs into <dir> as `herdr` and `claude.exe`, sets TEST_OUT if the
# caller has not, and prepends <dir> to PATH. Copies, not symlinks: a symlink target outside the mount would break in a
# container started with a different mount layout.
stubs_install() {
  local dir="$1" lib
  lib="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  mkdir -p "$dir"
  cp "$lib/stub-herdr.sh" "$dir/herdr"
  cp "$lib/stub-claude-exe.sh" "$dir/claude.exe"
  chmod +x "$dir/herdr" "$dir/claude.exe"
  : "${TEST_OUT:=$dir/../out}"
  mkdir -p "$TEST_OUT"
  : >"$TEST_OUT/calls.log"
  export TEST_OUT
  export PATH="$dir:$PATH"
}
