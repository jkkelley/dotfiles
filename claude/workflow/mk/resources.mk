# resources.mk - what each seat costs the machine, and cleaning up the MCP processes of seats that are gone.
# Included by claude/workflow/Makefile. Inputs are VAR=value (Design principles 101 item 17): LINE, RSS_MB, CPU_PCT,
# FLOOR_MB, DRY, JSON, PUBLISH. The work lives in resources/*.sh; see their headers.
SR_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST)))../resources)
SR_ARGS = $(if $(LINE),--line "$(LINE)") $(if $(RSS_MB),--rss-mb $(RSS_MB)) $(if $(CPU_PCT),--cpu-pct $(CPU_PCT)) \
  $(if $(FLOOR_MB),--floor-mb $(FLOOR_MB)) $(if $(JSON),--json) $(if $(PUBLISH),--publish)
.PHONY: seat-resources seat-resources-loop mcp-orphans-clean resources-test

seat-resources: ## make seat-resources [LINE= RSS_MB= CPU_PCT= FLOOR_MB= JSON=1 PUBLISH=1]: per seat CPU, RSS, processes, containers
	@bash $(SR_DIR)/seat-resources.sh $(SR_ARGS)
seat-resources-loop: ## make seat-resources-loop LINE=: the monitor entry; every 60 s, publishes res.<line>.<seat> to NATS
	@bash $(SR_DIR)/seat-resources.sh $(SR_ARGS) --publish --loop
mcp-orphans-clean: ## make mcp-orphans-clean [DRY=1]: stop MCP containers and processes whose seat is gone
	@bash $(SR_DIR)/mcp-orphans-clean.sh $(if $(DRY),--dry)
resources-test: image ## The resources scripts against stubs (relevant test only)
	@$(RUN) bash -c 'shellcheck -x resources/*.sh tests/unit/test_resources.sh && bash tests/unit/test_resources.sh'
test: resources-test
