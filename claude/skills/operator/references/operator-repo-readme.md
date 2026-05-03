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
