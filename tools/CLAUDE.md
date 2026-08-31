# `tools/` - this repository's own tooling

Everything in this directory exists to maintain **this repository**. None of it is
distributed, vendored, synced, or installed anywhere else.

## Do not put anything here that a project needs

There are two tool trees and the distinction is the whole point of having two:

| Directory       | Audience                          | Reaches a project by                            |
| --------------- | --------------------------------- | ----------------------------------------------- |
| `claude/tools/` | every project on the machine      | the registry's `tools` block, then `skill-sync` |
| `tools/`        | this repository, and nothing else | nothing. It never leaves this checkout          |

If what you are writing is useful inside a consuming project, it belongs in
`claude/tools/` and it belongs in `TOOLS_REGISTERED` in
`claude/skills/skill-registry/scripts/skill-version.sh`. If it maintains this
repository - its work-orders, its procedure documents, its own bookkeeping - it
belongs here.

The split is deliberate and it is load-bearing. `claude/` is the distributable
payload; everything at the repository root is this repository's own business,
which is already true of `docs/`, `work-orders/`, `setup.sh` and `HYDRATION.md`.
Putting a repo-local tool under `claude/tools/` would push a script to every
project on the machine that has nothing for it to operate on.

`render_tools` only ever walks `claude/tools/`, so nothing in this directory can
reach `claude/skills/registry.json` by accident. That is a safety net, not the
rule. The rule is the paragraph above.

## Conventions that still apply

Everything in root `CLAUDE.md` holds here without exception:

- **Rule 14** - anything whose purpose is to verify that something works runs in
  Podman. `tools/testing/run-tests.sh` is where that happens.
- **Rule 15** - every image is pinned to a digest. `:latest` is banned outright.
- **Rule 17** - bash runs under Git Bash on Windows, but the Linux utilities it
  usually sits beside do not. No `flock`, and check for `cmp` and `diff` before
  depending on either.

## Versions

A tool here carries its version as a marker in its first 20 lines:

```
# skill-tool-version: 1.0.0
```

Same token as `claude/tools/`, so there is one convention across the repository
rather than two. The token is deliberately not `version:`, so it can never be
confused with a `version:` in prose, and it reads under any comment syntax.

Nothing reads these markers automatically today except `workflow-version.sh`
reading its own. They are here so that the day something does, the data already
exists.

## What is here

| Path                    | What it does                                       |
| ----------------------- | -------------------------------------------------- |
| `workflow-version.sh`   | owns the versions of the documents in `workflows/` |
| `testing/run-tests.sh`  | the suite for everything in this directory         |
| `testing/Containerfile` | the image that suite runs in, pinned by digest     |
