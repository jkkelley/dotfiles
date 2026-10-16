#!/usr/bin/env bash
# treehouse-gate.sh - the dev gate for a treehouse upgrade: the new binary runs in podman against COPIES of the live pools,
# never the pools themselves, and every call the seat scripts make is proven to still behave before the host is updated.
#
#   treehouse-gate.sh --old BIN --new BIN --repos "ABS_REPO..." --pools "POOL_DIR_NAME..." --out FILE [--image IMG]
#   treehouse-gate.sh --inner ...      (run by the outer call inside the container; not for direct use)
#
# Owner order 2026-10-16 UTC (Design principles 101, item 34): dev, then UAT, then stable; dev is a podman sandbox.
# What it proves, per repo, with the new binary on the old binary's state:
#   C1 status --json keeps every slot's name, path, status, lease_id and lease_holder (no lease lost in a state upgrade)
#   C2 the coq seat.sh call, v2 flags only: get --lease --lease-holder H --no-fetch --json, then th_row finds H by status
#   C3 return PATH --if-lease-holder OTHER is refused and the lease stays
#   C4 return PATH --if-lease-holder H --force gives the slot back
#   C5 the v3 call workflow-spawn.sh makes: get --lease --lease-holder H -b BRANCH --no-fetch --json lands on BRANCH
#   C6 return without --force, stdin closed, on a clean slot (what herdr-grid.sh seat-down runs) gives it back
#   C7 the old binary still reads the state the new one wrote (the rollback path)
#   T  seconds for `git worktree add` + checkout of a new branch versus a lease of a pre-warmed slot
# YieldPoint pools are never copied: the caller names pools explicitly (owner, MSG-20261016-0605).
set -uo pipefail

if [ "${1:-}" = --inner ]; then
  shift; OLD=/opt/th-old/treehouse; NEW=/opt/th-new/treehouse; REPOS="$*"
  export GIT_CONFIG_GLOBAL=/tmp/gitconfig  # HOME is the owner's path, read-only here; the gate's git identity lives in /tmp
  git config --global user.email gate@example.com; git config --global user.name gate
  git config --global --add safe.directory '*'
  pass=1
  r() { printf '%s\n' "$*"; }
  chk() { if [ "$2" = 0 ]; then r "ok   $1"; else r "FAIL $1"; pass=0; fi; }
  proj='map({name,path,status,lease_id,lease_holder}) | sort_by(.name)'
  row() { "$NEW" status --json 2>/dev/null | jq -c --arg h "$1" '[.[]? | select(.lease_holder == $h)] | last // empty'; }
  for R in $REPOS; do
    cd "$R" || { r "FAIL cd $R"; pass=0; continue; }
    r "== repo $R"
    "$OLD" status --json 2>/dev/null > /tmp/s-old.json; chk "old status --json parses" $?
    "$NEW" status --json 2>/tmp/new-status.err > /tmp/s-new.json; chk "new status --json parses" $?
    r "     new-only fields: $(jq -c --slurpfile o /tmp/s-old.json '(.[0] // {} | keys) - ($o[0][0] // {} | keys)' /tmp/s-new.json)"
    diff <(jq -S "$proj" /tmp/s-old.json) <(jq -S "$proj" /tmp/s-new.json) >/tmp/d.txt; chk "C1 every slot and lease kept" $?
    [ -s /tmp/d.txt ] && sed 's/^/     /' /tmp/d.txt

    p="$("$NEW" get --lease --lease-holder gate-v2 --no-fetch --json 2>/tmp/e | jq -r .path)"
    r "     get --json keys: $("$NEW" status --json | jq -c --arg h gate-v2 '[.[]|select(.lease_holder==$h)][0]|keys')"
    [ -d "$p" ] && [ "$(row gate-v2 | jq -r .path)" = "$p" ] && [ -n "$(row gate-v2 | jq -r '.lease_id // empty')" ]
    chk "C2 coq v2 flags lease a slot and status finds holder, path, lease_id" $?
    "$NEW" return "$p" --if-lease-holder gate-other --force </dev/null >/dev/null 2>&1; rc=$?
    [ "$rc" != 0 ] && [ -n "$(row gate-v2)" ]; chk "C3 --if-lease-holder of another holder refused (exit $rc), lease kept" $?
    "$NEW" return "$p" --if-lease-holder gate-v2 --force </dev/null >/dev/null 2>&1; rc=$?
    [ "$rc" = 0 ] && [ -z "$(row gate-v2)" ]; chk "C4 return --if-lease-holder --force gives it back" $?

    br="gate/th-$$-$RANDOM"
    p="$("$NEW" get --lease --lease-holder gate-v3 -b "$br" --no-fetch --json 2>/tmp/e | jq -r .path)"
    [ -d "$p" ] && [ "$(git -C "$p" branch --show-current)" = "$br" ]; chk "C5 get -b lands the slot on the new branch" $?
    "$NEW" return "$p" --if-lease-holder gate-v3 </dev/null >/tmp/ret.out 2>&1; rc=$?
    [ "$rc" = 0 ] && [ -z "$(row gate-v3)" ]; chk "C6 return without --force, stdin closed, clean slot (exit $rc)" $?
    [ "$rc" = 0 ] || sed 's/^/     /' /tmp/ret.out
    "$OLD" status --json >/dev/null 2>&1; chk "C7 old binary reads the state the new one wrote" $?

    # T: the cost a seat start pays for its worktree, before (git worktree add) and after (lease of a pre-warmed slot)
    for i in 1 2 3; do
      d="/tmp/wt-$i"; b="gate/wt-$$-$i"
      s=$(date +%s.%N); git worktree add -q -b "$b" "$d" >/dev/null 2>&1; e=$(date +%s.%N)
      r "     T before git-worktree-add run $i: $(awk -v s="$s" -v e="$e" 'BEGIN{printf "%.3f", e-s}')s"
      git worktree remove --force "$d" >/dev/null 2>&1
      s=$(date +%s.%N); p="$("$NEW" get --lease --lease-holder gate-t -b "$b-th" --no-fetch --json 2>/dev/null | jq -r .path)"; e=$(date +%s.%N)
      r "     T after  treehouse-lease   run $i: $(awk -v s="$s" -v e="$e" 'BEGIN{printf "%.3f", e-s}')s"
      "$NEW" return "$p" --if-lease-holder gate-t --force </dev/null >/dev/null 2>&1
    done
  done
  if [ "$pass" = 1 ]; then r "GATE PASS"; exit 0; fi
  r "GATE FAIL"; exit 1
fi

OLD="" NEW="" REPOS="" POOLS="" OUT="" IMAGE="${IMAGE:-localhost/dotfiles-workflow-test:1}"
while [ $# -gt 0 ]; do
  case "$1" in
    --old) OLD="$2"; shift 2 ;; --new) NEW="$2"; shift 2 ;; --repos) REPOS="$2"; shift 2 ;;
    --pools) POOLS="$2"; shift 2 ;; --out) OUT="$2"; shift 2 ;; --image) IMAGE="$2"; shift 2 ;;
    *) echo "unknown arg $1" >&2; exit 2 ;;
  esac
done
for v in OLD NEW REPOS POOLS OUT; do [ -n "${!v}" ] || { echo "--${v,,} is required" >&2; exit 2; }; done
case " $POOLS " in *yieldpoint*) echo "refused: YieldPoint pools are never copied or touched" >&2; exit 3 ;; esac
STAGE="$(mktemp -d "${TMPDIR:-/tmp}/th-gate.XXXXXX")"; trap 'rm -rf "$STAGE"' EXIT
mkdir -p "$STAGE/th" "$STAGE/old" "$STAGE/new"
cp "$OLD" "$STAGE/old/treehouse"; cp "$NEW" "$STAGE/new/treehouse"
for p in $POOLS; do cp -a "$HOME/.treehouse/$p" "$STAGE/th/"; done
# the same absolute paths inside, because slot .git files and pool names point at them
mounts=(-v "$STAGE/th:$HOME/.treehouse:Z" -v "$STAGE/old:/opt/th-old:Z" -v "$STAGE/new:/opt/th-new:Z")
read -ra repos <<<"$REPOS"
for r in "${repos[@]}"; do mkdir -p "$STAGE/repo$r"; cp -a "$r/." "$STAGE/repo$r/"; mounts+=(-v "$STAGE/repo$r:$r:Z"); done
mounts+=(-v "$(readlink -f "$0"):/gate.sh:ro,Z")
{ printf 'old %s (%s)\nnew %s (%s)\npools %s\n' "$("$OLD" --version)" "$OLD" "$("$NEW" --version)" "$NEW" "$POOLS"
  podman run --rm --network=none --userns=keep-id -e HOME="$HOME" -e TREEHOUSE_NO_UPDATE_CHECK=1 "${mounts[@]}" "$IMAGE" \
    bash /gate.sh --inner "${repos[@]}"; } 2>&1 | tee -a "$OUT"
exit "${PIPESTATUS[0]}"
