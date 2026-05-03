# Jenkins Auth & Credential Reference

## Endpoint

`https://<jenkins-host>`

Pattern: this homelab puts services behind `<service>.<homelab-domain>` (sonarqube, jenkins, etc.). Substitute your real host in your project-level `CLAUDE.md` — never commit it back to this skill.

## Known credential IDs

| ID | Type | Used by | Notes |
|----|------|---------|-------|
| `<gitops-pat-credential-id>` | Username with password | `updateGitOpsManifest`, **GitHub Branch Source plugin** | Canonical credential for both GitOps commits AND multibranch SCM scanning. `<your-github-username>/<PAT>`, System / Global scope. Naming convention: `<machine>-<repo-group>-pat`. |
| `github-pat` | (verify type) | `buildKaniko`, GHCR image push | Used by Kaniko only. Don't use for Branch Source unless you've confirmed it's "Username with password" type. |
| `sonar-token` | Secret text | `sastSonarQube` step | |
| `snyk-token` | Secret text | `scaSnyk` step | |

## Creating a Jenkins API token (for CLI/script use)

1. Click your username (top-right) → "Configure"
2. API Token section → "Add new Token" → name it (e.g., `cli-local`)
3. Click "Generate" → **copy immediately** (shown once)
4. Save to a local file outside any git tree, e.g. `~/.config/jenkins/token`:
   ```
   chmod 600 ~/.config/jenkins/token
   ```
5. Use as basic auth: `curl -u "<your-github-username>:$(cat ~/.config/jenkins/token)" https://<jenkins-host>/...`

## Creating a *new* Branch Source credential (only if rotating)

Default is to reuse the existing GitOps PAT (`<gitops-pat-credential-id>`). Only create a new one if you're rotating PATs or scoping a different repo group.

1. Generate a GitHub PAT: GitHub → Settings → Developer settings → Personal access tokens → Tokens (classic)
   - Scopes: `repo`, `read:org`, `admin:repo_hook` (last only if wiring webhooks → Jenkins push notifications)
2. Manage Jenkins → Credentials → System → Global credentials → Add Credentials
3. Kind: **Username with password** (NOT "Secret text" — Branch Source dropdown filters that type out)
4. Scope: Global, Username: `<your-github-username>`, Password: the PAT
5. ID: e.g. `<machine>-<repo-group>-pat` (follow the naming convention above)
6. Save → update `defaults.scm_credentials_id` in `jenkins-shared-lib/jobs/repos.yaml` → re-run seed
