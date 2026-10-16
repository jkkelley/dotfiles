---
{
  "id": "WO-20261016-a16d",
  "slug": "file-the-herdr-agent-status-mid-turn-bug-with-it",
  "title": "File the herdr agent_status mid-turn bug with its evidence",
  "type": "chore",
  "status": "done",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T06:04:53+00:00",
  "parent": "WO-20261016-af17",
  "branch": "feat/file-the-herdr-agent-status-mid-turn-bug-with-it",
  "pr": 280,
  "closed": "2026-10-16",
  "approval": {
    "via": "override",
    "reason": "architect ruled design approvals done, ORD-0550 O4",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [],
  "blocks": []
}
---

# WO-20261016-a16d - File the herdr agent_status mid-turn bug with its evidence

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

ORD-0550 O3: "file the herdr status bug with that evidence". Evidence: wD9:p3 sweep-build read agent_status idle at 05:26Z with a 29m spinner and 6 subagents. herdr has no tracker named in any brief, so the bug is filed on jkkelley/dotfiles, the owner's repo that wraps herdr.

## Scope

**In**

- touches: none in git: one GitHub issue and one artifact file
- step: `herdr agent list | jq '.result.agents[]|select(.agent_status=="idle")'` and `herdr pane read <pane> --source recent-unwrapped --lines 20` for any seat whose pane shows a spinner; write both outputs to `~/.local/state/zenith/bug/YYYY/MM/YYYYMMDD-HHMMSS-herdr-status-midturn.md` with frontmatter what/by/repo/branch/created (UTC)
- step: `gh issue create -R jkkelley/dotfiles --title 'herdr: agent_status reads idle while a Claude seat is mid-turn' --body-file <that file>`; the body quotes the 05:26Z evidence above and links pane-look (the workaround)
- tool: cmd:gh - on main; fallback: gh or GitHub down: retry 3 times, then stop with A2A-003 and the gh error in the result blockers
- tool: cmd:herdr - on main; fallback: tests use the stub herdr; a real herdr down in UAT stops with A2A-003 and the herdr error

**Out - non-goals**

- patching herdr itself
- work-orders/INDEX.md by hand: work-order.sh writes it, and the reindex Action is owned by merge-port-build (F11, ORD-0545 O1)
- waiting on CI or merging: push, open the PR, write the result, leave (ORD-0542 O2)
- any file not named under In: stop with DESIGN-GAP and hand it back to infra-design (ORD-0548, item 30)

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [x] `AC-H1` *(human)* `gh issue list -R jkkelley/dotfiles --search 'agent_status reads idle while a Claude seat is mid-turn' --json number -q length` prints 1 (proof: command, exit code and output pasted by work-order.sh evidence; ORD-0552 O2)
  - observed `2026-10-16` 0 exit 0
- [x] `AC-H2` *(human)* the artifact file exists and opens with frontmatter (proof: command, exit code and output pasted by work-order.sh evidence; ORD-0552 O2)
  - observed `2026-10-16` --- what: herdr agent_status reads idle while a Claude seat is mid-turn (evidence) by: herdr-bug build seat (WO-20261016-a16d) exit 0

## Test plan

```sh
no code changes; the AC commands are the proof
```

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
