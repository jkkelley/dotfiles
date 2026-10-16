#!/usr/bin/env bash
# Tests artifact.sh against a scratch store and scratch git repos. Intent, one line per acceptance criterion:
# AC1 the path is <key>/YYYY/MM/YYYYMMDD-HHMMSS-<name>.<ext> with parseable frontmatter, and a 55-char name is refused,
# because an over-long or free-form name is exactly the drift the owner ordered gone.
# AC2 link leaves git status clean, because a repo must point at the store and never hold it.
# AC3 check fails on a tracked log, because CI is where a committed artifact gets stopped.
set -uo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"; A="$HERE/artifact.sh"
T="$(mktemp -d)"; export HOME="$T/home" ARTIFACT_ROOT="$T/store" ARTIFACT_CONF=/dev/null; mkdir -p "$HOME"
git config --global user.email t@example.com; git config --global user.name t; git config --global init.defaultBranch main
fail=0; ok() { echo "ok   $1"; }; bad() { echo "FAIL $1"; fail=1; }
yr=$(date -u +%Y); mo=$(date -u +%m)

# AC1
p=$(bash "$A" new --key log --name seat-run --ext md --what "a seat's run log" --repo demo --branch b1 --session s1)
[[ $p =~ ^$T/store/log/$yr/$mo/[0-9]{8}-[0-9]{6}-seat-run\.md$ ]] && ok "AC1 path format" || bad "AC1 path format: $p"
[ "$(sed -n 1p "$p")" = --- ] && grep -q '^created: "[0-9-]*T[0-9:]*Z"$' "$p" && grep -q '^what: "a seat'"'"'s run log"$' "$p" \
  && ok "AC1 yaml frontmatter" || bad "AC1 yaml frontmatter"
[ "$(grep -c '^---$' "$p")" = 2 ] && ok "AC1 frontmatter closes" || bad "AC1 frontmatter closes"
j=$(bash "$A" new --key result --name shot --ext png --repo demo)
jq -e '.key=="result" and .repo=="demo" and (.created|test("Z$"))' "$j.meta.json" >/dev/null && [ -f "$j" ] \
  && ok "AC1 sidecar for formats with no comments" || bad "AC1 sidecar"
s=$(bash "$A" new --key state --name seat-env --ext sh); [ "$(sed -n 1p "$s")" = "# ---" ] && bash -n "$s" && ok "AC1 comment frontmatter" || bad "AC1 comment frontmatter"
n38=$(printf 'a%.0s' $(seq 38)); n39=$(printf 'a%.0s' $(seq 39))
bash "$A" new --key log --name "$n38" --ext md >/dev/null 2>&1 && ok "AC1 54-char name accepted" || bad "AC1 54-char name accepted"
bash "$A" new --key log --name "$n39" --ext md >/dev/null 2>&1 && bad "AC1 55-char name must be refused" || ok "AC1 55-char name refused"
bash "$A" new --key nope --name x --ext md >/dev/null 2>&1 && bad "unknown key must be refused" || ok "unknown key refused"
bash "$A" new --key log --name Bad_Name --ext md >/dev/null 2>&1 && bad "non-slug must be refused" || ok "non-slug refused"
[ -L "$T/store/repos/demo/log/$yr/$mo/${p##*/}" ] && [ "$(cat "$T/store/repos/demo/log/$yr/$mo/${p##*/}" | sed -n 1p)" = --- ] \
  && ok "repo link resolves to the file" || bad "repo link"

# AC2
R="$T/demo"; git init -q "$R"; echo x > "$R/f"; git -C "$R" add f; git -C "$R" commit -qm init
bash "$A" link --dir "$R" >/dev/null 2>&1; git -C "$R" add .gitignore; git -C "$R" commit -qm ignore
bash "$A" link --dir "$R" >/dev/null 2>&1
[ -L "$R/.artifacts" ] && [ -z "$(git -C "$R" status --porcelain)" ] && ls "$R/.artifacts/log/$yr/$mo/" | grep -q seat-run \
  && ok "AC2 link made, git status clean, store reachable" || bad "AC2 link: $(git -C "$R" status --porcelain)"
[ "$(grep -cx '/.artifacts' "$R/.gitignore")" = 1 ] && ok "AC2 idempotent" || bad "AC2 idempotent"
R2="$T/demo2"; git init -q "$R2"; bash "$A" link --dir "$R2" --exclude >/dev/null 2>&1
[ -z "$(git -C "$R2" status --porcelain)" ] && ok "AC2 --exclude leaves status clean" || bad "AC2 --exclude"

# AC3
bash "$A" check --dir "$R" >/dev/null && ok "AC3 clean repo passes" || bad "AC3 clean repo passes"
echo boom > "$R/run.log"; git -C "$R" add -f run.log; git -C "$R" commit -qm log
out=$(bash "$A" check --dir "$R" 2>&1) && bad "AC3 tracked log must fail" || { grep -q run.log <<<"$out" && ok "AC3 tracked log flagged"; }
mkdir -p "$R/templates"; echo '{}' > "$R/templates/x-result.json"; git -C "$R" rm -q run.log; git -C "$R" add templates
git -C "$R" commit -qm t; bash "$A" check --dir "$R" >/dev/null && ok "allow list honoured" || bad "allow list"

# find and clean
[ "$(bash "$A" find --key log | wc -l)" = 2 ] && ok "find lists by key" || bad "find: $(bash "$A" find --key log)"
[ -z "$(bash "$A" find --key log --since 2999-01-01)" ] && ok "find --since filters" || bad "find --since"
old="$T/store/log/2020/01/20200101-000000-old.md"; mkdir -p "${old%/*}"; echo x > "$old"
grep -q "would remove $old" <<<"$(bash "$A" clean --key log --older-than 30)" && [ -f "$old" ] && ok "clean dry run keeps files" || bad "clean dry run"
bash "$A" clean --key log --older-than 30 --apply >/dev/null && [ ! -e "$old" ] && [ ! -d "$T/store/log/2020" ] && [ -f "$p" ] \
  && ok "clean --apply removes only old, prunes dirs" || bad "clean apply"
rm "$p"; bash "$A" clean --key log --older-than 0 --apply >/dev/null
[ ! -L "$T/store/repos/demo/log/$yr/$mo/${p##*/}" ] && [ -d "$T/store/repos/demo" ] && ok "dangling repo links pruned, link target kept" || bad "dangling prune"
rm -rf "$T"; exit $fail
