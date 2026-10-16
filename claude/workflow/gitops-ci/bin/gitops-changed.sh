#!/usr/bin/env bash
# name: gitops-changed.sh
# purpose: map a git diff of a GitOps repo to the yaml files, manifests, chart dirs, kustomize dirs and deploy flag a CI must check
# inputs: --repo OWNER/NAME, --repo-dir DIR, [--base REF], [--config FILE | env GITOPS_CI_CONFIG | ../config/gitops-ci.json]
# outputs: one compact JSON line on stdout: repo, base, yaml, manifests, charts, overlays, deploy
# writes-to: nothing
# cleanup: none
set -euo pipefail

HERE=$(cd "$(dirname "$(readlink -f "$0")")" && pwd)
usage() {
  echo "usage: gitops-changed.sh --repo OWNER/NAME --repo-dir DIR [--base REF] [--config FILE]"
  echo "  empty or absent --base lists every tracked file (push-to-main full run)"
}

REPO="" DIR="" BASE="" CFG=${GITOPS_CI_CONFIG:-$HERE/../config/gitops-ci.json}
while [ $# -gt 0 ]; do
  case $1 in
    -h | --help) usage; exit 0 ;;
    --repo) [ $# -ge 2 ] || { usage >&2; exit 2; }; REPO=$2; shift 2 ;;
    --repo-dir) [ $# -ge 2 ] || { usage >&2; exit 2; }; DIR=$2; shift 2 ;;
    --base) [ $# -ge 2 ] || { usage >&2; exit 2; }; BASE=$2; shift 2 ;;
    --config) [ $# -ge 2 ] || { usage >&2; exit 2; }; CFG=$2; shift 2 ;;
    *) usage >&2; exit 2 ;;
  esac
done
{ [ -n "$REPO" ] && [ -n "$DIR" ]; } || { usage >&2; exit 2; }

[ -f "$CFG" ] || { echo "gitops-changed: no config at $CFG" >&2; exit 2; }
if ! jq -e --arg r "$REPO" '.repos[$r] != null' "$CFG" >/dev/null 2>&1; then
  echo "gitops-changed: unknown repo $REPO" >&2
  exit 2
fi
RES=$(jq -c --arg r "$REPO" '.defaults * .repos[$r]' "$CFG")
cfg() { jq -r --arg k "$1" '.[$k]' <<<"$RES"; }
YAML_RE=$(cfg yaml_re) YAML_EX=$(cfg yaml_exclude_re)
MAN_RE=$(cfg manifest_re) MAN_EX=$(cfg manifest_exclude_re)
DEPLOY_RE=$(cfg deploy_re) DEPTH=$(cfg app_depth)

if [ -n "$BASE" ]; then
  CHANGED=$(git -C "$DIR" diff --name-only --diff-filter=d "$BASE...HEAD") || exit 4
else
  CHANGED=$(git -C "$DIR" ls-files) || exit 4
fi
ALL=$(git -C "$DIR" ls-files) || exit 4
KDIRS=$(printf '%s\n' "$ALL" | grep -E '/kustomization\.ya?ml$' | sed 's|/[^/]*$||' | sort -u || true)

YAML=() MANS=() CHARTS=() OVERLAYS=() DEPLOY=false
while IFS= read -r f; do
  [ -n "$f" ] || continue
  if printf '%s' "$f" | grep -Eq "$YAML_RE" && ! printf '%s' "$f" | grep -Eq "$YAML_EX"; then
    YAML+=("$f")
  fi
  if printf '%s' "$f" | grep -Eq "$DEPLOY_RE"; then DEPLOY=true; fi

  # chart: nearest ancestor dir holding Chart.yaml
  d=$(dirname "$f") chart=""
  while :; do
    if [ "$d" != . ] && [ -f "$DIR/$d/Chart.yaml" ]; then chart=$d; break; fi
    [ "$d" = . ] && break
    d=$(dirname "$d")
  done
  if [ -n "$chart" ]; then CHARTS+=("$chart"); continue; fi

  # kustomize: an ancestor up to the app root holds a kustomization
  root=$(printf '%s' "$f" | cut -d/ -f1-"$DEPTH")
  d=$(dirname "$f") hit=false
  while :; do
    if [ -f "$DIR/$d/kustomization.yaml" ] || [ -f "$DIR/$d/kustomization.yml" ]; then hit=true; break; fi
    { [ "$d" = "$root" ] || [ "$d" = . ]; } && break
    d=$(dirname "$d")
  done
  if $hit; then
    while IFS= read -r k; do
      [ -n "$k" ] || continue
      case $k in "$root" | "$root"/*) OVERLAYS+=("$k") ;; esac
    done <<<"$KDIRS"
    continue
  fi

  if printf '%s' "$f" | grep -Eq "$MAN_RE" && ! printf '%s' "$f" | grep -Eq "$MAN_EX"; then
    MANS+=("$f")
  fi
done <<<"$CHANGED"

arr() { if [ $# -eq 0 ]; then echo '[]'; else printf '%s\n' "$@" | jq -R . | jq -sc 'unique'; fi; }
jq -nc --arg repo "$REPO" --arg base "$BASE" --argjson deploy "$DEPLOY" \
  --argjson yaml "$(arr "${YAML[@]}")" --argjson manifests "$(arr "${MANS[@]}")" \
  --argjson charts "$(arr "${CHARTS[@]}")" --argjson overlays "$(arr "${OVERLAYS[@]}")" \
  '{repo: $repo, base: $base, yaml: $yaml, manifests: $manifests, charts: $charts, overlays: $overlays, deploy: $deploy}'
