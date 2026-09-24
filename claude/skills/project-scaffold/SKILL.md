---
name: project-scaffold
description: Install and maintain the agent context layer in any project - AGENTS.md with a CLAUDE.md pointer, COMPASS.md, issues/ and backlog/ entry trees, NAMING.md, plus the scripts that own their formats. Use when starting a new project or directory, when asked to "scaffold this project", "set up the context files", "add COMPASS/BACKLOG/ISSUES", when an agent needs to log an issue or manage a backlog item, or when a project's markdown has drifted from the standard. Not for cloning an existing repo as a template - that is repo-scaffold.
version: 1.6.0
---

# project-scaffold

Install the agent context layer into a project, and own the formats of the files that make it up.

Four markdown files, two entry trees, three scripts, one rule: **an agent never hand-edits a managed file.**
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
├── AGENTS.md            how an agent behaves here, any runtime - ships verbatim, then hand-edited
├── CLAUDE.md            a stub pointing at AGENTS.md, plus the skill-sync marker pair
├── COMPASS.md           the map: pointers only, capped at 100 lines
├── issues/              one entry file per issue              (log-issue.sh)
│   └── YYYY/MM/<UTC-timestamp>-<suffix>.md
├── backlog/             one entry file per item                (backlog.sh)
│   ├── now/  next/  later/    flat - live work is capped, not sharded
│   └── done/YYYY/MM/          month-sharded - Done accumulates
├── NAMING.md            inherited vs project-specific conventions
├── .gitignore           the shared ignore set, plus what the tools above create
├── .dockerignore        the same set, trimmed for a build context
├── .github/workflows/context-check.yml   only with --ci      (runs the check verb)
└── .claude/
    ├── settings.json
    ├── skills.toml      which skills this project uses      (skill-sync installs them)
    ├── scripts/         a versioned copy of the tools: log-issue.sh, backlog.sh, lib/common.sh
    └── skills/          the installed copies - gitignored, owned by skill-sync
```

The verbs are `scaffold`, `log-issue`, `backlog`, `migrate` and `check`, and nothing else.
There is no cache: the directory of small files **is** the cheap window.
The newest 10 paths are the newest 10 entries, so a derived copy of them would only add a staleness check to forget.

Issues and backlog items are **one file per entry**, named `<UTC-timestamp>-<suffix>.md`.
Sequential IDs (ISS-0043, BK-0014) are gone: allocating one needed a scan and a lock over a single
shared file, which is exactly where two concurrent agents on a trunk-based workflow collide - and
even when the lock held, git still saw every writer touching one file, so merges conflicted.
A random 5-char suffix minted at write time needs neither, and distinct paths mean merges never meet.
Cross-references (`refs:`, `resolves:`) point at suffixes and are greppable across the tree.

`.claude/skills.toml` is written once and then belongs to the project: a re-run skips it rather
than refreshing it, the same rule `settings.local.json` gets. It names skills and never versions,
because the copies under `.claude/skills/` are pulled fresh from upstream at every session start
and a hand-maintained version table would be wrong within a week.

`.claude/skills/` is **not** written here. This skill writes the manifest and the gitignore line
that keeps the copies out of git; `skill-sync` installs the directories at session start and owns
them. Nothing in this skill ever writes a skill directory or removes one.

## Workflow

### 1. Scaffold

Dry run first - it always is by default:

```sh
scripts/scaffold.sh --project <dir>              # prints the plan, writes nothing
scripts/scaffold.sh --project <dir> --apply      # interviews, then commits the plan
scripts/scaffold.sh --project <dir> --apply --yes --full   # non-interactive, everything
scripts/scaffold.sh --project <dir> --apply --ci # also install the CI workflow
```

`--ci` copies [references/templates/ci/context-check.yml](references/templates/ci/context-check.yml)
to `.github/workflows/context-check.yml`, and only `--ci` does. The workflow runs the vendored
`check` verb, the same code an agent runs locally, so CI and the agent cannot disagree about what a
valid tree is. It is opt-in because a workflow in a project not hosted on GitHub is a red X nobody
asked for. Create-if-absent: a workflow the project has edited is never overwritten.

On a terminal `--apply` interviews the user about the optional extras (`README.md`, `git init`) and
shows what each produces before writing. `--yes` skips the interview.

`.gitignore` and `.dockerignore` are **not** extras - they install by default, because an agent that
commits `skill-sync`'s `.claude/cache/` or bakes a `.env` into an image has already done the damage by the time
anyone reviews it. Both come from
[references/templates/](references/templates/), which vendors the shared ignore set from
`claudes-markdown-12-rules`; re-pull that upstream rather than hand-editing a project's copy.
`--no-gitignore` / `--no-dockerignore` opt out.

Every project also gets the Execution Rail, the owner-facing status page, from
[references/templates/rail/](references/templates/rail/README.md): `report/rail.sh` rendered with the
project directory's name, an empty `report/plan.json`, and the engine under `report/rail/`. The
engine is refreshed like `.claude/scripts/`; `rail.sh` and `plan.json` are the project's own once
they exist and are never overwritten. The ledger and the built page are state under
`~/.local/state/<project>-<key>/rail/`, never in the repository.

**Existing files are appended to, never deleted or overwritten.** A file already present gains only
the sections it is missing. A non-empty file with none of the expected structure is reported and
left byte-identical - guessing an insertion point is how hand-written work gets destroyed.

### 2. Log an issue

```sh
scripts/log-issue.sh --project <dir> \
  --title T --severity low|medium|high --area A \
  --symptom S --trigger T --cause C --fix F --verify V \
  [--tags a,b] [--refs x7q2m] [--resolves a3f9c2] [--json]
```

Writes one entry file under `issues/YYYY/MM/` and prints the new suffix on stdout.
A fix for an earlier issue is a **new entry** with `--resolves`, never an edit of the old one.
Reading newest-first, the resolution arrives before the problem it closed.

### 3. Manage the backlog

```sh
scripts/backlog.sh add   --project <dir> --title T --why W --done-when D [--bucket now|next|later]
scripts/backlog.sh move  --project <dir> --id a3f9c2 --to now
scripts/backlog.sh done  --project <dir> --id a3f9c2
scripts/backlog.sh list  --project <dir> [--bucket B] [--json]
```

A move is a rename between bucket directories; `done` renames into the `done/YYYY/MM/` shard and
stamps `completed:` in the metadata. `--id` takes a suffix; a suffix matching more than one file
is refused as ambiguous (exit 3) rather than guessed.

### 4. Migrate and check

```sh
scripts/log-issue.sh migrate --project <dir>   # ISSUES.md and BACKLOG.md -> issues/ and backlog/, one run
scripts/backlog.sh  migrate --project <dir>    # the same verb; either script runs it
scripts/log-issue.sh check   --project <dir>   # validates the tree, exit 3 names every offender
scripts/backlog.sh  check   --project <dir>
```

`migrate` is a one-time conversion of both monoliths in one run: it preserves each entry's recorded
timestamp as its filename and shard, and rewrites `refs:`/`resolves:` through one map that holds
both the `ISS-` and the `BK-` IDs, so a reference across the trees survives.
Every timestamp is checked before the first write, and a failure undoes the whole run, so a refused
migrate can be fixed and rerun. It refuses to run twice.
`check` validates filename shapes, shard placement, metadata completeness, duplicate suffixes,
dangling references, and that no hand-written monolith sits beside the directories.

## Contracts every tool honours

| Property | Rule                                                                                           |
| -------- | ---------------------------------------------------------------------------------------------- |
| stdout   | data only - an ID, or one JSON object under `--json`                                           |
| stderr   | every human word, including prompts and progress                                               |
| exit 0   | success                                                                                        |
| exit 2   | usage - unknown flag, missing or empty required value                                          |
| exit 3   | validation - bad enum, ambiguous ID, a `check` that found an invalid tree                      |
| exit 4   | io - unreadable or unwritable path                                                             |
| exit 6   | not found - a referenced ID does not exist                                                     |
| writes   | atomic (staged, then renamed); entry creation needs no lock - each name is unique at mint time |
| input    | written literally; nothing in a field value is ever evaluated                                  |

Branch on the exit code, never on the message text.

## Reading a scaffolded project

Stated in the installed `AGENTS.md`, and worth repeating here:

1. `COMPASS.md` first - it routes, it does not explain.
2. `issues/` - **the newest 10 entries, then stop.** The window is a directory walk: filenames and
   shard directories sort chronologically, so the newest 10 paths in reverse order ARE the newest
   10 entries. Go deeper only on request, or when an entry in the window references a suffix you need.
3. `backlog/` when choosing work - `now/` / `next/` / `later/` in full (live work, capped by
   discipline), `done/` **newest 10 only**. Done is kept indefinitely under month shards so a recent
   item stays findable, but retention is not a reading depth.
4. `NAMING.md` before naming anything.

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
