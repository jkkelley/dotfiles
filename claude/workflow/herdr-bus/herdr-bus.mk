# herdr-bus.mk - herdr status changes onto NATS, owner-tagged ones back out as toasts. Included by claude/workflow/Makefile.
# Inputs are VAR=value (Design principles 101 item 17): LINE (required for up/down), HB_CONFIG, NATS_BIN.
# The two long-running halves are seats in the line's grid, started through `make seat-up` (labeled pane, never a background job).
HB_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
HB_ENV  = $(if $(HB_CONFIG),HB_CONFIG=$(HB_CONFIG)) $(if $(NATS_BIN),NATS_BIN=$(NATS_BIN))
hb_need = $(if $(LINE),,$(error LINE= is required))
.PHONY: herdr-bus-up herdr-bus-down herdr-bus-status herdr-bus-test

herdr-bus-up: ## make herdr-bus-up LINE=: seats bus-publish and bus-notify in labeled panes (stream owned by line-watch's bus-up)
	$(hb_need)
	@$(MAKE) --no-print-directory seat-up LINE="$(LINE)" SEAT=bus-publish CMD="$(HB_ENV) bash $(HB_DIR)/herdr-bus.sh publish"
	@$(MAKE) --no-print-directory seat-up LINE="$(LINE)" SEAT=bus-notify CMD="$(HB_ENV) bash $(HB_DIR)/herdr-bus.sh notify"
herdr-bus-down: ## make herdr-bus-down [LINE=]: close both seats, their panes and any emptied tab
	@$(MAKE) --no-print-directory seat-down SEAT=bus-publish LINE="$(LINE)" FORCE=1
	@$(MAKE) --no-print-directory seat-down SEAT=bus-notify LINE="$(LINE)" FORCE=1
herdr-bus-status: ## make herdr-bus-status: tracked agents, state age, the notify consumer
	@$(HB_ENV) bash $(HB_DIR)/herdr-bus.sh status
herdr-bus-test: image ## The bridge against stub herdr and stub nats (relevant test only)
	@$(RUN) bash -c 'shellcheck -x herdr-bus/herdr-bus.sh herdr-bus/tests/test_herdr_bus.sh && bash herdr-bus/tests/test_herdr_bus.sh'
test: herdr-bus-test
