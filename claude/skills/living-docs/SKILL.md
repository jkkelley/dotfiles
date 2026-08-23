---
name: living-docs
description: The documentation standard for a project, and the machinery that keeps it true. Installs a Diataxis-shaped docs/ layer, owns the formats of decision records and SOPs, and makes documentation a gate rather than an intention by binding it to the ticket that changed the system. Use when starting documentation in a project, when asked to "document this", "write an ADR", "write an SOP", "set up docs", when a system change needs its documentation updated, or when documentation has drifted from what the code does.
version: 1.0.0
---

# living-docs

> **This copy is read-only.**
> Skills are vendored into a project as copies, and this may be one.
> Edit this skill upstream, bump its version, then re-pull it - never edit the copy where it landed.
> Upstream is https://raw.githubusercontent.com/jkkelley/dotfiles/refs/heads/main/claude/skills/living-docs/SKILL.md, and `skill-update.sh` pulls it from there - no dotfiles checkout is needed on this machine.
> `skill-update.sh` replaces the skill's directory rather than merging into it, so a local edit is destroyed by the next update with no conflict and no warning.
> The registry's content hash cannot catch it either, because a project's copy legitimately differs from upstream.

Documentation does not rot because people are lazy.
It rots because nothing fails when it is wrong.

This skill fixes that in one move: **documentation is an acceptance criterion on the ticket that changed the system**, and a ticket cannot reach `done` without evidence.
The enforcement already exists in `work-order`, so there is no new gate to build and nothing to remember.

Everything else here is the shape the documentation takes once it is being written.

## When this applies

- Starting documentation in a project
- "document this", "write an ADR", "write an SOP", "set up docs"
- A system change that needs its documentation to move with it
- Documentation that has drifted from what the code does

## What gets installed

```
<project>/docs/
├── README.md        the router - written by docs.sh init
├── tutorials/       learning        created on first use
├── how-to/          task            created on first use
├── reference/       information     created on first use
├── explanation/     understanding   created on first use
├── decisions/       ADRs            created by docs.sh adr
└── sops/            procedures      created by docs.sh sop
```

A directory appears once it has something in it.
An empty directory is a promise nobody kept, so none are created ahead of need.

## The four modes

Every document declares its mode in its own first lines.
Picking the mode is the first decision, not an afterthought, because mixing two modes in one document is the single largest cause of documentation nobody reads.

| Mode | Orientation | Answers |
| --- | --- | --- |
| tutorial | learning | "I am new, walk me to a first success" |
| how-to | task | "I have a goal, get me to it" |
| reference | information | "What exactly does this do" |
| explanation | understanding | "Why is it like this" |

See [references/diataxis.md](references/diataxis.md) for how to choose when a document seems to want two.

## Workflow

### 1. Install the layer

```sh
just init <project>
# or, without just:
scripts/docs.sh init --project <project>
```

Writes `docs/README.md` and nothing else.
An existing `README.md` is reported and left byte-identical.

### 2. Record a decision

```sh
scripts/docs.sh adr --project <dir> \
  --title T --context C --decision D --consequences X \
  [--status proposed|accepted|superseded] [--supersedes ADR-0003]
```

**A decision is superseded, never edited.**
A change of mind is a new record naming the one it replaces, the same way `ISSUES.md` treats a fix as a new entry rather than an edit of the old one.
Reading top-down, the current answer arrives before the answer it replaced.
`--supersedes` fails with exit 6 when the record named does not exist, so a superseding chain cannot point at nothing.

### 3. Record a procedure

```sh
scripts/docs.sh sop --project <dir> \
  --title T --purpose P --when W --steps S
```

Every SOP carries a Verification section, because a step that cannot be verified is a wish.
This is the Google SRE rule: a runbook is executable, not aspirational.

### 4. Verify

```sh
scripts/docs.sh verify --project <dir> [--json]
```

Exit 3 when any document under `docs/` lacks a mode declaration or a review date.
It names the files rather than printing a count, because the answer the reader wants is which file to fix.

## The mechanism that stops documentation being forgotten

Three parts, and only the first one is load-bearing.

**1. A documentation acceptance criterion on every ticket.**
`work-order` gates `done` behind `--observed` evidence for every acceptance criterion.
So the ticket that changes the system carries an AC saying which document moves with it, and it cannot close until someone has pasted what the update actually produced.
No new enforcement, no CI job, no honour system, no checklist to skip.

**2. The change-trigger table.**
[references/change-triggers.md](references/change-triggers.md) maps "touched X" to "update Y".
It exists so the decision does not need to be made at the moment of forgetting.

**3. Freshness metadata.**
Every document carries `Last reviewed:`.
`verify` fails without it. A date that is old is a visible question rather than an invisible lie.

## Contracts every tool honours

| Property | Rule |
| --- | --- |
| stdout | data only - an ID, or one JSON object under `--json` |
| stderr | every human word |
| exit 0 | success |
| exit 2 | usage - unknown flag, missing or empty required value |
| exit 3 | validation - bad enum, missing mode, missing review date |
| exit 4 | io - unreadable or unwritable path |
| exit 5 | lock timeout - another writer held the lock |
| exit 6 | not found - a referenced ID does not exist |
| writes | atomic (staged, then renamed) and serialised behind a lock |
| input | written literally; nothing in a field value is ever evaluated |

Branch on the exit code, never on the message text.

## OS awareness

**This skill runs on Linux and on Windows, and `justfile` is why.**

The scripts are bash, which runs under Git Bash on Windows.
What does not survive the crossing is the assumption that every Linux utility is present.
Two concrete cases this skill was written around:

- **`flock` does not exist in Git Bash.** Locking here is `mkdir`-based, which is atomic on every filesystem this repo runs on. A skill that claims to be OS aware cannot take a lock that only exists on one OS.
- **`podman` is not on the Windows host.** It lives inside WSL. `just test` dispatches through WSL on Windows and calls podman directly on Linux, translating the mount path with `wslpath`, so the same command works from either side.

`just` is a single binary and is the entry point rather than the implementation.
Every recipe has a plain `bash scripts/docs.sh ...` equivalent, so a machine without `just` is inconvenienced rather than blocked.

Where a skill genuinely cannot be OS aware, it says so in its own SKILL.md and names the platform it requires.
Silently working on one OS is the failure mode this section exists to prevent.

## Testing

Every check runs in Podman, per root `CLAUDE.md` Rule 14:

```sh
just test
```

Skill mounted read-only, network disabled, outputs forced onto a separate scratch mount.
`SOURCE_DATE_EPOCH` pins the clock so determinism is provable with `cmp` rather than asserted.

## Additional reference

- [references/diataxis.md](references/diataxis.md) - the four modes and how to choose
- [references/change-triggers.md](references/change-triggers.md) - the "touched X, update Y" table
- [references/templates/](references/templates/) - the templates the scripts render
- `work-order` skill - owns the acceptance criteria this skill binds documentation to
- `project-scaffold` skill - owns `CLAUDE.md`, `COMPASS.md`, `ISSUES.md`, which this skill does not touch
