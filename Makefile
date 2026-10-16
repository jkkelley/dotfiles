# Root entry points. Each target is a thin include; the work lives in scripts.
include claude/tools/ctx-guard/ctx-guard.mk
include claude/tools/artifact/artifact.mk
include claude/workflow/a2a-guard/a2a-guard.mk

# Contents lists on every Markdown file. Scripts drive it; nothing by hand.
BASE ?= origin/main
MAXLEVEL ?= 3
.PHONY: md-contents md-contents-check md-contents-global md-contents-global-check md-contents-discover

md-contents:            ## write contents lists (changed files; ALL=1 for everything)
	BASE=$(BASE) MAXLEVEL=$(MAXLEVEL) bash scripts/md-contents.sh write $(if $(ALL),--all)

md-contents-check:      ## fail on a missing or stale list (changed files; ALL=1 for everything)
	BASE=$(BASE) MAXLEVEL=$(MAXLEVEL) bash scripts/md-contents.sh check $(if $(ALL),--all)

md-contents-global:     ## write lists into the global files in config/md-contents-global.list (backs up first)
	bash scripts/md-contents.sh global

md-contents-global-check:
	bash scripts/md-contents.sh global --check

md-contents-discover:   ## print untracked global .md files missing from the list
	bash scripts/md-contents.sh discover

# Inputs are Make variables passed on, e.g. make golden-rules-repos PARALLEL=4 PROJECTS=~/projects
BRANCH ?= chore/golden-rules
PARALLEL ?= 8
PROJECTS ?= $(HOME)/projects
FROM ?= $(HOME)/AGENTS.md

.PHONY: golden-rules-global-check golden-rules golden-rules-extract golden-rules-check golden-rules-global golden-rules-repos

golden-rules-extract:   ## rebuild claude/golden-rules.md from FROM=<AGENTS.md> (owner rule edits only)
	bash scripts/golden-rules.sh extract $(FROM)


golden-rules: golden-rules-extract           ## write the golden rules block under the contents list of dotfiles' instruction files
	bash scripts/golden-rules.sh write

golden-rules-check:     ## fail when any copy drifts from claude/golden-rules.md
	bash scripts/golden-rules.sh check

golden-rules-global: golden-rules-extract    ## global instruction files (config/golden-rules.global), backed up first
	bash scripts/golden-rules.sh global

golden-rules-repos: golden-rules-extract     ## one branch + PR per git repo under ~/projects, in parallel (DRY=1 lists only)
	BRANCH=$(BRANCH) PARALLEL=$(PARALLEL) PROJECTS=$(PROJECTS) bash scripts/golden-rules.sh repos $(if $(DRY),--dry-run)

golden-rules-global-check:
	bash scripts/golden-rules.sh global --check

# System rolodex: what exists on this host and what does what. Scripts drive it; nothing by hand.
# Inputs are Make variables, e.g. make rolodex-headers ROOT=~/projects/foo WRITE=1 ; make rolodex-check BASE=origin/main ALL=1
ROOT ?= .
WRITE ?=
.PHONY: rolodex rolodex-headers rolodex-check rolodex-test

rolodex:                ## scan the host (config/rolodex.conf) and write SYSTEM_ROLODEX.md + system-rolodex.json
	python3 scripts/rolodex.py build $(if $(CONFIG),--config $(CONFIG)) $(if $(OUT_MD),--out-md $(OUT_MD)) $(if $(OUT_JSON),--out-json $(OUT_JSON))

rolodex-headers:        ## draft script headers (ROOT=<repo>; dry run unless WRITE=1)
	python3 scripts/rolodex.py headers --root $(ROOT) $(if $(WRITE),--write)

rolodex-check:          ## fail a new script with no header (ALL=1 checks every script)
	python3 scripts/rolodex.py check --root $(ROOT) --base $(BASE) $(if $(ALL),--all)

rolodex-test:           ## relevant tests only, in Podman (Rule 14)
	bash tools/rolodex/tests/run-tests.sh

# XML specs: 1000 lines or less, parse, open with <contents> (Design principles 101 item 28). Read-only.
# Inputs passed as VAR=value: FILES= (default: changed *.spec.xml vs BASE), LIMIT=, PATTERN=.
LIMIT ?= 1000
PATTERN ?= *.spec.xml
SPEC_IMAGE := localhost/dotfiles-workflow-test:1
.PHONY: spec-check spec-check-test

spec-check:             ## fail a changed XML spec over LIMIT lines, malformed, or without a <contents> first child
	BASE=$(BASE) LIMIT=$(LIMIT) PATTERN='$(PATTERN)' bash scripts/spec-check.sh $(FILES)

spec-check-test:        ## run scripts/tests/test_spec_check.sh in the pinned workflow test image (Rule 14)
	podman build -q -t $(SPEC_IMAGE) -f claude/workflow/tests/container/Containerfile claude/workflow >/dev/null
	podman run --rm --network=none --userns=keep-id -v "$(CURDIR):/work:Z" -w /work -e HOME=/tmp $(SPEC_IMAGE) bash scripts/tests/test_spec_check.sh

# Home migration: move a project's clones and worktrees into one home, symlink the old paths (docs/design/home-migrate.md).
# Inputs passed as VAR=value: CONF=<home project.json> (required), ONLY=<one old path> (UAT gate), PASSES= retries for busy paths, WAIT= seconds between.
.PHONY: home-plan home-apply home-check home-rollback home-migrate-test home-migrate-dev

home-plan:              ## read-only: one status-coded line per item (MOVE DONE BUSY CONFLICT KEEP)
	ONLY=$(ONLY) bash scripts/home-migrate.sh plan "$(CONF)"

home-apply:             ## move every MOVE item, symlink the old path; busy paths wait (PASSES= WAIT=)
	ONLY=$(ONLY) PASSES=$(or $(PASSES),1) WAIT=$(or $(WAIT),60) bash scripts/home-migrate.sh apply "$(CONF)"

home-check:             ## proof: every item in the home, old paths resolve, byte_for_byte manifests equal
	ONLY=$(ONLY) bash scripts/home-migrate.sh check "$(CONF)"

home-rollback:          ## scripted way back for one item: ONLY=<old path> required
	ONLY=$(ONLY) bash scripts/home-migrate.sh rollback "$(CONF)"

home-migrate-test:      ## dev gate: scripts/tests/test_home_migrate.sh in the pinned workflow test image (Rule 14)
	podman build -q -t $(SPEC_IMAGE) -f claude/workflow/tests/container/Containerfile claude/workflow >/dev/null
	podman run --rm --network=none --userns=keep-id -v "$(CURDIR):/work:Z" -w /work -e HOME=/tmp $(SPEC_IMAGE) bash -c 'shellcheck scripts/home-migrate.sh scripts/tests/test_home_migrate.sh && bash scripts/tests/test_home_migrate.sh'

home-migrate-dev:       ## dev gate on a mirror of CONF's real tree: manifest read on the host, migrated in Podman (Rule 14)
	@m=$$(mktemp) && c=$$(mktemp) && trap 'rm -f "$$m" "$$c"' EXIT && cp "$(CONF)" "$$c" && \
	bash scripts/tests/home_migrate_dev.sh manifest "$(CONF)" >"$$m" && \
	podman build -q -t $(SPEC_IMAGE) -f claude/workflow/tests/container/Containerfile claude/workflow >/dev/null && \
	podman run --rm --network=none --userns=keep-id -v "$(CURDIR):/work:Z" -v "$$m:/in/manifest.tsv:ro,Z" -v "$$c:/in/conf.json:ro,Z" \
	  -w /work -e HOME=/tmp $(SPEC_IMAGE) bash -c 'shellcheck scripts/tests/home_migrate_dev.sh && bash scripts/tests/home_migrate_dev.sh run /in/manifest.tsv /in/conf.json'
