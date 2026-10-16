---
{
  "id": "WO-20261016-8e05",
  "slug": "tools-refresh-sh-copy-the-seat-tool-trees-from-m",
  "title": "tools-refresh.sh: copy the seat tool trees from MAIN_CLONE origin/main (never its working tree) into TOOLS_DIR atomically, stamped with the source sha; make tools-refresh, tools-refresh-check, tools-refresh-install",
  "type": "feature",
  "status": "ready",
  "priority": "p0",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T11:11:03+00:00",
  "parent": "WO-20261016-4b6c",
  "branch": null,
  "pr": null,
  "closed": null,
  "approval": {
    "via": "override",
    "reason": "infra-design17 cut for ORD-1053 / ORD-0830 RR-orch-14; design approvals ruled done, ORD-0550 O4; Lavish prohibited for Claude seats (global rule)",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [
    "WO-20261016-f82b"
  ],
  "blocks": [
    "WO-20261016-9756"
  ],
  "ac_checks": [
    {
      "index": 1,
      "command": "make -C claude/workflow tools-refresh-test",
      "exit": 0,
      "expect": "ok install-idempotent"
    },
    {
      "index": 2,
      "command": "make -C claude/workflow lint",
      "exit": 0,
      "expect": null
    },
    {
      "index": 3,
      "command": "jq -r '.copies|length' claude/workflow/config/tools-refresh.json",
      "exit": 0,
      "expect": "^3$"
    },
    {
      "index": 4,
      "command": "grep -c '^include mk/tools-refresh.mk$' claude/workflow/Makefile",
      "exit": 0,
      "expect": "^1$"
    },
    {
      "index": 5,
      "command": "make rolodex-check BASE=origin/main",
      "exit": 0,
      "expect": null
    },
    {
      "index": 6,
      "command": "bash -c '! git diff --name-only origin/main...HEAD | grep -vE \"^(work-orders/.*|claude/workflow/(Makefile|bin/tools-refresh[.]sh|config/tools-refresh[.]json|mk/tools-refresh[.]mk|tests/unit/test_tools_refresh[.]sh))$\"'",
      "exit": 0,
      "expect": null
    }
  ],
  "provides": [
    "make:claude/workflow/Makefile:tools-refresh-test",
    "path:claude/workflow/bin/tools-refresh.sh"
  ],
  "labels": [
    "line:inbox-triage"
  ]
}
---

# WO-20261016-8e05 - tools-refresh.sh: copy the seat tool trees from MAIN_CLONE origin/main (never its working tree) into TOOLS_DIR atomically, stamped with the source sha; make tools-refresh, tools-refresh-check, tools-refresh-install

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

Seat tool copies (zwo, the architect copy) are refreshed by an untracked ~/.local/bin/zrefresh that nobody runs on a schedule and that rsyncs the ~/dotfiles working tree, so a seat can run an old or off-main copy. Evidence: seats/yp-design11.result.json design_gap[1]: zwo (the architect copy at ~/.local/share/zenith-architect/work-order, refreshed only when someone runs ~/.local/bin/zrefresh by hand) listed epics 0d38 1555 4ffa 708e 715b as leaves while dotfiles main next did not (repro: zwo next --project <business> vs bash ~/dotfiles/claude/skills/work-order/scripts/work-order.sh next); seats/yp-design6.result.json and yp-design11 approved business tickets with zwo because its old approve had no tool gate. zrefresh is untracked (~/.local/bin/zrefresh: git -C ~/dotfiles pull --ff-only, then rsync -a --delete of the ~/dotfiles working tree claude/workflow (minus tests), claude/skills/work-order and claude/tools/artifact into ~/.local/share/zenith-architect), so it copies whatever branch the clone sits on.

## Owner words

> ORD-1053 A4: prevention ticket: tool copies for seats come from dotfiles main only; seat-up runs zrefresh (or skill-sync) before a seat starts, so no seat uses a stale copy. (orchestrator brief BR-20261016-infra-design17)

> All tooling created for a project lives in that project's repository, tracked. (~/AGENTS.md, how agents talk to me)

> so its re-usable, add to it, makefiles, dont' be a crackhead and one off shit all the time, if we need to do so (Design principles 101 item 30)

> Have fallbacks too (Design principles 101 item 28)

## Context

Order ORD-1053 A4, brief BR-20261016-infra-design17. Tooling ticket first (item 30): the seat-up ticket this one blocks (seat-up calls it) depends on this. Port of zrefresh into dotfiles, generic and config-driven (items 4, 17). Config claude/workflow/config/tools-refresh.json, exactly: {"src_clone":"~/dotfiles","ref":"origin/main","dest":"~/.local/share/zenith-architect","bin_dir":"~/.local/bin","copies":[{"from":"claude/workflow","to":"workflow","exclude":["tests"]},{"from":"claude/skills/work-order","to":"work-order","exclude":[]},{"from":"claude/tools/artifact","to":"artifact","exclude":[]}]}; a leading ~/ expands to $HOME; env MAIN_CLONE, TOOLS_DIR, TOOLS_BIN_DIR and TOOLS_REFRESH_CONFIG override (arguments --config F win). Script claude/workflow/bin/tools-refresh.sh, verbs: run: (1) MAIN_CLONE not a git repo or ref unresolvable after the fetch: stderr 'tools-refresh: TOOLS-STALE <reason>' exit 3. (2) git -C MAIN_CLONE fetch -q origin main, up to 3 tries 2 s apart; all fail: stderr 'tools-refresh: FB fetch failed, using last fetched origin/main <sha>' and continue (fallback: the last fetched main, never the working tree). (3) sha=$(git rev-parse <ref>); if DEST/.source-sha equals sha and every copies[].to dir exists: print 'tools-refresh: current <sha>' exit 0, nothing written (idempotent). (4) else for each copy: git -C MAIN_CLONE archive <sha>:<from> | tar -x -C DEST/.staging-<to> (mkdir -p first, rm -rf a leftover staging dir), delete each exclude path inside staging, mv DEST/<to> DEST/.old-<to> if present, mv staging to DEST/<to>, rm -rf DEST/.old-<to>; after all copies write DEST/.source-sha (sha and newline) via a temp file and mv; print 'tools-refresh: refreshed <sha>' exit 0. A crash mid-run leaves .source-sha old, so the next run redoes every copy (graceful recovery). check: no fetch; exit 0 printing 'tools-refresh: current <sha>' when DEST/.source-sha equals <ref> in MAIN_CLONE, else exit 3 'tools-refresh: TOOLS-STALE have <a> want <b>'. install: write TOOLS_BIN_DIR/zrefresh as a 3-line bash wrapper 'exec bash <abs path of this script> run "$@"' (temp file then mv, chmod 755), byte-identical on a re-run; it does not touch zwo (zwo already execs DEST/work-order/scripts/work-order.sh). Usage error: exit 2. Rolodex header and a breadcrumb naming this ticket and the yp-design11 evidence. Make: claude/workflow/mk/tools-refresh.mk with targets tools-refresh ($(TIMED) bash bin/tools-refresh.sh run), tools-refresh-check, tools-refresh-install and tools-refresh-test (image prerequisite; $(TIMED) $(RUN) bash tests/unit/test_tools_refresh.sh), each with a ## help line; one line 'include mk/tools-refresh.mk' after 'include mk/resources.mk' in claude/workflow/Makefile. Rejected: rsync of the working tree (zrefresh), it copies whatever branch the clone sits on; rejected: skill-sync, it installs registry versions into projects, not the architect copies of claude/workflow and claude/tools; rejected: git pull in the clone, the main-clone guard (WO-20261016-c2b3) owns the clone. Cost: a refresh needs one fetch; tar is in the debian test image. Test claude/workflow/tests/unit/test_tools_refresh.sh, all in mktemp with a fixture bare repo holding claude/workflow/{bin/a.sh,tests/t.sh}, claude/skills/work-order/scripts/work-order.sh, claude/tools/artifact/artifact.sh and a clone of it, a fixture config pointing src_clone, dest and bin_dir into mktemp; cases, each printing 'ok <name>': first-run-copies (3 dirs, workflow/tests absent, .source-sha equals origin/main); rerun-current (prints current, no file mtime changes); upstream-delete (a file removed upstream and fetched is gone from dest); fetch-down (bare repo moved away: exit 0, stderr has 'FB fetch failed', dest unchanged); branch-not-copied (clone checked out on feat/x with an uncommitted edit to a.sh: dest a.sh equals origin/main content); check-stale (remote advances, git fetch in clone: check exit 3 with TOOLS-STALE); not-git (MAIN_CLONE a plain dir: run exit 3 TOOLS-STALE); install-idempotent (install twice: wrapper bytes equal, mode 755).

## Scope

**In**

- touches: claude/workflow/bin/tools-refresh.sh (new: verbs run, check, install as in Context)
- touches: claude/workflow/config/tools-refresh.json (new: exactly the JSON in Context)
- touches: claude/workflow/mk/tools-refresh.mk (new: four targets in Context)
- touches: claude/workflow/Makefile (one include line after include mk/resources.mk)
- touches: claude/workflow/tests/unit/test_tools_refresh.sh (new: the eight cases in Context)
- touches (generated, written only by work-order.sh start/submit/done, never by hand or git add): this ticket file and its archive path; work-orders/INDEX.md and the parent epic README.md are ignored generated views
- step: branch from origin/main in your own git worktree after WO-20261016-f82b merged (last ticket on claude/workflow/Makefile, rule 19), never the ~/dotfiles primary clone; write exactly the five files above to the design in Context
- step: run `make -C claude/workflow tools-refresh-test`, `make -C claude/workflow lint` and the AC checks only; CI runs the rest
- step: commit 'feat(workflow): tools-refresh copies seat tools from dotfiles origin/main' with the ticket id; no Bump trailer (no skill under claude/skills changes)
- tool: make:claude/workflow/Makefile:lint - on main (shellcheck bin/*.sh tests/unit/*.sh); fallback: image build fails: stop with ENV-MISSING podman
- tool: make:Makefile:rolodex-check - on main; fallback: missing: stop with DESIGN-GAP naming it
- tool: cmd:git, cmd:jq, cmd:make, cmd:podman, cmd:gh - fallback: missing on the host: stop with ENV-MISSING naming it; gh or GitHub down: retry 3 times, then stop with A2A-003 and its output

**Out - non-goals**

- seat-up calling it: the seat-up ticket this one blocks
- running install or run on the host: the architect or the A4B seat-up path does that after merge
- the main clone fast-forward: WO-20261016-c2b3 owns it
- work-orders/INDEX.md and epic READMEs by hand or by git add; waiting on CI or merging: push, open the PR, write the result, leave (ORD-0542 O2)
- any file not named under In: stop with DESIGN-GAP and hand it back to infra-design (ORD-0548, item 30)

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [ ] `AC-H1` *(human)* the tools-refresh suite passes
  - check: `make -C claude/workflow tools-refresh-test` exit 0 expect /ok install-idempotent/
- [ ] `AC-H2` *(human)* shellcheck is clean on the new scripts
  - check: `make -C claude/workflow lint` exit 0
- [ ] `AC-H3` *(human)* the config parses and names three copies
  - check: `jq -r '.copies|length' claude/workflow/config/tools-refresh.json` exit 0 expect /^3$/
- [ ] `AC-H4` *(human)* the Makefile includes the new mk once
  - check: `grep -c '^include mk/tools-refresh.mk$' claude/workflow/Makefile` exit 0 expect /^1$/
- [ ] `AC-H5` *(human)* every changed script has a rolodex header
  - check: `make rolodex-check BASE=origin/main` exit 0
- [ ] `AC-H6` *(human)* the diff holds only In files and generated work-orders files
  - check: `bash -c '! git diff --name-only origin/main...HEAD | grep -vE "^(work-orders/.*|claude/workflow/(Makefile|bin/tools-refresh[.]sh|config/tools-refresh[.]json|mk/tools-refresh[.]mk|tests/unit/test_tools_refresh[.]sh))$"'` exit 0

## Test plan

```sh
{"scope":"tools-refresh copies seat tools from origin/main only, atomically and idempotently","cases":[{"id":"TP-1","intent":"zwo ran an old copy (yp-design11); the refresh must copy origin/main, never a branch working tree, and fall back to the last fetched main when the fetch fails","command":"make -C claude/workflow tools-refresh-test","expected":"exit 0; eight ok lines"},{"id":"TP-2","intent":"shellcheck clean","command":"make -C claude/workflow lint","expected":"exit 0"},{"id":"TP-3","intent":"rolodex header kept","command":"make rolodex-check BASE=origin/main","expected":"exit 0"}],"isolation":{"runtime":"podman","image":"localhost/dotfiles-workflow-test:1"},"out_of_scope":["running against the real ~/dotfiles or ~/.local"]}
```

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
