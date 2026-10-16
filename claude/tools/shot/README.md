# shot

<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->

- [Status lines](#status-lines)
- [Usage](#usage)
- [Make targets](#make-targets)
- [Fallback](#fallback)
- [Cleanup](#cleanup)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

Generic HTML page screenshot into the artifact store, by headless Chromium, size checked.
It exists because every visual DAG node needs a screenshot written by script to the store (Design principles 101 items 23 and 31).

## Status lines

| Exit | Line | Meaning |
| ---- | ---- | ------- |
| 0 | `SHOT-OK <path>` | PNG written to the store, path on stdout |
| 2 | `SHOT-USAGE` | unknown flag, missing `--html` or `--name`, size not `WxH` |
| 3 | `SHOT-SRC` | html file missing |
| 4 | `SHOT-NOBROWSER` | no executable browser; set `CHROME_BIN` |
| 4 | `SHOT-RENDER` | browser failed, timed out, empty file, not a PNG, or wrong size |

## Usage

`bash claude/tools/shot/shot.sh --html FILE --name SLUG [--size WxH] [--what TEXT]`

Default size is 1440x900.
Env: `CHROME_BIN`, `SHOT_TIMEOUT_S` (default 30), `ARTIFACT_ROOT`.

## Make targets

- `make -f claude/tools/shot/shot.mk shot HTML= NAME= [SIZE=] [WHAT=]`
- `make -f claude/tools/shot/shot.mk shot-test`
- `make -f claude/tools/shot/shot.mk shot-lint`

## Fallback

If the Make target fails to start, run `bash claude/tools/shot/shot.sh` with the same arguments, switched by `timed-run.sh --fallback ... --fallback-code FB-008`.
With no headless shell on a host, set `CHROME_BIN` to any Chromium.

## Cleanup

`make artifact-clean KEY=screenshot OLDER_THAN=days`
