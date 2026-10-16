# Contents lists on every Markdown file. Scripts drive it; nothing by hand.
.PHONY: md-contents md-contents-check md-contents-global md-contents-global-check md-contents-discover

md-contents:            ## write contents lists (changed files; ALL=1 for everything)
	bash scripts/md-contents.sh write $(if $(ALL),--all)

md-contents-check:      ## fail on a missing or stale list (changed files; ALL=1 for everything)
	bash scripts/md-contents.sh check $(if $(ALL),--all)

md-contents-global:     ## write lists into the global files in config/md-contents-global.list (backs up first)
	bash scripts/md-contents.sh global

md-contents-global-check:
	bash scripts/md-contents.sh global --check

md-contents-discover:   ## print untracked global .md files missing from the list
	bash scripts/md-contents.sh discover
