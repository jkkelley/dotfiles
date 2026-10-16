# quota-probe - generic daily probe of a rate-limited tool. Inputs are VAR=value (Design principles 101 item 17).
# Own Makefile so no shared file is edited (WO-20261016-8009). Gates (item 34): dev, uat, stable; rollback.
QP_HOME := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
WF      := $(abspath $(QP_HOME)/..)
ROOT    := $(abspath $(WF)/../..)
IMAGE   := localhost/dotfiles-workflow-test:1
RUN     := podman run --rm --network=none --userns=keep-id -v "$(ROOT):/work:Z" -w /work/claude/workflow/quota-probe -e HOME=/tmp $(IMAGE)
UNITS   := $(HOME)/.config/systemd/user
STATE   := $(or $(QP_STATE_DIR),$(HOME)/.local/state/zenith/quota-probe)
qp_need = $(if $(NAME),,$(error NAME= is required))
.DEFAULT_GOAL := help
.PHONY: help probe install uninstall lint status test dev uat stable rollback clean

help: ## make help: list targets
	@grep -E '^[a-z-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN{FS=":.*?## "}{printf "  %-10s %s\n", $$1, $$2}'

probe: ## make probe NAME=: run one probe now
	$(qp_need)
	@bash $(QP_HOME)/quota-probe.sh --name "$(NAME)"

install: ## make install NAME=: render the units and enable the daily timer
	$(qp_need)
	@mkdir -p $(UNITS)
	@sed -e 's|@DIR@|$(QP_HOME)|' $(QP_HOME)/systemd/quota-probe@.service > $(UNITS)/quota-probe@.service
	@cp $(QP_HOME)/systemd/quota-probe@.timer $(UNITS)/quota-probe@.timer
	@systemctl --user daemon-reload && systemctl --user enable --now quota-probe@$(NAME).timer >/dev/null 2>&1
	@echo "quota-probe timer on: $(NAME)"

uninstall: ## make uninstall NAME=: disable the timer; remove the units when no other probe timer is enabled
	$(qp_need)
	@systemctl --user disable --now quota-probe@$(NAME).timer >/dev/null 2>&1 || true
	@if ! systemctl --user list-unit-files 'quota-probe@*.timer' --state=enabled --no-legend 2>/dev/null | grep -q 'quota-probe@.\+\.timer'; then \
	  rm -f $(UNITS)/quota-probe@.service $(UNITS)/quota-probe@.timer; fi
	@systemctl --user daemon-reload; echo "quota-probe timer off: $(NAME)"

lint: ## make lint: shellcheck in podman
	@$(MAKE) -s -C $(WF) image
	@$(RUN) shellcheck -x quota-probe.sh tests/test_quota_probe.sh

status: ## make status: timers and every state file
	@systemctl --user list-timers 'quota-probe@*' --no-pager 2>/dev/null | head -5
	@for f in $(STATE)/*.json; do [ -f "$$f" ] && cat "$$f"; done; true

test: ## make test: the 8 cases in podman
	@$(MAKE) -s -C $(WF) image
	@$(RUN) bash tests/test_quota_probe.sh

dev: test ## Gate 1: podman, stub publisher

uat: ## Gate 2: two selftest probes against the real bus, temp state
	@t=$$(mktemp -d); trap 'rm -rf "$$t"' EXIT; \
	jq -n '{state_dir:"x",subject_prefix:"line.all.event.quota",probes:{"selftest-ok":{command:"echo X-OK",ok_regex:"X-OK",out_regex:"X-LIMIT",timeout_s:10,resumes:[]},"selftest-out":{command:"echo X-LIMIT",ok_regex:"X-OK",out_regex:"X-LIMIT",timeout_s:10,resumes:[]}}}' > $$t/c.json; \
	for n in selftest-ok selftest-out; do QP_STATE_DIR=$$t/state bash $(QP_HOME)/quota-probe.sh --name $$n --config $$t/c.json; done; true

stable: ## Gate 3: install the figma timer (orchestrator, after merge)
	@$(MAKE) -s -f $(lastword $(MAKEFILE_LIST)) install NAME=figma

rollback: ## Roll stable back
	@$(MAKE) -s -f $(lastword $(MAKEFILE_LIST)) uninstall NAME=figma

clean: ## make clean: remove the state dir
	@rm -rf $(STATE)
