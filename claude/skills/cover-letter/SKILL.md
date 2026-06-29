---
name: cover-letter
description: Build a one-page .docx cover letter for a specific job application. Ingests a job description, picks prose fragments from tone-keyed pools, drafts a "why this company" paragraph, runs a pre-build checklist for user approval, then builds and PRs the output. Output lands in applications/<date>_<company>_<role>/ inside the resume content repo.
---

# /cover-letter - Cover Letter Generator

Builds a tailored, one-page `.docx` cover letter from a job description.
The engine (this skill) is portable; the personal content lives in a separate private resume repo.
No personal data ever enters this skill.

## Prerequisites

- The resume content repo is present locally (contains `content/` with `profile.py`, `achievements.py`, `cover_letter.py`).
- This skill is installed: `~/.claude/skills/cover-letter/` symlinks to `~/dotfiles/claude/skills/cover-letter/`.
- `podman` is available (used to run the Python renderer in an isolated container).

## Locate the content repo

If the user is already inside a resume content repo (the cwd has `content/cover_letter.py`), use it.
Otherwise ask: "Where is your resume content repo?" and use that path.
Store it as `CONTENT_REPO` for the rest of the run.

## Phase B - Full per-application workflow

### Step 1 - Branch

Create a branch in the content repo named `letter/<company>-<role>-<date>` (lowercase, hyphens, no spaces).
Example: `letter/sample-co-devops-engineer-2026-06-29`

```bash
git -C "$CONTENT_REPO" checkout -b letter/<company>-<role>-<date>
```

### Step 2 - Intake the job description

Accept the JD in either form:

**Pasted inline:** ask "Please paste the job description" and read the text from the user's reply.

**File path:** if the user provides a path (or drops a file), read it directly.

Save the JD text to:

```
$CONTENT_REPO/applications/<date>_<company>_<role>/job_description.txt
```

Use `YYYY-MM-DD` for the date, lowercase snake_case for company and role.
Create the directory if it does not exist.

### Step 3 - Read the pools

Read `$CONTENT_REPO/content/cover_letter.py` to see what fragments are available.
Read `$CONTENT_REPO/content/achievements.py` to see the `FACT_*` constants (understand what the numbers mean).
Read `$CONTENT_REPO/applications/2026-06-29_sample-co_devops-engineer/selection.py` as a reference template.

### Step 4 - Hand-pick fragments

Based on the JD, select:

- **One opening** from the tone-matched pool (`OPENING_FORMAL`, `OPENING_DIRECT`, or `OPENING_WARM`).
  Pick the index whose framing best fits the JD (AWS-broad vs. K8s-forward vs. regulated-industry emphasis).
- **Two to three proof paragraphs** from `PROOF_POOL`.
  Match to the JD's emphasis: cost/governance, security/compliance, K8s platform, GitOps/CI-CD, observability, IaC.
  Cap at three paragraphs to preserve the one-page limit.
- **One closing** from the tone-matched pool (`CLOSING_FORMAL`, `CLOSING_DIRECT`, or `CLOSING_WARM`).

### Step 5 - Draft WHY_THIS_COMPANY

Write a short paragraph (3-5 sentences) explaining why this specific company and role, drawn from the JD.
Be specific: reference the company's product, domain, or environment.
This is the only non-deterministic slot.
No personal data, client names, or unverifiable metrics.

### Step 6 - Choose tone

If the user has not already specified a tone, ask:
"Which tone? formal / direct / warm"

- **formal** - traditional, respectful register; appropriate for enterprise or government contexts.
- **direct** - confident and concise; good for startups, fintech, or roles that value action over ceremony.
- **warm** - conversational and enthusiastic; good for mission-driven companies or smaller teams.

### Step 7 - Write selection.py

Create `$CONTENT_REPO/applications/<date>_<company>_<role>/selection.py` with:

```python
from content.cover_letter import (
    OPENING_<TONE>,
    PROOF_POOL,
    CLOSING_<TONE>,
)

LETTER_META = {
    'date':    '<Full date, e.g. June 29, 2026>',
    'company': '<Company Name>',
    'role':    '<Role Title>',
    'tone':    '<tone>',
}

OPENING = OPENING_<TONE>[<n>]  # <inline comment: what this opening is>

PROOFS = [
    PROOF_POOL[<n>],  # <inline comment>
    PROOF_POOL[<n>],  # <inline comment>
    PROOF_POOL[<n>],  # <inline comment>  (omit if only two)
]

WHY_THIS_COMPANY = (
    "<drafted paragraph>"
)

CLOSING = CLOSING_<TONE>[<n>]  # <inline comment>
```

### Step 8 - Pre-build checklist

Show the user:

```
Date:    <date>
Company: <company>
Role:    <role>
Tone:    <tone>
Opening: OPENING_<TONE>[<n>] - <comment>
Proofs:
  PROOF_POOL[<n>] - <comment>
  PROOF_POOL[<n>] - <comment>
  PROOF_POOL[<n>] - <comment>
Closing: CLOSING_<TONE>[<n>] - <comment>

WHY_THIS_COMPANY:
<the drafted paragraph>
```

Then check: does the role title in LETTER_META match `CURRENT_JOB_TITLE` in the content repo's `content/profile.py`?
If they do not match, flag it explicitly:
"Warning: role is '<role>' but CURRENT_JOB_TITLE is '<value>'. Proceed anyway, or update the title first?"
Wait for the user's answer before continuing.

Ask: **"Is this good?"**
Do not build until the user says yes (or equivalent: "go ahead", "looks good", "yes", "yep", "ship it").

### Step 9 - Build

```bash
podman run --rm \
  -v "$CONTENT_REPO/applications/<date>_<company>_<role>:/work" \
  -v "$HOME/.claude/skills/cover-letter/scripts:/scripts" \
  -v "$CONTENT_REPO/content:/content" \
  python:3.12-slim bash -c \
  "pip install python-docx -q && python3 /scripts/build_cover_letter.py"
```

Confirm the build exits 0 and the output file exists:

```
$CONTENT_REPO/applications/<date>_<company>_<role>/james_kelley_cover_letter.docx
```

### Step 10 - Verify

Open the `.docx` with python-docx (in-container or locally) and confirm:

- The first paragraph contains the name from `profile.py`.
- The contact line is present.
- The role and company appear in the body.

Optionally convert to PDF to confirm one-page (requires LibreOffice in-container):

```bash
podman run --rm \
  -v "$CONTENT_REPO/applications/<date>_<company>_<role>:/work" \
  ghcr.io/linuxserver/libreoffice:latest bash -c \
  "libreoffice --headless --convert-to pdf --outdir /work /work/james_kelley_cover_letter.docx"
```

### Step 11 - Commit and PR

Stage and commit the application folder:

```bash
git -C "$CONTENT_REPO" add applications/<date>_<company>_<role>/
git -C "$CONTENT_REPO" commit -m "feat: cover letter for <company> <role> (<date>)"
git -C "$CONTENT_REPO" push -u origin letter/<company>-<role>-<date>
```

Open a PR targeting `main`:

```bash
gh pr create \
  --repo <repo-handle> \
  --base main \
  --head letter/<company>-<role>-<date> \
  --title "Cover letter: <role> at <company> (<date>)" \
  --body "Application folder for <role> at <company>."
```

### Step 12 - Final report

Deliver to the user:

```
Built: applications/<date>_<company>_<role>/james_kelley_cover_letter.docx
Selection: applications/<date>_<company>_<role>/selection.py
PR: <PR URL>
```

## Adding new fragments to the pools

When the user asks to add a new opening, proof, or closing:

1. Open `$CONTENT_REPO/content/cover_letter.py`.
2. Append the new entry to the end of the relevant pool (pools are append-only).
3. Add an inline `# what it is` comment.
4. If the entry uses a specific number, reference a `FACT_*` constant from `achievements.py` - never hard-code a digit.
5. Commit the change to the current branch or to a new branch as appropriate.

## Constraints

- One page hard cap - no more than 3-4 paragraphs in the body.
  If a page-count check fails, remove the least relevant proof paragraph.
- No tables anywhere (ATS rule).
- No middle dots or diamond symbols - standard bullets and commas only.
- No client names (confidentiality).
- No unverifiable metrics.
- Work history covers Aug 2020 onward - do not reference earlier experience.
- No Pulumi references.
- Every number in prose must trace to a `FACT_*` constant.
