# review.mk - verb `review`: make wiki-review WIKI=<root> [SRC=<ignored by this verb>]. Included by wiki.mk.
# SRC is accepted so one command line serves intake and review; the review reads <WIKI>/review.json and raw/, never SRC.
.PHONY: wiki-review
wiki-review: ## render review pages from raw captures per review.json, archive hand copies: WIKI=
	$(wiki-require)
	python3 $(WIKI_DIR)wiki_review.py "$(WIKI)"
