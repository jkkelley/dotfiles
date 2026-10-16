#!/usr/bin/env bash
# CI runs this suite. PR 99 merged with `make -C claude/workflow test` green only locally, because no job in
# .github/workflows/skill-pr-gate.yml ran it. This test is what stops that gap reopening silently: it drives the path
# selector the gate calls, and asserts the gate still has a job that runs the suite on pinned actions.
#
# The selector cases are the dependency list, stated as behaviour. A test here that starts calling another skill's
# script must add that skill to tools/ci-select.sh and a case below, or CI goes back to not running on its changes.
set -uo pipefail
R="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GATE="$R/../../.github/workflows/skill-pr-gate.yml"
SUITE="$R/../../.github/workflows/workflow-suite.yml"
PUB="$R/tools/ci-time-pub.sh"
ALLTEN='["schema","lint","herdr-first","compaction","chain","failover","test-plan","step-time","ci-job","inbox-sweep"]'
SEL="$R/tools/ci-select.sh"
fail=0
bad() { echo "FAIL: $1"; fail=1; }

sel() { printf '%s\n' "$@" | bash "$SEL"; }
want() { # want <expected> <paths...>
  local exp="$1"; shift
  local got; got="$(sel "$@" | head -n1)"
  [ "$got" = "workflow=$exp" ] || bad "ci-select on [$*] printed '$got', want workflow=$exp"
}
want true  claude/workflow/bin/seat-watch.sh
want true  claude/workflow/Makefile
want true  claude/skills/context-compaction/scripts/checkpoint.sh
want true  claude/skills/work-order/scripts/lib/test_plan.sh
want true  .github/workflows/skill-pr-gate.yml
want true  README.md claude/workflow/tests/unit/test_ci_job.sh
# The negatives: a docs-only or unrelated-skill pull request must not pay for this suite.
want false README.md
want false claude/skills/herdr/SKILL.md
want false claude/tools/skill-sync.sh
want false .github/workflows/skill-publish.yml
want false claude/workflowx/foo
# The shards= line, exactly (config order, no duplicates).
wantshards() { # wantshards <expected json> <paths...>
  local exp="$1"; shift
  local got; got="$(sel "$@" | sed -n 2p)"
  [ "$got" = "shards=$exp" ] || bad "ci-select on [$*] printed '$got', want shards=$exp"
}
wantshards '["lint","herdr-first","step-time"]' claude/workflow/bin/step-time.sh
wantshards '["inbox-sweep"]' claude/workflow/inbox-sweep/Makefile
wantshards '[]' claude/workflow/docs/x.md
[ "$(sel claude/workflow/docs/x.md | head -n1)" = "workflow=false" ] || bad "docs-only diff did not print workflow=false"
wantshards "$ALLTEN" claude/workflow/Makefile
wantshards "$ALLTEN" claude/workflow/timing/lib.sh
wantshards '[]' README.md
got="$(bash "$SEL" --full </dev/null | sed -n 2p)"
[ "$got" = "shards=$ALLTEN" ] || bad "ci-select --full printed '$got'"

# ci-time-pub.sh: the STEP_TIME_PUB contract; one JSON line per call, bad arity exits 2.
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
CI_TIME_FILE="$tmp/t.jsonl" bash "$PUB" line.ci.time.x '{"a":1}' || bad "ci-time-pub.sh exited non-zero"
[ "$(wc -l <"$tmp/t.jsonl")" = 1 ] || bad "ci-time-pub.sh did not write exactly one line"
[ "$(jq -r '.subject' "$tmp/t.jsonl")" = line.ci.time.x ] || bad "ci-time-pub.sh subject wrong"
[ "$(jq -r '.payload.a' "$tmp/t.jsonl")" = 1 ] || bad "ci-time-pub.sh payload wrong"
CI_TIME_FILE="$tmp/t.jsonl" bash "$PUB" onlyone 2>/dev/null; [ $? = 2 ] || bad "ci-time-pub.sh did not exit 2 on wrong arg count"

# An empty diff is a real input (a pull request whose only change was reverted) and must not error.
got="$(printf '' | bash "$SEL" | head -n1)" || bad "ci-select exited non-zero on an empty diff"
[ "$got" = "workflow=false" ] || bad "ci-select on an empty diff printed '$got'"

# The gate: the job exists, is selected by the selector, and runs the Makefile's own target.
python3 - "$GATE" "$SUITE" <<'PY' || fail=1
import re, sys, yaml
gate_src, suite_src = open(sys.argv[1]).read(), open(sys.argv[2]).read()
jobs = yaml.safe_load(gate_src)["jobs"]
errs = []
det = jobs.get("detect", {})
if det.get("outputs", {}).get("workflow") != "${{ steps.workflow.outputs.workflow }}":
    errs.append("detect does not export a workflow output from a step with id: workflow")
step = next((s for s in det.get("steps", []) if s.get("id") == "workflow"), None)
if not step or "claude/workflow/tools/ci-select.sh" not in step.get("run", ""):
    errs.append("detect's workflow step does not call claude/workflow/tools/ci-select.sh")
job = jobs.get("workflow")
if not job:
    errs.append("skill-pr-gate.yml has no workflow job")
else:
    if job.get("uses") != "./.github/workflows/workflow-suite.yml": errs.append("workflow job does not use workflow-suite.yml")
    if job.get("with", {}).get("shards") != "${{ needs.detect.outputs.workflow_shards }}": errs.append("workflow job does not pass detect's workflow_shards")
    if job.get("needs") != "detect": errs.append("workflow job does not need detect")
    if job.get("if") != "needs.detect.outputs.workflow == 'true'": errs.append("workflow job is not gated on detect's workflow output")
# The reusable workflow: triggers, cancel, timeout, podman, timing, cache, artifact.
suite = yaml.safe_load(suite_src)
on = suite.get(True, suite.get("on", {}))  # PyYAML reads the key `on` as True
for t in ("workflow_call", "push", "schedule"):
    if t not in on: errs.append(f"workflow-suite.yml has no {t} trigger")
if on.get("push", {}).get("branches") != ["main"]: errs.append("workflow-suite.yml push is not limited to main")
if not suite.get("concurrency", {}).get("cancel-in-progress"): errs.append("workflow-suite.yml does not cancel superseded runs")
sj = suite.get("jobs", {}).get("suite", {})
if sj.get("runs-on") != "ubuntu-24.04": errs.append("suite job is not on ubuntu-24.04 (Rule 15: never ubuntu-latest)")
if not sj.get("timeout-minutes"): errs.append("suite job has no timeout-minutes")
steps = sj.get("steps", [])
if not any("require-podman.sh" in s.get("run", "") for s in steps): errs.append("suite job does not assert podman")
if not any("bin/step-time.sh" in s.get("run", "") and "make -o image" in s.get("run", "") for s in steps): errs.append("suite job does not run the shard through step-time.sh with make -o image")
if not any(s.get("uses", "").startswith("actions/cache@") for s in steps): errs.append("suite job has no actions/cache step")
if not any(s.get("uses", "").startswith("actions/upload-artifact@") for s in steps): errs.append("suite job has no upload-artifact step")
# Rule 15 across both files: every action pinned to a full commit SHA with its tag in a comment.
for src in (gate_src, suite_src):
    for line in src.splitlines():
        m = re.search(r"^\s*(?:-\s*)?uses:\s*(\S+)(.*)$", line)
        if not m or m.group(1).startswith("./"): continue
        if not re.fullmatch(r"[\w.-]+/[\w./-]+@[0-9a-f]{40}", m.group(1)):
            errs.append(f"action not pinned to a commit SHA: {line.strip()}")
        elif not re.match(r"\s*#\s*v\d", m.group(2)):
            errs.append(f"pinned action has no tag comment: {line.strip()}")
for e in errs: print("FAIL: " + e)
sys.exit(1 if errs else 0)
PY

[ "$fail" = 0 ] && echo "ok  ci-job: the gate selects shards by diff and runs them sharded, timed, cached, on pinned actions"
exit "$fail"
