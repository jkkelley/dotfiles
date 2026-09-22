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

Two trees are script-owned outright: `issues/` and `backlog/`.
`COMPASS.md` and `NAMING.md` are hand-written inside a structure the scaffolder installs.
`CLAUDE.md` ships verbatim and is then yours.

---

## Every file states its own read protocol

The first lines of each hand-managed file say how much of it to read.
An agent should never have to guess, and "read the whole thing" is almost never the right answer.

This is where the token budget is actually won or lost.

---

## issues/

One file per issue, at `issues/YYYY/MM/<UTC-timestamp>-<suffix>.md`.
Written only by `log-issue.sh`.

### Why one file per entry, and why no sequential IDs

The old model was one monolithic `ISSUES.md` with sequential IDs (`ISS-0043`).
Allocating a successor ID required scanning the file AND holding a lock on it, which is exactly where two concurrent agents on a trunk-based workflow collide.
Worse, git saw every writer touching the same file, so merges conflicted even when the lock held (dotfiles #95).

A random 5-char suffix minted at write time needs no scan and no lock: the name is unique by construction, so creation is an atomic `ln` with a retry.
One file per entry means two agents never touch the same path, and merges never meet.

The cost: IDs are no longer dense, and the number tells you nothing about recency.
The UTC timestamp in the filename carries ordering instead, which is all the read window ever used the number for.

### Why month sharding

`issues/YYYY/MM/` keeps any single directory listing short once the log is long, and it puts the window walk in the newest shard first.
The shard a file sits in must be the shard its filename timestamp implies - `check` enforces it, because a file in the wrong shard is visited in the wrong month.

### Why the window is a directory walk

Filenames and shard directories both sort chronologically, so the newest 10 paths in reverse lexical order ARE the newest 10 entries.
There is no index file, so there is nothing to go stale.

### Read protocol

The newest 10 entries, then stop.
Go deeper only when the user asks, or when an entry inside the window references a suffix you need.

### Entry shape

```markdown
# Profile export now preserves the when clause

<!-- issue
id: a3f9c2
logged: 2026-08-05T21:10:02Z
severity: high
area: export
tags: data-loss, fixed
refs: b7e21x0
resolves: q9w41
-->

- **Symptom** - Exported bindings lost `when`, so they fired globally after import.
- **Trigger** - Export any profile holding a context-scoped binding.
- **Cause** - The serialiser wrote a fixed field list that omitted `when`.
- **Resolution** - Serialise from the binding schema instead of a literal list.
- **Verification** - Round-trip test added; fails if any field is dropped.
```

### Why an HTML comment holds the metadata

It is invisible in rendered markdown, greppable without a parser, and impossible for prose to corrupt.
`grep -r 'severity: high' issues/` works with no tooling at all.

### Why suffix references

`refs:` and `resolves:` point at 5-char suffixes, forming a DAG with no database.
A suffix is greppable across the whole tree: `grep -rl "resolves: a3f9c2" issues/ backlog/` finds everything that closes an entry.
`check` verifies every target exists, so a dangling pointer fails loudly instead of silently.

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
A resolution carries `resolves: <suffix>`, so reading newest-first you meet the fix before the problem.
The window stays truthful because nothing shifts underneath it.

The cost: "what is still open" is not answerable from the window alone once the log is long.
Answering it is a grep: every `id:` that appears in no later entry's `resolves:`.

---

## backlog/

One file per item.
Buckets are directories: `backlog/now/`, `backlog/next/`, `backlog/later/`, `backlog/done/`.
Written only by `backlog.sh`.

### The four buckets

| Bucket  | Means                                     | Discipline                                    |
| ------- | ----------------------------------------- | --------------------------------------------- |
| `now`   | in flight                                 | 1-3 items, or the word stops meaning anything |
| `next`  | committed, not started                    | an agent may pull from here when now is empty |
| `later` | captured so it stops taking up head space | never auto-promoted                           |
| `done`  | finished                                  | month-sharded, kept - git holds the rest      |

Buckets _are_ the priority.
No numeric ranks, because nobody ever agrees on what 3 versus 4 means.

### Why buckets are directories

A bucket used to be a marker line inside one monolithic `BACKLOG.md`, and a move used to be a scripted splice of one shared file.
Now a move is an atomic rename between directories and `done` is a rename into `done/YYYY/MM/` plus a `completed:` line in the metadata.
Distinct paths per item mean two agents working two items never touch the same file.

The live buckets stay flat because their discipline caps how many items they ever hold.
`done/` is month-sharded because it is the only bucket that accumulates, and its filename is re-stamped with the completion time - the shard a file sits in must be the shard its own name implies.

### Read protocol

`now/`, `next/` and `later/` are read in full - that is live work, and it is capped by the disciplines above rather than by a window.
`done/` is a sliding window: the newest 10, then stop.
`backlog.sh list` enforces both, so an agent does not have to remember the depth.

Go deeper only when the user asks, or when an item inside the window references a suffix you need in order to act.
Same rule as `issues/` and `CONTEXT_STATE.md`, and for the same reason - state it when you go deeper, and say why.

### Item shape

```markdown
# Map the chord namespace for window management

<!-- item
id: b7e21x0
added: 2026-08-05T14:32:11Z
-->

- why: chords are being assigned ad hoc and colliding (see q9w41)
- done-when: every ctrl+k chord is listed in NAMING.md with an owner
```

### Why `done-when` is mandatory

It is the load-bearing field.
An item whose completion someone has to adjudicate is not ready to be worked - it stays in `later/` until it can be phrased as a check.

### Why completion goes in the metadata

`done` adds `completed: <UTC timestamp>` to the comment block.
Appending the date to the title instead would pollute every parse of the item's name.

### Why moves are a script

Items move buckets, get reworded, get merged.
A script that only appended would not survive the first reprioritisation.
`move` renames the file between bucket directories, so nothing is retyped and nothing is lost.

Ambiguity is refused, not guessed: a suffix matching two files stops the run.

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
- **Logging an issue** - the instruction never to hand-edit `issues/` or `backlog/` entry files, and the exit-code contract.

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

## .claude/ settings

`settings.json` carries the attribution block.
`settings.local.json` carries a **project-scoped** permission allowlist: git, `gh-axi`, `podman`, `lavish-axi`, the test entry point.

Nothing user-level or machine-level belongs in it.
A home-directory glob would be wrong on any other machine and would put a username into a repository that may be public.
Both files are create-if-absent: a hand-edited settings file is never overwritten.

---

## ID format

5 lowercase alphanumeric characters, minted at random by the script at write time: `a3f9c2`.
The same format names issues and backlog items; the tree a suffix lives in says which it is.

There is no successor to compute, so there is no scan and no lock.
Creation is an atomic `ln` that retries with a fresh suffix on the rare collision, and `check` fails the tree if a duplicate ever appears anyway.

Cross-references (`refs:`, `resolves:`) hold suffixes.
They resolve across both trees and are validated by `check`, so the DAG stays honest without a database.

The old sequential format (`ISS-0043`, `BK-0014`) is gone entirely.
`migrate` converts a monolith's entries to suffixes and rewrites internal references through the old-to-new map it builds on the way.
