# Dotfiles — Agent Orientation

This repository is **public and intended to be shared**. The agents, skills, and configurations here are designed to be consumed by anyone. That means every file must be safe to read by the general public at all times.

## PII & PHI Policy — Strictly Enforced

**Never commit personally identifiable information (PII) or protected health information (PHI) to this repository.**

This includes but is not limited to:

| Category | Examples |
|----------|---------|
| Real names | Your full name, usernames tied to your identity |
| Account handles | GitHub usernames, email addresses, social handles |
| Internal hostnames | `myname.homelab.local`, node names tied to a real network |
| IP addresses | Any private or public IP specific to your infrastructure |
| Registry paths | `ghcr.io/<your-username>/...`, DockerHub org names |
| Repository URLs | Any URL containing a real GitHub username or org |
| Credentials | Tokens, passwords, API keys, secrets — in any form |
| PHI | Any health, medical, or patient-related data |

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

"MVP" means: it does *one* thing end-to-end, even if narrowly. A polished
v2 can land in a follow-up PR. What's not allowed is leaving a half-built
agent on a feature branch indefinitely.
