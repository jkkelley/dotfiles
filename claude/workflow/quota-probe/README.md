# quota-probe

<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->

- [Contents](#contents)
- [What it is](#what-it-is)
- [Status codes](#status-codes)
- [Add a probe](#add-a-probe)
- [Make targets](#make-targets)
- [Gates](#gates)
- [Cleanup](#cleanup)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

## Contents

- What it is
- Status codes
- Add a probe
- Make targets
- Gates
- Cleanup

## What it is

A generic, config-driven probe of a rate-limited tool.
A systemd --user timer runs it once a day; it publishes a transition event on the bus only when the result changes.
The first entry is `figma` (FB-006 resume check).

## Status codes

| Code | Exit | Meaning |
| ---- | ---- | ------- |
| QUOTA-OK | 0 | command exited 0 and output matches ok_regex |
| QUOTA-OUT | 5 | output matches out_regex |
| QUOTA-ERR | 4 | anything else, including a timeout |
| QUOTA-CFG | 2 | unknown name or missing config |
| QPROBE-BUS | - | fallback: bus down, event appended to state_dir/events.jsonl, stderr `FALLBACK QPROBE-BUS <name>` |

## Add a probe

Add one entry under `probes` in config.json: command, ok_regex, out_regex, timeout_s, resumes.
No code changes.

## Make targets

Run as `make -C claude/workflow/quota-probe TARGET`: probe NAME=, install NAME=, uninstall NAME=, lint, status, test, dev, uat, stable, rollback, clean.

## Gates

dev = test (podman, stub publisher). uat = two selftest probes against the real bus. stable = install the figma timer.
rollback removes it.

## Cleanup

`make clean` removes `~/.local/state/zenith/quota-probe`.
