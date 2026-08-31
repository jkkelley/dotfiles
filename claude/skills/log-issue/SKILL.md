---
name: log-issue
description: Append one or more issue/fix entries to the project issue log in ~/projects/knowledge-base. Use when the user says "add to the issue log", "log this issue/fix", "add these issues", or similar. Never read the full issue log file — only append to the top.
version: 1.0.3
---

# Issue Log Skill

Appends new issue entries to the monthly issue log file in `~/projects/knowledge-base`.

## Directory Structure

```
~/projects/knowledge-base/docs/projects/<project>/issues/
  YYYY/
    MM/
      YYYYMMDD_ISSUE_LOG.md   ← one file per day (YYYYMMDD = today's date, never reuse a prior day's file)
```

## Steps

1. **Resolve today's date** — get `YYYY`, `MM`, `YYYYMMDD`

2. **Identify the project** — infer from context or ask. Common values: `prospector`.

3. **Find or create today's file:**
   ```bash
   TARGET_DIR=~/projects/knowledge-base/docs/projects/<project>/issues/YYYY/MM
   TARGET_FILE=$TARGET_DIR/YYYYMMDD_ISSUE_LOG.md
   ```
   - If the directory does not exist: `mkdir -p $TARGET_DIR`, then create `TARGET_FILE`
   - If the directory exists and `YYYYMMDD_ISSUE_LOG.md` (today's date) already exists: use it
   - If the directory exists but has no file matching today's date: create `TARGET_FILE` with the header — even if older files from the same month exist. **Never reuse a file from a previous day.**

4. **Determine the next ISSUE number** — grep across all existing issue files to find the highest current number, then increment:
   ```bash
   grep -roh 'ISSUE-[0-9]\+' ~/projects/knowledge-base/docs/projects/<project>/issues/ \
     | grep -o '[0-9]\+' | sort -n | tail -1
   ```
   If no files exist yet, start at 001.

5. **Prepend each new entry** to the top of the file (below the `# Issue & Resolution Log` header if present), so the file stays newest-first.

6. **Commit and push** to `knowledge-base` main:
   ```
   docs: log issue(s) ISSUE-XXX [through ISSUE-YYY] for <project>
   ```

## Entry Format

```markdown
## [ISSUE-NNN] - Brief descriptive title
**Date:** YYYY-MM-DD
**Status:** RESOLVED | OPEN
**Severity:** High | Medium | Low

### Problem
Concise description of the technical issue. What broke, what was observed.

### Fix
* Bulleted list of technical steps taken.
* Reference specific files, functions, or commands where relevant.

**Result:** One sentence on the outcome.

**Rule:** (optional) A generalizable takeaway for future Claudes.

---
```

## Rules

- **Never read the full file** — only prepend. Files grow to thousands of lines.
- One entry per distinct issue/fix. Batch multiple issues in one commit.
- The file header `# Issue & Resolution Log — <Project> — Month YYYY` goes on line 1 if creating a new file.
- If creating a new monthly directory for a new project: also create the scaffold directories `YYYY/MM/` and a `YYYYMMDD_ISSUE_LOG.md` with just the header.
- Always commit and push after writing.

## New Project Bootstrap

When adding issue logging for a project that has no existing scaffold:

```bash
mkdir -p ~/projects/knowledge-base/docs/projects/<project>/issues/YYYY/MM
```

Then create `YYYYMMDD_ISSUE_LOG.md` with the header and first entry. No other files needed — the monthly files are self-contained.
