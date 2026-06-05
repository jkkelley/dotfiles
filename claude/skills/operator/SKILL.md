---
name: operator
description: Personal work-steering system. Captures ideas to a private inbox, tracks projects across multiple life domains (work, weekend-business, personal, etc.), and recommends what to work on weighted by time-of-week. Triggered by phrases like "hey operator", "btw operator", "operator:". Backed by a private git repo at $OPERATOR_REPO (default ~/projects/operator). NOT for kubernetes operators, mathematical operators, or any code-level use of the word "operator".
---

# Operator — Personal Work-Steering System

This skill is a single named entry point. The user invokes it in natural language and it parses two things from the prompt:

- **Domain hint** — `work`, `weekend-business`, `personal`, or any custom domain the user has created. Hint may be absent (some intents work without one).
- **Intent** — one of the 12 intents documented below.

The skill operates against a private data repo at `$OPERATOR_REPO` (default `~/projects/operator`). It does NOT operate on the current working directory.

## Configuration

- Read `$OPERATOR_REPO` from the environment. If unset, default to `~/projects/operator` (expand `~`).
- The data repo is git-tracked with a remote on GitHub (private). Sync rules:
  - **Pull-on-read:** before any read intent (plan, status, agenda, triage), run `git -C "$OPERATOR_REPO" pull --rebase`. On conflict or network failure, warn the user but continue with local state.
  - **Push-on-write:** after any write intent (capture, new-project, close, edit-north-star, new-domain, backlog, sessions), commit and `git -C "$OPERATOR_REPO" push`. On push failure, commit locally and tell the user to retry.
- If `$OPERATOR_REPO` does not exist on disk, run the **Bootstrap** flow before performing the requested intent (see below).

## Data layout

```
$OPERATOR_REPO/
├── README.md
├── HELP_README.md
├── claude-sessions/
│   └── YYYY/
│       └── MM/
│           └── DD-claude-sessions.md
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

Intents documented below: (a) capture, (b) plan, (c) status, (d) new-project, (e) close, (f) new-domain, (g) edit north-star, (h) agenda, (i) triage, (j) backlog, (k) sessions, help. Bootstrap is implicit and runs before any of these on first use.

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

---

## Intent (j): log a backlog item

**Trigger phrasing:** "backlog", "add to backlog", "log a backlog item", "backlog item", "add this to the backlog".

Example invocations:
- *"hey operator, yieldpoint-ai: backlog — timeout UI flicker"*
- *"hey operator, add this to the yieldpoint-ai backlog"*

### Behavior

1. Run pull-on-read.
2. Parse domain hint. Check that `$OPERATOR_REPO/domains/<domain>/backlog/` exists. If not, tell the user and stop.
3. Ask the following questions **one at a time** — wait for the answer before asking the next:
   - *"What's the problem?"*
   - *"What area? (frontend / infra / backend / content)"*
   - *"Proposed fix? ('Unknown' is fine)"*
   - *"Any extra notes? (or 'skip' to leave blank)"*
   - *"Severity? (Low / Medium / High / Critical)"*
4. Generate a slug from the problem text: lowercase, hyphenated, max 5 words.
5. Get today's date: `date +%Y%m%d` for filename, `date -I` for frontmatter.
6. Read the template from `references/backlog-item-template.md` and substitute all placeholders.
   - If user said "skip" for notes, replace `<NOTES>` with `_none_`.
7. Write `$OPERATOR_REPO/domains/<domain>/backlog/YYYYMMDD_<slug>.md` with the populated template.
8. Append a row to `$OPERATOR_REPO/domains/<domain>/backlog/BACKLOG.md`:
   ```
   | YYYYMMDD | [<slug>](YYYYMMDD_<slug>.md) | <Severity> | open |
   ```
9. Commit and push:
   ```bash
   git -C "$OPERATOR_REPO" add domains/<domain>/backlog/
   git -C "$OPERATOR_REPO" commit -m "backlog: <domain>/<slug> [<Severity>]"
   git -C "$OPERATOR_REPO" push
   ```
10. Output: `Backlog item logged: YYYYMMDD_<slug>.md [<Severity>]`

---

## Skill Update Convention

When a new intent is added to the operator skill:

1. Update `claude/skills/operator/references/help-card.md` with the new intent row in both the Intents table and the Intent Categories table.
2. Update `SKILL.md` with the new intent behavior section.
3. Update the intent dispatch list in the `## Intent dispatch` section of `SKILL.md`.
4. Write the updated `references/help-card.md` content to `$OPERATOR_REPO/HELP_README.md`.
5. Commit + push the operator repo: `"help: add <intent-name> intent"`
6. Announce to the user:
   ```
   New capability added: <intent-name>
   <one-line description>
   Try it: "<example trigger phrase>"
   ```

---

## Homelab K8s Project Context

When planning or estimating work on homelab Kubernetes projects, factor in the mandatory AVP + ESO infrastructure pattern:

- Every new app that deploys to the cluster needs ~0.5–1 session of infrastructure wiring **before** the app runs
- AVP (ArgoCD Vault Plugin): resolves all config values from Vault placeholders at sync time
- ESO (External Secrets Operator): materializes runtime secrets as k8s Secrets
- `imageTag` in values.yaml is the ONE literal value — everything else is a Vault placeholder
- ArgoCD Applications use `plugin: argocd-vault-plugin` source, never `helm:` source
- ghcr-pull-secret comes from Vault-backed ESO — factor this into new app setup time

When triaging or estimating a new homelab K8s app project, flag this as non-negotiable infrastructure cost.
