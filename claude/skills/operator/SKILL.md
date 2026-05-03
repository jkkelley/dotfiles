---
name: operator
description: Personal work-steering system. Captures ideas to a private inbox, tracks projects across multiple life domains (work, weekend-business, personal, etc.), and recommends what to work on weighted by time-of-week. Triggered by phrases like "hey operator", "btw operator", "operator:". Backed by a private git repo at $OPERATOR_REPO (default ~/projects/operator). NOT for kubernetes operators, mathematical operators, or any code-level use of the word "operator".
---

# Operator — Personal Work-Steering System

This skill is a single named entry point. The user invokes it in natural language and it parses two things from the prompt:

- **Domain hint** — `work`, `weekend-business`, `personal`, or any custom domain the user has created. Hint may be absent (some intents work without one).
- **Intent** — one of the 10 intents documented below.

The skill operates against a private data repo at `$OPERATOR_REPO` (default `~/projects/operator`). It does NOT operate on the current working directory.

## Configuration

- Read `$OPERATOR_REPO` from the environment. If unset, default to `~/projects/operator` (expand `~`).
- The data repo is git-tracked with a remote on GitHub (private). Sync rules:
  - **Pull-on-read:** before any read intent (plan, status, agenda, triage), run `git -C "$OPERATOR_REPO" pull --rebase`. On conflict or network failure, warn the user but continue with local state.
  - **Push-on-write:** after any write intent (capture, new-project, close, edit-north-star, new-domain), commit and `git -C "$OPERATOR_REPO" push`. On push failure, commit locally and tell the user to retry.
- If `$OPERATOR_REPO` does not exist on disk, run the **Bootstrap** flow before performing the requested intent (see below).

## Data layout

```
$OPERATOR_REPO/
├── README.md
├── domains/
│   └── <domain>/
│       ├── north-star.md
│       ├── projects/
│       │   └── <slug>.md
│       └── archive/
├── inbox.md
└── agenda.md
```

## Intent dispatch

When invoked, parse the user's prompt for:

1. **Domain hint** — look for a domain name followed by `:` (e.g., `weekend-business:`), or a domain mentioned naturally (e.g., "the work north-star"). Match against existing directories under `$OPERATOR_REPO/domains/`. If ambiguous, ask the user to clarify.
2. **Intent** — match the prompt's verb and structure to one of the intents below.

Intents are documented in subsequent sections. (Filled in by later tasks.)

## Bootstrap (implicit, runs when `$OPERATOR_REPO` does not exist)

Triggered automatically before performing any intent if the path resolved from `$OPERATOR_REPO` does not exist on disk. Do NOT require the user to type a magic command.

### Step 1: Detect remote state

Run:

```bash
gh repo view "$(gh api user --jq .login)/operator" --json name 2>/dev/null
```

If the command exits 0, the repo exists on GitHub (Flavor 2). Otherwise it does not (Flavor 1). If `gh` itself fails (not authenticated), tell the user: *"`gh` is not authenticated. Run `gh auth login`, then retry."* and stop.

### Flavor 1: Brand-new setup (remote does not exist)

Tell the user concisely: *"No operator repo yet. I'll scaffold one and create a private GitHub repo. Proceed?"* Wait for confirmation.

On confirmation:

1. Create the local directory:

   ```bash
   mkdir -p "$OPERATOR_REPO"
   cd "$OPERATOR_REPO"
   git init -b main
   ```

2. Write `README.md` by copying the contents of `references/operator-repo-readme.md` (use the Read tool to fetch the template from this skill's directory, then Write it into `$OPERATOR_REPO/README.md`).

3. Write empty `inbox.md` with a single `# Inbox` heading.

4. Write empty `agenda.md` with a single `# Agenda\n\n_(none yet — run the planner)_` body.

5. Create `domains/` directory (empty).

6. Initial commit:

   ```bash
   git add .
   git commit -m "Initial scaffold"
   ```

7. Create remote and push:

   ```bash
   gh repo create operator --private --source=. --push
   ```

8. After scaffold completes, tell the user: *"Operator repo created at `$OPERATOR_REPO` and pushed to GitHub. Want to create your first domain now? (e.g., 'work', 'weekend-business', 'personal')"* — if yes, dispatch to intent (f).

9. Then resume the original intent the user invoked.

### Flavor 2: New machine (remote exists)

Tell the user: *"No operator repo on this machine, but found `<user>/operator` on GitHub. Clone it to `$OPERATOR_REPO`?"* Wait for confirmation.

On confirmation:

```bash
gh repo clone "$(gh api user --jq .login)/operator" "$OPERATOR_REPO"
```

Then resume the original intent.

### Edge cases

- **`$OPERATOR_REPO` parent doesn't exist:** create it with `mkdir -p "$(dirname "$OPERATOR_REPO")"` before init/clone.
- **Path exists but is not a git repo:** stop, ask user to either delete or move the directory.
- **Path exists and is a git repo but no remote:** continue; the next push-on-write will fail with a useful message.
