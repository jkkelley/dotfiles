# intake.mk - verb `intake`: make wiki-intake WIKI=<root> SRC=<file or dir> [SRC="a b"]. Included by wiki.mk.
# Why the empty-SRC check: the script treats no sources as usage (exit 2); Make catches it first so the message names SRC.
.PHONY: wiki-intake
wiki-intake: ## capture SRC into WIKI raw by content hash: WIKI= SRC=
	$(wiki-require)
	@if [ -z "$(SRC)" ]; then echo "usage: SRC=<file or dir> is required" >&2; exit 2; fi
	python3 $(WIKI_DIR)wiki_intake.py "$(WIKI)" $(SRC)
