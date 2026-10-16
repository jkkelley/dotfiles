# tools/merge-train - collapse a repo's open PR stacks into its default branch, leaves first.
# Owner, 2026-10-16 UTC: "get this code merged the fuck in, dead code is shit, it sitting under agents is stupid".
# Every input is a VAR=value argument (Design principles 101 item 17). Tests run in Podman (Rule 14), reusing the
# workflow machinery's pinned image rather than adding a second one (item 4).
# Retired 2026-10-16 (WO-20261016-5630): RECOVER, METHOD, RETRIES and TEST_CMD. merge-train.sh is a wrapper over
# claude/workflow/pr-flow/bin/merge.sh, which owns the merge decision, retries and conflicts (pr-process.md section 7).
REPO     ?=
DRY      ?= 0
RESULT   ?=
CLONE    ?= $(ROOT)
ROOT     := $(abspath $(CURDIR)/../..)
IMAGE    := localhost/dotfiles-workflow-test:1
CF       := $(ROOT)/claude/workflow/tests/container/Containerfile
RUN      := podman run --rm --network=none --userns=keep-id -v "$(ROOT):/work:Z" -w /work/tools/merge-train -e HOME=/tmp $(IMAGE)

.DEFAULT_GOAL := help
.PHONY: help merge-train image test lint

help: ## Show targets
	@grep -E '^[a-z-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN{FS=":.*?## "}{printf "  %-12s %s\n", $$1, $$2}'

merge-train: ## Merge every green PR of REPO=<owner/repo>, leaves first, through pr-flow merge.sh [DRY=1 RESULT= CLONE=]
	@test -n "$(REPO)" || { echo "REPO=<owner/repo> is required" >&2; exit 2; }
	@bash merge-train.sh --repo "$(REPO)" --clone "$(CLONE)" $(if $(filter 1,$(DRY)),--dry) $(if $(RESULT),--result "$(RESULT)")

image:
	@podman build -q -t $(IMAGE) -f $(CF) $(ROOT)/claude/workflow >/dev/null

lint: image ## shellcheck the script and its test
	@$(RUN) shellcheck -x merge-train.sh tests/test_merge_train.sh

test: image lint ## Graph order and skip evidence against a stub gh
	@$(RUN) bash tests/test_merge_train.sh
