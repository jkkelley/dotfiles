# index.mk - verb `index`: make wiki-index WIKI=<root> SRC=<ignored>; included by wiki.mk.
# Design: docs/design/wiki.spec.xml (verb index). Generates <WIKI>/index/README.md from processed/*.md; never edited by hand.
# Why SRC is not read: the ticket's AC calls it with SRC=<dir>; index reads only processed/, so SRC is accepted and ignored.
.PHONY: wiki-index
wiki-index: ## generate index/README.md (contents, pages, topic map, backlinks) from processed pages: WIKI=
	$(wiki-require)
	@python3 $(WIKI_DIR)wiki_index.py "$(WIKI)"
