#!/usr/bin/env bash
# name: shot.sh
# purpose: screenshot one HTML file with headless Chromium into the artifact store, size checked.
# inputs: --html FILE --name SLUG [--size WxH] [--what TEXT]; env CHROME_BIN, SHOT_TIMEOUT_S, ARTIFACT_ROOT
# outputs: stdout store path of the PNG; stderr status line SHOT-OK|SHOT-USAGE|SHOT-SRC|SHOT-NOBROWSER|SHOT-RENDER
# writes-to: $ARTIFACT_ROOT/screenshot/YYYY/MM/ (PNG plus .meta.json sidecar, via artifact.sh)
# cleanup: make artifact-clean KEY=screenshot OLDER_THAN=days
# shot.sh - generic HTML page screenshot into the artifact store (Design principles 101 items 23 and 31).
#
# BREADCRUMB.
# What was missing: no generic HTML-to-PNG script in dotfiles; the only renderer, business linkedin-page
#   render-preview.sh, is hard-wired to one file and writes its PNG beside it in git, against item 23.
# Why headless Chromium from the cached Playwright install: already on the host, no network, and the same binary
#   render-preview.sh uses.
# Rejected: chrome-devtools-axi (needs a model turn per shot, item 39) and Figma get_screenshot (parked, FB-006).
# Why render before allocating the store path: a failed render leaves no empty file in the store.
# Cost: one browser start per shot.
# Exit codes: 0 SHOT-OK, 2 SHOT-USAGE, 3 SHOT-SRC, 4 SHOT-NOBROWSER or SHOT-RENDER.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  cat >&2 <<'U'
usage: shot.sh --html FILE --name SLUG [--size WxH] [--what TEXT]
  default size 1440x900; env CHROME_BIN, SHOT_TIMEOUT_S (default 30), ARTIFACT_ROOT
  exit: 0 SHOT-OK <path> | 2 SHOT-USAGE | 3 SHOT-SRC | 4 SHOT-NOBROWSER or SHOT-RENDER
U
}
fail() { printf '%s %s\n' "$1" "$3" >&2; exit "$2"; }

html="" name="" size="1440x900" what=""
while [ $# -gt 0 ]; do
  case "$1" in
    --help|-h) usage; exit 0 ;;
    --html) [ $# -ge 2 ] || fail SHOT-USAGE 2 "missing value for $1"; html="$2"; shift 2 ;;
    --name) [ $# -ge 2 ] || fail SHOT-USAGE 2 "missing value for $1"; name="$2"; shift 2 ;;
    --size) [ $# -ge 2 ] || fail SHOT-USAGE 2 "missing value for $1"; size="$2"; shift 2 ;;
    --what) [ $# -ge 2 ] || fail SHOT-USAGE 2 "missing value for $1"; what="$2"; shift 2 ;;
    *) usage; fail SHOT-USAGE 2 "unknown flag $1" ;;
  esac
done
if [ -z "$html" ] || [ -z "$name" ]; then usage; fail SHOT-USAGE 2 "--html and --name are required"; fi
[[ $size =~ ^[0-9]+x[0-9]+$ ]] || fail SHOT-USAGE 2 "size must be WxH, got $size"
[ -f "$html" ] || fail SHOT-SRC 3 "html file missing: $html"
W="${size%x*}" H="${size#*x}"

chrome="${CHROME_BIN:-}"
if [ -z "$chrome" ]; then
  # shellcheck disable=SC2012  # sort -V over a glob of version dirs is the ordering the ticket fixes
  chrome=$(ls -d "$HOME"/.cache/ms-playwright/chromium_headless_shell-*/chrome-headless-shell-linux64/chrome-headless-shell 2>/dev/null | sort -V | tail -n1)
fi
{ [ -n "$chrome" ] && [ -x "$chrome" ]; } || fail SHOT-NOBROWSER 4 "no executable browser; set CHROME_BIN to any Chromium"

TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
timeout "${SHOT_TIMEOUT_S:-30}" "$chrome" --no-sandbox --disable-gpu --hide-scrollbars --force-device-scale-factor=1 \
  --window-size="$W,$H" --screenshot="$TMP/out.png" "file://$(realpath "$html")" >/dev/null 2>&1 \
  || fail SHOT-RENDER 4 "browser failed or timed out"
[ -s "$TMP/out.png" ] || fail SHOT-RENDER 4 "empty screenshot"
[ "$(od -An -tx1 -N8 "$TMP/out.png" | tr -d ' \n')" = 89504e470d0a1a0a ] || fail SHOT-RENDER 4 "not a PNG"
read -r w h < <(od -An -tu1 -j16 -N8 "$TMP/out.png" | awk '{print $1*16777216+$2*65536+$3*256+$4, $5*16777216+$6*65536+$7*256+$8}')
{ [ "$w" = "$W" ] && [ "$h" = "$H" ]; } || fail SHOT-RENDER 4 "size ${w}x${h}, wanted ${W}x${H}"

path=$(bash "$HERE/../artifact/artifact.sh" new --key screenshot --name "$name" --ext png --what "${what:-$name}") \
  || fail SHOT-USAGE 2 "artifact.sh refused the name"
mv "$TMP/out.png" "$path"
printf 'SHOT-OK %s\n' "$path" >&2
printf '%s\n' "$path"
