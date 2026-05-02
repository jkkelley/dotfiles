# Post-Scaffold Verification Checklist

## Universal (every stack)

- [ ] README: update title, description, badge URLs, setup instructions
- [ ] Remove or update any hardcoded URLs pointing to the old service
- [ ] `.env.example`: rename all `OLD_NAME_*` vars to `NEW_NAME_*`
- [ ] Regenerate lockfile (don't commit old service's lockfile)
- [ ] Verify no leftover references: `grep -r "old-name" . --include="*.yml" --include="*.json" --include="*.toml"`
- [ ] Create remote repo: `gh repo create org/new-service --private`
- [ ] Push: `git remote add origin git@github.com:org/new-service.git && git push -u origin main`

---

## Node.js / TypeScript

- [ ] `package.json`: `name`, `description`, `repository.url`, `bugs.url`, `homepage`
- [ ] `package-lock.json` / `yarn.lock` / `pnpm-lock.yaml`: delete and regenerate
- [ ] `tsconfig.json`: `paths` aliases if service-name-based
- [ ] Check `jest.config.ts` / `vitest.config.ts` for hardcoded project name

---

## Python

- [ ] `pyproject.toml` / `setup.cfg`: `[project] name`, `[tool.poetry] name`
- [ ] Module directory name matches new package name
- [ ] Delete and regenerate `poetry.lock` / `requirements.txt` via `pip-compile`
- [ ] `pytest.ini` / `pyproject.toml [tool.pytest]`: `testpaths`, project name

---

## Go

- [ ] `go.mod`: `module github.com/org/new-service`
- [ ] All internal import paths updated: `grep -r "old-service" . --include="*.go"`
- [ ] Run `go mod tidy` to clean up deps

---

## Java / Kotlin

- [ ] `pom.xml` / `build.gradle`: `groupId`, `artifactId`, `name`, `description`
- [ ] Package names in source files: `com.org.oldservice` → `com.org.newservice`
- [ ] Rename directory tree to match new package: `src/main/java/com/org/newservice/`
- [ ] `application.properties` / `application.yml`: `spring.application.name`

---

## Docker / Containers

- [ ] `Dockerfile`: `LABEL`, any hardcoded service name in `CMD`/`ENTRYPOINT`
- [ ] `docker-compose.yml`: service names, container names, network names, volume names
- [ ] Image tag in compose: `image: registry/new-service:latest`
- [ ] `.dockerignore`: usually fine as-is

---

## Kubernetes / Helm

- [ ] `Chart.yaml`: `name`, `description`, `home`, `sources`
- [ ] `values.yaml`: `nameOverride`, `fullnameOverride`, image repository
- [ ] All `metadata.name` and `metadata.labels` in manifests
- [ ] `ingress.yaml`: hostname
- [ ] Namespace name if service-specific
- [ ] ArgoCD `Application` manifest: `metadata.name`, `spec.source.path`, `spec.destination.namespace`

---

## CI/CD

### GitHub Actions
- [ ] Workflow `name` fields
- [ ] `env.IMAGE` / registry path
- [ ] `environment:` names (staging, production) if service-specific
- [ ] `concurrency.group` values
- [ ] Any hardcoded repo name in `gh` CLI calls

### Jenkins
- [ ] `Jenkinsfile`: `BUILD_TAG` references, registry paths
- [ ] Jenkins job name (configured in Jenkins UI, not in repo)

### GitLab CI
- [ ] `CI_REGISTRY_IMAGE` usage (auto-set, but check overrides)
- [ ] `environment.name` and `environment.url`
- [ ] `resource_group` names

### CircleCI
- [ ] Context names if service-specific
- [ ] Workflow and job names referencing old service

---

## Secrets & credentials

- [ ] Do NOT copy `.env` — start fresh
- [ ] Update CI secrets/variables with new service credentials
- [ ] Rotate any secrets that were shared with the old service
- [ ] Update external service configs (databases, APIs, OAuth callbacks) with new service URLs
