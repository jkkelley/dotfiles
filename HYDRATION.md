# HYDRATION.md

The prompt that starts the next session, and the 10 before it.

**Read the top entry only.** It is the current one and it is complete on its own.
Everything below it has been superseded and is kept for history, not for reading.

**Newest on top.** Adding an entry removes the oldest in the same commit, so this
file holds exactly 10 once it has filled up. Entries are never renumbered and
never edited in place - a correction is a new entry.

Written by `hydration.sh add`. Do not hand-edit.
<!-- hydration-entry: none -->
## Implement doc for the skills package manager, reconciled with the two decided workflow docs
_Generated 2026-08-23 by hydration.sh. Newest entry._

### Ticket

No work order. This is the **implement-doc** phase of the skills package manager, phase 3 of 6 in the sequence: discovery, design doc, **implement doc**, poker, cut work-orders, do work. Tickets are cut in phase 5, after this one, so there is deliberately no ID yet.

Predecessor: the discovery and design sessions, merged as `#46` and `#47`.

### What just landed

Four documents on `main`, no code. Nothing has been built.

| File                                                                 | Lines | What it is                                    |
| -------------------------------------------------------------------- | ----- | --------------------------------------------- |
| `notes/skills-pm-discovery.md`                                       | 657   | measured state of the repo, and the gaps      |
| `docs/superpowers/specs/2026-08-23-skills-package-manager-design.md` | 428   | the design                                    |
| `docs/skill-distribution-workflow.md`                                | 81    | decided 2026-08-22, was untracked until `#47` |
| `docs/worktree-workflow.md`                                          | 243   | treehouse model, carries the real task list   |

The design settles: a TOML manifest at `.claude/skills.toml` as the only committed artifact, no lockfile, a `SessionStart` hook in `~/.claude/settings.json` rather than the project template, a sync tool as a PATH binary that no-ops without a manifest, registry schema 2 with `type` and `requires`, and five named failure modes with their handling.

The last two documents were written 2026-08-23 and left untracked. The design session never saw them and re-derived three of their decisions.

### What is NOT done

**Nothing has been built. No script, no workflow, no template change, no gitignore line exists.** What proves it:

```sh
ls claude/tools/ 2>&1              # No such file or directory
ls .github/ 2>&1                   # No such file or directory
git grep -n "skills.toml"          # only the two design docs
git grep -n "SessionStart" -- claude/   # nothing
```

**The design doc is wrong on one point and is merged that way.** It puts the CI version bump on the **PR branch**. `docs/skill-distribution-workflow.md` puts it on **merge to main**, and its reasoning is better: a version is a claim about ordering, and ordering is not knowable until merge. PRs `#41` and `#42` both allocated `project-scaffold` 1.2.0 from their own stale snapshots. Bumping on the PR branch reproduces that collision exactly. **Correct this before building.**

**Four things the design doc does not cover**, all raised in the two workflow docs:

- `.claude/scaffold.json` records which skill version the vendored copies came from. Gitignore the directory beside it and that record must survive independently or be regenerated.
- Rule 16 needs a carve-out for shared boilerplate. PR `#42` rewrote the read-only notice in all 42 `SKILL.md` files and forced 42 bumps.
- A skill local to one project that still needs version control. Flagged open and deliberately undesigned.
- `skill-onboard.sh` is specified using `git worktree add` by hand. That is the pattern `docs/worktree-workflow.md` exists to replace.

**Five decisions in the design doc are recommendations, not conclusions.** They are listed under "Decisions needing sign-off" and must be closed with the user, not chosen unilaterally.

### Stale or false in the docs

| Where                                                                      | What is wrong                                                                                                                                       |
| -------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------- |
| `2026-08-23-skills-package-manager-design.md`, "Publish, on the PR branch" | Superseded. Version allocation happens at merge time. See `docs/skill-distribution-workflow.md`                                                     |
| Same doc, "Onboarding an existing project"                                 | Uses `git worktree add` directly. Use treehouse                                                                                                     |
| Same doc, "Prerequisite"                                                   | Presents gitignoring `.claude/skills/` as newly discovered. It was decided 2026-08-22 and is item 3 of the task list in `docs/worktree-workflow.md` |
| `notes/skills-pm-discovery.md`                                             | Written before the two workflow docs were found. Treat the design doc as the current word wherever they differ                                      |
| Root `CLAUDE.md` Rule 16                                                   | Still says the author bumps and ships the registry. The actor becomes CI                                                                            |

### Your scope

Produce the **implementation document**. Not the code.

It decides build order, file layout, test strategy per Rule 14, and how the six items in "After the compaction" at the bottom of `docs/worktree-workflow.md` interleave with the design. That task list is the real backlog and predates the design doc; reconcile the two into one ordered plan rather than treating them as separate streams.

Output goes to `docs/superpowers/plans/2026-08-24-skills-package-manager-implementation.md`, matching the three plans already in that directory.

Also in scope: a follow-up PR correcting the four defects listed under "What is NOT done" in the design doc itself, so `main` stops asserting a superseded CI design.

Out of scope: writing `skill-sync.sh`, the workflow YAML, or any template edit. Those are phase 6.

### Before you start

**Close the five sign-off decisions with the user.** They are in the design doc under "Decisions needing sign-off": single registry source, the 30-minute stamp window, whether `skill-versioning` keeps its name, whether CI runs the skill test suites as well as `verify`, and Rule 17 Windows support. Ask; do not choose.

**Confirm the CI correction.** The design doc and `skill-distribution-workflow.md` disagree about where the bump happens. The recommendation is merge-time, and the evidence is the `#41`/`#42` collision, but the user should confirm before the implement doc bakes it in.

**One thing is genuinely unverified and gates treehouse adoption.** From `docs/worktree-workflow.md`: what `treehouse return` does with unpushed commits left on a branch. Idle slots are observed detached across all 15, but nothing was tested against a slot carrying unpushed work. Test it before the implement doc depends on it.

### Read in this order

1. `CLAUDE.md` at the repo root, all 17 rules. Rule 14 (Podman) and Rule 16 (versioning) both change in this work.
2. `HYDRATION.md`, this entry only.
3. `docs/superpowers/specs/2026-08-23-skills-package-manager-design.md` in full.
4. `docs/skill-distribution-workflow.md`, 81 lines. It overrides the design doc on CI.
5. `docs/worktree-workflow.md`, and especially "After the compaction" at the bottom.
6. `notes/skills-pm-discovery.md` only if you need the measurements behind a decision.
7. `claude/skills/skill-versioning/scripts/skill-version.sh`, `render_registry` at line 115, and `cmd_verify` at 174.

There is no `CONTEXT_STATE.md` in this repo.

### Reuse, it is proven

| Thing                                   | What it gives you                                                           | Sharp edge                                                                                        |
| --------------------------------------- | --------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------- |
| `skill-update.sh`                       | fetch a skill from GitHub with no dotfiles checkout; worktree-based PR flow | its `--mode inline` / `--mode standalone` split only means anything when the skill dir is tracked |
| `skill-version.sh verify`               | a pure pass/fail check, ideal as a CI gate                                  | also enforces the read-only notice and its per-skill URL, not just versions                       |
| `treehouse` v2.3.0, `~/.local/bin`      | worktree pool, self-updating Go binary                                      | v2.0.0 removed `destroy --force`; scripts using it broke 2026-08-23                               |
| `.claude/cache/`                        | already gitignored, declared derived, never pruned by `cache.sh`            | deleting it also deletes the sync tool's `.bak`                                                   |
| `project-scaffold/testing/`             | 14 numbered cases, `assert.sh`, `run-tests.sh`                              | the pattern to copy for testing `skill-sync.sh`                                                   |
| The `-axi` tools on `~/.npm-global/bin` | precedent for a PATH binary invoked from a `SessionStart` hook              | they run at `timeout: 10`; a cold skill sync needs more                                           |

### The verification ladder

1. `git grep` for the symbol. Catches a design doc referring to something that does not exist.
2. `bash -n` on any script. Catches the syntax error before a container spins up.
3. `skill-version.sh verify` locally. Catches an unversioned skill, a missing read-only notice, and a stale registry. It has caught all three.
4. The skill's own `testing/run-tests.sh` in Podman, per Rule 14 and `claude/skills/container-sandbox/references/skill-testing.md`.
5. A real session in a scratch repo, for anything touching the `SessionStart` hook. The hook only proves itself by firing.

Rung 5 matters more than usual here. The current session-start check is prose that an agent may or may not follow, and the entire point of this work is replacing it with something that cannot be skipped. That property is unobservable from a unit test.

### Traps, already paid for

- Untracked files in the working directory are invisible to a session that starts in a worktree. A whole session re-derived decided work because `docs/*.md` were never committed.
- `cannot remove a locked working tree` after a successful merge. A hand-rolled worktree pinning the branch. Hit twice now, once on 2026-08-23 and once in the design session. treehouse's detached-HEAD-when-idle invariant is the fix.
- Two PRs allocating the same version. Both were correct against their own snapshot of `main`. Git caught it only because they touched the same lines - the collision was semantic, the detector textual.
- `-p` in a `claude` launch command. It is `--print`: prints a reply and exits, so no session ever starts. The failure produces plausible output rather than an error.
- Overwriting a running bash script in place. Bash reads lazily by byte offset, so it reads garbage from wherever it had reached. `mv` preserves the inode; `cp` truncates it.
- A `SessionStart` hook that exits non-zero takes the session with it. Always exit 0, and print the failure loudly instead.

### Workflow

No work order exists for this phase, so there is no `work-order.sh` sequence to run. Tickets get cut in phase 5, from this document.

```sh
# isolated workspace
WT=$(treehouse get --lease --lease-holder "skills-pm-implement-doc")
cd "$WT"
git switch -c feat/skills-pm-implementation-doc

# ... write the implement doc, and the design-doc corrections ...

git add -A && git commit
git push -u origin HEAD
gh pr create --base main
gh pr merge <N> --squash --delete-branch

# close out
git checkout main && git fetch origin --prune && git merge --ff-only origin/main
treehouse return "$WT" --if-lease-holder "skills-pm-implement-doc"

HP=~/.claude/skills/hydration-prompt/scripts/hydration.sh
bash $HP add --project . --title "..." --body-file /tmp/entry.md
bash $HP command --project .
```

Docs-only changes touch nothing under `claude/skills/`, so no version bump and no registry regeneration are required. The moment a template or script is edited, Rule 16 applies.

### Conventions

Ticket references carry the ID **and** the full title, joined by a dash, on every mention. A bare ID is a defect.

No em dashes anywhere, plain dashes only. No agent co-author lines in commits. No Claude attribution footer in a PR body, ever, per Rule 13.

Feature branches only; `main` is never written directly. All testing runs in Podman per Rule 14. Pin every version to an immutable digest per Rule 15; `:latest` is banned.

Report failing tests as failing, and say plainly what was skipped. "Completed" is wrong if anything was silently left out.

