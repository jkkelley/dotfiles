---
{
  "id": "WO-20261016-474f",
  "slug": "mk-inc-make-mk-include-repo-dir-installs-one-mar",
  "title": "MK-INC: make mk-include REPO= DIR= installs one marked -include line for per-node make files, with mk-include-check",
  "type": "feature",
  "status": "draft",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T06:18:21+00:00",
  "parent": "WO-20261016-0272",
  "branch": null,
  "pr": null,
  "closed": null,
  "approval": null,
  "evidence": null,
  "surfaces": [],
  "depends_on": [
    "WO-20261016-d304"
  ],
  "blocks": [
    "WO-20261016-fa5f",
    "WO-20261016-2e9f"
  ],
  "labels": [
    "line:inbox-triage"
  ]
}
---

# WO-20261016-474f - MK-INC: make mk-include REPO= DIR= installs one marked -include line for per-node make files, with mk-include-check

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

Order ORD-0556 O1 verbatim: 'every tooling ticket builds a generic, config-driven tool in dotfiles (callable from any repo by Make with VAR=value), inventoried against existing dotfiles tools first; the specific ticket passes specifics as config or args; a one-off script inside a product repo is refused at design'. Need: ypli-01-src nodes C14a, C16a, C17a and C21a each write make/<node>.mk and ypli's Makefile includes nothing (checked 2026-10-16); owner item 19 'never touching same files'. Inventory: scripts/golden-rules.sh writes a block between markers into instruction files only; scripts/md-contents.sh writes contents lists only; no tool writes a Makefile include. So a small generic tool, marker-delimited like golden-rules.sh. Orchestrator orders 2026-10-16 (MSG-20261016T061019Z-yp-design): ORD-0552 O2 'write each AC as command + expected exit code + expected output in the ticket text, and carry owner words verbatim and full context in Problem'; ORD-0555 O1 'before a ticket goes ready, list every tool, script, Make target and fixture its steps and AC checks call; any not on main gets a tooling ticket first'; ORD-0556 O1 'every tooling ticket builds a generic, config-driven tool in dotfiles'; ORD-0558 O1 'every design and ready ticket names the fallback for each tool and dependency it uses, the scripted switch with its status code, and a test case for the fallback path'.

## Scope

**In**

- scripts/mk-include.sh install|check REPO DIR: install appends to REPO/Makefile, once, the block `# >>> mk-include (dotfiles scripts/mk-include.sh)` / `-include $(sort $(wildcard DIR/*.mk))` / `# <<< mk-include`; a second install changes nothing (prints `ok already`); check exits 3 with `FAIL <Makefile>: no mk-include block` when missing; DIR must be a relative path without `..`, else exit 2; header in the rolodex format
- Makefile (dotfiles root): `mk-include: ; bash scripts/mk-include.sh install $(REPO) $(DIR)` and `mk-include-check: ; bash scripts/mk-include.sh check $(REPO) $(DIR)`, plus `mk-include-test` running scripts/tests/test_mk_include.sh in localhost/dotfiles-workflow-test:1
- scripts/tests/test_mk_include.sh: install on a fixture Makefile, rerun is byte identical, a make/zz.mk target is reachable, check fails on a fresh Makefile, `..` refused
- Tool: podman with a digest-pinned image (make -C ~/dotfiles/claude/workflow image builds localhost/dotfiles-workflow-test:1). Fallback: rerun with --pull=never on the locally cached image of the same digest. Switch: timed-run.sh --fallback ... --fallback-code FB-001 (status code FB-001; switch from WO-20261016-d304 - TR-FB: timed-run.sh --fallback CMD --fallback-code FB-NNN, the one scripted fallback switch, with the FB code catalog)

**Out - non-goals**

- Editing any product repo; the specific ticket C00a in business runs the tool
- Any other Makefile edit

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [ ] `AC-H1` *(human)* `make -C ~/dotfiles mk-include-test` -> exit 0, no `FAIL` in output. Proof: command output
- [ ] `AC-H2` *(human)* `FORCE_FALLBACK=1 bash ~/dotfiles/claude/workflow/bin/timed-run.sh --node mk-inc --fallback "bash scripts/tests/test_mk_include.sh" --fallback-code FB-008 -- make -C ~/dotfiles mk-include-test` -> exit 0, stderr contains `FALLBACK FB-008`. Proof: command output

## Test plan

```sh
make -C ~/dotfiles mk-include-test
```

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

- `2026-10-16` DRAFT until tool WO-20261016-d304 - TR-FB (timed-run.sh --fallback) is on main (ORD-0555 O1); then approve --no-lavish --reason "architect ruled design approvals done, ORD-0550 O4"

## Outcome

_Written by `work-order done`. Empty until then._
