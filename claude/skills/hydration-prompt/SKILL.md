---
name: hydration-prompt
description: Writes the prompt that starts the next session, and hands back the exact command to launch it. Maintains HYDRATION.md as a 10-entry sliding window, newest on top. Use at close-out, after CONTEXT_STATE.md is written and before the pull request is opened, or whenever the user asks for a hydration prompt, a handoff, or how to start the next ticket.
---

# Hydration prompt

The last thing a session produces is the first thing the next one reads.

This skill turns that into an artifact rather than a message: an entry at the top
of `HYDRATION.md`, and a copy-paste command that launches the next session pointed
straight at it. The user should never have to explain the project again, and
should never have to assemble a command by hand.

## The one flow

`CONTEXT_STATE.md` -> hydration prompt -> **one** pull request -> merge -> cleanup -> the command.

```text
1  context-compaction writes CONTEXT_STATE.md          on the work branch
2  hydration-prompt writes HYDRATION.md                on the same branch
3  work-order.sh done                                  on the same branch
4  push, open ONE pull request                         code + both state files
5  human reviews and merges
6  work-order.sh close                                 archives, straight to main
7  hand back the prompt and its launch command
```

Steps 1 through 3 are all part of the deliverable and all ride the same branch.
**There is exactly one pull request per ticket.** A second PR that carries only
state files doubles the review surface for one piece of work and leaves `main`
briefly describing a world that no longer exists.

## The script does the mechanical parts

Never hand-edit `HYDRATION.md`, and never assemble the launch command by typing
it. Both are scripted precisely because an agent asked to "remember to trim to
ten" will eventually not, and will report that it did.

```sh
HP=.claude/skills/hydration-prompt/scripts/hydration.sh

bash $HP init    --project .
bash $HP check   --project . --body-file /tmp/entry.md      # before writing
bash $HP add     --project . --id WO-... --title "..." --body-file /tmp/entry.md
bash $HP command --project . --id WO-... --title "..."      # the launch block
bash $HP latest  --project .                                # what the next agent reads
```

`add` refuses a body that fails `check`, so a malformed entry never reaches the
file.

## Which file governs

`CONTEXT_STATE.md` and `HYDRATION.md` are written in the same commit, by the same
close-out, describing the same moment. They are meant to be read together and an
agent should read both.

**When they disagree, the hydration prompt wins.** It is not a tie to be
reconciled and it is not a judgement call.

The reason is what each file is for. `CONTEXT_STATE.md` is a **state snapshot**:
where things stood, what was decided, what was learned. `HYDRATION.md` is an
**instruction written for this session**: what to do, what not to assume, what
must be settled first. State describes; the prompt directs. A snapshot that has
drifted is stale information, which is survivable. An instruction that is
overridden by stale information is how a session goes and does the wrong thing
confidently.

So the reading order is: `HYDRATION.md` top entry for what to do, then
`CONTEXT_STATE.md` top 10 for the background it assumes. If the background
contradicts the instruction, follow the instruction and **say so** - a
contradiction between two files written in the same commit is a defect worth
reporting, not worth silently resolving.

## The window

**Read the top entry only.** It is current and complete on its own. The nine
below it are history, kept so a question about how we got here can be answered,
not so they can be read at the start of a session. This differs from
`CONTEXT_STATE.md` and `ISSUES.md`, which are read ten deep - ten full hydration
prompts is roughly fifteen thousand words of superseded instructions.

**Newest on top, oldest falls off.** Adding an entry removes the tenth in the
same write and therefore the same commit. Entries are never numbered, never
renumbered and never edited in place. A correction is a new entry.

## What an entry contains

Twelve sections, in order, each exactly once. `references/entry.tmpl` is the
template and `check` enforces it:

`Ticket` &middot; `What just landed` &middot; `What is NOT done` &middot;
`Stale or false in the docs` &middot; `Your scope` &middot; `Before you start` &middot;
`Read in this order` &middot; `Reuse, it is proven` &middot;
`The verification ladder` &middot; `Traps, already paid for` &middot;
`Workflow` &middot; `Conventions`

Two of those carry most of the value.

**`What is NOT done`** is the section most often written dishonestly, because
every incentive at close-out points at sounding finished. If nothing reached a
real system, say that in those words and give the command whose empty output
proves it. Anything carried onto another ticket is named there by ID and full
title so it cannot be quietly dropped.

**`Before you start`** is what makes a prerequisite a gate rather than a
discovery. Anything unsettled goes here, and an agent that finds an unanswered
question asks the user rather than choosing an answer and building on it. Write
`None.` when there is genuinely nothing - an empty section cannot be told apart
from a forgotten one.

### Duplicated sections are a defect, not a formatting quibble

`check` fails on a repeated heading. This exists because the first entry ever
written was assembled from terminal output that had three of its sections pasted
in twice, and every human who looked at it skimmed straight past. A reader who
hits the same heading a second time cannot tell which copy is current.

## The launch command

`command` emits this and only this, with every variable derived rather than
typed:

```sh
claude -p "Read Hydration Prompt located at $FULL_PATH_TO_FILE, Process work order $WO_ID per its acceptance criteria after you've read it." \
  --permission-mode bypassPermissions \
  -n "Session: $WO_ID - $WO_TITLE"
```

`$FULL_PATH_TO_FILE` is always the absolute path to the project's `HYDRATION.md`,
and the script refuses to print a command pointing at a file that is not there.

Prefer `command --project .` with no other flags. Both values are then read out
of the newest entry, so the command cannot disagree with the entry it points at.
Typing them again is a chance to type them differently.

Hand back the prompt **and** the command together. The command alone is not
enough - the user should be able to read what they are about to start.

### When there is no work order

Not every session is a ticket. A spike, an investigation, a piece of maintenance -
`--id` is optional, and both the entry and the command adapt:

```sh
claude -p "Read Hydration Prompt located at $FULL_PATH_TO_FILE" \
  -n "Session: "
```

Three deliberate differences from the shape above, none of them an oversight.

The **acceptance-criteria clause is dropped**, because there are none to process
and pointing it at nothing is worse than leaving it out.

**`--permission-mode bypassPermissions` is not carried over.** A ticket has a
reviewed scope and acceptance criteria behind it; an ad-hoc session has neither,
so it answers for itself.

**The session name is left empty on purpose.** Work outside a ticket has no name
until the person starting it decides what this session is - a design pass, a
spike, an investigation - so the slot stays open to be typed at the moment of
pasting. Do not fill it from the entry title. That looks like helpfulness and is
actually a guess, and a test asserts it stays empty.

The `Ticket` section of the entry still exists on this path - it names what the
session is and why, instead of an ID.

## Pointer

Every project using this skill carries a line in `CLAUDE.md` pointing at
`HYDRATION.md` and stating the read-the-top-entry-only rule.

`project-scaffold` writes that pointer; it does **not** create the file. Running
`hydration.sh init --project .` does, and this script owns the file from then on.
The split is the same one `context-compaction` has with `CONTEXT_STATE.md`: the
scaffold points at it, the owning skill writes it.

## Testing

```sh
bash testing/run-tests.sh
```

Runs in a container per the `container-sandbox` skill. Covers rotation at the
window boundary, refusal of a duplicated section, refusal of an empty
`Before you start`, and that the emitted command matches the template byte for
byte.
