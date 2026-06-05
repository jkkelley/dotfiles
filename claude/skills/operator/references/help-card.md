# Operator — Help

## Intents

| Intent | What it does | Example |
|--------|-------------|---------|
| capture | Drop a thought to your inbox — no action taken, just saved | `"hey operator, work: idea — try LangGraph"` |
| plan | Ask what you should work on right now | `"hey operator, what should I work on"` |
| status | See project status across all domains or one project | `"hey operator, status on migration-X"` |
| new-project | Create a new project card under a domain | `"hey operator, work: new project — migration-X"` |
| close | Mark a project done, paused, blocked, or abandoned | `"hey operator, migration-X is done"` |
| new-domain | Create a new life domain (work, personal, etc.) | `"hey operator, new domain: consulting"` |
| north-star | Edit or walk through a domain's north-star | `"hey operator, work north-star: add constraint X"` |
| agenda | Show the last planned agenda for today | `"hey operator, agenda"` |
| triage | Work through inbox items one by one | `"hey operator, let's triage"` |
| backlog | Log a bug or task to a project's backlog | `"hey operator, yieldpoint-ai: backlog — timeout flicker"` |
| sessions | Log one or more Claude sessions for the day | `"hey operator, log my sessions"` |
| help | Show this reference card | `"hey operator, help"` |

## Intent Categories

| Category | What it captures |
|----------|-----------------|
| capture | Raw ideas, thoughts, and observations — unprocessed, inbox-only |
| plan / agenda | Work recommendations and scheduled priorities weighted by time-of-week |
| status | Snapshot of where projects stand — active, blocked, last touched |
| new-project / close | Lifecycle events — creating, pausing, finishing, or abandoning a project |
| new-domain / north-star | Domain setup and long-term direction — mission, goals, constraints |
| triage | Decisions on inbox items — trash, promote to project, append to existing |
| backlog | Bugs, tasks, and rough edges tied to a specific project |
| sessions | Claude session activity — when they ran, what they were, where they lived |
| help | Operator's own capabilities and usage reference |
