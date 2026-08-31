---
name: project-scaffold
description: Install and maintain the agent context layer in any project - CLAUDE.md, COMPASS.md, BACKLOG.md, ISSUES.md, NAMING.md, plus the scripts that own their formats. Use when starting a new project or directory, when asked to "scaffold this project", "set up the context files", "add COMPASS/BACKLOG/ISSUES", when an agent needs to log an issue or manage a backlog item, or when a project's markdown has drifted from the standard. Not for cloning an existing repo as a template - that is repo-scaffold.
version: 1.5.0
---

# project-scaffold

Install the agent context layer into a project, and own the formats of the files that make it up.

Five markdown files, four scripts, one rule: **an agent never hand-edits a managed file.**
Format lives in a script, so changing the format later means changing one script - not auditing every project by hand.

## When this applies

- A new project or directory that agents will work in
- "scaffold this project", "set up the context files", "add a COMPASS/BACKLOG/ISSUES"
- Logging an issue, or adding / moving / completing a backlog item
- A project whose markdown has drifted from the standard

Not this skill: cloning an existing repo and renaming it. That is `repo-scaffold`.

## What gets installed

```
<project>/
├── CLAUDE.md            how an agent behaves here - ships verbatim, then hand-edited
├── COMPASS.md           the map: pointers only, capped at 100 lines
├── BACKLOG.md           Now / Next / Later / Done         (backlog.sh)
├── ISSUES.md            append-only, newest first          (log-issue.sh)
├── NAMING.md            inherited vs project-specific conventions
├── .gitignore           the shared ignore set, plus what the tools above create
├── .dockerignore        the same set, trimmed for a build context
└── .claude/
    ├── settings.json
    ├── skills.toml      which skills this project uses      (skill-sync installs them)
    ├── scripts/         a versioned copy of the four tools
    ├── skills/          the installed copies - gitignored, owned by skill-sync
    └── cache/           derived JSON slices                 (cache.sh)
```

`.claude/skills.toml` is written once and then belongs to the project: a re-run skips it rather
than refreshing it, the same rule `settings.local.json` gets. It names skills and never versions,
because the copies under `.claude/skills/` are pulled fresh from upstream at every session start
and a hand-maintained version table would be wrong within a week.

`.claude/skills/` is **not** written here. This skill writes the manifest and the gitignore line
that keeps the copies out of git; `skill-sync` installs the directories at session start and owns
them. Nothing in this skill ever writes a skill directory or removes one.

`CONTEXT_STATE.md` is **not** written here. This skill writes the pointer to it in `CLAUDE.md`; the
`context-compaction` skill owns the file itself.

`HYDRATION.md` is **not** written here either, for the same reason and by the same arrangement.
This skill writes the pointer to it in `CLAUDE.md`; `hydration-prompt`'s own `hydration.sh init`
creates the file, and that script owns its contents, its ordering and its 10-entry window.
Nothing in this skill ever writes an entry or reconciles a section of it.

## Workflow

### 1. Scaffold

Dry run first - it always is by default:

```sh
scripts/scaffold.sh --project <dir>              # prints the plan, writes nothing
scripts/scaffold.sh --project <dir> --apply      # interviews, then commits the plan
scripts/scaffold.sh --project <dir> --apply --yes --full   # non-interactive, everything
```

On a terminal `--apply` interviews the user about the optional extras (`README.md`, `git init`) and
shows what each produces before writing. `--yes` skips the interview.

`.gitignore` and `.dockerignore` are **not** extras - they install by default, because an agent that
commits `.claude/cache/` or bakes a `.env` into an image has already done the damage by the time
anyone reviews it. Both come from
[references/templates/](references/templates/), which vendors the shared ignore set from
`claudes-markdown-12-rules`; re-pull that upstream rather than hand-editing a project's copy.
`--no-gitignore` / `--no-dockerignore` opt out.

**Existing files are appended to, never deleted or overwritten.** A file already present gains only
the sections it is missing. A non-empty file with none of the expected structure is reported and
left byte-identical - guessing an insertion point is how hand-written work gets destroyed.

### 2. Log an issue

```sh
scripts/log-issue.sh --project <dir> \
  --title T --severity low|medium|high --area A \
  --symptom S --trigger T --cause C --fix F --verify V \
  [--tags a,b] [--refs BK-0014] [--resolves ISS-0041] [--json]
```

A fix for an earlier issue is a **new entry** with `--resolves`, never an edit of the old one.
Reading top-down, the resolution arrives before the problem it closed.

### 3. Manage the backlog

```sh
scripts/backlog.sh add   --project <dir> --title T --why W --done-when D [--bucket now|next|later]
scripts/backlog.sh move  --project <dir> --id BK-0014 --to now
scripts/backlog.sh done  --project <dir> --id BK-0014
scripts/backlog.sh list  --project <dir> [--bucket B] [--json]
```

### 4. Refresh the cache

```sh
scripts/cache.sh build  --project <dir>
scripts/cache.sh verify --project <dir> --json    # exit 3 when stale
```

`log-issue.sh` and `backlog.sh` do not rebuild the cache themselves - run `cache.sh build` after a
batch of writes, or `verify` before trusting a slice.

## Contracts every tool honours

| Property | Rule                                                               |
| -------- | ------------------------------------------------------------------ |
| stdout   | data only - an ID, or one JSON object under `--json`               |
| stderr   | every human word, including prompts and progress                   |
| exit 0   | success                                                            |
| exit 2   | usage - unknown flag, missing or empty required value              |
| exit 3   | validation - bad enum, missing sentinel, ambiguous ID, stale cache |
| exit 4   | io - unreadable or unwritable path                                 |
| exit 5   | lock timeout - another writer held the lock                        |
| exit 6   | not found - a referenced ID does not exist                         |
| writes   | atomic (staged, then renamed) and serialised behind `flock`        |
| input    | written literally; nothing in a field value is ever evaluated      |

Branch on the exit code, never on the message text.

## Reading a scaffolded project

Stated in the installed `CLAUDE.md`, and worth repeating here:

1. `COMPASS.md` first - it routes, it does not explain.
2. `ISSUES.md` - **top 10 entries, then stop.** Deeper only on request, or when an entry in the
   window references an older ID you need.
3. `CONTEXT_STATE.md` - top 10 checkpoints, same rule.
4. `HYDRATION.md` - **the top entry only**, not ten. It is current and complete on its own, and the
   nine below it are retained for history rather than for reading. This is the one file where the
   retention depth and the reading depth deliberately differ.
5. `BACKLOG.md` when choosing work - `Now` / `Next` / `Later` in full, `Done` **top 10 only**.
   `Done` is retained 20 deep so a recent item stays findable, but 20 is a retention limit, not a
   reading limit.
6. `NAMING.md` before naming anything.

If `.claude/cache/` is present and `cache.sh verify` passes, read the slices instead - same
information, roughly a fifth of the tokens. If verify fails, read the markdown; never trust a
stale slice.

## Versioning

The skill directory is authoritative. Scaffolding copies the tools into `.claude/scripts/` so the
project keeps working for someone without these dotfiles. A later `scaffold.sh` run compares each
copy against the skill and reports any that differs as `refresh`; `--apply` re-syncs it. Skew is
visible rather than silent.

The comparison is the copy itself, byte for byte, and there is no recorded version beside it. There
used to be, in `.claude/scaffold.json`, and it never answered a question the comparison had not
already answered - a stamp saying the copies came from tool version 1 tells you nothing when the
copy in front of you has been edited. Skills record what landed in `.claude/cache/skills-receipt.json`,
which `skill-sync` writes and owns; this skill's own copies are checked, not remembered.

## Testing

Every check runs in Podman, per root `CLAUDE.md` Rule 14:

```sh
testing/run-tests.sh
```

Skill mounted read-only, network disabled, outputs forced onto a separate scratch mount that is
removed on every exit path. `SCAFFOLD_NOW` injects a fixed clock so determinism is provable with
`cmp` rather than asserted.

See [testing/SOP.md](testing/SOP.md) for what each case covers and why its failure would matter.

## Additional reference

- [references/standards.md](references/standards.md) - the format spec for every managed file
- [references/templates/](references/templates/) - the templates themselves
- `claude/skills/container-sandbox/references/skill-testing.md` - how shell scripts in this repo are tested
- `context-compaction` skill - owns `CONTEXT_STATE.md`, which this skill only points at
- `hydration-prompt` skill - owns `HYDRATION.md` and the session-launch command, same arrangement
