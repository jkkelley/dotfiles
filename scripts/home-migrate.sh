#!/usr/bin/env bash
# rolodex: header reviewed
# name: home-migrate.sh
# purpose: move a project's scattered clones and worktrees into one home directory, leaving a symlink at every old path.
# inputs: plan|apply|check|rolodex|rollback CONF=<home project.json>; env ONLY (one old path), PASSES (1), WAIT (60), ARTIFACT_ROOT
# outputs: stdout one status-coded line per item; exit 0 ok, 2 usage, 3 conflict or failed check, 4 items still busy
# writes-to: the home (apply only), a symlink at each old path, <ARTIFACT_ROOT>/state/home-migrate/<name>/, a log under <ARTIFACT_ROOT>/log/
# cleanup: none needed; it never deletes, and a second apply changes nothing
# home-migrate.sh - move a project's scattered clones and worktrees into one home directory.
# Design: docs/design/home-migrate.md, spec docs/design/home-migrate.spec.xml.
# Owner words, 2026-10-16 UTC: "get everything yieldpoint to be moved in there unless there is a good reason not to".
# Usage: home-migrate.sh plan|apply|check|rolodex|rollback CONF
#   plan   read-only: one line per item, status MOVE / DONE / BUSY / CONFLICT / KEEP
#   apply  moves every MOVE item (git worktree move for a worktree, mv for a clone), symlinks the old path, logs
#   check  read-only proof: every item DONE and resolving through its old path, every byte_for_byte manifest equal
#   rollback ONLY=<old path> required: put one DONE item back (drop our symlink, move it home again); BUSY waits
#   rolodex  read-only: print the home's ROLODEX.md (places, worktrees, old paths, exceptions) to stdout
# Status codes: MOVE planned; DONE in the home with a symlink at the old path; BUSY a live process or herdr seat has
#   its cwd inside it, so it waits for the next pass; CONFLICT the target exists and is not ours, nothing is touched;
#   KEEP a stated exception (reason printed); FAIL a check or a move that did not land.
# Never deletes, never prunes, never overwrites. Rerun from any state lands in the same end state.
set -uo pipefail

usage() { sed -n '10,21p' "$0"; exit 2; }
[ $# -eq 2 ] || usage
VERB=$1 CONF=$2
case $VERB in plan|apply|check|rolodex|rollback) ;; *) usage ;; esac
[ -f "$CONF" ] || { echo "home-migrate: no config at $CONF" >&2; exit 2; }
{ command -v jq && command -v git; } >/dev/null || { echo "home-migrate: needs jq and git" >&2; exit 2; }
PASSES=${PASSES:-1} WAIT=${WAIT:-60}
case $PASSES$WAIT in *[!0-9]*) echo "home-migrate: PASSES and WAIT are whole numbers" >&2; exit 2 ;; esac

x() { local p; p=$(jq -r "$1 // empty" "$CONF"); printf '%s' "${p/#\~/$HOME}"; }
NAME=$(jq -r '.name // empty' "$CONF")
HOMEDIR=$(x .home) SRC=$(x .source_root) WTDIR=$(jq -r '.worktrees_dir // ".worktrees"' "$CONF")
if [ -z "$NAME" ] || [ -z "$HOMEDIR" ] || [ -z "$SRC" ]; then echo "home-migrate: config needs name, home, source_root" >&2; exit 2; fi
[ -d "$HOMEDIR" ] || { echo "home-migrate: home $HOMEDIR does not exist" >&2; exit 2; }
ROOT=${ARTIFACT_ROOT:-${XDG_STATE_HOME:-$HOME/.local/state}/zenith}
STATE=$ROOT/state/home-migrate/$NAME

# items: kind<TAB>src<TAB>dst, one per line. ONLY=<old path> narrows every verb to that one item (the UAT gate).
items() { if [ -n "${ONLY:-}" ]; then all_items | awk -F'\t' -v o="${ONLY%/}" '$2 == o'; else all_items; fi; }
# all_items: clones by name, then every paths entry, then every real directory a glob matches.
all_items() {
  local r p
  while IFS= read -r r; do [ -n "$r" ] && printf 'clone\t%s\t%s\n' "$SRC/$r" "$HOMEDIR/$r"; done < <(jq -r '.repos[]?' "$CONF")
  # paths: any other directory, moved by mv to a home-relative target
  jq -r '.paths[]? | "\(.src)\t\(.dst)"' "$CONF" | while IFS=$'\t' read -r p g; do
    printf 'clone\t%s\t%s\n' "${p/#\~/$HOME}" "$HOMEDIR/$g"
  done
  while IFS= read -r g; do
    [ -n "$g" ] || continue
    for p in "$SRC"/$g; do
      [ -e "$p" ] || [ -L "$p" ] || continue
      if [ -f "$p/.git" ] || { [ -L "$p" ] && [ "$(readlink "$p")" = "$HOMEDIR/$WTDIR/${p##*/}" ]; }; then
        printf 'worktree\t%s\t%s\n' "$p" "$HOMEDIR/$WTDIR/${p##*/}"
      elif [ -d "$p" ] && [ ! -L "$p" ]; then
        printf 'clone\t%s\t%s\n' "$p" "$HOMEDIR/$WTDIR/${p##*/}"
      fi
    done
  done < <(jq -r '.worktree_globs[]?' "$CONF")
}

# holders: snapshot every process cwd and herdr seat cwd once, as "cwd<TAB>holder" lines. Scanning /proc per item was
# minutes on a 50-item tree; one snapshot per pass is under a second. apply takes a fresh one right before each move.
HOLDERS=$(mktemp); trap 'rm -f "$HOLDERS"' EXIT
holders() {
  local pid c
  for pid in /proc/[0-9]*; do
    c=$(readlink "$pid/cwd" 2>/dev/null) && printf '%s\tpid %s:%s\n' "$c" "${pid#/proc/}" "$(cat "$pid/comm" 2>/dev/null)"
  done >"$HOLDERS"
  if command -v herdr >/dev/null; then
    herdr agent list 2>/dev/null | jq -r '.result.agents[]? | "\(.cwd)\therdr \(.name // .pane_id)"' >>"$HOLDERS"
  fi
}
# busy <dir>: print the first holder whose cwd is inside dir; status 0 when busy.
busy() { awk -F'\t' -v d="$1/" 'index($1 "/", d) == 1 { print $2; f = 1; exit } END { exit !f }' "$HOLDERS"; }

# linked worktrees of a clone that still sit at a real path (their seats keep the clone busy too)
linked() { git -C "$1" worktree list --porcelain 2>/dev/null | sed -n 's/^worktree //p' | tail -n +2; }

manifest() { (cd "$1" && find . -type f -print0 | LC_ALL=C sort -z | xargs -0 sha256sum | sha256sum | cut -d' ' -f1); }
is_b4b() { jq -e --arg r "${1##*/}" '(.byte_for_byte // []) | index($r)' "$CONF" >/dev/null; }

# status <kind> <src> <dst>: print CODE and detail; never writes
status() {
  local kind=$1 s=$2 d=$3 h w
  if [ -L "$s" ]; then
    [ "$(readlink "$s")" = "$d" ] && [ -d "$d" ] && { echo "DONE"; return; }
    echo "CONFLICT old path is a symlink to $(readlink "$s")"; return
  fi
  [ -e "$s" ] || { [ -d "$d" ] && echo "CONFLICT $d exists and $s is missing (no symlink)" || echo "CONFLICT $s is missing"; return; }
  [ -e "$d" ] && { echo "CONFLICT target $d already exists"; return; }
  # Nearest existing ancestor of the target: .worktrees may not exist yet on a first pass.
  w=$(dirname "$d"); while [ ! -d "$w" ]; do w=$(dirname "$w"); done
  [ "$(stat -c %d "$s")" = "$(stat -c %d "$w")" ] || { echo "CONFLICT $s and the home are on different filesystems"; return; }
  h=$(busy "$s") && { echo "BUSY $h"; return; }
  if [ "$kind" = clone ]; then
    while IFS= read -r w; do
      [ -n "$w" ] && [ ! -L "$w" ] && [ -e "$w" ] && h=$(busy "$w") && { echo "BUSY via worktree $w ($h)"; return; }
    done < <(linked "$s")
  fi
  echo "MOVE"
}

LOG=/dev/null
startlog() {
  local a=${HOME_MIGRATE_ARTIFACT:-$(dirname "$0")/../claude/tools/artifact/artifact.sh}
  [ -f "$a" ] && LOG=$(ARTIFACT_ROOT=$ROOT bash "$a" new --key log --name "hm-$NAME-$VERB" --ext log \
    --what "home-migrate $VERB run for $NAME" 2>/dev/null) && [ -f "$LOG" ] || LOG=/dev/null
}
say() { echo "$*"; echo "$*" >>"$LOG"; }

keeps() { jq -r '.exceptions[]? | "KEEP\t\(.path)\t\(.reason)"' "$CONF" | while IFS=$'\t' read -r c p r; do say "$c $p - $r"; done; }

move_one() {
  local kind=$1 s=$2 d=$3 m
  mkdir -p "$(dirname "$d")" || return 1
  if [ "$kind" = worktree ]; then
    # Run from the main worktree: git keeps its worktrees/<id>/gitdir record and the moved .git file in step.
    m=$(git -C "$s" rev-parse --path-format=absolute --git-common-dir) || return 1
    git -C "${m%/.git}" worktree move "$s" "$d" || return 1
  else
    if is_b4b "$s"; then mkdir -p "$STATE" && manifest "$s" >"$STATE/${s##*/}.sha256" || return 1; fi
    mv -T "$s" "$d" || return 1
  fi
  # A moved clone's linked worktrees still name its old .git path. Repair runs before the symlink exists: git repairs
  # only a link it sees as broken, and through the symlink every old link still resolves, so repair would skip them.
  # Cost: the old path is absent for the length of the repair; status already proved no process uses the clone or its worktrees.
  if [ "$kind" = clone ] && [ -n "$(linked "$d")" ]; then git -C "$d" worktree repair >/dev/null 2>&1 || { ln -s "$d" "$s"; return 1; }; fi
  ln -s "$d" "$s" || return 1
  if is_b4b "$s"; then m=$(manifest "$d"); [ "$m" = "$(cat "$STATE/${s##*/}.sha256")" ] || return 1; fi
  return 0
}

run_plan() {
  local kind s d st n=0
  holders
  while IFS=$'\t' read -r kind s d; do
    st=$(status "$kind" "$s" "$d"); say "${st%% *} $kind $s -> $d${st#"${st%% *}"}"; n=$((n + 1))
  done < <(items)
  keeps; say "items $n"
}

run_apply() {
  mkdir -p "$STATE" || exit 3
  mkdir "$STATE/lock" 2>/dev/null || { echo "home-migrate: another apply holds $STATE/lock" >&2; exit 3; }
  trap 'rmdir "$STATE/lock" 2>/dev/null; rm -f "$HOLDERS"' EXIT
  local pass kind s d st moved=0 busyn conflict failed=0
  # Worktrees first: a clone waits until none of its worktrees is in use, so moving them first frees it sooner.
  for ((pass = 1; pass <= PASSES; pass++)); do
    busyn=0 conflict=0
    holders
    while IFS=$'\t' read -r kind s d; do
      st=$(status "$kind" "$s" "$d")
      # Fresh snapshot right before a move, so a seat that started since the pass began is still seen.
      [ "$st" = MOVE ] && holders && st=$(status "$kind" "$s" "$d")
      case $st in
        MOVE) if move_one "$kind" "$s" "$d"; then say "MOVED $kind $s -> $d"; moved=$((moved + 1));
              else say "FAIL $kind $s -> $d"; failed=$((failed + 1)); fi ;;
        DONE) say "DONE $kind $s -> $d" ;;
        BUSY*) say "BUSY $kind $s${st#BUSY} (pass $pass)"; busyn=$((busyn + 1)) ;;
        *) say "${st%% *} $kind $s${st#"${st%% *}"}"; conflict=$((conflict + 1)) ;;
      esac
    done < <(items | sort -t$'\t' -k1,1r)
    [ "$busyn" -eq 0 ] || [ "$pass" -eq "$PASSES" ] && break
    sleep "$WAIT"
  done
  keeps; say "changed $moved busy $busyn conflict $conflict fail $failed log $LOG"
  [ "$failed" -eq 0 ] && [ "$conflict" -eq 0 ] || exit 3
  [ "$busyn" -eq 0 ] || exit 4
}

run_check() {
  local kind s d st bad=0 m
  holders
  while IFS=$'\t' read -r kind s d; do
    st=$(status "$kind" "$s" "$d")
    if [ "$st" != DONE ]; then say "FAIL $kind $s ${st}"; bad=$((bad + 1)); continue; fi
    if [ -n "$(git -C "$d" rev-parse --git-dir 2>/dev/null)" ] && ! git -C "$s" rev-parse --show-toplevel >/dev/null 2>&1; then
      say "FAIL $kind $s does not resolve through its symlink"; bad=$((bad + 1)); continue
    fi
    if is_b4b "$s"; then
      m=$(manifest "$d"); if [ "$m" != "$(cat "$STATE/${s##*/}.sha256" 2>/dev/null)" ]; then say "FAIL $kind $d bytes differ from its pre-move manifest"; bad=$((bad + 1)); continue; fi
      say "OK $kind $s -> $d (bytes equal $m)"
    else
      say "OK $kind $s -> $d"
    fi
  done < <(items)
  keeps
  if [ "$bad" -eq 0 ]; then say "check ok"; else say "check failed $bad"; exit 3; fi
}

# rollback: the scripted way back for the stable gate. ONLY is required, so one item rolls back at a time.
run_rollback() {
  [ -n "${ONLY:-}" ] || { echo "home-migrate: rollback needs ONLY=<old path>" >&2; exit 2; }
  local kind s d st m n=0
  holders
  while IFS=$'\t' read -r kind s d; do
    n=1; st=$(status "$kind" "$s" "$d")
    [ "$st" = DONE ] || { say "${st%% *} $kind $s not rolled back${st#"${st%% *}"}"; exit 3; }
    busy "$d" >/dev/null && { say "BUSY $kind $d $(busy "$d")"; exit 4; }
    rm "$s" || exit 3   # our own symlink, proven by status DONE
    if [ -f "$d/.git" ]; then
      m=$(git -C "$d" rev-parse --path-format=absolute --git-common-dir)
      if ! git -C "${m%/.git}" worktree move "$d" "$s"; then ln -s "$d" "$s"; exit 3; fi
    else
      mv -T "$d" "$s" || { ln -s "$d" "$s"; exit 3; }
      if [ -n "$(linked "$s")" ]; then git -C "$s" worktree repair >/dev/null 2>&1 || exit 3; fi
    fi
    say "ROLLED-BACK $kind $d -> $s"
  done < <(items)
  [ "$n" -eq 1 ] || { echo "home-migrate: ONLY matches no item" >&2; exit 2; }
}

# Backticks below are Markdown code spans, not command substitution.
# shellcheck disable=SC2016
run_rolodex() {
  local d n r b k s dst
  printf '# ROLODEX\n\n<!-- START doctoc -->\n- [Places](#places)\n- [Worktrees](#worktrees)\n- [Old paths](#old-paths)\n- [Kept outside the home](#kept-outside-the-home)\n<!-- END doctoc -->\n\n'
  printf 'Every place in the %s home, what it is, and where it came from.\n\n' "$NAME"
  printf '**Generated by `home-migrate.sh rolodex` from %s - do not hand-edit.** Regenerate with the home Makefile.\n\n' "${CONF##*/}"
  printf '## Places\n\n| Place | Kind | Remote | Branch | Explainer |\n| ----- | ---- | ------ | ------ | --------- |\n'
  for d in "$HOMEDIR"/*/; do
    d=${d%/}; n=${d##*/}; r=$(git -C "$d" remote get-url origin 2>/dev/null | sed 's#.*github.com[:/]##; s#\.git$##')
    b=$(git -C "$d" branch --show-current 2>/dev/null); k=dir; [ -d "$d/.git" ] && k=repo
    printf '| `%s` | %s | %s | %s | %s |\n' "$n" "$k" "${r:--}" "${b:--}" "$( { [ -f "$d/README.md" ] && echo "[README.md]($n/README.md)"; } || echo -)"
  done
  printf '\n## Worktrees\n\n| Place | Repo | Branch |\n| ----- | ---- | ------ |\n'
  for d in "$HOMEDIR/$WTDIR"/*/; do
    [ -d "$d" ] || continue; d=${d%/}
    r=$(git -C "$d" rev-parse --path-format=absolute --git-common-dir 2>/dev/null); r=${r%/.git}
    printf '| `%s/%s` | %s | %s |\n' "$WTDIR" "${d##*/}" "${r##*/}" "$(git -C "$d" branch --show-current 2>/dev/null)"
  done
  printf '\n## Old paths\n\nEach old path is a symlink into the home, so recorded paths and running seats keep working.\n\n| Old path | Now |\n| -------- | --- |\n'
  while IFS=$'\t' read -r k s dst; do
    [ -L "$s" ] && printf '| `%s` | `%s` |\n' "${s/#$HOME/\~}" "${dst#"$HOMEDIR"/}"
  done < <(items)
  printf '\n## Kept outside the home\n\n| Path | Reason |\n| ---- | ------ |\n'
  jq -r '.exceptions[]? | "| `\(.path)` | \(.reason) |"' "$CONF"
}

[ "$VERB" = apply ] && startlog
"run_$VERB"
