# Operator Skill — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a personal work-steering Claude Code skill (`operator`) that captures fleeting ideas, tracks projects across multiple life domains, and recommends what to work on — backed by a private GitHub data repo with pull-on-read/push-on-write sync.

**Architecture:** A user-level Claude Code skill at `claude/skills/operator/SKILL.md` plus two read-only subagents (`operator-planner`, `operator-triage`). Skill code is generic and lives in this public dotfiles repo; per-user data lives in a separate private repo at `$OPERATOR_REPO` (default `~/projects/operator`). The skill is invoked in natural language ("hey operator, ...") and dispatches by parsing a domain hint and an intent from the prompt.

**Tech Stack:** Markdown skill/agent definitions, Bash for git + `gh` CLI operations, no runtime code outside what Claude orchestrates via Read/Write/Edit/Bash tools.

**Reference spec:** [docs/superpowers/specs/2026-05-02-operator-design.md](../specs/2026-05-02-operator-design.md)

---

## File Structure

```
claude/skills/operator/
├── SKILL.md                                # main skill — intent dispatch and per-intent behavior
└── references/
    ├── north-star-template.md              # template scaffolded into domains/<d>/north-star.md
    ├── project-card-template.md            # template scaffolded into domains/<d>/projects/<slug>.md
    └── operator-repo-readme.md             # README written into the data repo on bootstrap

claude/agents/
├── operator-planner.md                     # subagent for intent (b) — read-only planner
└── operator-triage.md                      # subagent for intent (i) — read-only triage suggester

setup.sh                                    # already symlinks claude/* — verify operator picked up
```

**Why this split:** SKILL.md holds the dispatch logic and per-intent instructions because they belong together (one read = full understanding of what the skill does). Templates are extracted because they're scaffolded verbatim into another repo and editing a template shouldn't require editing dispatch logic. Subagents are separate files because Claude's agent discovery requires top-level files in `claude/agents/`.

---

## Task 1: Scaffold the operator skill directory and frontmatter

**Files:**
- Create: `claude/skills/operator/SKILL.md`
- Create: `claude/skills/operator/references/.gitkeep`

- [ ] **Step 1: Create skill directory**

```bash
mkdir -p claude/skills/operator/references
touch claude/skills/operator/references/.gitkeep
```

- [ ] **Step 2: Write SKILL.md with frontmatter and overview**

Write `claude/skills/operator/SKILL.md`:

````markdown
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
````

- [ ] **Step 3: Verify file is well-formed**

Run: `head -5 claude/skills/operator/SKILL.md`
Expected output: starts with `---` frontmatter, contains `name: operator` and `description:`.

- [ ] **Step 4: Commit**

```bash
git add claude/skills/operator/
git commit -m "feat(operator): scaffold skill directory and frontmatter"
```

---

## Task 2: Add the three reference templates

**Files:**
- Create: `claude/skills/operator/references/north-star-template.md`
- Create: `claude/skills/operator/references/project-card-template.md`
- Create: `claude/skills/operator/references/operator-repo-readme.md`
- Delete: `claude/skills/operator/references/.gitkeep`

- [ ] **Step 1: Write north-star template**

Write `claude/skills/operator/references/north-star-template.md`:

```markdown
---
name: <DOMAIN_SLUG>
created: <YYYY-MM-DD>
time-profile: anytime
---

## Mission

One or two sentences. The goal of this domain.

## Why this matters

The motivation. Future-you thanks present-you for capturing this.

## Success criteria

Concrete signals that you've achieved the mission.

## Out of scope

What this domain is NOT. Helps the planner refuse drift.

## Constraints

Time, budget, anything that bounds the domain.
```

The `time-profile` field accepts one of: `weekday-business-hours`, `evenings`, `weekends`, `weekends-and-evenings`, `anytime`.

- [ ] **Step 2: Write project-card template**

Write `claude/skills/operator/references/project-card-template.md`:

```markdown
---
name: <PROJECT_SLUG>
domain: <DOMAIN_SLUG>
status: starting
created: <YYYY-MM-DD>
last-touched: <YYYY-MM-DD>
repo:
context-state:
---

## North-star alignment

How this serves the domain's north-star.

## Next action

The next concrete step.

## Notes

Free-form context. Captured ideas, links, decisions.
```

The `status` field accepts one of: `starting`, `in-progress`, `blocked`, `paused`, `done`, `abandoned`.

- [ ] **Step 3: Write operator-repo README**

Write `claude/skills/operator/references/operator-repo-readme.md`:

````markdown
# Operator data repo

This is the private data store for the [`operator` Claude Code skill](https://github.com/<your-github-username>/dotfiles/tree/main/claude/skills/operator).

Do not edit files here directly unless you know what you're doing — the skill scaffolds and updates them. Direct edits to `agenda.md` will be overwritten by the next plan run.

## Layout

```
domains/<domain>/north-star.md     # the goal of this domain
domains/<domain>/projects/<slug>.md # active project cards
domains/<domain>/archive/<slug>.md  # closed project cards (done/abandoned)
inbox.md                           # raw idea captures awaiting triage
agenda.md                          # last planner output (overwritten each plan)
```

## Common operations (via Claude Code)

- Capture an idea: *"hey operator, weekend-business: idea — ..."*
- Plan today: *"hey operator, what should I work on?"*
- Status of a domain: *"hey operator, weekend-business status"*
- Triage inbox: *"hey operator, let's triage the inbox"*

See the skill source for the full intent list.
````

- [ ] **Step 4: Remove placeholder and commit**

```bash
rm claude/skills/operator/references/.gitkeep
git add claude/skills/operator/references/
git commit -m "feat(operator): add north-star, project-card, and repo-readme templates"
```

---

## Task 3: Implement the bootstrap flow

**Files:**
- Modify: `claude/skills/operator/SKILL.md` — add `## Bootstrap` section

- [ ] **Step 1: Append bootstrap section to SKILL.md**

Append to `claude/skills/operator/SKILL.md` (after the `## Intent dispatch` section):

````markdown
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
````

- [ ] **Step 2: Verify file structure**

Run: `grep -c '^## ' claude/skills/operator/SKILL.md`
Expected: at least 4 (Configuration, Data layout, Intent dispatch, Bootstrap).

- [ ] **Step 3: Commit**

```bash
git add claude/skills/operator/SKILL.md
git commit -m "feat(operator): add bootstrap flow with both flavors"
```

---

## Task 4: Implement intent (a) — capture an idea

**Files:**
- Modify: `claude/skills/operator/SKILL.md` — add `## Intent (a): capture` section

- [ ] **Step 1: Append capture intent section to SKILL.md**

Append to `claude/skills/operator/SKILL.md`:

````markdown
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
````

- [ ] **Step 2: Smoke-test plan (manual, after Task 14)**

This intent can't be run yet (the skill isn't symlinked into `~/.claude/skills/` and the data repo doesn't exist). Smoke test deferred to Task 14.

- [ ] **Step 3: Commit**

```bash
git add claude/skills/operator/SKILL.md
git commit -m "feat(operator): add capture intent (a)"
```

---

## Task 5: Implement intent (f) — create a new domain

**Files:**
- Modify: `claude/skills/operator/SKILL.md` — add `## Intent (f): new domain` section

We implement (f) before (d) because creating a project requires a domain to put it in.

- [ ] **Step 1: Append new-domain intent section to SKILL.md**

Append to `claude/skills/operator/SKILL.md`:

````markdown
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
````

- [ ] **Step 2: Commit**

```bash
git add claude/skills/operator/SKILL.md
git commit -m "feat(operator): add new-domain intent (f)"
```

---

## Task 6: Implement intent (d) — start a new project

**Files:**
- Modify: `claude/skills/operator/SKILL.md` — add `## Intent (d): new project` section

- [ ] **Step 1: Append new-project intent section to SKILL.md**

Append to `claude/skills/operator/SKILL.md`:

````markdown
## Intent (d): start a new project

**Trigger phrasing:** "new project", "started a new project", "create a project", "add a project".

Example invocations:
- *"hey operator, weekend-business: started a new project called gohighlevel-niche-templates, building per-vertical SaaS templates I can sell to leads."*
- *"hey operator, work: new project — migration-X"*

### Behavior

1. Run pull-on-read.
2. Parse from the prompt:
   - **domain** (required) — must match an existing directory under `$OPERATOR_REPO/domains/`. If missing or unrecognized, ask: *"Which domain? (existing: <list>)"*.
   - **project name / slug** (required) — slugs must be lowercase, hyphenated.
   - **gist** — any free-form text after the project name.
3. If `$OPERATOR_REPO/domains/<domain>/projects/<slug>.md` already exists, stop and tell the user.
4. Build a draft project card by reading `references/project-card-template.md` from this skill's directory and substituting:
   - `<PROJECT_SLUG>` → the slug
   - `<DOMAIN_SLUG>` → the domain
   - `<YYYY-MM-DD>` → today's date in both `created` and `last-touched`
5. If a gist was provided:
   - Place it under the `## Notes` section verbatim.
   - If the gist contains a clear next-step verb-phrase (e.g., starts with "build", "design", "research", "scrape", "draft"), copy that sentence to the `## Next action` section. Otherwise leave Next action empty.
6. **Show the draft to the user, ask "ship it?"**
7. On confirm:

   ```bash
   # Write the card
   git -C "$OPERATOR_REPO" add domains/<domain>/projects/<slug>.md
   git -C "$OPERATOR_REPO" commit -m "project: create <domain>/<slug>"
   git -C "$OPERATOR_REPO" push
   ```

8. Output: `Project '<slug>' created at domains/<domain>/projects/<slug>.md`.

### On reject

If the user rejects the draft, ask: *"Edit the draft inline, or discard?"*. On "edit," accept their corrections, re-show, and re-confirm. On "discard," do nothing — no file written.
````

- [ ] **Step 2: Commit**

```bash
git add claude/skills/operator/SKILL.md
git commit -m "feat(operator): add new-project intent (d)"
```

---

## Task 7: Implement intent (c) — show domain status

**Files:**
- Modify: `claude/skills/operator/SKILL.md` — add `## Intent (c): status` section

- [ ] **Step 1: Append status intent section to SKILL.md**

Append to `claude/skills/operator/SKILL.md`:

````markdown
## Intent (c): show domain status

**Trigger phrasing:** "status", "show me <domain> status", "how's <project>", "where am I on <project>".

Example invocations:
- *"hey operator, status"* — all domains, terse
- *"hey operator, show me weekend-business status"* — one domain, terse
- *"hey operator, status on mn-sos-scraper"* — one project, full card

### Behavior

1. Run pull-on-read.
2. Determine scope:
   - **Specific project name mentioned** (matches a slug under any `domains/*/projects/*.md`): print the full card content.
   - **Domain mentioned**: print terse summary for that domain only.
   - **Neither**: print terse summary across all domains.
3. **Terse format** — for each project (excluding archived), one line:

   ```
   <slug> · <status> · last touched <YYYY-MM-DD> · next: <next-action-or-empty>
   ```

   Group by domain with a heading: `## <domain>`.

4. **Project lookup** — when the user names a slug:
   - Use `find "$OPERATOR_REPO/domains" -path '*/projects/<slug>.md' -type f`.
   - If multiple matches (same slug in different domains), list them and ask which.
   - If no match, fuzzy-match against all project slugs and suggest closest.
5. No git changes (read-only intent).

### Output cap

If a domain has more than 12 active projects, show the 12 most recently touched and append `... and N more (run with --all to see all)`. (The user does not literally pass `--all`; they would say "show me all weekend-business projects" — at which point you uncap.)
````

- [ ] **Step 2: Commit**

```bash
git add claude/skills/operator/SKILL.md
git commit -m "feat(operator): add status intent (c)"
```

---

## Task 8: Implement intent (e) — close a project

**Files:**
- Modify: `claude/skills/operator/SKILL.md` — add `## Intent (e): close` section

- [ ] **Step 1: Append close intent section to SKILL.md**

Append to `claude/skills/operator/SKILL.md`:

````markdown
## Intent (e): close a project

**Trigger phrasing:** "is done", "is paused", "is blocked", "is abandoned", "mark as <status>", "pause <project>", "archive <project>".

Example invocations:
- *"hey operator, mn-sos-scraper is paused"*
- *"hey operator, gohighlevel-niche-templates is done"*
- *"hey operator, mark yelp-scraper as blocked"*

### Behavior

1. Run pull-on-read.
2. Parse: project slug (required), target status (required, one of `starting`, `in-progress`, `blocked`, `paused`, `done`, `abandoned`).
3. Locate the project file via `find` (same approach as intent c). If not found, fuzzy-match and suggest.
4. **For target status `paused` or `blocked`:** ask the user *"What would unblock this?"* — accept a one-line answer. Append it to the `## Notes` section as:

   ```
   - <YYYY-MM-DD> Paused/Blocked: <answer>
   ```

5. Update frontmatter via the Edit tool:
   - `status: <new-status>`
   - `last-touched: <today>`
6. **For target status `done` or `abandoned`:** move the file to `domains/<domain>/archive/<slug>.md`:

   ```bash
   git -C "$OPERATOR_REPO" mv domains/<domain>/projects/<slug>.md domains/<domain>/archive/<slug>.md
   ```

7. Commit and push:

   ```bash
   git -C "$OPERATOR_REPO" add -A
   git -C "$OPERATOR_REPO" commit -m "project: <slug> -> <status>"
   git -C "$OPERATOR_REPO" push
   ```

8. Output: `Project '<slug>' is now <status>` (and `(moved to archive)` if applicable).
````

- [ ] **Step 2: Commit**

```bash
git add claude/skills/operator/SKILL.md
git commit -m "feat(operator): add close-project intent (e)"
```

---

## Task 9: Implement intent (g) — edit/refine a north-star

**Files:**
- Modify: `claude/skills/operator/SKILL.md` — add `## Intent (g): edit north-star` section

- [ ] **Step 1: Append edit-north-star intent section to SKILL.md**

Append to `claude/skills/operator/SKILL.md`:

````markdown
## Intent (g): edit / refine a north-star

**Trigger phrasing:** "edit north-star", "refine north-star", "<domain> north-star: ...", "walk me through the <domain> north-star", "let's review <domain>".

### Two modes — picked from the prompt

#### Direct mode (default)

For small targeted edits, e.g.:

- *"hey operator, weekend-business north-star: add a constraint that we're MN-only for the first 90 days"*
- *"hey operator, work north-star, change the time-profile to evenings"*

Behavior:

1. Run pull-on-read.
2. Parse: target domain (required), edit instruction.
3. Read `$OPERATOR_REPO/domains/<domain>/north-star.md`.
4. Apply the edit using the Edit tool — interpret the instruction as: append (default for "add"), replace section (for "change <section>"), or update frontmatter field.
5. Show the diff with `git -C "$OPERATOR_REPO" diff -- domains/<domain>/north-star.md`.
6. Ask "ship it?"
7. On confirm, commit + push:

   ```bash
   git -C "$OPERATOR_REPO" add domains/<domain>/north-star.md
   git -C "$OPERATOR_REPO" commit -m "north-star: <domain> — <one-line summary of edit>"
   git -C "$OPERATOR_REPO" push
   ```

#### Walkthrough mode

Triggered by phrases: "walk me through", "refine", "let's review".

Walk each section in order: Mission → Why this matters → Success criteria → Out of scope → Constraints. For each:

1. Read the current section content aloud (echo it).
2. Ask: *"Keep, change, or replace? (Or 'skip' to leave as-is.)"*
3. On `change` or `replace`, accept the new content and apply via Edit tool.

After the last section, also ask: *"Update time-profile? (current: <value>)"*.

At the end of the walkthrough, run `git diff` to show all changes, ask "ship it?", and commit with a message like `north-star: <domain> — full refresh`.
````

- [ ] **Step 2: Commit**

```bash
git add claude/skills/operator/SKILL.md
git commit -m "feat(operator): add edit-north-star intent (g) with direct and walkthrough modes"
```

---

## Task 10: Build the `operator-planner` subagent

**Files:**
- Create: `claude/agents/operator-planner.md`

- [ ] **Step 1: Write the planner agent definition**

Write `claude/agents/operator-planner.md`:

````markdown
---
name: operator-planner
description: Read-only planner for the operator skill. Reads north-stars, project cards, inbox, and current time-of-week, then returns a ranked recommendation for what the user should work on. Output mode is one of stratified, focus, or list. Invoked exclusively by the operator skill.
tools: Read, Glob, Grep, Bash
model: sonnet
---

# Operator Planner

You are a focused subagent that reads the user's operator data repo and returns a recommendation for what to work on. You do not write files. You do not modify state. You read and reason.

## Inputs

The parent skill provides:

- `OPERATOR_REPO` — absolute path to the data repo (e.g., `/home/luna/projects/operator`)
- `mode` — one of `stratified`, `focus`, `list`
- `now` — ISO timestamp of the current local time (you may also call `date -Iseconds` yourself if not provided)

## What to read

1. `$OPERATOR_REPO/domains/*/north-star.md` — extract `time-profile` from frontmatter, plus Mission and Out-of-scope from body.
2. `$OPERATOR_REPO/domains/*/projects/*.md` (NOT `archive/*`) — extract `status`, `last-touched`, `next`, `notes`.
3. `$OPERATOR_REPO/inbox.md` — count items only (do not triage; that's a separate intent).
4. **Optionally** `$OPERATOR_REPO/domains/<d>/projects/<slug>.md` may have a `context-state` field pointing at an external CONTEXT_STATE.md. Best-effort: if the path exists and is readable, peek for `## Current Status` or similar headings to inform recency. If the read fails, skip silently.

## Time-profile matching

Match each domain's `time-profile` against `now`:

- `weekday-business-hours` — Monday through Friday, 09:00–17:00 local
- `evenings` — any day, 17:00–22:00 local
- `weekends` — Saturday or Sunday, all day
- `weekends-and-evenings` — Saturday or Sunday, OR weekday after 17:00
- `anytime` — always matches

A domain is **active** if its time-profile matches `now`. If NO domains are active under their declared profiles, fall back: treat all domains as active and note in the output: *"(no domains' time-profiles match the current time — showing all)"*.

## Output by mode

### `stratified` (default)

For each active domain, pick the top project (highest priority). Format:

```markdown
## <domain>

**<slug>** — <one-sentence reason this is the pick>
- Status: <status>
- Next: <next-action>
```

Repeat for each active domain.

### `focus`

Single recommendation across all active domains. Format:

```markdown
**<slug>** (<domain>)

<one-paragraph reason this beats every other live project>

Next: <next-action>
```

### `list`

One pick (same as focus), then a peripheral list of all other live projects across active domains, one line each:

```markdown
**Pick: <slug>** (<domain>) — <one-line reason>

Also live:
- <slug> (<domain>) · <status> · next: <next-action>
- <slug> (<domain>) · <status> · next: <next-action>
...
```

## Priority heuristic

When picking the top project for a domain (or the single focus pick):

1. Status `in-progress` outranks `starting` outranks `blocked`/`paused`.
2. Within the same status, prefer projects whose `## North-star alignment` content most directly serves the domain's Mission.
3. Tiebreak by recency (`last-touched`).
4. NEVER recommend `paused`, `blocked`, `done`, or `abandoned` projects unless every domain has only those.

## Inbox awareness

If `inbox.md` has more than 5 unactioned items, append a one-line note at the bottom of the output:

```
Inbox: <N> pending captures — consider triage.
```

Do not triage during planning.
````

- [ ] **Step 2: Verify file is well-formed**

Run: `head -10 claude/agents/operator-planner.md`
Expected: starts with `---` frontmatter containing `name: operator-planner`.

- [ ] **Step 3: Commit**

```bash
git add claude/agents/operator-planner.md
git commit -m "feat(operator): add operator-planner subagent"
```

---

## Task 11: Implement intent (b) — plan / "what should I work on?"

**Files:**
- Modify: `claude/skills/operator/SKILL.md` — add `## Intent (b): plan` section

- [ ] **Step 1: Append plan intent section to SKILL.md**

Append to `claude/skills/operator/SKILL.md`:

````markdown
## Intent (b): plan / "what should I work on?"

**Trigger phrasing:** "what should I work on", "what's next", "plan", "/standup", "what's on my plate".

Example invocations:
- *"hey operator, what should I work on?"* → stratified (default)
- *"hey operator, what's the one thing right now, max focus"* → focus
- *"hey operator, what's live across everything"* → list

### Behavior

1. Run pull-on-read.
2. Parse mode from prompt:
   - "max focus", "focus mode", "one thing", "the one thing" → `focus`
   - "list", "what's live", "give me a list", "everything" → `list`
   - default → `stratified`
3. Spawn the `operator-planner` subagent via the Agent tool. Pass:

   ```
   OPERATOR_REPO is set to <path>. Mode: <mode>. Current time: <ISO timestamp>.
   ```

   Tell the subagent to read the repo and return the recommendation in the requested mode's format.

4. Receive the subagent's markdown output.
5. Write the output to `$OPERATOR_REPO/agenda.md` with a frontmatter header:

   ```markdown
   ---
   generated: <ISO timestamp>
   mode: <mode>
   ---

   <subagent output>
   ```

6. Commit and push:

   ```bash
   git -C "$OPERATOR_REPO" add agenda.md
   git -C "$OPERATOR_REPO" commit -m "agenda: <mode> @ <YYYY-MM-DD HH:MM>"
   git -C "$OPERATOR_REPO" push
   ```

7. Display the subagent output to the user (the parent chat sees it).
````

- [ ] **Step 2: Commit**

```bash
git add claude/skills/operator/SKILL.md
git commit -m "feat(operator): add plan intent (b) with mode parsing"
```

---

## Task 12: Implement intent (h) — show today's agenda

**Files:**
- Modify: `claude/skills/operator/SKILL.md` — add `## Intent (h): agenda` section

- [ ] **Step 1: Append agenda intent section to SKILL.md**

Append to `claude/skills/operator/SKILL.md`:

````markdown
## Intent (h): show today's agenda

**Trigger phrasing:** "what's on the agenda", "show me the agenda", "agenda", "what did I plan".

### Behavior

1. Run pull-on-read.
2. Read `$OPERATOR_REPO/agenda.md`.
3. Parse the frontmatter for `generated` and `mode`. Compute age:

   ```bash
   generated_epoch=$(date -d "$generated" +%s)
   now_epoch=$(date +%s)
   age_seconds=$((now_epoch - generated_epoch))
   ```

4. Format age as a human-readable string: `<n>m ago` for < 60min, `<n>h ago` for < 24h, `<n>d ago` for >= 1 day.
5. Count pending inbox items: `grep -c '^- \[' "$OPERATOR_REPO/inbox.md" || echo 0`.
6. Print:

   ```
   Last planned: <YYYY-MM-DD HH:MM> (<age string>)
   Mode: <mode>
   Inbox: <N> pending captures

   <agenda body>
   ```

7. If `age_seconds > 43200` (12h), append the line: *"Agenda is from <age string> — run `/standup` again?"*.

8. No git changes — read-only intent.

### Edge cases

- **`agenda.md` missing or empty:** print *"No agenda yet — run `/standup` to generate one."* and stop.
- **Frontmatter unparseable:** print the file content unchanged with a warning header.
````

- [ ] **Step 2: Commit**

```bash
git add claude/skills/operator/SKILL.md
git commit -m "feat(operator): add agenda intent (h) with freshness header"
```

---

## Task 13: Build the `operator-triage` subagent

**Files:**
- Create: `claude/agents/operator-triage.md`

- [ ] **Step 1: Write the triage agent definition**

Write `claude/agents/operator-triage.md`:

````markdown
---
name: operator-triage
description: Read-only triage advisor for the operator skill. For each unactioned inbox item, suggests an action — trash, new project, append to existing project, or defer — with reasoning. Invoked exclusively by the operator skill.
tools: Read, Glob, Grep, Bash
model: sonnet
---

# Operator Triage Advisor

You are a focused subagent that reads inbox captures and existing project cards, then suggests a routing action for each captured item. You do not modify files. The parent skill performs writes after the user confirms each suggestion.

## Inputs

The parent skill provides:

- `OPERATOR_REPO` — absolute path to the data repo
- `target` — optional, either `all` (full triage) or a substring/id matching a specific inbox item

## What to read

1. `$OPERATOR_REPO/inbox.md` — extract all items as `(id, timestamp, domain-hint, text)`.
2. `$OPERATOR_REPO/domains/*/north-star.md` — Mission and Out-of-scope, for matching captures to domains.
3. `$OPERATOR_REPO/domains/*/projects/*.md` (NOT `archive/*`) — for matching captures to existing projects (compare capture text against project Mission/Notes).

## Output format

For each item to triage, output a block:

```markdown
### Item [<id>] — "<truncated text>"

**Suggested:** <one of: TRASH | NEW_PROJECT | APPEND | DEFER>

<short reasoning, 1-2 sentences>

<if NEW_PROJECT:>
- Domain: <domain>
- Proposed slug: <slug>
- Draft Notes: <copy of capture text>

<if APPEND:>
- Target project: domains/<domain>/projects/<slug>.md
- Match reason: <why this capture belongs in that project>
```

If `target=all`, output one block per item in inbox order.

If `target=<substring|id>`, find the matching item(s) and output blocks only for those.

## Suggestion rules

- **TRASH** — capture is a duplicate of an existing project's content, off-topic for any active domain, or trivial.
- **NEW_PROJECT** — capture describes a discrete deliverable, ≥ ~30 minutes of work, and either (a) names a new project explicitly or (b) doesn't fit any existing card.
- **APPEND** — capture is an idea, refinement, or reference clearly within scope of one existing project's Mission. State the matching project and why.
- **DEFER** — capture is too vague to act on, or might become a project later but needs more thought.

When in doubt between NEW_PROJECT and APPEND, prefer APPEND (don't proliferate cards).

## Important

You do NOT execute any of the suggested actions. You only suggest. The parent skill walks the user through your suggestions one-at-a-time and applies what the user confirms.
````

- [ ] **Step 2: Commit**

```bash
git add claude/agents/operator-triage.md
git commit -m "feat(operator): add operator-triage subagent"
```

---

## Task 14: Implement intent (i) — triage inbox

**Files:**
- Modify: `claude/skills/operator/SKILL.md` — add `## Intent (i): triage` section

- [ ] **Step 1: Append triage intent section to SKILL.md**

Append to `claude/skills/operator/SKILL.md`:

````markdown
## Intent (i): triage inbox

**Trigger phrasing:** "triage", "let's triage", "go through the inbox", "triage <item>".

### Two modes — picked from the prompt

- **Full** — *"hey operator, let's triage the inbox"* → walk all unactioned items.
- **Targeted** — *"hey operator, triage the yelp idea"* → pull just items whose text matches the substring "yelp".

### Behavior

1. Run pull-on-read.
2. Parse: `target` is either `all` or the substring/id from the prompt.
3. Spawn `operator-triage` subagent. Pass:

   ```
   OPERATOR_REPO is set to <path>. Target: <all|substring>.
   ```

4. Receive per-item suggestions.
5. **For each item**, present to the user:

   ```
   [<id>] "<text>"
   Suggested: <ACTION>
   <reasoning>

   Apply [y]es / [n]o / [e]dit / [s]kip?
   ```

   - `y` → apply the suggested action (see below)
   - `n` → ask the user which action they want instead, then apply
   - `e` → for NEW_PROJECT or APPEND, let the user edit the proposed slug or target project; then apply
   - `s` → leave in inbox (defer), move to next item

6. Apply actions:
   - **TRASH** — remove the line from `inbox.md`.
   - **NEW_PROJECT** — same flow as intent (d): build a draft card from `references/project-card-template.md`, populate from the capture, ask "ship it?", write file. Remove line from inbox.
   - **APPEND** — append the capture text as a `## Notes` bullet in the target project card, prefixed with the capture's date. Remove line from inbox. Update `last-touched` on the target card.
   - **DEFER / skip** — no change.

7. **One commit at the end** (not per item) summarizing actions:

   ```bash
   git -C "$OPERATOR_REPO" add -A
   git -C "$OPERATOR_REPO" commit -m "triage: <N> items — <N_new> new, <N_append> appended, <N_trash> trashed"
   git -C "$OPERATOR_REPO" push
   ```

8. If the user aborts mid-triage (Ctrl-C, or says "stop"), commit whatever was applied so far with a partial-triage message.

### Edge cases

- **Inbox empty:** print *"Inbox is empty — nothing to triage."* and stop.
- **Targeted match: no items:** print *"No inbox items match '<substring>'."* and stop.
- **Targeted match: multiple items:** list all matches with ids, ask the user to pick one or say "all of them".
````

- [ ] **Step 2: Commit**

```bash
git add claude/skills/operator/SKILL.md
git commit -m "feat(operator): add triage intent (i) with full and targeted modes"
```

---

## Task 15: Verify install and run end-to-end smoke test

**Files:**
- Read: `setup.sh` (no modifications expected; it auto-discovers from `claude/skills/` and `claude/agents/`)

- [ ] **Step 1: Confirm setup.sh picks up the new files**

Run:

```bash
grep -n 'SKILLS_SRC\|AGENTS_SRC' setup.sh | head
```

Expected: setup.sh references `claude/skills` and `claude/agents` directories — no per-skill allow-list needed.

- [ ] **Step 2: Re-run setup.sh against the user's `~/.claude` directory**

Run:

```bash
./setup.sh --dest "$HOME/.claude"
```

Expected: setup.sh prompts for link-vs-copy, then symlinks/copies `operator/` skill and `operator-planner.md`, `operator-triage.md` agents into `~/.claude/skills/` and `~/.claude/agents/` respectively.

- [ ] **Step 3: Verify the symlinks are in place**

Run:

```bash
ls -la ~/.claude/skills/operator/SKILL.md
ls -la ~/.claude/agents/operator-planner.md
ls -la ~/.claude/agents/operator-triage.md
```

Expected: all three files exist (symlinks pointing back to dotfiles, or copies, depending on chosen install type).

- [ ] **Step 4: Set OPERATOR_REPO env var**

Add to `~/.zshrc` (or whatever shell rc the user uses):

```bash
export OPERATOR_REPO="$HOME/projects/operator"
```

Then in the current shell:

```bash
export OPERATOR_REPO="$HOME/projects/operator"
```

- [ ] **Step 5: Smoke-test bootstrap (Flavor 1, brand new)**

Make sure `$OPERATOR_REPO` does NOT exist:

```bash
ls "$OPERATOR_REPO" 2>&1 | grep -q "No such" && echo "OK: missing" || echo "WARN: exists, delete first"
```

In a fresh Claude Code session in any directory, type:

```
hey operator, weekend-business: idea — test capture during bootstrap
```

Expected:
1. Skill detects missing repo.
2. Asks to confirm scaffold + GitHub repo creation.
3. On confirmation, creates local repo, runs `gh repo create`, pushes.
4. Asks if you want to create a first domain.
5. After domain creation, captures the test idea.

Verify: `~/projects/operator/` exists, has README.md/inbox.md/agenda.md/domains/, and the GitHub repo is visible at `https://github.com/<your-github-username>/operator`.

- [ ] **Step 6: Smoke-test each remaining intent**

In any Claude Code session:

| Intent | Test prompt | Expected |
|---|---|---|
| capture | *"hey operator, work: idea — try the new keyboard"* | new line in inbox.md |
| new-domain | *"hey operator, create a new domain called personal, time-profile anytime"* | `domains/personal/north-star.md` exists |
| new-project | *"hey operator, weekend-business: new project mn-sos-scraper, scrape the MN Secretary of State business registry"* | card exists with status `starting` |
| status | *"hey operator, weekend-business status"* | terse listing |
| status (project) | *"hey operator, status on mn-sos-scraper"* | full card content |
| close (paused) | *"hey operator, mn-sos-scraper is paused"* | prompts for unblock note, frontmatter updated |
| close (done) | *"hey operator, mn-sos-scraper is done"* | card moved to `archive/` |
| edit-north-star | *"hey operator, weekend-business north-star: add a constraint about MN-only first 90 days"* | diff shown, confirmed, committed |
| plan | *"hey operator, what should I work on?"* | stratified output, agenda.md updated |
| plan (focus) | *"hey operator, what's the one thing right now, max focus"* | focus output |
| agenda | *"hey operator, what's on the agenda?"* | last plan output + freshness header |
| triage | *"hey operator, let's triage the inbox"* | per-item walkthrough |

For each, verify the data repo state with `git -C "$OPERATOR_REPO" log --oneline -5` after.

- [ ] **Step 7: Smoke-test bootstrap Flavor 2 (clone-existing)**

Move the data repo aside:

```bash
mv "$OPERATOR_REPO" "${OPERATOR_REPO}.bak"
```

In a fresh Claude Code session:

```
hey operator, work status
```

Expected: skill detects missing repo, finds remote on GitHub, asks to clone, clones to `$OPERATOR_REPO`, then runs the status intent.

Cleanup after test:

```bash
rm -rf "${OPERATOR_REPO}.bak"
```

- [ ] **Step 8: Final commit if any tweaks were needed during smoke testing**

If smoke-testing turned up any wording / behavior bugs in the SKILL.md or agents, fix them now and commit:

```bash
git add claude/
git commit -m "fix(operator): smoke-test corrections"
```

---

## Out of plan (covered in spec §11 as future work)

- Session-start hook for auto-pull on every Claude session
- Inbox staleness warnings (> 30 days)
- Per-project time-profile overrides
- Calendar integration
- Structured CONTEXT_STATE handshake
- Automated test suite

These are explicitly deferred and not implemented in v1.
