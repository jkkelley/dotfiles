#!/usr/bin/env bash
# Proves the test-plan block is one contract, not three that happen to agree today (O-10).
#
# The template the architect copies, the parser work-order's start gate reads it with, and the schema are
# written in three files. Each property below has a silent failure mode:
#   1. The filled template, parsed by the work-order skill's own wo_test_plan_json, validates against the
#      schema. If a label in the template drifts from the parser, the parse loses a field and this fails.
#   2. The template as shipped, placeholders and all, is REJECTED. A plan copied and never filled must not
#      pass for a plan a tester can run.
#   3. A floating tag and a plan with no case are REJECTED, which is the owner law in data: Podman, pinned
#      by digest, and at least one case.
#
# Hermetic: parser and schema only, --network=none. The parser is sourced from the skill rather than copied,
# because a copy is exactly the second contract this test exists to prevent.
set -euo pipefail
R="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WO="$R/../skills/work-order/scripts/lib"
S="$R/schemas/test-plan.schema.json"
T="$R/templates/test-plan.md"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
fail=0

# shellcheck source=../../../skills/work-order/scripts/lib/common.sh disable=SC1091
. "$WO/common.sh"
# shellcheck source=../../../skills/work-order/scripts/lib/wo.sh disable=SC1091
. "$WO/wo.sh"
set +e   # the libraries are written for set -e callers; the checks below read exit codes themselves

accepts() { if bash "$R/tools/validate-schema.sh" "$S" "$2" 2>"$TMP/err"; then echo "ok  accepted: $1"; else echo "FAIL: schema REJECTED $1"; cat "$TMP/err"; fail=1; fi; }
rejects() { if bash "$R/tools/validate-schema.sh" "$S" "$2" 2>/dev/null; then echo "FAIL: schema ACCEPTED $1"; fail=1; else echo "ok  rejected: $1"; fi; }

python3 -c 'import json,sys; from jsonschema import Draft202012Validator as V; V.check_schema(json.load(open(sys.argv[1])))' "$S" \
  || { echo "FAIL: test-plan.schema.json is not a valid 2020-12 schema"; fail=1; }

# ---- 1. the template, filled the way an architect fills it ----
DIGEST="docker.io/library/debian@sha256:328d16499860ae6cb9b345e2e4cebca08c2a36e4f7278482c7bd1f39d71e5bfd"
# shellcheck disable=SC2016  # the backticks are literal markdown in the template, not expansions
sed -e 's|<the one unit this ticket changed[^>]*>|work-order.sh start on a test ticket|' \
    -e 's|<why it matters[^>]*>|a tester handed no plan would invent one|' \
    -e 's|`<the exact command[^>]*>`|`bash testing/run-tests.sh \| tail -1`|' \
    -e 's|<the exit code and[^>]*>|exit 0, the last line reads all cases passed|' \
    -e "s|\`<registry>/<name>@sha256:<64 hex digest>\` (<human tag at pin time>)|\`$DIGEST\` (debian:stable-slim)|" \
    -e 's|<what full integration CI[^>]*>|the full skill suite on every image, in skill-pr-gate|' \
    "$T" >"$TMP/filled.md"
wo_test_plan_json "$TMP/filled.md" >"$TMP/filled.json"
accepts "the filled template, as parsed by work-order" "$TMP/filled.json"
# A pipe inside a command survives the parse - the reason cases are a list and not a table.
if jq -e '.cases[0].command == "bash testing/run-tests.sh | tail -1"' "$TMP/filled.json" >/dev/null; then
  echo "ok  parsed: a command keeps its pipe and loses only its backticks"
else echo "FAIL: the case command was mangled: $(jq -c '.cases[0].command' "$TMP/filled.json")"; fail=1; fi
if jq -e ".isolation.image == \"$DIGEST\"" "$TMP/filled.json" >/dev/null; then
  echo "ok  parsed: the human tag beside the digest is not part of the image"
else echo "FAIL: the image was mangled: $(jq -c '.isolation.image' "$TMP/filled.json")"; fail=1; fi

# ---- the same block inside a ticket, between its neighbours, parses the same ----
{ printf -- '---\n{"id":"WO-20260923-0001","type":"test"}\n---\n# WO-20260923-0001 - t\n\n## Acceptance criteria\n\n- [ ] x\n\n## Test plan\n\n'
  cat "$TMP/filled.md"; printf '\n## Assumptions\n\n- **Cases**\n'; } >"$TMP/ticket.md"
wo_test_plan_json "$TMP/ticket.md" >"$TMP/ticket.json"
if [ "$(jq -S . "$TMP/filled.json")" = "$(jq -S . "$TMP/ticket.json")" ]; then
  echo "ok  parsed: the block inside a ticket reads the same, and stops at the next section"
else echo "FAIL: the in-ticket parse differs"; jq -c . "$TMP/filled.json" "$TMP/ticket.json"; fail=1; fi

# ---- 2. the template as shipped ----
wo_test_plan_json "$T" >"$TMP/raw.json"
rejects "the unfilled template (placeholders are not a plan)" "$TMP/raw.json"

# ---- 3. the owner law, in data ----
jq '.isolation.image = "docker.io/library/debian:stable-slim"' "$TMP/filled.json" >"$TMP/tag.json"
rejects "an image on a floating tag" "$TMP/tag.json"
jq '.isolation.runtime = "docker"' "$TMP/filled.json" >"$TMP/docker.json"
rejects "a runtime other than podman" "$TMP/docker.json"
jq '.cases = []' "$TMP/filled.json" >"$TMP/nocase.json"
rejects "a plan with no case" "$TMP/nocase.json"
jq 'del(.cases[0].intent)' "$TMP/filled.json" >"$TMP/nointent.json"
rejects "a case with no intent" "$TMP/nointent.json"
jq '.out_of_scope = []' "$TMP/filled.json" >"$TMP/noci.json"
rejects "a plan that names nothing CI covers" "$TMP/noci.json"

[ "$fail" -eq 0 ] || exit 1
echo "ok  test-plan: template, parser and schema agree; unfilled, unpinned and caseless plans refused"
