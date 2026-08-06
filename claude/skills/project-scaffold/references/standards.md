# Standards for the managed files

This is the format spec.
The scripts enforce it; this document explains it and says why each rule exists.

A rule with no reason gets reverted by the next person, so every section here states the failure it prevents.

---

## The rule underneath all of them

**An agent never hand-edits a managed file.**

Format lives in a script.
Changing the format later means changing one script, not auditing every project that ever used the old one.
Discipline does not survive contact with a hundred sessions; a script does.

Two files are script-owned outright: `ISSUES.md` and `BACKLOG.md`.
`COMPASS.md` and `NAMING.md` are hand-written inside a structure the scaffolder installs.
`CLAUDE.md` ships verbatim and is then yours.

---

## Every file states its own read protocol

The first lines of each managed file say how much of it to read.
An agent should never have to guess, and "read the whole thing" is almost never the right answer.

This is where the token budget is actually won or lost.

---

## ISSUES.md

Append-only.
Newest entry on top.
Written only by `log-issue.sh`.

### Read protocol

Top 10 entries, then stop.
Go deeper only when the user asks, or when an entry inside the window references an older ID you need.

### Entry shape

```markdown
## ISS-0043 - Profile export now preserves the when clause

<!-- issue
id: ISS-0043
logged: 2026-08-05T16:10:02-05:00
severity: high
area: export
tags: data-loss, fixed
refs: BK-0015
resolves: ISS-0041
-->

- **Symptom** - Exported bindings lost `when`, so they fired globally after import.
- **Trigger** - Export any profile holding a context-scoped binding.
- **Cause** - The serialiser wrote a fixed field list that omitted `when`.
- **Resolution** - Serialise from the binding schema instead of a literal list.
- **Verification** - Round-trip test added; fails if any field is dropped.

---
```

### Why an HTML comment holds the metadata

It is invisible in rendered markdown, greppable without a parser, and impossible for prose to corrupt.
`grep -A7 'severity: high' ISSUES.md` works with no tooling at all.

### Why the five fields are mandatory

Symptom, Trigger, Cause, Resolution, Verification.
The script rejects an entry missing any of them.
Without that, entries decay into "it broke, I fixed it" - which is exactly the entry that helps nobody six months later.

Use `pending` for a Resolution that does not exist yet, and `none yet` for Verification.
An honest placeholder is information; an omitted field is not.

### Why values collapse to a single line

The 10-entry window only means something if entries are a predictable size.
A multi-line value would also let a stray newline break every downstream grep.

### Why `-->` inside a value is neutralised

A literal comment terminator in a field would end the metadata block early and corrupt every parse after it.
It becomes `--&gt;`.

The replacement is expanded quoted, because bash 5.2 treats a bare `&` in a substitution replacement as "whatever the pattern matched" - an unquoted `--&gt;` silently produces `---->gt;`.

### Why a fix is a new entry

Nothing is ever rewritten.
A resolution carries `resolves: <ID>`, so reading top-down you meet the fix before the problem.
The window stays truthful because nothing shifts underneath it.

The cost: "what is still open" is not answerable from the window alone once the log is long.
That is what `.claude/cache/open-issues.json` computes - every ID that appears in no later `resolves:`.

---

## BACKLOG.md

Priority order, top to bottom.
Managed by `backlog.sh`.

### The four buckets

| Bucket  | Means                                     | Discipline                                       |
| ------- | ----------------------------------------- | ------------------------------------------------ |
| `Now`   | in flight                                 | 1-3 items, or the word stops meaning anything    |
| `Next`  | committed, not started                    | an agent may pull from here when Now is empty    |
| `Later` | captured so it stops taking up head space | never auto-promoted                              |
| `Done`  | finished                                  | newest first, trimmed to 20 - git holds the rest |

Buckets _are_ the priority.
No numeric ranks, because nobody ever agrees on what 3 versus 4 means.

### Item shape

```markdown
- [ ] **BK-0014** - Map the chord namespace for window management
  <!-- item
  id: BK-0014
  added: 2026-08-05T14:32:11-05:00
  -->
  - why: chords are being assigned ad hoc and colliding (see ISS-0042)
  - done-when: every ctrl+k chord is listed in NAMING.md with an owner
```

### Why `done-when` is mandatory

It is the load-bearing field.
An item whose completion someone has to adjudicate is not ready to be worked - it stays in `Later` until it can be phrased as a check.

### Why completion goes in the metadata

`done` flips the checkbox and adds `completed: <date>` to the comment block.
Appending the date to the title instead would pollute every parse of the item's name.

### Why moves are a script

Items move buckets, get reworded, get merged.
A script that only appended would not survive the first reprioritisation.
`move` lifts the item's body out byte for byte and splices it under the target marker, so nothing is retyped and nothing is lost.

Ambiguity is refused, not guessed: an ID appearing twice stops the run.

---

## COMPASS.md

A pointer file.
Hand-written inside the installed structure.

### Hard cap: 100 lines

Every row is _path - what it is - when you would open it_.
It routes; it never explains.

The moment COMPASS explains something, it has duplicated a file it points at, and the duplicate will go stale.
If something does not fit inside the cap, it belongs in the file being pointed at.

### Staleness is a defect

A row pointing at a path that no longer exists gets fixed in the same change that moved the file.

---

## NAMING.md

Two tiers, because the distinction is load-bearing.

**Inherited** rules hold across every project.
**Project-specific** rules are true only in this repo - they do not travel with copied code.
An agent lifting a pattern out of a repo needs to know which half comes with it.

A third section, **Reserved**, lists terms that already mean something here and must not be reused.

Every rule gets a good _and_ a bad example.
A convention stated abstractly gets interpreted; a convention with a counter-example gets followed.

---

## CLAUDE.md

Ships verbatim.
It is a starting template, not a generated file - edit it per project after scaffolding.

Two sections are appended by this skill because the tooling depends on them:

- **Session State** - the pointer to `CONTEXT_STATE.md` that the `context-compaction` skill needs in order to be found at all.
- **Logging an issue** - the instruction never to hand-edit `ISSUES.md` or `BACKLOG.md`, and the exit-code contract.

`scaffold.sh` treats `CLAUDE.md` as heading-delimited rather than marker-delimited, so no scaffolding comments are injected into text a human wrote.

---

## The agent cache

`.claude/cache/` is **derived**.
Delete it and nothing is lost; `cache.sh build` reconstructs it from the markdown.

### Rules that keep it honest

1. **Derived only.** Nothing is authored here. If a fact exists only in the cache, the cache has become a liability.
2. **Staleness detected, not assumed.** `index.json` records a sha256 per source file. A mismatch means the agent reads the markdown instead.
3. **It never answers a question its sources cannot.** No summarising, no inference - only reshaping.

### The one computed slice

`open-issues.json`: every issue whose ID appears in no later `resolves:`.
That is the exact question an append-only log plus a 10-entry window cannot answer, which is why it earns its place beyond being faster.

### Cache versus CONTEXT_STATE.md

|             | Agent cache             | CONTEXT_STATE.md                       |
| ----------- | ----------------------- | -------------------------------------- |
| Content     | derived from repo files | authored judgement about a session     |
| Rebuildable | yes, mechanically       | no - lose it and the reasoning is gone |
| Lifetime    | until a source changes  | permanent, append-only                 |
| Written by  | a script                | an agent, at a checkpoint              |

Keeping them separate is what stops the cache becoming a place people quietly author things that exist nowhere else.

---

## ID format

`<PREFIX>-<4 digits>`, zero-padded, never reused.
`ISS-` for issues, `BK-` for backlog items.

Allocation scans the existing IDs and takes the successor.
At 9999 the tools stop with a defined error rather than wrapping, because silent ID reuse is unrecoverable.

Allocation happens under `flock`, so parallel agents cannot race for the same number.
