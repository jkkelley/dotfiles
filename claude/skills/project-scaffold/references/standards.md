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
`AGENTS.md` ships verbatim and is then yours; `CLAUDE.md` is a stub pointing at it.

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

A shared file with sequential IDs needs a scan and a lock to allocate the next one, which is exactly where two concurrent agents on a trunk-based workflow collide.
Even when the lock holds, git sees every writer touching the same file, so merges conflict (dotfiles #95).

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
Answering it is a grep, and there is no derived index to keep it in: every `id:` that appears in no later entry's `resolves:`.

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

A move is an atomic rename between directories and `done` is a rename into `done/YYYY/MM/` plus a `completed:` line in the metadata.
Distinct paths per item mean two agents working two items never touch the same file.

The live buckets stay flat because their discipline caps how many items they ever hold.
`done/` is month-sharded because it is the only bucket that accumulates, and its filename is re-stamped with the completion time - the shard a file sits in must be the shard its own name implies.

### Read protocol

`now/`, `next/` and `later/` are read in full - that is live work, and it is capped by the disciplines above rather than by a window.
`done/` is a sliding window: the newest 10, then stop.
`backlog.sh list` enforces both, so an agent does not have to remember the depth.

Go deeper only when the user asks, or when an item inside the window references a suffix you need in order to act.
Same rule as `issues/`, and for the same reason - state it when you go deeper, and say why.

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

## AGENTS.md and CLAUDE.md

`AGENTS.md` is the agent orientation file, and it is written for every runtime, not only Claude.
It ships verbatim and is then yours to extend.
Each law it states is a `## Law: ...` section, and a law backed by a Drive document cites that document by name and version only - never an id or a URL, because this repository is public.

`CLAUDE.md` is a stub that says "read `AGENTS.md`" and states no rule of its own.
It keeps the `skill-sync` marker pair, because `claude/tools/skill-sync.sh` fills the installed skills list there.
A second copy of any rule in `CLAUDE.md` is how the two files drift, so nothing else belongs in it.

`scaffold.sh` treats both as heading-delimited rather than marker-delimited, so no scaffolding comments are injected into text a human wrote.
An existing `AGENTS.md` gains any law it is missing as an appended section.
The stub has no sections, so an existing `CLAUDE.md` is never touched.

---

## .claude/ settings

`settings.json` carries the attribution block.
`settings.local.json` carries a **project-scoped** permission allowlist: git, `gh-axi`, `podman`, `lavish-axi`, the test entry point.

Nothing user-level or machine-level belongs in it.
A home-directory glob would be wrong on any other machine and would put a username into a repository that may be public.
Both files are create-if-absent: a hand-edited settings file is never overwritten.

---

## .github/workflows/context-check.yml

Installed only by `scaffold.sh --ci`, and create-if-absent like the settings files.
It runs `log-issue.sh check` and `backlog.sh check` from `.claude/scripts/`, the same vendored code an agent runs, so CI cannot hold a different idea of a valid tree than the agent does.
It is the backstop, not the gate: an agent runs `check` before it pushes, and CI catches the push that skipped it.

Every action is pinned by commit SHA with its tag in a comment, per dotfiles Rule 15.
A moving tag means the check that ran is not the check that was reviewed.

---

## ID format

5 lowercase alphanumeric characters, minted at random by the script at write time: `a3f9c2`.
The same format names issues and backlog items; the tree a suffix lives in says which it is.

There is no successor to compute, so there is no scan and no lock.
Creation is an atomic `ln` that retries with a fresh suffix on the rare collision, and `check` fails the tree if a duplicate ever appears anyway.

Cross-references (`refs:`, `resolves:`) hold suffixes.
They resolve across both trees and are validated by `check`, so the DAG stays honest without a database.

A sequential ID (`ISS-0043`, `BK-0014`) is malformed here, and the scripts refuse it.
A project that predates the trees converts once with `migrate`; the procedure is in `SKILL.md`, not in this spec.
