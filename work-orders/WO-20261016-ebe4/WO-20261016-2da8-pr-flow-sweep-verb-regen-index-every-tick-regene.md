---
{
  "id": "WO-20261016-2da8",
  "slug": "pr-flow-sweep-verb-regen-index-every-tick-regene",
  "title": "pr-flow sweep verb regen-index: every tick regenerates index-only conflicts through regen-conflicts.sh, posts REGEN, make pr-regen-index",
  "type": "feature",
  "status": "ready",
  "priority": "p0",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T07:33:12+00:00",
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
  "depends_on": [],
  "blocks": [
    "WO-20261016-5082"
  ]
}
---

# WO-20261016-2da8 - pr-flow sweep verb regen-index: every tick regenerates index-only conflicts through regen-conflicts.sh, posts REGEN, make pr-regen-index

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

ORD-0726 S1 (orchestrator brief BR-20261016-infra-design4): "merge loop (pr-flow sweep, PR #191) gains two verbs: rerun-stale-red (...) and regen-index (port of ~/.local/share/zenith-architect/regen-merge.sh as make pr-regen-index, fallback until WO-20261016-565d lands). Both run on every sweep tick, coded RERUN and REGEN on the bus." Owner, Design principles 101 item 21: "get this code merged the fuck in, dead code is shit"; item 26: mechanical events are consumed by a script on the bus; item 30: "a need is met by adding a verb or a config entry to an existing tool and its Make target first". Inventory 2026-10-16T07:35Z: PR #191 (WO-20261016-83fb - pr-flow consumer, sweep, config, Make targets and worker playbook (T6)) already ports regen-merge.sh as claude/workflow/pr-flow/bin/regen-conflicts.sh (merge base, regenerate PR_FLOW_REGEN_PATHS with PR_FLOW_REGEN_CMD, push with the seat's gh login, report real-conflict otherwise), and repo_pass in pr-flow-consume.sh already calls it with --all on every tick, but its result reaches only stdout: nothing is posted on the bus, so no consumer sees a regen, and there is no pr-regen-index target (only pr-flow-regen). regen-merge.sh (22 lines, architect break glass) differs only in hard-coding work-orders/INDEX.md, */README.md and zwo reindex; regen-conflicts.sh reads both from pr-flow.json regen.paths and regen.cmd, so no new script is built. WO-20261016-565d - work-order skill: INDEX.md and epic READMEs become untracked build outputs, regenerated on demand (status ready) removes the cause; after it lands regen.paths for jkkelley/dotfiles becomes empty and this verb is a no-op by config, no code change. Record schema on PR #191 today: kinds pr.opened ci.passed ci.failed merged already-merged held merge.conflict blocked verified rejected; codes 100 201 422 200 0 3 409 423.

## Scope

**In**

- touches: claude/workflow/pr-flow/bin/pr-flow-consume.sh
- touches: claude/workflow/pr-flow/pr-flow.mk
- touches: claude/workflow/pr-flow/schemas/pr-flow-record.schema.json
- touches: claude/workflow/pr-flow/tests/regen-index.test.sh (new)
- touches: claude/workflow/pr-flow/tests/records.test.sh
- touches: claude/workflow/docs/pr-process/pr-process.md
- touches: claude/workflow/docs/pr-process/pr-process.spec.xml
- touches (generated, written only by work-order.sh start/submit/done, never by hand): work-orders/INDEX.md, this ticket file and its archive path, work-orders/WO-20261016-ebe4/README.md
- step: start only after PR #191 (WO-20261016-83fb) is merged: `gh pr view 191 -R jkkelley/dotfiles --json state -q .state` prints MERGED, else stop with DESIGN-GAP naming PR #191. No depends_on edge is recorded on purpose: an edge writes blocks into the 83fb ticket file, which PR #191 moves to archive, and that modify/rename conflict is outside regen.paths and would stall #191. Branch from origin/main
- step: pr-flow-record.schema.json: append "regen" to properties.kind.enum and "REGEN" to properties.code.enum; nothing else
- step: pr-flow-consume.sh: move the regen block at the top of repo_pass into a new function regen_index SLUG (same guard: regen.paths not empty and clone is a git checkout). It runs regen-conflicts.sh --repo CLONE --all exactly as today (--pr $PR instead when env PR is set, plus --dry-run when env DRY=1). For each output line matching '^PR ([0-9]+) regenerated: (.*)$' it reads the PR once with `$GH pr view N -R SLUG --json headRefOid,title,body`, TICKET = ticket_of over title and body, and calls post SLUG LINE regen REGEN "REGEN/SLUG/N/HEAD" N HEAD TICKET "regenerated: <paths>" unless records.sh seen has that key. Each line matching ' real-conflict: ' is echoed prefixed with SLUG and posts nothing (merge.sh owns 409). Lines matching ' clean: ' stay suppressed as today. regen_index always returns 0. repo_pass calls regen_index SLUG where the block was
- step: pr-flow-consume.sh: new verb regen-index in the case statement: for each slug in REPO or pr-flow-config.sh --list, regen_index SLUG. Update the header usage lines (the *) branch's sed -n range must still print the usage) and the Records list with: regen REGEN a PR conflicting only on regen.paths was merged with its base, regenerated and pushed key REGEN/<slug>/<pr>/<new head>. Add a BREADCRUMB 2026-10-16 - BR-20261016-infra-design4, ORD-0726 S1 comment: what broke (regen results never reached the bus, finding F20), why a verb on the sweep (item 30; regen-conflicts.sh is the regen-merge.sh port), rejected (a second script copied from regen-merge.sh), cost (one gh pr view per regenerated PR), and that WO-20261016-565d makes it a no-op by emptying regen.paths
- step: pr-flow.mk: add pr-regen-index to .PHONY and the target `pr-regen-index: ## make pr-regen-index REPO=owner/name [PR=N] [DRY=1]: the sweep's regen-index verb for one repository, posts REGEN` with recipe line 1 `@test -n "$(REPO)" || { echo "pr-regen-index needs REPO="; exit 2; }` and line 2 `@$(PF_TIME) --node regen-index --budget 60 --timeout 240 --retries 1 -- env REPO=$(REPO) PR=$(PR) DRY=$(DRY) $(PF)/pr-flow-consume.sh regen-index`. Keep pr-flow-regen unchanged. Add regen-index to the default CASES list of pr-flow-test after consume
- step: tests/regen-index.test.sh (new; rolodex header keys name/purpose/inputs/outputs/writes-to/cleanup; built on the consume.test.sh pattern: mktemp W, fake gh, stub publisher PR_FLOW_PUB, copied pf/bin with regen-conflicts.sh replaced by a stub that cats $W/regen.out): cases TP-1 and TP-2 of the test plan; last line `pass=N fail=M` like the other cases
- step: tests/records.test.sh: add two cases: post --kind regen --code REGEN exits 0; post --kind regen --code NOPE exits 3
- step: pr-process.md section 9: add row `| REGEN | \`regen\` | PR conflicting only on generated files merged with its base, regenerated, pushed; once per new head | nobody; CI runs on the new head |` after the 409 row; section 10 add one sentence: an empty regen.paths turns the regen-index verb off. pr-process.spec.xml <codes>: add `<code value="REGEN" kind="regen" acts="none; CI runs on the new head"/>` after the SLOW line; the spec stays under 1000 lines and parses
- step: run only TP-1..TP-6 and `make rolodex-check BASE=origin/main`; CI runs the rest
- tool: path:claude/workflow/pr-flow/bin/regen-conflicts.sh - lands with PR #191; fallback: missing on main: stop with DESIGN-GAP naming PR #191; architect break glass meanwhile: ~/.local/share/zenith-architect/regen-merge.sh <repo-dir> <branch>...
- tool: path:claude/workflow/pr-flow/bin/records.sh - lands with PR #191; fallback: bus down: records.sh's own dir backend (records: dir in pr-flow.json, item 28 file queue), no code change
- tool: make:claude/workflow/Makefile:pr-flow-test and pr-flow-lint - land with PR #191; fallback: missing: stop with DESIGN-GAP naming it
- tool: path:claude/workflow/bin/step-time.sh - on main; fallback: missing: stop with DESIGN-GAP, never an untimed target
- tool: make:Makefile:rolodex-check - on main; fallback: missing: stop with DESIGN-GAP naming it
- tool: cmd:gh, cmd:jq, cmd:git, cmd:podman - fallback: missing on the host: stop with ENV-MISSING naming it

**Out - non-goals**

- a new regen script or a copy of regen-merge.sh: regen-conflicts.sh is the port
- regen-conflicts.sh and pr-flow.json: unchanged; WO-20261016-565d owns removing the generated files
- rerun-stale-red: the sibling ticket cut alongside, which depends on this one because it touches the same files (item 19)
- work-orders/INDEX.md, the ticket file or the parent README by hand: work-order.sh writes them; their close-out diff is allowed
- waiting on CI or merging: push, open the PR, write the result, leave (ORD-0542 O2)
- any file not named under In: stop with DESIGN-GAP and hand it back to infra-design (ORD-0548, item 30)

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [ ] `AC-H1` *(human)* `make -C claude/workflow pr-flow-test CASES="regen-index consume records"` exits 0 and prints ok for all three, no line matching /^FAIL/ (proof: command, exit code and output pasted by work-order.sh evidence)
- [ ] `AC-H2` *(human)* `make -C claude/workflow pr-flow-lint` exits 0 (proof: command, exit code and output pasted by work-order.sh evidence)
- [ ] `AC-H3` *(human)* `make -C claude/workflow pr-regen-index; echo rc=$?` prints 'pr-regen-index needs REPO=' and 'rc=2' (proof: output pasted by work-order.sh evidence)
- [ ] `AC-H4` *(human)* `python3 -c 'import xml.dom.minidom,sys; xml.dom.minidom.parse(sys.argv[1])' claude/workflow/docs/pr-process/pr-process.spec.xml && grep -c 'value="REGEN"' claude/workflow/docs/pr-process/pr-process.spec.xml` exits 0 and prints 1 (proof: output pasted by work-order.sh evidence)
- [ ] `AC-H5` *(human)* `make rolodex-check BASE=origin/main` exits 0 (proof: command, exit code and output pasted by work-order.sh evidence)
- [ ] `AC-H6` *(human)* `git diff --name-only origin/main...HEAD | grep -vE '^(work-orders/|claude/workflow/(pr-flow/(bin/pr-flow-consume.sh|pr-flow.mk|schemas/pr-flow-record.schema.json|tests/(regen-index|records).test.sh)|docs/pr-process/pr-process.(md|spec.xml)))$'` exits 1 and prints nothing: only In files plus generated work-orders/ close-out files

## Test plan

_Test plan from claude/workflow/templates/test-plan.md, shaped by claude/workflow/schemas/test-plan.schema.json. The tester runs exactly these cases and nothing else._

**Scope under test**

pr-flow-consume.sh verb regen-index, its call from every sweep tick, the REGEN record, and the Make target pr-regen-index

**Cases**

- `TP-1`
  - intent: a PR conflicting only on generated work-order indexes gets no CI and never merges; every sweep tick must regenerate it and say so on the bus, or the line stalls (orchestrator finding F20, dotfiles 159, 161, 162, 180, 187)
  - command: `make -C claude/workflow pr-flow-test CASES="regen-index"`
  - expected: exit 0; prints `ok  regen-index`; the case asserts a stubbed regen-conflicts.sh line `PR 7 regenerated: work-orders/INDEX.md` yields exactly one pub.log line `line.test.event.regen` carrying code REGEN and key REGEN/o/r/7/<head>, and a second tick on the same head posts nothing
- `TP-2`
  - intent: a real conflict must not be reported as REGEN, or a worker is told the PR is fixed when it is not
  - command: `make -C claude/workflow pr-flow-test CASES="regen-index"`
  - expected: exit 0; the case asserts a stubbed line `PR 8 real-conflict: x.sh` posts no regen record and prints `o/r PR 8 real-conflict` on stdout
- `TP-3`
  - intent: the sweep keeps its existing records once per head after the verb is factored out
  - command: `make -C claude/workflow pr-flow-test CASES="consume records"`
  - expected: exit 0; prints `ok  consume` and `ok  records`
- `TP-4`
  - intent: the record schema accepts the new kind and code and still refuses unknown ones
  - command: `make -C claude/workflow pr-flow-test CASES="records"`
  - expected: exit 0; the added case posts kind regen code REGEN with exit 0 and kind regen code NOPE with exit 3
- `TP-5`
  - intent: the Make target passes its inputs as VAR=value and refuses without REPO (item 17)
  - command: `make -C claude/workflow pr-regen-index; echo rc=$?`
  - expected: prints `pr-regen-index needs REPO=` and `rc=2`
- `TP-6`
  - intent: scripts stay shellcheck clean
  - command: `make -C claude/workflow pr-flow-lint`
  - expected: exit 0

**Isolation**

- runtime: podman
- image: `docker.io/library/debian:bookworm-slim@sha256:3783cc01769c7b2b1b83a5c5ad96c815348e28ed7da68e2e3687004faa906251` (debian:bookworm-slim, base of localhost/dotfiles-workflow-test:1)

**Out of scope - CI covers**

- UAT gate (merge train): next real index conflict on dotfiles is regenerated within one sweep interval and line.pr-flow.event.regen shows its REGEN record; proof `nats-box` stream read of line.pr-flow.event.regen
- stable gate: the pr-flow pane runs the sweep with the verb for 24 h; rollback is `git revert` of the squash commit by the merge script
- the full claude/workflow suite: CI runs it

## Assumptions

1. PR #191 merges before this ticket starts; its layout (bin/, schemas/, tests/, pr-flow.mk) is as on origin/feat/pr-flow-t6-sweep at 2026-10-16T07:35Z
1. fallback when the verb fails on a tick: the tick continues (regen_index returns 0), the PR stays CONFLICTING and visible in gh, and the architect's break glass regen-merge.sh still works

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
