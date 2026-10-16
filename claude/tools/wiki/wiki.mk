# wiki.mk - include from the dotfiles root Makefile: `include claude/tools/wiki/wiki.mk`, then `make wiki-<verb> WIKI=<root>`.
# Design: docs/design/wiki.spec.xml (layout). The engine is generic; a wiki root holds only wiki.json, pages.json and content.
# Each verb is one mk/<verb>.mk and one wiki_<verb>.py, so adding a verb touches no other file (design item 40).
# Inputs are Make variables passed as arguments: WIKI= (required by every verb), SRC= (intake).
WIKI_DIR := $(dir $(lastword $(MAKEFILE_LIST)))
WIKI_IMAGE := docker.io/library/python@sha256:2f17fc044b579bab302c2e8054d3a686e2cb9a83de48e70534b94cd8ebbe06a9
WIKI ?=
.PHONY: wiki-test
# wiki-require: a verb that guesses a wiki root is the NEVER case; an empty WIKI is a usage error, exit 2.
define wiki-require
@if [ -z "$(WIKI)" ]; then echo "usage: WIKI=<root> is required" >&2; exit 2; fi
endef
wiki-test: ## relevant tests only, in Podman (Rule 14): TESTS= (default every tests/test_*.py)
	podman run --rm --network=none -v "$(CURDIR):/w:Z" -w /w $(WIKI_IMAGE) python3 -m unittest -v $(or $(TESTS),$(wildcard $(WIKI_DIR)tests/test_*.py))
-include $(wildcard $(WIKI_DIR)mk/*.mk)
