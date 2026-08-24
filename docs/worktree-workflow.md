# Worktrees: treehouse as the workspace broker

Worked out 2026-08-23. Companion to [skill-distribution-workflow.md](skill-distribution-workflow.md), which covers the same discipline applied to skills.

Status: **the model is settled, the integration is not built.** See "After the compaction" at the bottom for what is actually left to do.

## The problem it removes

A branch and a worktree are different things that normally get welded together.

- A **branch** is a pointer to a commit. A name for a line of history, living in `.git/refs/heads/`. It costs nothing.
- A **worktree** is a checked-out directory on disk. Files, `node_modules`, build cache. It costs a lot.

One repository normally means one working directory, and `git checkout` drags that single directory between branches. That is why switching branches is disruptive: it rewrites the files and throws the warm cache away.

`git worktree` breaks the one-to-one. One `.git` - one object store, one set of refs - with N directories, each on a different branch at the same time.

They are orthogonal, with **exactly one coupling constraint**: a branch can be checked out in at most one worktree at a time.

That constraint is not theoretical. It fired on this repository on 2026-08-23:

```text
cannot delete branch 'feat/scaffold-runbooks-source-of-truth'
used by worktree at '/home/luna/dotfiles/.worktrees/scaffold-runbooks'
```

`gh pr merge --delete-branch` failed on it, _after_ the merge had already succeeded. The tool reported an error on a merge that had worked, and left the branch alive both locally and on the remote. A hand-rolled worktree was holding the branch hostage.

## What treehouse actually is

A **pool of long-lived, reusable worktrees** that get borrowed and returned, rather than created and destroyed.

It is a **standalone Go binary**, not an npm package and not a Claude Code plugin. Installed at `~/.local/bin/treehouse`, currently **v2.3.0**. It ships its own updater: `treehouse update`.

It is a **broker in front of `git worktree`**. It does not replace git and does not manage branches. What it changes is the lifecycle:

|                      | Directory lifetime                       | Setup cost         |
| -------------------- | ---------------------------------------- | ------------------ |
| Plain `git worktree` | equals the task - create, work, destroy  | paid every task    |
| treehouse            | outlives the task - borrow, work, return | paid once per slot |

## The invariant that makes it safe

**An idle slot sits on a detached HEAD.**

Observed across all 15 slots in the nine populated pools on this machine, every one clean. That is deliberate, and it is the whole design:

```text
idle slot  ==  detached HEAD  ==  holds no branch
                                   │
                                   └─> "cannot delete branch used by worktree"
                                       cannot happen
```

Treehouse hands out a bare workbench, not a workbench with somebody's half-finished job still clamped to it.

**Treehouse owns the directory. Git owns the branch. You create the branch yourself, once you are inside the slot.**

## Who owns what

```text
the work
│
├─ DIRECTORY ──── treehouse ── long-lived, rented, survives many tickets
│                              detached when idle, so it pins no branch
│
├─ BRANCH ─────── git ─────── one per ticket, created in step 2, dies at merge
│                              cheap, unlimited, what the PR runs on
│
└─ TICKET ─────── work-order ─ one per session, names the lease holder
```

## The pool on disk

```text
~/.treehouse/
└── <repo>-<hash>/
    ├── treehouse-state.json      the lease table: name, path, leased, lease_holder, leased_at
    ├── treehouse-state.lock      the mutex
    ├── 1/<repo>/  ─┐
    ├── 2/<repo>/   ├─ ordinary git worktrees
    └── 3/<repo>/  ─┘  .git is one line: gitdir: ~/projects/<repo>/.git/worktrees/…
                       so the real repo, its refs and its objects stay where they were
```

Slots are numbered `1`, `2`, `3`. A pool grows a slot when more agents want one concurrently than exist.

A real lease, from the firstmate pool, held since June:

```json
{
  "name": "1",
  "path": "…/1/firstmate",
  "leased": true,
  "lease_holder": "yieldpoint",
  "leased_at": "2026-06-23T22:21:16Z"
}
```

## The lifecycle

```text
session start
│
├─ 0. SKILLS ─────────────── copies are immutable, upstream is dotfiles
│     ├─ fetch registry.json from GitHub
│     ├─ compare against installed version: lines
│     └─ swap stale ones out, or say nothing and start
│
├─ 1. ACQUIRE ────────────── treehouse owns this
│     ├─ treehouse get --lease --lease-holder "WO-20260821-35a4"
│     ├─ fetches origin first          (--no-fetch to skip)
│     ├─ hands back a slot on DETACHED HEAD, clean, cache warm
│     ├─ records the lease  ->  prune and any later get cannot touch it
│     └─ prints ONLY the path to stdout   (banners go to stderr)
│
├─ 2. BRANCH ─────────────── git owns this, and you do it, not treehouse
│     └─ git switch -c feat/<short-kebab>
│
├─ 3. WORK ───────────────── the ticket, all of it, on that branch
│     ├─ the code
│     ├─ CONTEXT_STATE.md      new checkpoint at the TOP
│     ├─ the ticket reaches done   evidence -> retro -> done
│     └─ HYDRATION.md          the successor's prompt
│
├─ 4. ONE PULL REQUEST ───── code + ticket + state + prompt, one review
│
└─ AFTER THE MERGE
   │
   ├─ 5. archive ─────────── work-order.sh close, straight to main
   │
   ├─ 6. RELEASE ─────────── treehouse owns this again
   │     ├─ treehouse return "$WT" --if-lease-holder "WO-20260821-35a4"
   │     ├─ reaps lingering processes first
   │     ├─ resets the slot back to detached HEAD
   │     └─ slot re-enters the pool, deps and build cache intact
   │
   └─ 7. hand back ───────── the prompt AND its launch command, then hold
```

## The commands that matter

```sh
WT=$(treehouse get --lease --lease-holder "WO-20260821-35a4")
cd "$WT"
git switch -c feat/<short-kebab>
# ... work, commit, push, open the PR ...
treehouse return "$WT" --if-lease-holder "WO-20260821-35a4"
```

| Command                   | Notes                                                                                                                                |
| ------------------------- | ------------------------------------------------------------------------------------------------------------------------------------ |
| `treehouse get`           | Interactive. Subshell in a free slot; exiting releases it                                                                            |
| `treehouse get --lease`   | Durable. Prints only the path to stdout, banners to stderr, so `$(…)` works                                                          |
| `--lease-holder <label>`  | Recorded in the lease table. **Use the ticket ID**                                                                                   |
| `--json`                  | Lease identity and metadata, requires `--lease`                                                                                      |
| `--no-fetch`              | Skip the origin fetch that `get` does by default                                                                                     |
| `treehouse status`        | The live map of which agent holds which slot                                                                                         |
| `treehouse enter <name>`  | **New in 2.3.0.** Attach to a slot another agent is in, without acquiring, resetting or returning it. `--print-path` for `cd "$(…)"` |
| `treehouse return <path>` | `--if-lease-holder` / `--if-lease-id` return only if you still hold it                                                               |
| `treehouse prune`         | Dry run by default. `--all` sweeps every pool, `--yes` actually deletes                                                              |
| `treehouse init`          | Writes a default `treehouse.toml`                                                                                                    |
| `--root .`                | **v2.2.0.** Relative paths resolve from the repo root, so this gives an in-project pool                                              |

`--if-lease-holder` is the guard against an agent that crashed, restarted, and would otherwise hand back a slot somebody else now owns. It is what "stable lease identities" in v2.1.0 bought.

### prune will only delete when all four hold

1. treehouse manages it
2. no owner reservation and **no running process** inside it
3. no uncommitted changes
4. its HEAD is **already merged into the default branch**

Dry run by default, `--yes` to act. `destroy` is the same shape.

## v1.8.0 -> v2.3.0, what changed

Updated 2026-08-23. The nine populated pools survived the major bump cleanly: state format unchanged, the two-month-old firstmate lease intact.

| Version    | Change                                                                                                                                                                                |
| ---------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **v2.0.0** | **BREAKING. `destroy --force` removed**, replaced by `--include-unlanded`, `--include-in-use`, `--include-leased`, each opted into separately, plus `--yes` and an explicit pool path |
| v2.0.1     | State persistence made atomic and recoverable                                                                                                                                         |
| v2.1.0     | Stable lease identities                                                                                                                                                               |
| v2.2.0     | `--root` flag and `TREEHOUSE_ROOT`; no-fetch acquire; squash-merge detection; correct root resolution from inside a worktree                                                          |
| v2.2.1     | Refuse to reset a worktree that still has live writers                                                                                                                                |
| **v2.3.0** | `enter` command; opt-in Jujutsu backend; slot flavors; **reaps processes before git operations**                                                                                      |

Two of those are direct answers to problems hit on 2026-08-23. **v2.2.1** is the locked-worktree-with-a-live-PID situation, now handled mechanically rather than by running `ps` and thinking about it. **v2.0.1** matters because a torn `treehouse-state.json` would strand every slot in a pool.

## How this gets implemented

Two integration points, and the split mirrors the tool itself.

### 1. `hydration-prompt` - the mechanism

It already prints the command that starts the next session. Acquiring a slot and labelling the lease with the ticket ID is a natural extension of exactly that, and releasing it belongs in the close-out it already owns.

`treehouse status` then becomes a live map of which agent holds which workbench, keyed by ticket ID.

### 2. `project-scaffold` CLAUDE.md template - the policy

A short section: isolated workspaces come from treehouse, one branch per ticket, return the slot at close-out.

**Pointer, not manual.** Same discipline as the `local-k8s-docs` rule merged in dotfiles #41: name the source of truth, do not copy it.

### Explicitly NOT a skill

Wrapping treehouse in a skill would recreate the exact problem [skill-distribution-workflow.md](skill-distribution-workflow.md) exists to solve: a vendored copy that goes stale independently of the thing it describes.

Treehouse went v1.8.0 -> v2.3.0 in a single morning. A skill documenting the v1 `destroy --force` flag would now be actively wrong and nothing would catch it. The tool has `--help` and a self-updater; that is better documentation than a frozen copy.

## Decided, 2026-08-24: the pool stays user-level

**`~/.treehouse/<repo>-<hash>/`. In-project `--root .` is rejected.**

The measurement that settled it: a slot's `.git` is a 108-byte pointer file, so git objects are never duplicated. The weight is build cache written _inside_ the slot - one measured slot carries 171M of `.cache` for a repository whose tracked content is under a megabyte.

`--root .` puts that cache inside the working tree, which is the thing this repo mounts into containers. Every `podman run -v "$PWD:/work"` under Rule 14 would bind and relabel the pool on every run, `podman build .` would take it as build context, and `git add -A` would stage another branch's cache unless a gitignore line that does not exist today were added to `gitignore.tmpl` and to every existing repo.

The cost of the decision is accepted rather than dismissed: `dotfiles-ff4128` is a hash directory, `ff4128` cannot be reconstructed by hand, and the pool name does not say where its repository lives. That is paid with one paragraph in the `project-scaffold` CLAUDE.md template and with `treehouse status`.

This repository still has hand-rolled worktrees at `.claude/worktrees/` and `.worktrees/`, which is what produced the branch-deletion failure above. Treehouse owning those instead is a separate cleanup, not part of this decision.

## Verified, 2026-08-24

**What `treehouse return` does with unpushed commits left on a branch.**

Probed in Podman per Rule 14, using the pattern in `container-sandbox`'s "Verifying a host CLI's behaviour" section: real `treehouse` v2.3.0 bind-mounted read-only, throwaway origin, `TREEHOUSE_ROOT` redirected inside the container, so the live pool was never touched.

| Case                                | Observed                                                                                                            |
| ----------------------------------- | ------------------------------------------------------------------------------------------------------------------- |
| unpushed commit, plain `return`     | **survives.** rc 0, slot resets to detached HEAD, the branch ref remains in the repository, the object is reachable |
| unpushed commit, `return --force`   | **survives.** `--force` cleans the worktree, not the refs                                                           |
| uncommitted changes, plain `return` | **prompts, takes the no-TTY default, aborts, leaves the slot leased - and exits 0**                                 |

The first two settle the question that was open. `treehouse return` is not a data-loss path, and a slot's `.git` is a pointer file rather than a repository, so objects were never duplicated in the first place.

The third is the finding that changes code:

```
| Worktree has uncommitted changes. Clean and return? [Y/n] 🌳 Aborted.
  return rc                          0
  final pool state                   1  leased  (held by gate-case-3)
```

With no TTY the prompt takes its default, does nothing, leaves the slot held, and exits 0. **Any script calling `treehouse return` must assert the slot is free afterwards rather than read `$?`.** That applies to the `hydration-prompt` close-out and to `skill-onboard.sh`, and it is written into both acceptance criteria in [the implementation plan](superpowers/plans/2026-08-24-skills-package-manager-implementation.md).

## After the compaction

This list is superseded. It has been reconciled into [the skills package manager implementation plan](superpowers/plans/2026-08-24-skills-package-manager-implementation.md), which is the ordered plan now; it is kept here so a question about where each item went can be answered.

| #   | Item                                             | Where it went                                                                   |
| --- | ------------------------------------------------ | ------------------------------------------------------------------------------- |
| 1   | Test `treehouse return` with unpushed commits    | **done, 2026-08-24.** See "Verified" above                                      |
| 2   | In-project pool vs `~/.treehouse/`               | **closed, 2026-08-24.** User-level, unchanged. See "Open, undecided" above      |
| 3   | `project-scaffold`: gitignore `.claude/skills/`  | plan ticket E2.2, blocked on the sync being proven end to end                   |
| 4   | `project-scaffold`: treehouse policy section     | plan ticket E2.4, unblocked by 2                                                |
| 5   | `hydration-prompt`: acquire and release the slot | plan ticket E2.8, unblocked by 1                                                |
| 6   | GitHub Actions bumps at merge                    | plan tickets E1.1, E1.7 and E1.8. The largest of the six, and why Epic 1 exists |

Items 3 through 6 are skill edits, so each carries a version bump and a regenerated registry per root `CLAUDE.md` Rule 16 - until E1.12 rewrites that rule and CI takes the obligation over.

### Unrelated loose ends from the same session

- **`treehouse destroy --force` no longer exists.** Any script still using it broke on 2026-08-23.
- **Node 20 vs the `>=22` floor.** `lavish-axi@0.1.57` wants Node >=22, `quota-axi@0.1.30` wants >=22.19, this machine runs v20.20.2. All five `-axi` tools were updated and all five were verified working, so the `EBADENGINE` warnings are advisory today. The risk is deferred and silent: the next release that actually calls a Node 22 API will throw at runtime rather than warn. Node 20 is end-of-life regardless. Upgrading moves `@anthropic-ai/claude-code` too, since it is installed globally under the same Node, so do it deliberately with nothing important open.
