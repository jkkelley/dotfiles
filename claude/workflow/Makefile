# claude/workflow - the workflow machinery's own inner loop.
# Every target that verifies anything runs in Podman (dotfiles CLAUDE.md Rule 14), --network=none.
IMAGE := localhost/dotfiles-workflow-test:1
CF    := tests/container/Containerfile
RUN   := podman run --rm --network=none --userns=keep-id -v "$(CURDIR):/work:Z" -w /work -e HOME=/tmp $(IMAGE)

.DEFAULT_GOAL := help
.PHONY: help image test schema lint

help: ## Show targets
	@grep -E '^[a-z-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN{FS=":.*?## "}{printf "  %-10s %s\n", $$1, $$2}'

image: ## Build the pinned test image
	@podman build -q -t $(IMAGE) -f $(CF) . >/dev/null && echo "ok  image: $(IMAGE)"

schema: image ## Validate every workflow declaration and record schema
	@$(RUN) bash tests/unit/test_workflow_schemas.sh

lint: image ## shellcheck every script
	@$(RUN) shellcheck -x bin/*.sh tools/*.sh report/rail.sh

test: schema lint ## Everything
	@echo "ok  workflow: schema + lint"
