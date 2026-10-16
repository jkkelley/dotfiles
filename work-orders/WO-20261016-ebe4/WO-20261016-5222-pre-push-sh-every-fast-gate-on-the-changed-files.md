---
{
  "id": "WO-20261016-5222",
  "slug": "pre-push-sh-every-fast-gate-on-the-changed-files",
  "title": "pre-push.sh: every fast gate on the changed files, in parallel, under 30 s; make pre-push, pre-push-install, pre-push-uninstall",
  "type": "feature",
  "status": "ready",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T08:28:09+00:00",
  "parent": "WO-20261016-ebe4",
  "branch": null,
  "pr": null,
  "closed": null,
  "approval": {
    "via": "override",
    "reason": "infra-design6 cut for ORD-0814 P1 P2; design approvals ruled done, ORD-0550 O4",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [],
  "blocks": [
    "WO-20261016-e4b4",
    "WO-20261016-b0ed",
    "WO-20261016-4814"
  ],
  "ac_checks": [
    {
      "index": 1,
      "command": "make -f claude/workflow/pre-push/pre-push.mk pre-push-test",
      "exit": 0,
      "expect": "pre-push: pass=[0-9]+ fail=0"
    },
    {
      "index": 2,
      "command": "make -f claude/workflow/pre-push/pre-push.mk pre-push-e2e",
      "exit": 0,
      "expect": "E2E-OK"
    },
    {
      "index": 3,
      "command": "bash -c s=\\$\\(date\\ +%s\\)\\;\\ make\\ -s\\ -f\\ claude/workflow/pre-push/pre-push.mk\\ pre-push\\ REPO=.\\ \\|\\|\\ exit\\ 1\\;\\ d=\\$\\(\\(\\ \\$\\(date\\ +%s\\)\\ -\\ s\\ \\)\\)\\;\\ echo\\ dur=\\$d\\;\\ \\[\\ \\\"\\$d\\\"\\ -lt\\ 30\\ \\]",
      "exit": 0,
      "expect": "PREPUSH-OK"
    },
    {
      "index": 4,
      "command": "bash -c make\\ -s\\ -f\\ claude/workflow/pre-push/pre-push.mk\\ pre-push-install\\ REPO=.\\ \\&\\&\\ make\\ -s\\ -f\\ claude/workflow/pre-push/pre-push.mk\\ pre-push-install\\ REPO=.\\ \\&\\&\\ make\\ -s\\ -f\\ claude/workflow/pre-push/pre-push.mk\\ pre-push-uninstall\\ REPO=.",
      "exit": 0,
      "expect": "PREPUSH-HOOK-REMOVED"
    },
    {
      "index": 5,
      "command": "make -f claude/workflow/pre-push/pre-push.mk pre-push",
      "exit": 2,
      "expect": "pre-push needs REPO="
    },
    {
      "index": 6,
      "command": "jq -e '.repos[\"jkkelley/dotfiles\"].gates | map(.name) == [\"tracked-ignored-check\",\"rolodex-check\",\"md-contents-check\",\"spec-check\",\"a2a-lint\",\"bump-resolve\"]' claude/workflow/pre-push/pre-push.json",
      "exit": 0,
      "expect": null
    },
    {
      "index": 7,
      "command": "make rolodex-check BASE=origin/main",
      "exit": 0,
      "expect": null
    },
    {
      "index": 8,
      "command": "bash -c \\!\\ git\\ diff\\ --name-only\\ origin/main...HEAD\\ \\|\\ grep\\ -vE\\ \\'\\^\\(work-orders/\\|claude/workflow/pre-push/\\(pre-push\\\\.\\(sh\\|json\\|mk\\)\\|tests/\\(test\\|e2e\\)_pre_push\\\\.sh\\)\\)\\$\\'",
      "exit": 0,
      "expect": null
    }
  ],
  "provides": [
    "make:pre-push",
    "make:pre-push-install",
    "make:pre-push-uninstall",
    "make:pre-push-test",
    "make:pre-push-e2e",
    "path:claude/workflow/pre-push/pre-push.sh",
    "path:claude/workflow/pre-push/tests/e2e_pre_push.sh"
  ]
}
---

# WO-20261016-5222 - pre-push.sh: every fast gate on the changed files, in parallel, under 30 s; make pre-push, pre-push-install, pre-push-uninstall

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

Seats push branches that a local, sub-second gate would have refused, so CI goes red and a seat is spent per PR. This is the tooling half of ORD-0814 P1: one generic, config-driven script and its Make targets in a standalone pre-push.mk.

## Owner words

> ORD-0814 P1: "cut the tooling ticket: make pre-push in dotfiles runs every fast gate on the changed files in under 30 s (rolodex-check, md-contents-check, tracked-ignored-check, bump-gate resolve against the PR body draft, a2a-lint, spec-check); seat-up installs it as a git pre-push hook in every seat worktree, and the work-order template adds it as the last checklist box before submit."

## Context

Evidence 2026-10-16 08:00-08:15Z: PRs 216, 219, 225, 234 red on headers or tracked-ignored-check; 213, 219, 210 red on bump intent. Each red costs a CI round and a seat; every one of those gates is local and fast.

Measured by the design seat 2026-10-16T08:40Z on main (serial, one run each): tracked-ignored-check 0.02 s, rolodex-check 0.06 s, spec-check 0.06 s, bump-gate.sh resolve 0.03 s, a2a-lint 0.53 s (podman, localhost/dotfiles-workflow-test:1); md-contents-check 3.8 s on the host (npx doctoc; the image has no npx and the target exits 2 there, so gates declare needs). Serial total under 5 s: 30 s is the budget with margin, and parallel runs keep it as gates are added.

Inventory: every gate already exists as a root Make target (tracked-ignored-check, rolodex-check, md-contents-check, spec-check, and a2a-lint from claude/workflow/a2a-guard/a2a-guard.mk) except bump-gate, which is .github/scripts/bump-gate.sh resolve --base REF --title-file F --body-file F. The root Makefile is touched by the ready chain WO-20261016-2ffe, 6630, f5dd, df39, so this ticket ships claude/workflow/pre-push/pre-push.mk run with make -f and touches no Makefile; the root include is its own ticket after df39. A worktree hooks live in the common git dir, so the hook path is read with git rev-parse --git-path, which also honours core.hooksPath. timed-run.sh --retries is the attempt count and repeats only on timeout, so 1 means one attempt.

Hook text, exactly 8 lines: (1) #!/usr/bin/env bash (2) # managed-by: dotfiles pre-push (claude/workflow/pre-push/pre-push.sh install) (3) # bypass once: git push --no-verify (CI still runs every gate); remove: make -f <MK> pre-push-uninstall REPO=<repo> (4) PP=<absolute pre-push.sh>; MK=<absolute pre-push.mk> (5) top=$(git rev-parse --show-toplevel) (6) [ -f "$PP" ] || { echo "PREPUSH-SKIP all NO-TOOL $PP"; exit 0; } (7) command -v make >/dev/null 2>&1 && exec make -s -f "$MK" pre-push REPO="$top" (8) exec bash "$PP" run --repo "$top"

pre-push.json, exactly (jq --indent 2): {"$comment": "pre-push gates per repository slug (owner/name from git remote get-url origin); defaults for any other repository. Each gate: name, cmd run by bash -c in the repository root with env BASE TITLE_FILE BODY_FILE DOTFILES, needs = tools that must be on PATH or the gate is skipped (ENV-MISSING). ORD-0814 P1.", "budget_s": 30, "timeout_s": 60, "defaults": {"gates": [{"name": "tracked-ignored-check", "needs": [], "cmd": "bad=$(git ls-files -ci --exclude-standard); [ -z \"$bad\" ] || { echo \"tracked but ignored:\"; echo \"$bad\"; exit 1; }"}]}, "repos": {"jkkelley/dotfiles": {"gates": [{"name": "tracked-ignored-check", "needs": [], "cmd": "make -s tracked-ignored-check"}, {"name": "rolodex-check", "needs": ["python3"], "cmd": "make -s rolodex-check BASE=\"$BASE\""}, {"name": "md-contents-check", "needs": ["npx"], "cmd": "make -s md-contents-check BASE=\"$BASE\""}, {"name": "spec-check", "needs": ["python3"], "cmd": "make -s spec-check BASE=\"$BASE\""}, {"name": "a2a-lint", "needs": [], "cmd": "make -s a2a-lint"}, {"name": "bump-resolve", "needs": [], "cmd": "bash .github/scripts/bump-gate.sh resolve --base \"$BASE\" --title-file \"$TITLE_FILE\" --body-file \"$BODY_FILE\""}]}}}

e2e_pre_push.sh body, run in localhost/dotfiles-workflow-test:1 with the repository mounted read-only at /src: set -e; git config --global user.email t@example.com, user.name t, --add safe.directory "*"; git clone -q --bare /src /tmp/r.git; git clone -q /tmp/r.git /tmp/c; cd /tmp/c; git remote set-url origin https://github.com/jkkelley/dotfiles.git; git remote set-url --push origin /tmp/r.git; git fetch -q /tmp/r.git main:refs/remotes/origin/main; bash claude/workflow/pre-push/pre-push.sh install --repo /tmp/c; git checkout -q -b t; echo x > work-orders/INDEX.md; git add -f work-orders/INDEX.md; git commit -qm red; a push that succeeds prints UNEXPECTED-PUSH and exits 1; grep -q "PREPUSH-RED.*tracked-ignored-check" on the refused push stderr; git rm -q --cached work-orders/INDEX.md; git commit -qm green; git push -q origin t; echo E2E-OK

## Scope

**In**

- touches: claude/workflow/pre-push/pre-push.sh (new)
- touches: claude/workflow/pre-push/pre-push.json (new)
- touches: claude/workflow/pre-push/pre-push.mk (new)
- touches: claude/workflow/pre-push/tests/test_pre_push.sh (new)
- touches: claude/workflow/pre-push/tests/e2e_pre_push.sh (new)
- touches (generated, written only by work-order.sh start/submit/done, never by hand): work-orders/INDEX.md, this ticket file and its archive path, work-orders/WO-20261016-ebe4/README.md
- step: pre-push.json: the exact JSON in Context, written with jq --indent 2
- step: pre-push.sh, bash, set -uo pipefail, rolodex header keys name/purpose/inputs/outputs/writes-to/cleanup, then a BREADCRUMB 2026-10-16 ORD-0814 P1 block naming the evidence PRs and why a config of gate commands rather than a fixed list (item 4: any repo, defaults for unknown ones). Verbs: run --repo DIR [--base REF] [--config FILE]; install --repo DIR; uninstall --repo DIR. Config: --config, else env PRE_PUSH_CONFIG, else pre-push.json beside the script. Exit: 0 ok, 1 red, 2 usage
- step: run: slug = git -C DIR remote get-url origin with everything up to github.com: or github.com/ and a trailing .git removed; gates = .repos[slug].gates // .defaults.gates; BASE default origin/main; when git -C DIR rev-parse --verify -q BASE^{commit} fails print "PREPUSH-SKIP all NO-BASE <BASE>" and exit 0. TITLE_FILE and BODY_FILE: the files at git -C DIR rev-parse --path-format=absolute --git-path PR_TITLE and --git-path PR_BODY.md when they exist (the seat writes its PR draft there), else mktemp files holding git -C DIR log -1 --format=%s and --format=%b. DOTFILES = the dotfiles root, three levels up from the script (readlink -f)
- step: run, per gate, all at once in the background, then wait: a gate whose needs names a tool not on PATH (command -v) prints "PREPUSH-SKIP <name> ENV-MISSING <tool>" and never runs; otherwise (cd DIR && BASE= TITLE_FILE= BODY_FILE= DOTFILES= bash -c CMD) with stdout and stderr to T/<name>.out, rc and whole seconds kept per gate. Then in config order: rc 0 "PREPUSH-PASS <name> <s>s"; rc 127 "PREPUSH-SKIP <name> ENV-MISSING"; else "PREPUSH-FAIL <name> rc=<rc>" then the last 20 lines of its output, each prefixed by two spaces. Last line: any FAIL "PREPUSH-RED <failed names, comma separated>" exit 1, else "PREPUSH-OK <n> gates <s>s" exit 0. T=mktemp -d, removed by trap on EXIT (item 11)
- step: install: H = git -C DIR rev-parse --path-format=absolute --git-path hooks/pre-push; mkdir -p its directory; the hook text is the 8 lines in Context with absolute paths filled. Same bytes present: "PREPUSH-HOOK-NOCHANGE <H>"; a file carrying the managed-by line but other bytes: rewrite, "PREPUSH-HOOK-UPDATED <H>"; any other file: write nothing, "PREPUSH-HOOK-FOREIGN <H>"; absent: write, chmod 755, "PREPUSH-HOOK-INSTALLED <H>". Every outcome exits 0
- step: uninstall: removes H only when it carries the managed-by line ("PREPUSH-HOOK-REMOVED <H>"); absent: "PREPUSH-HOOK-ABSENT <H>"; foreign kept: "PREPUSH-HOOK-FOREIGN <H>"; exit 0
- step: pre-push.mk: header comment (purpose, ORD-0814 P1, inputs as VAR=value: REPO= required, BASE=, CONFIG=); PP_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST)))); PP_IMAGE := localhost/dotfiles-workflow-test:1; .PHONY pre-push pre-push-install pre-push-uninstall pre-push-test pre-push-e2e. pre-push: line 1 the guard test -n "$(REPO)" or echo "pre-push needs REPO=" and exit 2; line 2 $(PP_DIR)/../bin/timed-run.sh --node pre-push --budget 30 --timeout 60 --retries 1 -- bash $(PP_DIR)/pre-push.sh run --repo "$(REPO)" plus --base $(BASE) and --config $(CONFIG) when set. pre-push-install and pre-push-uninstall: the same REPO guard, then bash $(PP_DIR)/pre-push.sh install or uninstall --repo "$(REPO)". pre-push-test: podman build -q -t $(PP_IMAGE) -f $(PP_DIR)/../tests/container/Containerfile $(PP_DIR)/.. then podman run --rm --network=none --userns=keep-id -v "$(abspath $(PP_DIR)/../../..):/work:Z" -w /work -e HOME=/tmp $(PP_IMAGE) bash -c "shellcheck -x claude/workflow/pre-push/pre-push.sh claude/workflow/pre-push/tests/*.sh && bash claude/workflow/pre-push/tests/test_pre_push.sh". pre-push-e2e: the same build, then podman run --rm --network=none --userns=keep-id -v "$(abspath $(PP_DIR)/../../..):/src:ro,Z" -e HOME=/tmp $(PP_IMAGE) bash /src/claude/workflow/pre-push/tests/e2e_pre_push.sh
- step: tests/test_pre_push.sh (rolodex header): W=mktemp -d with trap rm; a fixture repo with a bare remote, origin fetch url https://github.com/o/r.git and push url the bare path; fixture configs under repos["o/r"] passed by --config and PRE_PUSH_CONFIG; cases exactly TP-1 to TP-5 of the test plan; prints "ok <case>" or "FAIL <case>" per check and the last line "pre-push: pass=<n> fail=<m>", exit 1 when m>0
- step: tests/e2e_pre_push.sh (rolodex header): the body in Context
- step: run only TP-1 to TP-7 and make rolodex-check BASE=origin/main; CI runs the rest
- tool: path:claude/workflow/bin/timed-run.sh - on main; fallback: missing: stop with DESIGN-GAP naming it, never an untimed target
- tool: path:claude/workflow/tests/container/Containerfile - on main (localhost/dotfiles-workflow-test:1); fallback: missing: stop with DESIGN-GAP
- tool: path:.github/scripts/bump-gate.sh resolve - on main; fallback: a repo without it has no bump-resolve gate in pre-push.json
- tool: hook bypass - git push --no-verify skips the hook once; CI still runs every gate, so the fallback for a broken hook is CI as today
- tool: cmd:git, cmd:jq, cmd:make, cmd:podman - fallback: missing on the host: stop with ENV-MISSING naming it
- tool: make:Makefile:rolodex-check - on main; fallback: missing: stop with DESIGN-GAP naming it

**Out - non-goals**

- the root Makefile: the include ticket after WO-20261016-df39 owns it
- claude/workflow/bin/workflow-spawn.sh: the seat-up ticket owns it
- the work-order ticket template: the template box ticket owns it
- golden-rules-check, design-drift or any gate not named in the order: one config entry adds it later
- running any gate full-tree (ALL=1): pre-push checks the changed files only, CI runs the full suite (item 6)
- any file not named under In: stop with DESIGN-GAP and hand it back to infra-design

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [ ] `AC-H1` *(human)* the pre-push suite passes in podman
  - check: `make -f claude/workflow/pre-push/pre-push.mk pre-push-test` exit 0 expect /pre-push: pass=[0-9]+ fail=0/
- [ ] `AC-H2` *(human)* the real end-to-end push is refused on a tracked-ignored path and passes once it is untracked
  - check: `make -f claude/workflow/pre-push/pre-push.mk pre-push-e2e` exit 0 expect /E2E-OK/
- [ ] `AC-H3` *(human)* on the host in the ticket worktree the real gates pass in under 30 s
  - check: `bash -c s=\$\(date\ +%s\)\;\ make\ -s\ -f\ claude/workflow/pre-push/pre-push.mk\ pre-push\ REPO=.\ \|\|\ exit\ 1\;\ d=\$\(\(\ \$\(date\ +%s\)\ -\ s\ \)\)\;\ echo\ dur=\$d\;\ \[\ \"\$d\"\ -lt\ 30\ \]` exit 0 expect /PREPUSH-OK/
- [ ] `AC-H4` *(human)* install is idempotent and uninstall cleans up
  - check: `bash -c make\ -s\ -f\ claude/workflow/pre-push/pre-push.mk\ pre-push-install\ REPO=.\ \&\&\ make\ -s\ -f\ claude/workflow/pre-push/pre-push.mk\ pre-push-install\ REPO=.\ \&\&\ make\ -s\ -f\ claude/workflow/pre-push/pre-push.mk\ pre-push-uninstall\ REPO=.` exit 0 expect /PREPUSH-HOOK-REMOVED/
- [ ] `AC-H5` *(human)* the target refuses without REPO
  - check: `make -f claude/workflow/pre-push/pre-push.mk pre-push` exit 2 expect /pre-push needs REPO=/
- [ ] `AC-H6` *(human)* the dotfiles gate list is the six gates of the order, in order
  - check: `jq -e '.repos["jkkelley/dotfiles"].gates | map(.name) == ["tracked-ignored-check","rolodex-check","md-contents-check","spec-check","a2a-lint","bump-resolve"]' claude/workflow/pre-push/pre-push.json` exit 0
- [ ] `AC-H7` *(human)* every new script has a rolodex header
  - check: `make rolodex-check BASE=origin/main` exit 0
- [ ] `AC-H8` *(human)* the diff holds only In files and generated work-orders files
  - check: `bash -c \!\ git\ diff\ --name-only\ origin/main...HEAD\ \|\ grep\ -vE\ \'\^\(work-orders/\|claude/workflow/pre-push/\(pre-push\\.\(sh\|json\|mk\)\|tests/\(test\|e2e\)_pre_push\\.sh\)\)\$\'` exit 0

## Test plan

_Test plan from claude/workflow/templates/test-plan.md, shaped by claude/workflow/schemas/test-plan.schema.json. The tester runs exactly these cases and nothing else._

**Scope under test**

claude/workflow/pre-push/pre-push.sh verbs run, install, uninstall, its config pre-push.json and the Make targets in pre-push.mk

**Cases**

- `TP-1`
  - intent: a red gate caught at push costs seconds; caught in CI it costs a full CI round per PR (08:00-08:15Z: PRs 216, 219, 225, 234 red on headers or tracked-ignored-check, 213, 219, 210 red on bump intent)
  - command: `make -f claude/workflow/pre-push/pre-push.mk pre-push-test`
  - expected: exit 0; last line `pre-push: pass=N fail=0`; the fixture case with one gate `false` exits 1 and prints `PREPUSH-RED` naming that gate and its output; all-true gates exit 0 and print `PREPUSH-OK`
- `TP-2`
  - intent: gates run in parallel, or the budget of 30 s is lost as gates are added (item 2)
  - command: `make -f claude/workflow/pre-push/pre-push.mk pre-push-test`
  - expected: exit 0; the fixture with three gates `sleep 2` finishes in under 5 s
- `TP-3`
  - intent: a gate whose tool is missing never blocks a push; CI owns it (fallback)
  - command: `make -f claude/workflow/pre-push/pre-push.mk pre-push-test`
  - expected: exit 0; a gate with needs ["no-such-tool-xyz"] prints `PREPUSH-SKIP <gate> ENV-MISSING no-such-tool-xyz` and never runs its cmd; a gate cmd `exit 127` prints `PREPUSH-SKIP <gate> ENV-MISSING`; both runs exit 0
- `TP-4`
  - intent: install is idempotent and never overwrites a hook it does not own; uninstall cleans up only its own (items 11, 28)
  - command: `make -f claude/workflow/pre-push/pre-push.mk pre-push-test`
  - expected: exit 0; install prints PREPUSH-HOOK-INSTALLED then PREPUSH-HOOK-NOCHANGE; a foreign hook gives PREPUSH-HOOK-FOREIGN and is byte-identical after; uninstall prints PREPUSH-HOOK-REMOVED then PREPUSH-HOOK-ABSENT
- `TP-5`
  - intent: the installed hook really refuses a push on red and lets green through, end to end through git
  - command: `make -f claude/workflow/pre-push/pre-push.mk pre-push-test`
  - expected: exit 0; in the fixture, `git push` to a local bare remote exits non-zero with gate false and exits 0 with gate true; the bare remote's ref moves only on the green push
- `TP-6`
  - intent: scripts stay shellcheck clean and carry rolodex headers
  - command: `make -f claude/workflow/pre-push/pre-push.mk pre-push-test`
  - expected: exit 0; the target runs `shellcheck -x` on pre-push.sh and the test before the cases

- `TP-7`
  - intent: the real dotfiles gate list refuses a tracked-ignored push end to end (the PRs 216, 219, 225, 234 failure), and a missing npx never blocks
  - command: `make -f claude/workflow/pre-push/pre-push.mk pre-push-e2e`
  - expected: exit 0; last line `E2E-OK`

**Isolation**

- runtime: podman
- image: `docker.io/library/debian:bookworm-slim@sha256:3783cc01769c7b2b1b83a5c5ad96c815348e28ed7da68e2e3687004faa906251` (debian:bookworm-slim, base of localhost/dotfiles-workflow-test:1)

**Out of scope - CI covers**

- the real gates on the real dotfiles tree: AC-H2 runs them once on the host for the time budget; CI runs each gate itself
- UAT and stable: the test ticket cut beside this one

## Assumptions

1. the PR draft lives at PR_TITLE and PR_BODY.md under the worktree git dir (git rev-parse --git-path); with no draft the last commit subject and body stand in, which is what a squash merge of a one-commit branch carries
1. whole-run fallback: a broken hook is bypassed with git push --no-verify and CI gates exactly as today; a missing tool skips its gate (ENV-MISSING), never blocks

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
