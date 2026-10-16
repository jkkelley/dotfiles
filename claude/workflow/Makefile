# claude/workflow - the workflow machinery's own inner loop.
# Every target that verifies anything runs in Podman (dotfiles CLAUDE.md Rule 14), --network=none.
IMAGE := localhost/dotfiles-workflow-test:1
CF    := tests/container/Containerfile
# The repository root is mounted, not only this directory: the compaction tests call the context-compaction skill's
# checkpoint.sh, which is the one implementation of the checkpoint format and lives beside this machinery in dotfiles.
ROOT  := $(abspath $(CURDIR)/../..)
RUN   := podman run --rm --network=none --userns=keep-id -v "$(ROOT):/work:Z" -w /work/claude/workflow -e HOME=/tmp $(IMAGE)

.DEFAULT_GOAL := help
include mk/line-watch.mk
include mk/resources.mk
include a2a-guard/a2a-guard.mk
.PHONY: help image test schema lint herdr-first compaction chain failover test-plan ci-job grid step-time lease treehouse-gate inbox-sweep

help: ## Show targets
	@grep -E '^[a-z-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN{FS=":.*?## "}{printf "  %-10s %s\n", $$1, $$2}'

image: ## Build the pinned test image
	@podman build -q -t $(IMAGE) -f $(CF) . >/dev/null && echo "ok  image: $(IMAGE)"

schema: image ## Validate every workflow declaration and record schema
	@$(RUN) bash tests/unit/test_workflow_schemas.sh

lint: image ## shellcheck every script
	@$(RUN) shellcheck -x bin/*.sh tools/*.sh report/rail.sh tests/unit/*.sh

herdr-first: image ## Fail if anything here backgrounds a process (Rule 18)
	@$(RUN) bash tests/unit/test_herdr_first.sh

compaction: image ## The compaction ceremony, watcher, switch and hook, against a stub herdr
	@$(RUN) bash tests/unit/test_compaction.sh

chain: image ## The spawner starts the requested link of a model chain on that link's surface
	@$(RUN) bash tests/unit/test_model_chain.sh

failover: image ## The seat watcher: done records, hot swap along the chain, exhaustion, against a stub herdr
	@$(RUN) bash tests/unit/test_seat_watch.sh

test-plan: image ## The test-plan block: template, work-order's parser and the schema agree (O-10)
	@$(RUN) bash tests/unit/test_test_plan.sh

step-time: image ## step-time.sh: timing records, SLOW, timeout, retries, bus down tolerated (item 37)
	@$(RUN) bash tests/unit/test_step_time.sh

ci-job: image ## CI runs this suite: the gate's selector and the job that calls make test (PR 99 gap)
	@$(RUN) bash tests/unit/test_ci_job.sh

# WO-20261016-4c73: CI's claude/workflow job runs `make -C claude/workflow test`, and nothing here reached inbox-sweep, so
# its suites never ran in CI and PR 168 merged with its lint suite red (fixed by PR 192). Calling its own test-all keeps
# inbox-sweep's suite list in its own Makefile. Rejected: a second step in skill-pr-gate.yml, a file every CI change
# conflicts on. Cost: the job also runs every inbox-sweep suite, which is CI's job under Design principles 101 item 6.
inbox-sweep: ## Every inbox-sweep suite, for CI
	@$(MAKE) -s -C inbox-sweep test-all

test: schema lint herdr-first compaction chain failover test-plan ci-job step-time inbox-sweep ## Everything
	@echo "ok  workflow: schema, lint, herdr-first, compaction, chain, failover, test-plan, ci-job, inbox-sweep"

# ---- herdr 3x3 grid (docs/design/herdr-grid.md). Inputs are VAR=value; defaults live in config/project.json .workflow.herdr.grid
need = $(if $($(1)),,$(error $(1)= is required))
.PHONY: line-reconcile architect-up line-up seat-up seat-down seat-adopt line-adopt-named line-clean line-status line-adopt grid
line-up: ## make line-up LINE=<name>: tab "<name> 1", architect left, 2x3 seat slots
	$(call need,LINE)
	@bash bin/herdr-grid.sh line-up "$(LINE)"
line-reconcile: ## make line-reconcile LINE=: unique numbered tabs, seats packed, stash emptied, no restarts
	$(call need,LINE)
	@bash bin/herdr-grid.sh line-reconcile "$(LINE)"
architect-up: ## make architect-up LINE= [RESUME=1]: (re)start the architect with bypass + Remote Control
	$(call need,LINE)
	@bash bin/herdr-grid.sh architect-up "$(LINE)" $(if $(RESUME),resume)
seat-up: ## make seat-up LINE= SEAT= [CMD=]: next free slot, labelled; new tab when full
	$(call need,LINE)$(call need,SEAT)
	@bash bin/herdr-grid.sh seat-up "$(LINE)" "$(SEAT)" "$(CMD)"
seat-down: ## make seat-down SEAT= [LINE=] [FORCE=1]: close a finished seat, reflow
	$(call need,SEAT)
	@bash bin/herdr-grid.sh seat-down "$(SEAT)" "$(LINE)"
seat-adopt: ## make seat-adopt LINE= SEAT= PANE=<pane>: move a named pane from outside the grid into the next free slot, no restart
	$(call need,LINE)$(call need,SEAT)$(call need,PANE)
	@bash bin/herdr-grid.sh seat-adopt "$(LINE)" "$(SEAT)" "$(PANE)"
line-adopt-named: ## make line-adopt-named LINE=: seat-adopt every named agent pane that no grid, monitor or watchers tab holds (the sweep does this every minute)
	$(call need,LINE)
	@bash bin/herdr-grid.sh adopt-named "$(LINE)"
line-clean: ## make line-clean LINE=: close every finished seat of the line
	$(call need,LINE)
	@bash bin/herdr-grid.sh line-clean "$(LINE)"
line-status: ## make line-status LINE=: tab, slot, seat, agent, status
	$(call need,LINE)
	@bash bin/herdr-grid.sh line-status "$(LINE)"
line-adopt: ## make line-adopt LINE= ARCH=<pane> SEATS="name=pane ...": migrate a live line, no restarts
	$(call need,LINE)$(call need,ARCH)$(call need,SEATS)
	@bash bin/herdr-grid.sh line-adopt "$(LINE)" "$(ARCH)" $(SEATS)
grid: image ## The grid script against a stub herdr (relevant test only)
	@$(RUN) bash tests/unit/test_herdr_grid.sh
lease: image ## workflow-spawn.sh leases the seat's worktree from treehouse (relevant test only)
	@$(RUN) bash tests/unit/test_treehouse_lease.sh
treehouse-gate: image ## make treehouse-gate OLD= NEW= REPOS="abs..." POOLS="pool-dir..." OUT=: new treehouse on copied pools, in podman
	$(call need,OLD)$(call need,NEW)$(call need,REPOS)$(call need,POOLS)$(call need,OUT)
	@bash tests/container/treehouse-gate.sh --old "$(OLD)" --new "$(NEW)" --repos "$(REPOS)" --pools "$(POOLS)" --out "$(OUT)"
include herdr-bus/herdr-bus.mk
include stuck-watch/stuck-watch.mk
include timing/timing.mk
