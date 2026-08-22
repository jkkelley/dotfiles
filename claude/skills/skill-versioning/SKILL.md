---
name: skill-versioning
description: Semver for the skills in this dotfiles repo, and the machinery that keeps a project's installed copies honest. Use when bumping a skill's version, regenerating claude/skills/registry.json, checking whether a project's .claude/skills are behind the published registry, or applying an update to a project. Triggered by "bump this skill", "is my skill out of date", "update the skill in this project", "regenerate the registry", or by the session-start skill version check in CLAUDE.md.
version: 1.0.2
---

# Skill versioning

> **This copy is read-only.**
> Skills are vendored into a project as copies, and this may be one.
> Edit this skill upstream, bump its version, then re-pull it - never edit the copy where it landed.
> Upstream is `~/dotfiles/claude/skills/skill-versioning/`, or https://github.com/jkkelley/dotfiles/tree/main/claude/skills/skill-versioning if that checkout is not on this machine.
> `skill-update.sh` replaces the skill's directory rather than merging into it, so a local edit is destroyed by the next update with no conflict and no warning.
> The registry's content hash cannot catch it either, because a project's copy legitimately differs from upstream.

Skills are installed into projects as copies.
A copy has no idea the original moved on, so the moment a skill is edited here, every project holding a copy is silently behind.
That is not hypothetical: it is the default state of every project in this setup.

This skill fixes visibility first and updating second.
The version is metadata the copy carries with it, the registry is the published truth to compare against, and the update is a scripted, repeatable apply.

## The three pieces

| Piece                              | Where                               | Who writes it               |
| ---------------------------------- | ----------------------------------- | --------------------------- |
| `version:` in SKILL.md frontmatter | every skill                         | `skill-version.sh`          |
| `claude/skills/registry.json`      | this repo, published raw over HTTPS | `skill-version.sh`          |
| The session-start check            | each project's CLAUDE.md            | the agent, once per session |

The version lives in frontmatter because that is the one file `setup.sh` already copies.
An installed skill therefore self-reports its own version with no extra file and no change to the installer.

## What a version bump means

| Bump  | Trigger                                                                                                                                             |
| ----- | --------------------------------------------------------------------------------------------------------------------------------------------------- |
| MAJOR | A consumer's existing usage breaks. Renamed skill, removed or renamed script flag, changed format of a file the skill owns, removed trigger phrase. |
| MINOR | New capability, backward compatible. New intent, new script subcommand, new reference file, new trigger.                                            |
| PATCH | Wording, script bugfix, doc clarification, test-only change.                                                                                        |

## Commands

Run from anywhere; the script locates the skills directory from its own path.

```bash
scripts/skill-version.sh init                       # stamp unversioned skills at 1.0.0
scripts/skill-version.sh bump <skill> --minor       # bump one skill, regen the registry
scripts/skill-version.sh verify                     # the gate: versions present, notice present, registry fresh
scripts/skill-version.sh list                       # every skill and its version
```

`bump` is the only supported way to change a version.
Hand-editing the field leaves the registry stale, and `verify` exists to catch exactly that.

### Bump once, last

`bump` raises the version every time it is called, and it has no way to lower one again.
Run it **once, at the end**, after the last edit to the skill and immediately before committing.

Bumping in the middle and then editing again leaves the registry stale, and the obvious reaction - bump a second time - inflates the version by a release that never existed.
`hydration-prompt` reached 2.0.1 that way: 2.0.0 was published to nothing and skipped by nobody.
Harmless, and still a number that describes history inaccurately, which is the one thing this file is supposed to prevent.

The habit is: finish the change, run `verify` to see the drift, then bump once to clear it.

## Every SKILL.md carries the read-only notice

A skill is copied into a project, and the copy is the file an agent reads there.
If it does not say it is read-only, nothing does - a pointer to a document that did not travel with it is worth nothing at the moment somebody has the copy open and is about to change it.

The stakes are not stylistic.
`skill-update.sh` replaces the skill's directory rather than merging into it, so an edit made in a project is destroyed by the next update with no conflict and no warning.
The registry's `sha256` cannot catch that either: a project's copy legitimately differs from upstream, so the hash was never going to match and the drift is invisible from both ends.

`verify` fails on any `SKILL.md` without it, and names the skill.
That is what stops a new skill from being born without it, which is the failure this repository has already had once - with the session-start check, which lived in exactly one project until somebody asked why.

The block sits under the title and names that skill's own upstream twice: the local path, and the public URL.
Both, because the local path is worthless on a machine with no dotfiles checkout - which is precisely the machine a vendored copy is most likely to be sitting on.
A notice that says "edit it upstream" without a reachable upstream is a notice that gets ignored.

Neither is a placeholder. See the documented exception in root `CLAUDE.md`.
Copy the block from any other skill.

## The registry is generated, never edited

`render_registry` is a pure function of the skills on disk.
Same tree in, same bytes out.
That is what lets `verify` be a straight string comparison against the committed file instead of a JSON parser, and it is why the registry carries no timestamp.
A timestamp would change on every render and make `verify` fail for no reason.
When the comparison fails, `verify` walks the entries line-wise and names the skills that drifted rather than printing a byte diff, because the answer the reader wants is which skill to bump.
That path deliberately shells out to nothing beyond bash, grep and coreutils, so the tests can run on a minimal image.

Each entry carries a version and a `sha256` over the skill's file contents and relative paths.
The hash is what catches the failure the version alone cannot: contents changed, version did not.

```json
{
  "schema": 1,
  "generator": "skill-version.sh",
  "skills": {
    "hydration-prompt": { "version": "1.0.0", "sha256": "..." }
  }
}
```

The hash is a repo-side gate only.
The session-start check in a project compares versions, because a project's copy legitimately excludes files (`testing/`, for instance) and would never match the hash.

## Applying an update to a project

`scripts/skill-update.sh` implements the two apply modes the session-start check offers.

```bash
scripts/skill-update.sh --skill hydration-prompt --mode inline     --project ~/projects/foo
scripts/skill-update.sh --skill hydration-prompt --mode standalone --project ~/projects/foo
```

**inline** copies the skill into the working tree and stops.
The change is left uncommitted so it rides the commit the user is already about to make.
No branch, no PR, no round trip, no interruption.

**standalone** does the whole thing now, inside a throwaway git worktree so the user's dirty working tree is never touched.
It branches off `origin/main`, copies, commits, pushes, opens a PR, squash-merges it, deletes the remote branch, removes the worktree, fast-forwards local main when that is safe, and prints the PR URL.

The PR is merged without review on purpose.
The content is a byte copy of a file already reviewed in dotfiles, so there is nothing left for a human to decide.

Both modes replace the destination directory rather than merging into it.
A file deleted upstream has to disappear downstream too, or a skill goes on executing a script its own SKILL.md no longer mentions.

Every run is logged to `<project>/.claude/logs/skill-update-<skill>-<timestamp>.log`.
On failure the script names the step it died on, points at the log, and removes the worktree and branch, so a failed run leaves nothing half-applied.

## The obligation this creates on every skill edit

Changing any file under `claude/skills/<name>/` obliges the same PR to bump that skill's version and regenerate the registry.
This is Rule 16 in this repo's CLAUDE.md.
`skill-version.sh verify` is the gate that enforces it.

## Testing

Run from this skill's directory. 49 checks, 20 of them negative.

```bash
podman run --rm --userns=keep-id --network=none --entrypoint="" \
  -v "$PWD:/skill:ro,Z" -v "$(mktemp -d):/work:Z" -w /work \
  docker.io/bitnami/git@sha256:1baa6ddbde79fa7ba2fdf441cea47c4f04fae067504d9265e416358db0879ab2 \
  bash /skill/testing/run-tests.sh
```

The image is `bitnami/git` rather than `bash:5` because these scripts drive real git: worktrees, a bare remote, push, fast-forward.
`bash:5` ships no git at all, so testing this against it would test nothing that matters.

The source mount is read-only, which matters here because `init` and `bump` rewrite SKILL.md files in place.
The tests copy a fixture tree into `/work` and point `SKILL_VERSION_SKILLS_DIR` at it, so a passing run also proves neither script writes back into its own source.
`--network=none` proves the same about the network.
Standalone mode is driven against a local bare repo with a stubbed `gh` that performs the merge itself, so the branch, commit, push, merge and delete orchestration is genuinely exercised without ever reaching GitHub.
