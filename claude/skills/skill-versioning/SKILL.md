---
name: skill-versioning
description: Semver for the skills in this dotfiles repo, and the machinery that keeps a project's installed copies honest. Use when bumping a skill's version, regenerating claude/skills/registry.json, checking whether a project's .claude/skills are behind the published registry, or applying an update to a project. Triggered by "bump this skill", "is my skill out of date", "update the skill in this project", "regenerate the registry", or by the session-start skill version check in CLAUDE.md.
version: 2.0.4
---

# Skill versioning

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
scripts/skill-version.sh verify                     # the publisher's gate: versions present, registry fresh
scripts/skill-version.sh verify --structure         # the PR gate: versions present, registry untouched
scripts/skill-version.sh list                       # every skill and its version
```

`bump` is the only supported way to change a version.
Hand-editing the field leaves the registry stale, and `verify` exists to catch exactly that.

### The two forms of `verify`

They exist because two callers ask different questions, and the answer that is right for one is wrong for the other.

| Form          | Caller        | Asserts                                                                                                                     |
| ------------- | ------------- | --------------------------------------------------------------------------------------------------------------------------- |
| `verify`      | the publisher | every skill versioned, every `requires:` resolves, the registry is this schema, and it matches what the tree renders        |
| `--structure` | the PR gate   | every _registered_ skill versioned, every `requires:` resolves, and the branch's diff touches no `version:` and no registry |

Under merge-time allocation the version is allocated by CI when a PR merges, not by the contributor on the branch.
A skill PR therefore edits a skill and leaves the registry alone - and that state is exactly what plain `verify` calls `drifted`, correctly, because on `main` it would be.
`--structure` is the form that can gate a branch in that state without also blessing a stale registry on `main`.

`--structure` diffs against the first of `origin/main` or `main` that resolves; `--base <ref>` overrides it.
Outside a git repository it fails rather than passing with nothing checked.
The comparison runs against the working tree, so an uncommitted hand-edit is caught before it is ever committed.

Hand-editing is caught by both, by different means.
`--structure` sees the edit in the diff.
Plain `verify` sees it in the hash: the `version:` line lives inside `SKILL.md`, so moving it moves the content hash too, and the registry comparison fails.

#### A skill the registry has never carried

`--structure` makes none of its version assertions about a skill that is absent from `registry.json`.
Absence is the test for "this skill is new", and it is the same test `bump-gate.sh resolve` already makes before reporting a row as `- -> 1.0.0 new`.
Nothing was ever published under that name, so there is no allocated number for a branch to contradict.

That covers three shapes, and it has to cover all three or adding a skill becomes the one change the pipeline cannot land:

- a new skill with no `version:` line, which is what the publisher expects - it stamps the skill at `1.0.0` with `init` after the merge
- a new skill whose author wrote the line by hand anyway
- a renamed directory, which arrives under a name `main` has never seen, as an added file whose every line including `version:` is a `+`

The other half of a rename is the old path, and a `SKILL.md` that is gone from the tree is exempt too.
Its `version:` line leaves the diff as a `-`, which is a removal rather than a choice of number.
`bump-lib.sh`'s `skill_exists` exempts the same case for the same reason: a skill the change deletes needs no bump.

Every skill the registry does carry is held to the rule exactly as before, on the same tree, in the same run.
The exemption is per skill and not a switch a branch can flip.

Plain `verify` is unchanged and still refuses any unversioned skill.
It runs on `main` after the publisher, where everything has been stamped already, so one found there means `init` did not run - which is the post-state assertion the publisher depends on.

Both forms assert that every name in a `requires:` resolves to a skill that exists.
That is a property of the tree rather than of the registry, so the PR gate is the right place to reject it.
A typo'd dependency is the one failure the auto-install path cannot recover from: uncaught, it surfaces on some project's first sync, days later and somewhere else.

### The drift report names skills and tools separately

`registry.json` has two blocks and they are not the same kind of thing, so a stale registry is reported in two vocabularies rather than one.

| Line                        | Means                                                                        |
| --------------------------- | ---------------------------------------------------------------------------- |
| `drifted           <skill>` | the skill's contents moved and its `version:` did not                        |
| `not in registry   <skill>` | on disk, no row for it                                                       |
| `stale entry       <skill>` | a row with no directory behind it                                            |
| `tool drifted      <tool>`  | the tool's bytes moved and its `skill-tool-version:` marker did not          |
| `tool unregistered <tool>`  | on disk, no row for it                                                       |
| `tool gone         <tool>`  | a row with nothing behind it - `render_tools` skips a file that is not there |

Both blocks are compared in both directions, and each half is read through its own filter - `skills_block` and `tools_block`, the same `sed` range idiom `bump-lib.sh`'s `registry_version` uses.
A reader that walks the whole file instead sees `render_tools`'s entries at the same four-space indent as a skill's and calls a tool a skill that does not exist.

**The advice differs because the fix differs, and only the kind that was named gets a trailer.**
A skill is fixed with `bump`.
A tool is not: it has no frontmatter, so its version is the `skill-tool-version:` marker inside the file, raised by hand - and the registry is written from that marker, by the publisher on `main` or by `init` locally.
Handing a reader `bump <tool>` hands them a command that exits non-zero with `no such skill`.

If the registry differs and neither block accounts for it - a hand-edited `generator` line will do it - the failure says exactly that and points at `init`, rather than exiting non-zero in silence.

### A schema mismatch is its own failure

Plain `verify` reads the `schema` number out of the committed registry before comparing anything, and stops if it is not the number this generator writes.

The comparison is a string comparison, so a registry from an older generator differs on every single line.
Left to run, it names all forty-three skills as `drifted` and explains none of them - the reader is told forty-three times to bump a skill, when the actual fix is one `init`.
Refusing to compare is the more useful answer, and it is the only one that names the real cause.

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

**`verify` no longer checks for it, in either form.**
It used to fail on any `SKILL.md` without the notice and name the skill.
That check is gone, and nothing has replaced it yet: the notice is asserted present nowhere and absent nowhere.

This is a deliberate middle state, not an oversight.
The notice is being replaced by a single generated partial that `skill-sync` writes into an installed copy, so the end state asserts the notice is **absent** from every `SKILL.md` in this repository.
Between here and there the repository is mixed, and a gate that asserts "present" fails the first cleaned file while a gate that asserts "absent" fails the other forty-two.
Neither assertion is true of the tree, so for now `verify` makes neither.

The block sits under the title and names that skill's own upstream: the raw GitHub URL of its `SKILL.md`.
One URL and no local path beside it, because the local path was worthless on a machine with no dotfiles checkout - which is precisely the machine a vendored copy is most likely to be sitting on.
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
  "schema": 2,
  "generator": "skill-version.sh",
  "skills": {
    "hydration-prompt": {
      "version": "1.0.0",
      "sha256": "...",
      "type": "skill",
      "requires": []
    },
    "living-docs": {
      "version": "1.0.0",
      "sha256": "...",
      "type": "skill",
      "requires": ["work-order"]
    }
  },
  "tools": {}
}
```

One entry per line, and every entry the same shape.
The line is what `verify` compares and what it prints when a skill drifts, so nothing may split an entry across lines.
`requires` is rendered even when empty so a consumer never branches on key presence.

### `type` is derived, never declared

`type` is routing and nothing else: `skill` to `.claude/skills/`, `agent` to `.claude/agents/`.
It is a property of the tree an entry was found in, and the entry never states it.

Declaring it in frontmatter would write down a fact the filesystem already states, and create a second source of truth that can disagree with the first.
`render_registry` has to walk those directories to find the entries at all, so it already knows.

Today it walks the skills tree and nothing else, so every entry renders as `skill`.
`claude/agents/` carries no version and no registry row yet.

### `requires` is comma-separated, and it is not a YAML list

An optional frontmatter key, on the skill that has the dependency.
Absent means no dependencies, which is forty-one of the forty-three skills.

```yaml
---
name: living-docs
description: ...
version: 1.0.0
requires: work-order
---
```

Two or more names are separated by commas.
**Not a bracket list.** Rule 17 makes Git Bash a supported platform, and a bracket list needs a real parser where `requires: a, b` needs one line of `awk` - the same shape as the `read_version` beside it.

It is read from the leading fenced block only, exactly as `version:` is, so a `requires:` line in the body is prose and is ignored.
A skill that documents the key does not thereby acquire a dependency on it.

### The `tools` block

Shared infrastructure that is not a skill: the sync binary, and the read-only notice template that replaces the copy currently inlined in forty-three `SKILL.md` files.
A version and a hash here are the only thing that lets a change to either one reach an installed project.

| Tool               | File                                             |
| ------------------ | ------------------------------------------------ |
| `skill-sync`       | `claude/tools/skill-sync.sh`                     |
| `read-only-notice` | `claude/tools/partials/read-only-notice.md.tmpl` |

A tool has no frontmatter, so its version is a marker token instead - `skill-tool-version: 1.0.0`, readable under any comment syntax and impossible to confuse with a `version:` in prose.
A registered tool that is present but carries no marker is a hard failure, not a version-less entry.

**An entry is rendered only for a tool that exists on disk.**
`claude/tools/` has not been built yet, so the block renders as `{}` today.
That is the intended output, not a stub: `render_registry` is a pure function of the tree and cannot hash a file nobody has written, and a placeholder hash would be strictly worse than an absent entry because it would stay green after the real file landed.
Each entry appears on its own as its file lands, with no edit to `render_tools`.

The hash is a repo-side gate only.
The session-start check in a project compares versions, because a project's copy legitimately excludes files (`testing/`, for instance) and would never match the hash.

## Applying an update to a project

**This is the hand-authored path, and nothing else.**
A skill named in a project's `.claude/skills.toml` belongs to `claude/tools/skill-sync.sh`, which reinstalls it from the published source at every session start.
Pointing `skill-update.sh` at one of those produces a copy the next session start replaces - no conflict, no warning, and no sign that the work was undone.
Root `CLAUDE.md` Rule 16 states the split as policy; the script's own header states it as the first thing you read.

The test is the manifest, not the skill: a name in it means `skill-sync`, a name absent from it or a project with no manifest at all means this script.
Bringing a project onto the sync is `skill-onboard.sh`, and adding a skill to a project already on it is a line in `.claude/skills.toml` followed by a new session.

`scripts/skill-update.sh` implements the two apply modes the session-start check offers.

```bash
skill-update.sh --skill hydration-prompt --mode inline     --project ~/projects/foo
skill-update.sh --skill hydration-prompt --mode standalone --project ~/projects/foo
```

**The skill is fetched from GitHub, not from a checkout.**
`--from remote` is the default: one `codeload` tarball request for `jkkelley/dotfiles@main`, one directory extracted out of it.
A tarball rather than per-file raw requests, because 20 of the skills ship scripts, tests and references, and a per-file fetch needs a file list nobody maintains.

That is the whole point of the arrangement.
The script used to derive its source from its own location inside dotfiles, so the only machine that could not update a skill was a machine that had never cloned dotfiles - which is every machine a vendored copy is most likely to be sitting on.

`--from local` reads `--dotfiles` instead, which is how an unpushed change is tested before it ships.
`--repo` and `--ref` move the remote source, for a fork or a branch.

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

Run from this skill's directory. 103 checks, 42 of them negative.

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
`verify --structure` gets a second fixture: a real git repository with its skills under `claude/`, branched and edited, because every assertion that form makes is about a diff.
`--network=none` proves the same about the network.
Standalone mode is driven against a local bare repo with a stubbed `gh` that performs the merge itself, so the branch, commit, push, merge and delete orchestration is genuinely exercised without ever reaching GitHub.
