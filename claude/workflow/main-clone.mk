# main-clone.mk - Make targets for main-clone-guard.sh (WO-20261016-3327).
#
# Standalone on purpose, like a2a.mk: run as make -C claude/workflow -f main-clone.mk main-clone-check CLONE=<dir>
# BREADCRUMB - not included in claude/workflow/Makefile (Design principles 101 item 19: no shared-file edits across tickets).
# Inputs are VAR=value (item 17). check and ff are the tool and run on the host; main-clone-test is verification, Podman (Rule 14).
GUARD_SH := $(CURDIR)/bin/main-clone-guard.sh
A2A_IMAGE := localhost/dotfiles-workflow-test:1
A2A_ROOT := $(abspath $(CURDIR)/../..)
TIMED = bash $(abspath bin/timed-run.sh) --node $@ --kind make --

.PHONY: main-clone-check main-clone-ff main-clone-test

main-clone-check: ## Is CLONE on BRANCH and current: CLONE= [BRANCH=main] [REMOTE=origin] (MAIN-DRIFT exit 3)
	@test -n "$(CLONE)" || { echo "usage: make main-clone-check CLONE=<dir> [BRANCH=main] [REMOTE=origin]" >&2; exit 2; }
	@$(TIMED) $(GUARD_SH) check "$(CLONE)" "$(or $(BRANCH),main)" "$(or $(REMOTE),origin)"

main-clone-ff: ## Fast-forward CLONE when safe: CLONE= [BRANCH=main] [REMOTE=origin]
	@test -n "$(CLONE)" || { echo "usage: make main-clone-ff CLONE=<dir> [BRANCH=main] [REMOTE=origin]" >&2; exit 2; }
	@$(TIMED) $(GUARD_SH) ff "$(CLONE)" "$(or $(BRANCH),main)" "$(or $(REMOTE),origin)"

main-clone-test: ## The relevant tests only, in Podman
	@$(TIMED) podman run --rm --network=none --userns=keep-id -v "$(A2A_ROOT):/work:Z" -w /work/claude/workflow -e HOME=/tmp $(A2A_IMAGE) \
	  bash -c 'shellcheck -x bin/main-clone-guard.sh tests/unit/test_main_clone_guard.sh && bash tests/unit/test_main_clone_guard.sh'
