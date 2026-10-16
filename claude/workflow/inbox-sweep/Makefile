# claude/workflow/inbox-sweep - the sweep's controller targets and its own inner loop.
# Platform: WSL only (design D2, Rule 17). The sweep targets need herdr, Windows interop and the Windows home, so there is
# no justfile; every sweep target is one plain `bash bin/sweep.sh ...` call, which is its own fallback.
# The test targets below are the Podman implementation, and `sweep.sh test` calls them: they stay here so a `make test`
# and `sweep.sh test --changed` can never disagree, and so the controller does not recurse into itself.
# Every target that verifies anything runs in Podman on the pinned workflow test image (dotfiles CLAUDE.md Rule 14),
# --network=none, with the repository mounted read-only: a test that writes into the tree fails instead of leaving
# artifacts in a pull request. Test output goes to a mktemp dir inside the container and dies with it.
#
# The container has no git, so `test` computes changed paths here, on the host, and passes them in as SWEEP_CHANGED:
# committed since $(BASE), modified since HEAD, and untracked (--full-name keeps all three repo-root relative).
BASE  ?= origin/main
IMAGE := localhost/dotfiles-workflow-test:1
WF    := $(abspath $(CURDIR)/..)
ROOT  := $(abspath $(CURDIR)/../../..)
# RUN ends before the image name so a target can add -e flags; every use appends $(IMAGE) itself.
RUN   := podman run --rm --network=none --userns=keep-id -v "$(ROOT):/work:ro,Z" -w /work/claude/workflow/inbox-sweep -e HOME=/tmp

.DEFAULT_GOAL := help
.PHONY: help image test test-all herdr-first spec-lint nodes-check bottleneck-check migrate migrate-rollback reply-status reply-send reply-prune suite sweep sweep-gmail sweep-proton sweep-linkedin status clean prune

help: ## Show targets
	@grep -E '^[a-z-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN{FS=":.*?## "}{printf "  %-12s %s\n", $$1, $$2}'

image: ## Build the pinned test image (shared with claude/workflow)
	@podman build -q -t $(IMAGE) -f $(WF)/tests/container/Containerfile $(WF) >/dev/null

test: image ## Suites for files changed against $(BASE) (default origin/main) only
	@changed="$$( (cd $(ROOT) && git diff --name-only $(BASE)...HEAD; git diff --name-only HEAD; git ls-files -o --exclude-standard --full-name) | sort -u)"; \
	$(RUN) -e SWEEP_CHANGED="$$changed" $(IMAGE) bash tests/run.sh --changed

test-all: image ## Every suite; run once before a pull request
	@$(RUN) $(IMAGE) bash tests/run.sh --all

herdr-first: image ## Fail if any sweep script backgrounds a process (Rule 18); SWEEP_BIN_DIR= points the scan elsewhere
	@$(RUN) $(if $(SWEEP_BIN_DIR),-e SWEEP_BIN_DIR=$(SWEEP_BIN_DIR)) $(IMAGE) bash tests/run.sh --suite herdr-first

spec-lint: image ## Fail if any docs/design/*.spec.xml is over 1000 lines or not well-formed XML
	@$(RUN) $(IMAGE) bash bin/spec-lint.sh

nodes-check: image ## Node declarations validate, scripts name declared nodes, design tables agree
	@$(RUN) $(IMAGE) bash bin/node-lib.sh nodes-check

bottleneck-check: image ## List every node's serial reason; fail on a serial node with none
	@$(RUN) $(IMAGE) bash bin/node-lib.sh bottleneck-check

# migrate and migrate-rollback are operational, not verification: they write the owner's run records, so they run on the
# host (the test image mounts the tree read-only, and the records are not in the tree). Their tests run in Podman via `make test`.
migrate: ## Copy-forward every pending record file under DIR to the pinned schema version (writes beside the originals)
	@test -n "$(DIR)" || { echo "usage: make migrate DIR=<records dir>" >&2; exit 2; }
	@bash bin/migrate.sh migrate "$(DIR)"

migrate-rollback: ## Pin NODE back to TO, RECORD back to schema version SV, set aside newer copies in DIR
	@test -n "$(NODE)" && test -n "$(TO)" && test -n "$(RECORD)" && test -n "$(SV)" && test -n "$(DIR)" \
	  || { echo "usage: make migrate-rollback NODE=<id> TO=<semver> RECORD=<name> SV=<schema version> DIR=<records dir>" >&2; exit 2; }
	@bash bin/migrate.sh rollback "$(NODE)" "$(TO)" "$(RECORD)" "$(SV)" "$(DIR)"

# The reply targets are operational too: they read and write the owner's approval folders and start a real send seat, so they run
# on the host. Their tests run in Podman via `make test`. reply-send takes ONE approval file; there is no "send everything".
reply-status: ## List approved replies with their latest ledger code (DAY=yyyymmdd to narrow)
	@bash bin/reply-send.sh status $(if $(DAY),--day $(DAY))

reply-send: ## Start the send seat for one approved file: make reply-send APPROVAL=<send-*.txt>
	@test -n "$(APPROVAL)" || { echo "usage: make reply-send APPROVAL=<send-*.txt>" >&2; exit 2; }
	@bash bin/reply-send.sh send --approval "$(APPROVAL)"

reply-prune: ## Delete reply files past their age (DAYS=14; ledgers keep 90 days); DRY=1 only lists
	@bash bin/reply-send.sh prune --days $(or $(DAYS),14) $(if $(DRY),--dry-run)

suite: image ## One suite: make suite SUITE=<name>
	@test -n "$(SUITE)" || { echo "usage: make suite SUITE=<name>" >&2; exit 2; }
	@$(RUN) $(IMAGE) bash tests/run.sh --suite $(SUITE)

sweep: ## Start a sweep of every seat in the sweep-ctl pane; prints the run id
	@bash bin/sweep.sh start --seats all

sweep-gmail: ## Start a Gmail only sweep
	@bash bin/sweep.sh start --seats gmail

sweep-proton: ## Start a Proton only sweep
	@bash bin/sweep.sh start --seats proton

sweep-linkedin: ## Start a LinkedIn only sweep
	@bash bin/sweep.sh start --seats linkedin

status: ## Run status, latest by default; RUN=<run-id> for another
	@bash bin/sweep.sh status $(if $(RUN),--run $(RUN))

clean: ## Take a finished run down (tabs, briefs, seat dirs); RUN=<run-id>, default latest
	@bash bin/sweep.sh clean $(if $(RUN),--run $(RUN))

prune: ## Remove runs older than DAYS (default 14)
	@bash bin/sweep.sh prune --days $(or $(DAYS),14)
