# a2a-guard.mk - agent to agent messages go through a2a-send, never typed raw into a pane. Included by the root Makefile.
# Inputs are VAR=value (Design principles 101 item 17). Docs: README.md beside this file.
A2A_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
A2A_TEST_IMAGE := localhost/dotfiles-workflow-test:1
.PHONY: a2a-send a2a-deliver a2a-deliver-loop a2a-lint a2a-guard-test a2a-uat a2a-clean repo-settings-check

a2a-send: ## make a2a-send TO=<seat> FILE=<json> [LINE=]: validate, refuse ack-only, name by the store, queue, deliver at idle
	@test -n "$(TO)" -a -n "$(FILE)" || { echo "A2A-USAGE make a2a-send TO=<seat> FILE=<json> [LINE=]" >&2; exit 2; }
	@bash $(A2A_DIR)/a2a-send.sh --to "$(TO)" --file "$(FILE)" $(if $(LINE),--line "$(LINE)")
a2a-deliver: ## make a2a-deliver [LINE= SEAT=]: one delivery pass; idle seats with an empty input line get one line
	@bash $(A2A_DIR)/a2a-deliver.sh $(if $(LINE),--line "$(LINE)") $(if $(SEAT),--seat "$(SEAT)")
a2a-deliver-loop: ## make a2a-deliver-loop LINE= [INTERVAL=15]: the monitor entry (config/monitors.json)
	@bash $(A2A_DIR)/a2a-deliver.sh --line "$(LINE)" --loop --interval "$(or $(INTERVAL),15)"
a2a-lint: ## fail any raw `herdr pane send-text` outside a2a-guard (CI runs this)
	@bash $(A2A_DIR)/a2a-lint.sh --root "$(abspath $(A2A_DIR)/../../..)"
repo-settings-check: ## make repo-settings-check REPOS="owner/a owner/b": auto-merge, protection, merge workflow; read-only
	@test -n "$(REPOS)" || { echo "A2A-USAGE make repo-settings-check REPOS='owner/repo ...'" >&2; exit 2; }
	@bash $(A2A_DIR)/repo-settings-check.sh $(REPOS)
a2a-guard-test: ## dev gate: the relevant tests only, in Podman with a fake herdr (Rule 14)
	@podman run --rm --network=none --userns=keep-id -v "$(abspath $(A2A_DIR)/../../..):/work:Z" -w /work -e HOME=/tmp \
	  $(A2A_TEST_IMAGE) bash -c 'shellcheck -x claude/workflow/a2a-guard/*.sh claude/workflow/a2a-guard/tests/*.sh && bash claude/workflow/a2a-guard/tests/test_a2a_guard.sh'
a2a-uat: ## UAT gate: make a2a-uat [LINE=uat]: a real herdr test seat, busy then idle; notifies nobody
	@bash $(A2A_DIR)/uat.sh --line "$(or $(LINE),uat)"
a2a-clean: ## make a2a-clean OLDER_THAN=<days> [APPLY=1]: prune delivered/refused pointers (the store keeps its files)
	@test -n "$(OLDER_THAN)" || { echo "A2A-USAGE make a2a-clean OLDER_THAN=<days> [APPLY=1]" >&2; exit 2; }
	@find "$${A2A_STATE_DIR:-$$HOME/.local/state/zenith/a2a}/queue" -path '*/delivered/*.ptr' -o -path '*/refused/*.ptr' 2>/dev/null \
	  | while read -r f; do find "$$f" -mtime +$(OLDER_THAN) | while read -r g; do $(if $(APPLY),rm -v "$$g",echo "would remove $$g"); done; done
