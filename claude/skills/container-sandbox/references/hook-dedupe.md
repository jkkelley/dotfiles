# Hook dedupe across global and project settings

<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->

- [Contents](#contents)
- [Verdict](#verdict)
- [Documented behavior](#documented-behavior)
- [Empirical test](#empirical-test)
- [Caveats](#caveats)
- [Fallback](#fallback)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

## Contents

- [Verdict](#verdict)
- [Documented behavior](#documented-behavior)
- [Empirical test](#empirical-test)
- [Caveats](#caveats)
- [Fallback](#fallback)

## Verdict

<a id="verdict"></a>

Proven.
Claude Code runs an identical hook command once per event, even when it appears in both `~/.claude/settings.json` and `<project>/.claude/settings.json`.
A global `compaction-guard hook` install does not double-fire in a project that already carries a project-level install.

## Documented behavior

<a id="documented-behavior"></a>

The Claude Code hooks reference says: "All matching hooks run in parallel, and identical handlers are deduplicated automatically. Command hooks are deduplicated by command string and `args`, and HTTP hooks are deduplicated by URL."
Source: hooks.md in the Claude Code docs, retrieved through context7 (`/pjbrito/claude-code-docs`, a mirror of the official docs).
The hooks guide repeats it: "identical hook commands are automatically deduplicated."
The docs do not name settings sources explicitly, so the empirical test below closes that gap.

## Empirical test

<a id="empirical-test"></a>

Run with the real `claude` binary (2.1.296) in Podman, offline.
Image: `docker.io/library/debian@sha256:328d16499860ae6cb9b345e2e4cebca08c2a36e4f7278482c7bd1f39d71e5bfd` (debian stable-slim, amd64).
Flags: `--network=none`, `HOME` pointed at a scratch directory, the binary mounted read-only, so the real `~/.claude` is never touched.
`SessionStart` fires before authentication, so `claude -p hi` fires the hook even though the run ends with "Not logged in".
The hook command is `echo ran >> /work/count.log`.

| Case                                              | Lines in count.log |
| ------------------------------------------------- | ------------------ |
| Global settings only                              | 1                  |
| Same command in global and project settings       | 1                  |
| Different commands in global and project settings | 2                  |

The third row is the control.
It proves the project settings file was loaded and that dedupe is by command string, not a blanket skip.
No dedupe logic was reimplemented; the count comes from the real binary.

## Caveats

<a id="caveats"></a>

Dedupe is by exact command string and `args`.
`compaction-guard hook` in one file and `/abs/path/compaction-guard hook` in the other are different strings and both run.
Install global and project entries with the same literal command, or install only one of them.
Only `SessionStart` was exercised empirically; the documented rule is event-independent.

## Fallback

<a id="fallback"></a>

If the command strings must differ, install per worktree with `install --project` and leave the global settings alone.
