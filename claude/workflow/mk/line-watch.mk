# line-watch.mk - one line's monitoring in a labeled herdr "<LINE> monitor" tab. Included by claude/workflow/Makefile.
# Inputs are VAR=value (Design principles 101 item 17): LINE (required), WS, ARCH, LW_INTERVAL, LW_IDLE, LW_STATE,
# LW_COMPACT. The work lives in bin/line-watch.sh; see its header for the breadcrumb.
#
# BREADCRUMB - the adopt target is line-watch-adopt, not line-adopt.
# What broke: the brief asked for `make line-adopt LINE=`, but that name is already bin/herdr-grid.sh's migration target
#   in claude/workflow/Makefile (ARCH= SEATS=). A second recipe would silently override it and break the grid.
# Why this fix: every target here carries the line-watch prefix. Rejected: renaming the grid target, which another seat owns.
LW_SH := $(abspath $(dir $(lastword $(MAKEFILE_LIST)))../bin/line-watch.sh)
LW_ENV = $(if $(WS),WS=$(WS)) $(if $(ARCH),ARCH=$(ARCH)) $(if $(LW_INTERVAL),LW_INTERVAL=$(LW_INTERVAL)) \
  $(if $(LW_IDLE),LW_IDLE=$(LW_IDLE)) $(if $(LW_STATE),LW_STATE=$(LW_STATE)) $(if $(LW_COMPACT),LW_COMPACT=$(LW_COMPACT)) $(if $(ARTIFACT_ROOT),ARTIFACT_ROOT=$(ARTIFACT_ROOT))
lw_need = $(if $(LINE),,$(error LINE= is required))
.PHONY: line-watch line-watch-adopt line-watch-off line-watch-status line-watch-test

line-watch: ## make line-watch LINE= [WS= ARCH=]: tab "<LINE> monitor", the sweep pane, and every seat's watchers
	$(lw_need)
	@$(LW_ENV) bash $(LW_SH) up "$(LINE)"
line-watch-adopt: ## make line-watch-adopt LINE=: put every running seat of the line under the watchers, no restarts
	$(lw_need)
	@$(LW_ENV) bash $(LW_SH) adopt "$(LINE)"
line-watch-off: ## make line-watch-off LINE=: stop the sweep and its watchers, close the monitor tab(s)
	$(lw_need)
	@$(LW_ENV) bash $(LW_SH) off "$(LINE)"
line-watch-status: ## make line-watch-status LINE=: sweep pid, armed watchers, last log lines
	$(lw_need)
	@$(LW_ENV) bash $(LW_SH) status "$(LINE)"
line-watch-test: image ## The sweep against a stub herdr (relevant test only)
	@$(RUN) bash -c 'shellcheck -x bin/line-watch.sh bin/watch-ctl.sh tests/unit/test_line_watch.sh && bash tests/unit/test_line_watch.sh'
test: line-watch-test
