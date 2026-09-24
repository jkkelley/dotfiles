# Execution Rail - the project-scaffold template

The Rail is the owner-facing tracker page for a numbered plan.
One JSON plan, one TSV ledger appended only by a script, one page that moves when and only when the ledger moves.

This directory is the **vendored, project-agnostic copy** that `project-scaffold` installs into a project.
Dotfiles owns this copy outright.
It names no project, no investigation directory, and no owner path, so any project scaffolded from this skill adopts it unchanged.

## What gets installed into a project

```
report/
  rail.sh        the wrapper, rendered from rail.sh.tmpl with this project's four facts
  plan.json      the plan, committed
  side.html      optional folded panels, committed
  rail/
    bin/ledger.sh      append a row, print the same line
    bin/rail-build.sh  render plan + ledger into one HTML file
    assets/template.html
```

The ledger, the built page and the approval marker are **state, not source**.
They live under `~/.local/state/<project>-<key>/rail/` and never enter git.
What is committed is the plan, the side panels and the wrapper - the inputs, never the render.

## Surface routing - which model is driving decides where the page goes

A Kimi seat cannot mint a `claude.ai` artifact URL; that URL comes from a Claude-only tool.
A seat asked for an owner-facing page with no way to produce one either invents a URL or produces nothing, and an invented URL looks like success in the transcript.

So the surface is **data set at spawn time, never a judgement made by the model**:

| `RAIL_SURFACE` | Seat runtime             | Where the page goes                                                             |
| -------------- | ------------------------ | ------------------------------------------------------------------------------- |
| `lavish`       | kimi, codex, any runtime | `lavish-axi page.html`, served at a local `127.0.0.1` session URL               |
| `artifact`     | claude                   | the Artifact tool, republished to the one URL recorded in `report/ARTIFACT-URL` |

Unset falls back to `lavish`, which every runtime can open.
The workflow declaration names the runtime, so the spawner exports `RAIL_SURFACE` and no seat ever has to work it out.

## The one address rule

The page lives at one address for the life of the plan.
A second address strands every link the owner already holds.
For the artifact surface that address is recorded in `report/ARTIFACT-URL`; for lavish it is the session URL of the same file path.
Never publish a rebuilt page to a new address.

## Usage

```sh
./report/rail.sh log E-03 complete "Storage refactor green in Podman, both images"
./report/rail.sh publish
./report/rail.sh show 20
./report/rail.sh approve          # once, when the owner gives the signal
./report/rail.sh surface          # prints lavish or artifact
```

`log` rebuilds automatically.
The page is never hand-edited and never re-read to check it - the build is deterministic, and the only verification that matters is the owner opening it.

## Rules

- The plan document is the source of truth. The page is its view. Nothing appears on the page that is not in `plan.json` or the ledger.
- Republish only after a ledger row.
- Status is one of `started complete blocked issue question checkpoint`. Text is fifteen words or fewer - the limit is enforced, not advised.
- Step ids look like `E-01`. Keep them identical to the plan document.
- Timestamps are UTC, from `date -u`.

## Provenance

Design locked by Zenith 2026-09-21 from the rime execution plan page; Drive standard `EXECUTION-RAIL_v1.0.0`.
Vendored here from `~/.claude/skills/execution-rail` v1.0.1 on 2026-09-22 and de-personalised: `RIME_LEDGER` became `RAIL_LEDGER` with no default, `RIME_SEAT` became `RAIL_SEAT`.
Do not redesign the page. Change it by a new version of this template beside the old one.
