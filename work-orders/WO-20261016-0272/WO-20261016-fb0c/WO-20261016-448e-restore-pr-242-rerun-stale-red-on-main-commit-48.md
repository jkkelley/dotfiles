---
{
  "id": "WO-20261016-448e",
  "slug": "restore-pr-242-rerun-stale-red-on-main-commit-48",
  "title": "Restore PR 242 rerun-stale-red on main: commit 4817abc of PR 240 reverted all nine of its files",
  "type": "bug",
  "status": "in-progress",
  "priority": "p0",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T08:49:30+00:00",
  "parent": "WO-20261016-fb0c",
  "branch": "feat/restore-pr-242-rerun-stale-red-on-main-commit-48",
  "pr": null,
  "closed": null,
  "approval": {
    "via": "override",
    "reason": "infra-design7 cut for ORD-0830 RR-orch-15 and ORD-0832 B1; design approvals ruled done, ORD-0550 O4",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [],
  "blocks": [
    "WO-20261016-39da",
    "WO-20261016-73f2"
  ],
  "ac_checks": [
    {
      "index": 1,
      "command": "git diff --quiet d478078 HEAD -- claude/workflow/docs/pr-process/pr-process.md claude/workflow/docs/pr-process/pr-process.spec.xml claude/workflow/pr-flow/bin/pr-flow-consume.sh claude/workflow/pr-flow/config/pr-flow.json claude/workflow/pr-flow/pr-flow.mk claude/workflow/pr-flow/schemas/pr-flow-record.schema.json claude/workflow/pr-flow/tests/records.test.sh claude/workflow/pr-flow/tests/rerun-stale-red.test.sh work-orders/archive/2026/WO-20261016-5082-pr-flow-sweep-verb-rerun-stale-red-once-per-main.md",
      "exit": 0,
      "expect": null
    },
    {
      "index": 2,
      "command": "grep -c stale_red_pr claude/workflow/pr-flow/bin/pr-flow-consume.sh",
      "exit": 0,
      "expect": "^[1-9]"
    },
    {
      "index": 3,
      "command": "make -C claude/workflow pr-flow-test CASES=\"rerun-stale-red records consume\"",
      "exit": 0,
      "expect": "ok  rerun-stale-red"
    },
    {
      "index": 4,
      "command": "make -C claude/workflow pr-flow-lint",
      "exit": 0,
      "expect": null
    },
    {
      "index": 5,
      "command": "bash -c \\!\\ git\\ diff\\ --name-only\\ origin/main...HEAD\\ \\|\\ grep\\ -vE\\ \\'\\^\\(work-orders/\\|claude/workflow/\\(pr-flow/\\(bin/pr-flow-consume\\\\.sh\\|pr-flow\\\\.mk\\|config/pr-flow\\\\.json\\|schemas/pr-flow-record\\\\.schema\\\\.json\\|tests/\\(records\\|rerun-stale-red\\)\\\\.test\\\\.sh\\)\\|docs/pr-process/pr-process\\\\.\\(md\\|spec\\\\.xml\\)\\)\\)\\$\\'",
      "exit": 0,
      "expect": null
    }
  ],
  "provides": []
}
---

# WO-20261016-448e - Restore PR 242 rerun-stale-red on main: commit 4817abc of PR 240 reverted all nine of its files

## Contents

- Problem
- Owner words
- Context
- Scope
- Degrees of freedom
- Acceptance criteria
- Test plan
- Assumptions
- Open questions
- Notes
- Outcome

## Problem

On main the pr-flow sweep verb rerun-stale-red, make pr-rerun-stale-red, the RERUN record code, its suite and the done stamp of WO-20261016-5082 are gone: PR 240 (f049a84, inbox-sweep V2) carries the exact inverse of PR 242 (d478078). WO-20261016-5082 reads ready again, so WO-20261016-fb99 and every ticket after it cannot start.

## Owner words

> see a bug, isolate it, and get it fixed as asap (Design principles 101 item 22)

> get this code merged the fuck in, dead code is shit (item 21)

## Context

Evidence 2026-10-16 08:40Z: git diff --stat d478078^ f049a84 over the nine files below is empty (f049a84 holds them exactly as before PR 242); grep -c stale_red claude/workflow/pr-flow/bin/pr-flow-consume.sh on origin/main c8bab6c prints 0; git log f049a84..origin/main over the nine files is empty, so nothing landed on them since.

Isolated: PR 240 commit f28ba24 merged origin/main (parent d478078) into its branch and carried PR 242 in; the next commit 4817abc 'chore(inbox-sweep): rolodex header on the v2 migration script' reverted the nine files (pr-flow-consume.sh -64 lines, rerun-stale-red.test.sh deleted). The restore is git checkout d478078 over exactly those nine files; nothing else on main moved them, so it is byte-exact.

Who it unblocks: WO-20261016-fb99 (infra-design6, autofix) depends on WO-20261016-5082; the RR-orch-15 sweep verb extends stale_red_pr and MAIN_OF from PR 242.

## Scope

**In**

- touches: claude/workflow/pr-flow/bin/pr-flow-consume.sh
- touches: claude/workflow/pr-flow/config/pr-flow.json
- touches: claude/workflow/pr-flow/pr-flow.mk
- touches: claude/workflow/pr-flow/schemas/pr-flow-record.schema.json
- touches: claude/workflow/pr-flow/tests/records.test.sh
- touches: claude/workflow/pr-flow/tests/rerun-stale-red.test.sh (restored)
- touches: claude/workflow/docs/pr-process/pr-process.md
- touches: claude/workflow/docs/pr-process/pr-process.spec.xml
- touches: work-orders/archive/2026/WO-20261016-5082-pr-flow-sweep-verb-rerun-stale-red-once-per-main.md (restored to its done stamp)
- touches (generated, written only by work-order.sh start/submit/done, never by hand): work-orders/INDEX.md, this ticket file and its archive path, the parent epic README.md
- step: branch from origin/main in your own worktree; run `git checkout d478078 -- claude/workflow/docs/pr-process/pr-process.md claude/workflow/docs/pr-process/pr-process.spec.xml claude/workflow/pr-flow/bin/pr-flow-consume.sh claude/workflow/pr-flow/config/pr-flow.json claude/workflow/pr-flow/pr-flow.mk claude/workflow/pr-flow/schemas/pr-flow-record.schema.json claude/workflow/pr-flow/tests/records.test.sh claude/workflow/pr-flow/tests/rerun-stale-red.test.sh work-orders/archive/2026/WO-20261016-5082-pr-flow-sweep-verb-rerun-stale-red-once-per-main.md` and change nothing else
- step: commit with message 'fix(workflow): restore pr-flow rerun-stale-red reverted by PR 240 commit 4817abc' and the ticket id; no Bump trailer (no file under claude/skills changes)
- step: run TP-1 to TP-3 of the test plan and the AC checks only; CI runs the rest
- tool: make:claude/workflow/Makefile:pr-flow-test and pr-flow-lint - on main; fallback: missing: stop with DESIGN-GAP naming it
- tool: cmd:git, cmd:jq, cmd:make, cmd:podman, cmd:gh - fallback: missing on the host: stop with ENV-MISSING naming it; gh or GitHub down: retry 3 times, then stop with A2A-003 and its output
- tool: make:Makefile:rolodex-check - on main; fallback: missing: stop with DESIGN-GAP naming it

**Out - non-goals**

- any edit to the restored content: it is restored byte-exact from d478078, a change is a new ticket
- PR 240's own inbox-sweep files: they are correct on main
- work-orders/INDEX.md and epic READMEs by hand or by git add: they are ignored generated views
- waiting on CI or merging: push, open the PR, write the result, leave (ORD-0542 O2)
- any file not named under In: stop with DESIGN-GAP and hand it back to infra-design (ORD-0548, item 30)

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [ ] `AC-H1` *(human)* the nine files equal PR 242's merge commit
  - check: `git diff --quiet d478078 HEAD -- claude/workflow/docs/pr-process/pr-process.md claude/workflow/docs/pr-process/pr-process.spec.xml claude/workflow/pr-flow/bin/pr-flow-consume.sh claude/workflow/pr-flow/config/pr-flow.json claude/workflow/pr-flow/pr-flow.mk claude/workflow/pr-flow/schemas/pr-flow-record.schema.json claude/workflow/pr-flow/tests/records.test.sh claude/workflow/pr-flow/tests/rerun-stale-red.test.sh work-orders/archive/2026/WO-20261016-5082-pr-flow-sweep-verb-rerun-stale-red-once-per-main.md` exit 0
- [ ] `AC-H2` *(human)* the stale-red verb is back in the sweep
  - check: `grep -c stale_red_pr claude/workflow/pr-flow/bin/pr-flow-consume.sh` exit 0 expect /^[1-9]/
- [ ] `AC-H3` *(human)* the restored suites pass
  - check: `make -C claude/workflow pr-flow-test CASES="rerun-stale-red records consume"` exit 0 expect /ok rerun-stale-red/
- [ ] `AC-H4` *(human)* pr-flow scripts stay shellcheck clean
  - check: `make -C claude/workflow pr-flow-lint` exit 0
- [ ] `AC-H5` *(human)* the diff holds only In files and generated work-orders files
  - check: `bash -c \!\ git\ diff\ --name-only\ origin/main...HEAD\ \|\ grep\ -vE\ \'\^\(work-orders/\|claude/workflow/\(pr-flow/\(bin/pr-flow-consume\\.sh\|pr-flow\\.mk\|config/pr-flow\\.json\|schemas/pr-flow-record\\.schema\\.json\|tests/\(records\|rerun-stale-red\)\\.test\\.sh\)\|docs/pr-process/pr-process\\.\(md\|spec\\.xml\)\)\)\$\'` exit 0

## Test plan

_Test plan from claude/workflow/templates/test-plan.md, shaped by claude/workflow/schemas/test-plan.schema.json. The tester runs exactly these cases and nothing else._

**Scope under test**

the nine files of PR 242 restored from d478078: pr-flow-consume.sh verb rerun-stale-red, make pr-rerun-stale-red, the RERUN record, both pr-process docs

**Cases**

- `TP-1`
  - intent: PR 240 (f049a84) silently reverted PR 242; the restore must be byte-exact so nothing of 242 is lost or reinvented (item 7 evidence: git diff --stat d478078^ f049a84 over the nine files is empty)
  - command: `git diff --quiet d478078 HEAD -- claude/workflow/docs/pr-process/pr-process.md claude/workflow/docs/pr-process/pr-process.spec.xml claude/workflow/pr-flow/bin/pr-flow-consume.sh claude/workflow/pr-flow/config/pr-flow.json claude/workflow/pr-flow/pr-flow.mk claude/workflow/pr-flow/schemas/pr-flow-record.schema.json claude/workflow/pr-flow/tests/records.test.sh claude/workflow/pr-flow/tests/rerun-stale-red.test.sh work-orders/archive/2026/WO-20261016-5082-pr-flow-sweep-verb-rerun-stale-red-once-per-main.md`
  - expected: exit 0
- `TP-2`
  - intent: the restored verb and the record kinds still pass their own suites
  - command: `make -C claude/workflow pr-flow-test CASES="rerun-stale-red records consume"`
  - expected: exit 0; prints `ok  rerun-stale-red`, `ok  records`, `ok  consume`
- `TP-3`
  - intent: scripts stay shellcheck clean
  - command: `make -C claude/workflow pr-flow-lint`
  - expected: exit 0

**Isolation**

- runtime: podman
- image: `docker.io/library/debian:bookworm-slim@sha256:3783cc01769c7b2b1b83a5c5ad96c815348e28ed7da68e2e3687004faa906251` (debian:bookworm-slim, base of localhost/dotfiles-workflow-test:1)

**Out of scope - CI covers**

- the full claude/workflow suite and the skill gates: CI runs them

## Assumptions

1. fallback for the whole ticket: if git checkout d478078 fails (object missing), git fetch origin d478078 first; still missing: stop with A2A-003

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
