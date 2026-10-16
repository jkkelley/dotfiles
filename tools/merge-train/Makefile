# tools/merge-train - collapse a repo's open PR stacks into its default branch, leaves first.
# Owner, 2026-10-16 UTC: "get this code merged the fuck in, dead code is shit, it sitting under agents is stupid".
# Every input is a VAR=value argument (Design principles 101 item 17). Tests run in Podman (Rule 14), reusing the
# workflow machinery's pinned image rather than adding a second one (item 4).
REPO     ?=
RECOVER  ?= 0
DRY      ?= 0
METHOD   ?= auto
RETRIES  ?= 3
TEST_CMD ?=
RESULT   ?=
ROOT     := $(abspath $(CURDIR)/../..)
IMAGE    := localhost/dotfiles-workflow-test:1
CF       := $(ROOT)/claude/workflow/tests/container/Containerfile
RUN      := podman run --rm --network=none --userns=keep-id -v "$(ROOT):/work:Z" -w /work/tools/merge-train -e HOME=/tmp $(IMAGE)

.DEFAULT_GOAL := help
.PHONY: help merge-train image test lint

help: ## Show targets
	@grep -E '^[a-z-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN{FS=":.*?## "}{printf "  %-12s %s\n", $$1, $$2}'

merge-train: ## Merge every green PR of REPO=<owner/repo>, leaves first [DRY=1 RECOVER=1 METHOD= RETRIES= TEST_CMD= RESULT=]
	@test -n "$(REPO)" || { echo "REPO=<owner/repo> is required" >&2; exit 2; }
	@bash merge-train.sh --repo "$(REPO)" --method "$(METHOD)" --retries "$(RETRIES)" \
	  $(if $(filter 1,$(DRY)),--dry) $(if $(filter 1,$(RECOVER)),--recover) $(if $(TEST_CMD),--test-cmd "$(TEST_CMD)") $(if $(RESULT),--result "$(RESULT)")

image:
	@podman build -q -t $(IMAGE) -f $(CF) $(ROOT)/claude/workflow >/dev/null

lint: image ## shellcheck the script and its test
	@$(RUN) shellcheck -x merge-train.sh tests/test_merge_train.sh

test: image lint ## Graph order and skip evidence against a stub gh
	@$(RUN) bash tests/test_merge_train.sh
