# check.mk - the check verb: `make wiki-check WIKI=<root>`; included by wiki.mk. Design: docs/design/wiki.spec.xml (verbs, check).
# Read-only: prints one 'CODE path:line' per finding; exit 0 clean, 3 findings, 2 usage.
.PHONY: wiki-check
wiki-check: ## fail on missing contents, broken links, orphan raws, uncited sections, size, secrets, TODO-WRITE: WIKI=
	$(wiki-require)
	@python3 $(WIKI_DIR)wiki_check.py "$(WIKI)"
