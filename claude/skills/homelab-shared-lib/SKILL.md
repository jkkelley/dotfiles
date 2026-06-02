---
name: homelab-shared-lib
description: Reference for the homelab jenkins-shared-lib — DevSecOps pipeline steps for the Kaniko/K8s/GHCR stack. Use when writing or debugging Jenkinsfiles that call buildKaniko, deployStaging, dastZap, sastSonarQube, scaSnyk, iacCheckov, imageScanTrivy, deployProduction, updateGitOpsManifest, versionRelease, or pipelineConfig.
---

# Homelab Jenkins Shared Library

**Library declaration:**
```groovy
@Library('jenkins-shared-lib') _
```

**Repo:** `https://github.com/<your-github-username>/jenkins-shared-lib`
**Jenkins config:** Manage Jenkins → System → Global Pipeline Libraries → `jenkins-shared-lib` @ `main`

---

## pipelineConfig — Load environment config

Call at the top of the Jenkinsfile (before `pipeline {}`). Returns a Map of environment-specific values.

```groovy
def cfg = pipelineConfig('staging')   // or 'prod'
```

**Returned keys:**

| Key | Staging | Prod |
|-----|---------|------|
| `sonarHost` | `http://sonarqube.sonarqube.svc.cluster.local:9000` | same |
| `sonarDashUrl` | `https://sonarqube.<your-homelab-domain>` | same |
| `sonarProject` | `vulnerable-flask` | same |
| `githubUser` | `<your-github-username>` | same |
| `imageBase` | `ghcr.io/<your-github-username>/vulnerable-flask` | same |
| `trivyExitCode` | `0` | `0` |
| `zapFailOnHigh` | `false` | `true` |
| `snykSeverityThreshold` | `high` | `high` |
| `zapUrl` | `http://owasp-zap.staging.svc.cluster.local:8090` | `http://owasp-zap.prod.svc.cluster.local:8090` |
| `targetUrl` | `http://vulnerable-flask.staging.svc.cluster.local:5000` | `http://vulnerable-flask.prod.svc.cluster.local:5000` |

---

## sastSonarQube — Static analysis (SAST)

Runs SonarQube scanner against source code. Runs in a pod in the `jenkins` namespace.

```groovy
sastSonarQube(
    projectKey:   'my-app',                    // required — SonarQube project key
    sources:      "${WORKSPACE}/app",          // default
    credentialsId: 'sonar-token',              // default — secret text
    sonarHostUrl: 'http://sonarqube.sonarqube.svc.cluster.local:9000',  // default
    sonarDashUrl: 'https://sonarqube.<your-homelab-domain>',  // default
    pythonVersion: '3',                        // default
)
```

**Credential required:** `sonar-token` (Secret text — SonarQube token)

---

## scaSnyk — Dependency scan (SCA)

Runs Snyk against `requirements.txt` (Python) or `package.json` (npm). Runs in a pod using the shared PVC.

```groovy
scaSnyk(
    credentialsId:      'snyk-token',           // default — secret text
    image:              'snyk/snyk:python-3.8', // default — use snyk/snyk:linux on ARM64
    packageManager:     'pip',                  // default ('pip' or 'npm')
    severityThreshold:  'high',                 // default
    requirementsFile:   '/app/requirements.txt',// default
    namespace:          'jenkins',              // default
    pvcName:            'kaniko-workspace',     // default
)
```

**Credential required:** `snyk-token` (Secret text — Snyk API token)
**ARM64 note:** Always use `snyk/snyk:linux` on ARM64 nodes — the versioned images are amd64 only.

---

## iacCheckov — IaC misconfiguration scan

Runs Checkov in a pod against k8s manifests or Terraform. Source read from shared PVC.

```groovy
iacCheckov(
    directory:  '/tf/k8s',       // default — path inside the PVC/pod
    framework:  'kubernetes',    // default ('kubernetes', 'terraform', 'helm')
    namespace:  'jenkins',       // default
    pvcName:    'kaniko-workspace', // default
)
```

---

## buildKaniko — Build & push container image

Builds Dockerfile via Kaniko pod (no Docker daemon). Copies source from workspace to shared PVC, runs Kaniko, cleans up pod and secret.

```groovy
buildKaniko(
    imageFull:     "ghcr.io/<your-github-username>/my-app:${env.BUILD_NUMBER}", // REQUIRED
    imageName:     "ghcr.io/<your-github-username>/my-app",                     // REQUIRED
    credentialsId: 'github-pat',              // default — username/password
    sourceDir:     "${WORKSPACE}/app/.",      // default
    k8sDir:        "${WORKSPACE}/k8s/.",      // default
    namespace:     'jenkins',                 // default
    pvcName:       'kaniko-workspace',        // default
)
```

**Credential required:** `github-pat` (Username/password — GitHub PAT with `write:packages`)
**How it works:**
1. Copies `sourceDir` and `k8sDir` into `/kaniko-workspace/` on the shared PVC
2. Creates a short-lived k8s Secret `kaniko-ghcr-<BUILD_NUMBER>` with ghcr.io auth
3. Spawns pod `kaniko-<BUILD_NUMBER>` in `jenkins` namespace
4. Waits up to 600s for `Succeeded` phase
5. Deletes pod and secret on completion

---

## imageScanTrivy — CVE scan

Scans the built image for known CVEs using Trivy in a pod.

```groovy
imageScanTrivy(
    imageFull:     "ghcr.io/<your-github-username>/my-app:${env.BUILD_NUMBER}", // REQUIRED
    exitCode:      '0',               // default — set '1' to fail on CRITICAL/HIGH
    severity:      'CRITICAL,HIGH',   // default
    credentialsId: 'github-pat',      // default
    namespace:     'jenkins',         // default
)
```

**Credential required:** `github-pat` (to pull image from ghcr.io)

---

## deployStaging — Rolling deploy to staging

Creates/updates `ghcr-secret` image pull secret in the target namespace, optionally applies manifests, then does `kubectl set image` and waits for rollout.

```groovy
deployStaging(
    imageFull:      "ghcr.io/<your-github-username>/my-app:${env.BUILD_NUMBER}", // REQUIRED
    deploymentName: 'my-app',          // REQUIRED
    containerName:  'app',             // default
    namespace:      'staging',         // default
    credentialsId:  'github-pat',      // default
    pullSecretName: 'ghcr-secret',     // default
    rolloutTimeout: 120,               // default (seconds)
    manifestDir:    'k8s/staging',     // optional — apply manifests before rollout
)
```

**Credential required:** `github-pat`

---

## dastZap — OWASP ZAP dynamic scan

Talks to the ZAP daemon already running in the staging namespace via its REST API. Spider → active scan → collect alerts → generate `zap-report.html`.

```groovy
dastZap(
    targetUrl:   'http://my-app.staging.svc.cluster.local:5000', // REQUIRED
    zapUrl:      'http://owasp-zap.staging.svc.cluster.local:8090', // default
    zapNamespace: 'staging',      // default
    zapDeploy:   'owasp-zap',     // default
    failOnHigh:  false,           // default — set true to fail build on HIGH findings
    maxRuleMins: 1,               // default — max minutes per ZAP rule (prevents OOM)
    maxScanMins: 10,              // default — max total active scan duration
)
```

**Post step:** always archive `zap-report.html`:
```groovy
post {
    always {
        archiveArtifacts artifacts: 'zap-report.html', allowEmptyArchive: true
        publishHTML(target: [
            allowMissing: true, alwaysLinkToLastBuild: true, keepAll: true,
            reportDir: '.', reportFiles: 'zap-report.html', reportName: 'ZAP DAST Report'
        ])
    }
}
```

---

## deployProduction — Manual approval gate

Pauses pipeline and waits for named approver in Jenkins UI. Times out and aborts if no one approves.

```groovy
deployProduction(
    submitter:  'admin',                                          // default
    message:    'All security gates passed. Deploy to production?', // default
    ok:         'Deploy',                                         // default
    timeoutMin: 30,                                               // default
)
```

**Always wrap in:** `when { branch 'main' }` — don't gate prod from feature branches.

---

## updateGitOpsManifest — GitOps image tag update

Clones the GitOps config repo, runs `kustomize edit set image`, commits, and pushes. Must run inside a container with `kustomize` available.

```groovy
container('kustomize') {
    updateGitOpsManifest(
        gitRepo:       'https://github.com/<your-github-username>/gitops-config', // REQUIRED
        overlayPath:   'apps/overlays/staging/my-app',              // REQUIRED
        imageName:     'ghcr.io/<your-github-username>/my-app',                   // REQUIRED
        newTag:        env.IMAGE_TAG,                                // REQUIRED
        branch:        'main',                                       // default
        credentialsId: 'github-pat-credentials',                    // default
        containerName: 'kustomize',                                  // default
    )
}
```

**What it does:** `kustomize edit set image <imageName>=<imageName>:<newTag>` then commits `ci(gitops): roll <imageName> to tag <newTag>`. Skips commit if tag already set (idempotent).

---

## versionRelease — Semantic versioning + GitHub release

Runs `semantic-release` based on conventional commits. Creates a git tag + GitHub release. Re-tags the GHCR image from `BUILD_NUMBER` to the semver tag via OCI registry API (no Docker daemon).

Caches semantic-release in `/kaniko-workspace/semrel/` — downloaded once, reused.

```groovy
stage('Version & Release') {
    steps {
        script {
            def ver = versionRelease(
                imageName:    env.IMAGE_NAME,   // optional — re-tags image if provided
                buildTag:     env.IMAGE_TAG,    // default: BUILD_NUMBER
                credentialsId: 'github-pat',   // default
            )
            env.IMAGE_FULL = "${env.IMAGE_NAME}:${ver}"
        }
    }
}
```

**Returns:** semver string (e.g. `1.4.2`) if a release was created, or `BUILD_NUMBER` if no release (chore/docs commits only).

**Conventional commit → release mapping:**
| Commit type | Release |
|-------------|---------|
| `feat:` | MINOR (1.x.0) |
| `fix:` | PATCH (1.0.x) |
| `feat!:` or `BREAKING CHANGE:` | MAJOR (x.0.0) |
| `chore:` / `docs:` / `ci:` / `refactor:` / `test:` | No release |

---

## Required Jenkins Credentials

| Credential ID | Type | Used by |
|--------------|------|---------|
| `sonar-token` | Secret text | `sastSonarQube` |
| `snyk-token` | Secret text | `scaSnyk` |
| `github-pat` | Username/password | `buildKaniko`, `imageScanTrivy`, `deployStaging`, `versionRelease` |
| `github-pat-credentials` | Username/password | `updateGitOpsManifest` |

---

## Infrastructure Defaults

| Resource | Value |
|---------|-------|
| Shared PVC | `kaniko-workspace` (Longhorn RWX) |
| Jenkins namespace | `jenkins` |
| Staging namespace | `staging` |
| ZAP deployment | `owasp-zap` (in `staging`) |
| SonarQube | `http://sonarqube.sonarqube.svc.cluster.local:9000` |
| GHCR registry | `ghcr.io/<your-github-username>/` |
| Node.js cache | `/kaniko-workspace/nodejs/` |
| semrel cache | `/kaniko-workspace/semrel/` |

---

## Full DevSecOps Pipeline Pattern

```groovy
@Library('jenkins-shared-lib') _

def cfg = pipelineConfig('staging')

pipeline {
    agent { label 'linux' }
    environment {
        IMAGE_NAME = cfg.imageBase
        IMAGE_TAG  = "${env.BUILD_NUMBER}"
        IMAGE_FULL = "${IMAGE_NAME}:${IMAGE_TAG}"
    }
    stages {
        stage('SAST — SonarQube')   { steps { script { sastSonarQube(projectKey: 'my-app') } } }
        stage('SCA — Snyk')          { steps { script { scaSnyk(image: 'snyk/snyk:linux') } } }
        stage('IaC — Checkov')       { steps { script { iacCheckov(directory: '/tf/k8s') } } }
        stage('Build — Kaniko')      { steps { script { buildKaniko(imageFull: env.IMAGE_FULL, imageName: env.IMAGE_NAME) } } }
        stage('Scan — Trivy')        { steps { script { imageScanTrivy(imageFull: env.IMAGE_FULL) } } }
        stage('Version & Release')   {
            steps {
                script {
                    def ver = versionRelease(imageName: env.IMAGE_NAME, buildTag: env.IMAGE_TAG)
                    env.IMAGE_FULL = "${env.IMAGE_NAME}:${ver}"
                }
            }
        }
        stage('Deploy — Staging')    { steps { script { deployStaging(imageFull: env.IMAGE_FULL, deploymentName: 'my-app') } } }
        stage('DAST — ZAP')          {
            steps { script { dastZap(targetUrl: cfg.targetUrl, failOnHigh: cfg.zapFailOnHigh.toBoolean()) } }
            post  { always { archiveArtifacts artifacts: 'zap-report.html', allowEmptyArchive: true } }
        }
        stage('Deploy — Production') {
            when  { branch 'main' }
            steps { script { deployProduction(submitter: 'admin') } }
        }
    }
    post { always { cleanWs() } }
}
```

---

## Homelab AVP + ESO Contract — What the CI Pipeline Owns

The Jenkins pipeline owns **exactly one value** in the GitOps repo: `imageTag`.

```groovy
// updateGitOpsManifest writes this — the only literal in values.yaml
updateGitOpsManifest(
    overlayPath: 'helm/myapp',
    imageName:   env.IMAGE_NAME,
    newTag:      env.BUILD_NUMBER,   // → imageTag: "42" written by yq
)
```

**Everything else in `values.yaml` is an AVP placeholder.** The pipeline must never write to any other key in values.yaml. If it does, it will overwrite a Vault placeholder with a hardcoded value and break ArgoCD sync.

### What AVP resolves (at ArgoCD sync time, not in the pipeline)

```yaml
# These are resolved by ArgoCD Vault Plugin — CI never touches them
imageName:       <path:secret/data/homelab/apps/myapp#image-name>
iamRoleArn:      <path:secret/data/homelab/roles#myapp-eso>
awsRegion:       <path:secret/data/homelab/apps/myapp#aws-region>
ssmSaName:       <path:secret/data/homelab/apps/myapp#ssm-sa-name>
secretStoreName: <path:secret/data/homelab/apps/myapp#secret-store-name>
memoryLimit:     <path:secret/data/homelab/apps/myapp#memory-limit>
host:            <path:secret/data/homelab/apps/myapp#host>
# ... all non-imageTag values
```

### ArgoCD Application source (all new apps use plugin, not helm)

```yaml
source:
  path: helm/myapp
  plugin:
    name: argocd-vault-plugin
# NEVER: helm: { releaseName: myapp }
```

### ghcr-pull-secret comes from ESO (Vault-backed)

The pipeline does NOT create `ghcr-pull-secret`. ESO creates it at namespace deploy time
by pulling `secret/homelab/github#pat` from Vault. The pipeline's `github-pat` Jenkins
credential is separate and is only used for registry push during build.
