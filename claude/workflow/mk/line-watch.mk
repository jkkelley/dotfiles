# line-watch.mk - a line's monitoring tab, its bus and its consumers. Included by claude/workflow/Makefile.
# Inputs are VAR=value (Design principles 101 item 17): LINE, WS, LW_INTERVAL, LW_IDLE, LW_STATE, LW_COMPACT,
# LW_RESULTS, LW_BUS, LW_MONITORS, ROLE. The work lives in bin/monitors.sh, bin/line-watch.sh and bin/bus.sh.
#
# BREADCRUMB - the adopt target is line-watch-adopt, not line-adopt.
# What broke: the brief asked for `make line-adopt LINE=`, but that name is already bin/herdr-grid.sh's migration target
#   in claude/workflow/Makefile (ARCH= SEATS=). A second recipe would silently override it and break the grid.
# Why this fix: every target here carries a line-, bus- or monitors- prefix. Rejected: renaming the grid target.
LW_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST)))..)
LW_ENV = $(if $(WS),WS=$(WS)) $(if $(LW_INTERVAL),LW_INTERVAL=$(LW_INTERVAL)) $(if $(LW_IDLE),LW_IDLE=$(LW_IDLE)) \
  $(if $(LW_STATE),LW_STATE=$(LW_STATE)) $(if $(LW_COMPACT),LW_COMPACT=$(LW_COMPACT)) $(if $(ARTIFACT_ROOT),ARTIFACT_ROOT=$(ARTIFACT_ROOT)) \
  $(if $(LW_RESULTS),LW_RESULTS=$(LW_RESULTS)) $(if $(LW_BUS),LW_BUS=$(LW_BUS)) $(if $(LW_MONITORS),LW_MONITORS=$(LW_MONITORS))
lw_need = $(if $(LINE),,$(error LINE= is required))
.PHONY: monitors-up monitors-down monitors-status line-watch line-watch-off line-watch-adopt line-watch-status \
  line-watch-stop line-sweep line-consume line-queue bus-up bus-logs bus-down bus-status bus-tail bus-clean line-watch-test

monitors-up: ## make monitors-up LINE= [WS= LW_RESULTS=]: tab "<LINE> monitor", every monitor of config/monitors.json in its slot
	$(lw_need)
	@$(LW_ENV) bash $(LW_DIR)/bin/monitors.sh up "$(LINE)"
monitors-down: ## make monitors-down LINE=: every monitor's down, then the tab and its panes close together
	$(lw_need)
	@$(LW_ENV) bash $(LW_DIR)/bin/monitors.sh down "$(LINE)"
monitors-status: ## make monitors-status LINE=: each declared monitor, its slot and pane
	$(lw_need)
	@$(LW_ENV) bash $(LW_DIR)/bin/monitors.sh status "$(LINE)"
line-watch: monitors-up ## make line-watch LINE=: same as monitors-up
line-watch-off: monitors-down ## make line-watch-off LINE=: same as monitors-down
line-watch-adopt: ## make line-watch-adopt LINE=: put every running seat of the line under the watchers, no restarts
	$(lw_need)
	@$(LW_ENV) bash $(LW_DIR)/bin/line-watch.sh adopt "$(LINE)"
line-watch-status: ## make line-watch-status LINE=: sweep and consumer pids, armed watchers, bus, last log lines
	$(lw_need)
	@$(LW_ENV) bash $(LW_DIR)/bin/line-watch.sh status "$(LINE)"
line-watch-stop: ## make line-watch-stop LINE=: stop sweep, consumer and watchers (the sweep monitor's down)
	$(lw_need)
	@$(LW_ENV) bash $(LW_DIR)/bin/line-watch.sh stop "$(LINE)"
line-sweep: ## make line-sweep LINE=: adopt, then the sweep in the foreground of this herdr pane (a monitor)
	$(lw_need)
	@$(LW_ENV) bash $(LW_DIR)/bin/line-watch.sh run "$(LINE)"
line-consume: ## make line-consume LINE= [LW_RESULTS=dir]: consumer line-consume (no model) in the foreground (a monitor)
	$(lw_need)
	@$(LW_ENV) bash $(LW_DIR)/bin/line-watch.sh consume "$(LINE)"
line-queue: ## make line-queue LINE= ROLE=orchestrator|architect: pull and ack every waiting event, one JSON per line
	$(lw_need)$(if $(ROLE),,$(error ROLE= is required))
	@ROLE=$(ROLE) $(LW_ENV) bash $(LW_DIR)/bin/line-watch.sh queue "$(LINE)"
bus-up: ## NATS JetStream in podman (127.0.0.1, restart always, health check), stream LINE and its consumers
	@bash $(LW_DIR)/bin/bus.sh up
bus-logs: ## Follow the bus server's log (the bus monitor's foreground)
	@bash $(LW_DIR)/bin/bus.sh logs
bus-down: ## Stop and remove the bus container; the JetStream store stays
	@bash $(LW_DIR)/bin/bus.sh down
bus-status: ## Container health, the stream, every consumer with pending and unacked counts
	@bash $(LW_DIR)/bin/bus.sh status
bus-tail: ## Print every bus event as it lands, one line each (the events pane of the monitor tab; never acks)
	@$(LW_ENV) bash $(LW_DIR)/bin/bus.sh tail

bus-clean: ## bus-down, then delete the JetStream store
	@bash $(LW_DIR)/bin/bus.sh clean
line-watch-test: image ## Monitors tab, sweep, bus and consumers against stub herdr and nats (relevant test only)
	@$(RUN) bash -c 'shellcheck -x bin/line-watch.sh bin/bus.sh bin/monitors.sh bin/watch-ctl.sh tests/unit/test_line_watch.sh && bash tests/unit/test_line_watch.sh'
test: line-watch-test
