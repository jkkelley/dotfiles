#!/usr/bin/env bash
# shellcheck disable=SC2016 # single-quoted backticks are literal Markdown the rolodex must print
# rolodex: header reviewed
# name: test_home_migrate.sh
# purpose: dev gate test plan TP-1 to TP-9 for scripts/home-migrate.sh on a temp copy of a tree. Run in podman: make home-migrate-test.
# inputs: none; builds its own fixture repos, worktrees and a vault under a mktemp root
# outputs: stdout ok / not ok lines; exit 0 when every case passes
# writes-to: a mktemp scratch path
# cleanup: removes its own temp files and its sleeper process on exit
# Rules out: a plan that writes, a worktree moved without git knowing, an old path left dead, a second apply that
# changes something, a busy path moved under a live process, an existing target overwritten, vault bytes changed,
# a moved clone whose worktrees still point at the old .git, and a check that passes while work is pending.
set -uo pipefail
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
HM=$HERE/../home-migrate.sh
T=$(mktemp -d); SLEEPER=
trap '[ -n "$SLEEPER" ] && kill "$SLEEPER" 2>/dev/null; rm -rf "$T"' EXIT
export ARTIFACT_ROOT=$T/store HOME_MIGRATE_ARTIFACT=$T/none GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@example.com GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@example.com
fails=0
check() { if [ "$1" = "$2" ]; then echo "ok - $3"; else echo "not ok - $3 (want $1, got $2)"; fails=$((fails + 1)); fi; }
has() { case $2 in *"$1"*) echo "ok - $3" ;; *) echo "not ok - $3 (no [$1] in output)"; fails=$((fails + 1)) ;; esac; }

P=$T/projects H=$P/home
mkdir -p "$H" && git init -q -b main "$P/app" && git -C "$P/app" commit -q --allow-empty -m init
git -C "$P/app" worktree add -q "$P/app-w01" -b ticket/w01 && git -C "$P/app" worktree add -q "$P/app-w02" -b ticket/w02
git init -q -b main "$P/vault" && echo secret-notes >"$P/vault/n.md" && git -C "$P/vault" add -A && git -C "$P/vault" commit -q -m v
mkdir "$P/app-plain" && echo x >"$P/app-plain/f"
mkdir -p "$T/elsewhere/notes" && echo n >"$T/elsewhere/notes/a.md"
cat >"$T/conf.json" <<EOF
{"name":"t","home":"$H","source_root":"$P","worktrees_dir":".worktrees","repos":["app","vault"],
 "byte_for_byte":["vault"],"worktree_globs":["app-*"],"paths":[{"src":"$T/elsewhere/notes","dst":"notes/old-notes"}],"exceptions":[{"path":"~/.config/x.env","reason":"secret stays mode 600"}]}
EOF
snap() { find "$P" -printf '%p %y %l\n' | sort | sha256sum | cut -c1-16; }

# TP-1 plan is read-only and lists every item as MOVE, plus the KEEP exception with its reason
before=$(snap); out=$(bash "$HM" plan "$T/conf.json"); rc=$?
check 0 $rc "TP-1 plan exits 0"; check "$before" "$(snap)" "TP-1 plan writes nothing"
check 6 "$(grep -c '^MOVE' <<<"$out")" "TP-1 plan lists 6 MOVE items"; has "KEEP ~/.config/x.env - secret stays mode 600" "$out" "TP-1 exception printed with reason"

# TP-11 ONLY narrows apply to one item (the UAT gate) and leaves the rest alone
out=$(ONLY=$P/app-w01 bash "$HM" apply "$T/conf.json"); check 0 $? "TP-11 ONLY apply exits 0"
check "changed 1" "$(grep -o 'changed [0-9]*' <<<"$out")" "TP-11 ONLY apply moves exactly one item"
check "" "$(test -L "$P/app" && echo moved)" "TP-11 ONLY apply leaves other items in place"

# TP-2 a busy worktree is never moved and apply exits 4; everything else moves
(cd "$P/app-w02" && exec sleep 300) & SLEEPER=$!; sleep 0.3
out=$(bash "$HM" apply "$T/conf.json"); rc=$?
check 4 $rc "TP-2 apply exits 4 while a path is busy"
has "BUSY worktree $P/app-w02 pid" "$out" "TP-2 busy worktree named with its holder"
check "" "$(test -L "$P/app-w02" && echo moved)" "TP-2 busy worktree not moved"
has "BUSY clone $P/app via worktree $P/app-w02" "$out" "TP-2 clone waits while one of its worktrees is busy"
check "$H/.worktrees/app-w01" "$(readlink "$P/app-w01")" "TP-2 moved worktree leaves a symlink at the old path"
check "ticket/w01" "$(git -C "$P/app-w01" branch --show-current)" "TP-2 old path still works as a git worktree"
check "$H/.worktrees/app-w01" "$(git -C "$P/app" worktree list --porcelain | sed -n 's/^worktree //p' | grep w01)" "TP-2 git records the new worktree path"
check "$H/.worktrees/app-plain" "$(readlink "$P/app-plain")" "TP-2 plain glob match moved by mv"

check "$H/notes/old-notes" "$(readlink "$T/elsewhere/notes")" "TP-2 a paths entry moves to its home-relative target"

# TP-3 check fails while an item is pending
bash "$HM" check "$T/conf.json" >/dev/null; check 3 $? "TP-3 check exits 3 while work is pending"

# TP-4 the next pass moves what was busy, then the clone, and repairs the clone's worktree links
kill "$SLEEPER"; wait "$SLEEPER" 2>/dev/null; SLEEPER=
out=$(bash "$HM" apply "$T/conf.json"); rc=$?
check 0 $rc "TP-4 apply exits 0 once nothing is busy"
check "$H/app" "$(readlink "$P/app")" "TP-4 clone moved and symlinked"
check "gitdir: $H/app/.git/worktrees/app-w02" "$(cat "$H/.worktrees/app-w02/.git")" "TP-4 worktree .git repaired to the new clone path"
check "ticket/w02" "$(git -C "$P/app-w02" branch --show-current)" "TP-4 old worktree path resolves"

# TP-5 a second apply changes nothing
before=$(snap); out=$(bash "$HM" apply "$T/conf.json"); rc=$?
check 0 $rc "TP-5 second apply exits 0"; has "changed 0 busy 0 conflict 0 fail 0" "$out" "TP-5 second apply reports changed 0"
check "$before" "$(snap)" "TP-5 second apply leaves the tree identical"

# TP-6 check passes and proves vault bytes equal
out=$(bash "$HM" check "$T/conf.json"); rc=$?
check 0 $rc "TP-6 check exits 0"; has "bytes equal" "$out" "TP-6 vault bytes proven equal"
check secret-notes "$(cat "$P/vault/n.md")" "TP-6 vault content readable through old path"

# TP-10 rolodex is read-only and names places, worktrees, old paths and exceptions
before=$(snap); out=$(bash "$HM" rolodex "$T/conf.json"); rc=$?
check 0 $rc "TP-10 rolodex exits 0"; check "$before" "$(snap)" "TP-10 rolodex writes nothing"
has '| `.worktrees/app-w01` | app | ticket/w01 |' "$out" "TP-10 rolodex lists a worktree with repo and branch"
has '| `~/.config/x.env` | secret stays mode 600 |' "$out" "TP-10 rolodex lists the exception with its reason"
has "## Old paths" "$out" "TP-10 rolodex has the old paths section"

# TP-7 an existing target is a CONFLICT and nothing is touched
git -C "$H/app" worktree add -q "$P/app-w03" -b ticket/w03 && mkdir -p "$H/.worktrees/app-w03"
before=$(snap); out=$(bash "$HM" apply "$T/conf.json"); rc=$?
check 3 $rc "TP-7 apply exits 3 on a conflict"; has "CONFLICT worktree $P/app-w03 target" "$out" "TP-7 conflict named"
check "$before" "$(snap)" "TP-7 conflict touches nothing"

# TP-8 a second apply cannot run while one holds the lock
rmdir "$H/.worktrees/app-w03"; mkdir -p "$ARTIFACT_ROOT/state/home-migrate/t/lock"
bash "$HM" apply "$T/conf.json" >/dev/null 2>&1; check 3 $? "TP-8 concurrent apply refused"
rmdir "$ARTIFACT_ROOT/state/home-migrate/t/lock"

# TP-12 rollback puts one item back, apply moves it home again
out=$(ONLY=$P/app-w01 bash "$HM" rollback "$T/conf.json"); check 0 $? "TP-12 rollback exits 0"
check "ticket/w01" "$(test -L "$P/app-w01" || git -C "$P/app-w01" branch --show-current)" "TP-12 rolled back worktree is real again at the old path"
check "$P/app-w01" "$(git -C "$P/app" worktree list --porcelain | sed -n 's/^worktree //p' | grep w01)" "TP-12 git records the old path again"
bash "$HM" rollback "$T/conf.json" >/dev/null 2>&1; check 2 $? "TP-12 rollback without ONLY is usage error 2"
out=$(ONLY=$P/app-w01 bash "$HM" apply "$T/conf.json"); check "changed 1" "$(grep -o 'changed [0-9]*' <<<"$out")" "TP-12 apply moves it home again"

# TP-9 bad usage is 2, not a violation
bash "$HM" plan >/dev/null 2>&1; check 2 $? "TP-9 missing config is usage error 2"
bash "$HM" nuke "$T/conf.json" >/dev/null 2>&1; check 2 $? "TP-9 unknown verb is usage error 2"

if [ "$fails" -eq 0 ]; then echo "all ok"; else echo "$fails failed"; exit 1; fi
