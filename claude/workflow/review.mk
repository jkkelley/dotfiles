# review.mk - Make targets for publishing merged directories to the review server root (WO-20261016-8c45).
#
# Standalone like a2a.mk, run as: make -C claude/workflow -f review.mk review-publish REPO=<repo> SRC=<dir> NAME=<name>
# BREADCRUMB - why this is not in claude/workflow/Makefile: same reason as a2a.mk, a new file cannot collide with
#   another ticket's edit (Design principles 101 item 19). Cost: no include in Makefile until a later ticket adds one.
# Inputs are VAR=value (item 17). review-publish is the tool itself and runs on the host; review-test is verification
# and runs in Podman (Rule 14).
REVIEW_SH := $(CURDIR)/bin/review-publish.sh
REVIEW_IMAGE := localhost/dotfiles-workflow-test:1
REVIEW_ROOT := $(abspath $(CURDIR)/../..)
# Every recipe runs through the shared timing wrapper (item 37), as in a2a.mk.
TIMED = bash $(abspath bin/timed-run.sh) --node $@ --kind make --

.PHONY: review-publish review-test

review-publish: ## Publish a merged directory: REPO= SRC= NAME= [REF=] (git archive of REF:SRC into the review root, prints each URL)
	@test -n "$(REPO)" -a -n "$(SRC)" -a -n "$(NAME)" || { echo "usage: make review-publish REPO=<repo> SRC=<dir> NAME=<name> [REF=<ref>]" >&2; exit 2; }
	@$(TIMED) $(REVIEW_SH) "$(REPO)" "$(SRC)" "$(NAME)" $(if $(REF),"$(REF)")

review-test: ## The relevant tests only, in Podman
	@$(TIMED) podman run --rm --network=none --userns=keep-id -v "$(REVIEW_ROOT):/work:Z" -w /work/claude/workflow -e HOME=/tmp $(REVIEW_IMAGE) \
	  bash -c 'shellcheck -x bin/review-publish.sh tests/unit/test_review_publish.sh && bash tests/unit/test_review_publish.sh'
