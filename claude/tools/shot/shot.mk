# shot.mk - include from any Makefile or use `make -f claude/tools/shot/shot.mk shot HTML= NAME=`. See README.md.
SHOT_SH := $(dir $(lastword $(MAKEFILE_LIST)))shot.sh
export CHROME_BIN SHOT_TIMEOUT_S ARTIFACT_ROOT
.PHONY: shot shot-test shot-lint
shot: ## make -f claude/tools/shot/shot.mk shot HTML= NAME= [SIZE=] [WHAT=]: screenshot to the store
	@bash $(SHOT_SH) --html "$(HTML)" --name "$(NAME)" $(if $(SIZE),--size "$(SIZE)") $(if $(WHAT),--what "$(WHAT)")
shot-test: ## relevant-only test in podman
	@podman run --rm --network=none --userns=keep-id -v "$(abspath $(dir $(SHOT_SH))..):/w:ro,Z" localhost/dotfiles-workflow-test:1 bash /w/shot/tests/test_shot.sh
shot-lint: ## shellcheck in podman
	@podman run --rm --network=none --userns=keep-id -v "$(abspath $(dir $(SHOT_SH))..):/w:ro,Z" localhost/dotfiles-workflow-test:1 shellcheck -x /w/shot/shot.sh /w/shot/tests/test_shot.sh
