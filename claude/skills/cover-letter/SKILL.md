---
name: cover-letter
description: Build a one-page .docx cover letter for a specific job application. Ingests a job description, picks prose fragments from tone-keyed pools, drafts a "why this company" paragraph, runs a pre-build checklist for user approval, then builds and PRs the output. Output lands in applications/<date>_<company>_<role>/ inside this repo.
---

# /cover-letter - Cover Letter Generator

Builds a tailored, one-page `.docx` cover letter from a job description.
All personal content lives in this repo (`content/`, `applications/`).
The engine lives in `scripts/` alongside this file.

## Maintenance - mirroring to dotfiles

This skill is the source of truth.
The dotfiles repo at https://github.com/jkkelley/dotfiles mirrors it at
`claude/skills/cover-letter/` for portability to other machines.

**When this skill's scripts are updated:**
1. Make and test all changes here first.
2. Copy the updated files to dotfiles:
   ```bash
   cp .claude/skills/cover-letter/SKILL.md \
      .claude/skills/cover-letter/scripts/build_cover_letter.py \
      .claude/skills/cover-letter/scripts/docx_helpers.py \
      .claude/skills/cover-letter/scripts/requirements.txt \
      .claude/skills/cover-letter/scripts/test_design_system.py \
      ~/dotfiles/claude/skills/cover-letter/scripts/
   cp .claude/skills/cover-letter/SKILL.md \
      ~/dotfiles/claude/skills/cover-letter/SKILL.md
   ```
3. Commit and open a PR in dotfiles targeting `main`.

Never edit the dotfiles copy directly - changes made there will be overwritten.

## Prerequisites

- This skill is installed project-locally (already true if you are reading this).
- `podman` is available.
- The `content/` package is present in this repo.

## Phase B - Full per-application workflow

### Step 1 - Branch

Create a branch named `letter/<company>-<role>-<date>` (lowercase, hyphens, no spaces):

```bash
git checkout -b letter/<company>-<role>-<date>
```

### Step 2 - Intake the job description

Accept the JD in either form:

**Pasted inline:** ask "Please paste the job description" and read the text from the user's reply.

**File path:** if the user provides a path (or drops a file), read it directly.

Save the JD text to:
```
applications/<date>_<company>_<role>/job_description.txt
```

Use `YYYY-MM-DD` for the date, lowercase snake_case for company and role.
Create the directory if it does not exist.

### Step 3 - Read the pools

Read `content/cover_letter.py` to see available fragments.
Read `content/achievements.py` to understand the `FACT_*` constants (what the numbers mean).
Read `tests/sample-co_devops-engineer/selection.py` as a reference template.

### Step 4 - Hand-pick fragments

Based on the JD, select:

- **One opening** from the tone-matched pool (`OPENING_FORMAL`, `OPENING_DIRECT`, or `OPENING_WARM`).
  Pick the index whose framing best fits the JD (AWS-broad vs. K8s-forward).
- **Two to three proof paragraphs** from `PROOF_POOL`.
  Match to the JD's emphasis: cost/governance, security/compliance, K8s platform, GitOps/CI-CD, observability, IaC.
  Cap at three to preserve the one-page limit.
- **One closing** from the tone-matched pool (`CLOSING_FORMAL`, `CLOSING_DIRECT`, or `CLOSING_WARM`).

### Step 5 - Draft WHY_THIS_COMPANY

Write a short paragraph (3-5 sentences) explaining why this specific company and role, drawn from the JD.
Be specific: reference the company's product, domain, or environment.
This is the only non-deterministic slot.
No client names or unverifiable metrics.

### Step 6 - Choose tone

If the user has not already specified a tone, ask:
"Which tone? formal / direct / warm"

- **formal** - traditional, respectful register.
- **direct** - confident and concise; good for fintech/startups/regulated environments.
- **warm** - conversational and enthusiastic; good for mission-driven or smaller teams.

### Step 7 - Write selection.py

Create `applications/<date>_<company>_<role>/selection.py`:

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

OPENING = OPENING_<TONE>[<n>]  # <inline comment>

PROOFS = [
    PROOF_POOL[<n>],  # <inline comment>
    PROOF_POOL[<n>],  # <inline comment>
]

WHY_THIS_COMPANY = (
    "<drafted paragraph>"
)

CLOSING = CLOSING_<TONE>[<n>]  # <inline comment>
```

`OUTPUT_FILENAME` defaults to `james_kelley_cover_letter.docx` - omit it for real applications.
For test builds only, set `OUTPUT_FILENAME = 'TEST_james_kelley_cover_letter.docx'`.

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
Closing: CLOSING_<TONE>[<n>] - <comment>

WHY_THIS_COMPANY:
<the drafted paragraph>
```

Check: does the role title match `CURRENT_JOB_TITLE` in `content/profile.py`?
If they do not match, flag it:
"Warning: role is '<role>' but CURRENT_JOB_TITLE is '<value>'. Proceed anyway, or update the title first?"
Wait for the user's answer before continuing.

Ask: **"Is this good?"**
Do not build until the user confirms.

### Step 9 - Build

```bash
SKILL_DIR="$(pwd)/.claude/skills/cover-letter"
podman run --rm \
  -v "$(pwd)/applications/<date>_<company>_<role>:/work" \
  -v "$SKILL_DIR/scripts:/scripts" \
  -v "$(pwd)/content:/content" \
  python:3.12-slim bash -c \
  "pip install python-docx -q && python3 /scripts/build_cover_letter.py"
```

Confirm the build exits 0 and the output exists:
```
applications/<date>_<company>_<role>/james_kelley_cover_letter.docx
```

### Step 10 - Verify

Run the structure check in-container:
```bash
podman run --rm \
  -v "$(pwd)/applications/<date>_<company>_<role>:/work" \
  -v "$(pwd)/content:/content" \
  python:3.12-slim bash -c "pip install python-docx -q && python3 - <<'EOF'
import sys
sys.path.insert(0, '/')
from docx import Document
from content.profile import WHOS_RESUME_IS_THIS
d = Document('/work/james_kelley_cover_letter.docx')
text = '\n'.join(p.text for p in d.paragraphs)
assert WHOS_RESUME_IS_THIS in text, 'name missing'
assert 'Dear Hiring Team' in text, 'greeting missing'
assert 'Sincerely' in text, 'sign-off missing'
print('structure ok')
EOF"
```

### Step 11 - Commit and PR

```bash
git add applications/<date>_<company>_<role>/
git commit -m "feat: cover letter for <company> <role> (<date>)"
git push -u origin letter/<company>-<role>-<date>
gh pr create --base main \
  --title "Cover letter: <role> at <company> (<date>)" \
  --body "Application folder for <role> at <company>."
```

### Step 12 - Final report

Deliver to the user:

```
Built:     applications/<date>_<company>_<role>/james_kelley_cover_letter.docx
Selection: applications/<date>_<company>_<role>/selection.py
PR:        <PR URL>
```

## Adding new fragments to the pools

1. Open `content/cover_letter.py`.
2. Append to the end of the relevant pool (pools are append-only).
3. Add an inline `# what it is` comment.
4. If the entry uses a number, reference a `FACT_*` constant from `achievements.py` - never hard-code a digit.
5. After committing, copy updated `SKILL.md` and `scripts/` to dotfiles and open a dotfiles PR (see Maintenance above).

## Constraints

- One page hard cap - no more than 3-4 body paragraphs.
- No tables anywhere (ATS rule).
- No middle dots or diamond symbols - standard bullets and commas only.
- No client names (confidentiality).
- No unverifiable metrics.
- Work history covers Aug 2020 onward.
- No Pulumi references.
- Every number in prose must trace to a `FACT_*` constant.
