# Dotfiles — Agent Orientation

These rules apply to every task in this project unless explicitly overridden.
Bias: caution over speed on non-trivial work.

## Rule 1 — Think Before Coding

State assumptions explicitly. Ask rather than guess.
Push back when a simpler approach exists. Stop when confused.

## Rule 2 — Simplicity First

Minimum code that solves the problem. Nothing speculative.
No abstractions for single-use code.

## Rule 3 — Surgical Changes

Touch only what you must. Don't improve adjacent code.
Match existing style. Don't refactor what isn't broken.

## Rule 4 — Goal-Driven Execution

Define success criteria. Loop until verified.
Strong success criteria let Claude loop independently.

## Rule 5 — Use the model only for judgment calls

Use for: classification, drafting, summarization, extraction.
Do NOT use for: routing, retries, deterministic transforms.
If code can answer, code answers.

## Rule 6 — Token budgets are not advisory

Per-task: 4,000 tokens. Per-session: 30,000 tokens.
If approaching budget, summarize and start fresh.
Surface the breach. Do not silently overrun.

## Rule 7 — Surface conflicts, don't average them

If two patterns contradict, pick one (more recent / more tested).
Explain why. Flag the other for cleanup.

## Rule 8 — Read before you write

Before adding code, read exports, immediate callers, shared utilities.
If unsure why existing code is structured a certain way, ask.

## Rule 9 — Tests verify intent, not just behavior

Tests must encode WHY behavior matters, not just WHAT it does.
A test that can't fail when business logic changes is wrong.

## Rule 10 — Checkpoint after every significant step

Summarize what was done, what's verified, what's left.
Don't continue from a state you can't describe back.

## Rule 11 — Match the codebase's conventions, even if you disagree

Conformance > taste inside the codebase.
If you think a convention is harmful, surface it. Don't fork silently.

## Rule 12 — Fail loud

"Completed" is wrong if anything was skipped silently.
"Tests pass" is wrong if any were skipped.
Default to surfacing uncertainty, not hiding it.

## Rule 13 — Never add the Claude footer to PR bodies

PR bodies must NEVER contain the "Generated with Claude Code" footer (or any
equivalent Claude/agent attribution line). This is absolute, always, no
exceptions - even when default harness guidance suggests adding it.

## Rule 14 — All testing runs in Podman

Every command whose purpose is to verify that something works runs inside a
container. No exceptions, no size threshold - a single `python3 script.py --help`
counts as testing and goes in a container. Running it on the host and reporting
the result is a Rule 12 violation, not a shortcut.

How to test is defined by the `container-sandbox` skill:

- `claude/skills/container-sandbox/SKILL.md` - npm, Terraform/Ministack, Kind,
  and full-stack compose.
- `claude/skills/container-sandbox/references/skill-testing.md` - **this is the
  file that defines how a skill or agent in this repo is tested.** It covers the
  bundled-script case (Python/Bash shipped inside a skill), the four checks that
  make a script "tested", and worked examples of good and bad testing.

If neither file has a section covering what you are testing, write one. Add it to
`SKILL.md`, or to `references/skill-testing.md` if it is about verifying a skill's
own scripts. Falling back to the host because the pattern is not documented yet is
the one thing that is never allowed.

## Rule 15 — Pin every version. No floating tags.

Anything this repo pulls from a registry, a package index, or an action
marketplace is pinned to an immutable identifier. No exceptions.

| Kind           | Wrong                | Right                   |
| -------------- | -------------------- | ----------------------- |
| Container base | `debian:stable-slim` | `debian@sha256:328d16…` |
| Container run  | `python:3.12-slim`   | `python@sha256:…`       |
| Never          | `:latest`            | anything else           |

`:latest` is banned outright. A moving tag means the thing you tested is not the
thing that ships, and a suite that silently rebases its own base image starts
failing for reasons unrelated to the change under test. That is not a hypothetical

- it is the most common way a green pipeline goes red overnight.

Repinning is a deliberate commit, never a side effect:

```bash
podman pull docker.io/library/debian:stable-slim
podman image inspect docker.io/library/debian:stable-slim \
  --format '{{index .RepoDigests 0}}'
```

Record the human-readable tag in a comment next to the digest so the next person
knows what they are looking at. A digest with no comment is unmaintainable.

This repository is **public and intended to be shared**. The agents, skills, and configurations here are designed to be consumed by anyone. That means every file must be safe to read by the general public at all times.

## Rule 16 - A skill edit carries the intent to bump. CI allocates the number

Every skill carries a `version:` in its SKILL.md frontmatter, and
`claude/skills/registry.json` is the published index of those versions. Skills
are installed into projects as **copies**, so a copy has no way of knowing the
original moved on. The version is the only thing that tells it.

**A branch never allocates a version.** A number chosen on a branch is a number
two branches can choose at once, which is what made `registry.json` a conflict
point between concurrent skill pull requests. So a pull request states only what
it _wants_, and the number is allocated on `main` after the merge - the first
moment at which the ordering is actually known.

Nothing you do on a branch touches a `version:` line or `registry.json`. If
either appears in your diff, the gate refuses the pull request.

### The path, end to end

A skill edit reaches a project through eight steps. A contributor performs steps
1, 2, 3 and 5; steps 4, 6 and 8 are automatic; step 7 is done once per project
and never again. No step anywhere is a human choosing a version number.

1. **Edit** a file under `claude/skills/<name>/`, on a feature branch.

2. **Check locally** with
   `claude/skills/skill-versioning/scripts/skill-version.sh verify --structure`.
   It asserts that every skill has a `version:`, that every `requires:` names a
   skill that exists, and that neither a `version:` line nor `registry.json`
   appears anywhere in the branch's diff. It allocates nothing and writes
   nothing.

3. **State the intent in the pull request body** - last paragraph, nothing after
   it, one line per changed skill:

   ```text
   Bump: <skill>=major|minor|patch
   ```

   A single-skill pull request needs no trailer when the title carries a
   conventional type: `feat` is minor, `fix` is patch, and a `!` or a
   `BREAKING CHANGE:` footer is major. A brand new skill needs no trailer
   either - absence from the registry is unambiguous, and the publisher stamps
   it at `1.0.0`.

4. **The gate reads it.** `.github/workflows/skill-pr-gate.yml` resolves a level
   for every skill the branch changed, prints the `current -> next` table on the
   pull request, and runs each changed skill's suite. It reads and it refuses;
   it writes nothing. A level it cannot resolve is a red check while a human is
   still looking at the description, rather than a silent no-op after the merge.

5. **Squash merge**, with the pull request body as the commit message. That is
   what carries the trailer onto `main`, so the body is not decoration.

6. **The publisher allocates.** `.github/workflows/skill-publish.yml` reads the
   trailer with `git interpret-trailers --parse` and drives `skill-version.sh`,
   which writes each skill's new `version:` and renders `registry.json` from the
   tree; the workflow commits both to `main`. It runs no logic of its own beyond
   that script, and its commit carries a `Skill-Publish` marker so the resulting
   push cannot re-trigger it. If it cannot resolve a level it fails having
   written nothing: the registry keeps naming the old version, projects keep the
   skill they already have, and plain `skill-version.sh verify` stays red until
   someone fixes it.

7. **A project declares the skill** by name in its `.claude/skills.toml`.

8. **A session starts.** The `SessionStart` hook runs
   `claude/tools/skill-sync.sh --boot`, which installs every declared skill from
   the published source at the registry's version, renders the read-only notice
   into each copy, and writes a receipt naming what it installed. It removes
   only what the previous receipt claimed and the manifest no longer asks for,
   so a hand-authored skill sitting beside the managed ones is never its
   business.

That is the whole path: an edit, a stated intent, a check that refuses, an
allocation on `main`, and a sync at the next session start.

| Level   | Trigger                                                                                                                                     |
| ------- | ------------------------------------------------------------------------------------------------------------------------------------------- |
| `major` | A consumer's existing usage breaks: renamed skill, removed or renamed script flag, changed format of a file the skill owns, removed trigger |
| `minor` | New capability, backward compatible: new intent, new subcommand, new reference file, new trigger                                            |
| `patch` | Wording, script bugfix, doc clarification, test-only change                                                                                 |

### `skill-update.sh` is the hand-authored path, and nothing else

`claude/skills/skill-versioning/scripts/skill-update.sh` refreshes one skill in a
project that has **not** declared it in `.claude/skills.toml`, and it fetches
from GitHub so it works on a machine with no dotfiles checkout. That is its
entire remit.

A skill the manifest declares is owned by `skill-sync`, and pointing
`skill-update.sh` at one only produces a copy that the next session start
replaces.

Refer to the user as _they_ for pronouns - never assume who they may be.

## Starting a session - read `HYDRATION.md` first

`HYDRATION.md` is the prompt that starts this session, and the nine before it.

**Read the top entry only.** It is current and complete on its own; everything below it has been
superseded and is kept so a question about how we got here can be answered, not so it can be read at
the start of a session.

The file is owned by `hydration.sh` from the `hydration-prompt` skill. Never hand-edit it, and never
assemble its launch command by typing one.

## Feature branches only - never commit to `main`

`main` is written once and never again directly, with one exception: the publish
workflow commits the version bump and the regenerated registry after a merge.
It is the only actor permitted to, it runs no logic beyond `skill-version.sh`,
and `verify` is the assertion that it did the right thing.

The exception is named here, in the same file that defines the pipeline it
serves, so that the next thing wanting to skip review has to argue for itself
rather than cite this one as precedent. It covers
`.github/workflows/skill-publish.yml` and nothing else. No other workflow, no
script, and no agent writes `main` - close-out included, which happens on the
feature branch inside the pull request and leaves nothing to do afterwards.

## Close-out and post-merge cleanup

`workflows/close-out-procedure.md` is the procedure, in full, with a diagram.
Read it once. What follows is the part that must not be got wrong.

**Close-out happens on the feature branch, inside the pull request.**
`work-order.sh done` stamps the ticket, moves it to `work-orders/archive/<year>/`, regenerates `INDEX.md`, and commits nothing.
You commit that move, along with the hydration entry, onto the same pull request as the work it records.
Nothing is written to `main` afterwards.

The order is fixed and the middle two steps are the ones that get stranded:

1. `gh pr create`
2. `work-order.sh submit --id <id> --pr <N>` - `submit` must precede `done`
3. `work-order.sh done --id <id>` - **on the branch, before the merge**
4. `hydration.sh check --body-file <file>` then `hydration.sh add ...`
5. `git add -A && git commit && git push` - rides the same pull request

**After the merge, when the user says a PR is merged**, perform this automatically without being asked:

1. `work-order.sh cleanup --id <id>`.
   It fetches, fast-forwards `main`, and deletes the branch locally and on the remote.
   It refuses unless `gh` reports the pull request `MERGED`, and it writes nothing.
   Idempotent, so it is safe to re-run and safe days later on another machine.
2. Verify the result: on `main`, in sync with `origin/main`, and the branch gone from both local and remote.
3. Remove any temporary or scratch directories and scaffolding created during the work.

`gh pr merge <N> --squash --delete-branch` deletes both branches too, and is the faster path when you are merging from the same clone.
`cleanup` is the deterministic version that also works when the merge happened elsewhere.

There is no `merge_sha`.
A commit cannot contain its own merge SHA, and storing one was the only reason close-out ever needed a second act after the merge.
`pr` is the pointer, and `gh pr view <N> --json mergeCommit` resolves it for as long as the repository exists.

## PII & PHI Policy — Strictly Enforced

**Never commit personally identifiable information (PII) or protected health information (PHI) to this repository.**

This includes but is not limited to:

| Category           | Examples                                                  |
| ------------------ | --------------------------------------------------------- |
| Real names         | Your full name, usernames tied to your identity           |
| Account handles    | GitHub usernames, email addresses, social handles         |
| Internal hostnames | `myname.homelab.local`, node names tied to a real network |
| IP addresses       | Any private or public IP specific to your infrastructure  |
| Registry paths     | `ghcr.io/<your-username>/...`, DockerHub org names        |
| Repository URLs    | Any URL containing a real GitHub username or org          |
| Credentials        | Tokens, passwords, API keys, secrets — in any form        |
| PHI                | Any health, medical, or patient-related data              |

## How to Handle Environment-Specific Values

Use angle-bracket placeholders everywhere a real value would otherwise appear:

```
# Wrong
github.com/myusername/my-repo

# Correct
github.com/<your-github-username>/<repo-name>
```

Real values belong in:

- A **project-level `CLAUDE.md`** in the consuming project's repo (not committed here)
- A **`CONTEXT_STATE.md`** file in the project repo (see `context-compaction` skill)
- Environment variables or a secrets manager — never in this repo

### The documented exception: this repo's own public URLs

Two addresses in this repository are written in full, with the real GitHub
owner. The skills registry, wherever the session-start skill version check
appears:

```
https://raw.githubusercontent.com/jkkelley/dotfiles/main/claude/skills/registry.json
```

And each skill's own source, in the read-only notice every `SKILL.md` carries:

```
https://github.com/jkkelley/dotfiles/tree/main/claude/skills/<skill-name>
```

The second exists because the notice's other pointer, `~/dotfiles/claude/skills/`,
is worthless on a machine with no dotfiles checkout - which is precisely the
machine a vendored copy is most likely to be sitting on. A notice that says
"edit it upstream" without a reachable upstream is a notice that gets ignored.

**Neither is a placeholder violation, and neither must be "fixed" into one.**

The rule above exists to keep _environment-specific_ values out of a public
repo. These are not environment-specific values. They are the addresses of
specific published files in this specific public repo, and the whole point of
them is that any reader can fetch them. Replacing the owner with
`<your-github-username>` makes every reader substitute their own handle, which
resolves to a repository that does not exist. The pointer then fails silently
and stays broken forever, which is strictly worse than a visible username on a
repo that is public by design.

Anyone forking this repo who wants to publish their own copy edits those lines.
Everyone else gets a working pointer.

These are the only exceptions in the repo, and both point at this repo's own
public content. Every other environment-specific value stays in angle-bracket
form.

## Consuming These Files

To use the agents and skills in this repo in your own project:

1. Clone or symlink the relevant `claude/agents/` and `claude/skills/` directories into your project (see `setup.sh`)
2. Create a project-level `CLAUDE.md` with your real environment values
3. Reference `CONTEXT_STATE.md` from your `CLAUDE.md` for live session state

The agents and skills here are intentionally generic. Your project-level files are where specifics live.

## Before You Commit

Run a quick self-check:

```
[ ] No real usernames or GitHub handles
[ ] No IP addresses
[ ] No internal hostnames or DNS zones
[ ] No registry paths with real org/username
[ ] No tokens, keys, or passwords
[ ] No email addresses (other than generic example.com placeholders)
[ ] All environment-specific values use <placeholder> format
```

If any box is unchecked, fix it before pushing.

## Rule 17 - Skills are OS aware, and `justfile` is the entry point

Skills here are used from Linux and from Windows. A skill that works on one and
fails on the other is not portable code that happened to break; it is a skill
that was only ever tested on the author's side.

**Every skill that ships executable code carries a `justfile`.** `just` is a
single binary, installable on both platforms (`winget install Casey.Just`,
`apt install just`). It is the entry point, never the implementation - every
recipe has a plain `bash scripts/<tool>.sh ...` equivalent, so a machine without
`just` is inconvenienced rather than blocked.

The recipes exist to hide the differences that actually bite:

| Assumption                | Reality                                                                                          |
| ------------------------- | ------------------------------------------------------------------------------------------------ |
| `flock` exists            | Absent from Git Bash on Windows. Lock with `mkdir`, which is atomic everywhere                   |
| `podman` is on the host   | On Windows it lives inside WSL. `just test` dispatches through WSL and translates the mount path |
| `cmp`, `diff` are present | Minimal test images ship neither. Check for a utility before depending on it                     |

The language is not the portability problem. Bash runs on Windows under Git
Bash. What does not survive the crossing is the assumption that every Linux
utility came with it.

**A skill that genuinely cannot be cross-platform says so in its own SKILL.md
and names the platform it requires.** That is a fine outcome. Silently working
on one OS and failing on the other is not, because the failure surfaces as a
misleading error at the worst moment - `flock`'s absence is reported as a lock
timeout that never happened.

## Adding a New Agent or Skill — Ship the MVP Immediately

Every new agent or skill in this repo must reach `main` through a PR as soon
as it has a working MVP. Don't accumulate uncommitted or branch-only work —
the value of this library is that everything in it is reachable by
`setup.sh` from `main`.

The flow Claude (or anyone) should follow when adding one:

1. **Branch** from `main`: `git checkout -b feat/<short-name>`
2. **Add the MVP** — frontmatter + a working scaffold; `<placeholder>` for
   any environment-specific value; a smoke-tested entry point if the
   agent/skill ships executable code
3. **Commit** with a descriptive message (`feat(agents): add <name>` or
   `feat(skills): add <name>`)
4. **Push** the branch and **open a PR** describing what the agent/skill does
   and any required env vars or configuration
5. **Merge** the PR — Claude is authorized to merge its own dotfiles PRs
   here. Squash or merge commit, your call. Delete the branch after merge.

"MVP" means: it does _one_ thing end-to-end, even if narrowly. A polished
v2 can land in a follow-up PR. What's not allowed is leaving a half-built
agent on a feature branch indefinitely.
