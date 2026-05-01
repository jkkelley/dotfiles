---
name: jenkinsfile-snippets
description: Jenkinsfile patterns, pipeline snippets, and CI/CD recipes. Preloaded into the jenkins-ci agent.
---

# Jenkinsfile Snippets

## Pipeline Skeleton (Declarative)

```groovy
pipeline {
    agent { label 'linux' }
    options {
        timeout(time: 30, unit: 'MINUTES')
        disableConcurrentBuilds()
        buildDiscarder(logRotator(numToKeepStr: '20'))
        timestamps()
    }
    environment {
        APP_NAME  = 'my-app'
        IMAGE_TAG = "${env.GIT_COMMIT[0..7]}"
    }
    stages {
        stage('Checkout') {
            steps { checkout scm }
        }
        stage('Build') {
            steps { sh 'make build' }
        }
        stage('Test') {
            steps { sh 'make test' }
            post { always { junit 'reports/**/*.xml' } }
        }
        stage('Deploy') {
            when { branch 'main' }
            steps { /* deploy */ }
        }
    }
    post {
        always  { cleanWs() }
        success { slackSend color: 'good',   message: "✅ ${env.JOB_NAME} #${env.BUILD_NUMBER}" }
        failure { slackSend color: 'danger', message: "❌ ${env.JOB_NAME} #${env.BUILD_NUMBER} — ${env.BUILD_URL}" }
    }
}
```

## Credentials Patterns

```groovy
// Username + password
withCredentials([usernamePassword(credentialsId: 'dockerhub', usernameVariable: 'U', passwordVariable: 'P')]) {
    sh 'docker login -u $U -p $P'
}

// Secret text
withCredentials([string(credentialsId: 'slack-token', variable: 'SLACK_TOKEN')]) {
    sh 'curl -H "Authorization: Bearer $SLACK_TOKEN" ...'
}

// SSH key
withCredentials([sshUserPrivateKey(credentialsId: 'deploy-key', keyFileVariable: 'KEY')]) {
    sh 'ssh -i $KEY user@host "deploy.sh"'
}

// File credential
withCredentials([file(credentialsId: 'kubeconfig', variable: 'KUBECONFIG')]) {
    sh 'kubectl apply -f manifests/'
}
```

## Parallel Stages

```groovy
stage('Parallel Tests') {
    failFast true
    parallel {
        stage('Unit')        { steps { sh 'make test-unit' } }
        stage('Integration') { steps { sh 'make test-integration' } }
        stage('Lint')        { steps { sh 'make lint' } }
        stage('Security')    { steps { sh 'trivy fs .' } }
    }
}
```

## Kubernetes Agent Pod Template

```groovy
pipeline {
    agent {
        kubernetes {
            yaml """
apiVersion: v1
kind: Pod
spec:
  containers:
  - name: build
    image: maven:3.9-eclipse-temurin-21
    command: [cat]
    tty: true
    resources:
      requests: { memory: 2Gi, cpu: '1' }
      limits:   { memory: 4Gi, cpu: '2' }
  - name: docker
    image: docker:24-dind
    securityContext:
      privileged: true
  volumes:
  - name: docker-sock
    emptyDir: {}
"""
        }
    }
    stages {
        stage('Build') {
            steps {
                container('build') { sh 'mvn package -DskipTests' }
            }
        }
        stage('Docker') {
            steps {
                container('docker') { sh 'docker build -t myapp:latest .' }
            }
        }
    }
}
```

## Matrix Build (Cross-Version)

```groovy
stage('Test Matrix') {
    matrix {
        axes {
            axis { name 'PYTHON_VERSION'; values '3.10', '3.11', '3.12' }
            axis { name 'OS';            values 'linux', 'windows' }
        }
        stages {
            stage('Test') {
                steps { sh "tox -e py${PYTHON_VERSION.replace('.', '')}" }
            }
        }
    }
}
```

## Shared Library Usage

```groovy
@Library('my-shared-lib@main') _

pipeline {
    agent any
    stages {
        stage('Build') {
            steps {
                // Call var from shared lib (vars/dockerBuild.groovy)
                dockerBuild(imageName: 'my-app', tag: env.GIT_COMMIT[0..7])
            }
        }
    }
}
```

## Conditional When Clauses

```groovy
when { branch 'main' }                          // branch name
when { changeRequest() }                        // PR build
when { tag pattern: 'v\\d+\\.\\d+\\.\\d+', comparator: 'REGEXP' }  // semver tag
when { environment name: 'DEPLOY_ENV', value: 'production' }
when { expression { return params.DEPLOY == true } }
when {
    allOf {
        branch 'main'
        not { changeRequest() }
    }
}
```

## Useful Snippets

```groovy
// Retry with backoff
retry(3) { sh 'flaky-command' }

// Stash / unstash across agents
stash includes: 'dist/**', name: 'build-output'
unstash 'build-output'

// Read file content
def version = readFile('VERSION').trim()

// Write file
writeFile file: 'deploy.log', text: "Deployed ${env.GIT_COMMIT}"

// Archive artifacts
archiveArtifacts artifacts: 'dist/*.tar.gz', fingerprint: true

// Git info
env.GIT_COMMIT       // full SHA
env.GIT_COMMIT[0..7] // short SHA
env.GIT_BRANCH       // branch name
env.CHANGE_ID        // PR number (multibranch)

// Input / approval gate
input message: 'Deploy to production?', ok: 'Deploy', submitter: 'ops-team'
```

## Trigger Patterns

```groovy
triggers {
    // Webhook (preferred over polling)
    githubPush()

    // Cron — use H for load distribution
    cron('H 2 * * 1-5')

    // Upstream job
    upstream(upstreamProjects: 'my-build-job', threshold: hudson.model.Result.SUCCESS)
}
```
