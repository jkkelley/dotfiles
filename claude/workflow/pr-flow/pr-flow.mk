# claude/workflow/pr-flow/pr-flow.mk - the PR process targets (pr-process.md spec <make>), included by claude/workflow/Makefile.
# Every target takes its inputs as VAR=value (Design principles 101 item 17) and times itself through bin/step-time.sh (item 37).
PF      := pr-flow/bin
PF_LINE ?= pr-flow
PF_TIME  = bin/step-time.sh --line $(PF_LINE)

.PHONY: pr-merge pr-merge-all pr-flow-sweep pr-flow-consume pr-flow-consume-stop pr-flow-regen pr-flow-ci-install pr-flow-rollback pr-flow-test pr-flow-lint pr-flow-clean

pr-merge: ## make pr-merge REPO=owner/name PR=N: merge.sh for one PR (the backstop; the Action is the merge)
	@test -n "$(REPO)" && test -n "$(PR)" || { echo "pr-merge needs REPO= and PR="; exit 2; }
	@$(PF_TIME) --node N4 --budget 120 --timeout 300 --retries 1 -- $(PF)/merge.sh --slug $(REPO) --repo "$$($(PF)/pr-flow-config.sh $(REPO) | jq -r .clone)" --pr $(PR)

pr-merge-all: ## make pr-merge-all REPO=owner/name: merge.sh --all
	@test -n "$(REPO)" || { echo "pr-merge-all needs REPO="; exit 2; }
	@$(PF_TIME) --node N4 --budget 120 --timeout 600 --retries 1 -- $(PF)/merge.sh --slug $(REPO) --repo "$$($(PF)/pr-flow-config.sh $(REPO) | jq -r .clone)" --all

pr-flow-sweep: ## make pr-flow-sweep [REPO=owner/name]: one pass of the sweep (records, regen, backstop)
	@REPO=$(REPO) $(PF)/pr-flow-consume.sh sweep

pr-flow-consume: ## make pr-flow-consume: the sweep every 60 s, foreground, for the pr-flow pane of the monitoring tab
	@$(PF)/pr-flow-consume.sh loop --interval $(or $(INTERVAL),60)

pr-flow-consume-stop: ## make pr-flow-consume-stop: stop the sweep loop (its pane closes with the monitoring tab)
	@pkill -f 'pr-flow-consume.sh loop' && echo "pr-flow sweep stopped" || echo "pr-flow sweep was not running"

pr-flow-regen: ## make pr-flow-regen REPO=owner/name [PR=N] [DRY=1]: merge base into PRs conflicting only on generated files
	@test -n "$(REPO)" || { echo "pr-flow-regen needs REPO="; exit 2; }
	@cfg="$$($(PF)/pr-flow-config.sh $(REPO))" && GH_REPO=$(REPO) PR_FLOW_REGEN_PATHS="$$(jq -r .regen.paths <<<"$$cfg")" PR_FLOW_REGEN_CMD="$$(jq -r .regen.cmd <<<"$$cfg")" \
	  $(PF)/regen-conflicts.sh --repo "$$(jq -r .clone <<<"$$cfg")" $(if $(PR),--pr $(PR),--all) $(if $(DRY),--dry-run)

pr-flow-ci-install: ## make pr-flow-ci-install REPO=owner/name [DRY=1]: one PR installing the rendered workflows
	@test -n "$(REPO)" || { echo "pr-flow-ci-install needs REPO="; exit 2; }
	@$(PF)/pr-flow-install.sh install $(REPO) $(if $(DRY),--dry-run)

pr-flow-rollback: ## make pr-flow-rollback REPO=owner/name [DRY=1]: one PR removing merge-on-green.yml
	@test -n "$(REPO)" || { echo "pr-flow-rollback needs REPO="; exit 2; }
	@$(PF)/pr-flow-install.sh rollback $(REPO) $(if $(DRY),--dry-run)

pr-flow-test: image ## make pr-flow-test [CASES="gate records ..."]: the named pr-flow cases (default all) in the pinned test image
	@for c in $(or $(CASES),ci-template gate records merge merge-hold merge-cleanup consume); do \
	  $(RUN) bash pr-flow/tests/$$c.test.sh | tail -1 | sed "s/^/$$c: /" | grep -q 'fail=0' && echo "ok  $$c" || { echo "FAIL $$c"; exit 1; }; done

pr-flow-lint: image ## shellcheck every pr-flow script (warnings and errors; the coq ports carry coq's own info notes)
	@$(RUN) shellcheck --severity=warning -x pr-flow/bin/*.sh pr-flow/tests/*.sh

pr-flow-clean: ## remove pr-flow temp clones, regen worktrees and stale state (the posted ledger is kept: it is post-once)
	@rm -rf "$${PR_FLOW_STATE:-$$HOME/.local/state/zenith/pr-flow}"/install "$${PR_FLOW_STATE:-$$HOME/.local/state/zenith/pr-flow}"/regen \
	  "$${PR_FLOW_STATE:-$$HOME/.local/state/zenith/pr-flow}"/green-* && echo "pr-flow state cleaned"
