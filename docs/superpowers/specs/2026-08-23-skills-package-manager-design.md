# Skills package manager - design

Date: 2026-08-23
Status: draft, awaiting review
Discovery input: [`notes/skills-pm-discovery.md`](../../../notes/skills-pm-discovery.md)

## Problem

Skills are distributed to projects as copies.
A copy cannot know the original moved on, so the repo has grown machinery to detect and repair that drift: per-skill semver, a content-hashed registry, a session-start comparison, and a per-skill update script that opens and merges a pull request.

None of it is automatic.
The session-start check at `CLAUDE.md.tmpl:269` is prose, not code.
There is no `SessionStart` hook anywhere in the repository.
The version comparison is performed by the model reading two lists, which Rule 5 explicitly forbids.
The check then blocks and asks a human to pick one of three options before any work begins.

Separately, nothing records what a project wants.
The check greps `.claude/skills/*/SKILL.md`, so it can only see what is already installed.
A skill that should be present but never was is undetectable.

## The bet

**Disposable beats reconcilable.**

Almost everything expensive in a package manager exists to reconcile a mutable local install against a moving upstream.
Remove the mutability and most of the machinery stops being necessary.

If `.claude/skills/` is gitignored and rebuilt wholesale from upstream on every session, then there is no drift to detect, no version to pin, no conflict to resolve, and no lockfile to maintain.
The only thing worth committing is the list of names.

## Goals

- The sync runs every session, before any work, with no human in the loop.
- It reaches projects that were never scaffolded and projects scaffolded before this change, without migrating them.
- A project declares what it wants in one committed file.
- Failure is loud and never blocks a session.
- Semver and the registry are maintained by CI, not by memory.

## Non-goals

- Reproducing an old skill tree. Always-latest is the point.
- Managing skills in repositories that deliberately commit them. Those keep `skill-update.sh`.
- Cross-harness distribution. Claude Code only.
- Touching the 29 skills in this repo that are not symlinked into `~/.claude/skills`.

## Prerequisite

`.claude/skills/` is not gitignored today.
`gitignore.tmpl:30` ignores `**/.claude/agents/` and nothing ignores skills.
`prospector-be` has its skills committed to the index.

Adding `.claude/skills/` to `gitignore.tmpl` is what makes this design valid.
Everything below assumes it.

## Components

| Component          | Location                                                                   | Role                                             |
| ------------------ | -------------------------------------------------------------------------- | ------------------------------------------------ |
| Registry           | `claude/skills/registry.json`                                              | the index. Exists, gains a `tools` block         |
| Manifest           | `<project>/.claude/skills.toml`                                            | declared intent. Committed. New                  |
| Receipt            | `<project>/.claude/cache/skills-receipt.json`                              | what actually landed. Gitignored. Debugging only |
| Stamp              | `<project>/.claude/cache/.sync-stamp`                                      | re-sync guard. Gitignored                        |
| Sync tool          | `claude/tools/skill-sync.sh` upstream, `~/.local/bin/skill-sync` installed | does the work                                    |
| Onboarder          | `claude/tools/skill-onboard.sh`                                            | brings an existing project onto the system       |
| Publisher          | `.github/workflows/skill-semver.yml`                                       | bumps and regenerates on the PR branch           |
| Standalone updater | `claude/skills/skill-versioning/scripts/skill-update.sh`                   | unchanged, narrowed role                         |

The sync tool lives at `claude/tools/`, not under `claude/skills/`.
Everything under `claude/skills/<name>/` is a package that gets synced into projects, and the syncer must not be one of its own packages.

## The tool is a binary on PATH, not a path in the project

This follows from the hook being machine-level.

A `SessionStart` hook in `~/.claude/settings.json` fires in every project on the machine, including projects that have never heard of this system.
A hook command of `bash .claude/cache/skill-sync.sh` would therefore fail in most of them.

So the hook invokes a binary that is always present, and the binary decides whether there is anything to do:

```
skill-sync --boot
  |
  +- no .claude/skills.toml here?  ->  exit 0, print nothing
  +- stamp under 30 min old?       ->  exit 0, print nothing
  +- otherwise                     ->  sync
```

`setup.sh` installs it, the same way it already installs skills, alongside the existing `gh-axi` / `lavish-axi` / `chrome-devtools-axi` tools that use the same pattern.

This also simplifies self-update: one copy per machine in `~/.local/bin`, not one per project, and the `.bak` sits beside it.

## Data formats

### Manifest

```toml
# .claude/skills.toml
# What this project uses. Contents are pulled fresh from upstream on every sync;
# nothing here pins a version on purpose.

[skills]
use = [
  "work-order",
  "living-docs",
  "project-scaffold",
  "container-sandbox",
]

[agents]
use = [
  "polyglot-code-reviewer",
  "k8s-master",
]
```

Written by `project-scaffold` at scaffold time with a default set, and by `skill-onboard.sh` for existing projects.
Hand-editable; re-sync applies it.

`[agents]` is included because agents are already gitignored and already installed by `setup.sh`, but carry no version, no registry row, and no update path.
They are the half of the library with no loop at all.

### Registry, schema 2

```json
{
  "schema": 2,
  "generator": "skill-version.sh",
  "skills": {
    "living-docs": {
      "version": "1.0.0",
      "sha256": "...",
      "type": "skill",
      "requires": ["work-order"]
    }
  },
  "tools": {
    "skill-sync": { "version": "1.0.0", "sha256": "..." }
  }
}
```

`type` is routing only: `skill` to `.claude/skills/`, `agent` to `.claude/agents/`.

`requires` is a hard dependency and is auto-installed.
Two edges exist, both on `work-order`, both currently prose only:

- `cartography/SKILL.md:42` states it takes `work-order` as a sibling skill directory and that **there is no degraded mode**. `cartograph.sh` shells out to `work-order.sh` and never writes ticket markdown itself.
- `living-docs/SKILL.md:20,173` binds its documentation gate to `work-order`'s acceptance criteria.

Advisory would be the wrong choice here: both are hard failures on first run, and there are only two of them, so auto-install costs nothing and prevents the only half-installs that exist.

`cartography`'s reference to `figma-wireframe` is disambiguation, not a dependency, and is deliberately not encoded.

### Receipt

```json
{
  "synced": "2026-08-23T18:04:11Z",
  "source": "jkkelley/dotfiles@a1b7bb1",
  "status": "ok",
  "skills": {
    "work-order": { "version": "1.0.1", "sha256": "9f2c..." }
  }
}
```

Never read for resolution.
Read by a human when something behaves oddly, and by anything that wants to assert the last sync succeeded.

## Flows

### Session sync

```
session starts
  |
  v
SessionStart hook, ~/.claude/settings.json, matcher "", timeout 30
  |
  +- skill-sync --boot
       |
       +- no .claude/skills.toml         -> exit 0, silent
       +- stamp under 30 min             -> exit 0, silent
       |
       +- sweep stale .sync.* temp dirs (older than 1h)
       +- fetch registry.json
       +- resolve manifest + requires
       +- build the full tree into .claude/cache/.sync.XXXXXX
       +- atomic swap into .claude/skills/ and .claude/agents/
       +- write receipt, write stamp
       |
       +- self stale?  -> see self-update below
  |
  v
agent starts, reads ~6 lines about skills, does nothing
  |
  v
work starts
```

### Self-update

```
sync_everything                       # real work first, with the known-good binary

if self_is_stale && [[ -z "${SKILL_SYNC_CHILD:-}" ]]; then
  mv -f "$SELF" "$SELF.bak"           # rename, NOT copy - see failure modes
  curl -fsS "$UPSTREAM" -o "$SELF" || { mv -f "$SELF.bak" "$SELF"; die "fetch failed"; }
  chmod +x "$SELF"

  if SKILL_SYNC_CHILD=1 bash "$SELF" "$@"; then
    echo "self-updated to $(read_version "$SELF")"
  else
    mv -f "$SELF.bak" "$SELF"
    die "new version failed, rolled back to $(read_version "$SELF")"
  fi
fi
```

One `.bak` is kept and overwritten each time.

### Publish, on the PR branch

```
PR opened or updated
  |
  v
skill-version.sh verify
  |
  +- passes -> exit 0, nothing to do
  |
  +- fails
       |
       +- which skills:  git diff --name-only origin/main...HEAD -- claude/skills/
       +- how much:      commit type. feat -> minor, fix -> patch,
       |                 feat! or BREAKING CHANGE -> major
       +- skill-version.sh bump <name> --<level>   (regenerates registry.json)
       +- commit and push to the PR branch
       |
       v
     workflow reruns, verify passes, no-op
```

Self-terminating by construction, because `verify` is a pure check.
No `[skip ci]` and no actor filters are needed.
`GITHUB_TOKEN` pushes do not retrigger workflows, which is the wanted behaviour.

It runs on the PR branch and never on `main`, because this repo's rule is that `main` is written once and never again directly.
The merge carries the bump.

Commit scope is deliberately ignored when deciding which skills changed.
`feat(skills):` is generic and `fix(work-order,project-scaffold):` is multi, so the file list is authoritative and the commit type contributes only the level.

### Onboarding an existing project

The user's working tree is never touched.
No stash, no branch switch.

```
skill-onboard.sh --project <path>
  |
  +- git worktree add <tmp> origin/main
  +- write .claude/skills.toml
  +- add .claude/skills/ to .gitignore
  +- git rm -r --cached .claude/skills/   (only where they were committed)
  +- replace the CLAUDE.md session-start block
  +- commit, push, open PR, squash-merge, delete branch
  +- git worktree remove <tmp>
```

No hook is installed by this script.
The hook is machine level and `setup.sh` owns it.

The stash-based alternative was rejected.
The stash stack is shared across the main checkout and every worktree, other sessions can pop it concurrently, and bare `stash`/`pop` can restore someone else's work.
An onboarding script operating on a dirty tree is the worst possible place to accept that risk, and the worktree pattern removes the need entirely.
`skill-update.sh --mode standalone` already uses this pattern and its header states why.

## Failure modes

| Mode                              | Handling                                                                                                       |
| --------------------------------- | -------------------------------------------------------------------------------------------------------------- |
| Registry unreachable              | exit 0, print a loud two-line warning, leave the tree untouched                                                |
| Timeout mid-sync                  | tree is built in a temp dir and swapped atomically, so the previous state survives intact                      |
| Hard kill skips the `trap`        | temp dirs are created inside `.claude/cache/` with a `.sync.` prefix; every run sweeps ones older than an hour |
| New version of the tool is broken | `.bak` is restored and the failure is reported                                                                 |
| Self-update loop                  | `SKILL_SYNC_CHILD=1` makes the recursion one deep by construction                                              |
| Sync fires during auto-compact    | stamp file suppresses it                                                                                       |
| Hook itself fails                 | always exits 0. A non-zero `SessionStart` hook takes the session with it                                       |

### Ran is not worked

`|| true` conflates two requirements that must stay separate.

| Requirement            | Mechanism                                              |
| ---------------------- | ------------------------------------------------------ |
| Never kill the session | always exit 0                                          |
| Never hide a failure   | print loudly; hook stdout lands in the agent's context |

```
!! SKILL SYNC FAILED - registry unreachable after 3 tries
!! Skills are as of 2026-08-21. Say so before doing skill-dependent work.
```

Plus `"status": "failed"` in the receipt.
Silent success on failure is the defect being removed here; blocking is not the price of removing it.

### `mv`, never `cp`

Bash reads a script lazily, by byte offset, as it executes.
Overwriting the file in place makes the running shell read garbage from wherever it had reached.

`mv script script.bak` is a rename: the inode survives, the running shell keeps reading it, and `curl -o script` creates a new file.
This ordering is correct and must not be simplified into `cp script script.bak && curl -o script`, which truncates the live inode and fails in ways that look like anything except a self-update bug.

The line carries a comment saying so.

## Template changes

### Session-start block

Roughly 68 lines of prose (`CLAUDE.md.tmpl:269-336`) collapse to:

```markdown
## Skills

Synced automatically by a SessionStart hook before any work starts. You do not
run anything. If you see sync output, that is what changed; otherwise ignore it.
Never edit a skill in place - `.claude/skills/` is gitignored and the next sync
deletes it silently. Fix it in dotfiles, bump it, done.
```

### Installed list

Names only, no versions, generated between markers by the sync.

```markdown
<!-- skills:begin - generated by skill-sync, do not hand-edit -->

| Skill             | Agent                  |
| ----------------- | ---------------------- |
| container-sandbox | k8s-master             |
| work-order        | polyglot-code-reviewer |

<!-- skills:end -->
```

No version numbers in prose.
A hand-maintained version table is wrong within a week, and a stale one is worse than none because agents believe it.

### Documentation destination

The current rule at `CLAUDE.md.tmpl:92-111` says every runbook and playbook lives in `local-k8s-docs`.
`living-docs` writes procedures to `<project>/docs/sops/` via `docs.sh sop`.
Both are stated as the way it is done and nothing arbitrates, so it lands wherever the agent read last.

`living-docs` is correct as written and is not the thing to change.
Lifetime is the discriminator:

```markdown
## Hard rule: documentation goes where its lifetime says it goes

One question decides it: **would this still be true after this repo is deleted?**

| Answer                                               | Where it goes                              |
| ---------------------------------------------------- | ------------------------------------------ |
| Yes - the cluster, the pipeline, Vault, the platform | https://github.com/jkkelley/local-k8s-docs |
| No - it only makes sense inside this codebase        | this repo's `docs/`, via `living-docs`     |

Both halves are mandatory, and the second is the one that gets skipped.
If you worked out a process in order to finish a task, that process is a document
that does not exist yet. Write it, in whichever of the two the question above picks.

When you are following one, follow **its** format, not your own improved version.
```

## Rule 16 rewrite

From "you must remember to bump the version and ship the regenerated registry" to:

> CI bumps the version and regenerates the registry on the PR branch.
> Your commit type picks the level: `feat` minor, `fix` patch, `feat!` or `BREAKING CHANGE` major.
> `skill-version.sh verify` is the gate and runs on every PR.

The obligation does not disappear, it stops depending on memory.

## What survives, what changes, what goes

| Thing                                 | Fate                                                                               |
| ------------------------------------- | ---------------------------------------------------------------------------------- |
| `registry.json`                       | survives, schema 2, gains `tools` and per-skill `type` / `requires`                |
| `skill-version.sh`                    | survives. `render_registry` learns the new schema                                  |
| `skill-update.sh`                     | survives, narrowed to the standalone committed-skill case. Header states the split |
| Rule 16                               | rewritten, enforced by CI                                                          |
| Session-start prose check             | deleted, replaced by the hook                                                      |
| `--mode inline` / `--mode standalone` | survive for standalone projects only. Meaningless once a project is gitignored     |
| `setup.sh`                            | gains: install the binary, install the machine hook                                |
| Lockfile                              | never introduced                                                                   |

## Migration

| Population                                      | Action                                                                         |
| ----------------------------------------------- | ------------------------------------------------------------------------------ |
| Any project on this machine                     | none. The machine-level hook covers it, and the tool no-ops without a manifest |
| Project that wants in                           | run `skill-onboard.sh`                                                         |
| Project with skills committed (`prospector-be`) | `skill-onboard.sh` includes `git rm -r --cached`                               |
| A new machine                                   | run `setup.sh`                                                                 |

There is no migration for the hook itself, which is the main reason it is machine level.

## Decisions needing sign-off

Everything else in this document is settled.
These five are recommendations, not conclusions.

1. **Single source.** No skill needs a source other than the public dotfiles URL. `operator`'s skill is public here; only the data repo it points at is private. Recommend the registry stays one flat list at one address.
2. **Stamp window: 30 minutes.** Arbitrary. Long enough that compacts are free, short enough that a same-day upstream change lands. Needs a real number or an accepted shrug.
3. **`skill-versioning` keeps its name.** It sheds the consume side and becomes the publish discipline plus `skill-update.sh`. Renaming is churn across every SKILL.md read-only notice. Recommend keeping it.
4. **CI runs `verify` plus the test suites of changed skills.** Several skills ship `testing/run-tests.sh`. Rule 14 says tests run in Podman, which GitHub Actions can do. Recommend both, and it is the larger implementation cost in this document.
5. **Rule 17.** `skill-sync.sh` carries a `justfile` and avoids `flock`, `cmp`, and `diff`. `curl` and `git` are present in Git Bash. Recommend treating Windows as supported rather than declaring the tool Linux-only.

## Open, not yet designed

- Whether `project-scaffold` writes a default manifest, and what is in it.
- Whether the generated CLAUDE.md table is written by the sync or by `scaffold.sh`.
- Test strategy for `skill-sync.sh` itself, per `container-sandbox/references/skill-testing.md`.
