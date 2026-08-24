# Skills package manager - design

Date: 2026-08-23, revised 2026-08-24
Status: settled. Every decision below is closed. The next artefact is the implementation document.
Discovery input: [`notes/skills-pm-discovery.md`](../../../notes/skills-pm-discovery.md)
Also binding: [`docs/skill-distribution-workflow.md`](../../skill-distribution-workflow.md)

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

If a managed skill directory is gitignored and replaced wholesale from upstream, then there is no drift to detect, no version to pin, no conflict to resolve, and no lockfile to maintain.
The only thing worth committing is the list of names.

**The unit of disposability is the skill directory, never `.claude/skills/` itself.**
See "Ownership is per-directory" below.
This is the single most important correction to the first draft, and the one most likely to be lost if it is only stated once.

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
- Touching the skills in this repo that are not symlinked into `~/.claude/skills`.

## Prerequisite

`.claude/skills/` is not gitignored today.
`gitignore.tmpl:30` ignores `**/.claude/agents/` and nothing ignores skills.

`.claude/skills/` becomes **blanket gitignored**.
Everything below assumes it.

## Ownership is per-directory, not per-parent

The sync **never** removes or rebuilds `.claude/skills/` itself.
It replaces only the directories it is responsible for, and it is responsible for exactly the names the manifest resolves to.

```
.claude/skills/
├── work-order/          <- in the manifest. sync owns it, replaces it wholesale
├── living-docs/         <- in the manifest. sync owns it, replaces it wholesale
└── some-local-thing/    <- not in the manifest. sync does not read, touch,
                            report, warn about, or clean up this directory
```

A `rm -rf .claude/skills/` followed by a rebuild would destroy hand-authored,
project-only skills that legitimately live beside the managed ones.
That directory is blanket gitignored, so anything the sync deleted would be gone
with no recovery and no diff to notice it by.

### Removing a skill from the manifest

Ownership has to be recorded, or "not in the manifest" cannot be told apart from
"hand-authored and none of your business".
The receipt carries that record, which is its second job:

| In the manifest | In the last receipt | Sync does                                   |
| --------------- | ------------------- | ------------------------------------------- |
| yes             | yes                 | replace it                                  |
| yes             | no                  | install it                                  |
| no              | yes                 | remove it - sync installed it, sync owns it |
| no              | no                  | **nothing.** Not sync's directory           |

The last row is the one that matters.
A missing or unreadable receipt collapses to "sync owns nothing", so the failure
mode of a lost receipt is an orphaned managed directory, never a deleted local one.

## Components

| Component          | Location                                                                   | Role                                            |
| ------------------ | -------------------------------------------------------------------------- | ----------------------------------------------- |
| Registry           | `claude/skills/registry.json`                                              | the index. Exists, gains a `tools` block        |
| Manifest           | `<project>/.claude/skills.toml`                                            | declared intent. Committed. New                 |
| Receipt            | `<project>/.claude/cache/skills-receipt.json`                              | what landed, and what sync owns. Gitignored     |
| Stamp              | `<project>/.claude/cache/.sync-stamp`                                      | churn guard. Gitignored                         |
| Sync tool          | `claude/tools/skill-sync.sh` upstream, `~/.local/bin/skill-sync` installed | does the work                                   |
| Notice partial     | `claude/tools/partials/read-only-notice.md.tmpl`                           | rendered into each `SKILL.md` at install. New   |
| Onboarder          | `claude/tools/skill-onboard.sh`                                            | brings an existing project onto the system      |
| PR gate            | `.github/workflows/skill-pr-gate.yml`                                      | validates, tests, writes nothing. New           |
| Publisher          | `.github/workflows/skill-publish.yml`                                      | bumps and regenerates **on merge to main**. New |
| Standalone updater | `claude/skills/skill-registry/scripts/skill-update.sh`                     | narrowed to hand-authored skills only           |

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
  +- stamp under 15 min old?       ->  exit 0, print nothing
  +- otherwise                     ->  sync
```

`setup.sh` installs it, the same way it already installs skills, alongside the existing `gh-axi` / `lavish-axi` / `chrome-devtools-axi` tools that use the same pattern.

This also simplifies self-update: one copy per machine in `~/.local/bin`, not one per project, and the `.bak` sits beside it.

## Two separate problems: the matcher and the stamp

The first draft used one mechanism, the stamp, for two unrelated problems, and it only solves one of them.

### Problem A - a sync fires while an agent is mid-task

`SessionStart` fires on four sources: `startup`, `resume`, `clear`, and `compact`.
Auto-compact happens **mid-task**, and a sync firing then replaces skill directories under an agent that is part-way through reading one.

```
09:00  SessionStart(startup)
       └─ sync runs                            fine, nothing in flight

09:40  auto-compact fires mid-task
       └─ SessionStart(compact)
          └─ sync runs
             └─ agent is three steps into work-order.sh,
                reading references/lifecycle.md
                └─ sync replaces .claude/skills/work-order/
                   └─ the file it had open is now a different file
```

**A stamp window does not fix this.**
At 09:40 a 30-minute stamp is 40 minutes old, so the sync runs anyway.
A four-hour window moves the collision to 13:30.
No window closes it, because the hazard is not frequency, it is _which source fired_.

The fix is the matcher.
The sync runs on `startup`, `resume` and `clear`, and **never on `compact`**.

> **Implementation note.** The existing hooks in `~/.claude/settings.json` all use
> `"matcher": ""`, which matches every source, so this repo has no working example
> of the filtered form. Confirm that `SessionStart` matchers accept the source
> string before building on it. If they do not, the fallback is for `skill-sync`
> to read the source from the hook payload on stdin and exit early itself.

### Problem B - redundant syncs

```
machine-level hook  ─┐
                     ├─ same session  ->  two syncs
project-level hook  ─┘

clear, then clear again, then resume  ->  three syncs in two minutes
```

Harmless but wasteful, and it is what makes installing the hook at _both_ levels free.
This is the stamp's only job.

Once the two are separated the stamp stops being safety-critical and becomes a cache TTL.
**15 minutes.**

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
    "skill-sync": { "version": "1.0.0", "sha256": "..." },
    "read-only-notice": { "version": "1.0.0", "sha256": "..." }
  }
}
```

### Where `type` and `requires` come from

Decided 2026-08-24. This was the last thing left open in the implementation plan, and one half of it turned out not to be a question.

**`type` is never declared.**
It is routing only - `skill` to `.claude/skills/`, `agent` to `.claude/agents/` - and the thing already sits in one of those two trees upstream:

```
claude/skills/<name>/SKILL.md     ->  type: skill
claude/agents/<name>.md           ->  type: agent
```

`render_registry` walks those directories to find the entries at all, so it already knows.
Declaring the type would write down a fact the filesystem states, and create a second source of truth that can disagree with the first.

**`requires` is an optional frontmatter key**, on the skill that has the dependency:

```yaml
---
name: living-docs
description: ...
version: 1.0.1
requires: work-order
---
```

Absent means no dependencies, which is 41 of the 43 files.
Comma-separated for more than one.
**Not a YAML list** - Rule 17 makes Git Bash a supported platform, and a bracket list needs a real parser where `requires: a, b` needs one line of `awk`, the same shape as the `read_version` that already exists.

A variable frontmatter key set is not a new thing here.
The agents in `claude/agents/` already carry `tools:` and `model:` beside `name:` and `description:`, and `skill-version.sh` reads only `version:` - when one is missing it appends it as the last frontmatter key, so the script already treats the key set as open-ended.
The "exactly `name`, `description`, `version`" line under "The read-only notice becomes a partial" is an observation that the partial does not touch frontmatter, not a constraint on what frontmatter may hold.

The two alternatives were rejected on where the fact lives rather than on cost.
A lookup table inside `skill-version.sh` is fewer characters and puts `cartography`'s dependency inside another skill's script, where the one person who needs it - someone adding a skill that shells out to another skill - is editing a file that never mentions it.
A `skill.toml` beside each `SKILL.md` introduces a second per-skill format and a second thing that goes stale against the first.

**`verify` gains one assertion: every name in a `requires:` resolves to a skill that exists.**
That is what earns the key its keep, and it is free because `verify` already walks every skill.
A typo'd dependency then fails the PR gate instead of failing some project's first sync, days later and somewhere else.

### The two edges

`requires` is a hard dependency and is auto-installed.
Two edges exist, both on `work-order`, both currently prose only:

- `cartography/SKILL.md:42` states it takes `work-order` as a sibling skill directory and that **there is no degraded mode**. `cartograph.sh` shells out to `work-order.sh` and never writes ticket markdown itself.
- `living-docs/SKILL.md:20,173` binds its documentation gate to `work-order`'s acceptance criteria.

Advisory would be the wrong choice here: both are hard failures on first run, and there are only two of them, so auto-install costs nothing and prevents the only half-installs that exist.

`cartography`'s reference to `figma-wireframe` is disambiguation, not a dependency, and is deliberately not encoded.

The `read-only-notice` entry in `tools` is what lets a change to the notice reach installed projects.
See "The read-only notice becomes a partial".

### Receipt

```json
{
  "synced": "2026-08-23T18:04:11Z",
  "source": "jkkelley/dotfiles@a1b7bb1",
  "status": "ok",
  "owned": ["work-order", "living-docs", "container-sandbox"],
  "skills": {
    "work-order": { "version": "1.0.1", "sha256": "9f2c..." }
  }
}
```

Never read for resolution.
Read by a human when something behaves oddly, by anything asserting the last sync succeeded, and by the sync itself to answer **which directories it owns**.

## The read-only notice becomes a partial

43 of the 43 skills carry the same six-line block under their title, differing only by their own name in one URL (`work-order/SKILL.md:9-14`).

Under the current rule, editing that text is a change to 43 files and therefore 43 version bumps.
That happened once already: PR `#42` rewrote the notice everywhere and forced a bump on every skill, invalidating every in-flight branch at once.

### The change

The notice leaves all 43 `SKILL.md` files.
Upstream carries only the skill:

```markdown
---
name: work-order
description: ...
version: 1.0.3
---

# Work Order

Tickets an agent can act on without asking a follow-up question.
```

Frontmatter is untouched: `name`, `description`, `version`, in that order, confirmed across all 43.

One template at `claude/tools/partials/read-only-notice.md.tmpl` holds the text, with the skill name substituted.
`skill-sync.sh` renders it and inserts it after the first `# ` heading at install time, into the gitignored copy.
Upstream is never modified.

### What it buys

**42 bumps become 1.**
The template is versioned in the `tools` block, so changing the notice bumps one entry and forces a re-render.
The work still happens on every project; the version churn does not, and skill semver stops claiming that 43 skills changed behaviour when none did.

**It deletes a failure class rather than detecting it.**
`skill-version.sh:195` exists solely because the notice is hand-maintained in 43 places and a copy-paste can keep the neighbour's name:

```bash
elif ! grep -qF "$SKILL_SRC_URL/$name" "$d/SKILL.md" 2>/dev/null; then
  printf 'notice has no upstream URL, or names another skill   %s\n' "$name" >&2
```

Rendering from a template makes a wrong name unrepresentable, so the check is **deleted**, not improved.

**`verify` inverts on the notice.**
It stops asserting the notice is present and starts asserting it is **absent** upstream, so a paste-back cannot produce a doubled notice on install.

### The tool it names

The notice names its own installer three times.
It **hardcodes `skill-sync.sh`**.

No placeholder is needed, because after this work `skill-update.sh` no longer installs synced skills at all - it is for hand-authored skills only, and a synced copy naming it would simply be wrong.

### Accepted consequence

A skill that arrives by `cp`, `git clone`, or copy-paste lands with **no notice**, because nothing rendered it.
Accepted.

## Flows

### Session sync

```
session starts
  |
  v
SessionStart hook, ~/.claude/settings.json
  matcher: startup | resume | clear        (never compact)
  timeout: 30
  |
  +- skill-sync --boot
       |
       +- no .claude/skills.toml         -> exit 0, silent
       +- stamp under 15 min             -> exit 0, silent
       |
       +- sweep stale .sync.* temp dirs (older than 1h)
       +- fetch registry.json
       +- resolve manifest + requires        -> the owned set
       +- read receipt                       -> the previously owned set
       +- build owned dirs into .claude/cache/.sync.XXXXXX
       +- render the read-only notice into each SKILL.md
       +- swap each owned directory individually
       +- remove directories dropped from the manifest (receipt says sync owns them)
       +- leave every other directory untouched
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

## Publish: version allocation happens at merge, not on the PR branch

The first draft put the bump on the PR branch.
That is superseded by `docs/skill-distribution-workflow.md`, which is the binding document on this point.

**A version is a claim about ordering, and ordering is not knowable until merge.**

`registry.json` is one file listing every skill, so _every_ bump touches it.
Allocating versions on PR branches makes it a guaranteed conflict point between any two concurrent skill PRs, related or not.
PRs `#41` and `#42` both allocated `project-scaffold` 1.2.0 from their own stale snapshots.
Git blocked them only because they happened to edit the same lines.
Moving allocation to merge removes `registry.json` from pull requests entirely, so that whole conflict class stops existing.

### Repo settings, first

Checked on 2026-08-24, and one of them would have killed this silently:

```
squash_msg:   COMMIT_MESSAGES      <- the trap
squash_title: COMMIT_OR_PR_TITLE
allow_merge:  true                 <- escape hatch
allow_rebase: true                 <- escape hatch
```

`COMMIT_MESSAGES` builds the squash commit body from the branch's **commit messages**, not the PR description.
A `Bump:` trailer written in the PR description would never reach the commit, the publisher would find no trailer, and the cause would be invisible.

```bash
gh api -X PATCH repos/jkkelley/dotfiles \
  -f squash_merge_commit_title=PR_TITLE \
  -f squash_merge_commit_message=PR_BODY \
  -F allow_merge_commit=false \
  -F allow_rebase_merge=false
```

`PR_BODY` makes the PR description become the commit body verbatim.
That gives **one authored text**: the PR gate validates it, the merge copies it, the publisher parses it.
Divergence is structurally impossible.

Disabling merge commits and rebase merges matters because both produce a commit shape the publisher does not expect.
Squash becomes the only path in, which is already the practice - the last 14 commits on `main` are all single-parent.

### The `Bump:` trailer

One trailer per skill, repeated.
Not comma-separated: five skills on one line is unreadable, and one typo takes them all out.

```
feat(skills): move the read-only notice into a rendered partial

Whatever the PR body says.

Bump: work-order=major
Bump: living-docs=minor
Bump: cartography=patch
```

Parsed with `git interpret-trailers --parse`, which already owns this format.
Levels are `major`, `minor`, `patch`, and nothing else.

**Anything changed but not listed falls back to the title's conventional type** - `feat` minor, `fix` patch, `feat!` or `BREAKING CHANGE` major.
A single-skill PR therefore needs no trailer at all, which is most of them.

Commit _scope_ is deliberately ignored when deciding which skills changed.
`feat(skills):` is generic and `fix(work-order,project-scaffold):` is multi, so the file list is authoritative and the commit type contributes only the fallback level.

### The PR gate - `.github/workflows/skill-pr-gate.yml`

Runs on every PR. Writes nothing.

| Check                                | Fails when                                          |
| ------------------------------------ | --------------------------------------------------- |
| every named skill exists             | `Bump: work-oder=major` - a typo                    |
| every named skill actually changed   | the trailer names a skill this PR never touched     |
| every level is one of three words    | `Bump: x=mayor`                                     |
| no skill named twice                 | two trailers disagree                               |
| a changed skill resolves to a level  | trailer or a parseable title type, one or the other |
| no hand-edited `version:` / registry | those are CI's files now                            |
| `verify --structure` passes          | unversioned skill, or a notice left in a `SKILL.md` |
| changed skills' test suites pass     | see the test matrix below                           |

It prints the resolution table so the outcome is visible before merge:

```
work-order      1.0.3 -> 2.0.0   major   (trailer)
living-docs     1.0.0 -> 1.1.0   minor   (trailer)
cartography     1.2.1 -> 1.2.2   patch   (title: fix)
```

### `verify` splits

`cmd_verify` at `skill-version.sh:174` performs three checks today, and the third

- `render_registry` compared against `registry.json` - **cannot pass on a PR branch** once allocation moves to merge.
  A PR that edits a skill changes its content hash while deliberately leaving the registry alone.
  That is the correct state, and today's `verify` calls it `drifted`.

| Command              | Checks                                             | Runs                |
| -------------------- | -------------------------------------------------- | ------------------- |
| `verify --structure` | version present; notice **absent** from `SKILL.md` | PR gate             |
| `verify`             | the above, plus registry in sync with disk         | after publish, main |

### The test matrix

7 of the 43 skills ship `testing/run-tests.sh`: `cartography`, `context-compaction`, `hydration-prompt`, `living-docs`, `project-scaffold`, `skill-registry`, `work-order`.

Only the touched ones run.
The shape matters more than today's numbers, because the set only grows.

```
detect job
  ├─ changed = git diff --name-only origin/main...HEAD -- claude/skills/
  ├─ keep only those with testing/run-tests.sh
  └─ emit as JSON  ->  ["work-order","living-docs"]

test job (matrix, one runner per skill, in parallel)
  └─ podman ... bash testing/run-tests.sh
```

Four things that keep it from breaking:

**An empty matrix is a hard error in Actions.**
A docs-only PR produces `[]` and the workflow fails for no reason.
The test job needs `if: needs.detect.outputs.skills != '[]'`.

**It runs on the PR, not at merge.**
The publisher already knows the tests passed; re-running them after merge only delays the registry and adds a second place for it to go red.

**Podman is not on the runner.**
`ubuntu-latest` ships Docker, and Rule 14 requires Podman, so the job installs it.

**Runner labels cannot be digest-pinned.**
Rule 15 wants an immutable identifier and GitHub does not offer one for runner images.
`ubuntu-24.04` instead of `ubuntu-latest` is as far as the rule can be honoured there.
The images _inside_ each skill's tests are pinned already, and that is the part that governs what the tests actually run against.

### The publisher - `.github/workflows/skill-publish.yml`

```yaml
on:
  push:
    branches: [main]

concurrency:
  group: skill-publish
  cancel-in-progress: false # queue; cancelling would drop a bump
```

```
push to main
  ├─ checkout  ref: main          <- NOT github.sha
  ├─ verify passes?  -> nothing to do, exit 0
  ├─ which skills:   git diff --name-only <before>..<after> -- claude/skills/
  ├─ which levels:   git log -1 --format=%B | git interpret-trailers --parse
  ├─ absent from registry?  skill-version.sh init   (1.0.0, no trailer needed)
  ├─ else                   skill-version.sh bump <name> --<level>
  └─ commit + push
```

**`ref: main`, not the default.**
`actions/checkout` defaults to `github.sha`, the commit that triggered the run.
If a second PR merges while the first run is still going, that run is sitting on a tree that is no longer `main` and its push is rejected non-fast-forward - serialised or not.

Pinning the checkout to `main` makes batching fall out for free:

```
a'  PR A merges          run 1 queued
a'' PR B merges          run 2 queued behind it
    run 1 starts, checks out main (= a'', carries both changes)
    bumps BOTH skills, pushes a'''
    run 2 starts, checks out main (= a'''), verify passes, exits 0
```

Serialised checkout of `main` also means each run reads the previous run's output, so the same skill bumped twice goes 1.0.2 -> 1.0.3 -> 1.0.4 rather than colliding.

**The loop guard is free**, because `verify` is a pure check.
`GITHUB_TOKEN` pushes do not retrigger workflows.
If the token is ever swapped for a PAT or App token to satisfy branch protection, the run does retrigger - and still terminates, because `verify` passes the second time and it exits 0. The cost is one wasted run per publish.

**New skills need no trailer.**
Absence from the registry is unambiguous, and `init` stamps 1.0.0.

### Failure is closed, not guessed

If the publisher cannot resolve a level, **the run fails and nothing is bumped.**

The asymmetry is the whole reason.
A missing bump leaves `registry.json` with the old version and old hash, so projects keep the skill they already have - stale, safe, and `verify` stays red until it is fixed.
A guessed bump ships a breaking change to every project as a patch.
One is visible and harmless; the other is invisible and not.

### Writing to `main`

`main` has no branch protection and no rulesets, checked 2026-08-24, so the publisher pushes with `GITHUB_TOKEN` and needs no bypass.

Two alternatives were considered and rejected:

**Registry on a separate branch** is fatally broken, not merely costly.
`cmd_bump` at `skill-version.sh:169` writes the version into the skill's frontmatter _before_ it renders the registry:

```bash
write_version "$dir/SKILL.md" "$new"      # on main
render_registry > "$REGISTRY"              # also on main
```

Moving `registry.json` elsewhere does not stop the bot writing to `main`, because the `version:` line still lands there.
It also breaks `verify`, which compares `render_registry()` against the file on disk - put the file on another branch and both local verification and the PR gate need a fetch first.

**A publish PR with auto-merge** (the release-please pattern) keeps the rule intact literally, but costs two merges per skill change and adds a way for the registry to go quietly stale when auto-merge is off or a check hangs.
It buys a review step over an output that is a pure function of an already-reviewed input.

### The named exception

The publisher is the one actor permitted to write `main` directly, and Rule 16's rewrite says so explicitly rather than leaving it implied:

> `main` is written once and never again directly, with one exception: the publish
> workflow commits the version bump and the regenerated registry after a merge.
> It is the only actor permitted to, it runs no logic beyond `skill-version.sh`,
> and `verify` is the assertion that it did the right thing.

Naming the exception in the same section that defines the pipeline is what stops it becoming precedent for the next thing that wants to skip review.

### Onboarding an existing project

The user's working tree is never touched.
No stash, no branch switch.

```
skill-onboard.sh --project <path>
  |
  +- WT=$(treehouse get --lease --lease-holder "skill-onboard")
  +- write .claude/skills.toml
  +- add .claude/skills/ to .gitignore
  +- git rm -r --cached .claude/skills/   (only where they were committed)
  +- replace the CLAUDE.md session-start block
  +- commit, push, open PR, squash-merge, delete branch
  +- treehouse return "$WT" --if-lease-holder "skill-onboard"
```

**treehouse, not a hand-rolled `git worktree add`.**
The first draft used the raw command, which is the pattern `docs/worktree-workflow.md` exists to replace.
A hand-rolled worktree pins the branch it has checked out, which produces `cannot remove a locked working tree` after a successful merge - hit twice on 2026-08-23 alone.
treehouse's detached-HEAD-when-idle invariant is the fix.

No hook is installed by this script.
The hook is machine level and `setup.sh` owns it.

The stash-based alternative was rejected.
The stash stack is shared across the main checkout and every worktree, other sessions can pop it concurrently, and bare `stash`/`pop` can restore someone else's work.
An onboarding script operating on a dirty tree is the worst possible place to accept that risk, and the worktree pattern removes the need entirely.

> **Unverified, and it gates treehouse adoption.**
> What `treehouse return` does with unpushed commits on a branch has not been tested.
> Idle slots are observed detached across all 15, but nothing has been run against a slot carrying unpushed work.
> Test this before the implementation depends on it.

## Failure modes

| Mode                              | Handling                                                                                                       |
| --------------------------------- | -------------------------------------------------------------------------------------------------------------- |
| Registry unreachable              | exit 0, print a loud two-line warning, leave the tree untouched                                                |
| Timeout mid-sync                  | each owned directory is built in a temp dir and swapped individually, so the previous state survives intact    |
| Hard kill skips the `trap`        | temp dirs are created inside `.claude/cache/` with a `.sync.` prefix; every run sweeps ones older than an hour |
| New version of the tool is broken | `.bak` is restored and the failure is reported                                                                 |
| Self-update loop                  | `SKILL_SYNC_CHILD=1` makes the recursion one deep by construction                                              |
| Sync fires during auto-compact    | **the matcher excludes `compact`.** The stamp does not and cannot fix this                                     |
| Redundant syncs, double install   | stamp file, 15 minutes                                                                                         |
| Receipt missing or unreadable     | sync owns nothing; orphan a managed directory rather than delete a local one                                   |
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
Never edit a managed skill in place - it is gitignored and the next sync
replaces it silently. Fix it in dotfiles, bump it, done.
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

### `.claude/scaffold.json`

`project-scaffold` writes `.claude/scaffold.json` recording which skill version the vendored copies came from.

That record is redundant under this design and is **removed**.
It answers "what version is installed", which the receipt now answers with better provenance, and it is the kind of second source of truth that goes stale without anything noticing.
Anything still reading it moves to the receipt.

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

> CI allocates versions **on merge to `main`**, never on a PR branch.
> A pull request carries intent, not a number: one `Bump: <skill>=<level>` trailer
> per skill in the PR description, falling back to the commit type for anything
> unlisted - `feat` minor, `fix` patch, `feat!` or `BREAKING CHANGE` major.
> `verify --structure` gates the PR; `verify` asserts the publish afterwards.
> Never hand-edit `version:` or `registry.json` - the PR gate rejects it.

The obligation does not disappear, it stops depending on memory.

### The boilerplate carve-out

Rule 16 needed a carve-out for changes that touch only shared boilerplate across many skills.
**The partial is that carve-out.**
Once the read-only notice lives in one template instead of 43 files, a notice change is one `tools` bump, and the case the carve-out existed for stops arising.
No rule text is needed for it.

## Renaming `skill-versioning` to `skill-registry`

The name is wrong in a specific way.
After this work the skill owns exactly three publish-side things: stamp a version, render `registry.json`, and `verify`.
Consumers never touch it - they use `skill-sync`.
And "versioning" is precisely the part CI takes over, so the name points at the thing it stopped doing.

`skill-registry` names the artefact it produces, validates, and publishes, and it sits cleanly beside `skill-sync` - one publishes the registry, one consumes it.

### The rename happens last, not first

18 references across 9 files, and four of the affected repos carry the **identical two lines**:

```
~/dotfiles/claude/skills/skill-versioning/scripts/skill-update.sh \
```

Those lines are the prose session-start check that this design deletes.
Every one of those repos is visited by the rollout epic anyway, and that visit removes the block outright rather than editing a path inside it.

So the rename is the **closing commit of the rollout epic**, once the references it would break are already gone.
No compat artefact, no broken window, and no edit that gets thrown away.

A compat symlink was rejected.
A tombstone directory and a fix-the-four-repos-now pass were both considered and are unnecessary given the sequencing.

## What survives, what changes, what goes

| Thing                                 | Fate                                                                         |
| ------------------------------------- | ---------------------------------------------------------------------------- |
| `registry.json`                       | survives, schema 2, gains `tools` and per-skill `type` / `requires`          |
| `skill-version.sh`                    | survives. `render_registry` learns schema 2; `verify` splits                 |
| `skill-versioning`                    | renamed `skill-registry`, as the closing commit of the rollout epic          |
| `skill-update.sh`                     | survives, narrowed to **hand-authored skills only**. Header states the split |
| `skill-version.sh:195` URL check      | deleted. Rendering makes a wrong skill name unrepresentable                  |
| The read-only notice in 43 SKILL.md   | deleted upstream, rendered at install from one template                      |
| Rule 16                               | rewritten, enforced by CI, allocation at merge                               |
| Session-start prose check             | deleted, replaced by the hook                                                |
| `.claude/scaffold.json`               | removed. The receipt supersedes it                                           |
| `--mode inline` / `--mode standalone` | survive for hand-authored skills only                                        |
| `setup.sh`                            | gains: install the binary, install the machine hook                          |
| Lockfile                              | never introduced                                                             |

## Rollout

**Pilot: `hydration-prompt`, one skill, end to end.**

Trailer, PR gate, test matrix, merge-time bump, registry, sync into a project.
Nothing else moves until that path is proven.

It is a good pilot for two reasons: it is one of the 7 skills that ships a test suite, so the matrix is genuinely exercised, and it is used every session, so a break is immediately visible rather than discovered weeks later.

**Then a second epic carries the remaining 42 through the same procedure**, closing with the `skill-registry` rename.

| Population                                 | Action                                                                         |
| ------------------------------------------ | ------------------------------------------------------------------------------ |
| Any project on this machine                | none. The machine-level hook covers it, and the tool no-ops without a manifest |
| Project that wants in                      | run `skill-onboard.sh`                                                         |
| Project with skills committed to the index | `skill-onboard.sh` includes `git rm -r --cached`                               |
| A new machine                              | run `setup.sh`                                                                 |

There is no migration for the hook itself, which is the main reason it is machine level.

## Decisions, closed

The five items that were awaiting sign-off are settled.

| #   | Decision                                                                                                         |
| --- | ---------------------------------------------------------------------------------------------------------------- |
| 1   | **Single source.** The registry stays one flat list at one public dotfiles URL                                   |
| 2   | **Stamp window: 15 minutes**, and it is a cache TTL rather than a safety control. The matcher owns safety        |
| 3   | **`skill-versioning` is renamed `skill-registry`**, sequenced as the closing commit of the rollout epic          |
| 4   | **CI runs `verify --structure` plus the test suites of changed skills only**, as a matrix, on the PR             |
| 5   | **Rule 17.** `skill-sync.sh` treats Windows as supported: no `flock`, no `cmp`, no `diff`. `curl` and `git` only |

Decided during the 2026-08-24 revision:

| #   | Decision                                                                                     |
| --- | -------------------------------------------------------------------------------------------- |
| 6   | Version allocation moves to **merge time**. `docs/skill-distribution-workflow.md` is binding |
| 7   | `Bump: <skill>=<level>` trailers, one per line, title type as fallback                       |
| 8   | Repo settings: `squash_merge_commit_message=PR_BODY`, squash-only                            |
| 9   | Publisher: `concurrency` group, `cancel-in-progress: false`, `ref: main`, verify-first       |
| 10  | Publisher fails closed on an unresolvable level                                              |
| 11  | Registry stays on `main`; the bot push is a named exception to the never-write-main rule     |
| 12  | The read-only notice becomes a rendered partial                                              |
| 13  | Sync owns directories, not the parent. The receipt records ownership                         |
| 14  | `.claude/skills/` stays blanket gitignored                                                   |
| 15  | The matcher excludes `compact`; the stamp handles churn only                                 |
| 16  | `skill-update.sh` narrows to hand-authored skills                                            |
| 17  | The pipeline flow is documented in this repo's root `CLAUDE.md`                              |
| 18  | Pilot on `hydration-prompt`, then a second epic for the remaining 42                         |

Decided during implementation planning, and recorded here because they change what gets built:

| #   | Decision                                                                                                             |
| --- | -------------------------------------------------------------------------------------------------------------------- |
| 19  | The treehouse pool stays user-level at `~/.treehouse/<repo>-<hash>/`. In-project `--root .` rejected                 |
| 20  | `project-scaffold`'s default manifest is `work-order`, `living-docs`, `container-sandbox`, `context-compaction`      |
| 21  | `type` is derived from the tree, never declared. `requires` is an optional frontmatter key, and `verify` resolves it |

19 and 20 are argued in [the implementation plan](../plans/2026-08-24-skills-package-manager-implementation.md).
21 is argued above, under "Where `type` and `requires` come from".

## Open, not designed here

- **A system for project-only skills.** Hand-authored skills that live in a project and still want version control. Deliberately not designed in this document, and it does not block anything here - the ownership rule above is what keeps them safe in the meantime.
- **`justfile` coverage per Rule 17.** Two skills carry one today. Out of scope; the PR gate is the natural place to enforce it later if it is ever wanted.
- Whether `project-scaffold` writes a default manifest, and what is in it.
- Whether the generated CLAUDE.md table is written by the sync or by `scaffold.sh`.
- Test strategy for `skill-sync.sh` itself, per `container-sandbox/references/skill-testing.md`.
