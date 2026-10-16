# rolodex: header reviewed
# name: dag.mk
# purpose: the dag-state Make targets: take, plan, apply, drift, recover, migrate, rollback, status, check, clean, test
# inputs: VAR=value on the command line (TICKET RUN JOBS TO OLDER_THAN CASE); defaults come from dag/config/dag.json
# outputs: each target's script output; exit code is the script's
# writes-to: <state_dir>/runs/ through the scripts only (outside the repository)
# cleanup: none needed
# Included once from claude/workflow/Makefile. Spec: docs/design/dag-state.spec.xml <make>; design docs/design/dag-state.md section 12.
#
# BREADCRUMB (WO-20261016-e271, dag-state T11).
# What broke: nothing yet; the spec names RUN=<run-id> for every verb, and claude/workflow/Makefile already defines RUN as the
#   podman command line. `make dag-plan RUN=x` would override that variable for the whole run and every $(RUN) recipe would
#   start `x` instead of podman.
# Why this fix: the podman command here is built from IMAGE and ROOT (never overridden) into DAG_PODMAN, so RUN= can carry the
#   run id as the spec says. Rejected: renaming the argument to DAGRUN, which departs from the spec and the design table.
#   dag_need tests $(origin), because RUN is always defined here and a plain emptiness test would pass without RUN=.
# Cost: DAG_PODMAN repeats the flags of RUN in the Makefile; a flag change there must be made here too.
DAG_HOME   := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
DAG_CFG    := $(DAG_HOME)/config/dag.json
DAG_ROOT   := $(abspath $(DAG_HOME)/../../..)
DAG_STATE  := $(shell jq -r .state_dir $(DAG_CFG) | sed "s|^~|$$HOME|")
DAG_ENV    := DAG_CONFIG=$(DAG_CFG) DAG_STATE_DIR=$(DAG_STATE) DAG_DESIGN_DIR=$(DAG_ROOT)/$(shell jq -r .design_dir $(DAG_CFG))
DAG_PODMAN := podman run --rm --network=none --userns=keep-id -v "$(ROOT):/work:Z" -w /work/claude/workflow -e HOME=/tmp -e CASE="$(CASE)" $(IMAGE)
dag_need   = $(if $(filter command line environment,$(origin $(1))),,$(error $(1)= is required))
.PHONY: dag-take dag-plan dag-apply dag-drift dag-recover dag-migrate dag-migrate-rollback dag-status dag-check dag-clean dag-test

dag-take: ## make dag-take TICKET=WO-...: N1 to N3, opens the run, worktree and branch
	$(call dag_need,TICKET)
	@$(TIMED) env $(DAG_ENV) bash $(DAG_HOME)/bin/dag-take.sh --ticket "$(TICKET)"
dag-plan: ## make dag-plan RUN=<run-id>: classes every node, prints the ready set
	$(call dag_need,RUN)
	@$(TIMED) env $(DAG_ENV) bash $(DAG_HOME)/bin/dag-plan.sh --run "$(RUN)"
dag-apply: ## make dag-apply RUN=<run-id> [JOBS=n]: runs the ready set
	$(call dag_need,RUN)
	@$(TIMED) env $(DAG_ENV) bash $(DAG_HOME)/bin/dag-apply.sh --run "$(RUN)" $(if $(JOBS),--jobs "$(JOBS)")
dag-drift: ## make dag-drift RUN=<run-id>: state against design and world, never repairs
	$(call dag_need,RUN)
	@$(TIMED) env $(DAG_ENV) bash $(DAG_HOME)/bin/dag-drift.sh --run "$(RUN)"
dag-recover: ## make dag-recover RUN=<run-id>: clear a dead lock, reset dead nodes, plan then apply
	$(call dag_need,RUN)
	@$(TIMED) env $(DAG_ENV) bash $(DAG_HOME)/bin/dag-recover.sh --run "$(RUN)"
dag-migrate: ## make dag-migrate RUN=<run-id>: move a live run onto the design now
	$(call dag_need,RUN)
	@$(TIMED) env $(DAG_ENV) bash $(DAG_HOME)/bin/dag-migrate.sh "$(RUN)"
dag-migrate-rollback: ## make dag-migrate-rollback RUN=<run-id> TO=<semver>: undo the last migration that started at TO
	$(call dag_need,RUN)$(call dag_need,TO)
	@$(TIMED) env $(DAG_ENV) bash $(DAG_HOME)/bin/dag-migrate.sh rollback "$(RUN)" "$(TO)"
dag-status: ## make dag-status RUN=<run-id>: the run's facts and every node's status
	$(call dag_need,RUN)
	@$(TIMED) env $(DAG_ENV) bash $(DAG_HOME)/bin/dag-lib.sh status "$(RUN)"
dag-check: image ## node declarations, config, code map, ticket file sets, spec lint (podman)
	@$(TIMED) $(DAG_PODMAN) bash dag/bin/dag-check.sh
dag-clean: ## make dag-clean OLDER_THAN=<days>: remove archived runs older than that and runs with no state file
	$(call dag_need,OLDER_THAN)
	@$(TIMED) env $(DAG_ENV) bash $(DAG_HOME)/bin/dag-check.sh clean --older-than "$(OLDER_THAN)"
dag-test: image ## make dag-test [CASE=]: every dag/tests/unit/test_dag_*.sh in podman; a test given CASE runs only that case
	@$(TIMED) $(DAG_PODMAN) bash -c 'for f in dag/tests/unit/test_dag_*.sh; do bash "$$f" || exit 1; done'
