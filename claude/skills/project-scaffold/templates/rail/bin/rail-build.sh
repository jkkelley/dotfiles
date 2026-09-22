#!/usr/bin/env bash
# execution-rail: build the tracker page from a plan and a ledger. See SKILL.md for the contract.
# Usage: rail-build.sh --plan plan.json --ledger ledger.tsv --out page.html [--title T] [--eyebrow E] [--source S]
#        [--side side.html] [--signal GOTEAM] [--approved] [--not-approved]
set -euo pipefail
D="$(cd "$(dirname "$0")/.." && pwd)"; T="$D/assets/template.html"
plan= ledger= out= title="Execution Rail" eyebrow="execution rail" source="" side= signal="GOTEAM" approved=
while (( $# )); do case $1 in
  --plan) plan=$2; shift 2;; --ledger) ledger=$2; shift 2;; --out) out=$2; shift 2;; --title) title=$2; shift 2;;
  --eyebrow) eyebrow=$2; shift 2;; --source) source=$2; shift 2;; --side) side=$2; shift 2;; --signal) signal=$2; shift 2;;
  --approved) approved=true; shift;; --not-approved) approved=false; shift;; *) echo "unknown flag $1" >&2; exit 2;; esac; done
[ -n "$plan" ] && [ -n "$ledger" ] && [ -n "$out" ] || { sed -n 3,4p "$0"; exit 2; }
jq -e 'type=="array" and all(.[]; has("id") and has("t") and has("who"))' "$plan" >/dev/null || { echo "plan.json must be an array of {id,t,who,gate,owner}" >&2; exit 2; }
[ -f "$ledger" ] || printf 'at_utc\tstep\tstatus\ttext\tby\tref\n' > "$ledger"
marker="$(dirname "$out")/.approved"
if [ -z "$approved" ]; then approved=false; [ -f "$marker" ] && approved=true; else [ "$approved" = true ] && : > "$marker" || rm -f "$marker"; fi
rows="$(tail -n +2 "$ledger" | jq -R -s -c 'split("\n") | map(select(length>0) | split("\t") | {at_utc:.[0], step:.[1], status:.[2], text:.[3], by:.[4], ref:(.[5] // "")})')"
planjson="$(jq -c . "$plan")"; sidehtml=""; [ -n "$side" ] && sidehtml="$(cat "$side")"
built="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
python3 - "$T" "$out" "$planjson" "$rows" "$built" "$approved" "$title" "$eyebrow" "$source" "$sidehtml" "$signal" <<'PY'
import sys
t,o,plan,rows,built,approved,title,eyebrow,source,side,signal=sys.argv[1:12]
s=open(t,encoding="utf-8").read()
for k,v in (("__PLAN_JSON__",plan),("__LEDGER_JSON__",rows),("__BUILT_AT__",built),("__APPROVED__",approved),("__TITLE__",title),("__EYEBROW__",eyebrow),("__SOURCE__",source),("__SIDE_HTML__",side),("__SIGNAL__",signal)):
    s=s.replace(k,v)
open(o,"w",encoding="utf-8").write(s)
PY
echo "$out"
