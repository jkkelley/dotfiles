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
[ -f "$ledger" ] || printf 'at_utc\tstep\tstatus\ttext\tby\tref\n' > "$ledger"
marker="$(dirname "$out")/.approved"
if [ -z "$approved" ]; then approved=false; [ -f "$marker" ] && approved=true; else [ "$approved" = true ] && : > "$marker" || rm -f "$marker"; fi
sidehtml=""; [ -n "$side" ] && sidehtml="$(cat "$side")"
# BREADCRUMB - why plan validation and ledger parsing moved out of jq and into the python block below.
# What broke: the upstream copy (~/.claude/skills/execution-rail/bin/rail-build.sh, lines 11 and 15-16) called jq
#   three times, then python3 for the render. jq is absent from Git Bash on Windows and from the pinned python image
#   this skill's suite runs in, so the vendored copy could not be tested under Rule 14 without a third image.
# Why it mattered: a template every scaffolded project inherits must run wherever that project runs (Rule 17), and a
#   script that cannot be tested in the suite's own image ships unproven.
# Why this fix: python3 is already a hard dependency of this script for the render, so doing the parse there removes a
#   dependency instead of adding one. Rejected: a jq-carrying test image, which proves the script only on machines that
#   happen to have jq and leaves the Windows failure in place.
# Cost: none at runtime; the parse is the same five-field split jq did.
built="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
python3 - "$T" "$out" "$plan" "$ledger" "$built" "$approved" "$title" "$eyebrow" "$source" "$sidehtml" "$signal" <<'PY'
import json,sys
t,o,planf,ledgerf,built,approved,title,eyebrow,source,side,signal=sys.argv[1:12]
try:
    p=json.load(open(planf,encoding="utf-8"))
except (OSError,ValueError) as e:
    sys.exit(f"plan.json does not parse: {e}")
if not isinstance(p,list) or not all(isinstance(x,dict) and {"id","t","who"} <= x.keys() for x in p):
    sys.exit("plan.json must be an array of {id,t,who,gate,owner}")
plan=json.dumps(p,separators=(",",":"))
keys=("at_utc","step","status","text","by","ref")
lines=open(ledgerf,encoding="utf-8").read().split("\n")[1:]
rows=json.dumps([dict(zip(keys,(l.split("\t")+[""]*6)[:6])) for l in lines if l],separators=(",",":"))
s=open(t,encoding="utf-8").read()
for k,v in (("__PLAN_JSON__",plan),("__LEDGER_JSON__",rows),("__BUILT_AT__",built),("__APPROVED__",approved),("__TITLE__",title),("__EYEBROW__",eyebrow),("__SOURCE__",source),("__SIDE_HTML__",side),("__SIGNAL__",signal)):
    s=s.replace(k,v)
open(o,"w",encoding="utf-8").write(s)
PY
echo "$out"
