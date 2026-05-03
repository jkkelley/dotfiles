---
name: jenkins-job-bootstrap
description: Use when adding a new GitHub repo to homelab Jenkins and you don't want to click through the multibranch-job creation UI. Generates a Job DSL seed that creates/syncs all multibranch pipeline jobs from a YAML manifest committed to jenkins-shared-lib.
---

# Jenkins Job Bootstrap

## Overview

Replace manual "New Item → Multibranch Pipeline → fill 12 fields → Save" with a one-line edit to a YAML manifest + a single seed-job build. The seed reads `jobs/repos.yaml` from `jenkins-shared-lib`, iterates the entries, and emits a `multibranchPipelineJob {}` block per repo. Re-runnable, idempotent, GitOps-style.

This is a homelab Jenkins skill — assumes a Jenkins controller reachable at `<jenkins-host>`, the `jenkins-shared-lib` Groovy library, and a GitHub user/org that owns the tracked repos.

## When to use

- Adding a new GitHub repo whose pipeline should run in this Jenkins
- Renaming or removing a tracked repo (edit `repos.yaml`, re-run seed)
- Standing up homelab Jenkins from scratch on a new node (run seed once, all jobs return)
- Auditing what jobs *should* exist vs. what does (read `repos.yaml`)

**Don't use for:** one-off freestyle jobs, scripted pipelines, parameterized builds, jobs needing custom credentials per-repo (the manifest covers those — but if you're configuring something exotic, just use the UI).

## Prerequisites (one-time)

1. **Plugin installed:** `job-dsl` plugin (downloaded → enabled in `https://<jenkins-host>/manage/pluginManager/installed`). No restart needed.
2. **Branch Source credential exists** in Jenkins. Two options:
   - **Reuse `github-pat`** if it's "Username with password" type (check at `https://<jenkins-host>/manage/credentials/store/system/domain/_/credential/github-pat/`)
   - **Or create new:** Manage Jenkins → Credentials → System → Global → Add → Kind = "Username with password" → Username = `<your-github-username>` → Password = GitHub PAT with `repo` + `read:org` → ID = `github-branch-source-pat`
3. **Seed job exists** in Jenkins UI (one-time UI click — irony noted, this is the bootstrap-the-bootstrapper step):
   - New Item → name: `seed-multibranch-jobs` → Pipeline → "Pipeline script from SCM"
   - SCM: Git → URL: `https://github.com/<your-github-username>/jenkins-shared-lib.git`
   - Script Path: `jobs/seed-pipeline.groovy`
   - Save

After the seed job exists, every future repo addition is just `repos.yaml` edit + push + click "Build Now" on the seed.

## Workflow — Adding a new repo

1. Edit `jenkins-shared-lib/jobs/repos.yaml` — add an entry under `repos:`
2. Commit + push to `jenkins-shared-lib` main
3. Trigger the seed job: `https://<jenkins-host>/job/seed-multibranch-jobs/build` (or click "Build Now")
4. **First run only:** the build fails with a Script Security warning. Click the "Approve" link in console → re-run. May need 2-3 approval rounds.
5. Verify the new multibranch job appears in Jenkins root and scans branches successfully

## Files this skill ships

| File | Goes to | Purpose |
|------|---------|---------|
| `templates/seed-job.groovy` | `jenkins-shared-lib/jobs/seed-job.groovy` | The Job DSL script — emits one `multibranchPipelineJob {}` per repo |
| `templates/seed-pipeline.groovy` | `jenkins-shared-lib/jobs/seed-pipeline.groovy` | The Jenkinsfile for the seed job itself — runs `jobDsl()` on `seed-job.groovy` |
| `templates/repos.yaml` | `jenkins-shared-lib/jobs/repos.yaml` | The repo manifest — pre-populated with the 4 known prospector repos |
| `references/auth.md` | reference only | Jenkins URL, credential IDs, API token setup |
| `references/plugin-checklist.md` | reference only | Required plugins + verification one-liners |

## Safety defaults

- `removedJobAction: 'IGNORE'` — if you delete a repo from the YAML, the seed will NOT delete the corresponding Jenkins job. You must delete it manually. This protects against accidental YAML edits nuking job history.
- `buildDiscarder(numToKeepStr: '20')` — caps build retention per branch to 20.
- `discardOldItems(numToKeep: 20)` — caps the number of branches kept per multibranch job to 20.
- Seed job uses `lookupStrategy: 'JENKINS_ROOT'` — jobs land at the root, not nested in a folder.

## Common mistakes

- **Forgetting to commit `repos.yaml`** — the seed job clones from SCM, so unpushed local changes won't be picked up.
- **`ERROR: You must configure the DSL job to run as a specific user in order to use the Groovy sandbox.`** — happens when `jobDsl(sandbox: true)` is set without the "Authorize Project" plugin + per-job user config. Fix: this skill ships `sandbox: false` in `seed-pipeline.groovy` because for a single-admin homelab the sandbox protection isn't needed (admin controls the script). If you want sandbox ON, install the Authorize Project plugin and configure the seed job under "Authorization" → "Run as specific user".
- **Pending script approval** — with `sandbox: false`, the first run shows a yellow "ScriptApproval" pending state. Manage Jenkins → In-process Script Approval → approve `jobs/seed-job.groovy`. One-time, until the script content changes.
- **Wrong credential type** — Branch Source needs "Username with password", not "Secret text". A fine-grained PAT stored as Secret text won't appear in the credentials dropdown for the GitHub branch source plugin.
- **Forgetting `scriptPath('jenkins/Jenkinsfile')`** — Job DSL defaults to `Jenkinsfile` at repo root. The seed-job.groovy in this skill sets the explicit path. Don't strip it.

## Verification after first use

```bash
# from anywhere — does the new multibranch job exist?
curl -s -u "$JENKINS_USER:$JENKINS_TOKEN" \
  "https://<jenkins-host>/job/<repo-name>/api/json?tree=name,jobs[name]" | jq

# expected: top-level "name" matches, "jobs" array has at least "main"
```
