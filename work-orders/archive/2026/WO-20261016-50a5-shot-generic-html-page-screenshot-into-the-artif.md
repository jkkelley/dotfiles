---
{
  "id": "WO-20261016-50a5",
  "slug": "shot-generic-html-page-screenshot-into-the-artif",
  "title": "shot: generic HTML page screenshot into the artifact store, headless Chromium, size checked, for the HTML wireframes rev 2 evidence",
  "type": "feature",
  "status": "done",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T09:33:32+00:00",
  "parent": "WO-20261016-0272",
  "branch": "feat/shot-generic-html-page-screenshot-into-the-artif",
  "pr": 287,
  "closed": "2026-10-16",
  "approval": {
    "via": "override",
    "reason": "seat-ready cut ORD-0830 RR-orch-14 yp-design7: touches, exact steps, exit-coded ACs, test plan, fallback FB-008; architect ruling ORD-0550 O4; Lavish prohibited for Claude seats (global rule)",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [],
  "blocks": [],
  "ac_checks": [
    {
      "index": 1,
      "command": "make -f claude/tools/shot/shot.mk shot-test",
      "exit": 0,
      "expect": "pass=8 fail=0"
    },
    {
      "index": 2,
      "command": "make -f claude/tools/shot/shot.mk shot-lint",
      "exit": 0,
      "expect": null
    },
    {
      "index": 3,
      "command": "bash claude/tools/shot/shot.sh --html /nonexistent.html --name x 2>&1",
      "exit": 3,
      "expect": "SHOT-SRC"
    },
    {
      "index": 4,
      "command": "env FORCE_FALLBACK=1 bash claude/workflow/bin/timed-run.sh --node shot-fb --fallback \"bash claude/tools/shot/shot.sh --help\" --fallback-code FB-008 -- false 2>&1",
      "exit": 0,
      "expect": "FALLBACK FB-008 shot-fb"
    },
    {
      "index": 5,
      "command": "bash -c '! git diff --name-only origin/main...HEAD | grep -vE \"^(work-orders/|claude/tools/shot/(shot\\.sh|shot\\.mk|README\\.md|tests/test_shot\\.sh)$)\"'",
      "exit": 0,
      "expect": null
    }
  ],
  "provides": [
    "claude/tools/shot/shot.sh",
    "claude/tools/shot/shot.mk",
    "claude/tools/shot/tests/test_shot.sh",
    "make:shot",
    "make:shot-test",
    "make:shot-lint"
  ]
}
---

# WO-20261016-50a5 - shot: generic HTML page screenshot into the artifact store, headless Chromium, size checked, for the HTML wireframes rev 2 evidence

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

Every visual DAG node needs a screenshot written by script to the artifact store (items 23 and 31). The only renderer on disk, business ventures/yieldpoint-consulting/linkedin-page/scripts/render-preview.sh, screenshots one fixed file and writes the PNG beside it in git. The HTML wireframes rev 2 leaves need one generic call: an HTML file in, a size-checked PNG out under screenshot/YYYY/MM/ with its .meta.json sidecar (claude/tools/artifact/artifact.sh new already writes the sidecar for a png ext).

## Owner words

> Owner, Design principles 101 item 31, 2026-10-16 UTC: "if architects don't ahve supporting evidence and can't reproducre the error or no screenshot with clear evidence, then SOP wasn't followed"

> Owner, item 30, 2026-10-16 UTC: "if the task or job needs tools, the architect has a design agent build that shit out before the ticket goes in" and "create generic tooling too fucker"

## Context

ORD-0830 RR-orch-14 yp-design7; RR-orch-19: Figma parked FB-006, HTML wireframes rev 2 on the review pages are the source of truth. Business leaves WR2Ha-WR2Hd (yp-design7) screenshot their page by this tool; no generic HTML-to-PNG script exists in dotfiles (business linkedin-page/scripts/render-preview.sh is hard-wired to one file and writes into git).

## Scope

**In**

- touches: claude/tools/shot/shot.sh
- touches: claude/tools/shot/shot.mk
- touches: claude/tools/shot/tests/test_shot.sh
- touches: claude/tools/shot/README.md
- shot.sh --html FILE --name SLUG [--size WxH] [--what TEXT]; default size 1440x900; --help prints the usage block to stderr and exits 0; inputs also from env CHROME_BIN (browser path), SHOT_TIMEOUT_S (default 30), ARTIFACT_ROOT (passed through to artifact.sh). Exit codes and stderr status lines: 0 SHOT-OK <path>; 2 SHOT-USAGE (unknown flag, missing --html or --name, size not ^[0-9]+x[0-9]+$); 3 SHOT-SRC (html file missing); 4 SHOT-NOBROWSER (no executable browser: CHROME_BIN, else the newest ~/.cache/ms-playwright/chromium_headless_shell-*/chrome-headless-shell-linux64/chrome-headless-shell by sort -V); 4 SHOT-RENDER (browser non-zero, timeout, empty file, not a PNG, or wrong size). stdout carries only the store path.
- render order: mktemp -d with trap rm; run "$CHROME" --no-sandbox --disable-gpu --hide-scrollbars --force-device-scale-factor=1 --window-size=W,H --screenshot=$TMP/out.png "file://$(realpath FILE)" under timeout SHOT_TIMEOUT_S, its output to /dev/null; check: file non-empty, first 8 bytes equal 89504e470d0a1a0a (od -An -tx1 -N8 | tr -d " \n"), width and height read as big-endian u32 at byte offsets 16 and 20 (od -An -tu1 -j16 -N8) equal W and H; only then path=$(bash "$HERE/../artifact/artifact.sh" new --key screenshot --name SLUG --ext png --what "${WHAT:-SLUG}") and mv the PNG onto path. A failed render therefore leaves no store file.
- shot.mk, pattern of claude/tools/artifact/artifact.mk (SHOT_SH := $(dir $(lastword $(MAKEFILE_LIST)))shot.sh), usable as include or make -f: targets shot (## make -f claude/tools/shot/shot.mk shot HTML= NAME= [SIZE=] [WHAT=]: screenshot to the store), shot-test (## relevant-only test in podman: podman run --rm --network=none -v "$(abspath $(dir $(SHOT_SH))..):/w:ro,Z" localhost/dotfiles-workflow-test:1 bash /w/shot/tests/test_shot.sh) and shot-lint (same image, shellcheck -x /w/shot/shot.sh /w/shot/tests/test_shot.sh)
- tests/test_shot.sh, pattern of claude/tools/artifact/tests/test_artifact.sh (ok/FAIL lines, final "pass=N fail=M", exit 1 on any failure, mktemp dir removed on exit, ARTIFACT_ROOT pointed into it). A stub browser script in the temp dir parses --window-size=W,H and --screenshot=P and writes a valid PNG header for W x H with printf (8 signature bytes, IHDR length and type, W and H as 4 big-endian bytes each); a second stub writes W+1; a third exits 1; a fourth sleeps 5. Cases: t1 ok -> exit 0, stdout path under $ARTIFACT_ROOT/screenshot/, file has the PNG signature, path.meta.json exists with key screenshot; t2 wrong-size stub -> exit 4, stderr SHOT-RENDER, no file under screenshot/; t3 failing stub -> exit 4 SHOT-RENDER; t4 SHOT_TIMEOUT_S=1 with the sleeping stub -> exit 4 SHOT-RENDER; t5 missing html -> exit 3 SHOT-SRC; t6 CHROME_BIN=/nonexistent -> exit 4 SHOT-NOBROWSER; t7 --size 10by10 -> exit 2 SHOT-USAGE; t8 make -f shot.mk shot HTML= NAME= SIZE=20x10 with the ok stub -> exit 0, store path printed. Exactly 8 cases.
- README.md: contents list first (dotfiles hard rule, then bash scripts/md-contents.sh write claude/tools/shot/README.md), what it is, the status line table above, the Make targets, fallback, cleanup (make artifact-clean KEY=screenshot OLDER_THAN=days)
- breadcrumb comment at the top of shot.sh: what was missing (no generic HTML screenshot; render-preview.sh writes PNGs into git, against item 23), why headless Chromium from the cached Playwright install (already on the host, no network, same binary render-preview.sh uses), rejected alternatives (chrome-devtools-axi, which needs a model turn per shot, item 39; Figma get_screenshot, parked FB-006), why render before allocating the store path (no empty store file on failure), the cost (one browser start per shot)
- step 1: own worktree and feature branch from origin/main; write exactly the four touches files
- step 2: make -C claude/workflow image (only if localhost/dotfiles-workflow-test:1 is missing), then make -f claude/tools/shot/shot.mk shot-test and make -f claude/tools/shot/shot.mk shot-lint
- step 3: commit "feat(tools): shot, generic HTML screenshot into the artifact store (ORD-0830 RR-orch-14)", push, gh pr create with auto-merge, leave
- tool: cmd:podman, cmd:timeout, cmd:od, cmd:realpath - fallback: missing on the host -> stop with ENV-MISSING naming it
- tool: path:claude/tools/artifact/artifact.sh - on main; fallback: none needed, a file on main read locally
- fallback: make -f shot.mk shot fails to start -> run bash claude/tools/shot/shot.sh with the same arguments; switch timed-run.sh --fallback ... --fallback-code FB-008; no headless shell on a host -> set CHROME_BIN to any Chromium (SHOT-NOBROWSER says so)

**Out - non-goals**

- editing the root Makefile, artifact.sh, artifact.conf or claude/workflow/config/fallbacks.json
- any wireframe HTML (business WR2Ha-WR2Hd own those)
- a full-page or element screenshot mode, device emulation or dark-mode flags: a page puts its light and dark frames side by side itself
- any file not named under In: stop with DESIGN-GAP

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [x] `AC-H1` *(human)* the 8 cases pass in podman
  - observed `2026-10-16` check: make -f claude/tools/shot/shot.mk shot-test exit 0 output: ok t1 ok ok t2 wrong size ok t3 failing browser ok t4 timeout ok t5 missing html ok t6 no browser ok t7 bad size ok t8 make pass=8 fail=0
  - check: `make -f claude/tools/shot/shot.mk shot-test` exit 0 expect /pass=8 fail=0/
- [x] `AC-H2` *(human)* shellcheck clean
  - observed `2026-10-16` check: make -f claude/tools/shot/shot.mk shot-lint exit 0 output:
  - check: `make -f claude/tools/shot/shot.mk shot-lint` exit 0
- [x] `AC-H3` *(human)* a missing html exits 3 with SHOT-SRC
  - observed `2026-10-16` check: bash claude/tools/shot/shot.sh --html /nonexistent.html --name x 2>&1 exit 3 output: SHOT-SRC html file missing: /nonexistent.html
  - check: `bash claude/tools/shot/shot.sh --html /nonexistent.html --name x 2>&1` exit 3 expect /SHOT-SRC/
- [x] `AC-H4` *(human)* fallback switch runs the script with FB-008
  - observed `2026-10-16` check: env FORCE_FALLBACK=1 bash claude/workflow/bin/timed-run.sh --node shot-fb --fallback "bash claude/tools/shot/shot.sh --help" --fallback-code FB-008 -- false 2>&1 exit 0 output: usage: shot.sh --html FILE --name SLUG [--size WxH] [--what TEXT] default size 1440x900; env CHROME_BIN, SHOT_TIMEOUT_S (default 30), ARTIFACT_ROOT exit: 0 SHOT-OK <path> | 2 SHOT-USAGE | 3 SHOT-SRC | 4 SHOT-NOBROWSER or SHOT-RENDER FALLBACK FB-008 shot-fb
  - check: `env FORCE_FALLBACK=1 bash claude/workflow/bin/timed-run.sh --node shot-fb --fallback "bash claude/tools/shot/shot.sh --help" --fallback-code FB-008 -- false 2>&1` exit 0 expect /FALLBACK FB-008 shot-fb/
- [x] `AC-H5` *(human)* the diff is exactly the touches plus work-orders files
  - observed `2026-10-16` check: bash -c '! git diff --name-only origin/main...HEAD | grep -vE "^(work-orders/|claude/tools/shot/(shot.sh|shot.mk|README.md|tests/test_shot.sh)$)"' exit 0 output:
  - check: `bash -c '! git diff --name-only origin/main...HEAD | grep -vE "^(work-orders/|claude/tools/shot/(shot\.sh|shot\.mk|README\.md|tests/test_shot\.sh)$)"'` exit 0

## Test plan

```sh
make -f claude/tools/shot/shot.mk shot-test && make -f claude/tools/shot/shot.mk shot-lint
```

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
