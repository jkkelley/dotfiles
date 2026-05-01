# Platform Reference

## Jenkins

### Key built-in variables
| Variable | Value |
|---|---|
| `BUILD_NUMBER` | Incrementing integer, unique per job |
| `BUILD_TAG` | `jenkins-{job}-{build}` |
| `GIT_COMMIT` | Full SHA |
| `BRANCH_NAME` | Branch (multibranch pipelines only) |
| `CHANGE_ID` | PR number (multibranch + PR) |
| `WORKSPACE` | Agent workspace path |

### Isolation idioms

```groovy
pipeline {
  agent { docker { image 'node:20'; args '--network host' } }

  environment {
    RUN_ID = "${BRANCH_NAME.replaceAll('[^a-zA-Z0-9]', '-').toLowerCase()}-${BUILD_NUMBER}"
    IMAGE_TAG = "${GIT_COMMIT[0..6]}"
  }

  stages {
    stage('Build') {
      steps {
        script {
          // Network isolated per run
          sh "docker network create app-net-${RUN_ID}"
          sh "docker build -t myapp:${IMAGE_TAG} ."
          sh "docker push myapp:${IMAGE_TAG}"
        }
      }
    }
  }

  post {
    always {
      sh "docker network rm app-net-${RUN_ID} || true"
    }
  }
}
```

### Parallel stages with isolation

```groovy
stage('Test') {
  parallel {
    stage('Unit') {
      steps { sh 'npm test -- --shard=1/2' }
    }
    stage('Integration') {
      steps {
        sh "docker-compose -p proj-${RUN_ID} up -d"
        sh "npm run test:integration"
        sh "docker-compose -p proj-${RUN_ID} down -v"
      }
    }
  }
}
```

### Concurrency / resource locking

```groovy
stage('Deploy Prod') {
  options { lock(resource: 'production-deploy') }
  steps { sh './deploy.sh prod' }
}
```

### Credentials

```groovy
withCredentials([
  usernamePassword(credentialsId: 'registry-creds',
                   usernameVariable: 'REG_USER',
                   passwordVariable: 'REG_PASS')
]) {
  sh 'docker login -u $REG_USER -p $REG_PASS registry.example.com'
}
```

---

## GitHub Actions

### Key built-in variables
| Expression | Value |
|---|---|
| `github.sha` | Full commit SHA |
| `github.ref_name` | Branch or tag name |
| `github.run_id` | Unique per workflow run |
| `github.run_number` | Incrementing per workflow |
| `github.event.pull_request.number` | PR number |

### Isolation idioms

```yaml
env:
  SHA7: ${{ github.sha && github.sha[:7] || 'local' }}
  BRANCH_SLUG: ${{ github.ref_name }}  # sanitize in step if needed
  IMAGE: ghcr.io/${{ github.repository }}

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - name: Sanitize branch slug
        id: slug
        run: |
          slug=$(echo "${{ github.ref_name }}" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | cut -c1-40)
          echo "value=$slug" >> $GITHUB_OUTPUT

      - name: Build and push (immutable tag)
        run: |
          docker build -t $IMAGE:${{ github.sha }} .
          docker push $IMAGE:${{ github.sha }}

      - name: Re-tag mutable alias (only on main)
        if: github.ref_name == 'main'
        run: |
          docker tag $IMAGE:${{ github.sha }} $IMAGE:latest
          docker push $IMAGE:latest
```

### Concurrency — cancel redundant runs, serialize deploys

```yaml
concurrency:
  group: deploy-${{ github.ref }}
  cancel-in-progress: true   # use false for production deploys
```

### Matrix builds

```yaml
strategy:
  matrix:
    node: [18, 20, 22]
    os: [ubuntu-latest, macos-latest]
  fail-fast: false
runs-on: ${{ matrix.os }}
steps:
  - uses: actions/setup-node@v4
    with: { node-version: ${{ matrix.node }} }
```

### OIDC — keyless cloud auth

```yaml
permissions:
  id-token: write
  contents: read

steps:
  - uses: aws-actions/configure-aws-credentials@v4
    with:
      role-to-assume: arn:aws:iam::123456789:role/github-deploy
      aws-region: us-east-1
```

### Pass artifacts between jobs

```yaml
jobs:
  build:
    outputs:
      image-tag: ${{ steps.tag.outputs.value }}
    steps:
      - id: tag
        run: echo "value=${{ github.sha }}" >> $GITHUB_OUTPUT

  deploy:
    needs: build
    steps:
      - run: deploy.sh ${{ needs.build.outputs.image-tag }}
```

---

## GitLab CI

### Key built-in variables
| Variable | Value |
|---|---|
| `CI_COMMIT_SHA` | Full SHA |
| `CI_COMMIT_SHORT_SHA` | First 8 chars |
| `CI_PIPELINE_ID` | Unique pipeline integer |
| `CI_COMMIT_BRANCH` | Branch name |
| `CI_MERGE_REQUEST_IID` | MR number |
| `CI_REGISTRY_IMAGE` | Project registry path |

### Isolation idioms

```yaml
variables:
  IMAGE_TAG: $CI_COMMIT_SHORT_SHA
  RUN_ID: "${CI_COMMIT_REF_SLUG}-${CI_PIPELINE_ID}"

build:
  script:
    - docker build -t $CI_REGISTRY_IMAGE:$IMAGE_TAG .
    - docker push $CI_REGISTRY_IMAGE:$IMAGE_TAG

integration-test:
  script:
    - docker network create net-$RUN_ID
    - docker run --network net-$RUN_ID ...
  after_script:
    - docker network rm net-$RUN_ID || true
```

### DAG pipeline (needs — not just stage order)

```yaml
test-unit:
  stage: test
  script: pytest tests/unit

test-integration:
  stage: test
  needs: [test-unit]         # runs as soon as test-unit passes, not end of stage
  script: pytest tests/integration

deploy:
  needs: [test-unit, test-integration, build]
```

### Auto-cancel redundant pipelines

```yaml
workflow:
  auto_cancel:
    on_new_commit: interruptible

test:
  interruptible: true   # this job can be cancelled

deploy-prod:
  interruptible: false  # never cancel a prod deploy mid-flight
```

### Resource group (serialize deploys)

```yaml
deploy-prod:
  resource_group: production
  script: ./deploy.sh prod
```

### Ephemeral review environments

```yaml
deploy-review:
  environment:
    name: review/$CI_COMMIT_REF_SLUG
    url: https://$CI_COMMIT_REF_SLUG.review.example.com
    on_stop: stop-review
  only: [merge_requests]

stop-review:
  environment:
    name: review/$CI_COMMIT_REF_SLUG
    action: stop
  when: manual
  script: ./teardown.sh $CI_COMMIT_REF_SLUG
```

---

## CircleCI

### Key built-in variables
| Variable | Value |
|---|---|
| `CIRCLE_SHA1` | Full commit SHA |
| `CIRCLE_BUILD_NUM` | Build number |
| `CIRCLE_WORKFLOW_ID` | Unique workflow UUID |
| `CIRCLE_BRANCH` | Branch name |
| `CIRCLE_PULL_REQUEST` | PR URL (if PR build) |
| `CIRCLE_PR_NUMBER` | PR number |

### Isolation idioms

```yaml
environment:
  IMAGE_TAG: << pipeline.git.revision >>
  RUN_ID: "${CIRCLE_BRANCH//\//-}-${CIRCLE_BUILD_NUM}"
```

### Reusable defaults with YAML anchors

```yaml
defaults: &defaults
  docker:
    - image: cimg/node:20.0
  working_directory: ~/project

jobs:
  test:
    <<: *defaults
    steps:
      - run: npm test

  build:
    <<: *defaults
    steps:
      - run: docker build -t myapp:$CIRCLE_SHA1 .
```

### Workspaces — pass artifacts between jobs

```yaml
jobs:
  build:
    steps:
      - run: docker save myapp:$CIRCLE_SHA1 > image.tar
      - persist_to_workspace:
          root: .
          paths: [image.tar]

  deploy:
    steps:
      - attach_workspace: { at: . }
      - run: docker load < image.tar && ./deploy.sh
```

### Parallelism — split tests across containers

```yaml
jobs:
  test:
    parallelism: 4
    steps:
      - run: |
          TEST_FILES=$(circleci tests glob "**/*.test.js" | circleci tests split)
          npx jest $TEST_FILES
```

### Contexts — scoped secrets

```yaml
workflows:
  build-deploy:
    jobs:
      - deploy:
          context:
            - aws-production      # org-level context with AWS creds
            - slack-notifications
          filters:
            branches: { only: main }
```

### Hold / approval gate before prod

```yaml
workflows:
  deploy:
    jobs:
      - build
      - hold-for-approval:
          type: approval
          requires: [build]
      - deploy-prod:
          requires: [hold-for-approval]
```
