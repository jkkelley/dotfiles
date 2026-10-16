# claude/workflow/inbox-sweep - the sweep's own inner loop.
# Every target that verifies anything runs in Podman on the pinned workflow test image (dotfiles CLAUDE.md Rule 14),
# --network=none, with the repository mounted read-only: a test that writes into the tree fails instead of leaving
# artifacts in a pull request. Test output goes to a mktemp dir inside the container and dies with it.
#
# The container has no git, so `test` computes changed paths here, on the host, and passes them in as SWEEP_CHANGED:
# committed since $(BASE), modified since HEAD, and untracked (--full-name keeps all three repo-root relative).
BASE  ?= origin/main
IMAGE := localhost/dotfiles-workflow-test:1
WF    := $(abspath $(CURDIR)/..)
ROOT  := $(abspath $(CURDIR)/../../..)
# RUN ends before the image name so a target can add -e flags; every use appends $(IMAGE) itself.
RUN   := podman run --rm --network=none --userns=keep-id -v "$(ROOT):/work:ro,Z" -w /work/claude/workflow/inbox-sweep -e HOME=/tmp

.DEFAULT_GOAL := help
.PHONY: help image test test-all herdr-first spec-lint nodes-check bottleneck-check

help: ## Show targets
	@grep -E '^[a-z-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN{FS=":.*?## "}{printf "  %-12s %s\n", $$1, $$2}'

image: ## Build the pinned test image (shared with claude/workflow)
	@podman build -q -t $(IMAGE) -f $(WF)/tests/container/Containerfile $(WF) >/dev/null

test: image ## Suites for files changed against $(BASE) (default origin/main) only
	@changed="$$( (cd $(ROOT) && git diff --name-only $(BASE)...HEAD; git diff --name-only HEAD; git ls-files -o --exclude-standard --full-name) | sort -u)"; \
	$(RUN) -e SWEEP_CHANGED="$$changed" $(IMAGE) bash tests/run.sh --changed

test-all: image ## Every suite; run once before a pull request
	@$(RUN) $(IMAGE) bash tests/run.sh --all

herdr-first: image ## Fail if any sweep script backgrounds a process (Rule 18); SWEEP_BIN_DIR= points the scan elsewhere
	@$(RUN) $(if $(SWEEP_BIN_DIR),-e SWEEP_BIN_DIR=$(SWEEP_BIN_DIR)) $(IMAGE) bash tests/run.sh --suite herdr-first

spec-lint: image ## Fail if any docs/design/*.spec.xml is over 1000 lines or not well-formed XML
	@$(RUN) $(IMAGE) bash bin/spec-lint.sh

nodes-check: image ## Node declarations validate, scripts name declared nodes, design tables agree
	@$(RUN) $(IMAGE) bash bin/node-lib.sh nodes-check

bottleneck-check: image ## List every node's serial reason; fail on a serial node with none
	@$(RUN) $(IMAGE) bash bin/node-lib.sh bottleneck-check
