# artifact.mk - include from any repo's Makefile: `include path/to/artifact.mk`, then `make artifact-new KEY= NAME= EXT=`.
# Files that never go in git: written to the store by script, linked in like packages. See README.md beside this file.
ARTIFACT_SH := $(dir $(lastword $(MAKEFILE_LIST)))artifact.sh
# Inputs are Make variables passed as arguments; the store root and keys also come from artifact.conf or the environment
# (ARTIFACT_CONF, ARTIFACT_ROOT, ARTIFACT_KEYS, ARTIFACT_CHECK_PATTERNS, ARTIFACT_CHECK_ALLOW).
export ARTIFACT_CONF ARTIFACT_ROOT ARTIFACT_KEYS ARTIFACT_CHECK_PATTERNS ARTIFACT_CHECK_ALLOW
.PHONY: artifact-new artifact-link artifact-find artifact-check artifact-clean artifact-test
# BRANCH is forwarded only when the caller set it (command line or environment). The root Makefile sets
# `BRANCH ?= chore/golden-rules` for golden-rules-repos, so a plain $(if $(BRANCH),...) stamped that branch into
# every artifact's frontmatter. Left unset, artifact.sh reads the real branch from git. Renaming the variable was
# rejected: BRANCH= is this target's documented interface. Cost: a BRANCH set inside a makefile is ignored here.
ARTIFACT_BRANCH = $(if $(filter command line environment environment override,$(origin BRANCH)),$(BRANCH))
artifact-new: ## Print a new store path with frontmatter: KEY= NAME= EXT= [WHAT= REPO= BRANCH= SESSION=]
	@bash $(ARTIFACT_SH) new --key "$(KEY)" --name "$(NAME)" --ext "$(EXT)" $(if $(WHAT),--what "$(WHAT)") \
	  $(if $(REPO),--repo "$(REPO)") $(if $(ARTIFACT_BRANCH),--branch "$(ARTIFACT_BRANCH)") $(if $(SESSION),--session "$(SESSION)")
artifact-link: ## Gitignored .artifacts link from this repo into the store: [DIR=.] [EXCLUDE=1]
	@bash $(ARTIFACT_SH) link --dir "$(or $(DIR),.)" $(if $(EXCLUDE),--exclude)
artifact-find: ## List a key's files by date: KEY= [SINCE=YYYY-MM-DD] [REPO=]
	@bash $(ARTIFACT_SH) find --key "$(KEY)" $(if $(SINCE),--since "$(SINCE)") $(if $(REPO),--repo "$(REPO)")
artifact-check: ## Fail on any tracked file that belongs in the store: [DIR=.]
	@bash $(ARTIFACT_SH) check --dir "$(or $(DIR),.)"
artifact-clean: ## Dry run unless APPLY=1: KEY= OLDER_THAN=days
	@bash $(ARTIFACT_SH) clean --key "$(KEY)" --older-than "$(OLDER_THAN)" $(if $(APPLY),--apply)
artifact-test: ## Relevant-only test, in Podman (Rule 14)
	@podman run --rm --network=none --userns=keep-id --entrypoint="" -v "$(abspath $(dir $(ARTIFACT_SH))):/w:ro,Z" \
	  localhost/dotfiles-claude-tools-test:4 bash /w/tests/test_artifact.sh
