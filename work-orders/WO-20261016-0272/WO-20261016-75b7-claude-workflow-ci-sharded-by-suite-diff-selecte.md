---
{
  "id": "WO-20261016-75b7",
  "slug": "claude-workflow-ci-sharded-by-suite-diff-selecte",
  "title": "claude/workflow CI sharded by suite: diff-selected matrix, full on main and nightly, cached image, timed by step-time.sh",
  "type": "feature",
  "status": "ready",
  "priority": "p0",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T07:20:27+00:00",
  "parent": "WO-20261016-0272",
  "branch": null,
  "pr": null,
  "closed": null,
  "approval": {
    "via": "override",
    "reason": "infra-design3 cut for ORD-0715; design approvals ruled done, ORD-0550 O4",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [],
  "blocks": [
    "WO-20261016-ff68"
  ]
}
---

# WO-20261016-75b7 - claude/workflow CI sharded by suite: diff-selected matrix, full on main and nightly, cached image, timed by step-time.sh

## Contents

- Problem
- Scope
- Degrees of freedom
- Acceptance criteria
- Test plan
- Assumptions
- Open questions
- Notes
- Outcome

## Problem

ORD-0715 C1 (orchestrator brief BR-20261016-infra-design3): "the claude/workflow CI job is sharded into a matrix by suite directory, runs only the suites the diff touches (full matrix on main and nightly), caches podman images, and cancels superseded runs; budget 3 minutes per PR. Timed by step-time.sh so SLOW shows up on the bus." Owner, Design principles 101 item 1: "CICD SPEED IS KING"; item 6: "i hate slow CICD ... test only things relevant"; item 37: "every node, seat, job, CI run and merge records its start and end in UTC on the bus by script". Today .github/workflows/skill-pr-gate.yml job 'claude/workflow' runs the whole `make -C claude/workflow test` serially in one job whenever tools/ci-select.sh says workflow=true (any claude/workflow path): measured run 2026-10-16T07:02:20Z to 07:10:29Z, 8 min 9 s. Every target rebuilds localhost/dotfiles-workflow-test:1 from tests/container/Containerfile. Verified in podman 2026-10-16: `make -n -o image -C claude/workflow step-time` prints no podman build, but `make -C claude/workflow inbox-sweep` recurses into inbox-sweep whose own image target still builds, so the inbox-sweep shard calls `make -o image -C claude/workflow/inbox-sweep` directly. GitHub runners cannot reach the local NATS bus, so step-time.sh publishes through STEP_TIME_PUB=ci-time-pub.sh into a JSONL file uploaded as an artifact (item 28 fallback: bus down -> file queue); its import to the bus is WO cut alongside (C1b), and run-level start/end already reach the bus through WO-20261016-e832 - CI producer: ci-events.sh publishes GitHub Actions run start and end to the bus. Branch protection on main: none; merge-on-green REQUIRED_CHECK is 'what has to run' (the detect job), so renaming the claude/workflow job into a matrix breaks no required check.

## Scope

**In**

- touches: claude/workflow/config/ci-shards.json (new)
- touches: claude/workflow/tools/ci-select.sh
- touches: claude/workflow/tools/ci-time-pub.sh (new)
- touches: claude/workflow/tests/unit/test_ci_job.sh
- touches: .github/workflows/workflow-suite.yml (new)
- touches: .github/workflows/skill-pr-gate.yml
- touches (generated, written only by work-order.sh start/submit/done, never by hand): work-orders/INDEX.md, this ticket file and its archive path, work-orders/WO-20261016-0272/README.md
- step: copy /home/luna/.local/state/zenith/context/2026/10/20261016-071924-ci-shards-c1.json to claude/workflow/config/ci-shards.json byte for byte (`cp`); its $comment states the selection rules below
- step: tools/ci-select.sh: keep reading changed paths on stdin and keep printing `workflow=true|false` first; add flags `--config F` (default $HERE/../config/ci-shards.json) and `--full`; second output line `shards=<compact JSON array of shard names, config order, no duplicates>`. Per path, in order: matches any all_on glob -> every shard; else every shard whose paths match; else matches an ignore glob -> none; else matches a roots glob -> every shard; else none. Globs are compared with bash `[[ $p == $glob ]]` (unquoted glob). `--full` ignores stdin and prints every shard. workflow=true iff shards is not []. jq reads the config; update the header comment's path list to say the list now lives in config/ci-shards.json; keep the rolodex header keys (name, purpose, inputs, outputs, writes-to, cleanup) complete
- step: tools/ci-time-pub.sh (new, rolodex header keys name/purpose/inputs/outputs/writes-to/cleanup, set -euo pipefail): usage `ci-time-pub.sh <subject> <json>`, the STEP_TIME_PUB contract of bin/step-time.sh; appends `jq -nc --arg s SUBJECT --argjson p JSON '{subject:$s,payload:$p}'` as one line to ${CI_TIME_FILE:?}; exit 2 on wrong arg count; breadcrumb comment: GitHub runners cannot reach the local bus, the file is the item 28 fallback, uploaded as artifact step-time-<shard> and imported by the C1b ticket
- step: .github/workflows/workflow-suite.yml (new), name 'workflow suite', breadcrumb comment block at top citing ORD-0715 C1 and the 8 min 9 s measurement; on: workflow_call (input shards: string, required false, default ''), push branches [main], schedule cron '17 3 * * *', workflow_dispatch; permissions contents: read; concurrency group `workflow-suite-${{ github.event_name }}-${{ github.event.pull_request.number || github.ref }}`, cancel-in-progress: true
- step: workflow-suite.yml job 'plan' (runs-on ubuntu-24.04, checkout actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1): output shards = inputs.shards when not empty, else the shards= line of `bash claude/workflow/tools/ci-select.sh --full </dev/null` written to GITHUB_OUTPUT
- step: workflow-suite.yml job 'suite': needs plan; if needs.plan.outputs.shards != '[]'; name `${{ matrix.shard }}`; runs-on ubuntu-24.04; timeout-minutes 7; strategy fail-fast false, matrix shard fromJSON(needs.plan.outputs.shards). Steps in order: checkout (same pin, fetch-depth 0); `bash .github/scripts/require-podman.sh`; actions/cache@55cc8345863c7cc4c66a329aec7e433d2d1c52a9 # v6.1.0 with path ${{ runner.temp }}/workflow-image.tar, key workflow-image-${{ hashFiles('claude/workflow/tests/container/Containerfile') }}; image step: if the tar exists `podman load -i` it, else `make -C claude/workflow image` then `podman save -o <tar> localhost/dotfiles-workflow-test:1`; run step: read dir, target, pr_target, budget_s, timeout_s, retries for the shard from claude/workflow/config/ci-shards.json with jq; on pull_request with pr_target set use pr_target and append BASE=origin/${{ github.base_ref }}; run `CI_TIME_FILE=$RUNNER_TEMP/step-time.jsonl STEP_TIME_PUB='bash claude/workflow/tools/ci-time-pub.sh' bash claude/workflow/bin/step-time.sh --line ci --node workflow-<shard> --budget <budget_s> --timeout <timeout_s> --retries <retries> -- make -o image -C <dir> <target> [BASE=...]`; last step if: always(): actions/upload-artifact@043fb46d1a93c77aae656e7c1c64a875d1fc6a0a # v7.0.1 name step-time-${{ matrix.shard }}, path ${{ runner.temp }}/step-time.jsonl, retention-days 7, if-no-files-found ignore
- step: skill-pr-gate.yml: detect gains output `workflow_shards: ${{ steps.workflow.outputs.shards }}`; job 'workflow' keeps name claude/workflow, needs detect and its if, and becomes `uses: ./.github/workflows/workflow-suite.yml` with `with: shards: ${{ needs.detect.outputs.workflow_shards }}` (runs-on and steps removed, a reusable-workflow job cannot carry them); rewrite its comment block's last paragraph: the suite now runs sharded in workflow-suite.yml, why (8 min 9 s serial), rejected alternative (a path-filtered sibling workflow leaves a check pending forever), cost (one matrix job per selected shard). Leave the top-level concurrency block unchanged: it already cancels superseded PR runs
- step: tests/unit/test_ci_job.sh: keep every existing want line (they hold under the new rules: herdr SKILL.md, skill-sync.sh, skill-publish.yml and claude/workflowx/foo are outside roots); add want-shards cases asserting the shards= line exactly: claude/workflow/bin/step-time.sh -> ["lint","herdr-first","step-time"]; claude/workflow/inbox-sweep/Makefile -> ["inbox-sweep"]; claude/workflow/docs/x.md -> [] and workflow=false; claude/workflow/Makefile -> all ten; claude/workflow/timing/lib.sh (unmatched, under roots) -> all ten; README.md -> []; --full with empty stdin -> all ten. Replace the gate python block's assertions on job 'workflow' with: uses == './.github/workflows/workflow-suite.yml', with.shards == '${{ needs.detect.outputs.workflow_shards }}', needs detect, the existing if; and add a python block over workflow-suite.yml asserting the triggers (workflow_call, push main, schedule), concurrency.cancel-in-progress true, suite.runs-on ubuntu-24.04, suite.timeout-minutes present, a step running require-podman.sh, a step whose run contains 'bin/step-time.sh' and 'make -o image', an actions/cache step and an upload-artifact step; run the Rule 15 pin loop over both files; add a ci-time-pub.sh case: CI_TIME_FILE=$tmp/t.jsonl bash ci-time-pub.sh line.ci.time.x '{"a":1}' exits 0 and the file holds exactly one line whose .subject is line.ci.time.x and .payload.a is 1
- step: run `make -C claude/workflow ci-job`, `make -C claude/workflow lint`, `make rolodex-check BASE=origin/main` and the TP-5 command (only these; CI runs the rest)
- tool: make:claude/workflow/Makefile:ci-job - on main; fallback: target missing or failing to parse: stop with DESIGN-GAP naming it
- tool: make:claude/workflow/Makefile:lint - on main; fallback: target missing: stop with DESIGN-GAP naming it
- tool: make:Makefile:rolodex-check - on main; fallback: target missing: stop with DESIGN-GAP naming it
- tool: path:claude/workflow/bin/step-time.sh - on main; fallback: missing or its flags changed: stop with DESIGN-GAP naming it, never inline a timer in YAML
- tool: path:/home/luna/.local/state/zenith/context/2026/10/20261016-071924-ci-shards-c1.json - artifact store, the verbatim config; fallback: missing: stop with DESIGN-GAP naming it, never re-derive the shard map
- tool: action:actions/cache@55cc8345863c7cc4c66a329aec7e433d2d1c52a9 (v6.1.0, already pinned in claude/workflow/pr-flow/templates/ci.yml) - fallback: cache miss or cache service down: the image step builds with make image, the job still runs, only slower
- tool: action:actions/upload-artifact@043fb46d1a93c77aae656e7c1c64a875d1fc6a0a (v7.0.1, released 2026-04-10) - fallback: upload fails: the timing lines stay in the job log on stderr from step-time.sh; continue-on-error: true on that step
- tool: cmd:podman, cmd:jq, cmd:git - fallback: missing on the host: stop with ENV-MISSING naming it; missing on the runner: require-podman.sh already fails the job loudly

**Out - non-goals**

- claude/workflow/Makefile and claude/workflow/inbox-sweep/Makefile: WO-20261016-599f and WO-20261016-e271 hold claude/workflow/Makefile; the shards call existing targets with make -o image instead
- importing the step-time artifacts to the bus: the C1b ticket cut with this one
- work-orders/INDEX.md, the ticket file or the parent README by hand: work-order.sh writes them; their close-out diff is allowed
- waiting on CI or merging: push, open the PR, write the result, leave (ORD-0542 O2)
- any file not named under In: stop with DESIGN-GAP and hand it back to infra-design (ORD-0548, item 30)

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [ ] `AC-H1` *(human)* `make -C claude/workflow ci-job` exits 0 and its output matches /ok ci-job/ with no line matching /^FAIL/ (proof: command, exit code and output pasted by work-order.sh evidence)
- [ ] `AC-H2` *(human)* `make -C claude/workflow lint` exits 0 (proof: command, exit code and output pasted by work-order.sh evidence)
- [ ] `AC-H3` *(human)* `make rolodex-check BASE=origin/main` exits 0 (proof: command, exit code and output pasted by work-order.sh evidence)
- [ ] `AC-H4` *(human)* `printf 'claude/workflow/bin/step-time.sh\n' | bash claude/workflow/tools/ci-select.sh` exits 0 and prints exactly 'workflow=true' then 'shards=["lint","herdr-first","step-time"]' (proof: command, exit code and output pasted by work-order.sh evidence)
- [ ] `AC-H5` *(human)* TP-5 command prints 0 (proof: command and output pasted by work-order.sh evidence)
- [ ] `AC-H6` *(human)* `git diff --name-only origin/main...HEAD | grep -vE '^(work-orders/|claude/workflow/(config/ci-shards.json|tools/ci-select.sh|tools/ci-time-pub.sh|tests/unit/test_ci_job.sh)|\.github/workflows/(workflow-suite|skill-pr-gate)\.yml)$'` exits 1 and prints nothing: only In files plus generated work-orders/ close-out files

## Test plan

_Test plan from claude/workflow/templates/test-plan.md, shaped by claude/workflow/schemas/test-plan.schema.json. The tester runs exactly these cases and nothing else._

**Scope under test**

claude/workflow CI: ci-select.sh shard selection, ci-shards.json, workflow-suite.yml matrix, skill-pr-gate.yml wiring, ci-time-pub.sh

**Cases**

- `TP-1`
  - intent: a PR that touches one suite must run only that suite's shard, or CI stays slow (item 1, item 6)
  - command: `make -C claude/workflow ci-job`
  - expected: exit 0; prints `ok  ci-job`; the selector cases for step-time-only, lint-only, inbox-sweep-only, docs-only, Makefile (all shards), unmatched claude/workflow path (all shards) and --full all hold
- `TP-2`
  - intent: the gate and the reusable workflow keep running the suite on pinned actions with cache, timing, timeout and cancel (PR 99 gap, Rule 15)
  - command: `make -C claude/workflow ci-job`
  - expected: exit 0; no `FAIL:` line; the python block asserts workflow-suite.yml triggers (workflow_call, push main, schedule), concurrency cancel-in-progress, timeout-minutes, step-time call, actions/cache and upload-artifact pinned
- `TP-3`
  - intent: a timing record that cannot reach the bus from a GitHub runner must still be written, never fail the step (item 37, item 28 fallback)
  - command: `make -C claude/workflow ci-job`
  - expected: exit 0; the ci-time-pub.sh case appends one JSON line with subject and payload to CI_TIME_FILE and exits 0
- `TP-4`
  - intent: new and changed scripts stay shellcheck clean
  - command: `make -C claude/workflow lint`
  - expected: exit 0
- `TP-5`
  - intent: the image cache only pays off if a shard never rebuilds the image it loaded
  - command: `podman run --rm --network=none -v "$PWD:/w:ro,Z" -w /w localhost/dotfiles-workflow-test:1 bash -c 'make -n -o image -C claude/workflow step-time; make -n -o image -C claude/workflow/inbox-sweep test-all' | grep -c 'podman build'`
  - expected: prints 0 (grep exit 1)

**Isolation**

- runtime: podman
- image: `docker.io/library/debian:bookworm-slim@sha256:3783cc01769c7b2b1b83a5c5ad96c815348e28ed7da68e2e3687004faa906251` (debian:bookworm-slim, base of localhost/dotfiles-workflow-test:1)

**Out of scope - CI covers**

- UAT gate (merge train, not the build seat): this PR's own skill PR gate run shows one `claude/workflow / <shard>` job per selected shard, each concluded success, wall clock of the workflow job group under 180 s; proof `gh run view <id> --json jobs`
- stable gate: first push run of `workflow suite` on main runs every shard green; rollback is `git revert` of the squash commit by the merge script
- the full claude/workflow suite: CI runs it

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
