# CI/CD Design — Worked Patterns

## Pattern: Full image promotion pipeline (GitHub Actions)

Build once, promote the same immutable image through environments.

```yaml
name: CI/CD

on:
  push:
    branches: [main, 'feature/**']
  pull_request:

env:
  REGISTRY: ghcr.io
  IMAGE: ghcr.io/${{ github.repository_owner }}/myapp

concurrency:
  group: pipeline-${{ github.ref }}
  cancel-in-progress: ${{ github.ref != 'refs/heads/main' }}

jobs:
  # ── 1. Build & push immutable tag ──────────────────────────────────────
  build:
    runs-on: ubuntu-latest
    outputs:
      image-tag: ${{ steps.meta.outputs.version }}
    steps:
      - uses: actions/checkout@v4

      - name: Generate tags
        id: meta
        run: |
          SHA="${{ github.sha }}"
          SHORT="${SHA:0:7}"
          echo "version=$SHORT" >> $GITHUB_OUTPUT

      - name: Build and push
        run: |
          echo "${{ secrets.GITHUB_TOKEN }}" | docker login ghcr.io -u ${{ github.actor }} --password-stdin
          docker build -t $IMAGE:${{ steps.meta.outputs.version }} .
          docker push $IMAGE:${{ steps.meta.outputs.version }}

  # ── 2. Test against the built image (not a rebuild) ────────────────────
  test:
    needs: build
    runs-on: ubuntu-latest
    env:
      IMAGE_TAG: ${{ needs.build.outputs.image-tag }}
    steps:
      - uses: actions/checkout@v4
      - name: Pull image
        run: docker pull $IMAGE:$IMAGE_TAG
      - name: Run tests
        run: |
          docker network create test-net-$IMAGE_TAG
          docker run --rm --network test-net-$IMAGE_TAG $IMAGE:$IMAGE_TAG npm test
          docker network rm test-net-$IMAGE_TAG

  # ── 3. Security scan ───────────────────────────────────────────────────
  scan:
    needs: build
    runs-on: ubuntu-latest
    steps:
      - uses: aquasecurity/trivy-action@master
        with:
          image-ref: ${{ env.IMAGE }}:${{ needs.build.outputs.image-tag }}
          exit-code: 1
          severity: CRITICAL

  # ── 4. Deploy staging ─────────────────────────────────────────────────
  deploy-staging:
    needs: [test, scan]
    runs-on: ubuntu-latest
    environment: staging
    concurrency:
      group: deploy-staging
      cancel-in-progress: false
    steps:
      - run: ./deploy.sh staging ${{ needs.build.outputs.image-tag }}

  # ── 5. Deploy prod (main only, manual gate) ────────────────────────────
  deploy-prod:
    needs: [deploy-staging]
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    environment:
      name: production      # requires approval in GitHub environment settings
    concurrency:
      group: deploy-production
      cancel-in-progress: false
    steps:
      - run: ./deploy.sh prod ${{ needs.build.outputs.image-tag }}
      # Re-tag mutable aliases AFTER successful prod deploy
      - name: Tag :latest
        run: |
          docker tag ${{ env.IMAGE }}:${{ needs.build.outputs.image-tag }} ${{ env.IMAGE }}:latest
          docker push ${{ env.IMAGE }}:latest
```

---

## Pattern: PR ephemeral environment (GitLab)

Spin up a full environment per MR, tear it down on close.

```yaml
variables:
  SLUG: $CI_COMMIT_REF_SLUG        # already sanitized by GitLab
  IMAGE_TAG: $CI_COMMIT_SHORT_SHA
  ENV_URL: "https://${SLUG}.review.myapp.com"

stages: [build, test, deploy-review, cleanup]

build:
  stage: build
  script:
    - docker build -t $CI_REGISTRY_IMAGE:$IMAGE_TAG .
    - docker push $CI_REGISTRY_IMAGE:$IMAGE_TAG

deploy-review:
  stage: deploy-review
  environment:
    name: review/$SLUG
    url: $ENV_URL
    on_stop: stop-review
  script:
    - helm upgrade --install "app-$SLUG" ./chart
        --set image.tag=$IMAGE_TAG
        --set ingress.host="${SLUG}.review.myapp.com"
        --namespace "review-$SLUG" --create-namespace
  only: [merge_requests]

stop-review:
  stage: cleanup
  environment:
    name: review/$SLUG
    action: stop
  script:
    - helm uninstall "app-$SLUG" --namespace "review-$SLUG"
    - kubectl delete namespace "review-$SLUG"
  when: manual
  only: [merge_requests]
```

---

## Pattern: Matrix test fan-out + merge gate (GitHub Actions)

Run tests across multiple versions in parallel; block merge until all pass.

```yaml
jobs:
  test:
    strategy:
      matrix:
        node: [18, 20, 22]
        os: [ubuntu-latest, macos-latest]
      fail-fast: false       # let all matrix jobs complete; see full failure picture
    runs-on: ${{ matrix.os }}
    steps:
      - uses: actions/setup-node@v4
        with: { node-version: ${{ matrix.node }} }
      - run: npm ci && npm test

  # Merge gate: single job that depends on all matrix variants
  test-gate:
    needs: test
    if: always()
    runs-on: ubuntu-latest
    steps:
      - name: Check matrix result
        if: needs.test.result != 'success'
        run: exit 1
```

Set `test-gate` (not `test`) as the required status check in branch protection — avoids managing N matrix entries as required checks.

---

## Pattern: Isolated integration test with ephemeral DB (Jenkins)

```groovy
pipeline {
  agent any
  environment {
    RUN_ID = "${BRANCH_NAME.replaceAll('[^a-zA-Z0-9]', '-').toLowerCase()}-${BUILD_NUMBER}"
    DB_NAME = "testdb_${RUN_ID.replace('-', '_')}"
    NET_NAME = "test-net-${RUN_ID}"
  }

  stages {
    stage('Setup') {
      steps {
        sh """
          docker network create ${NET_NAME}
          docker run -d --name pg-${RUN_ID} \
            --network ${NET_NAME} \
            -e POSTGRES_DB=${DB_NAME} \
            -e POSTGRES_PASSWORD=test \
            postgres:16
          # Wait for readiness
          timeout 60 bash -c 'until docker exec pg-${RUN_ID} pg_isready -q; do sleep 2; done'
        """
      }
    }

    stage('Integration Tests') {
      steps {
        sh """
          docker run --rm \
            --network ${NET_NAME} \
            -e DATABASE_URL=postgres://postgres:test@pg-${RUN_ID}/${DB_NAME} \
            myapp:${GIT_COMMIT[0..6]} \
            npm run test:integration
        """
      }
    }
  }

  post {
    always {
      sh """
        docker stop pg-${RUN_ID} || true
        docker rm   pg-${RUN_ID} || true
        docker network rm ${NET_NAME} || true
      """
    }
  }
}
```

---

## Anti-patterns checklist

- [ ] **Pushing `:latest` before tests pass** — always push SHA first, re-tag after gate.
- [ ] **Shared mutable DB across concurrent builds** — suffix DB name with build/branch ID.
- [ ] **Re-building image at each stage** — build once, push, pull the same tag everywhere.
- [ ] **`sleep N` for service readiness** — use polling loops with timeout ceiling.
- [ ] **Hardcoded port numbers in integration tests** — use port 0 (random) or range-per-branch.
- [ ] **No cleanup on failure** — always run cleanup in `post.always` / `always:` / `after_script`.
- [ ] **Secrets in image build args** — inject at container runtime, not build time.
- [ ] **One `concurrency` group for everything** — separate groups for staging vs prod; cancel-in-progress only on non-prod.
