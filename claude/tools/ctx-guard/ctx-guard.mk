# ctx-guard.mk - include from any repo's Makefile: `include path/to/ctx-guard.mk`, then `make ctx-guard-install`.
# Wraps the existing compaction-guard (30% ceiling, smart checkpoints). See ctx-guard.sh for the breadcrumb.
CTX_GUARD_SH := $(dir $(lastword $(MAKEFILE_LIST)))ctx-guard.sh
.PHONY: ctx-guard-install ctx-guard-project ctx-guard-status ctx-guard-check ctx-guard-uninstall ctx-guard-watch
ctx-guard-install: ## Wire compaction-guard into ~/.claude (all projects), backed up, asserted
	@bash $(CTX_GUARD_SH) install --global
ctx-guard-project: ## Wire it into this repo only (CTX_GUARD_DIR=dir, default .)
	@bash $(CTX_GUARD_SH) install --project $(or $(CTX_GUARD_DIR),.)
ctx-guard-status: ## doctor plus per-session status
	@bash $(CTX_GUARD_SH) status
ctx-guard-check: ## One non-disruptive pass over every seat
	@bash $(CTX_GUARD_SH) check
ctx-guard-uninstall: ## Remove the wiring, restoring the chained status line
	@bash $(CTX_GUARD_SH) uninstall --global
ctx-guard-watch: ## Alerts on HIGH only, in one labeled herdr pane, no model calls
	@bash $(CTX_GUARD_SH) watch
ctx-guard-test: ## Relevant-only test, in Podman (Rule 14)
	@podman run --rm --network=none -v "$(abspath $(dir $(CTX_GUARD_SH))):/w:Z" localhost/dotfiles-workflow-test:1 bash /w/tests/test_ctx_guard.sh
