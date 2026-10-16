#!/usr/bin/env bash
# name: gitops-gate-evidence.sh
# purpose: hold a PR that touches a deploy path until its body names its ticket and carries Gate-Dev and Gate-UAT GATE-PASS lines
# inputs: --repo OWNER/NAME, --select FILE (selection JSON with .deploy), optional --body-file FILE, --config FILE (else GITOPS_CI_CONFIG, else ../config/gitops-ci.json); GITHUB_EVENT_PATH for the PR body
# outputs: GATE-SKIP, GATE-MISSING, GATE-HOLD or GATE-OK lines on stdout; exit 0 pass or skip, 1 held, 2 bad argument
# writes-to: nothing
# cleanup: none
set -euo pipefail
HERE=$(cd "$(dirname "$(readlink -f "$0")")" && pwd)

usage() {
  echo "usage: gitops-gate-evidence.sh --repo OWNER/NAME --select FILE [--body-file FILE] [--config FILE]"
}

repo="" select="" body_file="" config=""
while [ $# -gt 0 ]; do
  case $1 in
    -h|--help) usage; exit 0 ;;
    --repo) [ $# -ge 2 ] || { usage >&2; exit 2; }; repo=$2; shift 2 ;;
    --select) [ $# -ge 2 ] || { usage >&2; exit 2; }; select=$2; shift 2 ;;
    --body-file) [ $# -ge 2 ] || { usage >&2; exit 2; }; body_file=$2; shift 2 ;;
    --config) [ $# -ge 2 ] || { usage >&2; exit 2; }; config=$2; shift 2 ;;
    *) usage >&2; exit 2 ;;
  esac
done
if [ -z "$repo" ] || [ -z "$select" ]; then usage >&2; exit 2; fi
[ -f "$select" ] || { echo "gitops-gate-evidence.sh: no selection file $select" >&2; exit 2; }
config=${config:-${GITOPS_CI_CONFIG:-$HERE/../config/gitops-ci.json}}
[ -f "$config" ] || { echo "gitops-gate-evidence.sh: no config at $config" >&2; exit 2; }

if [ "$(jq -r .deploy "$select")" != "true" ]; then
  echo "GATE-SKIP no-deploy-path"
  exit 0
fi

if [ -n "$body_file" ]; then
  [ -f "$body_file" ] || { echo "gitops-gate-evidence.sh: no body file $body_file" >&2; exit 2; }
  body=$(cat "$body_file")
elif [ -n "${GITHUB_EVENT_PATH:-}" ] && jq -e .pull_request "$GITHUB_EVENT_PATH" >/dev/null 2>&1; then
  body=$(jq -r '.pull_request.body // ""' "$GITHUB_EVENT_PATH")
else
  echo "GATE-SKIP not-a-pr"
  exit 0
fi
body=${body//$'\r'/}

cfg=$(jq --arg r "$repo" '.defaults * (.repos[$r] // {})' "$config")
ticket_re=$(jq -r '.evidence.ticket_re' <<<"$cfg")
dev_re=$(jq -r '.evidence.dev_re' <<<"$cfg")
uat_re=$(jq -r '.evidence.uat_re' <<<"$cfg")

missing=0
ticket=$(grep -oE "$ticket_re" <<<"$body" | head -n1 || true)
if [ -z "$ticket" ]; then echo "GATE-MISSING ticket"; missing=1; fi
if ! grep -qE "$dev_re" <<<"$body"; then echo "GATE-MISSING dev"; missing=1; fi
if ! grep -qE "$uat_re" <<<"$body"; then echo "GATE-MISSING uat"; missing=1; fi
if [ "$missing" -ne 0 ]; then
  echo "GATE-HOLD add the ticket id and the Gate-Dev: and Gate-UAT: lines to the PR body, then push a commit (CI reads the body at the event)"
  exit 1
fi
echo "GATE-OK $ticket dev uat"
