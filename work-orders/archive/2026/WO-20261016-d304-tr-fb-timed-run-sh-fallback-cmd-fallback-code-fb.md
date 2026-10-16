---
{
  "id": "WO-20261016-d304",
  "slug": "tr-fb-timed-run-sh-fallback-cmd-fallback-code-fb",
  "title": "TR-FB: timed-run.sh --fallback CMD --fallback-code FB-NNN, the one scripted fallback switch, with the FB code catalog",
  "type": "feature",
  "status": "done",
  "priority": "p1",
  "created": "2026-10-16",
  "updated": "2026-10-16",
  "created_at": "2026-10-16T06:18:02+00:00",
  "parent": "WO-20261016-0272",
  "branch": "feat/tr-fb-timed-run-sh-fallback-cmd-fallback-code-fb",
  "pr": 223,
  "closed": "2026-10-16",
  "approval": {
    "via": "override",
    "reason": "architect ruled design approvals done, ORD-0550 O4",
    "at": "2026-10-16"
  },
  "evidence": null,
  "surfaces": [],
  "depends_on": [],
  "blocks": [
    "WO-20261016-adfd",
    "WO-20261016-474f",
    "WO-20261016-6e7f",
    "WO-20261016-96c4",
    "WO-20261016-b9ba",
    "WO-20261016-168d",
    "WO-20261016-b6a8",
    "WO-20261016-0b9c",
    "WO-20261016-6584",
    "WO-20261016-7784",
    "WO-20261016-2013",
    "WO-20261016-3787",
    "WO-20261016-35de",
    "WO-20261016-2e9f",
    "WO-20261016-a8eb",
    "WO-20261016-8454"
  ]
}
---

# WO-20261016-d304 - TR-FB: timed-run.sh --fallback CMD --fallback-code FB-NNN, the one scripted fallback switch, with the FB code catalog

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

Order ORD-0558 O1 verbatim: 'every design and ready ticket names the fallback for each tool and dependency it uses, the scripted switch with its status code, and a test case for the fallback path (item 28 amended)'. Owner item 28: 'graceful recovery and idempotentency, automation forever NEVER HAND FED'. Owner item 37: 'One shared wrapper script does the timing, the timeout and the bus events for every Make target'. Inventory: claude/workflow/bin/timed-run.sh (dotfiles #170) is that wrapper and has no fallback; no other dotfiles tool switches to a fallback (grep fallback over scripts/, claude/workflow/bin, claude/tools: none). So the switch extends timed-run.sh rather than adding a second wrapper (principle 4). Bootstrap: this ticket cannot use the switch it builds, so its own steps carry an inline `||` switch. Orchestrator orders 2026-10-16 (MSG-20261016T061019Z-yp-design): ORD-0552 O2 'write each AC as command + expected exit code + expected output in the ticket text, and carry owner words verbatim and full context in Problem'; ORD-0555 O1 'before a ticket goes ready, list every tool, script, Make target and fixture its steps and AC checks call; any not on main gets a tooling ticket first'; ORD-0556 O1 'every tooling ticket builds a generic, config-driven tool in dotfiles'; ORD-0558 O1 'every design and ready ticket names the fallback for each tool and dependency it uses, the scripted switch with its status code, and a test case for the fallback path'.

## Scope

**In**

- claude/workflow/bin/timed-run.sh: new flags `--fallback CMD` (run with bash -c) and `--fallback-code CODE` (required with --fallback, must match ^FB-[0-9]{3}$, else exit 2)
- Behaviour: without --fallback nothing changes. With it: when the primary exits non-zero, or every attempt timed out, run CMD once under the same timeout; publish `line.<L>.event.node.fallback` {code, primary_rc, rc} through tm_event; print `FALLBACK <CODE> <node>` on stderr; exit with CMD's exit code. `FORCE_FALLBACK=1` skips the primary (the test path every ticket's plan uses)
- Breadcrumb comment at the new flags: what it is for (ORD-0558 O1), rejected alternative (a second wrapper script), cost (one more branch in the hot path)
- claude/workflow/config/fallbacks.json: catalog keyed by code: FB-001 podman pinned image -> --pull=never on the cached digest; FB-002 podman uv network sync -> --pull=never and uv sync --locked --offline; FB-003 gh -> git push and park the PR step with a note; FB-004 make artifact-new -> artifact.sh new; FB-005 Figma get_screenshot -> Claude in Chrome screenshot; FB-006 Figma use_figma -> park with a note; FB-007 herdr -> pgrep -af claude and /proc/<pid>/cwd; FB-008 make target -> the wrapped script directly; each row {tool, primary, fallback, meaning, who_acts}
- claude/workflow/templates/a2a/README.md status code table: one row per FB-001..FB-008 plus FALLBACK (meaning: primary failed, fallback ran, rc is the fallback's; who acts: nobody when rc 0, orchestrator when not)
- claude/workflow/tests/unit/test_timed_run_fallback.sh: cases primary ok (fallback not run), primary rc 3 (fallback runs, FALLBACK line, rc of fallback), all timeouts (fallback runs), FORCE_FALLBACK=1, bad code exit 2, no --fallback unchanged; bus calls stubbed as in the existing timing tests
- Inline switch for this ticket's own test step: `make -C ~/dotfiles/claude/workflow image || { echo FB-001; podman image exists localhost/dotfiles-workflow-test:1; }`
- Tool: make -C ~/dotfiles/claude/workflow image and podman (on main). Fallback: FB-001 inline as above
- Tool: claude/workflow/timing/lib.sh tm_event (on main). Fallback: none needed, a local file; the bus being down is already handled by tm_event

**Out - non-goals**

- Any caller change; tickets adopt the switch in their own steps
- A second wrapper script

## Degrees of freedom

- [fixed] None declared: implement exactly as specified; raise a question before deviating.

## Acceptance criteria

- [x] `AC-H1` *(human)* `podman run --rm --network=none --userns=keep-id -v ~/dotfiles:/work:Z -w /work -e HOME=/tmp localhost/dotfiles-workflow-test:1 bash claude/workflow/tests/unit/test_timed_run_fallback.sh` -> exit 0, output ends with `ok` for every case and no `FAIL`. Proof: command output
  - observed `2026-10-16` exit 0; 8 cases ok, pass=8 fail=0, no FAIL
- [x] `AC-H2` *(human)* `FORCE_FALLBACK=1 bash claude/workflow/bin/timed-run.sh --node tp --fallback 'true' --fallback-code FB-001 -- false` -> exit 0, stderr contains `FALLBACK FB-001 tp`. Proof: command output
  - observed `2026-10-16` exit 0; stderr: FALLBACK FB-001 tp
- [x] `AC-H3` *(human)* `bash claude/workflow/bin/timed-run.sh --node tp --fallback 'true' --fallback-code BAD -- true` -> exit 2, stderr contains `fallback-code`. Proof: command output
  - observed `2026-10-16` exit 2; stderr: timed-run: --fallback needs --fallback-code matching FB-NNN
- [x] `AC-H4` *(human)* `jq -r 'keys|join(" ")' claude/workflow/config/fallbacks.json` -> exit 0, output `FB-001 FB-002 FB-003 FB-004 FB-005 FB-006 FB-007 FB-008`. Proof: command output
  - observed `2026-10-16` exit 0; FB-001 FB-002 FB-003 FB-004 FB-005 FB-006 FB-007 FB-008

## Test plan

```sh
podman run --rm --network=none --userns=keep-id -v ~/dotfiles:/work:Z -w /work -e HOME=/tmp localhost/dotfiles-workflow-test:1 bash claude/workflow/tests/unit/test_timed_run_fallback.sh
```

## Assumptions

_none_

## Open questions

_none_

## Notes

_Newest first. Appended only by `work-order note` - never by hand._

## Outcome

_Written by `work-order done`. Empty until then._
