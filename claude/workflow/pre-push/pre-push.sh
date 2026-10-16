#!/usr/bin/env bash
# name: pre-push.sh
# purpose: run every fast gate of a repository on the changed files, in parallel, before a push; install it as the git pre-push hook
# inputs: verbs run|install|uninstall; --repo DIR, --base REF, --config FILE; env PRE_PUSH_CONFIG; pre-push.json beside this script
# outputs: PREPUSH-PASS/SKIP/FAIL per gate, PREPUSH-OK or PREPUSH-RED last line; PREPUSH-HOOK-* for install and uninstall; exit 0 ok, 1 red, 2 usage
# writes-to: DIR/.git hooks/pre-push (install, uninstall); a temp dir removed on exit
# cleanup: the temp dir is removed by trap on EXIT; uninstall removes only the hook this script wrote
#
# BREADCRUMB 2026-10-16 ORD-0814 P1 - local gates before the push.
# What broke: PRs 216, 219, 225, 234 went red on headers or tracked-ignored-check and 213, 219, 210 on bump intent
#   (2026-10-16 08:00-08:15Z); each red cost a CI round and a seat, and every one of those gates runs locally in under a second.
# Why this fix: a config of gate commands per repository slug (pre-push.json) rather than a fixed list, so any repository gets
#   the same hook, unknown ones get the defaults, and a new gate is one config entry (Design principles 101 item 4). Gates run
#   in parallel so the 30 s budget holds as gates are added (item 2). A gate whose tool is missing is skipped, never blocks.
# Rejected: a hard-coded gate list per repo in this script. Cost: gates are shell strings in JSON, so they are quoted by hand.
set -uo pipefail

usage() { echo "usage: pre-push.sh run --repo DIR [--base REF] [--config FILE] | install --repo DIR | uninstall --repo DIR" >&2; exit 2; }

[ $# -ge 1 ] || usage
VERB="$1"; shift
REPO=""; BASE="origin/main"; CONFIG=""
while [ $# -gt 0 ]; do
  case "$1" in
    --repo) [ $# -ge 2 ] || usage; REPO="$2"; shift 2 ;;
    --base) [ $# -ge 2 ] || usage; BASE="$2"; shift 2 ;;
    --config) [ $# -ge 2 ] || usage; CONFIG="$2"; shift 2 ;;
    *) usage ;;
  esac
done
[ -n "$REPO" ] || usage

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
SELF_DIR="$(dirname "$SELF")"
t=""
MANAGED="# managed-by: dotfiles pre-push (claude/workflow/pre-push/pre-push.sh install)"

hook_path() { git -C "$REPO" rev-parse --path-format=absolute --git-path hooks/pre-push; }

hook_text() {
  local pp="$SELF" mk="$SELF_DIR/pre-push.mk"
  # shellcheck disable=SC2016  # the hook text is literal; its variables expand when the hook runs
  printf '%s\n' \
    '#!/usr/bin/env bash' \
    "$MANAGED" \
    "# bypass once: git push --no-verify (CI still runs every gate); remove: make -f $mk pre-push-uninstall REPO=<repo>" \
    "PP=$pp; MK=$mk" \
    'top=$(git rev-parse --show-toplevel)' \
    '[ -f "$PP" ] || { echo "PREPUSH-SKIP all NO-TOOL $PP"; exit 0; }' \
    'command -v make >/dev/null 2>&1 && exec make -s -f "$MK" pre-push REPO="$top"' \
    'exec bash "$PP" run --repo "$top"'
}

do_install() {
  local h want; h="$(hook_path)" || exit 2
  want="$(hook_text)"
  if [ -f "$h" ]; then
    if [ "$(cat "$h")" = "$want" ]; then echo "PREPUSH-HOOK-NOCHANGE $h"; return 0; fi
    if grep -qF "$MANAGED" "$h"; then
      printf '%s\n' "$want" > "$h"; chmod 755 "$h"; echo "PREPUSH-HOOK-UPDATED $h"; return 0
    fi
    echo "PREPUSH-HOOK-FOREIGN $h"; return 0
  fi
  mkdir -p "$(dirname "$h")"
  printf '%s\n' "$want" > "$h"; chmod 755 "$h"
  echo "PREPUSH-HOOK-INSTALLED $h"
}

do_uninstall() {
  local h; h="$(hook_path)" || exit 2
  if [ ! -f "$h" ]; then echo "PREPUSH-HOOK-ABSENT $h"; return 0; fi
  if grep -qF "$MANAGED" "$h"; then rm -f "$h"; echo "PREPUSH-HOOK-REMOVED $h"; return 0; fi
  echo "PREPUSH-HOOK-FOREIGN $h"
}

do_run() {
  local cfg url slug gates n i name cmd tool miss rc d
  cfg="${CONFIG:-${PRE_PUSH_CONFIG:-$SELF_DIR/pre-push.json}}"
  [ -f "$cfg" ] || { echo "pre-push: no config $cfg" >&2; exit 2; }
  git -C "$REPO" rev-parse --git-dir >/dev/null 2>&1 || { echo "pre-push: not a git repository $REPO" >&2; exit 2; }
  url="$(git -C "$REPO" remote get-url origin 2>/dev/null || true)"
  slug="$(printf '%s' "$url" | sed -e 's#^.*github\.com[:/]##' -e 's#\.git$##')"
  gates="$(jq -c --arg s "$slug" '.repos[$s].gates // .defaults.gates' "$cfg")" || exit 2
  if ! git -C "$REPO" rev-parse --verify -q "$BASE^{commit}" >/dev/null; then
    echo "PREPUSH-SKIP all NO-BASE $BASE"; exit 0
  fi
  t="$(mktemp -d)"  # global on purpose: the EXIT trap runs after this function returns
  trap 'rm -rf "$t"' EXIT
  local title body
  title="$(git -C "$REPO" rev-parse --path-format=absolute --git-path PR_TITLE)"
  body="$(git -C "$REPO" rev-parse --path-format=absolute --git-path PR_BODY.md)"
  if [ ! -f "$title" ] || [ ! -f "$body" ]; then
    title="$t/title"; body="$t/body"
    git -C "$REPO" log -1 --format=%s > "$title"
    git -C "$REPO" log -1 --format=%b > "$body"
  fi
  local start_all=$SECONDS dotfiles; dotfiles="$(readlink -f "$SELF_DIR/../../..")"
  n="$(jq 'length' <<<"$gates")"
  for ((i = 0; i < n; i++)); do
    name="$(jq -r ".[$i].name" <<<"$gates")"
    cmd="$(jq -r ".[$i].cmd" <<<"$gates")"
    miss=""
    while IFS= read -r tool; do
      [ -n "$tool" ] || continue
      command -v "$tool" >/dev/null 2>&1 || { miss="$tool"; break; }
    done < <(jq -r ".[$i].needs[]?" <<<"$gates")
    if [ -n "$miss" ]; then echo "$miss" > "$t/$name.miss"; continue; fi
    (
      s=$SECONDS
      (cd "$REPO" && BASE="$BASE" TITLE_FILE="$title" BODY_FILE="$body" DOTFILES="$dotfiles" bash -c "$cmd") > "$t/$name.out" 2>&1
      echo $? > "$t/$name.rc"
      echo $((SECONDS - s)) > "$t/$name.s"
    ) &
  done
  wait
  local failed=()
  for ((i = 0; i < n; i++)); do
    name="$(jq -r ".[$i].name" <<<"$gates")"
    if [ -f "$t/$name.miss" ]; then echo "PREPUSH-SKIP $name ENV-MISSING $(cat "$t/$name.miss")"; continue; fi
    rc="$(cat "$t/$name.rc")"; d="$(cat "$t/$name.s")"
    if [ "$rc" -eq 0 ]; then echo "PREPUSH-PASS $name ${d}s"
    elif [ "$rc" -eq 127 ]; then echo "PREPUSH-SKIP $name ENV-MISSING"
    else
      echo "PREPUSH-FAIL $name rc=$rc"
      tail -n 20 "$t/$name.out" | sed 's/^/  /'
      failed+=("$name")
    fi
  done
  if [ ${#failed[@]} -gt 0 ]; then
    echo "PREPUSH-RED $(IFS=,; echo "${failed[*]}")"; exit 1
  fi
  echo "PREPUSH-OK $n gates $((SECONDS - start_all))s"
}

case "$VERB" in
  run) do_run ;;
  install) do_install ;;
  uninstall) do_uninstall ;;
  *) usage ;;
esac
