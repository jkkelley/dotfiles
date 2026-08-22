---
name: repo-sync
description: Syncs a local git repository to its main branch. Accepts a repo name or full path, finds the repo on disk if needed, runs git checkout main && git pull origin main, and gives the user a verification command that works from any working directory without disrupting their current session.
version: 1.0.2
---

# repo-sync — Sync a Repo to Main

> **This copy is read-only.**
> Skills are vendored into a project as copies, and this may be one.
> Edit this skill upstream, bump its version, then re-pull it - never edit the copy where it landed.
> Upstream is https://raw.githubusercontent.com/jkkelley/dotfiles/refs/heads/main/claude/skills/repo-sync/SKILL.md, and `skill-update.sh` pulls it from there - no dotfiles checkout is needed on this machine.
> `skill-update.sh` replaces the skill's directory rather than merging into it, so a local edit is destroyed by the next update with no conflict and no warning.
> The registry's content hash cannot catch it either, because a project's copy legitimately differs from upstream.

Syncs a local git repository to its `main` branch.
Accepts either a full path or a repo name.
Always uses `git -C <path>` so verification commands work from any directory without disrupting the user's current session.

## Input

The user provides one of:

- A **full path** — e.g. `~/projects/homelab-gitops`
- A **repo name** — e.g. `homelab-gitops`

## Step 1: Resolve the repo path

### If the user gave a full path

Expand `~` to the home directory and check if it exists and is a git repo:

```bash
test -d "<path>/.git"
```

If this fails:

- Tell the user: _"No git repo found at `<path>`."_
- Offer two options:
  1. _"Give me a different path."_
  2. _"Let me search for it — I'll look under `~/projects`, `~/Documents`, and `~/`."_
- Wait for the user's choice, then follow the appropriate branch below.

### If the user gave a repo name (or chose "search for it")

Search in order: `~/projects`, `~/Documents`, `~/`.
Set a 3-minute wall-clock limit on the entire search.

```bash
timeout 180 find ~/projects -maxdepth 3 -type d -name "<repo-name>" 2>/dev/null | head -5
# if empty:
timeout 180 find ~/Documents -maxdepth 3 -type d -name "<repo-name>" 2>/dev/null | head -5
# if still empty:
timeout 60 find ~/ -maxdepth 4 -type d -name "<repo-name>" 2>/dev/null | head -5
```

**If exactly one match is found:** proceed with that path.

**If multiple matches are found:** list them, ask the user which one to use.

**If no match is found (or the search times out):** tell the user:
_"I couldn't find a repo named `<repo-name>` anywhere under `~/projects`, `~/Documents`, or `~/` within 3 minutes. Double-check the name, or give me a full path."_
Stop.

## Step 2: Checkout main

```bash
git -C "<resolved-path>" checkout main
```

**If this succeeds:** continue to Step 3.

**If this fails:**

- Tell the user: _"Couldn't switch to `main` in `<resolved-path>`. This repo may use a different primary branch name."_
- Check what the remote thinks the default branch is:

  ```bash
  git -C "<resolved-path>" remote show origin | grep 'HEAD branch'
  ```

- If that returns a branch name (e.g. `master`): tell the user what it found and ask _"Want me to checkout `<branch>` instead?"_
- If the remote check also fails (no remote, network issue): tell the user what happened, show the raw error, and stop.
- Do NOT automatically checkout a different branch without the user's explicit confirmation.

## Step 3: Pull from origin

```bash
git -C "<resolved-path>" pull origin main
```

### Pull error handling

Wrap all errors — never dump raw git output alone.
Always explain what happened, what the user's options are, and flag anything dangerous.

| Scenario                  | Message to user                                                                                      | Options to offer                                                                                                                                                                                                             |
| ------------------------- | ---------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Merge conflict            | "There are conflicting changes between your local branch and the remote. Git can't auto-merge them." | 1. Manually resolve conflicts, then `git -C <path> add . && git -C <path> commit` 2. Discard your local changes with `git -C <path> reset --hard origin/main` (**warn: this permanently deletes uncommitted local changes**) |
| Uncommitted local changes | "You have local changes that would be overwritten by the pull."                                      | 1. Stash changes: `git -C <path> stash`, then retry 2. Discard them: `git -C <path> checkout -- .` (**warn: permanent**) 3. Commit them first, then retry                                                                    |
| No remote `origin`        | "This repo doesn't have a remote named `origin`. Nothing to pull from."                              | Show what remotes exist: `git -C <path> remote -v`. Ask if they want to use a different remote.                                                                                                                              |
| Network/auth failure      | "Couldn't reach the remote. This is usually a network or auth issue."                                | 1. Check connection and retry 2. Check SSH key or token is set up for this remote                                                                                                                                            |
| Already up to date        | Not an error — tell the user: "Already up to date. No new commits pulled."                           | None needed                                                                                                                                                                                                                  |

**Dangerous operation rule:** before suggesting any command that rewrites or discards history (e.g. `reset --hard`, `checkout -- .`, `push --force`), always prepend a clear warning:
_"Warning: this will permanently discard your local changes and cannot be undone."_

## Step 4: Confirm and verify

### Plain English summary (always shown)

Tell the user what happened in plain terms:

- Which repo was synced
- What branch they're now on
- How many new commits were pulled (parse from git output, e.g. "Fast-forward ... 3 files changed" → "3 commits pulled")
- If already up to date, say so

Example:

> Synced `homelab-gitops` to `main`. Pulled 4 new commits. You're now on the latest version of main.

### Verification commands (always show both)

Show both blocks every time, labeled clearly:

---

**New to git? Run this:**

```bash
git -C <resolved-path> log --oneline -3
```

This shows the last 3 saves (commits) to the repo.
The top line should be the most recent one.
You can run this from anywhere — it won't affect what you're currently working on.

---

**Familiar with git? Run these:**

```bash
git -C <resolved-path> status
git -C <resolved-path> log --oneline -5
```

---

The `git -C <path>` flag tells git to operate on a specific repo without changing your current directory.
Safe to run from inside any other project.
