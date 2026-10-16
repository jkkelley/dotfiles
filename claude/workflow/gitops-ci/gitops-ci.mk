# claude/workflow/gitops-ci/gitops-ci.mk - diff-selected CI for a GitOps repository (ticket WO-20261016-ae02, ORD-1128 K1).
# Called as: make -f <dotfiles>/claude/workflow/gitops-ci/gitops-ci.mk <target> REPO=owner/name REPO_DIR=<checkout> BASE=<ref>; every input is VAR=value (item 17), every recipe is timed by bin/timed-run.sh (item 37).
GC := $(patsubst %/,%,$(dir $(abspath $(lastword $(MAKEFILE_LIST)))))
TIMED = bash $(GC)/../bin/timed-run.sh --node $@ --kind make --
REPO_DIR ?= $(CURDIR)
BASE ?=
SELECT ?= $(or $(TMPDIR),/tmp)/gitops-ci-select-$(subst /,_,$(REPO)).json
.PHONY: gitops-select gitops-check gitops-gate gitops-ci-test gitops-ci-clean

gitops-select: ## write the diff selection JSON to SELECT
	@test -n "$(REPO)" || { echo "gitops-select needs REPO="; exit 2; }
	@$(TIMED) bash $(GC)/bin/gitops-changed.sh --repo $(REPO) --repo-dir $(REPO_DIR) --base "$(BASE)" > $(SELECT)

gitops-check: gitops-select ## yamllint, kubeconform, helm template and kustomize build on the selection
	@$(TIMED) bash $(GC)/bin/gitops-check.sh --repo $(REPO) --repo-dir $(REPO_DIR) --select $(SELECT)

gitops-gate: gitops-select ## dev and UAT gate evidence on a PR touching a deploy path
	@$(TIMED) bash $(GC)/bin/gitops-gate-evidence.sh --repo $(REPO) --select $(SELECT) $(if $(BODY),--body-file $(BODY))

gitops-ci-test: ## the gitops-ci tests in the pinned workflow test image
	@$(MAKE) --no-print-directory -C $(GC)/.. image && $(TIMED) podman run --rm --network=none --userns=keep-id -e HOME=/tmp -v "$(abspath $(GC)/../../..):/work:Z" -w /work localhost/dotfiles-workflow-test:1 bash claude/workflow/gitops-ci/tests/gitops-ci.test.sh

gitops-ci-clean: ## remove the selection files
	@rm -f $(or $(TMPDIR),/tmp)/gitops-ci-select-*.json && echo "gitops-ci: clean"
