# Inbox sweep

<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->

- [Contents](#contents)
- [Platform](#platform)
- [Use](#use)
- [Where things live](#where-things-live)
- [Cleanup](#cleanup)
- [Tests](#tests)
- [Design](#design)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

One command reads three inboxes (Gmail, Proton, LinkedIn) through seats, summarises them, and puts anything that needs the owner on a Bearings card.
It reads and it marks read.
It never sends, replies, deletes or archives (design D1).

## Contents

- Platform
- Use
- Where things live
- Cleanup
- Tests
- Design

## Platform

WSL only (design D2).
The controller needs herdr, Windows interop (`cmd.exe`, `powershell.exe`, `claude.exe`) and the Windows home, where run dirs live.
Per dotfiles Rule 17 it says so here and ships no justfile.
Every `make` target is one plain `bash bin/sweep.sh ...` call, so `make` itself is optional.

## Use

Run from this directory, inside herdr.

| Command | What it does |
| --- | --- |
| `make sweep` | Start a run of every enabled seat; prints the run id and returns in under 5 seconds |
| `make sweep-gmail`, `sweep-proton`, `sweep-linkedin` | The same for one source |
| `make status [RUN=<run-id>]` | Run code, each seat's status and deadline; the latest run by default |
| `make clean [RUN=<run-id>]` | Take a finished run down |
| `make prune [DAYS=14]` | Remove runs older than DAYS |
| `make test`, `make test-all` | Podman suites; `make help` lists every target |

`make sweep` creates a herdr tab `inbox-sweep` whose pane `sweep-ctl` runs the whole run in the foreground, so the owner watches it there.
The pane renames itself `sweep-ctl <run-id> <status>` when the run ends, and the last two lines it prints are the run code and the path of `summary.md`.

A run needs two owner files, which no target ever removes: `~/.config/zenith/inbox-sweep/config.json` and `~/.config/zenith/inbox-sweep/owner-words.md`.
Without owner words `start` refuses with `PF-NO-OWNER-WORDS` and creates nothing.

## Where things live

| What | Where |
| --- | --- |
| Run dir (run.json, briefs, results, proof, logs, summary) | `<win-home>/.local/state/zenith/inbox-sweep/runs/<run-id>/` |
| Latest run | `~/.local/state/zenith/inbox-sweep/latest` |
| Seat dirs and record rows | `~/.local/state/dotfiles/execution/seats/` and `records/` |
| Bearings cards | `~/.bearings/inbox-sweep/questions.json` |

## Cleanup

Outputs live outside the repository.
Each one has exactly one command that removes it.

| Output | Command |
| --- | --- |
| Run dir | `make prune DAYS=14` |
| `latest` symlink | `make prune` (removes it when dangling) |
| Briefs | `make clean RUN=<run-id>` |
| Seat tabs | `make clean RUN=<run-id>` |
| Seat dirs | `make clean RUN=<run-id>` |
| Record rows | `make prune DAYS=14` |
| Bearings page | `node ~/.claude/skills/bearings/scripts/server.mjs inbox-sweep --stop`, then `rm -rf ~/.bearings/inbox-sweep` |
| Proof screenshots and verdict | `make prune DAYS=14` |
| Test output | `make clean` with no run |

`config.json` and `owner-words.md` are never removed by any target.
`make clean` refuses a run that is still `RUN-RUNNING`.

## Tests

Every suite runs in Podman on the pinned workflow test image with `--network=none` (Rule 14).
`make test` runs only the suites whose files changed against `origin/main`; `make test-all` runs every suite and is run once before a pull request.
`tests/unit/test_controller.sh` is the integration test: the real scripts, with `herdr`, `claude.exe`, `powershell.exe` and the spawner stubbed.

## Design

`docs/design/inbox-sweep.md` is the design, and `docs/design/inbox-sweep.spec.xml` is the spec.
Status codes (`PF-*`, seat, `RUN-*`, `CLEAN-*`) are mapped in the spec under `codes`.
