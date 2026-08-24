# Discovery: a personal package manager for skills and docs

Session type: discovery only.
No design, no implementation, no tickets.
Base commit: `a1b7bb1`.

The next phase is a design doc, in its own session.
This file is the raw material that session opens with.

## The idea in one paragraph

One registry (this repo), one sync tool, one declared manifest per project, and a
disposable install directory that is rebuilt from upstream rather than reconciled
with it.
Because the install is disposable, there is no lockfile, no drift detection, no
version pinning, and no update conflict class.
The manifest records intent, git is the source of truth, and the sync is
deterministic and destructive.
Skills, agents, and doc standards all travel the same path.
The only thing committed to a consuming project is the list of names.

The bet the whole design rests on: **disposable beats reconcilable.**
Most of what is expensive in a normal package manager exists to reconcile a mutable
install against a moving upstream.
Remove the mutability and most of the machinery stops being necessary.

## What already exists

Five of the seven parts of a package manager are here and working.

| Part      | Equivalent             | Here                                          | Status                    |
| --------- | ---------------------- | --------------------------------------------- | ------------------------- |
| Package   | package dir + manifest | skill dir + SKILL.md frontmatter              | present                   |
| Registry  | registry.npmjs.org     | `claude/skills/registry.json`, content-hashed | present                   |
| Store     | `~/.npm/_cacache`      | this git repo                                 | present                   |
| Publish   | `npm publish`          | git push + Rule 16                            | present                   |
| Integrity | `integrity:`           | `sha256` per skill                            | present                   |
| Manifest  | `package.json` deps    | nothing                                       | **missing**               |
| Lockfile  | `package-lock.json`    | nothing                                       | **not needed, see below** |

The registry is genuinely good.
Content-hashing every package is more than most real registries do.

`setup.sh` has a config-file mode accepting `skills=a b c`, which is most of a
manifest already.
It is discarded after the install instead of committed, so it records intent for one
invocation and nothing after that.

## The current session-start flow, as it actually runs

```
Session starts in a scaffolded project
|
+- Does anything run automatically?
|     NO. settings.json.tmpl is only {"attribution": {...}}
|     No SessionStart hook. No verify.sh.
|     grep for SessionStart across the repo returns nothing.
|
+- Agent reads CLAUDE.md top to bottom
   |
   +- line 269: "## Session start - skill version check"
      |
      |   Prose in a ~360-line file. An instruction addressed to the
      |   agent, not code. Runs only if the agent reads that far and
      |   decides to follow it.
      |
      +- .claude/skills/ missing? -> skip entirely
      |
      +- STEP 1  agent runs two commands by hand
      |     curl .../dotfiles/main/claude/skills/registry.json
      |     grep -H '^version:' .claude/skills/*/SKILL.md
      |
      +- STEP 2  agent compares the two lists by eye
      |     no version: line     -> treat as behind
      |     absent from registry -> project-local, ignore silently
      |     curl failed          -> one line, continue, never block
      |
      +- STEP 3  all match -> say nothing, start work
      |
      +- STEP 4  anything behind -> print table, offer 3 options, WAIT
            |
            +- [1] Update now      skill-update.sh --mode standalone
            |                      throwaway worktree, commit, push, PR,
            |                      squash-merge unreviewed, delete branch, ff main
            +- [2] Fold into work  --mode inline, copy in, leave uncommitted
            +- [3] Note and move on
```

### Six gaps between that and a deterministic loop

|     | Gap                                                                                                                                                                                            |
| --- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| a   | Nothing triggers it. No hook. Prose at line 269, competing with everything above it                                                                                                            |
| b   | The diff is done by the model. Rule 5 says if code can answer, code answers. Comparing two version lists is a deterministic transform being eyeballed                                          |
| c   | It blocks on a human. Even with an unambiguous answer it stops and waits for 1/2/3                                                                                                             |
| d   | One skill per run. Five stale skills is five invocations and, in mode 1, five auto-merged PRs                                                                                                  |
| e   | It can only see what is already installed. It greps `.claude/skills/*/SKILL.md`. A skill that should be present but never was is undetectable, because nothing declares what the project wants |
| f   | Modes 1 and 2 exist only because the directory is committed                                                                                                                                    |

Gap (f) collapses the tree: gitignore the directory and both modes evaporate, because
there is nothing to commit.

Gap (e) is the only one that still needs a committed file.

## The blocking prerequisite

`.claude/skills/` is **not** gitignored today, and in at least one project it is
committed:

```
$ grep -n "claude" claude/skills/project-scaffold/references/templates/gitignore.tmpl
30:**/.claude/agents/          <- agents ARE ignored
                               <- skills are NOT

$ git -C ~/projects/prospector-fe-be/prospector-be ls-files .claude/skills
.claude/skills/api-design-checklist/SKILL.md
.claude/skills/backend-patterns/SKILL.md
```

Adding `.claude/skills/` to `gitignore.tmpl` is the single change that makes the
disposable model valid.
Everything else in this note assumes it.

Migration: at least `prospector-be` has skills committed and will need them removed
from the index.

## Proposed shape

### The manifest, the only new committed file

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

Written by `project-scaffold` at scaffold time with a default set.
Hand-editable, then re-sync.

`[agents]` is included because agents are already gitignored and already installed by
`setup.sh`, but carry no version, no registry row, and no update path.
They are the half of the library with no loop at all.

### No lockfile

npm needs one to reproduce an exact tree months later.
That is explicitly not wanted here: gitignored, wiped, always-latest.
A lockfile would be a promise never intended to be kept.

What survives is a **receipt**, for debugging only, in a directory the gitignore
template already declares derived and never authoritative (line 80,
`.claude/cache/`):

```json
// .claude/cache/skills-receipt.json
{
  "synced": "2026-08-23T18:04:11Z",
  "source": "jkkelley/dotfiles@a1b7bb1",
  "skills": {
    "work-order": { "version": "1.0.1", "sha256": "9f2c..." },
    "living-docs": { "version": "1.0.0", "sha256": "4ab1..." }
  }
}
```

Never read for resolution.
Read by a human when something behaves oddly.

### Two registry additions

```json
"living-docs": {
  "version": "1.0.0",
  "sha256": "...",
  "type": "skill",
  "requires": ["work-order"]
}
```

`type` is routing only: `skill` to `.claude/skills/`, `agent` to `.claude/agents/`.

An earlier `type: "reference"` idea was dropped. It existed to stop the 13
agent-payload docs from costing description tokens, and the manifest already solves
that: a project that does not list them does not get them.

### The dependency edges, complete

Two, both on `work-order`, both hard, both currently prose only.

`cartography/SKILL.md:42`

> **work-order**, as a sibling skill directory, at `$CARTO_WORK_ORDER`, or via
> `--work-order PATH`. There is no degraded mode.

`cartograph.sh` shells out to `work-order.sh` and never writes ticket markdown
itself. Installed alone, cartography is broken on first run.

`living-docs/SKILL.md:20`, `:173`

> The enforcement already exists in `work-order`, so there is no new gate to build.
> `work-order` skill - owns the acceptance criteria this skill binds documentation to.

Not a dependency: cartography's "Not for wireframing a UI - that is figma-wireframe"
is disambiguation. Do not encode it.

### The sync script - decided

Lives upstream at `claude/tools/skill-sync.sh`.
**Not** under `claude/skills/`: everything under `claude/skills/<name>/` is a package
that gets synced into projects, and the syncer must not be one of its own packages.

Lands in a project at `.claude/cache/skill-sync.sh`.
That directory is already gitignored and already declared derived and never
authoritative, so the `.bak` needs no new gitignore line.
`cache.sh` only ever rebuilds that directory, never prunes it.

Bootstrapped by a one-line pointer in the CLAUDE.md template, then self-maintaining.

Versioned in `registry.json` under a new `tools` block, schema 2:

```json
{
  "schema": 2,
  "generator": "skill-version.sh",
  "skills": { "...": {} },
  "tools": {
    "skill-sync": { "version": "1.0.0", "sha256": "..." }
  }
}
```

`render_registry` at `skill-version.sh:115` has to learn to emit it.
Rule 16: the script owns the format, nothing is hand-edited.

#### Self-update flow

```
CLAUDE.md pointer  --curl-->  .claude/cache/skill-sync.sh     (bootstrap, once)
                                        |
                                        v
                              1. sync skills + agents from registry
                              2. am I stale?  registry.tools.skill-sync.version
                                        |
                                   no --+-- yes
                                   |         |
                                 done        mv self -> self.bak  (overwrite old .bak)
                                             curl new self
                                             bash new self, SKILL_SYNC_CHILD=1
                                                  |
                                            ok ---+--- fail
                                            |           |
                                          done      mv .bak -> self, exit 1
```

#### Three constraints the implementation must honour

**1. Re-exec guard.** If the new copy also reads itself as stale - registry
unreachable mid-run, empty version parse, botched publish - it self-updates forever.
An env var makes the recursion one deep by construction rather than by hoping the
versions line up:

```bash
if [[ -z "${SKILL_SYNC_CHILD:-}" ]]; then
  # only the parent may self-update
fi
```

**2. `mv`, never `cp`.** Bash reads a script lazily by byte offset as it executes.
Overwriting the file in place makes the running shell read garbage from wherever it
had got to.
`mv script script.bak` is a rename: the inode survives, the running bash keeps
reading it, and `curl -o script` creates a new file.
This ordering is correct and must not be "cleaned up" into
`cp script script.bak && curl -o script`, which truncates the live inode and fails in
ways that look like anything but a self-update bug.
The line needs a comment saying so.

**3. Fork, do not `exec`.** `exec` replaces the process, so the old script is gone and
nothing is left to restore the `.bak` when the new version fails.
The old script stays alive as supervisor:

```bash
sync_everything                       # real work, with the known-good script

if self_is_stale && [[ -z "${SKILL_SYNC_CHILD:-}" ]]; then
  mv -f "$SELF" "$SELF.bak"           # rename, not copy - see constraint 2
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

`bash "$SELF"`, not `exec`. That is the difference between the `.bak` being a
rollback and being decorative.

### What goes in the CLAUDE.md template

Names only, no versions, generated between markers.

```markdown
## Skills and agents in this project

<!-- skills:begin - generated by sync, do not hand-edit -->

| Skill             | Agent                  |
| ----------------- | ---------------------- |
| container-sandbox | k8s-master             |
| living-docs       | polyglot-code-reviewer |
| project-scaffold  |                        |
| work-order        |                        |

<!-- skills:end -->

Declared in `.claude/skills.toml`.

`.claude/skills/` and `.claude/agents/` are gitignored and rebuilt from upstream on
every sync. Never edit a skill in place - the next sync deletes it without warning.
Fix it in dotfiles, bump it, sync.
```

No version numbers in prose. A hand-maintained version table is wrong within a week,
and a stale one is worse than none because agents believe it.

## The two CLAUDE.md template rewrites

### 1. Replace the runbook rule (currently lines 92-111)

The rule as written collides with `living-docs`.
An agent that has worked out a procedure gets two contradictory instructions:
`CLAUDE.md.tmpl:92-105` says write it in `local-k8s-docs`, while
`living-docs/SKILL.md:41,90` writes it to `<project>/docs/sops/` via `docs.sh sop`.
Nothing arbitrates, so it lands wherever the agent read last.

`living-docs` is correct as written and is not the thing to change.
Lifetime is the discriminator: knowledge that outlives any single repo goes to the
one docs repo, everything else rides along with the project.

```markdown
## Hard rule: documentation goes where its lifetime says it goes

One question decides it: **would this still be true after this repo is deleted?**

| Answer | Where it goes |
| --- | --- |
| Yes - it is about the cluster, the pipeline, Vault, the platform | https://github.com/jkkelley/local-k8s-docs |
| No - it only makes sense inside this codebase | this repo's `docs/`, via `living-docs` |

Both halves are mandatory, and the second one is the one that gets skipped.
If you worked out a process in order to finish a task, that process is a document
that does not exist yet. Write it, in whichever of the two the question above picks.

When you are following one, follow **its** format, not your own improved version.
```

### 2. Replace the session-start check (currently lines 269-336)

Deletes roughly 68 lines: the curl/grep pair, the eyeball comparison, and the
three-option prompt.
No human decision remains, and no agent action either - a SessionStart hook runs the
sync before the session begins. See "The sync runs automatically" below for the hook
itself; this is only what is left in the prose.

```markdown
## Skills

Synced automatically by a SessionStart hook before any work starts. You do not
run anything. If you see sync output, that is what changed; otherwise ignore it.
Never edit a skill in place - `.claude/skills/` is gitignored and the next sync
deletes it silently. Fix it in dotfiles, bump it, done.
```

## skill-update.sh keeps a job

Lives at `claude/skills/skill-versioning/scripts/skill-update.sh`, 11.9KB.

There is no GitHub Actions pipeline in this repo - no `.github/` directory at all -
so nothing automates semver. `skill-version.sh bump` is run by hand under Rule 16.

What loses purpose is narrower than the script: `--mode standalone` and
`--mode inline` both exist only to get a changed file committed into the project
repo. Gitignore `.claude/skills/` and there is nothing to commit, so for a synced
project neither mode has work to do.

The core capability stays valuable and is the standalone case: fetch ONE named skill
from GitHub, into a project, on a machine with no dotfiles checkout.

| | Skills are | Tool | Trigger |
| --- | --- | --- | --- |
| Synced project | gitignored, disposable, whole set | `skill-sync.sh` | SessionStart hook, automatic |
| Standalone skill | committed, deliberate, one at a time | `skill-update.sh` | by hand, one skill |

Header to add to the script, above the existing `Two apply modes` block:

```bash
# ROLE, since skill-sync.sh exists
#
# This script updates ONE named skill, deliberately, in a project that COMMITS
# its skills. That is the standalone case and it is the only case this script
# serves now.
#
# It is NOT the session-start path. A project whose .claude/skills/ is gitignored
# is synced wholesale by skill-sync.sh from a SessionStart hook, with no PR and
# no human choice, because there is nothing to commit. The --mode inline and
# --mode standalone distinction below only means anything when the skill
# directory is tracked by git.
```

The same split gets recorded in dotfiles `CLAUDE.md`, beside Rule 16, where the
skill-edit obligation already lives.

## The sync runs automatically - and the hook lives on the machine

Not prose, not agent-driven, and **not primarily in the project template**.

A hook shipped in `settings.json.tmpl` can only fire in projects that already have
the template. Projects scaffolded before this change, and projects never scaffolded
at all, are exactly the population that needs reaching. The guarantee has to live
outside the thing being guaranteed.

`~/.claude/settings.json` already runs SessionStart hooks on this machine
(`lavish-axi`, `gh-axi`, `chrome-devtools-axi`, all `"matcher": ""`, `timeout: 10`).
Observed firing on both startup and resume. That is the mechanism.

|                               | Hook in project template | Hook in `~/.claude/settings.json` |
| ----------------------------- | ------------------------ | --------------------------------- |
| New scaffolded project        | works                    | works                             |
| Project scaffolded last year  | no hook                  | works                             |
| Project never scaffolded      | no hook                  | works                             |
| Project with no `skills.toml` | n/a                      | no-ops instantly                  |
| Migration needed              | every project            | none                              |

**Install in both.** Machine level is the guarantee and needs no migration. Project
level is documentation - the repo describes its own requirements and works for
anyone who clones it without these dotfiles. The stamp file below makes the second
firing a no-op, so double-install is free.

`setup.sh` installs the machine-level hook, the same way it already installs skills.

Consequence: the onboarding script no longer installs a hook anywhere. It shrinks to
writing `skills.toml`, the gitignore lines, and `git rm -r --cached` where needed -
which removes most of the reason it needed a PR at all.

```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "",
        "hooks": [
          { "type": "command", "timeout": 30, "command": "skill-sync --boot" }
        ]
      }
    ]
  }
}
```

### Five constraints, all of which fail silently

**1. Atomic swap, not in-place rewrite.** Existing hooks use `timeout: 10`. A cold
sync - fetch registry, download a dozen skill directories - can exceed that on a bad
connection. Killed mid-write leaves a _half-written_ skills directory, which is worse
than a stale one. Build into a temp dir, swap at the end. A timeout then leaves the
previous state fully intact.

**2. Temp cleanup survives a hard kill.**

```bash
TMP=$(mktemp -d "${CACHE}/.sync.XXXXXX")
trap 'rm -rf "$TMP"' EXIT
```

`trap ... EXIT` fires on success, error, and Ctrl-C. It does **not** fire on a hard
kill, which is precisely what a hook timeout does. So the temp dir is created inside
`.claude/cache/` with a known prefix, and every run sweeps `.sync.*` older than an
hour before starting. The one failure mode that skips the trap is the likeliest one.

**3. Ran is not worked.** `|| true` currently conflates two requirements. Split them:

| Requirement            | Mechanism                                              |
| ---------------------- | ------------------------------------------------------ |
| Never kill the session | always exit 0. A dead hook is a dead session           |
| Never hide a failure   | print loudly; hook stdout lands in the agent's context |

```
!! SKILL SYNC FAILED - registry unreachable after 3 tries
!! Skills are as of 2026-08-21. Say so before doing skill-dependent work.
```

Plus `"status": "failed"` in the receipt so it is machine-checkable. Silent success
on failure is the defect being removed; blocking is not the price of removing it.

**4. Stamp file, not matcher surgery.** SessionStart fires on four sources:
`startup`, `resume`, `clear`, and `compact`. Only the last is a problem - auto-compact
happens mid-task, and syncing then deletes and rewrites skill files while an agent is
halfway through using them.

```
sync runs  ->  write .claude/cache/.sync-stamp
next run   ->  stamped under 30 min ago? print nothing, exit 0
```

Simpler than matcher filtering, and it is what makes the both-levels install free.

**5. A new machine** needs `setup.sh` to have run. Already true of everything else
here, so not new debt, but it is the one place the guarantee genuinely does not hold.

## CI replaces the Rule 16 obligation

There is no `.github/` in this repo today. Nothing automates semver;
`skill-version.sh bump` is run by hand.

The bump _level_ cannot be read from a diff, but it can be read from the commit
convention already followed rigorously here (`fix(context-compaction):`,
`feat(project-scaffold):`, `feat(skill-versioning):`).

| Question                 | Source                                                                    |
| ------------------------ | ------------------------------------------------------------------------- |
| **Which** skills changed | `git diff --name-only origin/main...HEAD -- claude/skills/`               |
| **How much** to bump     | commit type: `feat` minor, `fix` patch, `feat!` / `BREAKING CHANGE` major |

Files answer which, commit type answers how much. Nothing is inferred by a model.
Scope is deliberately ignored: `feat(skills):` is generic and
`fix(work-order,project-scaffold):` is multi.

**Runs on the PR, never on main.** This repo's rule is that main is written once and
never again directly, so CI commits the bump back to the PR branch and the merge
carries it.

**The loop guard falls out for free**, because `verify` is already a pure check:

```
verify passes  ->  nothing to do, exit 0
verify fails   ->  bump, regen registry, commit, push
                   next run: verify passes, no-op
```

Self-terminating by construction. No `[skip ci]`, no actor filters. `GITHUB_TOKEN`
pushes do not retrigger workflows anyway, which is the wanted behaviour.

**Rule 16 rewrites** from "you must remember to bump and ship the registry" to "CI
bumps, your commit type picks the level, `verify` is the gate."

## Onboarding existing projects - no stash

Scriptable, and roughly 70% already exists inside `skill-update.sh`.

The originally sketched flow was: check branch, stash, checkout main, cut branch,
write, PR, merge, cleanup, checkout back, pop stash. **Do not do this.**

Two reasons. The stash stack is shared across the main checkout and every worktree,
other sessions can pop concurrently, and bare `stash`/`pop` can restore someone
else's work - an onboarding script touching a dirty tree is the worst place to hit
that. More fundamentally, the working tree never needs touching at all.

`skill-update.sh --mode standalone` already solves this, per its own header: "in a
throwaway git worktree so the user's dirty working tree is never touched."

```
SKETCHED                           WORKTREE
--------                           --------
check branch                       git worktree add <tmp> origin/main
stash -u                           write files in <tmp>
checkout main                      commit, push, PR, squash-merge
cut branch                         delete branch
write files                        git worktree remove <tmp>
commit, push, PR, merge
branch cleanup
checkout main
checkout feat branch
stash pop        <- 6 restore steps that can fail
```

The user stays on their feature branch with dirty files throughout. Nothing to
restore because nothing was disturbed.

Lives at `claude/tools/skill-onboard.sh`, invoked the way `skill-update.sh` already
is:

```bash
curl -fsSL https://raw.githubusercontent.com/jkkelley/dotfiles/main/claude/tools/skill-onboard.sh -o /tmp/skill-onboard.sh
bash /tmp/skill-onboard.sh --project .
```

Payload: `.claude/skills.toml`, the gitignore lines, the CLAUDE.md block, and
`git rm -r --cached .claude/skills/` for repos like `prospector-be` that committed
them. No hook - that is machine level now.

## Decided

|                                 |                                                                         |
| ------------------------------- | ----------------------------------------------------------------------- |
| Manifest format                 | TOML                                                                    |
| Lockfile                        | none. Receipt in `.claude/cache/`, debugging only                       |
| Sync tool                       | `claude/tools/skill-sync.sh`, lands in `.claude/cache/`                 |
| Sync tool versioning            | `tools` block in `registry.json`, schema 2                              |
| Self-update                     | `mv` to `.bak`, fork not `exec`, roll back on failure, one `.bak`       |
| Trigger                         | SessionStart hook in `~/.claude/settings.json`, installed by `setup.sh` |
| Project template hook           | also installed, as documentation; stamp makes it a no-op                |
| Re-sync guard                   | stamp file, 30 min                                                      |
| Write safety                    | build in temp dir, atomic swap, sweep stale `.sync.*` on every run      |
| Failure behaviour               | always exit 0, always print loudly, `status` in the receipt             |
| `type: reference`               | dropped, the manifest makes it unnecessary                              |
| CLAUDE.md content               | generated table of names, no versions                                   |
| Runbook rule                    | replaced by the lifetime question, both destinations mandatory          |
| `skill-update.sh`               | kept, narrowed to the standalone committed-skill case                   |
| Semver                          | GitHub Actions on the PR branch; commit type picks the level            |
| Rule 16                         | rewritten: CI bumps, `verify` gates                                     |
| Onboarding                      | worktree, never stash; no hook in its payload                           |
| The 29 unsymlinked skills       | out of scope, leave alone                                               |
| Skills committed in other repos | out of scope, they are like that for a reason                           |

## Open

1. Does any skill ever need a source other than the one public dotfiles URL? If no,
   the registry stays one flat list at one address.
2. Rule 17: does `skill-sync.sh` carry a `justfile`, and does it survive Git Bash?
   `curl` and `git` are present there; the landmines are `flock`, `cmp`, `diff`.
3. `requires` - hard auto-install, or warn only?
4. Does `skill-versioning` keep its name once it no longer owns the consume side?
5. Is `skill-sync` a script path in the hook, or a binary on PATH installed by
   `setup.sh` alongside the axi tools? The hook JSON differs.
6. Stamp window: 30 min is a guess. What is actually right?
7. Does CI also run the skill test suites, or only `verify`?

## Phases

Discovery is this file. Nothing proceeds without an explicit go-ahead.

| Phase         | Output                                                                                              |
| ------------- | --------------------------------------------------------------------------------------------------- |
| Discovery     | this file                                                                                           |
| Design doc    | open questions closed, TOML schema fixed, hook and CI specified                                     |
| Implement doc | `skill-sync.sh`, `skill-onboard.sh`, the workflow, registry schema 2, what `skill-versioning` sheds |
| Poker         | size the epics                                                                                      |
| Cut tickets   | work-order epics and children                                                                       |
| Do work       |                                                                                                     |
