# a2a-guard.mk - agent to agent messages go through a2a-send, never typed raw into a pane. Included by the root Makefile.
# Inputs are VAR=value (Design principles 101 item 17). Docs: README.md beside this file.
A2A_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
A2A_TEST_IMAGE := localhost/dotfiles-workflow-test:1
# BREADCRUMB - every target below runs through the shared timing wrapper (WO-20261016-39e6, item 37 amended:
#   "time out everything logically, you'll ID the bottlenecks, and it'll get things thru faster").
# What broke: nothing yet; these recipes called their scripts untimed, so a slow or hung step left no event on the bus.
# Why this fix: TIMED prefixes each recipe command, so only the step is timed. Rejected: a SHELL override, which also
#   times recipe-internal shell calls. A down bus only warns (timed-run.sh tm_event), the step keeps its own exit code.
# Path: the ticket wrote $(abspath bin/timed-run.sh), which resolves against the caller's cwd; this file is included by
#   the root Makefile too, so it is anchored on A2A_DIR instead.
# Left unwrapped: help-only and need-check lines, a2a-clean (find/rm only), a2a-deliver-loop (a daemon: the 600s make
#   timeout would kill it and retry it, DESIGN-GAP sent back to infra-design). Cost: one bash fork per wrapped step.
TIMED = bash $(A2A_DIR)/../bin/timed-run.sh --node $@ --kind make --
.PHONY: a2a-send a2a-deliver a2a-deliver-loop a2a-lint a2a-guard-test a2a-uat a2a-clean repo-settings-check

a2a-send: ## make a2a-send TO=<seat> FILE=<json> [LINE=]: validate, refuse ack-only, name by the store, queue, deliver at idle
	@test -n "$(TO)" -a -n "$(FILE)" || { echo "A2A-USAGE make a2a-send TO=<seat> FILE=<json> [LINE=]" >&2; exit 2; }
	@$(TIMED) bash $(A2A_DIR)/a2a-send.sh --to "$(TO)" --file "$(FILE)" $(if $(LINE),--line "$(LINE)")
a2a-deliver: ## make a2a-deliver [LINE= SEAT=]: one delivery pass; idle seats with an empty input line get one line
	@$(TIMED) bash $(A2A_DIR)/a2a-deliver.sh $(if $(LINE),--line "$(LINE)") $(if $(SEAT),--seat "$(SEAT)")
a2a-deliver-loop: ## make a2a-deliver-loop LINE= [INTERVAL=15]: the monitor entry (config/monitors.json)
	@bash $(A2A_DIR)/a2a-deliver.sh --line "$(LINE)" --loop --interval "$(or $(INTERVAL),15)"
a2a-lint: ## fail any raw `herdr pane send-text` outside a2a-guard (CI runs this)
	@$(TIMED) bash $(A2A_DIR)/a2a-lint.sh --root "$(abspath $(A2A_DIR)/../../..)"
repo-settings-check: ## make repo-settings-check REPOS="owner/a owner/b": auto-merge, protection, merge workflow; read-only
	@test -n "$(REPOS)" || { echo "A2A-USAGE make repo-settings-check REPOS='owner/repo ...'" >&2; exit 2; }
	@$(TIMED) bash $(A2A_DIR)/repo-settings-check.sh $(REPOS)
a2a-guard-test: ## dev gate: the relevant tests only, in Podman with a fake herdr (Rule 14)
	@$(TIMED) podman run --rm --network=none --userns=keep-id -v "$(abspath $(A2A_DIR)/../../..):/work:Z" -w /work -e HOME=/tmp \
	  $(A2A_TEST_IMAGE) bash -c 'shellcheck -x claude/workflow/a2a-guard/*.sh claude/workflow/a2a-guard/tests/*.sh && bash claude/workflow/a2a-guard/tests/test_a2a_guard.sh'
a2a-uat: ## UAT gate: make a2a-uat [LINE=uat]: a real herdr test seat, busy then idle; notifies nobody
	@$(TIMED) bash $(A2A_DIR)/uat.sh --line "$(or $(LINE),uat)"
a2a-clean: ## make a2a-clean OLDER_THAN=<days> [APPLY=1]: prune delivered/refused pointers (the store keeps its files)
	@test -n "$(OLDER_THAN)" || { echo "A2A-USAGE make a2a-clean OLDER_THAN=<days> [APPLY=1]" >&2; exit 2; }
	@find "$${A2A_STATE_DIR:-$$HOME/.local/state/zenith/a2a}/queue" -path '*/delivered/*.ptr' -o -path '*/refused/*.ptr' 2>/dev/null \
	  | while read -r f; do find "$$f" -mtime +$(OLDER_THAN) | while read -r g; do $(if $(APPLY),rm -v "$$g",echo "would remove $$g"); done; done
