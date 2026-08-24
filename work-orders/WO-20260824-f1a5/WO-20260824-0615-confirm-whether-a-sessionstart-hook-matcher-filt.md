---
{
  "id": "WO-20260824-0615",
  "slug": "confirm-whether-a-sessionstart-hook-matcher-filt",
  "title": "Confirm whether a SessionStart hook matcher filters by source",
  "type": "spike",
  "status": "done",
  "priority": "p1",
  "created": "2026-08-24",
  "updated": "2026-08-24",
  "created_at": "2026-08-24T13:19:06-05:00",
  "parent": "WO-20260824-f1a5",
  "branch": "feat/confirm-whether-a-sessionstart-hook-matcher-filt",
  "pr": 58,
  "merge_sha": null,
  "closed": null,
  "approval": {
    "via": "override",
    "reason": "Reviewed and approved on PR #55 on GitHub, which is where the whole cut was read as one diff. Lavish was offered and declined in favour of the PR.",
    "at": "2026-08-24"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [],
  "blocks": [
    "WO-20260824-bb0d"
  ]
}
---

# WO-20260824-0615 - Confirm whether a SessionStart hook matcher filters by source

## Problem

The design's safety property is that the sync never runs on a compact. That depends entirely on SessionStart matchers accepting a source string, and every hook in settings.json on this machine uses an empty matcher, so there is no working example of the filtered form anywhere. The property is unobservable from a unit test and has to be watched happening.

## Scope

**In**

- a scratch project with a SessionStart hook whose matcher is the literal startup
- starting, resuming, clearing and force-compacting a session and recording which fired

**Out - non-goals**

- writing the real hook, which setup.sh owns
- any change to skill-sync.sh, which only happens if the answer is no

## Acceptance criteria


- [x] `AC-H1` *(human)* the four sources are each exercised and which of them fired is written down
  - observed `2026-08-24` All four sources exercised against a scratch project carrying three SessionStart entries. matcher 'startup' fired on startup only (15:12:35, 15:12:46) and not on resume, clear or compact. matcher 'startup|resume|clear' fired on startup, resume and clear (15:12:35, 15:12:40, 15:12:46, 15:13:05) and not on compact. The control matcher '' fired on all four (…plus compact at 15:14:49), which is what proves each event genuinely occurred rather than a session failing to start.
- [x] `AC-H2` *(human)* the ticket records the resulting decision: either the matcher form for setup.sh, or that skill-sync.sh must read the source from stdin and exit early itself
  - observed `2026-08-24` Matchers do filter. The decision recorded on this ticket and in the note below: WO-20260824-bb0d uses the matcher form 'startup|resume|clear', which is confirmed working rather than assumed. WO-20260824-5b89 gains no scope: skill-sync.sh needs no stdin read and no self-imposed early exit on compact.

## Test plan

```sh
manual, rung 5 of the ladder. A scratch project, a hook that appends its stdin payload to a file, and four real session events
```

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

- `2026-08-24` ANSWER: SessionStart matchers filter by source, and alternation is honoured. The design's safety property is available from the matcher alone. Truth table, Claude Code 2.1.220, scratch project outside this repository, one hook script appending its stdin payload and an ISO timestamp to a per-entry log: | source | matcher "startup" | matcher "startup|resume|clear" | matcher "" (control) | | ------- | ----------------- | ----------------------------- | ------------------- | | startup | fired | fired | fired | | resume | - | fired | fired | | clear | - | fired | fired | | compact | - | - | fired | The control entry is the load-bearing part of the design. Without it a hook that did not fire is indistinguishable from a session event that never happened, and that is the one confusion that would make the whole result wrong. The payload on stdin is {cwd, hook_event_name, session_id, source, transcript_path}, so the source is readable from stdin as well - but it does not have to be, which is the point. How each event was produced. startup and resume ran headless: 'claude -p --session-id <uuid>' then 'claude -p --resume <uuid>'. clear and compact cannot be produced headlessly and ran in a genuine interactive session driven through tmux, which supplies the real TTY. /compact refuses with 'Not enough messages to compact' on a short conversation, so the session was given six turns first; that refusal is a no-op and fires nothing. Rule 14 note: this experiment cannot run in Podman. A SessionStart hook fires from a real interactive Claude Code session on the host and there is no way to produce a genuine resume or compact inside a container. The ticket's own test plan calls this rung 5 and manual. Stated, not quietly skipped. Consequences for other tickets: - WO-20260824-bb0d - setup.sh installs the skill-sync binary, then the SessionStart hook: uses "matcher": "startup|resume|clear". Confirmed working, not assumed. - WO-20260824-5b89 - skill-sync.sh part one: resolution, and the tools test tree it is proved in: unchanged. No stdin read, no self-imposed early exit on compact. The no-answer branch did not happen. ~/.claude/settings.json was not touched. The scratch project was deleted afterwards.
- `2026-08-24` Poker 2026-08-24: 3 points. Small work, high fiddliness: forcing a compact costs a real context window, and a no answer adds scope to skill-sync.sh.

## Outcome

_Written by `work-order close`. Empty until then._
