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
SEL="$R/tools/ci-select.sh"
fail=0
bad() { echo "FAIL: $1"; fail=1; }

sel() { printf '%s\n' "$@" | bash "$SEL"; }
want() { # want <expected> <paths...>
  local exp="$1"; shift
  local got; got="$(sel "$@")"
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
# An empty diff is a real input (a pull request whose only change was reverted) and must not error.
got="$(printf '' | bash "$SEL")" || bad "ci-select exited non-zero on an empty diff"
[ "$got" = "workflow=false" ] || bad "ci-select on an empty diff printed '$got'"

# The gate: the job exists, is selected by the selector, and runs the Makefile's own target.
python3 - "$GATE" <<'PY' || fail=1
import re, sys, yaml
src = open(sys.argv[1]).read()
jobs = yaml.safe_load(src)["jobs"]
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
    if job.get("needs") != "detect": errs.append("workflow job does not need detect")
    if job.get("if") != "needs.detect.outputs.workflow == 'true'": errs.append("workflow job is not gated on detect's workflow output")
    if job.get("runs-on") != "ubuntu-24.04": errs.append("workflow job is not on ubuntu-24.04 (Rule 15: never ubuntu-latest)")
    runs = [s.get("run", "") for s in job.get("steps", [])]
    if "bash .github/scripts/require-podman.sh" not in runs: errs.append("workflow job does not assert podman")
    if "make -C claude/workflow test" not in runs: errs.append("workflow job does not run make -C claude/workflow test")
# Rule 15 across the whole gate: every action pinned to a full commit SHA with its tag in a comment.
for line in src.splitlines():
    m = re.search(r"uses:\s*(\S+)(.*)$", line)
    if m and not re.fullmatch(r"[\w.-]+/[\w./-]+@[0-9a-f]{40}", m.group(1)):
        errs.append(f"action not pinned to a commit SHA: {line.strip()}")
    elif m and not re.match(r"\s*#\s*v\d", m.group(2)):
        errs.append(f"pinned action has no tag comment: {line.strip()}")
for e in errs: print("FAIL: " + e)
sys.exit(1 if errs else 0)
PY

[ "$fail" = 0 ] && echo "ok  ci-job: the gate runs make -C claude/workflow test when its dependencies change, on pinned actions"
exit "$fail"
