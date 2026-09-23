# claude/workflow - the workflow machinery's own inner loop.
# Every target that verifies anything runs in Podman (dotfiles CLAUDE.md Rule 14), --network=none.
IMAGE := localhost/dotfiles-workflow-test:1
CF    := tests/container/Containerfile
# The repository root is mounted, not only this directory: the compaction tests call the context-compaction skill's
# checkpoint.sh, which is the one implementation of the checkpoint format and lives beside this machinery in dotfiles.
ROOT  := $(abspath $(CURDIR)/../..)
RUN   := podman run --rm --network=none --userns=keep-id -v "$(ROOT):/work:Z" -w /work/claude/workflow -e HOME=/tmp $(IMAGE)

.DEFAULT_GOAL := help
.PHONY: help image test schema lint herdr-first compaction chain failover test-plan

help: ## Show targets
	@grep -E '^[a-z-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN{FS=":.*?## "}{printf "  %-10s %s\n", $$1, $$2}'

image: ## Build the pinned test image
	@podman build -q -t $(IMAGE) -f $(CF) . >/dev/null && echo "ok  image: $(IMAGE)"

schema: image ## Validate every workflow declaration and record schema
	@$(RUN) bash tests/unit/test_workflow_schemas.sh

lint: image ## shellcheck every script
	@$(RUN) shellcheck -x bin/*.sh tools/*.sh report/rail.sh tests/unit/*.sh

herdr-first: image ## Fail if anything here backgrounds a process (Rule 18)
	@$(RUN) bash tests/unit/test_herdr_first.sh

compaction: image ## The compaction ceremony, watcher, switch and hook, against a stub herdr
	@$(RUN) bash tests/unit/test_compaction.sh

chain: image ## The spawner starts the requested link of a model chain on that link's surface
	@$(RUN) bash tests/unit/test_model_chain.sh

failover: image ## The seat watcher: done records, hot swap along the chain, exhaustion, against a stub herdr
	@$(RUN) bash tests/unit/test_seat_watch.sh

test-plan: image ## The test-plan block: template, work-order's parser and the schema agree (O-10)
	@$(RUN) bash tests/unit/test_test_plan.sh

test: schema lint herdr-first compaction chain failover test-plan ## Everything
	@echo "ok  workflow: schema, lint, herdr-first, compaction, chain, failover, test-plan"
