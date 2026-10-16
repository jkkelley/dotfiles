#!/usr/bin/env bash
# name: gitops-check.sh
# purpose: validate a gitops-changed selection (yamllint, kubeconform, helm template, kustomize build) in digest-pinned images, PASS/FAIL per target
# inputs: --repo OWNER/NAME --repo-dir DIR --select FILE [--config FILE]; config/gitops-ci.json (or GITOPS_CI_CONFIG); GITOPS_CI_RUNTIME optional
# outputs: one PASS/FAIL/SKIP line per check target, then GITOPS-CHECK ok (exit 0) or GITOPS-CHECK fail N (exit 1); exit 2 bad argument, exit 4 env missing
# writes-to: a mktemp dir per chart, removed on exit
# cleanup: the mktemp dir is removed after each chart and by an EXIT trap
set -uo pipefail
HERE=$(cd "$(dirname "$(readlink -f "$0")")" && pwd)

usage() { echo "usage: gitops-check.sh --repo OWNER/NAME --repo-dir DIR --select FILE [--config FILE]"; }

REPO="" DIR="" SEL="" CFG=${GITOPS_CI_CONFIG:-}
while [ $# -gt 0 ]; do
  case $1 in
    -h|--help) usage; exit 0 ;;
    --repo) REPO=${2:-}; shift 2 ;;
    --repo-dir) DIR=${2:-}; shift 2 ;;
    --select) SEL=${2:-}; shift 2 ;;
    --config) CFG=${2:-}; shift 2 ;;
    *) usage >&2; exit 2 ;;
  esac
done
{ [ -n "$REPO" ] && [ -n "$DIR" ] && [ -n "$SEL" ]; } || { usage >&2; exit 2; }
[ -n "$CFG" ] || CFG=$HERE/../config/gitops-ci.json
[ -f "$SEL" ] || { echo "gitops-check: no selection at $SEL" >&2; exit 2; }
[ -f "$CFG" ] || { echo "gitops-check: no config at $CFG" >&2; exit 2; }

# Runtime: env override, else podman, else docker.
if [ -n "${GITOPS_CI_RUNTIME:-}" ]; then
  [ -x "$GITOPS_CI_RUNTIME" ] || { echo "ENV-MISSING GITOPS_CI_RUNTIME"; exit 4; }
  RT=$GITOPS_CI_RUNTIME
elif command -v podman >/dev/null 2>&1; then RT=podman
elif command -v docker >/dev/null 2>&1; then RT=docker
else echo "ENV-MISSING podman docker"; exit 4
fi

RC=$(jq -c --arg r "$REPO" '.defaults * (.repos[$r] // {})' "$CFG") || { echo "gitops-check: bad config $CFG" >&2; exit 2; }
cfg() { jq -r "$1" <<<"$RC"; }
IMG_Y=$(cfg .images.yamllint) IMG_K=$(cfg .images.kubeconform) IMG_H=$(cfg .images.helm) IMG_Z=$(cfg .images.kustomize)
YCFG=$(cfg .yamllint_config)
KC=(-strict -summary -ignore-missing-schemas -kubernetes-version "$(cfg .kubernetes_version)")
while IFS= read -r loc; do KC+=(-schema-location "$loc"); done < <(jq -r '.schema_locations[]' <<<"$RC")

list() { jq -r ".$1[]?" "$SEL"; }
mapfile -t YAML < <(list yaml)
mapfile -t MANIFESTS < <(list manifests)
mapfile -t CHARTS < <(list charts)
mapfile -t OVERLAYS < <(list overlays)

TMP=""
trap '[ -n "$TMP" ] && rm -rf "$TMP"' EXIT

pull() {
  local img=$1 n d
  for n in 1 2 3; do
    "$RT" pull -q "$img" >/dev/null 2>&1 && return 0
    [ "$n" -lt 3 ] && { d=$((n * 2)); sleep "$d"; }
  done
  echo "IMAGE-PULL $img"; exit 4
}
[ ${#YAML[@]} -gt 0 ] && pull "$IMG_Y"
if [ ${#MANIFESTS[@]} -gt 0 ] || [ ${#CHARTS[@]} -gt 0 ] || [ ${#OVERLAYS[@]} -gt 0 ]; then pull "$IMG_K"; fi
[ ${#CHARTS[@]} -gt 0 ] && pull "$IMG_H"
[ ${#OVERLAYS[@]} -gt 0 ] && pull "$IMG_Z"

FAILS=0
report() { # status check target
  echo "$1 $2 $3"
  [ "$1" = FAIL ] && FAILS=$((FAILS + 1))
  return 0
}

# Every image mounts at /work: the kustomize image keeps its binary in /app and helm works in /apps.
if [ ${#YAML[@]} -gt 0 ]; then
  if "$RT" run --rm -v "$DIR:/work:ro,Z" -w /work "$IMG_Y" -d "$YCFG" -- "${YAML[@]}"; then
    report PASS yamllint "${#YAML[@]} files"
  else report FAIL yamllint "${#YAML[@]} files"; fi
else report SKIP yamllint none; fi

if [ ${#MANIFESTS[@]} -gt 0 ]; then
  if "$RT" run --rm -v "$DIR:/work:ro,Z" -w /work "$IMG_K" "${KC[@]}" "${MANIFESTS[@]}"; then
    report PASS manifests "${#MANIFESTS[@]} files"
  else report FAIL manifests "${#MANIFESTS[@]} files"; fi
else report SKIP manifests none; fi

if [ ${#CHARTS[@]} -gt 0 ]; then
  for c in "${CHARTS[@]}"; do
    TMP=$(mktemp -d)
    cp -a "$DIR/$c/." "$TMP/"
    ok=1
    if grep -q '^dependencies:' "$TMP/Chart.yaml" 2>/dev/null; then
      "$RT" run --rm -v "$TMP:/work:Z" -w /work "$IMG_H" dependency build . || ok=0
    fi
    if [ "$ok" = 1 ]; then
      ( set -o pipefail
        "$RT" run --rm -v "$TMP:/work:ro,Z" -w /work "$IMG_H" template ci . \
          | "$RT" run --rm -i "$IMG_K" "${KC[@]}" - ) || ok=0
    fi
    rm -rf "$TMP"; TMP=""
    if [ "$ok" = 1 ]; then report PASS chart "$c"; else report FAIL chart "$c"; fi
  done
else report SKIP chart none; fi

if [ ${#OVERLAYS[@]} -gt 0 ]; then
  for o in "${OVERLAYS[@]}"; do
    if ( set -o pipefail
         "$RT" run --rm -v "$DIR:/work:ro,Z" -w /work "$IMG_Z" build "$o" \
           | "$RT" run --rm -i "$IMG_K" "${KC[@]}" - ); then
      report PASS overlay "$o"
    else report FAIL overlay "$o"; fi
  done
else report SKIP overlay none; fi

if [ "$FAILS" -eq 0 ]; then echo "GITOPS-CHECK ok"; exit 0; fi
echo "GITOPS-CHECK fail $FAILS"; exit 1
