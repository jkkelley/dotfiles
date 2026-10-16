# stuck-watch.mk - is a seat really stuck: codes on the bus, the owner's phone, a deadman nothing on the line can kill.
# Included by claude/workflow/Makefile. Inputs are VAR=value (Design principles 101 item 17): LINE, SINCE, LINES,
# NTFY_TOPIC_VAR (every test and gate: YPC_NTFY_TEST_TOPIC, item 35; stable real events: unset = config YPC_NTFY_TOPIC).
# Gates (item 34): stuck-watch-dev, stuck-watch-uat, stuck-watch-stable, rollback stuck-watch-rollback.
SW_HOME := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
SW_UNITS := $(HOME)/.config/systemd/user
SW_LINES = $(or $(LINES),$(LINE),$(shell jq -r '.lines|join(" ")' $(SW_HOME)/config.json))
SW_ENV = $(if $(NTFY_TOPIC_VAR),NTFY_TOPIC_VAR=$(NTFY_TOPIC_VAR))
sw_need = $(if $(LINE),,$(error LINE= is required))
.PHONY: stuck-watch-loop stuck-watch-up stuck-watch-down stuck-watch-status stuck-audit deadman-install deadman-uninstall deadman-status \
  stuck-watch-clean stuck-watch-test stuck-watch-dev stuck-watch-uat stuck-watch-stable stuck-watch-rollback

stuck-watch-up: ## make stuck-watch-up LINE= [WS=]: the line monitor tab with stuck-watch at its slot (bin/monitors.sh)
	$(sw_need)
	@$(SW_ENV) bash $(SW_HOME)/stuck-watch-ctl.sh up "$(LINE)"
stuck-watch-down: ## make stuck-watch-down LINE=: stop this watcher only; the tab and other monitors stay
	$(sw_need)
	@bash $(SW_HOME)/stuck-watch-ctl.sh down "$(LINE)"
stuck-watch-loop: ## make stuck-watch-loop LINE=: the monitors.json entry; the watcher in the foreground of its pane
	$(sw_need)
	@$(SW_ENV) bash $(SW_HOME)/stuck-watch.sh --line "$(LINE)"
stuck-watch-status: ## make stuck-watch-status LINE=: pid, pane, last heartbeat age on the bus
	$(sw_need)
	@bash $(SW_HOME)/stuck-watch-ctl.sh status "$(LINE)"
stuck-audit: ## make stuck-audit LINE= [SINCE=]: every stuck node, duration and evidence path, from the bus
	$(sw_need)
	@bash $(SW_HOME)/stuck-audit.sh --line "$(LINE)" $(if $(SINCE),--since "$(SINCE)")
deadman-install: ## make deadman-install [LINES= NTFY_TOPIC_VAR=]: systemd --user timer runs deadman.sh every minute
	@mkdir -p $(SW_UNITS)
	@sed -e 's|@DIR@|$(SW_HOME)|' -e 's|@LINES@|$(SW_LINES)|' -e 's|@TOPIC_VAR@|$(or $(NTFY_TOPIC_VAR),YPC_NTFY_TOPIC)|' \
	  $(SW_HOME)/systemd/stuck-deadman.service > $(SW_UNITS)/stuck-deadman.service
	@cp $(SW_HOME)/systemd/stuck-deadman.timer $(SW_UNITS)/stuck-deadman.timer
	@systemctl --user daemon-reload && systemctl --user enable --now stuck-deadman.timer >/dev/null 2>&1
	@echo "deadman timer on: lines=$(SW_LINES) topic_var=$(or $(NTFY_TOPIC_VAR),YPC_NTFY_TOPIC)"
deadman-uninstall: ## make deadman-uninstall: stop and remove the timer and service (idempotent)
	@systemctl --user disable --now stuck-deadman.timer >/dev/null 2>&1 || true
	@rm -f $(SW_UNITS)/stuck-deadman.service $(SW_UNITS)/stuck-deadman.timer
	@systemctl --user daemon-reload; echo "deadman timer off"
deadman-status: ## make deadman-status: timer state and the last deadman log lines
	@systemctl --user list-timers stuck-deadman.timer --no-pager 2>/dev/null | head -3
	@tail -n 5 $(HOME)/.local/state/zenith/stuck-watch/deadman.log 2>/dev/null || echo "no deadman log yet"
stuck-watch-clean: ## make stuck-watch-clean [LINE=]: drop dedupe and per-line state (evidence stays in the artifact store)
	@rm -f $(HOME)/.local/state/zenith/stuck-watch/notified.json $(if $(LINE),$(HOME)/.local/state/zenith/stuck-watch/$(LINE).json,$(HOME)/.local/state/zenith/stuck-watch/*.json)
	@echo "stuck-watch state cleaned"
stuck-watch-test: image ## The stuck-watch scripts against stubs, --network=none [CASE=] (relevant test only)
	@$(RUN) bash -c 'shellcheck -x stuck-watch/*.sh stuck-watch/tests/*.sh && CASE="$(CASE)" bash stuck-watch/tests/test_stuck_watch.sh'
stuck-watch-dev: stuck-watch-test ## Gate 1 (item 34): podman, fake herdr/gh/bus/ntfy; nothing leaves the container
stuck-watch-uat: ## Gate 2: real bus, a scripted idle test seat, the TEST topic read back (AC1-AC4, AC6) [LINE=stuck-uat]
	@bash $(SW_HOME)/tests/uat.sh "$(or $(LINE),stuck-uat)"
stuck-watch-stable: ## Gate 3: watcher up for every line in config .lines, deadman timer on the owner topic, checked
	@for l in $(SW_LINES); do $(MAKE) --no-print-directory stuck-watch-up LINE=$$l || exit 1; done
	@$(MAKE) --no-print-directory deadman-install LINES="$(SW_LINES)"
	@sleep 70; for l in $(SW_LINES); do $(MAKE) --no-print-directory stuck-watch-status LINE=$$l || exit 1; done
stuck-watch-rollback: ## Roll stable back: every watcher down, deadman timer removed
	@for l in $(SW_LINES); do $(MAKE) --no-print-directory stuck-watch-down LINE=$$l; done
	@$(MAKE) --no-print-directory deadman-uninstall
test: stuck-watch-test
