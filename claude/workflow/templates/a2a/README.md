# Agent to agent briefs and results

<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->

- [Why](#why)
- [Files](#files)
- [Status codes](#status-codes)
- [Commands](#commands)
- [GOOD and NEVER](#good-and-never)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

## Why

Owner, 2026-10-16 UTC: "agent to agent prose sucks, schemas with defined AC always".
Every brief and result between agents is JSON valid against a schema, and every one carries acceptance criteria with the proof that ticks each.
Prose is for the owner only.

## Files

- `schemas/brief.schema.json` is `zenith.a2a.brief.v1`: the compaction-guard a2a envelope plus `acceptance_criteria` (at least one) and `done_token`.
- `schemas/result.schema.json` is `zenith.a2a.result.v1`: a done result ticks every criterion with proof.
- `templates/a2a/brief.json` and `result.json` are the starting points.
- `migrations/brief/<schema id with / as _>.jq` upgrades one schema version to the next; `brief.sh migrate` chains them.

## Status codes

| Code | Meaning | Who acts |
| --- | --- | --- |
| A2A-001 | brief issued | receiving seat |
| A2A-002 | result done, every AC ticked | orchestrator |
| A2A-003 | result blocked, blockers listed | orchestrator re-routes |
| A2A-004 | SOP breach: error raised without repro or screenshot evidence; claim dropped | orchestrator files the checklist gap as a work order against the design |
| DESIGN-GAP | a build brief names no ready work order, or a ready work order lacks a file, command, test plan or AC; seat not started or stopped | orchestrator routes it to the design seat; the design seat cuts or fixes the work order |
| PERM-MISSING | blocked on a missing permission for approved work; exact permission and evidence attached; node stopped | orchestrator forwards to the architect at once, architect hotfixes, a work order designs it in |
| FB-001 | pinned image pull failed; ran from the cached digest: podman run on the pinned image -> --pull=never on the cached digest | nobody when rc 0, orchestrator when not |
| FB-002 | network sync failed; ran offline from the lock: uv sync over the network -> --pull=never and uv sync --locked --offline | nobody when rc 0, orchestrator when not |
| FB-003 | gh failed; pushed with git, PR step parked: gh -> git push and park the PR step with a note | nobody when rc 0, orchestrator when not |
| FB-004 | make target failed; ran the wrapped script: make artifact-new -> artifact.sh new | nobody when rc 0, orchestrator when not |
| FB-005 | Figma screenshot failed; took a browser screenshot: Figma get_screenshot -> Claude in Chrome screenshot | nobody when rc 0, orchestrator when not |
| FB-006 | use_figma failed; step parked with a note: Figma use_figma -> park with a note | nobody when rc 0, orchestrator when not |
| FB-007 | herdr unreachable; read seats from the process table: herdr -> pgrep -af claude and /proc/<pid>/cwd | nobody when rc 0, orchestrator when not |
| FB-008 | make target failed; ran the script directly: make target -> the wrapped script directly | nobody when rc 0, orchestrator when not |
| FALLBACK | primary failed, fallback ran, rc is the fallback's (`timed-run.sh --fallback`, catalog `config/fallbacks.json`) | nobody when rc 0, orchestrator when not |

A2A-004 is Design principles 101 item 31 (owner, 2026-10-16 UTC): a claim without a reproduction or clear screenshot is dropped, and the node checklist that let it through is the defect.

PERM-MISSING is Design principles 101 item 36 (owner, 2026-10-16 UTC): the seat prints `PERM-MISSING <exact permission>` on its own line, writes the permission and its evidence into its result blockers, and stops that node.

## Commands

```bash
bin/brief.sh new --config cfg.json --out brief.json
bin/brief.sh check brief.json
bin/brief.sh result-check result.json --brief brief.json
bin/brief.sh migrate old-brief.json --out brief.json
```

## GOOD and NEVER

GOOD: the spawner is given `--brief brief.json`, refuses it if `brief.sh check` fails, and tells the seat only the path.
NEVER: pasting a brief as prose into a pane, or marking a result done with an AC unticked.

GOOD: an old brief upgraded with `brief.sh migrate`.
NEVER: hand-editing a brief to fit a new schema.
