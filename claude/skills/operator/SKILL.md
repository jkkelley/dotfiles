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

First, verify `gh` is authenticated:

```bash
gh auth status >/dev/null 2>&1
```

If this exits non-zero, tell the user: *"`gh` is not authenticated. Run `gh auth login`, then retry."* and stop. Do NOT proceed to scaffold.

Get the GitHub username:

```bash
gh api user --jq .login
```

If this exits non-zero, tell the user: *"`gh` API call failed (network or token issue). Try again later."* and stop.

With auth confirmed and `<user>` known, check whether the operator repo already exists on GitHub:

```bash
gh repo view "<user>/operator" --json name >/dev/null 2>&1
```

If this exits 0, the repo exists on GitHub → **Flavor 2**. Otherwise → **Flavor 1**. (Auth failures are no longer possible at this point because we checked first.)

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

3. Write `inbox.md` with this body:

   ```markdown
   # Inbox
   ```

4. Write `agenda.md` with this body (literal multi-line content, NOT escaped):

   ```markdown
   # Agenda

   _(none yet — run the planner)_
   ```

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

## Intent (a): capture an idea

**Trigger phrasing:** any prompt where the user is dropping a thought without asking for action — phrases like "idea —", "capture —", "btw —", "by the way —", "thought —", or simply a domain prefix followed by free text.

Example invocations:
- *"hey operator, weekend-business: idea — scrape Yelp reviews for restaurant niches"*
- *"hey operator, capture: try LangGraph for the planner"*
- *"hey operator, work: thought — pair with Marcus on the migration"*

### Behavior

1. Run pull-on-read: `git -C "$OPERATOR_REPO" pull --rebase` (warn but continue on failure).
2. Parse domain hint from the prompt (text before a `:` matching an existing domain). If none, the capture goes to a domain-less section of `inbox.md`.
3. Generate a 6-character id from `sha256(timestamp + text)`:

   ```bash
   id=$(printf '%s%s' "$(date -Iseconds)" "$captured_text" | sha256sum | head -c 6)
   ```

4. Append a line to `$OPERATOR_REPO/inbox.md` in the format:

   ```
   - [<id>] <YYYY-MM-DD HH:MM> :: [<domain>] <text>
   ```

   If no domain hint, omit the `[<domain>] ` prefix.

5. Commit and push:

   ```bash
   git -C "$OPERATOR_REPO" add inbox.md
   git -C "$OPERATOR_REPO" commit -m "capture: <id>"
   git -C "$OPERATOR_REPO" push
   ```

6. Output to user: `Captured to inbox: [<id>] <text>`

### Strict rule

Do NOT ask any follow-up questions on capture. Capture friction is the enemy. If the prompt is ambiguous about the domain, append without a domain prefix and let triage handle it later.

## Intent (f): create a new domain

**Trigger phrasing:** "create a new domain", "new domain", "add a domain", "make a domain".

Example invocations:
- *"hey operator, create a new domain called consulting"*
- *"hey operator, new domain: weekend-business — selling SaaS templates to local businesses"*

### Behavior

1. Run pull-on-read.
2. Parse the domain slug (required) from the prompt. Slugs must be lowercase, hyphenated, no spaces.
3. If the slug already exists at `$OPERATOR_REPO/domains/<slug>/`, tell the user and stop.
4. Build a draft north-star by reading `references/north-star-template.md` from this skill's directory and substituting:
   - `<DOMAIN_SLUG>` → the parsed slug
   - `<YYYY-MM-DD>` → today's date (`date -I`)
5. If the user provided a one-line mission in the prompt, populate the Mission section. If the user mentioned a `time-profile` value (matching one of the enum values), substitute it; otherwise leave the default `anytime` and ask in step 7 if they want to change it.
6. **Show the draft to the user, ask "ship it?"**
7. If the time-profile is still `anytime`, also ask: *"Time profile? (anytime / weekday-business-hours / evenings / weekends / weekends-and-evenings)"* — accept the answer.
8. On confirm:

   ```bash
   mkdir -p "$OPERATOR_REPO/domains/<slug>/projects"
   mkdir -p "$OPERATOR_REPO/domains/<slug>/archive"
   ```

   Write the populated north-star to `$OPERATOR_REPO/domains/<slug>/north-star.md`. Touch `.gitkeep` files in the empty `projects/` and `archive/` directories so git tracks them:

   ```bash
   touch "$OPERATOR_REPO/domains/<slug>/projects/.gitkeep"
   touch "$OPERATOR_REPO/domains/<slug>/archive/.gitkeep"
   ```

9. Commit and push:

   ```bash
   git -C "$OPERATOR_REPO" add domains/<slug>
   git -C "$OPERATOR_REPO" commit -m "domain: create <slug>"
   git -C "$OPERATOR_REPO" push
   ```

10. Output: `Domain '<slug>' created with north-star at domains/<slug>/north-star.md`.
