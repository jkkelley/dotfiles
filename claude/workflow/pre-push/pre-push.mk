# pre-push.mk - every fast gate on the changed files before a push (ORD-0814 P1). Run with make -f; touches no Makefile.
# Inputs as VAR=value: REPO= (required), BASE= (default origin/main), CONFIG= (default pre-push.json beside the script).
# Docs: pre-push.sh header.
PP_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
PP_IMAGE := localhost/dotfiles-workflow-test:1
.PHONY: pre-push pre-push-install pre-push-uninstall pre-push-test pre-push-e2e

pre-push:
	@test -n "$(REPO)" || { echo "pre-push needs REPO="; exit 2; }
	@bash $(PP_DIR)/../bin/timed-run.sh --node pre-push --budget 30 --timeout 60 --retries 1 -- bash $(PP_DIR)/pre-push.sh run --repo "$(REPO)"$(if $(BASE), --base $(BASE))$(if $(CONFIG), --config $(CONFIG))

pre-push-install:
	@test -n "$(REPO)" || { echo "pre-push needs REPO="; exit 2; }
	@bash $(PP_DIR)/pre-push.sh install --repo "$(REPO)"

pre-push-uninstall:
	@test -n "$(REPO)" || { echo "pre-push needs REPO="; exit 2; }
	@bash $(PP_DIR)/pre-push.sh uninstall --repo "$(REPO)"

pre-push-test:
	podman build -q -t $(PP_IMAGE) -f $(PP_DIR)/../tests/container/Containerfile $(PP_DIR)/.. >/dev/null
	podman run --rm --network=none --userns=keep-id -v "$(abspath $(PP_DIR)/../../..):/work:Z" -w /work -e HOME=/tmp $(PP_IMAGE) bash -c "shellcheck -x claude/workflow/pre-push/pre-push.sh claude/workflow/pre-push/tests/*.sh && bash claude/workflow/pre-push/tests/test_pre_push.sh"

pre-push-e2e:
	podman build -q -t $(PP_IMAGE) -f $(PP_DIR)/../tests/container/Containerfile $(PP_DIR)/.. >/dev/null
	podman run --rm --network=none --userns=keep-id -v "$(abspath $(PP_DIR)/../../..):/src:ro,Z" -e HOME=/tmp $(PP_IMAGE) bash /src/claude/workflow/pre-push/tests/e2e_pre_push.sh
