#!/usr/bin/env bash
# review-publish.sh - copy a merged directory from REF of a repo into the review root under NAME, and print each URL. No model calls.
# name: review-publish.sh
# purpose: publish a merged repo directory (git archive of REF:SRC) to the review server root, idempotent, never deleting a hand copy
# inputs: REPO, SRC, NAME, [REF] (default config .ref); config claude/workflow/config/review.json, override with env REVIEW_CONFIG
# outputs: 'ok review NAME SHA (N files)' or 'ok review NAME unchanged at SHA', then one http://BIND:PORT/NAME/RELPATH line per file; exit 0 ok, 2 usage, 3 REVIEW-NOSRC
# writes-to: ROOT/NAME and ROOT/.retired/ (ROOT from the config); git fetch in REPO
# cleanup: removes its own temp dir and the previous ROOT/NAME copy (recoverable from git); hand copies move to ROOT/.retired, never removed
#
# usage: review-publish.sh REPO SRC NAME [REF]
# BREADCRUMB - WO-20261016-8c45 (ORD-1012 W1, brief BR-20261016-infra-design14, F35).
# What broke: the owner's review pages (localhost:45610/{d18,content,wire}/) were hand copies in
#   ~/.local/state/zenith/inbox-triage/20261015/review, served by a python3 -m http.server 45610 --bind 127.0.0.1 an architect
#   background shell started (ss -ltnp, pid 1987220, cwd an unrelated investigations dir). They went stale as the source
#   merged (content lacked business #69 and #71), and nothing fixed the port or the root.
# Why this fix: git archive of REF (origin/main) publishes only merged content, and the config fixes root, bind and port.
#   Rejected: rsync from the working tree, which publishes unmerged edits.
# Cost: a publish needs the commit fetched; a failed fetch publishes the last fetched REF with a warning.
set -uo pipefail
usage() { echo "usage: review-publish.sh REPO SRC NAME [REF]" >&2; exit 2; }
if [ $# -lt 3 ] || [ $# -gt 4 ]; then usage; fi
repo=$1; src=$2; name=$3
HERE="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"
cfg=${REVIEW_CONFIG:-$HERE/config/review.json}
[ -f "$cfg" ] || { echo "review-publish.sh: config $cfg missing" >&2; exit 2; }
root=$(jq -r '.root' "$cfg"); bind=$(jq -r '.bind' "$cfg"); port=$(jq -r '.port' "$cfg"); cfgref=$(jq -r '.ref' "$cfg")
# shellcheck disable=SC2088 # the literal two characters ~/ are what the config holds
case "$root" in "~/"*) root="$HOME/${root#"~/"}" ;; esac
ref=${4:-$cfgref}
src=${src%/}

[[ $name =~ ^[a-z0-9][a-z0-9._-]*$ ]] || usage
git -C "$repo" rev-parse --is-inside-work-tree >/dev/null 2>&1 || usage
[ -n "$src" ] || usage
case "$src" in /*) usage ;; esac
case "/$src/" in */../*) usage ;; esac
case "$src" in *..*) usage ;; esac

timeout 60 git -C "$repo" fetch -q origin 2>/dev/null \
  || echo "warn review fetch failed, using last fetched $ref" >&2

if [ "$(git -C "$repo" rev-parse --verify -q "$ref:$src" >/dev/null && git -C "$repo" cat-file -t "$ref:$src" 2>/dev/null)" != tree ]; then
  echo "REVIEW-NOSRC $src not on $ref"; exit 3
fi
sha=$(git -C "$repo" rev-parse --short=12 "$ref")

urls() {
  (cd "$root/$name" && find . -type f ! -path ./.review-publish.json | sed 's|^\./||' | LC_ALL=C sort) \
    | while IFS= read -r f; do printf 'http://%s:%s/%s/%s\n' "$bind" "$port" "$name" "$f"; done
}

meta="$root/$name/.review-publish.json"
if [ -f "$meta" ] && [ "$(jq -r '.sha' "$meta")" = "$sha" ] && [ "$(jq -r '.src' "$meta")" = "$src" ]; then
  echo "ok review $name unchanged at $sha"; urls; exit 0
fi

mkdir -p "$root/.retired"
if [ -e "$root/$name" ] && [ ! -f "$meta" ]; then
  dest="$root/.retired/$name-$(date -u +%Y%m%dT%H%M%SZ)"
  mv "$root/$name" "$dest"
  echo "warn review $name: hand copy moved to $dest" >&2
fi

tmp=$(mktemp -d "$root/.$name.XXXXXX") || exit 1
trap 'rm -rf "$tmp"' EXIT
k=$(awk -F/ '{print NF}' <<<"$src")
if ! git -C "$repo" archive "$ref" "$src" | tar -x -C "$tmp" --strip-components="$k"; then
  echo "review-publish.sh: archive of $ref:$src failed" >&2; exit 1
fi
jq -n --arg repo "$repo" --arg src "$src" --arg ref "$ref" --arg sha "$sha" --arg at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  '{repo:$repo,src:$src,ref:$ref,sha:$sha,at:$at}' > "$tmp/.review-publish.json"
old="$root/.$name.old.$$"
[ -e "$root/$name" ] && mv "$root/$name" "$old"
mv "$tmp" "$root/$name"
rm -rf "$old"
trap - EXIT

n=$(urls | wc -l)
echo "ok review $name $sha ($n files)"
urls
