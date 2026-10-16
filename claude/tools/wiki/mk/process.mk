# process.mk - verb `process`: make wiki-process WIKI=<root> SRC=<unused-by-script>; included by wiki.mk.
# Design: docs/design/wiki.spec.xml (verb process). Writes page skeletons from <WIKI>/pages.json; never touches written prose.
# Why SRC is not read: the ticket's AC calls it with SRC=<dir>; process reads only pages.json and raw/, so SRC is accepted and ignored.
.PHONY: wiki-process
wiki-process: ## write page skeletons with raw citations from pages.json: WIKI=
	$(wiki-require)
	python3 $(WIKI_DIR)wiki_process.py "$(WIKI)"
