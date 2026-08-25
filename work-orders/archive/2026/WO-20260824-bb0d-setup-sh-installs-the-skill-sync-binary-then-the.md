---
{
  "id": "WO-20260824-bb0d",
  "slug": "setup-sh-installs-the-skill-sync-binary-then-the",
  "title": "setup.sh installs the skill-sync binary, then the SessionStart hook",
  "type": "feature",
  "status": "done",
  "priority": "p1",
  "created": "2026-08-24",
  "updated": "2026-08-25",
  "created_at": "2026-08-24T13:19:08-05:00",
  "parent": "WO-20260824-f1a5",
  "branch": "feat/setup-sh-installs-the-skill-sync-binary-then-the",
  "pr": 72,
  "merge_sha": null,
  "closed": "2026-08-25",
  "approval": {
    "via": "override",
    "reason": "Reviewed and approved on PR #55 on GitHub, which is where the whole cut was read as one diff. Lavish was offered and declined in favour of the PR.",
    "at": "2026-08-24"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [
    "WO-20260824-0615",
    "WO-20260824-efb0"
  ],
  "blocks": [
    "WO-20260824-316d"
  ]
}
---

# WO-20260824-bb0d - setup.sh installs the skill-sync binary, then the SessionStart hook

## Problem

The hook fires in every project on this machine, so it cannot be installed before the binary it calls exists, and it cannot be noisy in a project with no manifest - which is almost every project here. A hook that prints something irrelevant at every session start gets deleted by whoever is annoyed by it first, and the whole system goes with it.

## Scope

**In**

- installing skill-sync to ~/.local/bin, beside the existing -axi tools
- adding the SessionStart hook to ~/.claude/settings.json with a 30 second timeout, after the binary
- the matcher form decided by the matcher spike
- idempotency: running setup.sh twice does not produce two hooks

**Out - non-goals**

- per-project hook installation - this hook is machine level

## Acceptance criteria


- [x] `AC-H1` *(human)* a session started in a project with no .claude/skills.toml prints nothing at all
  - observed `2026-08-25` Rung 5, on the host and manual - a SessionStart hook cannot be produced inside Podman, so this one check is stated rather than containerised. setup.sh was run against the real ~/.claude, then a real headless session was started in a scratch project with no .claude/skills.toml: claude -p --session-id 89d8ba5b-472c-4c42-8762-da2eef785d95. stdout carried the model's reply and nothing else, stderr was empty, and no .claude/ directory was created. The transcript is the load-bearing part, for the same reason WO-20260824-0615 kept a control matcher: SessionStart:startup is recorded in it and all three pre-existing -axi hooks produced output there, so the hooks demonstrably fired, and skill-sync appears in that transcript exactly 0 times. Silence, not a hook that failed to run. The containerisable half is in claude/tools/testing/run-tests.sh: the binary setup.sh installed exits 0, writes nothing and prints nothing on either stream in a directory with no manifest.
- [x] `AC-H2` *(human)* running setup.sh twice leaves exactly one SessionStart hook in settings.json
  - observed `2026-08-25` Observed twice. Rung 2, in Podman: claude/tools/testing/run-tests.sh drives setup.sh against a fake HOME under the scratch mount and counts the entries with jq rather than by eye - a second run exits 0 and leaves exactly one skill-sync hook, a third run is still one, and the run adds no SessionStart entry of any kind. Rung 3 covers the settings.json a real machine actually has: an unrelated top-level key, a PostToolUse hook and an unrelated SessionStart hook all survive, and a second run over that file duplicates none of them. A stale skill-sync entry carrying an older matcher is replaced rather than accumulated beside, which is why the jq drops by command rather than by exact-entry equality. The assertions were proved able to fail: removing the dedupe from setup.sh turned exactly those six checks red and nothing else. And on the real machine - setup.sh run twice against ~/.claude/settings.json, which went from 3 SessionStart entries to 4 and stayed at 4, with the skill-sync count 1 after both runs and lavish-axi, gh-axi and chrome-devtools-axi untouched.

## Test plan

```sh
a container with a fake HOME proves idempotency; the silence criterion is observed in a real session
```

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

- `2026-08-25` Two contradictions worth stating rather than quietly resolving. The ticket says the binary goes to ~/.local/bin 'beside the existing -axi tools'. On this machine the -axi tools are in ~/.npm-global/bin, not ~/.local/bin. The named path wins - both the plan's E1.9 and this ticket say ~/.local/bin explicitly, and ~/.local/bin is what already holds shellcheck, treehouse and no-mistakes - so the prose is what is wrong, not the path. Separately, the tools test image gained jq. It is the only thing in claude/tools/ that needs it and it is deliberately not stubbed, because a stubbed jq proves nothing about a JSON edit. The hazard the Containerfile's own comment warns about - an image carrying a binary the code must not depend on hides a dependency until someone else's machine finds it - is answered with an assertion rather than a promise: the suite checks that no runnable line of skill-sync.sh names jq. setup.sh's own missing-jq branch runs against a hand-built PATH rather than against the image, because that is the Git Bash case and it has to fail as a refusal rather than as a sed into JSON. The image tag moved from :1 to :2 for the same reason Rule 15 exists - podman image exists only builds when the tag is absent, so an edited Containerfile under an unchanged tag leaves every machine that already ran this suite on the old image.
- `2026-08-25` Three decisions taken in the open, none of them in the plan. (1) The binary is always a COPY, never a symlink, whatever INSTALL_TYPE says. skill-sync replaces itself in place when the registry publishes a newer version - mv self self.bak, then curl - so a symlink would be swapped for a real file on the first self-update, silently turning a live link to the repo into a stale copy nobody knows is stale. (2) The binary and the hook are machine level and are NOT derived from --dest. A --dest run installs skills into that project and still writes the hook to ~/.claude/settings.json, because the hook fires in every project on the machine. There is a check for it. (3) The empty selection no longer exits early. 'Nothing valid to install. Exiting without changes.' became false the moment the tool and the hook were installed on every run, and 'install the hook on a machine whose skills are already in place' is a real run to want - it is the one used for rung 5 here. The summary lists the tool and the hook, and the confirmation prompt is still the only thing that lets anything be written; declining it writes neither.
- `2026-08-24` Poker 2026-08-24: 3 points. Two steps in a fixed order; idempotency is the only trap.

## Outcome

_Written by `work-order close`. Empty until then._
