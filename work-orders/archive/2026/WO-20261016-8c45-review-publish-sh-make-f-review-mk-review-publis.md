---
{
  "id": "WO-20261016-8c45",
  "slug": "review-publish-sh-make-f-review-mk-review-publis",
  "title": "review-publish.sh: make -f review.mk review-publish REPO= SRC= NAME= copies a merged directory from origin/main into the review root and prints each URL",
  "type": "feature",
  "status": "done",
  "priority": "p2",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T10:25:16+00:00",
  "parent": "WO-20261016-35de",
  "branch": "feat/review-publish-sh-make-f-review-mk-review-publis",
  "pr": 310,
  "closed": "2026-10-16",
  "approval": {
    "via": "override",
    "reason": "infra-design14 cut for ORD-0830 RR-orch-14 F35; design approvals ruled done, ORD-0550 O4",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [],
  "blocks": [
    "WO-20261016-bf62"
  ],
  "ac_checks": [
    {
      "index": 1,
      "command": "make -C claude/workflow -f review.mk review-test",
      "exit": 0,
      "expect": "ok review-publish: 8 cases"
    },
    {
      "index": 2,
      "command": "make rolodex-check BASE=origin/main",
      "exit": 0,
      "expect": null
    },
    {
      "index": 3,
      "command": "jq -r '\"\\(.bind):\\(.port) \\(.root) \\(.ref)\"' claude/workflow/config/review.json",
      "exit": 0,
      "expect": "^127\\.0\\.0\\.1:45610 ~/\\.local/state/zenith/review origin/main$"
    },
    {
      "index": 4,
      "command": "git diff --name-only origin/main...HEAD | grep -vE '^(work-orders/.*|claude/workflow/(bin/review-publish\\.sh|review\\.mk|config/review\\.json|tests/unit/test_review_publish\\.sh))$'",
      "exit": 1,
      "expect": null
    }
  ],
  "provides": [
    "make:review-test",
    "make:review-publish",
    "path:claude/workflow/bin/review-publish.sh",
    "path:claude/workflow/config/review.json"
  ],
  "labels": [
    "line:inbox-triage"
  ]
}
---

# WO-20261016-8c45 - review-publish.sh: make -f review.mk review-publish REPO= SRC= NAME= copies a merged directory from origin/main into the review root and prints each URL

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

The owner's review pages (http://localhost:45610/{d18,content,wire}/) are hand copies in ~/.local/state/zenith/inbox-triage/20261015/review, served by a python http.server the architect started in a background shell. They go stale the moment the merged source moves (content lacks business #69 and #71). Nothing publishes a merged directory to the review server by script, and nothing fixes the port or the root (WO-20261016-3787 gap: localhost:45610 and review_dir not fixed by the spec).

## Owner words

> ORD-1012 W1 (first): tooling ticket: make review-publish REPO= SRC= NAME= publishes a merged directory from origin/main into the review server root under NAME (git archive, idempotent, prints each URL) (orchestrator brief BR-20261016-infra-design14)

> if the task or job needs tools, the architect has a design agent build that shit out before the ticket goes in, thats a prereq for the ticket ready then (Design principles 101 item 30)

> Have fallbacks too (Design principles 101 item 28)

## Context

Order ORD-1012 W1 via brief BR-20261016-infra-design14, ORD-0830 RR-orch-14; F35. Evidence: ss -ltnp shows python3 -m http.server 45610 --bind 127.0.0.1 --directory ~/.local/state/zenith/inbox-triage/20261015/review (pid 1987220, cwd an unrelated investigations dir) - an architect background shell, not a monitor. This ticket builds the publish tool and its config; the systemd unit that serves the root is the next ticket (it depends on this one).

Config, new file claude/workflow/config/review.json, exactly: {"$comment": "Review server: review-publish.sh writes ROOT/NAME, the review-server unit serves ROOT on BIND:PORT. Breadcrumb in bin/review-publish.sh.", "root": "~/.local/state/zenith/review", "bind": "127.0.0.1", "port": 45610, "ref": "origin/main"}. A leading ~/ in root is expanded to $HOME. Env REVIEW_CONFIG overrides the config path (tests point it at a fixture).

Behaviour, fixed. review-publish.sh REPO SRC NAME [REF]; REF defaults to config .ref. (1) NAME not matching ^[a-z0-9][a-z0-9._-]*$, REPO not a git work tree, SRC empty, absolute or containing '..': usage on stderr, exit 2. (2) git -C REPO fetch -q origin under timeout 60; on failure stderr 'warn review fetch failed, using last fetched REF' and continue. (3) git -C REPO rev-parse --verify -q REF:SRC must name a tree, else stdout 'REVIEW-NOSRC SRC not on REF', exit 3. (4) SHA = git -C REPO rev-parse --short=12 REF. If ROOT/NAME/.review-publish.json exists with the same sha and src, print 'ok review NAME unchanged at SHA' then the URL lines, exit 0 (idempotent). (5) If ROOT/NAME exists without .review-publish.json it is a hand copy: mv it to ROOT/.retired/NAME-YYYYMMDDTHHMMSSZ (UTC), stderr 'warn review NAME: hand copy moved to PATH'; never rm a hand copy. (6) T = mktemp -d ROOT/.NAME.XXXXXX; git -C REPO archive REF SRC | tar -x -C T --strip-components=K where K is the number of / separated parts of SRC; write T/.review-publish.json {repo, src, ref, sha, at (UTC Z)}; then mv ROOT/NAME aside to ROOT/.NAME.old.PID if present, mv T ROOT/NAME, rm -rf the .old dir (it is a previous git archive, recoverable from git). (7) stdout 'ok review NAME SHA (N files)' then one line per regular file under ROOT/NAME except .review-publish.json, sorted: 'http://BIND:PORT/NAME/RELPATH'. Exit 0 ok, 2 usage, 3 REVIEW-NOSRC. The script carries the repo's rolodex header and a breadcrumb naming this ticket, the http.server evidence above and the rejected alternative (rsync from the working tree: publishes unmerged edits).

review.mk is standalone like claude/workflow/a2a.mk (make -C claude/workflow -f review.mk TARGET), copies a2a.mk's TIMED and podman RUN lines: review-publish REPO= SRC= NAME= [REF=] runs the script on the host; review-test runs shellcheck -x on the script and the test, then the test, in localhost/dotfiles-workflow-test:1 with --network=none --userns=keep-id. The test builds a bare origin and a clone in mktemp, sets REVIEW_CONFIG to a fixture config whose root is in mktemp, prints 'ok (N) ...' per case and ends with exactly 'ok review-publish: 8 cases'. Cases: 1 publish docs/ -> files under ROOT/NAME, one URL line per file, exit 0; 2 again at the same sha -> 'unchanged', exit 0, mtime of ROOT/NAME/.review-publish.json unchanged; 3 a new commit pushed to origin removes a file -> republished, the file is gone; 4 SRC absent on REF -> exit 3 REVIEW-NOSRC; 5 NAME '../x' -> exit 2 and nothing written; 6 ROOT/NAME preexists without the json -> moved under ROOT/.retired/, publish ok; 7 a local commit not pushed is not published; 8 origin path removed -> fetch warn on stderr, publishes from the last fetched ref.

## Scope

**In**

- touches: claude/workflow/bin/review-publish.sh (new, behaviour in Context)
- touches: claude/workflow/review.mk (new, standalone; targets review-publish, review-test)
- touches: claude/workflow/config/review.json (new, exactly as in Context)
- touches: claude/workflow/tests/unit/test_review_publish.sh (new, the 8 cases in Context)
- touches (generated, written only by work-order.sh start/submit/done, never by hand or git add): this ticket file and its archive path; work-orders/INDEX.md and the parent epic README.md are ignored generated views
- step: branch from origin/main in your own git worktree, never the ~/dotfiles primary clone
- step: write the four files exactly as in Context
- step: run make -C claude/workflow -f review.mk review-test and make rolodex-check BASE=origin/main and the AC checks only; CI runs the rest
- step: commit 'feat(workflow): review-publish.sh publishes a merged directory to the review root' with the ticket id; no Bump trailer
- tool: make:claude/workflow/review.mk:review-test - built by this ticket; tool: image localhost/dotfiles-workflow-test:1 - fallback: missing: make -C claude/workflow image, then retry once; build fails: stop with ENV-MISSING podman
- tool: make:Makefile:rolodex-check - on main; fallback: missing: stop with DESIGN-GAP naming it
- tool: cmd:git, cmd:jq, cmd:make, cmd:podman, cmd:gh - fallback: missing on the host: stop with ENV-MISSING naming it; gh or GitHub down: retry 3 times, then stop with A2A-003 and its output

**Out - non-goals**

- the systemd unit, starting or stopping any server, and the monitors entry: the next ticket
- calling review-publish from wiki-review (WO-20261016-6584) or regenerating the d18, content and wire pages (WO-20261016-3787)
- claude/workflow/Makefile: no include, the .mk is standalone
- any file not named under In: stop with DESIGN-GAP
- work-orders/INDEX.md and epic READMEs by hand or by git add; waiting on CI or merging: push, open the PR, write the result, leave
- a Bump trailer: no skill under claude/skills changes

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [x] `AC-H1` *(human)* the 8 review-publish cases pass in podman
  - observed `2026-10-16` make -C claude/workflow -f review.mk review-test exit 0: ok review-publish: 8 cases
  - check: `make -C claude/workflow -f review.mk review-test` exit 0 expect /ok review-publish: 8 cases/
- [x] `AC-H2` *(human)* every changed script has a rolodex header
  - observed `2026-10-16` make rolodex-check BASE=origin/main exit 0: 2 script(s) checked, all have headers
  - check: `make rolodex-check BASE=origin/main` exit 0
- [x] `AC-H3` *(human)* the config fixes the port and the root
  - observed `2026-10-16` jq output: 127.0.0.1:45610 ~/.local/state/zenith/review origin/main
  - check: `jq -r '"\(.bind):\(.port) \(.root) \(.ref)"' claude/workflow/config/review.json` exit 0 expect /^127\.0\.0\.1:45610 ~/\.local/state/zenith/review origin/main$/
- [x] `AC-H4` *(human)* the diff holds only In files and generated work-orders files
  - observed `2026-10-16` grep -v filter exit 1, no stray files
  - check: `git diff --name-only origin/main...HEAD | grep -vE '^(work-orders/.*|claude/workflow/(bin/review-publish\.sh|review\.mk|config/review\.json|tests/unit/test_review_publish\.sh))$'` exit 1

## Test plan

```sh
{"scope":"review-publish.sh against a fixture bare origin and a mktemp review root","cases":[{"id":"TP-1","intent":"the owner reviewed stale hand copies; publish must take only merged content, be idempotent, never delete a hand copy, and print every URL","command":"make -C claude/workflow -f review.mk review-test","expected":"exit 0; 8 ok lines, last ok review-publish: 8 cases"},{"id":"TP-2","intent":"the new script carries its rolodex header","command":"make rolodex-check BASE=origin/main","expected":"exit 0"}],"isolation":{"runtime":"podman","image":"localhost/dotfiles-workflow-test:1"},"out_of_scope":["the server unit: next ticket","the full workflow suite: CI runs it"]}
```

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
