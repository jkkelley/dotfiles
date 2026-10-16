#!/usr/bin/env bash
# rolodex: header reviewed
# name: home_migrate_dev.sh
# purpose: dev gate on a temp copy of a real home's tree: mirror every item (same names, branches, kinds), then plan, apply twice, check.
# inputs: manifest CONF (host, read-only) | run MANIFEST CONF (in podman: make home-migrate-dev CONF=)
# outputs: manifest: TSV kind name branch rel on stdout; run: ok / not ok lines, exit 0 when the mirror migrates cleanly
# writes-to: run: a mktemp scratch path inside the container only
# cleanup: removes its own temp files on exit
# Why a mirror and not a copy: a copied worktree's .git file names the real clone, so a move in the copy would edit the
# real repository's metadata. The mirror rebuilds each clone and worktree under a temp root with the same names and branches.
set -uo pipefail
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
HM=$HERE/../home-migrate.sh
case ${1:-} in
  manifest)
    CONF=$2; SRC=$(jq -r .source_root "$CONF"); SRC=${SRC/#\~/$HOME}
    jq -r '.repos[]?' "$CONF" | while read -r r; do [ -d "$SRC/$r" ] && printf 'clone\t%s\t%s\t-\n' "$r" "$(git -C "$SRC/$r" branch --show-current 2>/dev/null || echo -)"; done
    jq -r '.worktree_globs[]?' "$CONF" | while read -r g; do
      for p in "$SRC"/$g; do
        [ -f "$p/.git" ] || continue
        m=$(git -C "$p" rev-parse --path-format=absolute --git-common-dir); m=${m%/.git}
        printf 'worktree\t%s\t%s\t%s\n' "${p##*/}" "$(git -C "$p" branch --show-current)" "${m##*/}"
      done
    done
    jq -r '.paths[]? | .dst' "$CONF" | while read -r d; do printf 'path\t%s\t-\t-\n' "$d"; done ;;
  run)
    MAN=$2 CONF=$3
    T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
    export ARTIFACT_ROOT=$T/store HOME_MIGRATE_ARTIFACT=$T/none GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@example.com GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@example.com
    P=$T/projects H=$P/home; mkdir -p "$H/.worktrees"
    fails=0; check() { if [ "$1" = "$2" ]; then echo "ok - $3"; else echo "not ok - $3 (want $1, got $2)"; fails=$((fails + 1)); fi; }
    paths='[]'
    while IFS=$'\t' read -r kind name branch main; do
      case $kind in
        clone) git init -q -b "${branch/#-/main}" "$P/$name" && echo "$name" >"$P/$name/README" && git -C "$P/$name" add -A && git -C "$P/$name" commit -q -m init ;;
        worktree) [ -d "$P/$main" ] || { git init -q -b main "$P/$main" && git -C "$P/$main" commit -q --allow-empty -m init; }
                  git -C "$P/$main" worktree add -q "$P/$name" -b "$branch" ;;
        path) mkdir -p "$T/other/${name//\//-}" && echo x >"$T/other/${name//\//-}/f"
              paths=$(jq -c --arg s "$T/other/${name//\//-}" --arg d "$name" '. + [{src: $s, dst: $d}]' <<<"$paths") ;;
      esac
    done <"$MAN"
    jq --arg h "$H" --arg p "$P" --argjson paths "$paths" '.home = $h | .source_root = $p | .paths = $paths' "$CONF" >"$T/conf.json"
    n=$(wc -l <"$MAN")
    out=$(bash "$HM" plan "$T/conf.json"); check "$n" "$(grep -c '^MOVE' <<<"$out")" "dev plan: every mirrored item is MOVE ($n)"
    out=$(bash "$HM" apply "$T/conf.json"); check 0 $? "dev apply 1 exits 0"; check "$n" "$(grep -c '^MOVED' <<<"$out")" "dev apply 1 moved $n"
    out=$(bash "$HM" apply "$T/conf.json"); check 0 $? "dev apply 2 exits 0"
    case $out in *"changed 0 busy 0 conflict 0 fail 0"*) echo "ok - dev apply 2 changed 0" ;; *) echo "not ok - dev apply 2: $(tail -1 <<<"$out")"; fails=$((fails + 1)) ;; esac
    out=$(bash "$HM" check "$T/conf.json"); check 0 $? "dev check exits 0"
    bad=0
    while IFS=$'\t' read -r kind name branch main; do
      [ "$kind" = worktree ] || continue
      [ "$(git -C "$P/$name" branch --show-current)" = "$branch" ] || bad=$((bad + 1))
      m=$P/$main; [ -L "$m" ] && m=$H/$main
      grep -q "gitdir: $m/.git/worktrees/" "$H/.worktrees/$name/.git" || bad=$((bad + 1))
    done <"$MAN"
    check 0 "$bad" "dev every worktree keeps its branch via the old path and points at the moved clone"
    if [ "$fails" -eq 0 ]; then echo "all ok"; else echo "$fails failed"; exit 1; fi ;;
  *) sed -n '5,6p' "$0"; exit 2 ;;
esac
