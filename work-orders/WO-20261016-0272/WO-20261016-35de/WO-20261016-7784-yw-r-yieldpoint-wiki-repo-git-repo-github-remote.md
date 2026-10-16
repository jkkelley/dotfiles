---
{
  "id": "WO-20261016-7784",
  "slug": "yw-r-yieldpoint-wiki-repo-git-repo-github-remote",
  "title": "YW-R: YieldPoint wiki repo - git repo, GitHub remote, wiki.json, pages.json, review.json, AGENTS.md and CI",
  "type": "chore",
  "status": "draft",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T06:19:43+00:00",
  "parent": "WO-20261016-35de",
  "branch": null,
  "pr": null,
  "closed": null,
  "approval": null,
  "evidence": null,
  "surfaces": [],
  "depends_on": [
    "WO-20261016-d304",
    "WO-20261016-0b9c"
  ],
  "blocks": [
    "WO-20261016-b1b7",
    "WO-20261016-2013"
  ]
}
---

# WO-20261016-7784 - YW-R: YieldPoint wiki repo - git repo, GitHub remote, wiki.json, pages.json, review.json, AGENTS.md and CI

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

Owner words, verbatim: "MAKE SURE A KNOWLEDGE BASE WIKI OF YIELDPOINT AI IS BUILT AND USING DOC DESIGN FIRST AND PUT THAT SHIT IN THE ~/PROJECTS/YIELDPOINT/WIKI/<ALL SUB DIRS HERE INTAKE|RAW|PROCESS|I'M JUST MAKING SHIT UP TO SHOW>"; "good never examples"; "get everything centrally located for this yieldpoint stuff, i have a directory already in ~/projects". Architect ruling BR-20261016-yp-wiki: the wiki is ~/projects/yieldpoint-ai/wiki. ORD-0556 O1: the engine is a generic, config-driven dotfiles tool at claude/tools/wiki/, called as `make -C ~/dotfiles wiki-<verb> WIKI=<root>`; the YieldPoint wiki holds only config and content. This replaces business tickets YW0-YW7 (cancelled, superseded). Line node: WO-20261016-35de - Line build L2 - yp-wiki and wiki-review. Specific ticket: config only, no scripts (ORD-0556 O1). Orchestrator orders 2026-10-16 (MSG-20261016T061019Z-yp-design): ORD-0552 O2 'write each AC as command + expected exit code + expected output in the ticket text, and carry owner words verbatim and full context in Problem'; ORD-0555 O1 'before a ticket goes ready, list every tool, script, Make target and fixture its steps and AC checks call; any not on main gets a tooling ticket first'; ORD-0556 O1 'every tooling ticket builds a generic, config-driven tool in dotfiles'; ORD-0558 O1 'every design and ready ticket names the fallback for each tool and dependency it uses, the scripted switch with its status code, and a test case for the fallback path'.

## Scope

**In**

- `mkdir -p ~/projects/yieldpoint-ai/wiki && git -C ~/projects/yieldpoint-ai/wiki init -b main` (idempotent); seed commit on main with README.md (title and '## Contents') only
- `gh repo create jkkelley/yieldpoint-wiki --private --source ~/projects/yieldpoint-ai/wiki --remote origin --push`, skipped when `gh repo view jkkelley/yieldpoint-wiki` exits 0
- Branch chore/yw-r-config, then: wiki.json {intake_dir intake, raw_dir raw, processed_dir processed, index_dir index, blob_limit_bytes 1048576, max_page_lines 200, artifact_new 'make -s -C ~/dotfiles artifact-new KEY=context', review_dir '~/.local/state/zenith/inbox-triage/20261015/review'}; pages.json (the seven pages of YW-C); review.json [{page d18, title 'LinkedIn reply DAG', raw_source '~/dotfiles/docs/design/inbox-sweep.md'}, {page content, title 'Content Engine Review', raw_source '~/projects/business/ventures/yieldpoint-consulting/linkedin-content/design.md'}, {page wire, title 'LinkedIn Page Wireframes', raw_source '~/projects/business/ventures/yieldpoint-consulting/linkedin-page/wireframes/README.md', assets 'screenshot', asset_prefix 'yp-r2-'}]; .gitignore intake/
- AGENTS.md: title, '## Contents', then `bash ~/dotfiles/scripts/golden-rules.sh write AGENTS.md`; one line pointing at ~/dotfiles/docs/design/wiki.md
- .github/workflows/ci.yml: on pull_request, concurrency cancel-in-progress, actions/checkout pinned by full SHA, a second checkout of jkkelley/dotfiles at the full SHA of the WK5 merge into .dotfiles, step `make -C .dotfiles wiki-check WIKI=$GITHUB_WORKSPACE`
- Push and open the PR through the switch: bash ~/dotfiles/claude/workflow/bin/timed-run.sh --node yw-r-pr --fallback "git push -u origin HEAD && echo parked" --fallback-code FB-003 -- gh pr create --fill
- Tool: gh, the GitHub API (on this host). Fallback: push the branch with git and park the PR step with a ticket note; the line sweep opens the PR when gh answers. Switch: timed-run.sh --fallback ... --fallback-code FB-003 (status code FB-003; switch from WO-20261016-d304 - TR-FB: timed-run.sh --fallback CMD --fallback-code FB-NNN, the one scripted fallback switch, with the FB code catalog)
- Tool: scripts/golden-rules.sh (on main). Fallback: none needed, the tool is a file on main read locally; a missing file stops the step with exit 4

**Out - non-goals**

- Content pages (YW-C)
- Any script in the wiki repo

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [ ] `AC-H1` *(human)* `git -C ~/projects/yieldpoint-ai/wiki remote get-url origin` -> exit 0, output ends `yieldpoint-wiki.git`. Proof: command output
- [ ] `AC-H2` *(human)* `bash ~/dotfiles/scripts/golden-rules.sh check ~/projects/yieldpoint-ai/wiki/AGENTS.md` -> exit 0. Proof: command output
- [ ] `AC-H3` *(human)* `jq -e 'length==3' ~/projects/yieldpoint-ai/wiki/review.json` -> exit 0, output `true`. Proof: command output
- [ ] `AC-H4` *(human)* `FORCE_FALLBACK=1 bash ~/dotfiles/claude/workflow/bin/timed-run.sh --node yw-r-fb --fallback "echo parked" --fallback-code FB-003 -- false` -> exit 0, stderr contains `FALLBACK FB-003`. Proof: command output

## Test plan

```sh
jq -e 'length==3' ~/projects/yieldpoint-ai/wiki/review.json
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
