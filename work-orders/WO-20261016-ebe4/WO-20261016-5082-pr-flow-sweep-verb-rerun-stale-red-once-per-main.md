---
{
  "id": "WO-20261016-5082",
  "slug": "pr-flow-sweep-verb-rerun-stale-red-once-per-main",
  "title": "pr-flow sweep verb rerun-stale-red: once per main sha, refresh open PRs whose red run predates main, post RERUN, make pr-rerun-stale-red",
  "type": "feature",
  "status": "ready",
  "priority": "p0",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T07:33:17+00:00",
  "parent": "WO-20261016-ebe4",
  "branch": null,
  "pr": null,
  "closed": null,
  "approval": {
    "via": "override",
    "reason": "infra-design4 cut for ORD-0726 S1; design approvals ruled done, ORD-0550 O4",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [
    "WO-20261016-2da8"
  ],
  "blocks": []
}
---

# WO-20261016-5082 - pr-flow sweep verb rerun-stale-red: once per main sha, refresh open PRs whose red run predates main, post RERUN, make pr-rerun-stale-red

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

ORD-0726 S1 (orchestrator brief BR-20261016-infra-design4): "rerun-stale-red (when main gets a new commit, rerun failed jobs of open PRs whose failing run predates that commit, once per main sha) ... Both run on every sweep tick, coded RERUN and REGEN on the bus." Evidence in the brief: "07:23Z cycle: PRs 207 and 210 MERGEABLE but red on claude/workflow from a run predating #208 (1dd0b32); orchestrator finding F20". Owner, Design principles 101 item 21: "get this code merged the fuck in, dead code is shit, it sitting under agents is stupid"; item 22: "see a bug, isolate it, and get it fixed as asap"; item 30: add a verb to the existing tool. Today the sweep (pr-flow-consume.sh repo_pass on PR #191, WO-20261016-83fb - pr-flow consumer, sweep, config, Make targets and worker playbook (T6)) posts ci.failed 422 once per head and then never looks at that PR again until its head moves, so a red caused by main being broken at run time stays red after main is fixed. Mechanism fact the design rests on: GitHub docs, Re-running workflows and jobs (https://docs.github.com/en/actions/managing-workflow-runs-and-deployments/managing-workflow-runs/re-running-workflows-and-jobs): "Re-running a workflow or jobs in a workflow uses the same GITHUB_SHA (commit SHA) and GITHUB_REF (Git ref) of the original event that triggered the workflow run." Every dotfiles PR workflow runs on pull_request and checks out the default ref (.github/workflows/skill-pr-gate.yml lines 55-56, 77-79: actions/checkout with no ref, i.e. the refs/pull/N/merge commit fixed at event time, and BASE = github.event.pull_request.base.sha from the same payload), so `gh run rerun --failed` re-tests the old merge commit, which still lacks the fix on main. A fresh merge ref needs a new pull_request event: `gh pr update-branch` merges the base into the head through the API with the seat's own gh login, whose push starts workflows (the same identity reason regen-conflicts.sh's breadcrumb records). So the default mode is update-branch; mode rerun is kept, by config, for a repository whose red is a flake rather than a stale base; the verb name stays as ordered.

## Scope

**In**

- touches: claude/workflow/pr-flow/bin/pr-flow-consume.sh
- touches: claude/workflow/pr-flow/pr-flow.mk
- touches: claude/workflow/pr-flow/config/pr-flow.json
- touches: claude/workflow/pr-flow/schemas/pr-flow-record.schema.json
- touches: claude/workflow/pr-flow/tests/rerun-stale-red.test.sh (new)
- touches: claude/workflow/pr-flow/tests/records.test.sh
- touches: claude/workflow/docs/pr-process/pr-process.md
- touches: claude/workflow/docs/pr-process/pr-process.spec.xml
- touches (generated, written only by work-order.sh start/submit/done, never by hand): work-orders/INDEX.md, this ticket file and its archive path, work-orders/WO-20261016-ebe4/README.md
- step: start only after WO-20261016-2da8 is done and merged (work-order.sh next lists this ticket only then); branch from origin/main
- step: pr-flow-record.schema.json: append "ci.rerun" to properties.kind.enum and "RERUN" to properties.code.enum; nothing else
- step: pr-flow.json defaults: add "stale_red": {"mode": "update-branch"} with the $comment extended by one clause: stale_red.mode is update-branch (merge base into head, new pull_request event, fresh merge ref), rerun (gh run rerun --failed, same merge ref, for flakes) or off. No per-repo override is added
- step: pr-flow-consume.sh: open-PR list adds baseRefName to its --json fields; the check-runs --jq adds st: (.started_at // "") to each object. New function stale_red_pr SLUG LINE N HEAD BASE TICKET CHECKS MODE: return 0 at once if MODE is empty, null or off. MAIN=$($GH api repos/SLUG/commits/BASE --jq '.sha + " " + .commit.committer.date') read once per BASE per pass (cache in an associative array); return 0 if MAIN's sha is empty. RED_AT = max .st over the failing checks (same selection as failed). Return 0 unless RED_AT < MAIN date (string compare of ISO-8601 UTC). Key RERUN/SLUG/N/MAINSHA: return 0 if records.sh seen has it. Mode update-branch: `$GH pr update-branch N -R SLUG`; on non-zero, fallback `$GH api -X PUT repos/SLUG/pulls/N/update-branch -f expected_head_sha=HEAD`. Mode rerun: ID=$($GH run list -R SLUG --commit HEAD --status failure --json databaseId --jq '.[0].databaseId'), then `$GH run rerun ID -R SLUG --failed`. On success post SLUG LINE ci.rerun RERUN KEY N HEAD TICKET "red at RED_AT predates BASE MAINSHA12 at MAINDATE; mode MODE" and echo "SLUG PR N rerun: MODE". When every call failed echo "SLUG PR N stale-red-fail: MODE" and post nothing (the 422 already posted stands for the worker). Always return 0
- step: pr-flow-consume.sh repo_pass: in the failed branch, after the 422 post line and before continue, call stale_red_pr with the PR's baseRefName and MODE=$(jq -r '.stale_red.mode // "off"' <<<"$cfg"). New verb rerun-stale-red in the case statement: for each slug in REPO or pr-flow-config.sh --list, list open PRs and their check-runs exactly as repo_pass does and call stale_red_pr for each PR with a failing check; DRY=1 prints the would-be call ("SLUG PR N would-rerun: MODE") and posts nothing. Update the header usage lines (the *) branch's sed -n range must still print usage) and the Records list: ci.rerun RERUN a red whose failing checks started before the base head was refreshed key RERUN/<slug>/<pr>/<base sha>. Add a BREADCRUMB 2026-10-16 - BR-20261016-infra-design4, ORD-0726 S1 comment: what broke (PRs 207 and 210 red from a run before #208, F20), why update-branch and not rerun (the GitHub docs sentence above, quoted), rejected (gh run rerun as default; closing and reopening the PR, which notifies), cost (a merge commit on the PR branch, as regen-conflicts.sh already makes, and one gh api call per base per pass)
- step: pr-flow.mk: add pr-rerun-stale-red to .PHONY and the target `pr-rerun-stale-red: ## make pr-rerun-stale-red REPO=owner/name [DRY=1]: the sweep's rerun-stale-red verb for one repository, posts RERUN` with recipe line 1 `@test -n "$(REPO)" || { echo "pr-rerun-stale-red needs REPO="; exit 2; }` and line 2 `@$(PF_TIME) --node rerun-stale-red --budget 60 --timeout 240 --retries 1 -- env REPO=$(REPO) DRY=$(DRY) $(PF)/pr-flow-consume.sh rerun-stale-red`. Add rerun-stale-red to the default CASES list of pr-flow-test after regen-index
- step: tests/rerun-stale-red.test.sh (new; rolodex header keys name/purpose/inputs/outputs/writes-to/cleanup; consume.test.sh pattern: mktemp W, fake gh that logs every call and answers pr list, check-runs with started_at, commits/main, pr update-branch, api -X PUT, run list, run rerun from fixture files, failing a verb when $W/fail.<verb> exists; stub publisher PR_FLOW_PUB; cfg.json with stale_red.mode set per case): cases TP-1 to TP-4 of the test plan; last line `pass=N fail=M`. consume.test.sh is not edited: its cfg has no stale_red, so mode is off and its fake gh is never asked for commits/main
- step: tests/records.test.sh: add two cases: post --kind ci.rerun --code RERUN exits 0; post --kind ci.rerun --code NOPE exits 3
- step: pr-process.md section 9: add row `| RERUN | \`ci.rerun\` | a red whose failing checks started before the base head; base merged into head (or failed jobs rerun); once per base sha | nobody; CI runs on the new head |` after the REGEN row; section 10 add one sentence on stale_red.mode (update-branch, rerun, off). pr-process.spec.xml <codes>: add `<code value="RERUN" kind="ci.rerun" acts="none; CI runs on the new head"/>` after the REGEN line; the spec stays under 1000 lines and parses
- step: run only TP-1..TP-7 and `make rolodex-check BASE=origin/main`; CI runs the rest
- tool: cmd:gh pr update-branch - gh 2.92.0 on the host (added in gh 2.42); fallback: refused or absent: REST PUT repos/O/N/pulls/N/update-branch (coded in the step); both refused: stale-red-fail, the 422 record stands for the worker
- tool: path:claude/workflow/pr-flow/bin/pr-flow-consume.sh regen-index verb - lands with WO-20261016-2da8; fallback: missing on main: stop with DESIGN-GAP naming WO-20261016-2da8
- tool: path:claude/workflow/pr-flow/bin/records.sh - lands with PR #191; fallback: bus down: records.sh's own dir backend (records: dir in pr-flow.json, item 28 file queue), no code change
- tool: make:claude/workflow/Makefile:pr-flow-test and pr-flow-lint - land with PR #191; fallback: missing: stop with DESIGN-GAP naming it
- tool: path:claude/workflow/bin/step-time.sh - on main; fallback: missing: stop with DESIGN-GAP, never an untimed target
- tool: make:Makefile:rolodex-check - on main; fallback: missing: stop with DESIGN-GAP naming it
- tool: cmd:gh, cmd:jq, cmd:git, cmd:podman - fallback: missing on the host: stop with ENV-MISSING naming it

**Out - non-goals**

- changing any GitHub workflow file or merge-on-green: the refresh happens from the sweep with the seat's gh login
- rerunning a red whose failing checks started after the base head: that is a real failure, the 422 worker lane owns it
- consume.test.sh, regen-conflicts.sh, merge.sh, gate.sh: unchanged
- work-orders/INDEX.md, the ticket file or the parent README by hand: work-order.sh writes them; their close-out diff is allowed
- waiting on CI or merging: push, open the PR, write the result, leave (ORD-0542 O2)
- any file not named under In: stop with DESIGN-GAP and hand it back to infra-design (ORD-0548, item 30)

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [ ] `AC-H1` *(human)* `make -C claude/workflow pr-flow-test CASES="rerun-stale-red regen-index consume records"` exits 0 and prints ok for all four, no line matching /^FAIL/ (proof: command, exit code and output pasted by work-order.sh evidence)
- [ ] `AC-H2` *(human)* `make -C claude/workflow pr-flow-lint` exits 0 (proof: command, exit code and output pasted by work-order.sh evidence)
- [ ] `AC-H3` *(human)* `make -C claude/workflow pr-rerun-stale-red; echo rc=$?` prints 'pr-rerun-stale-red needs REPO=' and 'rc=2' (proof: output pasted by work-order.sh evidence)
- [ ] `AC-H4` *(human)* `jq -r .defaults.stale_red.mode claude/workflow/pr-flow/config/pr-flow.json` prints update-branch (proof: output pasted by work-order.sh evidence)
- [ ] `AC-H5` *(human)* `python3 -c 'import xml.dom.minidom,sys; xml.dom.minidom.parse(sys.argv[1])' claude/workflow/docs/pr-process/pr-process.spec.xml && grep -c 'value="RERUN"' claude/workflow/docs/pr-process/pr-process.spec.xml` exits 0 and prints 1 (proof: output pasted by work-order.sh evidence)
- [ ] `AC-H6` *(human)* `make rolodex-check BASE=origin/main` exits 0 (proof: command, exit code and output pasted by work-order.sh evidence)
- [ ] `AC-H7` *(human)* `git diff --name-only origin/main...HEAD | grep -vE '^(work-orders/|claude/workflow/(pr-flow/(bin/pr-flow-consume.sh|pr-flow.mk|config/pr-flow.json|schemas/pr-flow-record.schema.json|tests/(rerun-stale-red|records).test.sh)|docs/pr-process/pr-process.(md|spec.xml)))$'` exits 1 and prints nothing: only In files plus generated work-orders/ close-out files

## Test plan

_Test plan from claude/workflow/templates/test-plan.md, shaped by claude/workflow/schemas/test-plan.schema.json. The tester runs exactly these cases and nothing else._

**Scope under test**

pr-flow-consume.sh verb rerun-stale-red, its call from every sweep tick, the RERUN record, config key stale_red, and the Make target pr-rerun-stale-red

**Cases**

- `TP-1`
  - intent: a PR red only because its failing run predates a fix on main sits red forever and never merges (07:23Z cycle: PRs 207 and 210 red on claude/workflow from a run before #208, 1dd0b32)
  - command: `make -C claude/workflow pr-flow-test CASES="rerun-stale-red"`
  - expected: exit 0; prints `ok  rerun-stale-red`; with main head M committed after the failing check started, fake gh logs exactly one `pr update-branch 1 -R o/r` call and pub.log holds exactly one `line.test.event.ci.rerun` line with code RERUN and key RERUN/o/r/1/M
- `TP-2`
  - intent: once per main sha, or the sweep churns CI on every tick (item 1)
  - command: `make -C claude/workflow pr-flow-test CASES="rerun-stale-red"`
  - expected: exit 0; a second tick with the same main head M adds no update-branch call and no record; a tick after main moves to M2 adds exactly one of each
- `TP-3`
  - intent: a red that is newer than main is a real failure for the worker, never refreshed
  - command: `make -C claude/workflow pr-flow-test CASES="rerun-stale-red"`
  - expected: exit 0; a PR whose failing check started after M gets no update-branch call and no RERUN record, and its ci.failed 422 record is still posted
- `TP-4`
  - intent: the fallbacks are coded: update-branch refused falls to the REST call, mode rerun calls gh run rerun --failed, both failing leaves the 422 for the worker
  - command: `make -C claude/workflow pr-flow-test CASES="rerun-stale-red"`
  - expected: exit 0; fake gh failing `pr update-branch` logs one `api -X PUT repos/o/r/pulls/1/update-branch` call; config stale_red.mode rerun logs one `run rerun <id> --failed`; both refusals print `o/r PR 1 stale-red-fail` and post no RERUN record
- `TP-5`
  - intent: the existing sweep, regen-index and record schema cases still hold
  - command: `make -C claude/workflow pr-flow-test CASES="consume regen-index records"`
  - expected: exit 0
- `TP-6`
  - intent: the Make target refuses without REPO (item 17)
  - command: `make -C claude/workflow pr-rerun-stale-red; echo rc=$?`
  - expected: prints `pr-rerun-stale-red needs REPO=` and `rc=2`
- `TP-7`
  - intent: scripts stay shellcheck clean
  - command: `make -C claude/workflow pr-flow-lint`
  - expected: exit 0

**Isolation**

- runtime: podman
- image: `docker.io/library/debian:bookworm-slim@sha256:3783cc01769c7b2b1b83a5c5ad96c815348e28ed7da68e2e3687004faa906251` (debian:bookworm-slim, base of localhost/dotfiles-workflow-test:1)

**Out of scope - CI covers**

- UAT gate (merge train): the next merge to dotfiles main refreshes every open PR whose red predates it within one sweep interval, a fresh CI run starts on each new head, and line.pr-flow.event.ci.rerun shows one RERUN record per PR; proof `gh run list --branch <b> --json createdAt,headSha` and the stream read
- stable gate: the pr-flow pane runs the sweep with the verb for 24 h; rollback is `git revert` of the squash commit, or config stale_red.mode off with no code change
- the full claude/workflow suite: CI runs it

## Assumptions

1. the brief says rerun failed jobs; per the GitHub docs sentence in Problem a rerun reuses the old merge ref and cannot pick up a fix on main, so update-branch is the default and rerun stays a config mode; the owner flips it with one config line (stale_red.mode), no code change
1. fallback for the whole verb: stale_red.mode off in pr-flow.json disables it with no code change; the 422 worker lane is the path it falls back to

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
