---
name: context-compaction
description: Distill a session into a checkpoint appended to CONTEXT_STATE.md, a sliding window read 10 deep. Prevents context drift across sessions and across agents. Use when context usage exceeds 30%, before starting a new thread, after a significant milestone, when an agent contradicts an earlier architectural decision, or when architecture details feel stale.
version: 2.0.0
---

# context-compaction

`CONTEXT_STATE.md` is the state any agent hydrates from at the start of a session.
It is not a summary of a conversation. It is a stack of checkpoints, newest on top, read 10 deep and no further.

**A checkpoint is appended above the last one. Nothing below the top is ever rewritten.**

## What changed in 2.0.0, and why it is a major bump

Version 1 described `CONTEXT_STATE.md` as a single mutable state and told an agent to hand-write it from a schema.
Its own workflow diffed `old_value -> new_value` and asked for confirmation before overwriting.

That contradicts the sliding-window rule the file is subject to, which says in as many words that nothing is ever rewritten in place and a new checkpoint is appended at the top rather than edited into the one below.

The failure was invisible on the first run, because one checkpoint looks the same under either reading.
On the second run, in a different session, the first checkpoint was destroyed.

Two things changed:

1. **The format is append-only, and a checkpoint has a delimiter.** `## Checkpoint YYYY-MM-DD HH:MM UTC`. Without a delimiter, "read the top 10" was not a resolvable instruction.
2. **A script owns the format.** Version 1 was prose only. Nothing mechanical could catch the contradiction, which is why it survived. Format now lives in `scripts/checkpoint.sh`.

Anything that read version 1's schema will not find it. Hence major.

## When to invoke

- Context usage exceeds 30%
- Before starting a new thread on the same project
- After completing a significant milestone
- An agent produced output contradicting an earlier architectural decision

## The shape of the file

```
CONTEXT_STATE.md
├── preamble                              static, written once by init
├── ## Checkpoint 2026-08-24 09:12 UTC    newest - read this and stop
│   ├── ### Current state                 restated IN FULL
│   │   ├── #### Infrastructure
│   │   ├── #### Toolchain
│   │   ├── #### Active Tasks
│   │   └── #### Blockers
│   ├── ### New this checkpoint           only what happened since the last
│   │   ├── #### Decisions
│   │   └── #### Lessons Learned
│   └── ### Hydration prompt
├── ## Checkpoint 2026-08-23 16:52 UTC    pushed down, immutable
└── ...
```

### The rule that makes the window work

| Section | Treatment | Why |
| --- | --- | --- |
| Infrastructure, Toolchain, Active Tasks, Blockers | **restated in full** every checkpoint | The top checkpoint has to answer "what is true now" without reading down |
| Decisions, Lessons Learned | **only what is new** since the last checkpoint | Already dated and never superseded. Restating them ten times is ten times the tokens for no information |

Reading top-down therefore accumulates history the same way `ISSUES.md` does.
The top block is current state; everything below is how you got here.

## Workflow

### 1. Install, once per project

```sh
scripts/checkpoint.sh init --project <dir>
```

Writes the preamble and no checkpoint. An existing file is left byte-identical.

### 2. Read before writing

```sh
scripts/checkpoint.sh read --project <dir> --top 1
```

The new checkpoint restates current state in full and records only what is new.
Reading the top one is how you know what "new" means.

### 3. Author the body, then check it

Write the sections to a file, without a `## Checkpoint` heading - the script writes the heading and stamps the time.

```sh
scripts/checkpoint.sh check --body-file /tmp/cp.md
```

Exit 3 names every missing section. Nothing is written.

### 4. Append it

```sh
scripts/checkpoint.sh new --project <dir> --body-file /tmp/cp.md
```

Prepends above the previous top and prints the timestamp.
The preamble stays where it is, and every checkpoint below is untouched.

### 5. Verify

```sh
scripts/checkpoint.sh verify --project <dir> [--json]
```

Exit 3 when timestamps are out of order, a timestamp repeats, or the **top** checkpoint is missing a required section.

Older checkpoints are checked for ordering only, never for completeness.
They were written under whatever schema existed at the time, and rewriting one to satisfy a newer gate is exactly the in-place edit this version exists to prevent.

## Retention

The window is a **reading** rule: take the top 10 and stop.

Retention is deliberately not implemented. Pruning is trivial once a delimiter exists, since it is "drop everything below the Nth heading", and the shape above makes that a later decision rather than a constraint designed in now.

## Contracts

| Property | Rule |
| --- | --- |
| stdout | data only - a timestamp, the requested checkpoints, or one JSON object |
| stderr | every human word |
| exit 0 | success |
| exit 2 | usage |
| exit 3 | validation - missing section, bad ordering, duplicate timestamp |
| exit 4 | io |
| exit 5 | lock timeout |
| exit 6 | not found |
| writes | atomic, and serialised behind a lock |
| input | written literally; nothing in a body is ever evaluated |

## Staleness

Read the **top checkpoint's timestamp**, not a field.
A field could be edited in place; a heading cannot be, without violating the rule.

If the top checkpoint is older than 7 days, say so before trusting the infrastructure sections:

```
CONTEXT_STATE.md top checkpoint is <N> days old.
Verify infrastructure fields before relying on them.
```

## OS awareness

Rule 17. Locking is `mkdir`-based rather than `flock`, which is absent from Git Bash on Windows and reports its own absence as a lock timeout that never happened.
`just test` dispatches through WSL on Windows, where podman does not live on the host.
Every recipe has a plain `bash scripts/checkpoint.sh ...` equivalent.

## Testing

```sh
just test
```

41 checks in Podman, per Rule 14.
The load-bearing one asserts that after a second checkpoint is written, the first is still byte-identical.
That is the regression version 1 shipped with.

## Wiring into a project

Add to the project's `CLAUDE.md`:

```markdown
## Session State
See `CONTEXT_STATE.md`. Read the top checkpoint and stop.
It restates current state in full; everything below it is history.
```

## Additional reference

- `project-scaffold` skill - owns `CLAUDE.md` and the sliding-window rule this skill obeys
- `living-docs` skill - the same bet, that a format nobody scripts is a format that drifts
