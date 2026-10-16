#!/usr/bin/env bash
# B1: the result and config schemas, and the three seat declarations.
#   - every seat status code in the schema has a fixture that validates (a code with no fixture is a code nothing tests)
#   - every invalid fixture is refused, above all a mutation other than marked-read (spec rule no-send)
#   - the config schema accepts the example config and refuses each bad one
#   - the Gmail declaration denies every send-class tool; the browser declarations ride the claude-win-chrome link
# Schema validity of the declarations themselves is `make -C claude/workflow schema`; the declarations are read-only here.
set -uo pipefail
R="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=_t.sh
. "$(dirname "${BASH_SOURCE[0]}")/_t.sh"
REPO="$(cd "$R/../../.." && pwd)"

if ! python3 -I - "$R" "$REPO" <<'PY'
import json, pathlib, sys
from jsonschema import Draft202012Validator
R = pathlib.Path(sys.argv[1]); REPO = pathlib.Path(sys.argv[2])
bad = 0
def load(p): return json.loads(pathlib.Path(p).read_text())
def errs(s, i): return list(Draft202012Validator(s).iter_errors(i))
def ok(m): print("ok  " + m)
def no(m, *d):
    global bad; bad = 1; print("FAIL " + m); [print("     " + x) for x in d]

res = load(R / "schemas/result.schema.json"); cfg = load(R / "schemas/config.schema.json")
Draft202012Validator.check_schema(res); Draft202012Validator.check_schema(cfg)
ok("both schemas are valid draft 2020-12")

codes = set(res["properties"]["status"]["enum"])
seen = set()
for f in sorted((R / "tests/fixtures/results").glob("*.json")):
    e = errs(res, load(f))
    if e: no(f"{f.name} should validate", e[0].message)
    else: ok(f"{f.name} validates")
    seen.add(load(f)["status"])
if seen != codes: no("one fixture per status code", f"missing: {sorted(codes - seen)}", f"unknown: {sorted(seen - codes)}")
else: ok(f"all {len(codes)} seat status codes have a validating fixture")

for f in sorted((R / "tests/fixtures/results/invalid").glob("*.json")):
    e = errs(res, load(f))
    if e: ok(f"{f.name} refused: {e[0].message[:70]}")
    else: no(f"{f.name} was ACCEPTED")
for act in ("sent", "deleted", "archived", "replied", "moved"):
    if not (R / f"tests/fixtures/results/invalid/mutation-{act}.json").exists(): no(f"mutation-{act} fixture missing")

valid = load(R / "tests/fixtures/config/valid.json")
if errs(cfg, valid): no("valid config should validate", errs(cfg, valid)[0].message)
else: ok("config/valid.json validates")
for f in sorted((R / "tests/fixtures/config").glob("invalid-*.json")):
    e = errs(cfg, load(f))
    if e: ok(f"{f.name} refused: {e[0].message[:70]}")
    else: no(f"{f.name} was ACCEPTED")

W = REPO / "claude/workflow/schemas/workflows"
g = load(W / "inbox-sweep-gmail.workflow.json")["agent"]
sends = {"send_message", "reply", "forward", "create_draft", "update_draft", "trash_thread", "trash_message",
         "label_thread", "label_message", "mark_thread_spam", "mark_message_spam"}
missing = {"mcp__claude_ai_Gmail__" + s for s in sends} - set(g["denied_tools"])
leak = {"mcp__claude_ai_Gmail__" + s for s in sends} & set(g["allowed_tools"])
if missing or leak: no("gmail declaration denies every send-class tool", f"not denied: {sorted(missing)}", f"allowed: {sorted(leak)}")
else: ok("gmail declaration denies every send-class tool and allows none")
for n in ("proton", "linkedin"):
    a = load(W / f"inbox-sweep-{n}.workflow.json")["agent"]
    if [m["id"] for m in a.get("models", [])] != ["claude-win-chrome"]: no(f"{n} declaration rides the claude-win-chrome link")
    else: ok(f"{n} declaration rides the claude-win-chrome link")
sys.exit(bad)
PY
then fail=1; fi
finish
