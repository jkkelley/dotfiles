# Operator — Personal Work-Steering System

**Status:** Draft
**Date:** 2026-05-02
**Scope:** Single design, single implementation plan.

## 1. Problem

The user is juggling multiple parallel projects across distinct life domains: a day job, a "weekend business" focused on selling SaaS templates (GoHighLevel niche templates) to local businesses, plus personal items. The supporting infrastructure — homelab, k8s, Jenkins, ArgoCD, scrapers, agents — exists in service of that weekend-business north-star: get business contact data from the web (name, phone, website, type) so the user can call those businesses directly and sell templates.

Three pain points hurt most:

- **Losing ideas overnight.** A great thought at 11pm is gone by 8am.
- **Working on the wrong thing.** Time spent on rabbit holes when the north-star — generating sales leads — gets neglected.
- **Cold-start cost.** Returning to a project after a few days takes ~20 minutes of reorientation.

The user has the tools (skills, agents, infra). What's missing is a steering layer that helps them remember, prioritize, and reorient.

## 2. North star (for this design)

A single `operator` skill, available in every Claude Code session everywhere, that:

1. Captures fleeting ideas in seconds, with no follow-up friction
2. Tracks active projects across multiple life domains
3. Recommends what to work on, weighted by current time-of-week against per-domain time profiles
4. Survives across machines via a private GitHub repo as the source of truth

## 3. Out of scope (explicitly)

- The actual lead-generation scrapers (MN Secretary of State, Yelp, etc.) — those become *projects managed by* operator, not part of operator
- CRM / marketing-history tracking ("who have I called?") — separate project
- The GoHighLevel template-building work itself
- Web UI; this is a Claude Code skill only
- Notifications, daemons, cron — all interactions are pull-based via skill invocation
- Automated test suite — manual smoke tests only for v1

## 4. Architecture

### 4.1 Two-repo split

- **Public (this dotfiles repo):** Skill source code, subagent definitions. Generic — no PII.
- **Private (`<your-github-username>/operator`):** The data — north-stars, project cards, inbox, agenda. Cloned to `~/projects/operator/` by default.

### 4.2 Distribution

- Skill at `dotfiles/claude/skills/operator/SKILL.md`, symlinked to `~/.claude/skills/operator/` by `setup.sh`
- Subagents at `dotfiles/claude/agents/operator-planner.md` and `dotfiles/claude/agents/operator-triage.md`, symlinked to `~/.claude/agents/`
- User-level installation = available in every Claude Code session, every directory, every machine after `setup.sh`

### 4.3 Configuration

- `OPERATOR_REPO` environment variable, default `~/projects/operator`. Set in shell rc.
- Skill detects missing repo and runs bootstrap flow (§6.1).

### 4.4 Sync model

- **Pull-on-read** — before any read intent (plan, status, agenda, triage), `git pull --rebase` first.
- **Push-on-write** — after any write intent (capture, new-project, archive, edit-north-star, new-domain), commit + push immediately.
- **Failure modes:**
  - Pull fails (offline, conflict): warn user, continue with local state, do not auto-resolve.
  - Push fails (network, auth): commit locally, warn user with instructions to retry manually.

## 5. Data model

### 5.1 Repo layout

```
~/projects/operator/
├── README.md
├── domains/
│   ├── work/
│   │   ├── north-star.md
│   │   ├── projects/
│   │   │   └── <slug>.md
│   │   └── archive/
│   │       └── <slug>.md
│   ├── weekend-business/
│   │   ├── north-star.md
│   │   ├── projects/
│   │   └── archive/
│   └── personal/
│       ├── north-star.md
│       ├── projects/
│       └── archive/
├── inbox.md
└── agenda.md
```

### 5.2 North-star template

`domains/<domain>/north-star.md`:

```markdown
---
name: <domain-slug>
created: YYYY-MM-DD
time-profile: weekday-business-hours | evenings | weekends | weekends-and-evenings | anytime
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

### 5.3 Project card template

`domains/<domain>/projects/<slug>.md`:

```markdown
---
name: <slug>
domain: <domain-slug>
status: starting | in-progress | blocked | paused | done | abandoned
created: YYYY-MM-DD
last-touched: YYYY-MM-DD
repo: <path-to-project-repo>            # optional
context-state: <path>/CONTEXT_STATE.md  # optional
---

## North-star alignment
How this serves the domain's north-star.

## Next action
The next concrete step.

## Notes
Free-form context. Captured ideas, links, decisions.
```

### 5.4 Inbox format

`inbox.md`:

```markdown
# Inbox

- [<id>] 2026-05-02 11:42 :: <raw text>
- [<id>] 2026-05-02 12:08 :: <raw text>
```

`<id>` is a 6-character hash of `timestamp + content`, stable for referencing during triage.

### 5.5 Agenda format

`agenda.md` is overwritten by the planner subagent on every plan run:

```markdown
---
generated: 2026-05-02 07:14
mode: stratified  # or focus, list
---

[planner output]
```

## 6. Intents

The operator skill is invoked in natural language. From each prompt it parses two things:
- **Domain hint** — `work`, `weekend-business`, `personal`, or any custom domain
- **Intent** — one of the 10 below

The skill description (§8) provides examples broad enough that Claude reliably invokes the skill on phrases like *"hey operator,"* *"btw operator,"* and *"operator: ..."*.

### 6.1 Bootstrap (implicit, fires when `$OPERATOR_REPO` doesn't exist)

When the skill runs and the data repo is missing locally, before performing the requested intent:

1. Run `gh repo view <your-github-username>/operator` to detect remote state.
2. **Remote exists** (new machine, existing repo): prompt user, then `gh repo clone <your-github-username>/operator $OPERATOR_REPO`. Resume original intent.
3. **Remote does not exist** (brand new): scaffold locally — `mkdir -p $OPERATOR_REPO`, `git init`, write `README.md`, write empty `inbox.md`, write empty `agenda.md`, create empty `domains/`. Then `gh repo create <your-github-username>/operator --private`, set remote, push initial commit. Prompt user to create their first domain (chains into intent f).

The trigger is implicit — first-run does not require knowing a magic command.

### 6.2 Capture an idea (a)

Example: *"hey operator, weekend-business: idea — scrape Yelp business reviews for restaurant niches"*

- Parse domain hint (if any) and raw text.
- Append to `inbox.md` with timestamp + 6-char id.
- **No follow-up questions.** Capture friction is the enemy of capture.
- Commit + push.
- Output: `Captured to inbox: [<id>] <text>`

### 6.3 Plan / "what should I work on?" (b)

Example: *"hey operator, what should I work on right now?"*

- Pull.
- Spawn `operator-planner` subagent.
- Subagent reads:
  - All `domains/*/north-star.md`
  - All `domains/*/projects/*.md` (excluding `archive/`)
  - `inbox.md` (count + topical scan, not full triage)
  - Optionally: linked CONTEXT_STATE files (best-effort, skip on read failure)
  - Current time vs each domain's `time-profile`
- Subagent returns recommendation in the requested mode:
  - **stratified** (default): top pick per active domain — one recommendation per domain whose `time-profile` matches the current time (treating `anytime` as always matching). If no domains match, fall back to picking from all domains regardless of profile and note the fallback in the output.
  - **focus**: single next action with a short reason; nothing else
  - **list**: one pick + peripheral list of other live projects, one line each
- Mode parsed from prompt phrasing — *"max focus" / "focus mode"* → focus, *"give me a list" / "what's live"* → list, default → stratified.
- Time-profile-to-clock matching is the planner's responsibility; e.g., `weekday-business-hours` matches Mon–Fri 9–17 local time, `weekends-and-evenings` matches Sat/Sun all day plus weekday after 17, etc. Planner uses sensible defaults; user can override matching rules in the future (out of scope for v1).
- Output is written to `agenda.md` with mode + timestamp, committed + pushed.
- Output is also returned to the user in chat.

### 6.4 Show domain status (c)

Examples:
- *"hey operator, show me weekend-business status"* (one domain)
- *"hey operator, status"* (all domains)
- *"hey operator, status on mn-sos-scraper"* (single project, full card)

- Pull.
- Read project cards in scope.
- **All-domains or one-domain:** terse one-line-per-project format: `<slug> · <status> · last touched <date> · next: <next-action>`
- **Single project (by name):** print full card content.
- Done in the parent skill — no subagent needed (file-read + format only).

### 6.5 Start a new project (d)

Example: *"hey operator, weekend-business: started a new project called gohighlevel-niche-templates, building per-vertical SaaS templates I can sell to leads."*

- Required: project name (parsed), domain (parsed or asked). All other fields best-effort.
- Scaffold a draft card from the template, pre-filling `Notes` with the gist text. If the gist contains a clear next-step verb-phrase, infer `Next action`.
- **Scaffold-and-confirm:** show the draft, ask "ship it?"
- On confirm: write to `domains/<domain>/projects/<slug>.md`, commit + push.
- On reject: discard or open for inline edits.

### 6.6 Close a project (e)

Examples: *"hey operator, mn-sos-scraper is paused"* / *"hey operator, gohighlevel-niche-templates is done"*

- Parse: project slug, target status.
- Update `status` and `last-touched` frontmatter.
- **Done / abandoned:** move card from `domains/<d>/projects/` to `domains/<d>/archive/`.
- **Paused / blocked:** ask one-line *"What would unblock this?"*, append answer to Notes section. (Captures cold-start context for future-you.)
- **Starting / in-progress:** flip the flag, no prompt.
- Commit + push.

### 6.7 Create a new domain (f)

Example: *"hey operator, create a new domain called consulting"*

- Required: domain slug. Optional: one-line mission and time-profile.
- Scaffold draft `north-star.md` with template (mission populated if given, time-profile asked if not specified).
- **Scaffold-and-confirm:** show the draft, ask "ship it?"
- On confirm: create `domains/<slug>/{north-star.md, projects/, archive/}`, commit + push.

### 6.8 Edit / refine a north-star (g)

Two modes, picked from prompt phrasing:

**Direct mode** (default) — small targeted edit:
- Example: *"hey operator, weekend-business north-star: add a constraint that we're MN-only for the first 90 days"*
- Parse target north-star + edit instruction.
- Apply via Edit tool, show diff, ask confirm.
- Commit + push on confirm.

**Walkthrough mode** — triggered by *"refine"*, *"walk me through"*, *"let's review"*:
- Walk each section in order: Mission → Why → Success Criteria → Out of Scope → Constraints.
- For each: *"keep / change / replace?"*
- One commit at the end with all changes.

### 6.9 Show today's agenda (h)

Example: *"hey operator, what's on the agenda?"*

- Pull.
- Read `agenda.md`.
- Print header: timestamp of last planner run, age (e.g., "3h ago"), pending inbox count.
- Print agenda content unchanged.
- If last planner run > 12 hours ago, print nudge: *"agenda is from <duration> ago — run /standup again?"*
- No git changes (read-only).
- `agenda.md` is **planner-authored only.** Not user-editable. Editing-by-hand is discouraged because it splits the source of truth — to add an item, capture it to inbox or create a project, then re-run the planner.

### 6.10 Triage inbox (i)

Two modes, picked from prompt phrasing:

**Full walkthrough** — *"hey operator, let's triage the inbox"*:
- Walk through all inbox items one at a time.

**Targeted** — *"hey operator, triage the yelp idea"*:
- Pull just the matching item by partial text match against inbox content.
- If multiple match, list with ids and ask user to pick.

For both modes:
- Pull.
- Spawn `operator-triage` subagent.
- Subagent reads `inbox.md` and all project cards.
- For each item, suggests an action with reasoning, picking from:
  - **Trash** — discard
  - **New project** — scaffold a card in domain X with proposed slug
  - **Append** — add as a note to existing project Y (with rationale for the match)
  - **Defer** — leave in inbox
- User picks/overrides each suggestion. Subagent applies (parent skill performs writes).
- Items are removed from `inbox.md` when actioned. Deferred items stay.
- One commit at end of triage session, push.

## 7. Subagents

### 7.1 `operator-planner`

- **Purpose:** Read repo state, output a ranked recommendation in the requested mode.
- **Inputs:** `OPERATOR_REPO` path; requested mode (stratified | focus | list); current ISO timestamp.
- **Outputs:** Markdown recommendation following the requested mode's structure.
- **Tools:** Read, Glob, Grep (read-only). No Edit/Write — agenda writing is done by parent skill from the subagent's returned text.
- **Why a subagent:** Crosses many files; produces focused output. Subagent isolation keeps the main session's context clean.

### 7.2 `operator-triage`

- **Purpose:** For each inbox item, suggest a routing action with reasoning.
- **Inputs:** `OPERATOR_REPO` path; optional target item id or partial text.
- **Outputs:** Per-item suggestion (trash | new-project + proposed slug + draft card | append + target project + rationale | defer) with reasoning.
- **Tools:** Read, Glob, Grep (read-only). All file mutations done by parent skill after user confirms each action.
- **Why a subagent:** Same as planner — needs to read across all project cards.

## 8. Skill metadata

The `SKILL.md` description must trigger reliably on the user's natural phrasing while avoiding false positives.

**Strong triggers** (the skill should fire):
- "hey operator, ..."
- "btw operator, ..."
- "operator: ..."
- "/operator ..." (slash-style)

**Weaker triggers** (skill may fire if no other skill matches):
- "what should I work on?" / "what's on my plate?"
- "capture this idea" / "add to my inbox"
- "show me my projects"

**Anti-triggers** (skill should NOT fire):
- "kubernetes operator" / "k8s operator"
- Mathematical or programming uses of "operator"
- Code containing the literal string `operator` as an identifier

The description should explicitly mention this is a personal work-steering tool, not a generic word-match.

## 9. Error handling

| Condition | Behavior |
|---|---|
| Repo missing locally | Trigger bootstrap (§6.1) before resuming intent |
| `git pull` conflict or offline | Warn user, continue with local state, do not auto-resolve |
| `git push` failure | Commit locally, warn with retry instructions |
| Domain doesn't exist | Suggest closest match; ask to confirm or create |
| Project slug doesn't exist | Fuzzy-match against existing slugs in domain; suggest |
| Multiple inbox items match triage target | List matches with ids; ask user to disambiguate |
| `gh` CLI not authenticated (during bootstrap) | Print clear instructions to run `gh auth login`, then retry |
| `OPERATOR_REPO` set but path doesn't exist | Treat as missing repo; trigger bootstrap |

## 10. Testing strategy

This is a personal Claude Code skill, not a deployed service. Validation is manual:

- **Smoke test for each intent** after implementation: capture, plan (3 modes), status (3 scopes), new-project, close (3 status transitions), new-domain, edit-north-star (both modes), agenda, triage (both modes), bootstrap (both flavors).
- **Bootstrap validated on a clean machine** (or by temporarily renaming `$OPERATOR_REPO` and re-invoking).
- **Pull-on-read / push-on-write validated** by editing the GitHub repo directly between intent invocations and confirming the next read picks up the change.

No automated test suite. The skill is small enough that manual smoke testing is faster than building harness infrastructure.

## 11. Open questions / future work

- **Multi-machine drift:** If you work on machine A and don't push (because you only ran read intents), then start on machine B, you'll diverge. Pull-on-read mitigates but doesn't eliminate. Future enhancement: a session-start hook that pulls.
- **Inbox staleness:** Items deferred forever stay forever. Future: a "stale capture" warning when triaging items > 30 days old.
- **Time-profile granularity:** What if you work the side-business during weekday lunch? `time-profile` may need per-project overrides, not just per-domain. Defer until pain shows up.
- **Calendar integration:** Pulling work hours from Google Calendar to refine time-profile could be added later.
- **CONTEXT_STATE awareness:** The planner peeks at linked CONTEXT_STATE.md files best-effort. A more structured handshake (e.g., a manifest in each project repo) might emerge if this becomes flaky.
