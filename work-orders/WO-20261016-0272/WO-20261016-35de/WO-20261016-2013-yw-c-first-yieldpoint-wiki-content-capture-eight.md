---
{
  "id": "WO-20261016-2013",
  "slug": "yw-c-first-yieldpoint-wiki-content-capture-eight",
  "title": "YW-C: first YieldPoint wiki content - capture eight sources and write the seven cited pages",
  "type": "feature",
  "status": "draft",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T06:19:55+00:00",
  "parent": "WO-20261016-35de",
  "branch": null,
  "pr": null,
  "closed": null,
  "approval": null,
  "evidence": null,
  "surfaces": [],
  "depends_on": [
    "WO-20261016-d304",
    "WO-20261016-7784",
    "WO-20261016-b9ba",
    "WO-20261016-b6a8",
    "WO-20261016-f963"
  ],
  "blocks": [
    "WO-20261016-5060",
    "WO-20261016-3787"
  ]
}
---

# WO-20261016-2013 - YW-C: first YieldPoint wiki content - capture eight sources and write the seven cited pages

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

Owner words, verbatim: "MAKE SURE A KNOWLEDGE BASE WIKI OF YIELDPOINT AI IS BUILT AND USING DOC DESIGN FIRST AND PUT THAT SHIT IN THE ~/PROJECTS/YIELDPOINT/WIKI/<ALL SUB DIRS HERE INTAKE|RAW|PROCESS|I'M JUST MAKING SHIT UP TO SHOW>"; "good never examples"; "get everything centrally located for this yieldpoint stuff, i have a directory already in ~/projects". Architect ruling BR-20261016-yp-wiki: the wiki is ~/projects/yieldpoint-ai/wiki. ORD-0556 O1: the engine is a generic, config-driven dotfiles tool at claude/tools/wiki/, called as `make -C ~/dotfiles wiki-<verb> WIKI=<root>`; the YieldPoint wiki holds only config and content. This replaces business tickets YW0-YW7 (cancelled, superseded). Line node: WO-20261016-35de - Line build L2 - yp-wiki and wiki-review. Brief: 'first content: the system map, services, brand, the LinkedIn page design, the content engine, the venture plan, each page cited'; AC4 'an agent can answer what does client-provisioner do from one processed page'. Orchestrator orders 2026-10-16 (MSG-20261016T061019Z-yp-design): ORD-0552 O2 'write each AC as command + expected exit code + expected output in the ticket text, and carry owner words verbatim and full context in Problem'; ORD-0555 O1 'before a ticket goes ready, list every tool, script, Make target and fixture its steps and AC checks call; any not on main gets a tooling ticket first'; ORD-0556 O1 'every tooling ticket builds a generic, config-driven tool in dotfiles'; ORD-0558 O1 'every design and ready ticket names the fallback for each tool and dependency it uses, the scripted switch with its status code, and a test case for the fallback path'.

## Scope

**In**

- Step 1: `git -C ~/projects/business pull --ff-only` and `git -C ~/dotfiles pull --ff-only` (both on main)
- Step 2: for each source ~/projects/yieldpoint-ai/CLAUDE.md, ~/projects/yieldpoint-ai/yieldpoint-client-provisioner/README.md, ~/projects/yieldpoint-ai/yieldpoint-ai-branding/README.md, ~/projects/business/ventures/yieldpoint-consulting/design.md, ~/projects/business/ventures/yieldpoint-consulting/linkedin-page/design.md, ~/projects/business/ventures/yieldpoint-consulting/linkedin-page/wireframes/README.md, ~/projects/business/ventures/yieldpoint-consulting/linkedin-content/design.md, ~/dotfiles/docs/design/inbox-sweep.md: `make -C ~/dotfiles wiki-intake WIKI=~/projects/yieldpoint-ai/wiki SRC=<source>`
- Step 3: pages.json (written by YW-R): system-map (platform; what-it-is, repos, how-they-connect), services (platform; client-provisioner, gitops, platform-infra, static-website), brand (brand; tokens, logo, voice), linkedin-page (linkedin; layout, revision-2), content-engine (linkedin; pipeline, humanize, jitter, preview), reply-dag (linkedin; owner-gate, states), venture-plan (venture; offers, sales, work-sourcing); `make -C ~/dotfiles wiki-process WIKI=~/projects/yieldpoint-ai/wiki`
- Step 4: write each TODO-WRITE section as short factual prose taken only from its cited raw files, each claim beside its [raw: ...] link; services#client-provisioner answers what the client provisioner does in its first paragraph
- Step 5: `make -C ~/dotfiles wiki-index WIKI=~/projects/yieldpoint-ai/wiki` then `make -C ~/dotfiles wiki-check WIKI=~/projects/yieldpoint-ai/wiki`
- Step 6: one line in ~/projects/yieldpoint-ai/CLAUDE.md under its contents list: 'Knowledge base: wiki/ (index wiki/index/README.md)'; the home is not a git repo, so the line is noted on this ticket
- Tool: make running the target (wiki verbs from WK1-WK4). Fallback: run the script the target wraps directly with the same arguments. Switch: timed-run.sh --fallback ... --fallback-code FB-008 (status code FB-008; switch from WO-20261016-d304 - TR-FB: timed-run.sh --fallback CMD --fallback-code FB-NNN, the one scripted fallback switch, with the FB code catalog)
- Tool: make -C ~/dotfiles artifact-new (make artifact-new on main). Fallback: bash ~/dotfiles/claude/tools/artifact/artifact.sh new with the same KEY NAME EXT. Switch: timed-run.sh --fallback ... --fallback-code FB-004 (status code FB-004; switch from WO-20261016-d304 - TR-FB: timed-run.sh --fallback CMD --fallback-code FB-NNN, the one scripted fallback switch, with the FB code catalog)
- Tool: gh, the GitHub API (PR step). Fallback: push the branch with git and park the PR step with a ticket note; the line sweep opens the PR when gh answers. Switch: timed-run.sh --fallback ... --fallback-code FB-003 (status code FB-003; switch from WO-20261016-d304 - TR-FB: timed-run.sh --fallback CMD --fallback-code FB-NNN, the one scripted fallback switch, with the FB code catalog)

**Out - non-goals**

- Any fact not in a cited raw file
- yieldpoint-ai-vault-* content
- Secrets, names of private people

## Degrees of freedom

- [free] wording of each section, as long as every sentence is supported by a cited raw file and each page stays under 200 lines

## Acceptance criteria

- [ ] `AC-H1` *(human)* `make -C ~/dotfiles wiki-check WIKI=~/projects/yieldpoint-ai/wiki` -> exit 0, output `WIKI-000`. Proof: command output
- [ ] `AC-H2` *(human)* `grep -c 'id="client-provisioner"' ~/projects/yieldpoint-ai/wiki/processed/services.md` -> exit 0, output `1`. Proof: command output
- [ ] `AC-H3` *(human)* `FORCE_FALLBACK=1 bash ~/dotfiles/claude/workflow/bin/timed-run.sh --node yw-c-fb --fallback "python3 ~/dotfiles/claude/tools/wiki/wiki_check.py $HOME/projects/yieldpoint-ai/wiki" --fallback-code FB-008 -- make -C ~/dotfiles wiki-check WIKI=$HOME/projects/yieldpoint-ai/wiki` -> exit 0, stderr contains `FALLBACK FB-008`. Proof: command output

## Test plan

```sh
make -C ~/dotfiles wiki-check WIKI=~/projects/yieldpoint-ai/wiki
```

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

- `2026-10-16` DESIGN-GAP (infra-design12): stays draft. The code repo ~/projects/yieldpoint-ai/wiki does not exist yet, and approve resolves step and AC tools in this dotfiles project until WO-20261016-e297 (approve --code-dir) and WO-20261016-f57d (ticket repo field) merge, so In cannot name repo files with a scope AC that approve can check. Also step 6 writes ~/projects/yieldpoint-ai/CLAUDE.md, outside any git repo, so no scope AC or PR can carry it; depends on WO-20261016-7784 - YW-R (draft)
- `2026-10-16` DRAFT until tool WO-20261016-d304 - TR-FB (timed-run.sh --fallback) is on main (ORD-0555 O1); then approve --no-lavish --reason "architect ruled design approvals done, ORD-0550 O4"

## Outcome

_Written by `work-order done`. Empty until then._
