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
