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
